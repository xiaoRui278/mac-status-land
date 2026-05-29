import Foundation
import AppKit
import CoreGraphics

class MenuBarCaptureService {
    
    static let menuBarHeight: CGFloat = 25
    
    static func captureMenuBar() -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        
        let screenFrame = screen.frame
        let menuBarRect = CGRect(
            x: 0,
            y: screenFrame.height - menuBarHeight,
            width: screenFrame.width,
            height: menuBarHeight
        )
        
        guard let cgImage = CGWindowListCreateImage(
            menuBarRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: screenFrame.width, height: menuBarHeight))
    }
    
    static func simulateClick(at screenPoint: CGPoint) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: screenPoint,
            mouseButton: .left
        ) else { return false }
        
        mouseDown.post(tap: .cghidEventTap)
        
        usleep(50000)
        
        guard let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: screenPoint,
            mouseButton: .left
        ) else { return false }
        
        mouseUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    static func screenPointFromImageView(point: CGPoint, imageViewSize: CGSize) -> CGPoint? {
        guard let screen = NSScreen.main else { return nil }
        
        let screenFrame = screen.frame
        let scaleX = screenFrame.width / imageViewSize.width
        let scaleY = menuBarHeight / imageViewSize.height
        
        let screenX = point.x * scaleX
        let screenY = screenFrame.height - (point.y * scaleY)
        
        return CGPoint(x: screenX, y: screenY)
    }
}
