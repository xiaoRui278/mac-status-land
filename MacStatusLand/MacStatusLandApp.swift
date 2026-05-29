import SwiftUI

@main
struct MacStatusLandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var permissionWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        
        statusBarController = StatusBarController()
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            let hasAccess = AccessibilityService.checkAccessibility(prompt: false)
            if hasAccess {
                print("Accessibility permission granted")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.showAllIcons()
    }
    
    private func showPermissionWindow() {
        print("Showing permission window")
        let viewModel = MenuBarViewModel()
        let hostingView = NSHostingView(rootView: PermissionView(viewModel: viewModel))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = hostingView
        window.title = "Mac Status Land"
        window.center()
        permissionWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("Permission window shown")
        
        // 监听权限变化
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AccessibilityService.checkAccessibility(prompt: false) {
                timer.invalidate()
                window.close()
                self?.statusBarController = StatusBarController()
            }
        }
    }
}
