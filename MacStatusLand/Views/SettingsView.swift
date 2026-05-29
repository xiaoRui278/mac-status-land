import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @State private var showResetConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title2)
                .padding(.bottom, 8)
            
            GroupBox("通用") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("开机自动启动", isOn: Binding(
                        get: { LoginItemService.isEnabled() },
                        set: { LoginItemService.setEnabled($0) }
                    ))
                    Toggle("启动时自动隐藏配置的图标", isOn: $viewModel.settings.autoHideOnLaunch)
                }
                .padding(8)
            }
            
            GroupBox("隐藏规则") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.discoveredApps) { app in
                        HStack {
                            Toggle(app.displayName, isOn: Binding(
                                get: { viewModel.isAppHiddenByDefault(app.bundleIdentifier) },
                                set: { _ in viewModel.toggleHiddenApp(app.bundleIdentifier) }
                            ))
                            Spacer()
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }
            
            HStack {
                Button("刷新图标列表") {
                    viewModel.refreshMenuBarApps()
                }
                Spacer()
                Button("重置设置") {
                    showResetConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 400)
        .alert("确认重置", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                viewModel.updateSettings(.default)
                viewModel.showAllApps()
            }
        } message: {
            Text("这将重置所有设置并显示所有隐藏的图标。确定要继续吗？")
        }
    }
}