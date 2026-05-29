import Foundation

struct AppSettings: Codable {
    var launchAtLogin: Bool = true
    var autoHideOnLaunch: Bool = true
    var hiddenAppIdentifiers: Set<String> = []

    static let `default` = AppSettings()
}
