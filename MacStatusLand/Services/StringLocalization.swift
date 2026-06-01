import Foundation

extension String {
    var localized: String {
        let language = SettingsService.shared.appLanguage
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
    
    func localized(_ args: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: args)
    }
}
