import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  /// Set once the menu bar icon is up.
  static var hideOnClose = false

  /// Hidden, the app has no window to speak of, so it leaves the Dock too.
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    guard MainFlutterWindow.hideOnClose else { return true }
    orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
    return false
  }

  func present() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    makeKeyAndOrderFront(nil)
  }

  override func awakeFromNib() {
    delegate = self
    // Opening the app again from Finder or Launchpad while it hides. The menu
    // bar menu does not activate the app, so it does not get here.
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self, MainFlutterWindow.hideOnClose, !self.isVisible else { return }
      self.present()
    }

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // crocell/window: "present" raises the window, for notification clicks and
    // the menu bar; "setIcon" changes the Dock icon; "setHideOnClose" keeps the
    // app in the menu bar when the window closes.
    let channel = FlutterMethodChannel(
      name: "crocell/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "present":
        self?.present()
        result(nil)
      case "setHideOnClose":
        MainFlutterWindow.hideOnClose = call.arguments as? Bool ?? false
        result(nil)
      case "setIcon":
        // The Dock icon of the running app, as chosen in Customize.
        if let data = call.arguments as? FlutterStandardTypedData, let image = NSImage(data: data.data) {
          NSApp.applicationIconImage = image
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
