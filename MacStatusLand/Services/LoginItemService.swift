// MacStatusLand/MacStatusLand/Services/LoginItemService.swift

import Foundation
import ServiceManagement

/// 启动时登录服务
class LoginItemService {
    static let shared = LoginItemService()
    
    private init() {}
    
    /// 是否已启用
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    /// 启用启动时登录
    func enable() throws {
        try SMAppService.mainApp.register()
    }
    
    /// 禁用启动时登录
    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
    
    /// 切换状态
    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
