import SwiftUI

struct PermissionView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("需要权限")
                .font(.title)
            
            Text("Mac Status Land 需要以下权限才能正常工作：")
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    icon: "accessibility",
                    title: "辅助功能",
                    description: "用于读取和操控状态栏图标"
                )
                
                PermissionRow(
                    icon: "display",
                    title: "屏幕录制",
                    description: "用于截取状态栏图标图像"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Button("打开系统设置并请求权限") {
                _ = AccessibilityService.checkAccessibility(prompt: true)
                openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            
            Button("我已授权，继续") {
                viewModel.initialize()
            }
            .buttonStyle(.link)
        }
        .padding(40)
        .frame(width: 450)
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
