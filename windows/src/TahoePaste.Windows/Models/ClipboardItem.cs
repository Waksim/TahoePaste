using System.Globalization;
using System.Text.Json.Serialization;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Services;

namespace TahoePaste.Windows.Models;

public sealed record ClipboardItem(
    Guid Id,
    ClipboardKind Kind,
    DateTimeOffset CreatedAt,
    string? Text,
    string? TextPreview,
    string? ImageFilename,
    ClipboardPixelSize? PixelSize,
    IReadOnlyList<ClipboardFileReference>? FileReferences)
{
    [JsonIgnore]
    public bool IsText => Kind == ClipboardKind.Text;

    [JsonIgnore]
    public bool IsImage => Kind == ClipboardKind.Image;

    [JsonIgnore]
    public bool IsLink => Kind == ClipboardKind.Link;

    [JsonIgnore]
    public bool IsCode => Kind == ClipboardKind.Code;

    [JsonIgnore]
    public bool IsFile => Kind == ClipboardKind.File;

    [JsonIgnore]
    public bool UsesTextCardLayout => IsImage == false;

    [JsonIgnore]
    public int CharacterCount => Text?.Length ?? 0;

    [JsonIgnore]
    public int FileCount => FileReferences?.Count ?? 0;

    [JsonIgnore]
    public IReadOnlyList<ClipboardTag> Tags
    {
        get
        {
            var tags = new List<ClipboardTag> { Kind.PrimaryTag() };

            if (Kind != ClipboardKind.File && Text is { Length: > 0 } text)
            {
                foreach (var tag in ClipboardContentClassifier.DetectedTags(text))
                {
                    if (tags.Contains(tag) == false)
                    {
                        tags.Add(tag);
                    }
                }
            }

            if (FileReferences is not null)
            {
                foreach (var reference in FileReferences)
                {
                    foreach (var tag in reference.Category.Tags())
                    {
                        if (tags.Contains(tag) == false)
                        {
                            tags.Add(tag);
                        }
                    }
                }
            }

            return tags;
        }
    }

    [JsonIgnore]
    public IReadOnlyList<ClipboardTag> DisplayTags => Tags.Count <= 3 ? Tags : Tags.Take(3).ToArray();

    [JsonIgnore]
    public string DisplayPreviewText
    {
        get
        {
            if (IsFile && FileReferences is { Count: > 0 } fileReferences)
            {
                return FilePreview(fileReferences);
            }

            return TextPreview ?? Text ?? L10n.Tr("card.no_text_preview");
        }
    }

    public string? MetadataText(CultureInfo culture)
    {
        return Kind switch
        {
            ClipboardKind.File => FileMetadataText(culture),
            ClipboardKind.Text or ClipboardKind.Link or ClipboardKind.Code => L10n.Tr("unit.characters", CharacterCount),
            ClipboardKind.Image => PixelSize?.DisplayText ?? L10n.Tr("card.image"),
            _ => null
        };
    }

    public string TimestampText(CultureInfo culture) => CreatedAt.LocalDateTime.ToString("HH:mm", culture);

    public static string PreviewText(string text, int maxLength = 180)
    {
        var collapsed = string.Join(" ", text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (collapsed.Length <= maxLength)
        {
            return collapsed;
        }

        return collapsed[..maxLength].Trim() + "...";
    }

    public static string FilePreview(IReadOnlyList<ClipboardFileReference> fileReferences, int maxVisibleNames = 3)
    {
        var names = fileReferences.Take(maxVisibleNames).Select(reference => reference.DisplayName).ToList();
        var remainingCount = fileReferences.Count - names.Count;

        if (remainingCount > 0)
        {
            names.Add(L10n.Tr("card.more_files", remainingCount));
        }

        return string.Join(Environment.NewLine, names);
    }

    public static string FormatByteCount(long byteCount, CultureInfo culture)
    {
        var bytes = Math.Max(byteCount, 0);
        const double kilobyte = 1024d;
        const double megabyte = kilobyte * 1024d;
        const double gigabyte = megabyte * 1024d;

        double value;
        string unit;

        if (bytes >= gigabyte)
        {
            value = bytes / gigabyte;
            unit = "GB";
        }
        else if (bytes >= megabyte)
        {
            value = bytes / megabyte;
            unit = "MB";
        }
        else if (bytes >= kilobyte)
        {
            value = bytes / kilobyte;
            unit = "KB";
        }
        else
        {
            value = bytes;
            unit = "B";
        }

        var decimals = unit == "B" ? 0 : 1;
        return $"{value.ToString($"N{decimals}", culture)} {unit}";
    }

    private string? FileMetadataText(CultureInfo culture)
    {
        if (FileReferences is not { Count: > 0 } fileReferences)
        {
            return null;
        }

        var knownByteSizes = fileReferences.Select(reference => reference.ByteSize).Where(size => size.HasValue).Select(size => size!.Value).ToArray();
        var totalByteSize = knownByteSizes.Sum();

        if (fileReferences.Count == 1)
        {
            if (fileReferences[0].ByteSize is { } byteSize)
            {
                return FormatByteCount(byteSize, culture);
            }

            return fileReferences[0].IsDirectory ? L10n.Tr("card.folder") : L10n.Tr("card.file");
        }

        var countText = L10n.Tr("unit.files", fileReferences.Count);
        return totalByteSize > 0 ? $"{countText} · {FormatByteCount(totalByteSize, culture)}" : countText;
    }
}
