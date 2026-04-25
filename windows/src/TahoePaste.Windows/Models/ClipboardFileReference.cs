namespace TahoePaste.Windows.Models;

public sealed record ClipboardFileReference(
    string Path,
    string DisplayName,
    bool IsDirectory,
    ClipboardFileCategory Category,
    long? ByteSize);
