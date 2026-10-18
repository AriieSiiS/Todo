#ifndef RUNNER_SHELL_BRIDGE_H_
#define RUNNER_SHELL_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

// Puente entre la ventana de Windows y Dart para la captura rápida:
// registra el atajo global, reenvía los argumentos de una segunda instancia
// y cambia la ventana al modo mini (siempre visible, a un lado de la pantalla).
class ShellBridge {
 public:
  // Identificador de WM_COPYDATA para argumentos de arranque reenviados.
  static constexpr ULONG_PTR kLaunchArgumentData = 0x544F4441;

  ShellBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~ShellBridge();

  // Devuelve true si el atajo registrado es el que ha saltado.
  bool HandleHotKey(WPARAM id);
  void ForwardLaunchArgument(const std::string& argument);

 private:
  void BringToFront();
  bool SetCompactMode(bool enabled);

  HWND window_;
  bool hotkey_registered_ = false;
  bool compact_ = false;
  bool placement_saved_ = false;
  WINDOWPLACEMENT saved_placement_{sizeof(WINDOWPLACEMENT)};
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SHELL_BRIDGE_H_
