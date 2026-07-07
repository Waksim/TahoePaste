using System.Globalization;
using System.Runtime.CompilerServices;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

public static class ClipboardSearchEngine
{
    // Search only scans the head and the tail of very large texts; tag
    // detection (4 000) and previews (180) set the precedent for capping
    // analysed text. The tail is kept because the end of a long buffer (log
    // output, appended notes) is a common search target.
    private const int IndexedHeadCharacterCount = 5_000;
    private const int IndexedTailCharacterCount = 2_000;

    // Items are immutable records, so their normalized searchable fields are
    // computed once per instance instead of on every keystroke.
    private static readonly ConditionalWeakTable<ClipboardItem, SearchDocument> Documents = new();

    private static readonly Dictionary<ClipboardTag, string[]> NormalizedKeywordsByTag =
        Enum.GetValues<ClipboardTag>().ToDictionary(tag => tag, tag => tag.SearchKeywords().Select(Normalize).ToArray());

    private static Dictionary<ClipboardTag, string>? _normalizedTagTitles;

    static ClipboardSearchEngine()
    {
        L10n.LanguageChanged += (_, _) => _normalizedTagTitles = null;
    }

    // Builds the per-item documents ahead of the first query; safe to call from
    // a background thread (ConditionalWeakTable is thread-safe and items are
    // immutable), so a large freshly loaded history doesn't stall the first
    // keystroke on the dispatcher thread.
    public static void WarmUp(IEnumerable<ClipboardItem> items)
    {
        foreach (var item in items)
        {
            _ = DocumentFor(item);
        }
    }

    public static IReadOnlyList<ClipboardItem> Matches(IEnumerable<ClipboardItem> items, string query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return items.ToArray();
        }

        var normalizedQuery = Normalize(query);
        var alternateQuery = Normalize(KeyboardLayoutMapper.SwappedLayout(query));

        return items
            .Select(item => new { Item = item, Score = Score(DocumentFor(item), normalizedQuery, alternateQuery) })
            .Where(entry => entry.Score > 0)
            .OrderByDescending(entry => entry.Score)
            .ThenByDescending(entry => entry.Item.CreatedAt)
            .Select(entry => entry.Item)
            .ToArray();
    }

    private sealed class SearchDocument
    {
        public required IReadOnlyList<string> NormalizedTexts { get; init; }
        public required IReadOnlyList<ClipboardTag> Tags { get; init; }
        public required IReadOnlyList<string> NormalizedTagKeywords { get; init; }
    }

    private static int Score(SearchDocument document, string query, string alternateQuery)
    {
        if (ContainsQuery(document, query))
        {
            return 2;
        }

        if (query != alternateQuery && ContainsQuery(document, alternateQuery))
        {
            return 1;
        }

        return 0;
    }

    private static bool ContainsQuery(SearchDocument document, string query)
    {
        foreach (var field in document.NormalizedTexts)
        {
            if (field.Contains(query, StringComparison.Ordinal))
            {
                return true;
            }
        }

        foreach (var keyword in document.NormalizedTagKeywords)
        {
            if (keyword.Contains(query, StringComparison.Ordinal))
            {
                return true;
            }
        }

        foreach (var tag in document.Tags)
        {
            if (NormalizedTagTitle(tag).Contains(query, StringComparison.Ordinal))
            {
                return true;
            }
        }

        return false;
    }

    private static SearchDocument DocumentFor(ClipboardItem item) => Documents.GetValue(item, CreateDocument);

    private static SearchDocument CreateDocument(ClipboardItem item)
    {
        var texts = new List<string>();

        if (item.Text is { Length: > 0 } text)
        {
            texts.Add(Normalize(IndexableText(text)));
        }

        if (item.TextPreview is { Length: > 0 } preview)
        {
            texts.Add(Normalize(preview));
        }

        if (item.FileReferences is not null)
        {
            foreach (var fileReference in item.FileReferences)
            {
                texts.Add(Normalize(fileReference.DisplayName));
                texts.Add(Normalize(fileReference.Path));
            }
        }

        var tags = item.Tags;

        return new SearchDocument
        {
            NormalizedTexts = texts,
            Tags = tags,
            NormalizedTagKeywords = tags.SelectMany(tag => NormalizedKeywordsByTag[tag]).Distinct().ToArray()
        };
    }

    // The space between the chunks keeps a query from matching across the seam.
    private static string IndexableText(string text)
    {
        if (text.Length <= IndexedHeadCharacterCount + IndexedTailCharacterCount)
        {
            return text;
        }

        return string.Concat(text.AsSpan(0, IndexedHeadCharacterCount), " ", text.AsSpan(text.Length - IndexedTailCharacterCount));
    }

    // Localized tag titles depend on the active language, so they are cached
    // separately from the documents and rebuilt after a language switch.
    private static string NormalizedTagTitle(ClipboardTag tag)
    {
        var titles = _normalizedTagTitles ??= Enum.GetValues<ClipboardTag>()
            .ToDictionary(candidate => candidate, candidate => Normalize(L10n.Tr(candidate.TitleKey())));

        return titles.TryGetValue(tag, out var title) ? title : string.Empty;
    }

    private static string Normalize(string value)
    {
        return value.Trim().ToLower(CultureInfo.InvariantCulture);
    }
}
