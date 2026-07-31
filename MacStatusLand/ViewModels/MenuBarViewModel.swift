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

    // MARK: - 全部退出（inline 二次确认 + 进度）

    /// 第一次点 power：进入 inline 确认态（5s 不点则自动取消）
    var confirmingQuitAll: Bool = false
    /// 确认态倒计时：1.0 → 0.0（5s 归零）
    var quitConfirmFraction: Double = 1.0
    private var quitConfirmTask: Task<Void, Never>?

    /// 进度态：forceTerminate 跑中
    var isQuittingAll: Bool = false
    var quitProgressDone: Int = 0
    var quitProgressTotal: Int = 0

    var quitProgressFraction: Double {
        guard quitProgressTotal > 0 else { return 0 }
        return Double(quitProgressDone) / Double(quitProgressTotal)
    }

    var errorMessage: String?
    var showError: Bool = false
    var hoveredIconId: String?
    var hoveredHeaderId: String?
    var hoveredFooterId: String?
    var hoveredSearchClear: Bool = false
    var pressedIconId: String?  // 按压瞬间短暂置位，iconRow 用来做 scale 反馈
    
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

        var items: [IconItem] = []
        for raw in rawIcons {
            // 每个图标唯一 id：
            // - 如果有 identifier: 使用 identifier + appBundleID 保证唯一性
            // - 如果没有 identifier: 使用 description/title + appName
            let baseId = raw.identifier ?? raw.displayTitle
            let bundlePart = raw.appBundleIdentifier ?? "unknown"
            let uniqueID = "\(bundlePart)_\(baseId)"

            var item = IconItem(
                id: uniqueID,
                appName: raw.appName,
                bundleIdentifier: baseId,
                category: IconCategory.classify(bundleIdentifier: bundlePart)
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

            items.append(item)
        }

        // 最后过滤一遍：排除自身 app
        let ownBundleID = Bundle.main.bundleIdentifier
        items = items.filter { item in
            if let own = ownBundleID, let itemBid = item.appBundleIdentifier, itemBid == own {
                print("🚫 Filtering out self in VM: \(item.appName) \(itemBid)")
                return false
            }
            return true
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
        print("🔍 [MenuBarViewModel] clicking icon: \(icon.appName), id=\(icon.id)")
        let rawIcons = accessibilityService.getSystemStatusBarIcons()
        print("🔍 [MenuBarViewModel] found \(rawIcons.count) total raw icons")

        // Re-generate IDs the same way to match correctly
        for raw in rawIcons {
            let baseId = raw.identifier ?? raw.displayTitle
            let bundlePart = raw.appBundleIdentifier ?? "unknown"
            let uniqueID = "\(bundlePart)_\(baseId)"

            if uniqueID == icon.id {
                print("✅ [MenuBarViewModel] found raw icon, performing action...")
                // 隐藏状态下先临时抬起，让被挤出屏幕的原图标恢复可点击位置
                // 对 popover-only app（Docker/微信 等）尤为关键
                PlaceholderService.shared.performTemporaryReveal { [weak self] in
                    guard let self = self else { return }
                    let success = self.accessibilityService.performAction(raw)
                    print(success ? "✅ [MenuBarViewModel] click succeeded" : "❌ [MenuBarViewModel] click failed")
                    if success {
                        if let index = self.icons.firstIndex(where: { $0.id == icon.id }) {
                            self.icons[index].lastUsed = Date()
                        }
                    } else {
                        self.errorMessage = "点击失败"
                        self.showError = true
                    }
                }
                // 返回 true：抬起 + 触发都是异步的，走乐观策略；真失败时上面回调已 setError
                return true
            }
        }

        print("❌ [MenuBarViewModel] icon not found in fresh scan")
        errorMessage = "无法找到图标"
        showError = true
        return false
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
        // 系统 app + 自身兜底保护
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        let killable = apps.filter {
            !($0.bundleIdentifier?.hasPrefix("com.apple.") ?? false) &&
            $0.bundleIdentifier != ownBundleID
        }
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

    /// 强制退出所有可见的非系统 app（在 MainActor 跑，forceTerminate 本身丢到后台 detached 不阻塞主线程，UI 可继续渲染进度）
    /// - Returns: 实际被终止的图标数
    @discardableResult
    @MainActor
    func forceQuitAll() async -> Int {
        let targets = quitAllTargets
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        guard !targets.isEmpty else { return 0 }

        isQuittingAll = true
        quitProgressDone = 0
        quitProgressTotal = targets.count
        defer {
            isQuittingAll = false
            quitProgressDone = 0
            quitProgressTotal = 0
        }

        var killedCount = 0
        for icon in targets {
            let bid = icon.appBundleIdentifier ?? ""
            let killed = await Task.detached(priority: .userInitiated) {
                let apps = NSRunningApplication
                    .runningApplications(withBundleIdentifier: bid)
                    .filter {
                        !($0.bundleIdentifier?.hasPrefix("com.apple.") ?? false) &&
                        $0.bundleIdentifier != ownBundleID
                    }
                apps.forEach { $0.forceTerminate() }
                return apps.isEmpty ? 0 : 1
            }.value
            killedCount += killed
            quitProgressDone += 1   // 回到 MainActor，UI 自动刷新
        }

        // 等 app 真正退出再刷
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await refresh()
        return killedCount
    }

    // MARK: - 全部退出 inline 二次确认

    /// 第一次点 power 按钮：进入 inline 确认态（启动 5s 倒计时，归零自动取消）
    @MainActor
    func requestQuitAll() {
        guard !confirmingQuitAll, !isQuittingAll, !quitAllTargets.isEmpty else { return }
        confirmingQuitAll = true
        quitConfirmFraction = 1.0
        startQuitConfirmCountdown()
    }

    /// 确认态下点"退出"：取消倒计时 + 触发 forceQuitAll
    @MainActor
    func confirmQuitAll() {
        guard confirmingQuitAll, !isQuittingAll else { return }
        cancelQuitConfirmCountdown()
        confirmingQuitAll = false
        Task { await forceQuitAll() }
    }

    /// 取消确认（点"取消"或倒计时归零）
    @MainActor
    func cancelQuitAllConfirm() {
        cancelQuitConfirmCountdown()
        confirmingQuitAll = false
        quitConfirmFraction = 1.0
    }

    @MainActor
    private func startQuitConfirmCountdown() {
        cancelQuitConfirmCountdown()
        let totalTicks = 50         // 5s，每 100ms 推进一步
        let intervalNs: UInt64 = 100_000_000
        quitConfirmTask = Task { @MainActor [weak self] in
            for tick in stride(from: totalTicks, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: intervalNs)
                if Task.isCancelled { return }
                guard let self else { return }
                self.quitConfirmFraction = Double(tick) / Double(totalTicks)
            }
            // 倒计时归零 → 自动取消
            guard let self else { return }
            self.confirmingQuitAll = false
            self.quitConfirmFraction = 1.0
        }
    }

    @MainActor
    private func cancelQuitConfirmCountdown() {
        quitConfirmTask?.cancel()
        quitConfirmTask = nil
    }

    /// 全部退出的目标集合（用于弹窗预览）
    var quitAllTargets: [IconItem] {
        // 按 app bundle ID 去重，同一 app 多个图标只算一个
        var seen: Set<String> = []
        var result: [IconItem] = []
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        for icon in icons where !icon.isHidden {
            let bid = icon.appBundleIdentifier ?? ""
            if bid.isEmpty || bid.hasPrefix("com.apple.") || bid == ownBundleID { continue }
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
