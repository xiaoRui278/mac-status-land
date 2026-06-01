import SwiftUI
import AVFoundation

@main
struct MacStatusLandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestScreenRecordingPermission()
        statusBarController = StatusBarController()
    }
    
    private func requestScreenRecordingPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                print("屏幕录制权限已授予")
            } else {
                print("屏幕录制权限被拒绝")
            }
        }
    }
}
