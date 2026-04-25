using System.Windows.Media.Imaging;

namespace TahoePaste.Windows.Models;

public enum ClipboardPayloadKind
{
    Text,
    Image,
    FileUrls
}

public sealed record ClipboardPayload(
    ClipboardPayloadKind PayloadKind,
    string? Text = null,
    BitmapSource? Image = null,
    IReadOnlyList<string>? FilePaths = null)
{
    public static ClipboardPayload FromText(string text) => new(ClipboardPayloadKind.Text, Text: text);

    public static ClipboardPayload FromImage(BitmapSource image) => new(ClipboardPayloadKind.Image, Image: image);

    public static ClipboardPayload FromFiles(IReadOnlyList<string> paths) => new(ClipboardPayloadKind.FileUrls, FilePaths: paths);
}
