import SwiftUI

@available(macOS 14.0, *)
struct MenuBarPopoverView: View {
    @State private var viewModel = MenuBarViewModel()
    @ObservedObject private var settings = SettingsService.shared
    @State private var showCheckmark: String?  // 显示成功动画的图标 ID
    @State private var shakingIcon: String?    // 显示抖动动画的图标 ID
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            headerSection
            
            // 搜索栏
            searchSection
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            // 置顶图标区
            if !viewModel.pinnedIcons.isEmpty {
                pinnedSection
            }
            
            // 图标列表
            if viewModel.isLoading {
                loadingSection
            } else if viewModel.filteredIcons.isEmpty {
                if !viewModel.searchText.isEmpty {
                    searchEmptyStateSection
                } else {
                    emptyStateSection
                }
            } else {
                iconListSection
            }
            
            // 底部栏
            footerSection
        }
        .frame(width: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .task {
            await viewModel.discoverIcons()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
            Task { await viewModel.refresh() }
        }
    }
    
    // MARK: - 顶部栏
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    if let appIcon = appIconImage() {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text("MSL")
                        .font(.headline)
                        .help("MacStatusLand")
                }
                .padding(.leading, 4)

            Spacer()

            // 快速切换：隐藏/显示左侧图标
            Button(action: {
                settings.autoHideLeftIcons.toggle()
            }) {
                Image(systemName: settings.autoHideLeftIcons ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(settings.autoHideLeftIcons ? Color.accentColor : Color.secondary)
                    .padding(6)
                    .background(
                        settings.autoHideLeftIcons
                            ? Color.accentColor.opacity(0.12)
                            : (viewModel.hoveredHeaderId == "toggle-hide" ? Color.secondary.opacity(0.1) : Color.clear),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .help(settings.autoHideLeftIcons ? "toggle_show_left".localized() : "toggle_hide_left".localized())
            .onHover { isHovered in
                withAnimation(.easeOut(duration: 0.15)) {
                    if !accessibilityReduceMotion {
                        viewModel.hoveredHeaderId = isHovered ? "toggle-hide" : nil
                    }
                }
            }

            // 全部退出（强制）/ 进度
            if viewModel.isQuittingAll {
                HStack(spacing: 6) {
                    ProgressView(value: viewModel.quitProgressFraction)
                        .progressViewStyle(.linear)
                        .frame(width: 90)
                    Text("正在退出 \(viewModel.quitProgressDone)/\(viewModel.quitProgressTotal)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.12), in: Capsule())
            } else {
                Button(action: {
                    if viewModel.confirmingQuitAll {
                        viewModel.confirmQuitAll()
                    } else {
                        viewModel.requestQuitAll()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .semibold))
                        Text("quit_all_button".localized())
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.12), in: Capsule())
                    .overlay(
                        Capsule().stroke(.red.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("quit_all_button".localized())
                .disabled(viewModel.quitAllTargets.isEmpty)
                .opacity(viewModel.quitAllTargets.isEmpty ? 0.4 : 1)
                .onHover { isHovered in
                    withAnimation(.easeOut(duration: 0.15)) {
                        if !accessibilityReduceMotion {
                            viewModel.hoveredHeaderId = isHovered ? "quit-all" : nil
                        }
                    }
                }
                .scaleEffect(viewModel.hoveredHeaderId == "quit-all" && !accessibilityReduceMotion ? 1.05 : 1.0)
            }

            // 设置入口
            Button(action: {
                NotificationCenter.default.post(name: .menuBarDidRequestSettings, object: nil)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(
                        viewModel.hoveredHeaderId == "settings" ? .secondary.opacity(0.1) : Color.clear,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .help("settings_menu".localized())
            .onHover { isHovered in
                withAnimation(.easeOut(duration: 0.15)) {
                    if !accessibilityReduceMotion {
                        viewModel.hoveredHeaderId = isHovered ? "settings" : nil
                    }
                }
            }

            Button(action: { Task { await viewModel.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(
                        viewModel.hoveredHeaderId == "refresh" ? .secondary.opacity(0.1) : Color.clear,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .onHover { isHovered in
                withAnimation(.easeOut(duration: 0.15)) {
                    if !accessibilityReduceMotion {
                        viewModel.hoveredHeaderId = isHovered ? "refresh" : nil
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, viewModel.confirmingQuitAll ? 8 : 10)
        }

            // inline 二次确认条（power 按钮第一次点后展开；5s 不点自动收起）
            if viewModel.confirmingQuitAll {
                quitAllConfirmBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.confirmingQuitAll)
    }

    private var quitAllConfirmBar: some View {
        let count = viewModel.quitAllTargets.count
        return HStack(spacing: 8) {
            // 倒计时环（左侧装饰，5s 顺时针缩到 0）
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: viewModel.quitConfirmFraction)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.quitConfirmFraction)
            }
            .frame(width: 16, height: 16)

            Text("确认退出 \(count) 个应用？")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("取消") { viewModel.cancelQuitAllConfirm() }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                viewModel.confirmQuitAll()
            } label: {
                Text("退出")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.red.opacity(0.25), lineWidth: 0.5)
        )
    }
    
    // MARK: - 搜索栏
    
    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            
            TextField("search_placeholder".localized(), text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    withAnimation(.easeOut(duration: 0.15)) {
                        if !accessibilityReduceMotion {
                            viewModel.hoveredSearchClear = isHovered
                        }
                    }
                }
                .opacity(viewModel.hoveredSearchClear && !accessibilityReduceMotion ? 0.7 : 1.0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - 置顶区
    
    private var pinnedSection: some View {
        VStack(spacing: 4) {
            ForEach(viewModel.pinnedIcons) { icon in
                iconRow(icon)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial.opacity(0.8))
        .overlay(alignment: .bottom) {
            Divider()
                .background(.secondary.opacity(0.15))
        }
    }
    
    // MARK: - 图标列表
    
    private var groupedIconSection: some View {
        ForEach(IconCategory.allCases, id: \.self) { category in
            let categoryIcons = viewModel.unpinnedIcons.filter { $0.category == category }

            if !categoryIcons.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: category.sfSymbol)
                        .font(.caption2)
                        .foregroundStyle(category.tint)
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(categoryIcons.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)

                ForEach(categoryIcons, id: \.id) { icon in
                    iconRow(icon)
                }
            }
        }
    }
    
    private var iconListSection: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                groupedIconSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: min(NSScreen.main?.frame.height ?? 480 * 0.4, 360))
    }
    
    // MARK: - 图标行
    
    private func iconRow(_ icon: IconItem) -> some View {
        let isPressed = viewModel.pressedIconId == icon.id
        return HStack(spacing: 12) {
            // 图标
            Group {
                if let image = icon.iconImage {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // 应用名称
            VStack(alignment: .leading, spacing: 2) {
                Text(icon.appName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if icon.isPinned {
                    Text("pinned_label".localized())
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // 操作指示（hover 才出现，视觉更安静）
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(viewModel.hoveredIconId == icon.id ? 0.8 : 0)
                .animation(.easeOut(duration: 0.12), value: viewModel.hoveredIconId)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.hoveredIconId == icon.id ? .secondary.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.1), lineWidth: 0.5)
        )
        .overlay {
            if showCheckmark == icon.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .offset(x: shakingIcon == icon.id ? 5 : 0)
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeOut(duration: 0.15)) {
                if !accessibilityReduceMotion {
                    viewModel.hoveredIconId = isHovered ? icon.id : nil
                }
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            // 按压瞬间反馈
            withAnimation { viewModel.pressedIconId = icon.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if viewModel.pressedIconId == icon.id {
                    viewModel.pressedIconId = nil
                }
            }

            let success = viewModel.clickIcon(icon)
            if !accessibilityReduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if success {
                        showCheckmark = icon.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation { showCheckmark = nil }
                        }
                    } else {
                        shakingIcon = icon.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            shakingIcon = nil
                        }
                    }
                }
            } else {
                if success {
                    showCheckmark = icon.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showCheckmark = nil
                    }
                } else {
                    shakingIcon = icon.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shakingIcon = nil
                    }
                }
            }
        }
        .contextMenu {
            Button(action: { viewModel.togglePin(icon) }) {
                Label(
                    (icon.isPinned ? "context_unpin" : "context_pin").localized(),
                    systemImage: icon.isPinned ? "pin.slash" : "pin"
                )
            }

            Button(action: { viewModel.hideIcon(icon) }) {
                Label("context_hide".localized(), systemImage: "eye.slash")
            }

            if !(icon.appBundleIdentifier ?? "").hasPrefix("com.apple.") {
                Divider()

                Button(action: { viewModel.quitApp(icon, force: false) }) {
                    Label("context_quit_app".localized(), systemImage: "power")
                }

                Button(role: .destructive, action: { viewModel.quitApp(icon, force: true) }) {
                    Label("context_force_quit_app".localized(), systemImage: "xmark.octagon")
                }
            }
        }
    }
    
    // MARK: - 加载中
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            
            Text("正在发现图标...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: 200)
    }
    
    // MARK: - 空状态
    
    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            if viewModel.showError {
                Text("no_permission".localized())
                    .font(.headline)
                
                Text("请在系统设置中删除旧的 MacStatusLand 条目，然后重新添加")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("open_settings".localized()) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Text("no_icons_found".localized())
                    .font(.headline)
                
                Text("请确保有第三方应用在运行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: 200)
        .padding()
    }

    private var searchEmptyStateSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("无匹配结果")
                .font(.headline)
            Text("试试别的关键词，或清空搜索框")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("清空搜索") {
                viewModel.searchText = ""
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxHeight: 200)
        .padding()
    }
    
    // MARK: - 底部栏
    
    private var footerSection: some View {
        HStack {
            Spacer()

            Text("GitHub")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(4)
                .background(
                    viewModel.hoveredFooterId == "github" ? .secondary.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .onHover { isHovered in
                    withAnimation(.easeOut(duration: 0.15)) {
                        if !accessibilityReduceMotion {
                            viewModel.hoveredFooterId = isHovered ? "github" : nil
                        }
                    }
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/xiaoRui278/mac-status-land") {
                        NSWorkspace.shared.open(url)
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial.opacity(0.5))
    }

    /// 加载 app 图标：避开 NSApp.applicationIconImage（spm run 下会返回系统 generic 占位图，显示成"文件夹"）
    /// 1. Bundle.main 读 AppIcon.icns（release .app 模式：.app/Contents/Resources/ 下）
    /// 2. Bundle.module 读 AppIcon.icns（spm run 模式：SPM resource bundle 内）
    private func appIconImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url), img.size.width > 0 {
            return img
        }
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url), img.size.width > 0 {
            return img
        }
        return nil
    }
}
