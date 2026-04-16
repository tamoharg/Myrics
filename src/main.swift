import AppKit

final class CaptionsAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App is configured as LSUIElement=YES in Info.plist
        // Create an empty status item to anchor the app initially
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎵 Captions"
        NSLog("[Captions] Initial native status item created")

        let controller = MenuBarController(statusItem: statusItem)
        controller.setup()
        menuBarController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.teardown()
    }
}

let app = NSApplication.shared
let delegate = CaptionsAppDelegate()
app.delegate = delegate
app.run()
