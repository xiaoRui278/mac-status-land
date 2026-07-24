import Foundation
import AppKit
import SwiftUI
import Combine

/// 自动隐藏 MSL 图标左侧图标的服务
///
/// 参考 Ice（github.com/jordanbaird/Ice）实现：
/// - 创建一个独立的 divider status item
/// - 开启时把 divider 的 length 撑到 10000 → 系统会把它左侧的所有 status item 挤出可见区域
/// - autosaveName 让系统记住用户 ⌘ 拖动放置 divider 的位置
/// - divider 在 MSL 图标左侧（通过 preferredPosition 预设）
///
/// 用户操作流程：
/// 1. 应用启动后，菜单栏出现 divider 图标（<<）
/// 2. 关闭自动隐藏时可见，用户 ⌘ 拖动 divider 到期望位置
/// 3. 开启自动隐藏后，divider 撑到 10000 → 其左侧图标被挤出屏幕
@available(macOS 14.0, *)
class PlaceholderService: NSObject {
    static let shared = PlaceholderService()

    /// autosaveName：让系统持久化用户 ⌘ 拖动后 divider 的位置
    private static let autosaveName = "MacStatusLand.HideDivider"

    /// 撑开挤压左侧图标时使用的宽度（参考 Ice）
    private static let expandedLength: CGFloat = 10_000

    private var dividerItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var hintPopover: NSPopover?

    private override init() {
        super.init()
        setupObservers()
        setupTerminationObserver()
    }

    private func setupObservers() {
        SettingsService.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSettingChanged()
                self?.updateDividerTooltip()
            }
        }.store(in: &cancellables)
    }

    private func setupTerminationObserver() {
        // 应用退出时清理 divider，避免残留超宽 status item 挤压菜单栏
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let item = self?.dividerItem {
                item.length = 0
                NSStatusBar.system.removeStatusItem(item)
            }
        }
    }

    /// 由 StatusBarController 在主图标创建后调用
    func startObserving(mainButton: NSStatusBarButton) {
        _ = mainButton   // 保留参数用于 API 兼容

        createDivider()

        // 启动时延迟应用设置，等菜单栏布局稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.handleSettingChanged()
        }

        // 首次启动引导：避免与主 popover 重叠
        if !SettingsService.shared.hasSeenDividerHint {
            scheduleFirstUseHint()
        }
    }

    private func scheduleFirstUseHint() {
        // 若本次启动主 popover 会自动打开：等它关闭后再弹引导
        // 否则（老用户，无自动 popover）：延迟 2.5s 直接弹
        let willAutoOpenMainPopover = !SettingsService.shared.hasCompletedFirstLaunch
        if willAutoOpenMainPopover {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(mainPopoverDidClose),
                name: NSPopover.didCloseNotification,
                object: nil
            )
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.showFirstUseHint()
            }
        }
    }

    @objc private func mainPopoverDidClose(_ note: Notification) {
        // 只在首次未显示过引导时响应，且忽略自己的 hintPopover
        guard !SettingsService.shared.hasSeenDividerHint else {
            NotificationCenter.default.removeObserver(self, name: NSPopover.didCloseNotification, object: nil)
            return
        }
        if let closed = note.object as? NSPopover, closed === hintPopover {
            return
        }
        NotificationCenter.default.removeObserver(self, name: NSPopover.didCloseNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showFirstUseHint()
        }
    }

    private func createDivider() {
        guard dividerItem == nil else { return }

        // preferredPosition 越大越靠左。首次启动时预设为 800（大于典型主图标的 ~462），
        // 让 divider 一开始出现在 MSL 图标左侧
        let posKey = "NSStatusItem Preferred Position \(Self.autosaveName)"
        if UserDefaults.standard.object(forKey: posKey) == nil {
            UserDefaults.standard.set(800, forKey: posKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = Self.autosaveName
        item.isVisible = true

        if let button = item.button {
            let image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle hide left icons")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(dividerClicked)
            button.target = self
        }

        dividerItem = item
        updateDividerTooltip()
    }

    /// 点击 divider → 切换自动隐藏（开→关，关→开）
    @objc private func dividerClicked() {
        SettingsService.shared.autoHideLeftIcons.toggle()
    }

    private func handleSettingChanged() {
        let enabled = SettingsService.shared.autoHideLeftIcons
        guard let item = dividerItem else { return }

        if enabled {
            // 撑到 10000 让 divider 左侧所有 status item 被推出屏幕
            item.length = Self.expandedLength
        } else {
            // 恢复正常宽度，用户可看到 << 图标并 ⌘ 拖动调整位置
            item.length = NSStatusItem.squareLength
        }
    }

    private func updateDividerTooltip() {
        guard let button = dividerItem?.button else { return }
        let enabled = SettingsService.shared.autoHideLeftIcons
        button.toolTip = (enabled ? "divider_icon_tooltip_active" : "divider_icon_tooltip").localized()
    }

    // MARK: - 首次使用引导

    /// 在 divider 图标下方弹出小 popover，说明其用途
    private func showFirstUseHint() {
        guard let button = dividerItem?.button else { return }
        guard hintPopover == nil else { return }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 180)

        let host = NSHostingController(rootView: DividerHintView(onDismiss: { [weak self] in
            self?.dismissHint()
        }))
        popover.contentViewController = host

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        hintPopover = popover

        SettingsService.shared.hasSeenDividerHint = true

        // 兜底：10 秒后自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.dismissHint()
        }
    }

    private func dismissHint() {
        hintPopover?.performClose(nil)
        hintPopover = nil
    }

    deinit {
        if let item = dividerItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        cancellables.removeAll()
    }
}

/// 首次使用引导 popover 内容
@available(macOS 14.0, *)
private struct DividerHintView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("divider_hint_title".localized())
                    .font(.system(size: 14, weight: .semibold))
            }

            Text("divider_hint_body".localized())
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("divider_hint_dismiss".localized())
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }
}
