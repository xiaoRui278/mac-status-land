// MacStatusLand/MacStatusLand/Services/PersistenceService.swift

import Foundation

/// 持久化服务
class PersistenceService {
    static let shared = PersistenceService()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// 应用支持目录
    private var appSupportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacStatusLand")
    }
    
    /// 设置文件路径
    private var settingsURL: URL {
        appSupportDirectory.appendingPathComponent("settings.json")
    }
    
    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        ensureDirectoryExists()
    }
    
    // MARK: - 目录管理
    
    /// 确保目录存在
    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - 设置读写
    
    /// 加载设置
    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    /// 保存设置
    func saveSettings(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }
    
    // MARK: - 便捷方法
    
    /// 更新设置
    func updateSettings(_ block: (inout AppSettings) -> Void) {
        var settings = loadSettings()
        block(&settings)
        saveSettings(settings)
    }
    
    /// 重置设置
    func resetSettings() {
        try? fileManager.removeItem(at: settingsURL)
    }
}
