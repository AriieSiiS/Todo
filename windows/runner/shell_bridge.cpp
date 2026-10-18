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
          flutter::EncodableMap status;
          status[flutter::EncodableValue("hotkeyRegistered")] =
              flutter::EncodableValue(hotkey_registered_);
          status[flutter::EncodableValue("compact")] =
              flutter::EncodableValue(compact_);
          result->Success(flutter::EncodableValue(status));
        } else if (call.method_name() == "setCompactMode") {
          const bool* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("argumento", "Se esperaba un valor lógico.");
            return;
          }
          result->Success(flutter::EncodableValue(SetCompactMode(*enabled)));
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
