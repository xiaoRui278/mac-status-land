import Foundation
import AppKit

class IconDiscoveryService {
    
    private var discoveredApps: [MenuBarApp] = []
    
    func discoverMenuBarApps() -> [MenuBarApp] {
        let items = AccessibilityService.getMenuBarItems()
        var apps: [MenuBarApp] = []
        
        for (index, item) in items.enumerated() {
            let bundleId = AccessibilityService.getElementBundleIdentifier(item)
            let title = AccessibilityService.getElementTitle(item)
            let label = AccessibilityService.getElementStatusLabel(item)
            let position = AccessibilityService.getElementPosition(item)
            let size = AccessibilityService.getElementSize(item)
            
            print("Item \(index): bundleId=\(bundleId ?? "nil"), title=\(title ?? "nil"), label=\(label ?? "nil"), pos=\(position?.debugDescription ?? "nil"), size=\(size?.debugDescription ?? "nil")")
            
            guard let bundleId = bundleId else {
                print("  -> Skipped: no bundleId")
                continue
            }
            
            if isSystemIcon(bundleIdentifier: bundleId) {
                print("  -> Skipped: system icon")
                continue
            }
            
            guard let position = position, let _ = size else {
                print("  -> Skipped: no position/size")
                continue
            }
            
            let displayName = getAppName(bundleIdentifier: bundleId) ?? bundleId
            
            var app = MenuBarApp(
                bundleIdentifier: bundleId,
                displayName: displayName
            )
            app.originalPosition = position
            
            apps.append(app)
            print("  -> Added: \(displayName)")
        }
        
        discoveredApps = apps
        return apps
    }
    
    private func isSystemIcon(bundleIdentifier: String) -> Bool {
        return bundleIdentifier.hasPrefix("com.apple.")
    }
    
    private func getAppName(bundleIdentifier: String) -> String? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let bundle = Bundle(url: url)
            return bundle?.infoDictionary?["CFBundleName"] as? String
        }
        return nil
    }
    
    func getElement(for bundleIdentifier: String) -> AXUIElement? {
        let items = AccessibilityService.getMenuBarItems()
        return items.first { item in
            AccessibilityService.getElementBundleIdentifier(item) == bundleIdentifier
        }
    }
    
    func getDiscoveredApps() -> [MenuBarApp] {
        return discoveredApps
    }
}
