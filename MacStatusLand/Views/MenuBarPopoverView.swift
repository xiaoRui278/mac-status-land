import SwiftUI

struct MenuBarPopoverView: View {
    @State private var menuBarImage: NSImage?
    
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
                MenuBarImageView(image: image)
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
}

struct MenuBarImageView: NSViewRepresentable {
    let image: NSImage
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isEditable = false
        
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        imageView.addGestureRecognizer(clickGesture)
        
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(image: image)
    }
    
    class Coordinator: NSObject {
        let image: NSImage
        
        init(image: NSImage) {
            self.image = image
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let imageView = gesture.view as? NSImageView else { return }
            
            let locationInView = gesture.location(in: imageView)
            let imageViewSize = imageView.bounds.size
            
            guard let screenPoint = MenuBarCaptureService.screenPointFromImageView(
                point: locationInView,
                imageViewSize: imageViewSize
            ) else { return }
            
            _ = MenuBarCaptureService.simulateClick(at: screenPoint)
        }
    }
}
