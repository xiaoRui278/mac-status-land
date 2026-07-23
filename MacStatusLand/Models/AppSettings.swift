// MacStatusLand/MacStatusLand/Models/AppSettings.swift

import Foundation

/// 应用设置
struct AppSettings: Codable {
    /// 启动时登录
    var launchAtLogin: Bool = false

    /// 显示系统图标
    var showSystemApps: Bool = false

    /// 应用语言
    var appLanguage: String = "zh"

    /// 已隐藏的图标 (bundleIdentifier 集合)
    var hiddenIcons: Set<String> = []

    /// 已置顶的图标 (有序列表)
    var pinnedIcons: [String] = []

    /// 失焦自动关闭
    var autoCloseOnFocusLoss: Bool = true

    /// Whether user has completed first launch (seen popover)
    var hasCompletedFirstLaunch: Bool = false

    /// 自动隐藏 MacStatusLand 图标左侧所有图标
    var autoHideLeftIcons: Bool = false
}
