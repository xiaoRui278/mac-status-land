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
    
    func getSystemStatusBarIcons() -> [StatusBarIcon] {
        guard checkAccessibilityPermission() else {
            print("❌ Accessibility permission not granted")
            return []
        }
        
        var allIcons: [StatusBarIcon] = []
        let apps = NSWorkspace.shared.runningApplications
        
        for app in apps {
            guard let appName = app.localizedName else { continue }
            
            if let bundleID = app.bundleIdentifier, bundleID.hasPrefix("com.apple.") {
                continue
            }
            
            let pid = app.processIdentifier
            let appRef = AXUIElementCreateApplication(pid)
            
            // 只获取 AXExtrasMenuBar（状态栏图标）
            var extrasMenuBar: AnyObject?
            let extrasResult = AXUIElementCopyAttributeValue(appRef, "AXExtrasMenuBar" as CFString, &extrasMenuBar)
            
            guard extrasResult == .success, let extrasElement = extrasMenuBar else {
                continue
            }
            
            let menuBar = extrasElement as! AXUIElement
            let icons = extractIcons(from: menuBar, appName: appName)
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
    
    private func extractIcons(from menuBar: AXUIElement, appName: String = "") -> [StatusBarIcon] {
        var children: AnyObject?
        let result = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childrenArray = children as? [AXUIElement] else {
            return []
        }
        
        var icons: [StatusBarIcon] = []
        
        for (index, child) in childrenArray.enumerated() {
            if let icon = parseStatusBarIcon(from: child, at: index, appName: appName) {
                let hasTitle = !(icon.title.isEmpty)
                let hasDescription = icon.description != nil && !icon.description!.isEmpty
                let hasIdentifier = icon.identifier != nil && !icon.identifier!.isEmpty
                let hasAppName = !(icon.appName.isEmpty)
                if hasTitle || hasDescription || hasIdentifier || hasAppName {
                    icons.append(icon)
                }
            }
        }
        
        return icons
    }
    
    private func parseStatusBarIcon(from element: AXUIElement, at index: Int, appName: String = "") -> StatusBarIcon? {
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
        if imageResult == .success {
            let cgImage = imageRef as! CGImage
            image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        
        return StatusBarIcon(
            index: index,
            title: titleString ?? "",
            description: descriptionString ?? titleString,
            element: element,
            identifier: identifierString,
            appName: appName,
            image: image
        )
    }
    
    // MARK: - Icon Interaction
    
    func performAction(_ icon: StatusBarIcon) -> Bool {
        let result = AXUIElementPerformAction(
            icon.element,
            kAXPressAction as CFString
        )
        
        if result == .success {
            print("✅ Action performed for \(icon.displayTitle)")
        } else {
            print("❌ Action failed for \(icon.displayTitle): \(result.rawValue)")
        }
        
        return result == .success
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