import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    var onSettings: (() -> Void)?

    let columns = [
        GridItem(.adaptive(minimum: 60, maximum: 80))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("隐藏的图标")
                    .font(.headline)
                Spacer()
                Button("显示全部") {
                    viewModel.showAllApps()
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 8)

            if viewModel.discoveredApps.filter({ $0.isHidden }).isEmpty {
                Text("没有隐藏的图标")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.discoveredApps.filter { $0.isHidden }) { app in
                        IconCell(app: app) {
                            viewModel.triggerClick(for: app)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("刷新") {
                    viewModel.refreshMenuBarApps()
                    viewModel.captureScreenshots()
                }
                Spacer()
                Button("设置") {
                    onSettings?()
                }
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 300)
    }
}

struct IconCell: View {
    let app: MenuBarApp
    let onClick: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // 图标图像
            if let data = app.screenshotData,
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accentColor)
            }

            // 应用名
            Text(app.displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            onClick()
        }
        .help(app.displayName)
    }
}
