import Foundation
import AppKit

class IconDiscoveryService {
    
    private var discoveredApps: [MenuBarApp] = []
    
    func discoverMenuBarApps() -> [MenuBarApp] {
        let items = AccessibilityService.getStatusBarItems()
        var apps: [MenuBarApp] = []
        var seenBundleIds: Set<String> = []
        
        for (index, item) in items.enumerated() {
            let bundleId = AccessibilityService.getElementBundleIdentifier(item)
            let title = AccessibilityService.getElementTitle(item)
            let position = AccessibilityService.getElementPosition(item)
            let size = AccessibilityService.getElementSize(item)
            
            guard let bundleId = bundleId, let position = position, let size = size else {
                continue
            }
            
            if seenBundleIds.contains(bundleId) {
                continue
            }
            
            if isSystemIcon(bundleIdentifier: bundleId) {
                print("Item \(index): \(title ?? "nil") -> Skipped system icon")
                continue
            }
            
            if size.width == 0 || size.height == 0 {
                continue
            }
            
            seenBundleIds.insert(bundleId)
            let displayName = getAppName(bundleIdentifier: bundleId) ?? title ?? bundleId
            
            var app = MenuBarApp(
                bundleIdentifier: bundleId,
                displayName: displayName
            )
            app.originalPosition = position
            
            apps.append(app)
            print("Item \(index): \(title ?? "nil") -> Added \(displayName)")
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
        let items = AccessibilityService.getStatusBarItems()
        return items.first { item in
            AccessibilityService.getElementBundleIdentifier(item) == bundleIdentifier
        }
    }
    
    func getDiscoveredApps() -> [MenuBarApp] {
        return discoveredApps
    }
}
