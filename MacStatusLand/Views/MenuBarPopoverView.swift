import SwiftUI

struct IconItem: Identifiable {
    let id = UUID()
    let title: String
    let index: Int
    let sfSymbol: String?
    let appName: String
}

struct MenuBarPopoverView: View {
    @State private var icons: [IconItem] = []
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("状态栏图标 (\(icons.count))")
                    .font(.headline)
                Spacer()
                Button("刷新") {
                    discoverIcons()
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 8)
            
            if showError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("无法获取状态栏图标")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("打开系统设置") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.link)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if icons.isEmpty {
                Text("点击刷新获取状态栏图标")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(icons) { icon in
                            IconRow(title: icon.title, sfSymbol: icon.sfSymbol, appName: icon.appName) {
                                clickIcon(at: icon.index)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            Divider()
            
            Text("点击图标触发对应操作")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            discoverIcons()
        }
    }
    
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
                appName: $0.element.appName
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

struct IconRow: View {
    let title: String
    let sfSymbol: String?
    let appName: String
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            HStack {
                if let symbol = sfSymbol {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 22, height: 22)
                } else {
                    Text(String(appName.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


