#ifndef RUNNER_IMPORTANT_ALARM_BRIDGE_H_
#define RUNNER_IMPORTANT_ALARM_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

class ImportantAlarmBridge {
 public:
  ImportantAlarmBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~ImportantAlarmBridge();

  void ActivateFromSecondInstance(const std::string& alarm_id);
  bool HandleCloseRequest();

 private:
  void ShowAlarmWindow(bool started_by_alarm);
  void RestoreWindow(bool close_application);

  HWND window_;
  bool alarm_active_ = false;
  bool placement_saved_ = false;
  WINDOWPLACEMENT saved_placement_{sizeof(WINDOWPLACEMENT)};
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_IMPORTANT_ALARM_BRIDGE_H_
