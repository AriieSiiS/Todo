#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <windows.h>
#include <wrl/client.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

#define RETURN_IF_FAILED(expr)        \
  {                                   \
    const HRESULT hr__ = (expr);      \
    if (FAILED(hr__)) {               \
      return hr__;                    \
    }                                 \
  }

constexpr wchar_t kTodoAppId[] = L"AlejandroAfonso.Todo.App";

struct JumpTaskDefinition {
  const wchar_t* title;
  const wchar_t* arguments;
  const wchar_t* description;
};

std::wstring GetExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  const auto size = ::GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  path.resize(size);
  return path;
}

HRESULT CreateShellLink(const std::wstring& executable_path,
                        const JumpTaskDefinition& definition,
                        IShellLinkW** shell_link) {
  Microsoft::WRL::ComPtr<IShellLinkW> link;
  RETURN_IF_FAILED(::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&link)));
  RETURN_IF_FAILED(link->SetPath(executable_path.c_str()));
  RETURN_IF_FAILED(link->SetArguments(definition.arguments));
  RETURN_IF_FAILED(link->SetDescription(definition.description));
  RETURN_IF_FAILED(link->SetIconLocation(executable_path.c_str(), 0));

  Microsoft::WRL::ComPtr<IPropertyStore> property_store;
  RETURN_IF_FAILED(link.As(&property_store));

  PROPVARIANT title;
  RETURN_IF_FAILED(::InitPropVariantFromString(definition.title, &title));
  RETURN_IF_FAILED(property_store->SetValue(PKEY_Title, title));
  RETURN_IF_FAILED(property_store->Commit());
  ::PropVariantClear(&title);

  *shell_link = link.Detach();
  return S_OK;
}

HRESULT ConfigureJumpList() {
  RETURN_IF_FAILED(::SetCurrentProcessExplicitAppUserModelID(kTodoAppId));

  Microsoft::WRL::ComPtr<ICustomDestinationList> destination_list;
  RETURN_IF_FAILED(::CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&destination_list)));
  RETURN_IF_FAILED(destination_list->SetAppID(kTodoAppId));

  UINT slots = 0;
  Microsoft::WRL::ComPtr<IObjectArray> removed_items;
  RETURN_IF_FAILED(destination_list->BeginList(&slots, IID_PPV_ARGS(&removed_items)));

  Microsoft::WRL::ComPtr<IObjectCollection> tasks;
  RETURN_IF_FAILED(::CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr, CLSCTX_INPROC_SERVER,
                                      IID_PPV_ARGS(&tasks)));

  const std::wstring executable_path = GetExecutablePath();
  const JumpTaskDefinition definitions[] = {
      {L"Hoy", L"--section=today", L"Abrir la vista de hoy"},
      {L"Calendario", L"--section=calendar", L"Abrir el calendario semanal"},
      {L"Proyectos", L"--section=projects", L"Abrir la vista de proyectos"},
      {L"Nueva tarea", L"--new-task", L"Abrir la app creando una tarea"},
      {L"Nuevo proyecto", L"--new-project", L"Abrir la app creando un proyecto"},
      {L"Ajustes", L"--section=settings", L"Abrir los ajustes"},
  };

  for (const auto& definition : definitions) {
    Microsoft::WRL::ComPtr<IShellLinkW> link;
    RETURN_IF_FAILED(CreateShellLink(executable_path, definition, &link));
    RETURN_IF_FAILED(tasks->AddObject(link.Get()));
  }

  Microsoft::WRL::ComPtr<IObjectArray> tasks_array;
  RETURN_IF_FAILED(tasks.As(&tasks_array));
  RETURN_IF_FAILED(destination_list->AddUserTasks(tasks_array.Get()));
  RETURN_IF_FAILED(destination_list->CommitList());
  return S_OK;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  ConfigureJumpList();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(36, 28);
  Win32Window::Size size(1660, 960);
  if (!window.Create(L"todo", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
