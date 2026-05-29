import Foundation
import Combine

class MenuBarViewModel: ObservableObject {
    
    @Published var discoveredApps: [MenuBarApp] = []
    @Published var isLoading: Bool = false
    @Published var showPermissionAlert: Bool = false
    
    private let discoveryService = IconDiscoveryService()
    private let screenshotService = IconScreenshotService()
    private let hidingService = IconHidingService()
    private let persistenceService = PersistenceService()
    
    @Published var settings: AppSettings
    
    init() {
        self.settings = persistenceService.loadSettings()
    }
    
    // MARK: - 初始化
    
    func initialize() {
        checkAccessibilityPermission()
        loadSavedState()
        
        if settings.autoHideOnLaunch {
            hideConfiguredApps()
        }
    }
    
    private func checkAccessibilityPermission() {
        if !AccessibilityService.checkAccessibility(prompt: false) {
            showPermissionAlert = true
        }
    }
    
    private func loadSavedState() {
        let savedApps = persistenceService.loadApps()
        discoveredApps = savedApps.isEmpty ? discoveryService.discoverMenuBarApps() : savedApps
    }
    
    // MARK: - 图标发现
    
    func refreshMenuBarApps() {
        isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.discoveredApps = self.discoveryService.discoverMenuBarApps()
            print("Discovered \(self.discoveredApps.count) apps:")
            for app in self.discoveredApps {
                print("  - \(app.displayName) (\(app.bundleIdentifier))")
            }
            self.isLoading = false
        }
    }
    
    // MARK: - 截图
    
    func captureScreenshots() {
        for app in discoveredApps {
            guard let element = discoveryService.getElement(for: app.bundleIdentifier),
                  let position = AccessibilityService.getElementPosition(element),
                  let size = AccessibilityService.getElementSize(element) else {
                continue
            }
            
            if let image = screenshotService.captureAndCache(
                for: app.bundleIdentifier,
                at: position,
                size: size
            ) {
                if let index = discoveredApps.firstIndex(where: { $0.id == app.id }) {
                    discoveredApps[index].screenshotData = image.tiffRepresentation
                }
            }
        }
        
        persistenceService.saveApps(discoveredApps)
    }
    
    // MARK: - 隐藏/显示
    
    func toggleHide(for app: MenuBarApp) {
        if app.isHidden {
            showApp(app)
        } else {
            hideApp(app)
        }
    }
    
    func hideApp(_ app: MenuBarApp) {
        guard let element = discoveryService.getElement(for: app.bundleIdentifier) else {
            print("Warning: Could not find element for \(app.bundleIdentifier)")
            return
        }
        
        guard let position = AccessibilityService.getElementPosition(element) else {
            print("Warning: Could not get position for \(app.bundleIdentifier)")
            return
        }
        
        guard hidingService.hideIcon(for: app.bundleIdentifier, at: position) else {
            print("Warning: Failed to hide icon for \(app.bundleIdentifier)")
            return
        }
        
        if let index = discoveredApps.firstIndex(where: { $0.id == app.id }) {
            discoveredApps[index].isHidden = true
            discoveredApps[index].originalPosition = position
            persistenceService.updateApp(discoveredApps[index])
        }
    }
    
    func showApp(_ app: MenuBarApp) {
        guard hidingService.showIcon(for: app.bundleIdentifier) else {
            print("Warning: Failed to show icon for \(app.bundleIdentifier)")
            return
        }
        
        if let index = discoveredApps.firstIndex(where: { $0.id == app.id }) {
            discoveredApps[index].isHidden = false
            discoveredApps[index].originalPosition = nil
            persistenceService.updateApp(discoveredApps[index])
        }
    }
    
    func hideConfiguredApps() {
        for app in discoveredApps where settings.hiddenAppIdentifiers.contains(app.bundleIdentifier) {
            hideApp(app)
        }
    }
    
    func showAllApps() {
        hidingService.showAll()
        
        for index in discoveredApps.indices {
            discoveredApps[index].isHidden = false
            discoveredApps[index].originalPosition = nil
        }
        
        persistenceService.saveApps(discoveredApps)
    }
    
    // MARK: - 触发点击
    
    func triggerClick(for app: MenuBarApp) -> Bool {
        guard let element = discoveryService.getElement(for: app.bundleIdentifier) else {
            return false
        }
        
        return AccessibilityService.performClick(element)
    }
    
    // MARK: - 设置
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        persistenceService.saveSettings(settings)
    }
    
    func toggleHiddenApp(_ bundleIdentifier: String) {
        if settings.hiddenAppIdentifiers.contains(bundleIdentifier) {
            settings.hiddenAppIdentifiers.remove(bundleIdentifier)
        } else {
            settings.hiddenAppIdentifiers.insert(bundleIdentifier)
        }
        persistenceService.saveSettings(settings)
    }
    
    func isAppHiddenByDefault(_ bundleIdentifier: String) -> Bool {
        return settings.hiddenAppIdentifiers.contains(bundleIdentifier)
    }
}
