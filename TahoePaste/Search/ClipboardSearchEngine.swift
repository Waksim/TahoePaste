import Foundation

struct ClipboardSearchEngine {
    struct Match: Equatable {
        let item: ClipboardItem
        let score: Int
    }

    static func matches(for items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let normalizedQuery = normalize(query)
        guard normalizedQuery.isEmpty == false else {
            return items
        }

        let alternateQuery = normalize(KeyboardLayoutMapper.swappedLayout(for: query))

        let rankedMatches = items.compactMap { item -> Match? in
            guard let bestScore = bestScore(for: item, query: normalizedQuery, alternateQuery: alternateQuery) else {
                return nil
            }

            return Match(item: item, score: bestScore)
        }

        return rankedMatches
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }

                return left.item.createdAt > right.item.createdAt
            }
            .map(\.item)
    }

    static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestScore(for item: ClipboardItem, query: String, alternateQuery: String) -> Int? {
        var candidateScores: [Int] = []

        for haystack in searchableTexts(for: item) {
            if let score = score(for: haystack, query: query, variantPenalty: 0) {
                candidateScores.append(score)
            }

            if alternateQuery.isEmpty == false, alternateQuery != query,
               let score = score(for: haystack, query: alternateQuery, variantPenalty: 350) {
                candidateScores.append(score)
            }
        }

        for haystack in tagTexts(for: item) {
            if let score = score(for: haystack, query: query, variantPenalty: 1_100) {
                candidateScores.append(score)
            }

            if alternateQuery.isEmpty == false, alternateQuery != query,
               let score = score(for: haystack, query: alternateQuery, variantPenalty: 1_450) {
                candidateScores.append(score)
            }
        }

        return candidateScores.max()
    }

    private static func searchableTexts(for item: ClipboardItem) -> [String] {
        var results: [String] = []

        if let text = item.text {
            let normalizedText = normalize(text)
            if normalizedText.isEmpty == false {
                results.append(normalizedText)
            }
        }

        if let preview = item.textPreview {
            let normalizedPreview = normalize(preview)
            if normalizedPreview.isEmpty == false, results.contains(normalizedPreview) == false {
                results.append(normalizedPreview)
            }
        }

        if let fileReferences = item.fileReferences {
            for fileReference in fileReferences {
                let normalizedDisplayName = normalize(fileReference.displayName)
                if normalizedDisplayName.isEmpty == false, results.contains(normalizedDisplayName) == false {
                    results.append(normalizedDisplayName)
                }

                let normalizedPath = normalize(fileReference.path)
                if normalizedPath.isEmpty == false, results.contains(normalizedPath) == false {
                    results.append(normalizedPath)
                }
            }
        }

        return results
    }

    private static func tagTexts(for item: ClipboardItem) -> [String] {
        Array(Set(item.tags.flatMap(\.searchKeywords).map(normalize).filter { $0.isEmpty == false }))
    }

    private static func score(for haystack: String, query: String, variantPenalty: Int) -> Int? {
        guard query.isEmpty == false else {
            return nil
        }

        if haystack == query {
            return 1_800 - variantPenalty
        }

        if haystack.hasPrefix(query) {
            return 1_500 - variantPenalty
        }

        if let wordBoundaryIndex = wordBoundaryMatchIndex(in: haystack, query: query) {
            return 1_250 - variantPenalty - min(wordBoundaryIndex, 200)
        }

        if let range = haystack.range(of: query) {
            let position = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            return 1_000 - variantPenalty - min(position, 250)
        }

        return nil
    }

    private static func wordBoundaryMatchIndex(in haystack: String, query: String) -> Int? {
        var currentIndex = haystack.startIndex

        while currentIndex < haystack.endIndex {
            let previousIndex = currentIndex == haystack.startIndex ? nil : haystack.index(before: currentIndex)
            let previousCharacter = previousIndex.map { haystack[$0] }

            if isWordBoundary(previousCharacter), haystack[currentIndex...].hasPrefix(query) {
                return haystack.distance(from: haystack.startIndex, to: currentIndex)
            }

            currentIndex = haystack.index(after: currentIndex)
        }

        return nil
    }

    private static func isWordBoundary(_ character: Character?) -> Bool {
        guard let character else {
            return true
        }

        return String(character).rangeOfCharacter(from: .alphanumerics) == nil
    }
}
