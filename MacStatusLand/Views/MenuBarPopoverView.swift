import SwiftUI

struct MenuBarPopoverView: View {
    @State private var menuBarImage: NSImage?
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("状态栏图标")
                    .font(.headline)
                Spacer()
                Button("刷新") {
                    captureMenuBar()
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 8)
            
            if let image = menuBarImage {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width)
                        .background(Color.white)
                        .cornerRadius(4)
                        .onTapGesture { location in
                            handleClick(at: location, in: geometry.size)
                        }
                }
                .frame(height: 30)
            } else {
                Text("点击刷新捕获菜单栏")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
            
            Divider()
            
            Text("点击上方图标触发对应操作")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            captureMenuBar()
        }
    }
    
    private func captureMenuBar() {
        menuBarImage = MenuBarCaptureService.captureMenuBar()
    }
    
    private func handleClick(at point: CGPoint, in viewSize: CGSize) {
        guard let image = menuBarImage else { return }
        
        let imageAspect = image.size.width / image.size.height
        let viewAspect = viewSize.width / viewSize.height
        
        var actualImageSize: CGSize
        if imageAspect > viewAspect {
            actualImageSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            actualImageSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        
        let offsetX = (viewSize.width - actualImageSize.width) / 2
        let offsetY = (viewSize.height - actualImageSize.height) / 2
        
        let imagePoint = CGPoint(
            x: point.x - offsetX,
            y: point.y - offsetY
        )
        
        guard imagePoint.x >= 0, imagePoint.x <= actualImageSize.width,
              imagePoint.y >= 0, imagePoint.y <= actualImageSize.height else {
            return
        }
        
        if let screenPoint = MenuBarCaptureService.screenPointFromImageView(
            point: imagePoint,
            imageViewSize: actualImageSize
        ) {
            _ = MenuBarCaptureService.simulateClick(at: screenPoint)
        }
    }
}
