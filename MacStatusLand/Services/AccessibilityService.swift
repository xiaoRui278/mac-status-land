import Foundation
import AppKit

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

            // If no windows found, this is probably a helper/login item
            // Try to find main app in parent directory (look up until we find a .app package that is not current helper)
            if windowCount == 0 {
                // Get the helper app's bundle URL from running process
                if let app = NSRunningApplication(processIdentifier: pid), let bundleURL = app.bundleURL {
                    var components = bundleURL.path.components(separatedBy: "/")
                    print("👉 Searching for main app from helper path: \(bundleURL.path)")

                    // Remove helper name first, then keep going up until we find a .app
                    if !components.isEmpty {
                        components.removeLast() // remove helper app name
                    }

                    while !components.isEmpty && !(components.last?.hasSuffix(".app") ?? false) {
                        components.removeLast()
                    }

                    if let last = components.last, last.hasSuffix(".app") {
                        let mainAppPath = components.joined(separator: "/")
                        if FileManager.default.fileExists(atPath: mainAppPath) {
                            let mainAppURL = URL(fileURLWithPath: mainAppPath)
                            openSuccess = NSWorkspace.shared.open(mainAppURL)
                            print("👉 Found main app at \(mainAppPath), opening... success=\(openSuccess)")
                        }
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