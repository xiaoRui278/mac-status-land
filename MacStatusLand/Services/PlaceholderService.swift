import Foundation
import AppKit
import Combine

/// 自动隐藏 MSL 图标左侧图标的服务
///
/// 原理：占位符挤出法
/// 1. main 图标先创建 → 位于菜单栏可见位置
/// 2. placeholder 后创建 → macOS 将其放置在 main 左侧（新增 item 总添加至最左）
/// 3. placeholder 向右扩展，其右边缘对齐 main 左边缘
/// 4. 中间的其他 app 图标被挤到 placeholder 更左边（超出屏幕，被 notch 遮挡）
/// 5. 迭代多次直到 placeholder 位置不再移动（所有可挤走的图标都已挤走）
/// 6. 检测到 placeholder 越过 main（macOS 重新排版把 main 挤走了）时回退到上一个安全宽度
@available(macOS 14.0, *)
class PlaceholderService {
    static let shared = PlaceholderService()

    private var statusItem: NSStatusItem?
    private var mainButton: NSStatusBarButton?
    private var observation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
        setupTerminationObserver()
    }

    private func setupObservers() {
        SettingsService.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSettingChanged()
            }
        }.store(in: &cancellables)
    }

    private func setupTerminationObserver() {
        // 应用退出时确保移除占位符，避免菜单栏图标恢复不完全
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let statusItem = self.statusItem else { return }
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    /// main 图标创建后调用，用于监听位置变化
    func startObserving(mainButton: NSStatusBarButton) {
        self.mainButton = mainButton

        // 创建占位符（此时 main 已存在 → 占位符会被系统放到 main 左边）
        createPlaceholder()

        // 主图标位置变化（用户拖动）时重新计算宽度
        observation = mainButton.observe(\.frame, options: [.new]) { [weak self] _, _ in
            guard let self = self, SettingsService.shared.autoHideLeftIcons else { return }
            DispatchQueue.main.async {
                self.updatePlaceholderWidth()
            }
        }

        // 启动时等待菜单栏完成布局再应用设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.handleSettingChanged()
        }
    }

    private func createPlaceholder() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: 0)
        statusItem?.button?.isTransparent = true
        statusItem?.button?.wantsLayer = true
        statusItem?.button?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func handleSettingChanged() {
        let enabled = SettingsService.shared.autoHideLeftIcons

        if enabled {
            if statusItem == nil {
                createPlaceholder()
                // 给占位符一个较大初始宽度，强制系统进行布局定位
                statusItem?.length = 2000
            }
            // 等布局稳定后再测量位置
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updatePlaceholderWidth()
            }
        } else {
            statusItem?.length = 0
        }
    }

    private func updatePlaceholderWidth() {
        guard let statusItem = statusItem,
              let mainButton = mainButton,
              let placeholderButton = statusItem.button else {
            return
        }

        let placeholderMinX = screenMinX(of: placeholderButton)
        let mainMinX = screenMinX(of: mainButton)

        // 宽度 = 占位符起点到主图标起点的距离，让占位符右边缘刚好对齐主图标左边缘
        let width = mainMinX - placeholderMinX

        if width > 0 {
            statusItem.length = width

            // 迭代扩展：设置宽度后占位符起点可能左移，需再次计算继续扩展直到收敛
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.iterativeExpand(iteration: 1, lastWidth: width, lastSafeWidth: 0)
            }
        } else {
            statusItem.length = 0
        }
    }

    /// 迭代扩展占位符直到位置稳定（所有可挤走的图标都已挤走）
    /// - lastSafeWidth: 上一次已验证不会导致主图标被挤出的安全宽度
    private func iterativeExpand(iteration: Int, lastWidth: CGFloat, lastSafeWidth: CGFloat) {
        guard iteration <= 5,
              let statusItem = statusItem,
              let mainButton = mainButton,
              let placeholderButton = statusItem.button else {
            return
        }

        let placeholderMinX = screenMinX(of: placeholderButton)
        let mainMinX = screenMinX(of: mainButton)

        // 越界保护：占位符位置超过主图标 → 主图标已被挤到左边看不见 → 回退到上一个安全宽度
        if placeholderMinX > mainMinX {
            statusItem.length = lastSafeWidth
            return
        }

        let newWidth = mainMinX - placeholderMinX

        // 若能进一步扩展（占位符还在左移）则继续
        if newWidth > lastWidth + 5 {
            statusItem.length = newWidth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.iterativeExpand(iteration: iteration + 1, lastWidth: newWidth, lastSafeWidth: lastWidth)
            }
        }
        // 否则收敛，保持当前宽度
    }

    /// 获取按钮在屏幕坐标系中的左边缘 X（每个 status item 有自己独立 NSWindow）
    private func screenMinX(of button: NSStatusBarButton) -> CGFloat {
        guard let window = button.window else { return 0 }
        let frame = button.convert(button.bounds, to: nil)
        return window.convertToScreen(frame).minX
    }

    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        observation = nil
        cancellables.removeAll()
    }
}
