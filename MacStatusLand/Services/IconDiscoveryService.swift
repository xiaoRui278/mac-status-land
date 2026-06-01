import Foundation

class IconDiscoveryService {
    
    static let shared = IconDiscoveryService()
    
    private let accessibilityService = AccessibilityService.shared
    
    private init() {}
    
    func discoverStatusBarIcons() -> [StatusBarIcon] {
        return accessibilityService.getSystemStatusBarIcons()
    }
    
    func performAction(_ icon: StatusBarIcon) -> Bool {
        return accessibilityService.performAction(icon)
    }
}