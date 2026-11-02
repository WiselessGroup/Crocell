import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // crocell/window: "present" raises the window, for notification clicks;
    // "setIcon" changes the Dock icon.
    let channel = FlutterMethodChannel(
      name: "crocell/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "present":
        NSApp.activate(ignoringOtherApps: true)
        self?.makeKeyAndOrderFront(nil)
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
