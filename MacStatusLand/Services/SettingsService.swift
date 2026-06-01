import Foundation
import SwiftUI

class SettingsService: ObservableObject {
    static let shared = SettingsService()
    
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("autoRefreshInterval") var autoRefreshInterval: Int = 0
    @AppStorage("showSystemApps") var showSystemApps: Bool = false
    @AppStorage("appLanguage") var appLanguage: String = "zh"
    
    private init() {}
    
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
