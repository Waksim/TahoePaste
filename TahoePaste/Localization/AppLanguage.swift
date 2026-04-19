import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case russian = "ru"
    case simplifiedChinese = "zh-Hans"

    static let defaultsKey = "TahoePasteAppLanguage"

    var id: String {
        rawValue
    }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .russian:
            return Locale(identifier: "ru_RU")
        case .simplifiedChinese:
            return Locale(identifier: "zh_Hans_CN")
        }
    }

    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }

        return bundle
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    static func initial(defaults: UserDefaults) -> AppLanguage {
        if let storedValue = defaults.string(forKey: defaultsKey),
           let language = AppLanguage(rawValue: storedValue) {
            return language
        }

        return bestMatch(for: Locale.preferredLanguages)
    }

    static func bestMatch(for preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            if identifier.hasPrefix("ru") {
                return .russian
            }

            if identifier.hasPrefix("zh") {
                return .simplifiedChinese
            }

            if identifier.hasPrefix("en") {
                return .english
            }
        }

        return .english
    }
}
