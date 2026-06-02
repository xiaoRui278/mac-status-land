// MacStatusLand/MacStatusLand/Services/HotkeyService.swift

import Foundation
import AppKit
import Carbon.HIToolbox

/// 全局快捷键服务
class HotkeyService {
    static let shared = HotkeyService()
    
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?
    
    private init() {}
    
    /// 注册快捷键
    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        // 先注销旧的
        unregister()
        
        self.action = action
        
        var eventType = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // 安装事件处理器
        let handler: EventHandlerUPP = { _, _, _ -> OSStatus in
            HotkeyService.shared.action?()
            return noErr
        }
        
        InstallEventHandler(
            GetCurrentEventQueue(),
            handler,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        
        // 注册快捷键
        let hotkeyID = EventHotKeyID(signature: OSType(0x4D534C), id: 1)
        RegisterEventHotKey(
            UInt32(keyCode),
            modifiers.carbonFlags,
            hotkeyID,
            GetCurrentEventQueue(),
            0,
            &hotkeyRef
        )
    }
    
    /// 注销快捷键
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
        action = nil
    }
    
    deinit {
        unregister()
    }
}

extension NSEvent.ModifierFlags {
    /// 转换为 Carbon 修饰键
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
