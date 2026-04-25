namespace TahoePaste.Windows.Models;

public enum ClipboardFileCategory
{
    Folder,
    Video,
    Audio,
    Document,
    Pdf,
    Spreadsheet,
    Presentation,
    Archive,
    Code,
    Image,
    Other
}

public static class ClipboardFileCategoryExtensions
{
    private static readonly HashSet<string> VideoExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".avi", ".m4v", ".mkv", ".mov", ".mp4", ".mpeg", ".mpg", ".webm"
    };

    private static readonly HashSet<string> AudioExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".aac", ".aiff", ".flac", ".m4a", ".mp3", ".ogg", ".wav"
    };

    private static readonly HashSet<string> ArchiveExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".7z", ".bz2", ".dmg", ".gz", ".rar", ".tar", ".tgz", ".xz", ".zip"
    };

    private static readonly HashSet<string> SpreadsheetExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".csv", ".numbers", ".ods", ".tsv", ".xls", ".xlsx"
    };

    private static readonly HashSet<string> PresentationExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".key", ".odp", ".ppt", ".pptx"
    };

    private static readonly HashSet<string> CodeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".c", ".cc", ".cpp", ".cs", ".css", ".go", ".h", ".hpp", ".html", ".java", ".js", ".json", ".kt",
        ".md", ".php", ".py", ".rb", ".rs", ".sh", ".sql", ".swift", ".toml", ".ts", ".tsx", ".xml", ".yaml", ".yml", ".zsh"
    };

    private static readonly HashSet<string> ImageExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".bmp", ".gif", ".heic", ".icns", ".jpeg", ".jpg", ".png", ".svg", ".tif", ".tiff", ".webp"
    };

    private static readonly HashSet<string> DocumentExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".doc", ".docx", ".odt", ".pages", ".rtf", ".txt"
    };

    public static IReadOnlyList<ClipboardTag> Tags(this ClipboardFileCategory category) => category switch
    {
        ClipboardFileCategory.Folder => [ClipboardTag.File, ClipboardTag.Folder],
        ClipboardFileCategory.Video => [ClipboardTag.File, ClipboardTag.Video],
        ClipboardFileCategory.Audio => [ClipboardTag.File, ClipboardTag.Audio],
        ClipboardFileCategory.Document => [ClipboardTag.File, ClipboardTag.Document],
        ClipboardFileCategory.Pdf => [ClipboardTag.File, ClipboardTag.Document, ClipboardTag.Pdf],
        ClipboardFileCategory.Spreadsheet => [ClipboardTag.File, ClipboardTag.Document, ClipboardTag.Spreadsheet],
        ClipboardFileCategory.Presentation => [ClipboardTag.File, ClipboardTag.Document, ClipboardTag.Presentation],
        ClipboardFileCategory.Archive => [ClipboardTag.File, ClipboardTag.Archive],
        ClipboardFileCategory.Code => [ClipboardTag.File, ClipboardTag.Code],
        ClipboardFileCategory.Image => [ClipboardTag.File, ClipboardTag.Image],
        _ => [ClipboardTag.File]
    };

    public static ClipboardFileCategory Detect(string path, bool isDirectory)
    {
        if (isDirectory)
        {
            return ClipboardFileCategory.Folder;
        }

        var extension = Path.GetExtension(path);

        if (VideoExtensions.Contains(extension)) return ClipboardFileCategory.Video;
        if (AudioExtensions.Contains(extension)) return ClipboardFileCategory.Audio;
        if (ArchiveExtensions.Contains(extension)) return ClipboardFileCategory.Archive;
        if (string.Equals(extension, ".pdf", StringComparison.OrdinalIgnoreCase)) return ClipboardFileCategory.Pdf;
        if (SpreadsheetExtensions.Contains(extension)) return ClipboardFileCategory.Spreadsheet;
        if (PresentationExtensions.Contains(extension)) return ClipboardFileCategory.Presentation;
        if (CodeExtensions.Contains(extension)) return ClipboardFileCategory.Code;
        if (ImageExtensions.Contains(extension)) return ClipboardFileCategory.Image;
        if (DocumentExtensions.Contains(extension)) return ClipboardFileCategory.Document;

        return ClipboardFileCategory.Other;
    }
}
