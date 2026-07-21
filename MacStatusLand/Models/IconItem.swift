// MacStatusLand/MacStatusLand/Models/IconItem.swift

import Foundation
import AppKit

/// 图标数据模型
struct IconItem: Identifiable, Codable, Equatable {
    /// 唯一标识 (bundleIdentifier)
    let id: String
    
    /// 应用名称
    let appName: String
    
    /// Bundle Identifier
    let bundleIdentifier: String
    
    /// 是否置顶
    var isPinned: Bool = false
    
    /// 是否隐藏
    var isHidden: Bool = false

    /// 最后使用时间
    var lastUsed: Date?

    /// 图标分类
    var category: IconCategory = .thirdParty

    // MARK: - 运行时属性（不序列化）

    /// 缓存的 AXUIElement 引用
    var axElement: AXUIElement?

    /// 缓存的图标图像
    var iconImage: NSImage?

    /// 拥有此图标的 app 的真实 bundle identifier（区别于 `bundleIdentifier` — 后者存的是 AXIdentifier 用作 UI key）
    var appBundleIdentifier: String?

    /// 拥有此图标的 app 的 PID（bundle ID 缺失时兜底）
    var appPID: pid_t?
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, appName, bundleIdentifier, isPinned, isHidden, lastUsed, category
    }
    
    // MARK: - Equatable
    
    static func == (lhs: IconItem, rhs: IconItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.appName == rhs.appName &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.isPinned == rhs.isPinned &&
        lhs.isHidden == rhs.isHidden
    }
}

/// 图标分类
enum IconCategory: String, Codable, CaseIterable {
    case system
    case network
    case media
    case utility
    case thirdParty

    var displayName: String {
        switch self {
        case .system: return "category_system".localized()
        case .network: return "category_network".localized()
        case .media: return "category_media".localized()
        case .utility: return "category_utility".localized()
        case .thirdParty: return "category_third_party".localized()
        }
    }

    /// 根据 bundleIdentifier 自动分类
    static func classify(bundleIdentifier: String) -> IconCategory {
        let id = bundleIdentifier.lowercased()

        // 网络类
        if id.contains("wifi") ||
           id.contains("bluetooth") ||
           id.contains("vpn") ||
           id.contains("net") ||
           id.contains("network") ||
           id.contains("proxy") ||
           id.contains("cloud") {
            return .network
        }

        // 媒体类
        if id.contains("music") ||
           id.contains("spotify") ||
           id.contains("podcast") ||
           id.contains("tv") ||
           id.contains("video") ||
           id.contains("audio") ||
           id.contains("player") ||
           id.contains("radio") {
            return .media
        }

        // 工具类
        if id.contains("calendar") ||
           id.contains("clock") ||
           id.contains("calculator") ||
           id.contains("notes") ||
           id.contains("reminder") ||
           id.contains("todo") ||
           id.contains("weather") ||
           id.contains("utils") ||
           id.contains("utility") ||
           id.contains("monitor") ||
           id.contains("stats") ||
           id.contains("bat") ||
           id.contains("cpu") ||
           id.contains("gpu") ||
           id.contains("memory") {
            return .utility
        }

        // 系统类
        if id.hasPrefix("com.apple") {
            return .system
        }

        return .thirdParty
    }
}
