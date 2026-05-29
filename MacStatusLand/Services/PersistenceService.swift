import Foundation

class PersistenceService {
    
    private let settingsKey = "MacStatusLandSettings"
    private let appsKey = "MacStatusLandApps"
    
    // MARK: - 设置
    
    func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    func saveSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
    
    // MARK: - 应用列表
    
    func loadApps() -> [MenuBarApp] {
        guard let data = UserDefaults.standard.data(forKey: appsKey),
              let apps = try? JSONDecoder().decode([MenuBarApp].self, from: data) else {
            return []
        }
        return apps
    }
    
    func saveApps(_ apps: [MenuBarApp]) {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        UserDefaults.standard.set(data, forKey: appsKey)
    }
    
    // MARK: - 单个应用更新
    
    func updateApp(_ app: MenuBarApp) {
        var apps = loadApps()
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index] = app
        } else {
            apps.append(app)
        }
        saveApps(apps)
    }
    
    func removeApp(identifier: String) {
        var apps = loadApps()
        apps.removeAll { $0.id == identifier }
        saveApps(apps)
    }
    
    // MARK: - 截图持久化
    
    func saveScreenshot(_ data: Data, for bundleIdentifier: String) throws {
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(bundleIdentifier).png")
        try data.write(to: fileURL)
    }
    
    func loadScreenshot(for bundleIdentifier: String) -> Data? {
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(bundleIdentifier).png")
        return try? Data(contentsOf: fileURL)
    }
    
    private func getCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("MacStatusLand/icon-cache")
        
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        return cacheDir
    }
}
