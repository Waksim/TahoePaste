import Foundation

enum KeyboardLayoutMapper {
    private static let englishCharacters = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,./")
    private static let russianCharacters = Array("ёйцукенгшщзхъфывапролджэячсмитьбю.")

    private static let englishToRussian: [Character: Character] = Dictionary(
        uniqueKeysWithValues: zip(englishCharacters, russianCharacters)
    )

    private static let russianToEnglish: [Character: Character] = Dictionary(
        uniqueKeysWithValues: zip(russianCharacters, englishCharacters)
    )

    static func swappedLayout(for text: String) -> String {
        String(
            text.map { character in
                let lowercased = Character(String(character).lowercased())

                if let mapped = englishToRussian[lowercased] {
                    return mapped
                }

                if let mapped = russianToEnglish[lowercased] {
                    return mapped
                }

                return lowercased
            }
        )
    }
}

