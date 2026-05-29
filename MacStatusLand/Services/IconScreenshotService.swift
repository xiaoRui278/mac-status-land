import Foundation
import AppKit
import CoreGraphics

class IconScreenshotService {
    
    private var screenshotCache: [String: NSImage] = [:]
    
    /// 截取指定位置和尺寸的屏幕区域
    func captureIcon(at position: CGPoint, size: CGSize) -> NSImage? {
        let rect = CGRect(origin: position, size: size)
        
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: size)
    }
    
    /// 截取并缓存图标
    func captureAndCache(for bundleIdentifier: String, at position: CGPoint, size: CGSize) -> NSImage? {
        if let cached = screenshotCache[bundleIdentifier] {
            return cached
        }
        
        guard let image = captureIcon(at: position, size: size) else {
            return nil
        }
        
        screenshotCache[bundleIdentifier] = image
        return image
    }
    
    /// 获取缓存的截图
    func getCachedScreenshot(for bundleIdentifier: String) -> NSImage? {
        return screenshotCache[bundleIdentifier]
    }
    
    /// 清除缓存
    func clearCache() {
        screenshotCache.removeAll()
    }
    
    /// 保存截图到文件
    func saveScreenshot(_ image: NSImage, for bundleIdentifier: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return
        }
        
        let pngData = bitmap.representation(using: .png, properties: [:])
        
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(bundleIdentifier).png")
        
        try pngData?.write(to: fileURL)
    }
    
    /// 从文件加载截图
    func loadScreenshot(for bundleIdentifier: String) -> NSImage? {
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(bundleIdentifier).png")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return NSImage(contentsOf: fileURL)
    }
    
    /// 获取缓存目录
    private func getCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDir = appSupport.appendingPathComponent("MacStatusLand/icon-cache")
        
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        return cacheDir
    }
}
