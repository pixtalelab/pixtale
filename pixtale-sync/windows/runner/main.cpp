#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Only one process may run in the current Windows logon session.
constexpr const wchar_t kSingleInstanceMutex[] =
    L"Local\\PixtaleSync-B8A7A2F1-48DF-4A0F-9A4A-6A0E2F7B1D90";

// Restore the running window from minimized or tray state.
void ActivateExistingWindow() {
  HWND window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Pixtale Sync");
  if (window == nullptr) {
    return;
  }
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  } else {
    ::ShowWindow(window, SW_SHOW);
  }
  HWND foreground = ::GetForegroundWindow();
  DWORD foreground_thread = ::GetWindowThreadProcessId(foreground, nullptr);
  DWORD window_thread = ::GetWindowThreadProcessId(window, nullptr);
  bool attached = foreground_thread != 0 && foreground_thread != window_thread &&
                  ::AttachThreadInput(foreground_thread, window_thread, TRUE);
  ::BringWindowToTop(window);
  ::SetForegroundWindow(window);
  if (attached) {
    ::AttachThreadInput(foreground_thread, window_thread, FALSE);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(instance_mutex);
    ActivateExistingWindow();
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Pixtale Sync", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex != nullptr) {
    ::ReleaseMutex(instance_mutex);
    ::CloseHandle(instance_mutex);
  }
  return EXIT_SUCCESS;
}
