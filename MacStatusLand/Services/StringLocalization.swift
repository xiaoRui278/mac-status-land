import Foundation
import SwiftUI

extension String {
    func localized(_ language: String? = nil) -> String {
        let lang = language ?? SettingsService.shared.appLanguage
        let bundle = Bundle.main

        if let path = bundle.path(forResource: lang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return NSLocalizedString(self, tableName: nil, bundle: langBundle, comment: "")
        }
        return NSLocalizedString(self, tableName: nil, bundle: bundle, comment: "")
    }

    func localizedFormat(_ language: String? = nil, _ args: CVarArg...) -> String {
        let format = self.localized(language)
        return String(format: format, arguments: args)
    }
}
