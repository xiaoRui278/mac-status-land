// MacStatusLand/MacStatusLand/Services/SettingsService.swift

import Foundation
import SwiftUI

/// 设置服务
class SettingsService: ObservableObject {
    static let shared = SettingsService()
    
    private let persistence = PersistenceService.shared
    
    /// 当前设置
    @Published private var settings: AppSettings
    
    private init() {
        self.settings = persistence.loadSettings()
    }
    
    // MARK: - 便捷访问器
    
    var launchAtLogin: Bool {
        get { settings.launchAtLogin }
        set {
            settings.launchAtLogin = newValue
            save()
        }
    }
    
    var autoRefreshInterval: Int {
        get { settings.autoRefreshInterval }
        set {
            settings.autoRefreshInterval = newValue
            save()
        }
    }
    
    var showSystemApps: Bool {
        get { settings.showSystemApps }
        set {
            settings.showSystemApps = newValue
            save()
        }
    }
    
    var appLanguage: String {
        get { settings.appLanguage }
        set {
            settings.appLanguage = newValue
            save()
        }
    }
    
    var hiddenIcons: Set<String> {
        get { settings.hiddenIcons }
        set {
            settings.hiddenIcons = newValue
            save()
        }
    }
    
    var pinnedIcons: [String] {
        get { settings.pinnedIcons }
        set {
            settings.pinnedIcons = newValue
            save()
        }
    }
    
    var presets: [IconPreset] {
        get { settings.presets }
        set {
            settings.presets = newValue
            save()
        }
    }
    
    var globalHotkey: HotkeyConfig? {
        get { settings.globalHotkey }
        set {
            settings.globalHotkey = newValue
            save()
        }
    }
    
    var enableTouchIDLock: Bool {
        get { settings.enableTouchIDLock }
        set {
            settings.enableTouchIDLock = newValue
            save()
        }
    }
    
    var autoCloseOnFocusLoss: Bool {
        get { settings.autoCloseOnFocusLoss }
        set {
            settings.autoCloseOnFocusLoss = newValue
            save()
        }
    }
    
    // MARK: - 保存
    
    private func save() {
        persistence.saveSettings(settings)
    }
    
    // MARK: - 重置
    
    func resetToDefaults() {
        persistence.resetSettings()
        settings = persistence.loadSettings()
    }
    
    // MARK: - UI 辅助
    
    var refreshIntervalOptions: [Int] {
        return [0, 15, 30, 60]
    }
    
    var refreshIntervalLabel: String {
        switch autoRefreshInterval {
        case 0: return "off".localized(appLanguage)
        case 15: return "seconds".localizedFormat(appLanguage, 15)
        case 30: return "seconds".localizedFormat(appLanguage, 30)
        case 60: return "seconds".localizedFormat(appLanguage, 60)
        default: return "off".localized(appLanguage)
        }
    }
    
    var languageOptions: [(value: String, label: String)] {
        return [("zh", "中文"), ("en", "English")]
    }
    
    var currentLanguageLabel: String {
        return appLanguage == "zh" ? "中文" : "English"
    }
}
