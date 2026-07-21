// MacStatusLand/MacStatusLand/Models/AppSettings.swift

import Foundation
import AppKit

/// 应用设置
struct AppSettings: Codable {
    /// 启动时登录
    var launchAtLogin: Bool = false
    
    /// 自动刷新间隔（秒）
    var autoRefreshInterval: Int = 30
    
    /// 显示系统图标
    var showSystemApps: Bool = false
    
    /// 应用语言
    var appLanguage: String = "zh"
    
    /// 已隐藏的图标 (bundleIdentifier 集合)
    var hiddenIcons: Set<String> = []
    
    /// 已置顶的图标 (有序列表)
    var pinnedIcons: [String] = []
    
    /// 预设配置
    var presets: [IconPreset] = []
    
    /// 全局快捷键配置
    var globalHotkey: HotkeyConfig?
    
    /// 失焦自动关闭
    var autoCloseOnFocusLoss: Bool = true

    /// Whether user has completed first launch (seen popover)
    var hasCompletedFirstLaunch: Bool = false
}

/// 快捷键配置
struct HotkeyConfig: Codable, Equatable {
    /// 按键码
    var keyCode: UInt16
    
    /// 修饰键
    var modifiers: UInt
    
    /// 修饰键 (NSEvent.ModifierFlags)
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }
    
    /// 显示名称
    var displayName: String {
        var parts: [String] = []
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { parts.append("⌘") }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { parts.append("⌥") }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { parts.append("⌃") }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { parts.append("⇧") }
        parts.append(KeyCodeMap.displayString(for: keyCode))
        return parts.joined()
    }
}

/// 按键码映射
enum KeyCodeMap {
    static func displayString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 42: return "\\"
        case 43: return ","
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        case 24: return "="
        case 27: return "-"
        case 33: return "["
        case 30: return "]"
        case 39: return "'"
        case 41: return ";"
        case 44: return "/"
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "⎋"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "Key(\(keyCode))"
        }
    }
}
