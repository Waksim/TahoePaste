namespace TahoePaste.Windows.Models;

public enum ClipboardKind
{
    Text,
    Image,
    Link,
    Code,
    File
}

public static class ClipboardKindExtensions
{
    public static ClipboardTag PrimaryTag(this ClipboardKind kind) => kind switch
    {
        ClipboardKind.Text => ClipboardTag.Text,
        ClipboardKind.Image => ClipboardTag.Image,
        ClipboardKind.Link => ClipboardTag.Link,
        ClipboardKind.Code => ClipboardTag.Code,
        ClipboardKind.File => ClipboardTag.File,
        _ => ClipboardTag.Text
    };
}
