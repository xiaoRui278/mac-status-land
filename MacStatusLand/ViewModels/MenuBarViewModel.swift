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
        guard let element = icon.axElement ?? cacheService.getElement(bundleIdentifier: icon.id) else {
            errorMessage = "无法访问图标"
            showError = true
            return false
        }
        
        let statusBarIcon = StatusBarIcon(
            index: 0,
            title: icon.appName,
            description: nil,
            element: element,
            identifier: icon.bundleIdentifier,
            appName: icon.appName,
            image: icon.iconImage
        )
        
        let success = accessibilityService.performAction(statusBarIcon)
        
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
