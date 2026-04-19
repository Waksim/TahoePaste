import Foundation

enum ClipboardContentClassifier {
    static func classify(text: String) -> ClipboardKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return .text
        }

        if isLink(trimmed) {
            return .link
        }

        if isCode(trimmed) {
            return .code
        }

        return .text
    }

    private static func isLink(_ text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range) else {
            return false
        }

        guard match.range == range, let url = match.url else {
            return false
        }

        return url.scheme?.isEmpty == false || text.lowercased().hasPrefix("www.")
    }

    private static func isCode(_ text: String) -> Bool {
        if text.hasPrefix("```"), text.hasSuffix("```") {
            return true
        }

        let singleLineCommandPattern = #"^(git|npm|pnpm|yarn|npx|brew|curl|ssh|scp|cd|ls|cp|mv|rm|mkdir|docker|kubectl|python|python3|node|swift|xcodebuild|defaults)\b"#
        if text.range(of: singleLineCommandPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        if looksLikeStructuredPayload(text) {
            return true
        }

        let indicators = [
            "{", "}", ";", "</", "/>", "=>", "::", "func ", "let ", "var ", "const ", "import ", "return ",
            "class ", "struct ", "enum ", "SELECT ", "INSERT ", "UPDATE ", "DELETE ", "FROM ", "WHERE ",
            "#include", "def ", "elif ", "lambda ", "public ", "private ", "protocol ", "guard ", "if (", "$ "
        ]

        let matchedIndicators = indicators.reduce(into: 0) { count, indicator in
            if text.range(of: indicator, options: [.caseInsensitive, .literal]) != nil {
                count += 1
            }
        }

        let hasMultipleLines = text.contains("\n")
        if matchedIndicators >= 2, hasMultipleLines {
            return true
        }

        return matchedIndicators >= 3
    }

    private static func looksLikeStructuredPayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            return true
        }

        let xmlPattern = #"^<([A-Za-z][A-Za-z0-9:_-]*)(\s|>).*<\/\1>$"#
        return trimmed.range(of: xmlPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
