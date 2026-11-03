#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <cwchar>
#include <optional>
#include <variant>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // crocell/window: "present" raises the window, for notification clicks and
  // the tray; "setIcon" changes the taskbar icon; "setHideOnClose" keeps the
  // app in the tray when the window closes.
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "crocell/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HWND hwnd = GetHandle();
        if (call.method_name() == "present") {
          // Hidden in the tray, or never shown after a --hidden start.
          if (!IsWindowVisible(hwnd)) this->Show();
          if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
          result->Success();
        } else if (call.method_name() == "setHideOnClose") {
          const auto* on = std::get_if<bool>(call.arguments());
          hide_on_close_ = on != nullptr && *on;
          result->Success();
        } else if (call.method_name() == "setIcon") {
          // A PNG, which icon resources may be since Vista. The window owns
          // the handle from here on; the old one is released.
          const auto* png = std::get_if<std::vector<uint8_t>>(call.arguments());
          if (png != nullptr && !png->empty()) {
            HICON icon = CreateIconFromResourceEx(
                const_cast<PBYTE>(png->data()), static_cast<DWORD>(png->size()),
                TRUE, 0x00030000, 256, 256, LR_DEFAULTCOLOR);
            if (icon != nullptr) {
              HICON old_big = reinterpret_cast<HICON>(SendMessage(
                  hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(icon)));
              HICON old_small = reinterpret_cast<HICON>(SendMessage(
                  hwnd, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(icon)));
              if (old_big != nullptr) DestroyIcon(old_big);
              if (old_small != nullptr && old_small != old_big) DestroyIcon(old_small);
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Started with the system: the app stays in the tray until someone opens it.
  const bool start_hidden = wcsstr(GetCommandLineW(), L"--hidden") != nullptr;
  flutter_controller_->engine()->SetNextFrameCallback([this, start_hidden]() {
    if (!start_hidden) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_CLOSE:
      if (hide_on_close_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case WM_ENDSESSION:
      // Logging off, or an installer asking the app to close: really close.
      if (wparam) hide_on_close_ = false;
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
