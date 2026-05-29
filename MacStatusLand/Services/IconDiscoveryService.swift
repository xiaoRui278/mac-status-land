import Foundation
import AppKit

class IconDiscoveryService {
    
    private var discoveredApps: [MenuBarApp] = []
    
    func discoverMenuBarApps() -> [MenuBarApp] {
        let items = AccessibilityService.getMenuBarItems()
        var apps: [MenuBarApp] = []
        
        for item in items {
            guard let bundleId = AccessibilityService.getElementBundleIdentifier(item) else {
                continue
            }
            
            if isSystemIcon(bundleIdentifier: bundleId) {
                continue
            }
            
            guard let position = AccessibilityService.getElementPosition(item),
                  let _ = AccessibilityService.getElementSize(item) else {
                continue
            }
            
            let displayName = getAppName(bundleIdentifier: bundleId) ?? bundleId
            
            var app = MenuBarApp(
                bundleIdentifier: bundleId,
                displayName: displayName
            )
            app.originalPosition = position
            
            apps.append(app)
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
