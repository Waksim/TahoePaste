import Foundation

enum L10n {
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let language = currentLanguage()
        let format = NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: language.bundle,
            value: key,
            comment: ""
        )

        guard arguments.isEmpty == false else {
            return format
        }

        return String(format: format, locale: language.locale, arguments: arguments)
    }

    private static func currentLanguage() -> AppLanguage {
        let defaults = UserDefaults.standard

        if let storedValue = defaults.string(forKey: AppLanguage.defaultsKey),
           let language = AppLanguage(rawValue: storedValue) {
            return language
        }

        return AppLanguage.bestMatch(for: Locale.preferredLanguages)
    }
}
