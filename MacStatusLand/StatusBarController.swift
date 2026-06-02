import AppKit
import SwiftUI

@available(macOS 14.0, *)
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "MacStatusLand")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.animates = true

        let hostingView = NSHostingView(rootView: MenuBarPopoverView())
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView

        self.popover = popover
        
        // 监听应用失焦
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidDeactivate),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button,
              let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            // Touch ID 锁定检查（仅在显示时）
            if SettingsService.shared.enableTouchIDLock && popover?.isShown != true {
                Task {
                    do {
                        let authenticated = try await TouchIDService.shared.authenticate(
                            reason: "解锁 MacStatusLand"
                        )
                        
                        if authenticated {
                            await MainActor.run {
                                showPopover(button: button)
                            }
                        }
                    } catch {
                        // 认证失败，不显示
                    }
                }
                return
            }
            
            showPopover(button: button)
        }
    }
    
    private func showPopover(button: NSStatusBarButton) {
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "settings_menu".localized(), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "quit_menu".localized(), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func openSettings() {
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        NSApp.setActivationPolicy(.regular)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacStatusLand 设置"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        window.isReleasedWhenClosed = false
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        settingsWindow = window
    }
    
    @objc private func settingsWindowWillClose() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: settingsWindow
        )
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc private func appDidDeactivate() {
        guard SettingsService.shared.autoCloseOnFocusLoss else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
