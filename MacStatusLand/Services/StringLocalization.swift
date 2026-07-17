import Foundation
import SwiftUI

extension String {
    func localized(_ language: String? = nil) -> String {
        let lang = language ?? SettingsService.shared.appLanguage
        guard let langBundle = LocalizationBundleResolver.bundle(for: lang) else {
            return self
        }
        return NSLocalizedString(self, tableName: nil, bundle: langBundle, comment: "")
    }

    func localizedFormat(_ language: String? = nil, _ args: CVarArg...) -> String {
        let format = self.localized(language)
        return String(format: format, arguments: args)
    }
}

/// 定位本地化 bundle：兼容 `swift run`（SPM 资源包）和 `.app` 打包（Resources/ 平铺）两种场景。
private enum LocalizationBundleResolver {
    /// 缓存已解析的语言 bundle，避免每次调用重复扫盘
    private static var cache: [String: Bundle] = [:]
    private static let lock = NSLock()

    static func bundle(for language: String) -> Bundle? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[language] {
            return cached
        }

        // 候选根目录：
        // 1. Bundle.main.resourceURL —— .app 打包场景 (Contents/Resources/<lang>.lproj/)
        // 2. Bundle.main.resourceURL/MacStatusLand_MacStatusLand.bundle —— swift run 场景（SPM 生成的资源 bundle）
        // 3. Bundle.main.bundleURL —— 兜底（可执行文件同级）
        var candidates: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL)
            candidates.append(resourceURL.appendingPathComponent("MacStatusLand_MacStatusLand.bundle"))
        }
        candidates.append(Bundle.main.bundleURL)
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("MacStatusLand_MacStatusLand.bundle"))

        for root in candidates {
            let lprojURL = root.appendingPathComponent("\(language).lproj")
            if FileManager.default.fileExists(atPath: lprojURL.path),
               let bundle = Bundle(url: lprojURL) {
                cache[language] = bundle
                return bundle
            }
        }

        return nil
    }
}
