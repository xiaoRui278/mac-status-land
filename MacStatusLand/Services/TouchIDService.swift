// MacStatusLand/MacStatusLand/Services/TouchIDService.swift

import Foundation
import LocalAuthentication

/// Touch ID 服务
class TouchIDService {
    static let shared = TouchIDService()
    
    private init() {}
    
    /// 是否可用
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// 认证
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? TouchIDError.notAvailable
        }
        
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            throw TouchIDError.authenticationFailed
        }
    }
}

/// Touch ID 错误
enum TouchIDError: LocalizedError {
    case notAvailable
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Touch ID 不可用"
        case .authenticationFailed:
            return "认证失败"
        }
    }
}
