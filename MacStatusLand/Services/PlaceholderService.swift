import Foundation
import AppKit
import Combine

@available(macOS 14.0, *)
class PlaceholderService {
    static let shared = PlaceholderService()

    private init() {
        setupObservers()
    }

    private var statusItem: NSStatusItem?
    private var mainButton: NSStatusBarButton?
    private var observation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    private func setupObservers() {
        // 监听设置变化
        SettingsService.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSettingChanged()
            }
        }.store(in: &cancellables)
    }

    /// 启动服务，监听主按钮位置变化
    func startObserving(mainButton: NSStatusBarButton) {
        self.mainButton = mainButton

        // KVO 监听 frame 变化（位置改变时更新占位宽度）
        observation = mainButton.observe(\.frame, options: [.new]) { [weak self] _, _ in
            guard let self = self, SettingsService.shared.autoHideLeftIcons else { return }
            self.updatePlaceholderWidth()
        }

        // 如果功能已经开启，立即创建占位符
        handleSettingChanged()
    }

    /// 处理设置开关变化
    private func handleSettingChanged() {
        let enabled = SettingsService.shared.autoHideLeftIcons

        if enabled {
            createPlaceholder()
            updatePlaceholderWidth()
        } else {
            removePlaceholder()
        }
    }

    /// 创建占位符
    private func createPlaceholder() {
        guard statusItem == nil else { return }
        // 创建可变长度的占位符
        statusItem = NSStatusBar.system.statusItem(withLength: 0)
        // 完全透明，不显示任何内容，不响应点击
        statusItem?.button?.isTransparent = true
        statusItem?.button?.wantsLayer = true
        statusItem?.button?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// 移除占位符
    private func removePlaceholder() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    /// 根据主按钮位置更新占位宽度
    private func updatePlaceholderWidth() {
        guard let statusItem = statusItem,
              let mainButton = mainButton else {
            return
        }

        // 获取主按钮在屏幕坐标系中的 frame
        let buttonFrameInWindow = mainButton.convert(mainButton.bounds, to: nil)
        let buttonFrameInScreen = mainButton.window?.convertToScreen(buttonFrameInWindow)

        // 占位宽度 = 主按钮左边缘距离屏幕左边的距离
        // 这样占位符正好填满从屏幕最左到主按钮左边缘的全部空间
        // 将这区间内所有图标挤出屏幕可视区域
        let width = buttonFrameInScreen?.minX ?? 0

        // 更新占位符长度
        if width > 0 {
            statusItem.length = width
        } else {
            // 如果宽度接近0，说明主按钮在最左侧，不需要占位
            statusItem.length = 0
        }
    }

    deinit {
        removePlaceholder()
        observation = nil
        cancellables.removeAll()
    }
}
