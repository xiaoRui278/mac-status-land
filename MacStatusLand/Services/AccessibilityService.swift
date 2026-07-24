import Foundation
import AppKit
import CoreGraphics

class AccessibilityService {
    
    static let shared = AccessibilityService()
    
    private init() {}
    
    // MARK: - Permission Check
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - System Status Bar Access
    
    /// 异步发现状态栏图标
    func discoverStatusBarIcons() async -> [StatusBarIcon] {
        await Task.detached {
            self.getSystemStatusBarIcons()
        }.value
    }
    
    func getSystemStatusBarIcons() -> [StatusBarIcon] {
        guard checkAccessibilityPermission() else {
            print("❌ Accessibility permission not granted")
            return []
        }
        
        var allIcons: [StatusBarIcon] = []
        let apps = NSWorkspace.shared.runningApplications
        let ownBundleID = Bundle.main.bundleIdentifier
        let ownAppName = "MacStatusLand"

        for app in apps {
            guard let appName = app.localizedName else { continue }

            // 排除自己：bundleID 匹配 或者 名称匹配，都跳过
            var isSelf = false
            if let own = ownBundleID, let bundleID = app.bundleIdentifier, bundleID == own {
                isSelf = true
            }
            if appName == ownAppName {
                isSelf = true
            }
            if isSelf {
                continue
            }

            if !SettingsService.shared.showSystemApps {
                if let bundleID = app.bundleIdentifier, bundleID.hasPrefix("com.apple.") {
                    continue
                }
            }

            let appIcon = app.icon

            let pid = app.processIdentifier
            let appBundleID = app.bundleIdentifier
            let appRef = AXUIElementCreateApplication(pid)

            // 只获取 AXExtrasMenuBar（状态栏图标）
            var extrasMenuBar: AnyObject?
            let extrasResult = AXUIElementCopyAttributeValue(appRef, "AXExtrasMenuBar" as CFString, &extrasMenuBar)

            guard extrasResult == .success, let extrasElement = extrasMenuBar else {
                continue
            }

            guard CFGetTypeID(extrasElement) == AXUIElementGetTypeID() else {
                print("⚠️ Invalid AXUIElement type for extrasMenuBar")
                continue
            }
            let menuBar = unsafeBitCast(extrasElement, to: AXUIElement.self)
            let icons = extractIcons(from: menuBar, appName: appName, appIcon: appIcon, appBundleID: appBundleID, appPID: pid)
            if !icons.isEmpty {
                print("  \(appName): \(icons.count) icons")
                allIcons.append(contentsOf: icons)
            }
        }
        
        print("✅ Total icons found: \(allIcons.count)")
        return allIcons
    }
    
    // MARK: - Private Helpers
    
    private func getSystemUIServerPID() -> pid_t? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        let statusBarHosts = [
            "com.apple.systemuiserver",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui"
        ]
        
        for bundleID in statusBarHosts {
            for app in runningApps {
                if app.bundleIdentifier?.lowercased() == bundleID {
                    print("  Found \(app.localizedName ?? bundleID): \(app.processIdentifier)")
                    return app.processIdentifier
                }
            }
        }
        
        print("  ❌ No status bar host process found")
        return nil
    }
    
    private func extractIcons(from menuBar: AXUIElement, appName: String = "", appIcon: NSImage? = nil, appBundleID: String? = nil, appPID: pid_t? = nil) -> [StatusBarIcon] {
        var icons: [StatusBarIcon] = []
        let ownBundleID = Bundle.main.bundleIdentifier
        var children: AnyObject?
        let result = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &children)

        guard result == .success, let childrenArray = children as? [AXUIElement] else {
            return []
        }

        for (index, child) in childrenArray.enumerated() {
            // 第二层过滤：图标所属 app bundle ID 就是自己也跳过
            if let appBundleID = appBundleID, appBundleID == ownBundleID {
                continue
            }
            if let icon = parseStatusBarIcon(from: child, at: index, appName: appName, appIcon: appIcon, appBundleID: appBundleID, appPID: appPID) {
                // 修复BUG: 原来 hasAppName 总是 true，导致空容器也被直接添加，永远不会去子层找实际图标
                // appName 总是存在，不算作图标自身内容
                let hasTitle = !(icon.title.isEmpty)
                let hasDescription = icon.description != nil && !icon.description!.isEmpty
                let hasIdentifier = icon.identifier != nil && !icon.identifier!.isEmpty

                if hasTitle || hasDescription || hasIdentifier {
                    icons.append(icon)
                } else {
                    // 图标自身没内容 → 说明是容器，检查一层子元素
                    var childChildren: AnyObject?
                    let childResult = AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &childChildren)
                    if childResult == .success, let childChildrenArray = childChildren as? [AXUIElement] {
                        var found = false
                        for (childIndex, grandChild) in childChildrenArray.enumerated() {
                            if let childIcon = parseStatusBarIcon(from: grandChild, at: index * 100 + childIndex, appName: appName, appIcon: appIcon, appBundleID: appBundleID, appPID: appPID) {
                                let childHasTitle = !(childIcon.title.isEmpty)
                                let childHasDesc = childIcon.description != nil && !childIcon.description!.isEmpty
                                let childHasId = childIcon.identifier != nil && !childIcon.identifier!.isEmpty
                                if childHasTitle || childHasDesc || childHasId {
                                    icons.append(childIcon)
                                    found = true
                                    break // 只加第一个找到的有效图标
                                }
                            }
                        }
                        // 如果容器里没找到，保持数量不变兜底加容器
                        if !found {
                            icons.append(icon)
                        }
                    } else {
                        // 没有子元素，加容器兜底
                        icons.append(icon)
                    }
                }
            }
        }

        // 保持输出数量和原顶级孩子一致 → 布局尺寸不变 → popover不会闪
        return icons
    }

    private func parseStatusBarIcon(from element: AXUIElement, at index: Int, appName: String = "", appIcon: NSImage? = nil, appBundleID: String? = nil, appPID: pid_t? = nil) -> StatusBarIcon? {
        var title: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let titleString = title as? String
        
        var description: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        let descriptionString = description as? String
        
        var identifier: AnyObject?
        AXUIElementCopyAttributeValue(element, "AXIdentifier" as CFString, &identifier)
        let identifierString = identifier as? String
        
        var image: NSImage?
        var imageRef: AnyObject?
        let imageResult = AXUIElementCopyAttributeValue(element, "AXImage" as CFString, &imageRef)
        if imageResult == .success, let imageObj = imageRef,
           CFGetTypeID(imageObj) == CGImage.typeID {
            let img = unsafeBitCast(imageObj, to: CGImage.self)
            image = NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))
        } else if imageResult == .success {
            print("⚠️ Invalid CGImage type for AXImage attribute")
        }
        
        if image == nil {
            image = appIcon
        }
        
        return StatusBarIcon(
            index: index,
            title: titleString ?? "",
            description: descriptionString ?? titleString,
            element: element,
            identifier: identifierString,
            appName: appName,
            image: image,
            appBundleIdentifier: appBundleID,
            appPID: appPID
        )
    }
    
    // MARK: - Icon Interaction
    
    func performAction(_ icon: StatusBarIcon) -> Bool {
        // Always click the icon first (for apps that just need menu toggle)
        var pressSuccess = false
        let pressResult = AXUIElementPerformAction(
            icon.element,
            kAXPressAction as CFString
        )
        if pressResult == .success {
            pressSuccess = true
            print("✅ Action performed (kAXPressAction) for \(icon.displayTitle)")
        }

        // Always open/bring main application window
        // User expects clicking icon here opens main app, not just menu
        var openSuccess = false

        if let pid = icon.appPID, let app = NSRunningApplication(processIdentifier: pid) {
            // First try activate current process, raises all windows
            openSuccess = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            print("👉 Activated app \(icon.appName) pid=\(pid), success=\(openSuccess)")

            // Raise all windows via accessibility
            let appRef = AXUIElementCreateApplication(pid)
            var windows: AnyObject?
            let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windows)
            var windowCount = 0
            if result == .success, let windowArray = windows as? [AXUIElement] {
                windowCount = windowArray.count
                for window in windowArray {
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                }
                print("👉 Raised \(windowCount) windows for \(icon.appName)")
            }

            // 判断是否有"真正的普通窗口"（非菜单/悬浮）
            // AX 里的 windowCount 会把状态栏 popover、隐藏后台窗口都算进去，导致
            // 像 WPS Office Service 这种明明没有主界面却 count=1 的情况不进兜底分支。
            // 用 CGWindowList 过滤 layer=0（普通应用窗口）来更准确判断。
            let hasNormalWindow = appHasNormalWindow(pid: pid)
            print("👉 hasNormalWindow=\(hasNormalWindow) for \(icon.appName)")

            // If no visible normal window, this is probably a helper/login item OR a menu-bar-only app
            if !hasNormalWindow {
                if let app = NSRunningApplication(processIdentifier: pid), let bundleURL = app.bundleURL {
                    let path = bundleURL.path
                    print("👉 No visible window. Trying to open main window from: \(path)")

                    // Helper 场景：路径含 /Library/LoginItems/ 或 /Contents/Library/ → 向上查找主 .app
                    let isHelper = path.contains("/Library/LoginItems/") || path.contains("/Contents/")
                    if isHelper {
                        var components = path.components(separatedBy: "/")
                        if !components.isEmpty { components.removeLast() }
                        while !components.isEmpty && !(components.last?.hasSuffix(".app") ?? false) {
                            components.removeLast()
                        }
                        if let last = components.last, last.hasSuffix(".app") {
                            let mainAppPath = components.joined(separator: "/")
                            if FileManager.default.fileExists(atPath: mainAppPath) {
                                let mainAppURL = URL(fileURLWithPath: mainAppPath)
                                // 用 openApplication 而非 open，触发 default launch，
                                // 对已运行 app（如 Docker）会请求它显示主窗口
                                let config = NSWorkspace.OpenConfiguration()
                                config.activates = true
                                NSWorkspace.shared.openApplication(at: mainAppURL, configuration: config) { _, error in
                                    if let error = error {
                                        print("⚠️ openApplication failed for helper's main app \(mainAppPath): \(error)")
                                    } else {
                                        print("👉 openApplication succeeded for helper's main app \(mainAppPath)")
                                    }
                                }
                                // 补发 reopen Apple Event，模拟双击 Dock 图标语义
                                // openApplication 对已运行 app 只激活不开窗（如 Docker Electron）
                                if let mainApp = runningApp(for: mainAppURL) {
                                    sendReopenEvent(to: mainApp.processIdentifier)
                                }
                                openSuccess = true
                            }
                        }
                    } else {
                        // 菜单栏 app 自身：NSWorkspace.open 请求系统调起主窗口
                        // 使用 openApplication 显式带 activate 语义，效果类似双击 Dock 图标
                        let config = NSWorkspace.OpenConfiguration()
                        config.activates = true
                        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, error in
                            if let error = error {
                                print("⚠️ openApplication failed for \(path): \(error)")
                            } else {
                                print("👉 openApplication succeeded for \(path)")
                            }
                        }
                        // 补发 reopen（rapp）Apple Event，语义 = 双击 Dock 图标
                        sendReopenEvent(to: pid)
                        openSuccess = true
                    }
                }
            }
        }

        // If activation didn't work or no pid, try open by bundleID
        if !openSuccess, let bundleID = icon.appBundleIdentifier {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                // Skip opening login items (they just helpers, not main app) - already handled above
                let path = url.path
                if !path.contains("/Library/LoginItems/") {
                    openSuccess = NSWorkspace.shared.open(url)
                    print("👉 Opened app \(icon.appName) via NSWorkspace, url=\(path), success=\(openSuccess)")
                }
            }
        }

        // If either click or open succeeded, count as success
        let overallSuccess = pressSuccess || openSuccess
        return overallSuccess
    }

    /// 检查指定进程是否有真正的"普通应用窗口"（layer=0）
    /// 用 CGWindowListCopyWindowInfo，过滤：
    /// - kCGWindowLayer == 0（普通窗口层；菜单、Dock、状态栏 popover 等 layer > 0）
    /// - kCGWindowOwnerPID == pid
    /// - 有非零尺寸
    private func appHasNormalWindow(pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            if let bounds = info[kCGWindowBounds as String] as? [String: Any],
               let w = bounds["Width"] as? CGFloat, let h = bounds["Height"] as? CGFloat,
               w > 50, h > 50 {
                return true
            }
        }
        return false
    }

    /// 查找 bundleURL 对应的正在运行的 NSRunningApplication
    private func runningApp(for bundleURL: URL) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first { $0.bundleURL == bundleURL }
    }

    /// 向目标进程发送 reopen (`rapp`) Apple Event，等效双击 Dock 图标
    /// 对 Electron / Chromium 类应用尤为关键：openApplication 只激活不开窗，reopen 才会显示主窗口
    private func sendReopenEvent(to pid: pid_t) {
        var pidVar = pid
        guard let target = NSAppleEventDescriptor(
            descriptorType: typeKernelProcessID,
            bytes: &pidVar,
            length: MemoryLayout.size(ofValue: pidVar)
        ) else {
            print("⚠️ Failed to build target descriptor for reopen pid=\(pid)")
            return
        }
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        var reply = AppleEvent()
        var eventCopy = event.aeDesc!.pointee
        let sendResult = AESendMessage(&eventCopy, &reply, AESendMode(kAENoReply), 1)
        if sendResult == noErr {
            print("👉 Sent reopen event to pid=\(pid)")
        } else {
            print("⚠️ Reopen event failed pid=\(pid) OSStatus=\(sendResult)")
        }
        AEDisposeDesc(&reply)
    }
}

// MARK: - Data Model

struct StatusBarIcon: Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let description: String?
    let element: AXUIElement
    let identifier: String?
    let appName: String
    let image: NSImage?
    /// 拥有此图标的 app 的真实 bundle identifier（用于 terminate 等操作）
    let appBundleIdentifier: String?
    /// 拥有此图标的 app 的 PID（bundle ID 缺失时的兜底）
    let appPID: pid_t?
    
    var displayTitle: String {
        return description ?? title
    }
    
    var sfSymbol: String? {
        guard let id = identifier else { return nil }
        switch id {
        case "com.apple.menuextra.battery": return "battery.100"
        case "com.apple.menuextra.clock": return "clock"
        case "com.apple.menuextra.wifi": return "wifi"
        case "com.apple.menuextra.controlcenter": return "controlcenter"
        case "com.apple.menuextra.bluetooth": return "bluetooth"
        case "com.apple.menuextra.sound": return "speaker.wave.2"
        case "com.apple.menuextra.airport": return "airplayaudio"
        default: return nil
        }
    }
}