import Foundation
import SwiftUI

extension String {
    func localized(_ language: String? = nil) -> String {
        let lang = language ?? SettingsService.shared.appLanguage
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
    
    func localizedFormat(_ language: String? = nil, _ args: CVarArg...) -> String {
        let format = self.localized(language)
        return String(format: format, arguments: args)
    }
}
