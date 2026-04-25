using System.Globalization;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

public static class ClipboardSearchEngine
{
    public static IReadOnlyList<ClipboardItem> Matches(IEnumerable<ClipboardItem> items, string query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return items.ToArray();
        }

        var normalizedQuery = Normalize(query);
        var alternateQuery = Normalize(KeyboardLayoutMapper.SwappedLayout(query));

        return items
            .Select(item => new { Item = item, Score = Score(item, normalizedQuery, alternateQuery) })
            .Where(entry => entry.Score > 0)
            .OrderByDescending(entry => entry.Score)
            .ThenByDescending(entry => entry.Item.CreatedAt)
            .Select(entry => entry.Item)
            .ToArray();
    }

    private static int Score(ClipboardItem item, string query, string alternateQuery)
    {
        var searchableFields = SearchableFields(item).Select(Normalize).ToArray();
        var direct = searchableFields.Any(field => field.Contains(query, StringComparison.Ordinal));
        var alternate = query != alternateQuery && searchableFields.Any(field => field.Contains(alternateQuery, StringComparison.Ordinal));

        if (direct) return 2;
        if (alternate) return 1;
        return 0;
    }

    private static IEnumerable<string> SearchableFields(ClipboardItem item)
    {
        if (item.Text is { Length: > 0 } text)
        {
            yield return text;
        }

        if (item.TextPreview is { Length: > 0 } preview)
        {
            yield return preview;
        }

        foreach (var tag in item.Tags)
        {
            yield return L10n.Tr(tag.TitleKey());

            foreach (var keyword in tag.SearchKeywords())
            {
                yield return keyword;
            }
        }

        if (item.FileReferences is not null)
        {
            foreach (var fileReference in item.FileReferences)
            {
                yield return fileReference.DisplayName;
                yield return fileReference.Path;
            }
        }
    }

    private static string Normalize(string value)
    {
        return value.Trim().ToLower(CultureInfo.InvariantCulture);
    }
}
