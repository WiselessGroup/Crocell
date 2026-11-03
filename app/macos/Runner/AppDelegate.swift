import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // With the icon in the menu bar, closing the window only hides it.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return !MainFlutterWindow.hideOnClose
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
