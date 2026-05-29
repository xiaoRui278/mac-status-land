import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private let viewModel = MenuBarViewModel()

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        viewModel.initialize()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Mac Status Land")
            button.action = #selector(togglePopover)
            button.target = self
            print("Status bar button created successfully")
        } else {
            print("ERROR: Failed to create status bar button")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "显示所有图标", action: #selector(showAllIcons), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "刷新", action: #selector(refreshIcons), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.animates = true

        let hostingView = NSHostingView(rootView: PopoverView(viewModel: viewModel, onSettings: { [weak self] in
            self?.popover?.performClose(nil)
            self?.openSettings()
        }))
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView

        self.popover = popover
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            viewModel.captureScreenshots()
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: SettingsView(viewModel: viewModel))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                                  styleMask: [.titled, .closable],
                                  backing: .buffered,
                                  defer: false)
            window.contentView = hostingView
            window.title = "Mac Status Land 设置"
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAllIcons() {
        viewModel.showAllApps()
    }

    @objc func refreshIcons() {
        viewModel.refreshMenuBarApps()
        viewModel.captureScreenshots()
    }

    @objc func quitApp() {
        viewModel.showAllApps()
        NSApp.terminate(nil)
    }
}
