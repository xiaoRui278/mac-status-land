// MacStatusLand/MacStatusLand/ViewModels/MenuBarViewModel.swift

import Foundation
import SwiftUI
import AppKit

/// 菜单栏视图模型
@available(macOS 14.0, *)
@Observable
class MenuBarViewModel {
    // MARK: - 状态
    
    var icons: [IconItem] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    
    // MARK: - 服务依赖
    
    private let accessibilityService = AccessibilityService.shared
    private let settingsService = SettingsService.shared
    private let cacheService = IconCacheService.shared
    
    // MARK: - 计算属性
    
    var filteredIcons: [IconItem] {
        let visibleIcons = icons.filter { !$0.isHidden }
        
        if searchText.isEmpty {
            return visibleIcons
        }
        
        return visibleIcons.filter {
            $0.appName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var pinnedIcons: [IconItem] {
        filteredIcons.filter { $0.isPinned }
    }
    
    var unpinnedIcons: [IconItem] {
        filteredIcons.filter { !$0.isPinned }
    }
    
    // MARK: - 初始化
    
    init() {}
    
    // MARK: - 图标发现
    
    func discoverIcons() async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        defer { isLoading = false }
        
        let rawIcons = accessibilityService.getSystemStatusBarIcons()
        
        var items = rawIcons.map { raw -> IconItem in
            let bundleID = raw.identifier ?? "unknown.\(raw.appName)"
            var item = IconItem(
                id: bundleID,
                appName: raw.appName,
                bundleIdentifier: bundleID,
                category: IconCategory.classify(bundleIdentifier: bundleID)
            )

            item.isPinned = settingsService.pinnedIcons.contains(item.id)
            item.isHidden = settingsService.hiddenIcons.contains(item.id)

            item.axElement = raw.element
            if let image = raw.image {
                item.iconImage = image
                cacheService.set(element: raw.element, image: image, for: item.id)
            }

            // 记录真实的 app bundle ID + PID，用于退出等操作
            item.appBundleIdentifier = raw.appBundleIdentifier
            item.appPID = raw.appPID

            return item
        }
        
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.appName.localizedCompare(rhs.appName) == .orderedAscending
        }
        
        icons = items
    }
    
    // MARK: - 图标操作
    
    @discardableResult
    func clickIcon(_ icon: IconItem) -> Bool {
        let rawIcons = accessibilityService.getSystemStatusBarIcons()
        
        guard let rawIcon = rawIcons.first(where: { 
            ($0.identifier ?? "unknown.\($0.appName)") == icon.id 
        }) else {
            errorMessage = "无法找到图标"
            showError = true
            return false
        }
        
        let success = accessibilityService.performAction(rawIcon)
        
        if success {
            if let index = icons.firstIndex(where: { $0.id == icon.id }) {
                icons[index].lastUsed = Date()
            }
        } else {
            errorMessage = "点击失败"
            showError = true
        }
        
        return success
    }
    
    func togglePin(_ icon: IconItem) {
        if let index = icons.firstIndex(where: { $0.id == icon.id }) {
            icons[index].isPinned.toggle()
            
            if icons[index].isPinned {
                settingsService.pinnedIcons.append(icon.id)
            } else {
                settingsService.pinnedIcons.removeAll { $0 == icon.id }
            }
            
            sortIcons()
        }
    }
    
    func hideIcon(_ icon: IconItem) {
        if let index = icons.firstIndex(where: { $0.id == icon.id }) {
            icons[index].isHidden = true
            settingsService.hiddenIcons.insert(icon.id)
        }
    }
    
    func restoreIcon(_ bundleIdentifier: String) {
        settingsService.hiddenIcons.remove(bundleIdentifier)

        if let index = icons.firstIndex(where: { $0.id == bundleIdentifier }) {
            icons[index].isHidden = false
        }
    }

    // MARK: - 退出应用

    /// 退出单个图标对应的 app
    /// - Parameters:
    ///   - icon: 目标图标
    ///   - force: true = forceTerminate（丢弃未保存数据），false = terminate（走 app 自己的退出流程）
    func quitApp(_ icon: IconItem, force: Bool) {
        let apps = runningApps(for: icon)
        // 系统 app 兜底保护
        let killable = apps.filter { !($0.bundleIdentifier?.hasPrefix("com.apple.") ?? false) }
        guard !killable.isEmpty else {
            print("⚠️ quitApp: no killable target for \(icon.appName)")
            return
        }

        for app in killable {
            let ok = force ? app.forceTerminate() : app.terminate()
            print("\(ok ? "✅" : "❌") \(force ? "forceTerminate" : "terminate") \(app.bundleIdentifier ?? "?") pid=\(app.processIdentifier)")
        }

        // 延迟刷新，等待 app 真正退出
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await self?.refresh()
        }
    }

    /// 强制退出所有可见的非系统 app
    /// - Returns: 实际被终止的图标数
    @discardableResult
    func forceQuitAll() -> Int {
        let targets = quitAllTargets
        var killedCount = 0
        for icon in targets {
            let apps = runningApps(for: icon).filter { !($0.bundleIdentifier?.hasPrefix("com.apple.") ?? false) }
            apps.forEach { $0.forceTerminate() }
            if !apps.isEmpty { killedCount += 1 }
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await self?.refresh()
        }

        return killedCount
    }

    /// 全部退出的目标集合（用于弹窗预览）
    var quitAllTargets: [IconItem] {
        // 按 app bundle ID 去重，同一 app 多个图标只算一个
        var seen: Set<String> = []
        var result: [IconItem] = []
        for icon in icons where !icon.isHidden {
            let bid = icon.appBundleIdentifier ?? ""
            if bid.isEmpty || bid.hasPrefix("com.apple.") { continue }
            if seen.insert(bid).inserted {
                result.append(icon)
            }
        }
        return result
    }

    /// 解析图标对应的运行中 app：优先按 bundle ID，兜底按 PID
    private func runningApps(for icon: IconItem) -> [NSRunningApplication] {
        if let bid = icon.appBundleIdentifier, !bid.isEmpty {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
            if !apps.isEmpty { return apps }
        }
        if let pid = icon.appPID, let app = NSRunningApplication(processIdentifier: pid) {
            return [app]
        }
        return []
    }
    
    // MARK: - 排序
    
    private func sortIcons() {
        icons.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.appName.localizedCompare(rhs.appName) == .orderedAscending
        }
    }
    
    // MARK: - 刷新
    
    func refresh() async {
        cacheService.invalidateAll()
        await discoverIcons()
    }
}
