import Foundation
import ApplicationServices
import AppKit

class AccessibilityService {
    
    enum AccessibilityError: Error {
        case notAuthorized
        case elementNotFound
        case attributeError
    }
    
    // MARK: - 权限检查
    
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let trusted = AXIsProcessTrusted()
        print("AXIsProcessTrusted: \(trusted)")
        
        if prompt && !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return trusted
    }
    
    // MARK: - 状态栏元素获取
    
    static func getMenuBarItems() -> [AXUIElement] {
        var allItems: [AXUIElement] = []
        
        let systemApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular || $0.bundleIdentifier?.hasPrefix("com.apple.") == true
        }
        
        for app in systemApps {
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var menuBarRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
                  let menuBar = menuBarRef else {
                continue
            }
            
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else {
                continue
            }
            
            allItems.append(contentsOf: children)
        }
        
        print("Found \(allItems.count) total menu bar items")
        return allItems
    }
    
    // MARK: - 属性读取
    
    static func getElementAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }
    
    static func getElementPosition(_ element: AXUIElement) -> CGPoint? {
        guard let positionRef = getElementAttribute(element, attribute: kAXPositionAttribute) else { return nil }
        
        var point = CGPoint.zero
        if AXValueGetValue(positionRef as! AXValue, .cgPoint, &point) {
            return point
        }
        return nil
    }
    
    static func getElementSize(_ element: AXUIElement) -> CGSize? {
        guard let sizeRef = getElementAttribute(element, attribute: kAXSizeAttribute) else { return nil }
        
        var size = CGSize.zero
        if AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
            return size
        }
        return nil
    }
    
    /// 状态栏元素本身没有 bundleIdentifier，需要通过 pid 查找父应用
    static func getElementBundleIdentifier(_ element: AXUIElement) -> String? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else { return nil }
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.bundleIdentifier
        }
        return nil
    }
    
    static func getElementTitle(_ element: AXUIElement) -> String? {
        guard let titleRef = getElementAttribute(element, attribute: kAXTitleAttribute) else {
            return nil
        }
        return titleRef as? String
    }
    
    /// 获取元素的 AXStatusLabel（未公开属性，但可用）
    static func getElementStatusLabel(_ element: AXUIElement) -> String? {
        guard let labelRef = getElementAttribute(element, attribute: "AXStatusLabel") else {
            return nil
        }
        return labelRef as? String
    }
    
    // MARK: - 操作
    
    static func performClick(_ element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        return result == .success
    }
}
