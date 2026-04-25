using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Media.Imaging;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

public sealed class StorageService
{
    private readonly AppPaths _paths;
    private readonly JsonSerializerOptions _jsonOptions;

    public StorageService(AppPaths paths)
    {
        _paths = paths;
        _jsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            Converters = { new JsonStringEnumConverter() }
        };
    }

    public string RootDirectory => _paths.RootDirectory;

    public IReadOnlyList<ClipboardItem> LoadHistory()
    {
        _paths.Ensure();

        if (File.Exists(_paths.HistoryPath) == false)
        {
            return [];
        }

        var json = File.ReadAllText(_paths.HistoryPath);
        var decoded = JsonSerializer.Deserialize<List<ClipboardItem>>(json, _jsonOptions) ?? [];
        var cleaned = decoded
            .Where(item => item.IsImage == false || ImagePath(item) is { } path && File.Exists(path))
            .OrderByDescending(item => item.CreatedAt)
            .ToArray();

        RemoveOrphanedImages(cleaned);

        if (cleaned.Length != decoded.Count)
        {
            SaveHistory(cleaned);
        }

        return cleaned;
    }

    public void SaveHistory(IReadOnlyList<ClipboardItem> items)
    {
        _paths.Ensure();

        var tempPath = _paths.HistoryPath + ".tmp";
        var json = JsonSerializer.Serialize(items, _jsonOptions);
        File.WriteAllText(tempPath, json);
        File.Move(tempPath, _paths.HistoryPath, overwrite: true);
        RemoveOrphanedImages(items);
    }

    public ClipboardItem Store(ClipboardPayload payload)
    {
        _paths.Ensure();

        return payload.PayloadKind switch
        {
            ClipboardPayloadKind.Text => StoreText(payload.Text ?? string.Empty),
            ClipboardPayloadKind.Image => StoreImage(payload.Image ?? throw new InvalidOperationException("Missing image payload.")),
            ClipboardPayloadKind.FileUrls => StoreFiles(payload.FilePaths ?? []),
            _ => throw new InvalidOperationException("Unsupported clipboard payload.")
        };
    }

    public BitmapImage? LoadImage(ClipboardItem item)
    {
        var path = ImagePath(item);
        if (path is null || File.Exists(path) == false)
        {
            return null;
        }

        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.UriSource = new Uri(path, UriKind.Absolute);
        image.EndInit();
        image.Freeze();
        return image;
    }

    public string? ImagePath(ClipboardItem item)
    {
        return item.ImageFilename is null ? null : Path.Combine(_paths.ImagesDirectory, item.ImageFilename);
    }

    public void ClearHistory()
    {
        SaveHistory([]);
    }

    public long StorageUsageBytes()
    {
        _paths.Ensure();

        return Directory.EnumerateFiles(_paths.RootDirectory, "*", SearchOption.AllDirectories)
            .Select(path => new FileInfo(path).Length)
            .Sum();
    }

    public string FormattedStorageUsage()
    {
        var culture = L10n.Language.Culture();
        return ClipboardItem.FormatByteCount(StorageUsageBytes(), culture);
    }

    public void RevealInExplorer()
    {
        _paths.Ensure();
        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = $"\"{_paths.RootDirectory}\"",
            UseShellExecute = true
        });
    }

    private ClipboardItem StoreText(string text)
    {
        var kind = ClipboardContentClassifier.Classify(text);
        return new ClipboardItem(
            Guid.NewGuid(),
            kind,
            DateTimeOffset.Now,
            text,
            ClipboardItem.PreviewText(text),
            null,
            null,
            null);
    }

    private ClipboardItem StoreImage(BitmapSource image)
    {
        var filename = $"{Guid.NewGuid():N}.png";
        var path = Path.Combine(_paths.ImagesDirectory, filename);

        using (var stream = File.Create(path))
        {
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(image));
            encoder.Save(stream);
        }

        return new ClipboardItem(
            Guid.NewGuid(),
            ClipboardKind.Image,
            DateTimeOffset.Now,
            null,
            null,
            filename,
            new ClipboardPixelSize(image.PixelWidth, image.PixelHeight),
            null);
    }

    private ClipboardItem StoreFiles(IReadOnlyList<string> paths)
    {
        var references = paths
            .Where(path => File.Exists(path) || Directory.Exists(path))
            .Select(FileReference)
            .ToArray();

        return new ClipboardItem(
            Guid.NewGuid(),
            ClipboardKind.File,
            DateTimeOffset.Now,
            string.Join(Environment.NewLine, references.Select(reference => reference.Path)),
            null,
            null,
            null,
            references);
    }

    private static ClipboardFileReference FileReference(string path)
    {
        var isDirectory = Directory.Exists(path);
        var displayName = Path.GetFileName(path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        long? byteSize = null;

        if (isDirectory == false && File.Exists(path))
        {
            byteSize = new FileInfo(path).Length;
        }

        return new ClipboardFileReference(
            path,
            string.IsNullOrEmpty(displayName) ? path : displayName,
            isDirectory,
            ClipboardFileCategoryExtensions.Detect(path, isDirectory),
            byteSize);
    }

    private void RemoveOrphanedImages(IReadOnlyList<ClipboardItem> items)
    {
        _paths.Ensure();

        var referenced = items
            .Select(item => item.ImageFilename)
            .Where(filename => string.IsNullOrWhiteSpace(filename) == false)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        foreach (var path in Directory.EnumerateFiles(_paths.ImagesDirectory))
        {
            if (referenced.Contains(Path.GetFileName(path)) == false)
            {
                TryDelete(path);
            }
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch
        {
            // Cleanup is best-effort; stale files should not break clipboard capture.
        }
    }
}
