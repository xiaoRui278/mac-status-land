import SwiftUI

@available(macOS 14.0, *)
struct MenuBarPopoverView: View {
    @State private var viewModel = MenuBarViewModel()
    @State private var showCheckmark: String?  // 显示成功动画的图标 ID
    @State private var shakingIcon: String?    // 显示抖动动画的图标 ID
    
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
                emptyStateSection
            } else {
                iconListSection
            }
            
            // 底部栏
            footerSection
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .task {
            await viewModel.discoverIcons()
        }
    }
    
    // MARK: - 顶部栏
    
    private var headerSection: some View {
        HStack {
            Text("MacStatusLand")
                .font(.headline)
            
            Spacer()
            
            Button(action: { Task { await viewModel.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
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
                .background(.white.opacity(0.15))
        }
    }
    
    // MARK: - 图标列表
    
    private var groupedIconSection: some View {
        ForEach(IconCategory.allCases, id: \.self) { category in
            let categoryIcons = viewModel.unpinnedIcons.filter { $0.category == category }
            
            if !categoryIcons.isEmpty {
                HStack {
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                ForEach(categoryIcons) { icon in
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
        .frame(maxHeight: 320)
    }
    
    // MARK: - 图标行
    
    private func iconRow(_ icon: IconItem) -> some View {
        HStack(spacing: 12) {
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
                
                if icon.isPinned {
                    Text("pinned_label".localized())
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            // 操作指示
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
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
        .onTapGesture {
            let success = viewModel.clickIcon(icon)
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
        }
        .contextMenu {
            Button(action: { viewModel.togglePin(icon) }) {
                Label(
                    icon.isPinned ? "取消置顶" : "置顶",
                    systemImage: icon.isPinned ? "pin.slash" : "pin"
                )
            }
            
            Button(action: { viewModel.hideIcon(icon) }) {
                Label("隐藏", systemImage: "eye.slash")
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
    
    // MARK: - 底部栏
    
    private var footerSection: some View {
        HStack {
            Button(action: { Task { await viewModel.refresh() } }) {
                Label("refresh".localized(), systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            
            Spacer()
            
            Text("GitHub")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
