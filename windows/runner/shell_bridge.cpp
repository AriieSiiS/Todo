#include "shell_bridge.h"

#include <algorithm>

namespace {

constexpr char kChannelName[] = "todo/shell";
constexpr int kQuickCaptureHotKeyId = 0x5451;
// Ancho y alto del modo mini en píxeles lógicos.
constexpr int kCompactWidth = 380;
constexpr int kCompactHeight = 640;
constexpr int kCompactMargin = 16;

}  // namespace

ShellBridge::ShellBridge(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  // Ctrl + Alt + N abre la captura rápida desde cualquier aplicación.
  hotkey_registered_ =
      ::RegisterHotKey(window_, kQuickCaptureHotKeyId,
                       MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 'N') != 0;

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "getStatus") {
          dart_ready_ = true;
          flutter::EncodableMap status;
          status[flutter::EncodableValue("hotkeyRegistered")] =
              flutter::EncodableValue(hotkey_registered_);
          status[flutter::EncodableValue("compact")] =
              flutter::EncodableValue(compact_);
          status[flutter::EncodableValue("fullScreen")] =
              flutter::EncodableValue(full_screen_);
          result->Success(flutter::EncodableValue(status));
          if (exit_requested_) channel_->InvokeMethod("requestExit", nullptr);
        } else if (call.method_name() == "setCompactMode") {
          const bool* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("argumento", "Se esperaba un valor lógico.");
            return;
          }
          result->Success(flutter::EncodableValue(SetCompactMode(*enabled)));
        } else if (call.method_name() == "setFullScreen") {
          const bool* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("argumento", "Se esperaba un valor lógico.");
            return;
          }
          result->Success(flutter::EncodableValue(SetFullScreen(*enabled)));
        } else if (call.method_name() == "finishExit") {
          exiting_ = true;
          result->Success();
          ::PostMessageW(window_, WM_CLOSE, 0, 0);
        } else if (call.method_name() == "exitFailed") {
          exit_requested_ = false;
          ::EnableWindow(window_, TRUE);
          BringToFront();
          std::wstring mensaje =
              L"No se pudieron guardar los cambios. Todo sigue abierto para que puedas reintentarlo.";
          // El motivo llega en UTF-8 desde Dart; se añade para poder investigarlo.
          if (const auto* motivo = std::get_if<std::string>(call.arguments())) {
            const int largo = ::MultiByteToWideChar(
                CP_UTF8, 0, motivo->c_str(), static_cast<int>(motivo->size()),
                nullptr, 0);
            if (largo > 0) {
              std::wstring ancho(static_cast<size_t>(largo), L'\0');
              ::MultiByteToWideChar(CP_UTF8, 0, motivo->c_str(),
                                    static_cast<int>(motivo->size()),
                                    ancho.data(), largo);
              mensaje += L"\n\nMotivo: " + ancho.substr(0, 300);
            }
          }
          ::MessageBoxW(window_, mensaje.c_str(), L"Todo", MB_OK | MB_ICONERROR);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

}

ShellBridge::~ShellBridge() {
  if (hotkey_registered_) {
    ::UnregisterHotKey(window_, kQuickCaptureHotKeyId);
  }
}

void ShellBridge::RequestExit() {
  if (exit_requested_) return;
  exit_requested_ = true;
  // Se oculta al instante; el guardado termina sin que se vea la ventana colgada.
  ::EnableWindow(window_, FALSE);
  ::ShowWindow(window_, SW_HIDE);
  if (dart_ready_) channel_->InvokeMethod("requestExit", nullptr);
}

bool ShellBridge::HandleCloseRequest() {
  if (exiting_) return false;
  RequestExit();
  return true;
}

bool ShellBridge::HandleHotKey(WPARAM id) {
  if (id != kQuickCaptureHotKeyId) {
    return false;
  }
  BringToFront();
  channel_->InvokeMethod("quickCapture", nullptr);
  return true;
}

void ShellBridge::ForwardLaunchArgument(const std::string& argument) {
  channel_->InvokeMethod(
      "launchArgument",
      std::make_unique<flutter::EncodableValue>(argument));
}

void ShellBridge::BringToFront() {
  if (::IsIconic(window_)) {
    ::ShowWindow(window_, SW_RESTORE);
  } else if (!::IsWindowVisible(window_)) {
    ::ShowWindow(window_, SW_SHOW);
  }
  // Windows impide robar el foco desde otro proceso; se acopla un instante a
  // la entrada del hilo que tiene el foco para poder activar la ventana.
  const HWND foreground = ::GetForegroundWindow();
  const DWORD foreground_thread =
      foreground == nullptr ? 0 : ::GetWindowThreadProcessId(foreground, nullptr);
  const DWORD current_thread = ::GetCurrentThreadId();
  const bool attached = foreground_thread != 0 &&
                        foreground_thread != current_thread &&
                        ::AttachThreadInput(foreground_thread, current_thread, TRUE);
  ::SetForegroundWindow(window_);
  ::SetFocus(window_);
  if (attached) {
    ::AttachThreadInput(foreground_thread, current_thread, FALSE);
  }
}

bool ShellBridge::SetCompactMode(bool enabled) {
  if (enabled == compact_) {
    return true;
  }
  if (enabled && full_screen_ && !SetFullScreen(false)) {
    return false;
  }
  if (enabled) {
    saved_placement_.length = sizeof(WINDOWPLACEMENT);
    placement_saved_ = ::GetWindowPlacement(window_, &saved_placement_) != 0;
    if (::IsZoomed(window_) || ::IsIconic(window_)) {
      ::ShowWindow(window_, SW_RESTORE);
    }
    MONITORINFO info{sizeof(MONITORINFO)};
    const HMONITOR monitor =
        ::MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
    if (!::GetMonitorInfoW(monitor, &info)) {
      return false;
    }
    const UINT dpi = ::GetDpiForWindow(window_);
    const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
    const int work_width = info.rcWork.right - info.rcWork.left;
    const int work_height = info.rcWork.bottom - info.rcWork.top;
    const int margin = static_cast<int>(kCompactMargin * scale);
    const int width =
        (std::min)(static_cast<int>(kCompactWidth * scale), work_width - 2 * margin);
    const int height = (std::min)(static_cast<int>(kCompactHeight * scale),
                                  work_height - 2 * margin);
    const int x = info.rcWork.right - width - margin;
    const int y = info.rcWork.top + margin;
    ::SetWindowPos(window_, HWND_TOPMOST, x, y, width, height, SWP_SHOWWINDOW);
  } else {
    ::SetWindowPos(window_, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    if (placement_saved_) {
      ::SetWindowPlacement(window_, &saved_placement_);
    }
  }
  compact_ = enabled;
  return true;
}

bool ShellBridge::SetFullScreen(bool enabled) {
  if (enabled == full_screen_) {
    return true;
  }
  if (enabled) {
    if (compact_ && !SetCompactMode(false)) {
      return false;
    }
    MONITORINFO info{sizeof(MONITORINFO)};
    const HMONITOR monitor =
        ::MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
    if (!::GetMonitorInfoW(monitor, &info)) {
      return false;
    }
    full_screen_placement_.length = sizeof(WINDOWPLACEMENT);
    ::GetWindowPlacement(window_, &full_screen_placement_);
    saved_style_ = ::GetWindowLongPtrW(window_, GWL_STYLE);
    // Ventana sin bordes que cubre el monitor entero, barra de tareas incluida;
    // no cambia la resolución ni toma la pantalla en exclusiva.
    ::SetWindowLongPtrW(window_, GWL_STYLE,
                        (saved_style_ & ~WS_OVERLAPPEDWINDOW) | WS_POPUP);
    const RECT& area = info.rcMonitor;
    ::SetWindowPos(window_, HWND_TOP, area.left, area.top,
                   area.right - area.left, area.bottom - area.top,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOOWNERZORDER);
  } else {
    ::SetWindowLongPtrW(window_, GWL_STYLE, saved_style_);
    ::SetWindowPos(window_, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                       SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    ::SetWindowPlacement(window_, &full_screen_placement_);
  }
  full_screen_ = enabled;
  return true;
}
