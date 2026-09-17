#include "important_alarm_bridge.h"

#include <comdef.h>
#include <taskschd.h>
#include <wrl/client.h>

#include <algorithm>
#include <sstream>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return std::wstring();
  const int size = ::MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0);
  std::wstring result(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), size);
  return result;
}

std::wstring EscapeXml(const std::wstring& value) {
  std::wstring result;
  for (const wchar_t character : value) {
    switch (character) {
      case L'&': result += L"&amp;"; break;
      case L'<': result += L"&lt;"; break;
      case L'>': result += L"&gt;"; break;
      case L'\"': result += L"&quot;"; break;
      case L'\'': result += L"&apos;"; break;
      default: result += character; break;
    }
  }
  return result;
}

std::wstring ExecutablePath() {
  std::wstring path(32768, L'\0');
  const DWORD size = ::GetModuleFileNameW(nullptr, path.data(),
                                          static_cast<DWORD>(path.size()));
  path.resize(size);
  return path;
}

HRESULT GetOrCreateFolder(ITaskFolder* parent, const wchar_t* name,
                          ITaskFolder** folder) {
  HRESULT result = parent->GetFolder(_bstr_t(name), folder);
  if (SUCCEEDED(result)) return result;
  return parent->CreateFolder(_bstr_t(name), _variant_t(), folder);
}

HRESULT SyncScheduledTasks(
    const std::vector<std::pair<std::wstring, std::wstring>>& alarms) {
  ComPtr<ITaskService> service;
  HRESULT result = ::CoCreateInstance(CLSID_TaskScheduler, nullptr,
                                      CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&service));
  if (FAILED(result)) return result;
  result = service->Connect(_variant_t(), _variant_t(), _variant_t(),
                            _variant_t());
  if (FAILED(result)) return result;

  ComPtr<ITaskFolder> root;
  result = service->GetFolder(_bstr_t(L"\\"), &root);
  if (FAILED(result)) return result;
  ComPtr<ITaskFolder> todo;
  result = GetOrCreateFolder(root.Get(), L"Todo", &todo);
  if (FAILED(result)) return result;
  ComPtr<ITaskFolder> folder;
  result = GetOrCreateFolder(todo.Get(), L"Alarmas", &folder);
  if (FAILED(result)) return result;

  ComPtr<IRegisteredTaskCollection> existing;
  if (SUCCEEDED(folder->GetTasks(TASK_ENUM_HIDDEN, &existing))) {
    LONG count = 0;
    existing->get_Count(&count);
    for (LONG index = count; index >= 1; --index) {
      ComPtr<IRegisteredTask> task;
      if (SUCCEEDED(existing->get_Item(_variant_t(index), &task))) {
        BSTR name = nullptr;
        if (SUCCEEDED(task->get_Name(&name)) && name != nullptr) {
          folder->DeleteTask(name, 0);
          ::SysFreeString(name);
        }
      }
    }
  }

  const std::wstring executable = EscapeXml(ExecutablePath());
  for (const auto& alarm : alarms) {
    std::wstring safe_name = alarm.first;
    std::replace_if(safe_name.begin(), safe_name.end(),
                    [](wchar_t c) { return !(iswalnum(c) || c == L'_'); },
                    L'_');
    const std::wstring task_name = L"Alarma_" + safe_name;
    std::wstringstream xml;
    xml << LR"(<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"><RegistrationInfo><Description>Alarma importante de Todo</Description></RegistrationInfo><Triggers><TimeTrigger><StartBoundary>)"
        << EscapeXml(alarm.second)
        << LR"(</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers><Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals><Settings><MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><StartWhenAvailable>true</StartWhenAvailable><WakeToRun>false</WakeToRun><ExecutionTimeLimit>PT5M</ExecutionTimeLimit><Enabled>true</Enabled></Settings><Actions Context="Author"><Exec><Command>)"
        << executable << LR"(</Command><Arguments>--important-alarm=)"
        << EscapeXml(alarm.first)
        << LR"(</Arguments></Exec></Actions></Task>)";
    ComPtr<IRegisteredTask> registered;
    result = folder->RegisterTask(
        _bstr_t(task_name.c_str()), _bstr_t(xml.str().c_str()),
        TASK_CREATE_OR_UPDATE, _variant_t(), _variant_t(),
        TASK_LOGON_INTERACTIVE_TOKEN, _variant_t(L""), &registered);
    if (FAILED(result)) return result;
  }
  return S_OK;
}

const EncodableValue* FindValue(const EncodableMap& map,
                                const char* key) {
  const auto iterator = map.find(EncodableValue(key));
  return iterator == map.end() ? nullptr : &iterator->second;
}

}  // namespace

ImportantAlarmBridge::ImportantAlarmBridge(flutter::BinaryMessenger* messenger,
                                           HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "todo/important_alarms",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "showAlarmWindow") {
          bool started_by_alarm = false;
          if (call.arguments() != nullptr) {
            if (const EncodableMap* map =
                    std::get_if<EncodableMap>(call.arguments())) {
              if (const EncodableValue* value = FindValue(*map, "startedByAlarm")) {
                if (const bool* started = std::get_if<bool>(value)) {
                  started_by_alarm = *started;
                }
              }
            }
          }
          ShowAlarmWindow(started_by_alarm);
          result->Success();
          return;
        }
        if (call.method_name() == "setAlarmActive") {
          if (call.arguments() != nullptr) {
            if (const bool* value = std::get_if<bool>(call.arguments())) {
              alarm_active_ = *value;
            }
          }
          result->Success();
          return;
        }
        if (call.method_name() == "restoreAlarmWindow") {
          bool close_application = false;
          if (call.arguments() != nullptr) {
            if (const EncodableMap* map =
                    std::get_if<EncodableMap>(call.arguments())) {
              if (const EncodableValue* value =
                      FindValue(*map, "closeApplication")) {
                if (const bool* close = std::get_if<bool>(value)) {
                  close_application = *close;
                }
              }
            }
          }
          RestoreWindow(close_application);
          result->Success();
          return;
        }
        if (call.method_name() == "syncAlarms") {
          std::vector<std::pair<std::wstring, std::wstring>> alarms;
          if (call.arguments() != nullptr) {
            if (const EncodableList* list =
                    std::get_if<EncodableList>(call.arguments())) {
              for (const auto& entry : *list) {
                const EncodableMap* map = std::get_if<EncodableMap>(&entry);
                if (map == nullptr) continue;
                const EncodableValue* id_value = FindValue(*map, "id");
                const EncodableValue* time_value = FindValue(*map, "triggerAt");
                if (id_value == nullptr || time_value == nullptr) continue;
                const std::string* id = std::get_if<std::string>(id_value);
                const std::string* time = std::get_if<std::string>(time_value);
                if (id != nullptr && time != nullptr) {
                  alarms.emplace_back(Utf8ToWide(*id), Utf8ToWide(*time));
                }
              }
            }
          }
          const HRESULT hr = SyncScheduledTasks(alarms);
          if (FAILED(hr)) {
            std::ostringstream code;
            code << std::hex << static_cast<unsigned long>(hr);
            result->Error("task_scheduler", "El Programador de tareas rechazó la alarma.",
                          EncodableValue(code.str()));
          } else {
            result->Success();
          }
          return;
        }
        result->NotImplemented();
      });
}

ImportantAlarmBridge::~ImportantAlarmBridge() = default;

void ImportantAlarmBridge::ActivateFromSecondInstance(
    const std::string& alarm_id) {
  alarm_active_ = true;
  ShowAlarmWindow(false);
  if (channel_) {
    channel_->InvokeMethod(
        "importantAlarmActivated",
        std::make_unique<EncodableValue>(alarm_id));
  }
}

bool ImportantAlarmBridge::HandleCloseRequest() {
  if (!alarm_active_ || !channel_) return false;
  channel_->InvokeMethod("alarmCloseRequested", nullptr);
  return true;
}

void ImportantAlarmBridge::ShowAlarmWindow(bool started_by_alarm) {
  if (!placement_saved_) {
    if (started_by_alarm) {
      const HMONITOR monitor =
          ::MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
      MONITORINFO info{sizeof(MONITORINFO)};
      ::GetMonitorInfoW(monitor, &info);
      const int work_width =
          static_cast<int>(info.rcWork.right - info.rcWork.left);
      const int work_height =
          static_cast<int>(info.rcWork.bottom - info.rcWork.top);
      const int normal_width = std::min(1660, work_width);
      const int normal_height = std::min(960, work_height);
      saved_placement_.length = sizeof(WINDOWPLACEMENT);
      saved_placement_.showCmd = SW_SHOWNORMAL;
      saved_placement_.rcNormalPosition = {
          info.rcWork.left + (info.rcWork.right - info.rcWork.left - normal_width) / 2,
          info.rcWork.top + (info.rcWork.bottom - info.rcWork.top - normal_height) / 2,
          info.rcWork.left + (info.rcWork.right - info.rcWork.left + normal_width) / 2,
          info.rcWork.top + (info.rcWork.bottom - info.rcWork.top + normal_height) / 2};
      placement_saved_ = true;
    } else {
      saved_placement_.length = sizeof(WINDOWPLACEMENT);
      placement_saved_ =
          ::GetWindowPlacement(window_, &saved_placement_) != FALSE;
    }
  }
  ::ShowWindow(window_, SW_RESTORE);
  const int width = 520;
  const int height = 340;
  const HMONITOR monitor = ::MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  ::GetMonitorInfoW(monitor, &info);
  const int x = info.rcWork.left + (info.rcWork.right - info.rcWork.left - width) / 2;
  const int y = info.rcWork.top + (info.rcWork.bottom - info.rcWork.top - height) / 2;
  ::SetWindowPos(window_, HWND_TOPMOST, x, y, width, height,
                 SWP_SHOWWINDOW);
  ::SetForegroundWindow(window_);
  FLASHWINFO flash{sizeof(FLASHWINFO), window_, FLASHW_ALL | FLASHW_TIMERNOFG,
                   0, 0};
  ::FlashWindowEx(&flash);
}

void ImportantAlarmBridge::RestoreWindow(bool close_application) {
  alarm_active_ = false;
  FLASHWINFO flash{sizeof(FLASHWINFO), window_, FLASHW_STOP, 0, 0};
  ::FlashWindowEx(&flash);
  ::SetWindowPos(window_, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  if (placement_saved_) {
    ::SetWindowPlacement(window_, &saved_placement_);
    placement_saved_ = false;
  }
  if (close_application) ::PostMessageW(window_, WM_CLOSE, 0, 0);
}
