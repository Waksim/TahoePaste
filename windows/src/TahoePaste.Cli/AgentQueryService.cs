using System.Text.Json.Serialization;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;

namespace TahoePaste.Cli;

/// <summary>
/// Read-side of the agent CLI: querying, filtering, sensitivity gating, and
/// the JSON DTOs agents consume. Mirrors the macOS AgentQueryService so both
/// CLIs speak the same wire format.
/// </summary>
public sealed class AgentQueryService
{
    public const int DefaultLimit = 10;
    public const int MaxLimit = 100;
    public const int MaxFullTextCharacters = 200_000;

    public sealed record ItemSummary(
        Guid Id,
        string Kind,
        IReadOnlyList<string> Tags,
        DateTimeOffset CreatedAt,
        string? Preview,
        int? CharCount,
        ClipboardPixelSize? PixelSize,
        int? FileCount,
        bool IsSensitive);

    public sealed record ListResponse(
        IReadOnlyList<ItemSummary> Items,
        int TotalItems,
        int SensitiveExcluded);

    public sealed record FileInfoDto(
        string Path,
        string DisplayName,
        bool IsDirectory,
        string Category,
        long? ByteSize);

    public sealed record ItemDetail(
        Guid Id,
        string Kind,
        IReadOnlyList<string> Tags,
        DateTimeOffset CreatedAt,
        string? Preview,
        int? CharCount,
        ClipboardPixelSize? PixelSize,
        int? FileCount,
        bool IsSensitive,
        string? Text,
        bool? Truncated,
        int? TotalChars,
        string? ImagePath,
        IReadOnlyList<FileInfoDto>? Files);

    public sealed record ImageInfo(
        Guid Id,
        string ImagePath,
        ClipboardPixelSize? PixelSize);

    public sealed class QueryException : Exception
    {
        public QueryException(string code, int exitCode, string message) : base(message)
        {
            Code = code;
            ExitCode = exitCode;
        }

        public string Code { get; }
        public int ExitCode { get; }

        public static QueryException NotFound(Guid id) =>
            new("not_found", 3, $"No history item with id {id}.");

        public static QueryException Sensitive(Guid id) =>
            new("sensitive", 4, $"Item {id} looks like a password or token. Re-run with --include-sensitive to access it.");

        public static QueryException NoImage(Guid id) =>
            new("not_found", 3, $"Item {id} has no stored image.");
    }

    private readonly HistoryRepository _repository;
    private readonly StorageService _storageService;

    public AgentQueryService(HistoryRepository repository, StorageService storageService)
    {
        _repository = repository;
        _storageService = storageService;
    }

    public ListResponse Recent(int limit, bool includeSensitive)
    {
        return Search(query: "", kind: null, tag: null, since: null, limit, includeSensitive);
    }

    public ListResponse Search(
        string query,
        ClipboardKind? kind,
        ClipboardTag? tag,
        DateTimeOffset? since,
        int limit,
        bool includeSensitive)
    {
        IEnumerable<ClipboardItem> candidates = _repository.ReadSnapshot();

        if (since is { } sinceDate)
        {
            candidates = candidates.Where(item => item.CreatedAt >= sinceDate);
        }

        if (kind is { } kindFilter)
        {
            candidates = candidates.Where(item => item.Kind == kindFilter);
        }

        if (tag is { } tagFilter)
        {
            candidates = candidates.Where(item => item.Tags.Contains(tagFilter));
        }

        var materialized = candidates.ToArray();
        var matched = string.IsNullOrEmpty(query)
            ? materialized
            : ClipboardSearchEngine.Matches(materialized, query);

        var visible = includeSensitive ? matched : matched.Where(item => IsSensitive(item) == false).ToArray();
        var clampedLimit = Math.Min(Math.Max(limit, 1), MaxLimit);

        return new ListResponse(
            visible.Take(clampedLimit).Select(Summary).ToArray(),
            visible.Count,
            matched.Count - visible.Count);
    }

    public ItemDetail Detail(Guid id, bool full, bool includeSensitive)
    {
        var item = Item(id);
        EnsureAccessible(item, includeSensitive);

        string? text = null;
        bool? truncated = null;
        int? totalChars = null;
        string? imagePath = null;
        IReadOnlyList<FileInfoDto>? files = null;

        if (full)
        {
            if (item.Text is { } fullText)
            {
                if (fullText.Length > MaxFullTextCharacters)
                {
                    text = fullText[..MaxFullTextCharacters];
                    truncated = true;
                    totalChars = fullText.Length;
                }
                else
                {
                    text = fullText;
                }
            }

            imagePath = _storageService.ImagePath(item);
            files = item.FileReferences?
                .Select(reference => new FileInfoDto(
                    reference.Path,
                    reference.DisplayName,
                    reference.IsDirectory,
                    TagWireNames.ToWire(reference.Category),
                    reference.ByteSize))
                .ToArray();
        }

        var summary = Summary(item);
        return new ItemDetail(
            summary.Id,
            summary.Kind,
            summary.Tags,
            summary.CreatedAt,
            summary.Preview,
            summary.CharCount,
            summary.PixelSize,
            summary.FileCount,
            summary.IsSensitive,
            text,
            truncated,
            totalChars,
            imagePath,
            files);
    }

    public ImageInfo GetImageInfo(Guid id)
    {
        var item = Item(id);

        if (_storageService.ImagePath(item) is not { } imagePath)
        {
            throw QueryException.NoImage(id);
        }

        return new ImageInfo(item.Id, imagePath, item.PixelSize);
    }

    public ClipboardItem Item(Guid id)
    {
        return _repository.ReadSnapshot().FirstOrDefault(item => item.Id == id)
            ?? throw QueryException.NotFound(id);
    }

    /// <summary>
    /// Single-item access gate for get/copy. Persisted tags only cover the
    /// first 4000 characters, so the full text is re-scanned here.
    /// </summary>
    public void EnsureAccessible(ClipboardItem item, bool includeSensitive)
    {
        if (includeSensitive)
        {
            return;
        }

        if (IsSensitive(item))
        {
            throw QueryException.Sensitive(item.Id);
        }

        if (item.Text is { } text && ClipboardContentClassifier.ContainsSensitiveContentInFullText(text))
        {
            throw QueryException.Sensitive(item.Id);
        }
    }

    public static bool IsSensitive(ClipboardItem item)
    {
        var tags = item.Tags;
        return tags.Contains(ClipboardTag.Password) || tags.Contains(ClipboardTag.Token);
    }

    public static ItemSummary Summary(ClipboardItem item)
    {
        var isTextLike = item.Kind is ClipboardKind.Text or ClipboardKind.Link or ClipboardKind.Code;

        string? preview = item.Kind switch
        {
            ClipboardKind.Text or ClipboardKind.Link or ClipboardKind.Code =>
                item.TextPreview ?? (item.Text is { } text ? ClipboardItem.PreviewText(text) : null),
            ClipboardKind.File =>
                item.FileReferences is { } references ? ClipboardItem.FilePreview(references) : null,
            _ => null
        };

        return new ItemSummary(
            item.Id,
            TagWireNames.ToWire(item.Kind),
            item.Tags.Select(TagWireNames.ToWire).ToArray(),
            item.CreatedAt,
            preview,
            isTextLike ? item.CharacterCount : null,
            item.PixelSize,
            item.IsFile ? item.FileCount : null,
            IsSensitive(item));
    }

    /// <summary>
    /// Accepts ISO8601 timestamps or relative offsets like 30m, 2h, 7d.
    /// </summary>
    public static DateTimeOffset? ParseSince(string raw, DateTimeOffset? now = null)
    {
        if (DateTimeOffset.TryParse(raw, out var parsed))
        {
            return parsed;
        }

        var reference = now ?? DateTimeOffset.Now;

        if (raw.Length < 2 || double.TryParse(raw[..^1], out var value) == false)
        {
            return null;
        }

        return raw[^1] switch
        {
            'm' => reference.AddMinutes(-value),
            'h' => reference.AddHours(-value),
            'd' => reference.AddDays(-value),
            _ => null
        };
    }
}
