import Foundation

struct ClipboardSearchEngine {
    /// Search documents index only the head and the tail of very large texts;
    /// the classifier (4 000) and preview (180) set the precedent for capping
    /// analysed text. The tail is kept because the end of a long buffer (log
    /// output, appended notes) is a common search target.
    static let indexedHeadCharacterCount = 5_000
    static let indexedTailCharacterCount = 2_000

    /// Precomputed, normalized searchable representation of a single item.
    /// Building a document is the expensive part (folding, whitespace collapse,
    /// tag detection); matching against it is a plain substring scan.
    struct SearchDocument: Equatable, Sendable {
        let itemID: UUID
        let createdAt: Date
        let normalizedTexts: [String]
        let normalizedTagKeywords: [String]
    }

    static func makeDocument(for item: ClipboardItem) -> SearchDocument {
        SearchDocument(
            itemID: item.id,
            createdAt: item.createdAt,
            normalizedTexts: searchableTexts(for: item),
            normalizedTagKeywords: tagTexts(for: item)
        )
    }

    static func matches(for items: [ClipboardItem], query: String) -> [ClipboardItem] {
        guard normalize(query).isEmpty == false else {
            return items
        }

        let orderedIDs = matches(documents: items.map(makeDocument), query: query)
        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return orderedIDs.compactMap { itemsByID[$0] }
    }

    static func matches(documents: [SearchDocument], query: String) -> [UUID] {
        let normalizedQuery = normalize(query)
        guard normalizedQuery.isEmpty == false else {
            return documents.map(\.itemID)
        }

        let alternateQuery = normalize(KeyboardLayoutMapper.swappedLayout(for: query))

        let rankedMatches = documents.compactMap { document -> (id: UUID, createdAt: Date, score: Int)? in
            guard let bestScore = bestScore(for: document, query: normalizedQuery, alternateQuery: alternateQuery) else {
                return nil
            }

            return (document.itemID, document.createdAt, bestScore)
        }

        return rankedMatches
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }

                return left.createdAt > right.createdAt
            }
            .map(\.id)
    }

    static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestScore(for document: SearchDocument, query: String, alternateQuery: String) -> Int? {
        var bestScore: Int?

        func consider(_ candidate: Int?) {
            if let candidate, candidate > (bestScore ?? Int.min) {
                bestScore = candidate
            }
        }

        let hasAlternate = alternateQuery.isEmpty == false && alternateQuery != query

        for haystack in document.normalizedTexts {
            consider(score(for: haystack, query: query, variantPenalty: 0))

            if hasAlternate {
                consider(score(for: haystack, query: alternateQuery, variantPenalty: 350))
            }
        }

        for haystack in document.normalizedTagKeywords {
            consider(score(for: haystack, query: query, variantPenalty: 1_100))

            if hasAlternate {
                consider(score(for: haystack, query: alternateQuery, variantPenalty: 1_450))
            }
        }

        return bestScore
    }

    private static func searchableTexts(for item: ClipboardItem) -> [String] {
        var results: [String] = []

        if let text = item.text {
            let normalizedText = normalize(indexableText(text))
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

    // The space between the chunks keeps a query from matching across the seam.
    static func indexableText(_ text: String) -> String {
        guard text.count > indexedHeadCharacterCount + indexedTailCharacterCount else {
            return text
        }

        return text.prefix(indexedHeadCharacterCount) + " " + text.suffix(indexedTailCharacterCount)
    }

    private static let normalizedKeywordsByTag: [ClipboardTag: [String]] = {
        var result: [ClipboardTag: [String]] = [:]
        for tag in ClipboardTag.allCases {
            result[tag] = tag.searchKeywords.map(normalize).filter { $0.isEmpty == false }
        }
        return result
    }()

    private static func tagTexts(for item: ClipboardItem) -> [String] {
        Array(Set(item.tags.flatMap { normalizedKeywordsByTag[$0] ?? [] }))
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

        guard let firstRange = haystack.range(of: query) else {
            return nil
        }

        if let boundaryIndex = wordBoundaryMatchIndex(in: haystack, query: query, firstOccurrence: firstRange) {
            return 1_250 - variantPenalty - min(boundaryIndex, 200)
        }

        let position = haystack.distance(from: haystack.startIndex, to: firstRange.lowerBound)
        return 1_000 - variantPenalty - min(position, 250)
    }

    private static func wordBoundaryMatchIndex(
        in haystack: String,
        query: String,
        firstOccurrence: Range<String.Index>
    ) -> Int? {
        // Walk occurrences instead of every character position: the previous
        // implementation ran hasPrefix at each index, which is O(n·m) on large
        // clipboard texts.
        var occurrence: Range<String.Index>? = firstOccurrence

        while let currentOccurrence = occurrence {
            let lowerBound = currentOccurrence.lowerBound
            let previousCharacter = lowerBound == haystack.startIndex
                ? nil
                : haystack[haystack.index(before: lowerBound)]

            if isWordBoundary(previousCharacter) {
                return haystack.distance(from: haystack.startIndex, to: lowerBound)
            }

            let nextSearchStart = haystack.index(after: lowerBound)
            occurrence = haystack.range(of: query, range: nextSearchStart..<haystack.endIndex)
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
