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

        // Auto-open popover on first launch so user sees app is running
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self,
                  let button = self.statusItem?.button else { return }
            // Check if this is the first launch (no persisted settings yet)
            // Always open on fresh launch to help new users discover the app
            if !SettingsService.shared.hasCompletedFirstLaunch {
                self.showPopover(button: button)
                SettingsService.shared.hasCompletedFirstLaunch = true
            }
        }
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

            // 启动占位服务（占位符会在 startObserving 内部创建，位于主图标左侧）
            PlaceholderService.shared.startObserving(mainButton: button)
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
        
        // 注册全局快捷键
        if let hotkey = SettingsService.shared.globalHotkey {
            HotkeyService.shared.register(
                keyCode: hotkey.keyCode,
                modifiers: hotkey.modifierFlags
            ) { [weak self] in
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
        
        // 监听快捷键设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        // Check for right click if event available
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        // Default: left click toggles popover
        showPopover(button: button)
    }
    
    private func showPopover(button: NSStatusBarButton) {
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 每次打开弹出框都刷新图标，保证最新状态
            NotificationCenter.default.post(name: .popoverDidOpen, object: nil)
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
    
    @objc private func hotkeyDidChange() {
        if let hotkey = SettingsService.shared.globalHotkey {
            HotkeyService.shared.register(
                keyCode: hotkey.keyCode,
                modifiers: hotkey.modifierFlags
            ) { [weak self] in
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        } else {
            HotkeyService.shared.unregister()
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let popoverDidOpen = Notification.Name("popoverDidOpen")
}
