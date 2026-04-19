import Foundation

enum ClipboardContentClassifier {
    static func classify(text: String) -> ClipboardKind {
        let trimmed = trimmedText(text)
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

    static func detectedTags(for text: String) -> [ClipboardTag] {
        let analyzedText = analysisText(text)
        guard analyzedText.isEmpty == false else {
            return []
        }

        let tokenDetected = containsToken(analyzedText)
        let passwordDetected = containsPassword(analyzedText, tokenDetected: tokenDetected)
        var tags: [ClipboardTag] = []

        if passwordDetected {
            tags.append(.password)
        }

        if tokenDetected {
            tags.append(.token)
        }

        if containsEmail(analyzedText) {
            tags.append(.email)
        }

        if containsPhoneNumber(analyzedText) {
            tags.append(.phone)
        }

        if containsDate(analyzedText) {
            tags.append(.dateTime)
        }

        if containsAddress(analyzedText) {
            tags.append(.address)
        }

        return tags
    }

    private static let maxAnalyzedCharacterCount = 4_000
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let phoneDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    private static let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private static let addressDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)

    private static let emailRegex = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    private static let passwordContextRegex = try? NSRegularExpression(
        pattern: #"(?:password|passcode|passwd|pwd|парол(?:ь|я)|密码)\s*(?:[:=]\s*|\bis\b\s+)\S{4,}"#,
        options: [.caseInsensitive]
    )
    private static let tokenContextRegex = try? NSRegularExpression(
        pattern: #"(?:api(?:\s+|_|-)?key|access(?:\s+|_|-)?token|refresh(?:\s+|_|-)?token|auth(?:orization)?(?:\s+|_|-)?token|client(?:\s+|_|-)?secret|session(?:\s+|_|-)?token|private(?:\s+|_|-)?key|secret|token|токен|секрет|ключ|令牌|密钥)\s*(?:[:=]\s*|\bis\b\s+)\S{8,}"#,
        options: [.caseInsensitive]
    )
    private static let bearerTokenRegex = try? NSRegularExpression(
        pattern: #"bearer\s+[A-Za-z0-9._\-]{8,}"#,
        options: [.caseInsensitive]
    )
    private static let jwtRegex = try? NSRegularExpression(
        pattern: #"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"#
    )
    private static let prefixedTokenRegex = try? NSRegularExpression(
        pattern: #"\b(?:sk|pk|rk|ghp|gho|ghu|ghs|ghr|xox[baprs])_[A-Za-z0-9_\-]{10,}\b|\bgithub_pat_[A-Za-z0-9_]{20,}\b|\bAIza[0-9A-Za-z\-_]{20,}\b"#,
        options: [.caseInsensitive]
    )
    private static let likelyFileNameRegex = try? NSRegularExpression(
        pattern: #"^[^/\n]+\.[A-Za-z0-9]{2,6}$"#,
        options: [.caseInsensitive]
    )
    private static let hexadecimalSecretRegex = try? NSRegularExpression(
        pattern: #"^[A-F0-9]{16,}$"#,
        options: [.caseInsensitive]
    )
    private static let strongPasswordSymbolCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()_+=[]{}|:;\",<>?/`~\\")

    private static func isLink(_ text: String) -> Bool {
        guard let detector = linkDetector else {
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

    private static func containsEmail(_ text: String) -> Bool {
        containsMatch(of: emailRegex, in: text)
    }

    private static func containsPhoneNumber(_ text: String) -> Bool {
        guard let detector = phoneDetector else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: range).contains { match in
            guard let phoneNumber = match.phoneNumber else {
                return false
            }

            let digits = phoneNumber.filter(\.isNumber)
            return digits.count >= 7
        }
    }

    private static func containsDate(_ text: String) -> Bool {
        containsDataDetectionMatch(of: dateDetector, in: text)
    }

    private static func containsAddress(_ text: String) -> Bool {
        containsDataDetectionMatch(of: addressDetector, in: text)
    }

    private static func containsPassword(_ text: String, tokenDetected: Bool) -> Bool {
        if containsMatch(of: passwordContextRegex, in: text) {
            return true
        }

        if tokenDetected {
            return false
        }

        return looksLikeStandalonePassword(text)
    }

    private static func containsToken(_ text: String) -> Bool {
        containsMatch(of: tokenContextRegex, in: text)
            || containsMatch(of: bearerTokenRegex, in: text)
            || containsMatch(of: jwtRegex, in: text)
            || containsMatch(of: prefixedTokenRegex, in: text)
    }

    private static func looksLikeStructuredPayload(_ text: String) -> Bool {
        let trimmed = trimmedText(text)

        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            return true
        }

        let xmlPattern = #"^<([A-Za-z][A-Za-z0-9:_-]*)(\s|>).*<\/\1>$"#
        return trimmed.range(of: xmlPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func looksLikeStandalonePassword(_ text: String) -> Bool {
        let trimmed = trimmedText(text)

        guard trimmed.count >= 8, trimmed.count <= 64 else {
            return false
        }

        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return false
        }

        guard trimmed.contains("/") == false, trimmed.contains("\\") == false else {
            return false
        }

        guard isLink(trimmed) == false else {
            return false
        }

        guard containsEmail(trimmed) == false, containsPhoneNumber(trimmed) == false else {
            return false
        }

        guard containsMatch(of: likelyFileNameRegex, in: trimmed) == false else {
            return false
        }

        guard containsMatch(of: hexadecimalSecretRegex, in: trimmed) == false else {
            return false
        }

        let hasUppercase = trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbol = trimmed.rangeOfCharacter(from: strongPasswordSymbolCharacterSet) != nil

        return hasUppercase && hasLowercase && hasDigit && hasSymbol
    }

    private static func containsDataDetectionMatch(of detector: NSDataDetector?, in text: String) -> Bool {
        guard let detector else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func containsMatch(of regex: NSRegularExpression?, in text: String) -> Bool {
        guard let regex else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func analysisText(_ text: String) -> String {
        let trimmed = trimmedText(text)
        guard trimmed.count > maxAnalyzedCharacterCount else {
            return trimmed
        }

        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxAnalyzedCharacterCount)
        return String(trimmed[..<endIndex])
    }
}
