// MacStatusLand/MacStatusLand/Services/IconCacheService.swift

import Foundation
import AppKit

/// 图标缓存服务
class IconCacheService {
    static let shared = IconCacheService()
    
    /// 缓存项
    private struct CachedIcon {
        let element: AXUIElement
        let image: NSImage?
        let cachedAt: Date
    }
    
    /// 缓存存储
    private var cache: [String: CachedIcon] = [:]
    
    /// 缓存有效期（秒）
    private let ttl: TimeInterval = 300  // 5 分钟
    
    /// 并发队列
    private let queue = DispatchQueue(label: "com.macstatusland.iconcache", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - 读取
    
    /// 获取缓存的 AXUIElement
    func getElement(bundleIdentifier: String) -> AXUIElement? {
        queue.sync {
            guard let cached = cache[bundleIdentifier] else { return nil }
            
            // 检查是否过期
            if Date().timeIntervalSince(cached.cachedAt) > ttl {
                cache.removeValue(forKey: bundleIdentifier)
                return nil
            }
            
            return cached.element
        }
    }
    
    /// 获取缓存的图标图像
    func getImage(bundleIdentifier: String) -> NSImage? {
        queue.sync {
            guard let cached = cache[bundleIdentifier] else { return nil }
            
            if Date().timeIntervalSince(cached.cachedAt) > ttl {
                cache.removeValue(forKey: bundleIdentifier)
                return nil
            }
            
            return cached.image
        }
    }
    
    // MARK: - 写入
    
    /// 缓存图标
    func set(element: AXUIElement, image: NSImage?, for bundleIdentifier: String) {
        queue.async(flags: .barrier) {
            self.cache[bundleIdentifier] = CachedIcon(
                element: element,
                image: image,
                cachedAt: Date()
            )
        }
    }
    
    // MARK: - 失效
    
    /// 失效指定图标
    func invalidate(bundleIdentifier: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: bundleIdentifier)
        }
    }
    
    /// 失效所有缓存
    func invalidateAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    // MARK: - 清理
    
    /// 清理过期缓存
    func cleanExpired() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { now.timeIntervalSince($0.value.cachedAt) <= self.ttl }
        }
    }
    
    /// 缓存大小
    var count: Int {
        queue.sync { cache.count }
    }
}
