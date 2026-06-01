import SwiftUI

struct IconItem: Identifiable {
    let id = UUID()
    let title: String
    let index: Int
    let sfSymbol: String?
    let appName: String
    let image: NSImage?
}

struct MenuBarPopoverView: View {
    @State private var icons: [IconItem] = []
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if showError {
                errorSection
            } else if icons.isEmpty {
                emptyStateSection
            } else {
                iconListSection
            }
            
            Divider()
            footerSection
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 380)
        .onAppear {
            discoverIcons()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("状态栏图标")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\(icons.count) 个图标")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: discoverIcons) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(spacing: 12) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 6) {
                Text("无法获取状态栏图标")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button(action: openAccessibilitySettings) {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.system(size: 12, weight: .medium))
                    Text("打开系统设置")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                Text("暂无图标")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("点击刷新按钮获取状态栏图标")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Icon List Section
    
    private var iconListSection: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(icons) { icon in
                    IconRow(
                        title: icon.title,
                        sfSymbol: icon.sfSymbol,
                        appName: icon.appName,
                        image: icon.image
                    ) {
                        clickIcon(at: icon.index)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 320)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryLabel)
            Text("点击图标触发对应操作")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Actions
    
    private func discoverIcons() {
        showError = false
        errorMessage = ""
        
        let service = IconDiscoveryService.shared
        let discovered = service.discoverStatusBarIcons()
        icons = discovered.enumerated().map {
            IconItem(
                title: $0.element.displayTitle,
                index: $0.offset,
                sfSymbol: $0.element.sfSymbol,
                appName: $0.element.appName,
                image: $0.element.image
            )
        }
        
        if icons.isEmpty {
            showError = true
            errorMessage = "未找到状态栏图标。请确保已授予辅助功能权限。"
        }
    }
    
    private func clickIcon(at index: Int) {
        let service = IconDiscoveryService.shared
        let allIcons = service.discoverStatusBarIcons()
        if index < allIcons.count {
            _ = service.performAction(allIcons[index])
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Icon Row

struct IconRow: View {
    let title: String
    let sfSymbol: String?
    let appName: String
    let image: NSImage?
    let onClick: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(isHovered ? 0.15 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    } else if let symbol = sfSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.accentColor)
                    } else {
                        Text(String(appName.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !appName.isEmpty {
                        Text(appName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.tertiaryLabel)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.primary.opacity(0.1) : 
                          isHovered ? Color.primary.opacity(0.05) : 
                          Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Color Extensions

private extension Color {
    static let tertiaryLabel = Color(NSColor.tertiaryLabelColor)
}
