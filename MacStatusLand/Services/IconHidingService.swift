import Foundation
import CoreGraphics
import AppKit

class IconHidingService {
    
    private var hiddenPositions: [String: CGPoint] = [:]
    private let offscreenX: CGFloat = -10000
    
    // MARK: - Cmd+drag 模拟
    
    /// 模拟 Cmd+drag 手势移动状态栏图标
    /// 这是唯一能移动状态栏图标的方法
    private func performCmdDrag(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        duration: TimeInterval = 0.24,
        steps: Int = 16
    ) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        let stepDuration = duration / Double(steps)
        let deltaX = (endPoint.x - startPoint.x) / CGFloat(steps)
        let deltaY = (endPoint.y - startPoint.y) / CGFloat(steps)
        
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: startPoint,
            mouseButton: .left
        ) else { return false }
        
        mouseDown.flags = .maskCommand
        mouseDown.post(tap: .cghidEventTap)
        
        for i in 1...steps {
            let point = CGPoint(
                x: startPoint.x + deltaX * CGFloat(i),
                y: startPoint.y + deltaY * CGFloat(i)
            )
            
            guard let mouseDrag = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { break }
            
            mouseDrag.flags = .maskCommand
            mouseDrag.post(tap: .cghidEventTap)
            
            Thread.sleep(forTimeInterval: stepDuration)
        }
        
        guard let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: endPoint,
            mouseButton: .left
        ) else { return false }
        
        mouseUp.flags = .maskCommand
        mouseUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    // MARK: - 隐藏/显示
    
    /// 隐藏图标（移动到屏幕外）
    func hideIcon(for bundleIdentifier: String, at position: CGPoint) -> Bool {
        guard let element = getElement(for: bundleIdentifier) else {
            return false
        }
        
        guard let currentPosition = AccessibilityService.getElementPosition(element) else {
            return false
        }
        
        hiddenPositions[bundleIdentifier] = currentPosition
        
        let offscreenPosition = CGPoint(x: offscreenX, y: currentPosition.y)
        
        return performCmdDrag(from: currentPosition, to: offscreenPosition)
    }
    
    /// 显示图标（恢复原始位置）
    func showIcon(for bundleIdentifier: String) -> Bool {
        guard let element = getElement(for: bundleIdentifier),
              let originalPosition = hiddenPositions[bundleIdentifier] else {
            return false
        }
        
        guard let currentPosition = AccessibilityService.getElementPosition(element) else {
            return false
        }
        
        let result = performCmdDrag(from: currentPosition, to: originalPosition)
        
        if result {
            hiddenPositions.removeValue(forKey: bundleIdentifier)
        }
        
        return result
    }
    
    /// 批量隐藏
    func hideAll(identifiers: [String], discoveryService: IconDiscoveryService) {
        for identifier in identifiers {
            if let element = discoveryService.getElement(for: identifier),
               let position = AccessibilityService.getElementPosition(element) {
                hideIcon(for: identifier, at: position)
            }
        }
    }
    
    /// 显示所有隐藏的图标
    func showAll() {
        for (identifier, _) in hiddenPositions {
            showIcon(for: identifier)
        }
    }
    
    /// 检查图标是否被隐藏
    func isHidden(bundleIdentifier: String) -> Bool {
        return hiddenPositions[bundleIdentifier] != nil
    }
    
    /// 获取隐藏前的原始位置
    func getHiddenPosition(for bundleIdentifier: String) -> CGPoint? {
        return hiddenPositions[bundleIdentifier]
    }
    
    // MARK: - 辅助方法
    
    private func getElement(for bundleIdentifier: String) -> AXUIElement? {
        let items = AccessibilityService.getStatusBarItems()
        return items.first { item in
            AccessibilityService.getElementBundleIdentifier(item) == bundleIdentifier
        }
    }
}
