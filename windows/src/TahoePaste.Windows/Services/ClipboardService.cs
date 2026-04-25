using System.Collections.Specialized;
using System.Windows;
using System.Windows.Media.Imaging;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

public sealed class ClipboardService
{
    public ClipboardPayload? ReadSupportedPayload(AppSettings settings)
    {
        try
        {
            if (Clipboard.ContainsFileDropList())
            {
                var files = Clipboard.GetFileDropList()
                    .Cast<string>()
                    .Where(path => File.Exists(path) || Directory.Exists(path))
                    .ToArray();

                if (files.Length > 0)
                {
                    return ClipboardPayload.FromFiles(files);
                }
            }

            if (settings.CaptureImages && Clipboard.ContainsImage())
            {
                var image = Clipboard.GetImage();
                if (image is not null)
                {
                    image.Freeze();
                    return ClipboardPayload.FromImage(image);
                }
            }

            if (settings.CaptureText && Clipboard.ContainsText())
            {
                var text = Clipboard.GetText();
                if (string.IsNullOrEmpty(text) == false)
                {
                    return ClipboardPayload.FromText(text);
                }
            }
        }
        catch
        {
            return null;
        }

        return null;
    }

    public void WriteItem(ClipboardItem item, StorageService storageService)
    {
        switch (item.Kind)
        {
            case ClipboardKind.Text:
            case ClipboardKind.Link:
            case ClipboardKind.Code:
                if (string.IsNullOrEmpty(item.Text))
                {
                    throw new InvalidOperationException("Selected item has no text payload.");
                }

                var textData = new DataObject();
                textData.SetText(item.Text);
                Clipboard.SetDataObject(textData, true);
                return;

            case ClipboardKind.Image:
                var image = storageService.LoadImage(item)
                    ?? throw new InvalidOperationException("Selected item has no image payload.");
                var imageData = new DataObject();
                imageData.SetImage(image);
                Clipboard.SetDataObject(imageData, true);
                return;

            case ClipboardKind.File:
                if (item.FileReferences is not { Count: > 0 })
                {
                    throw new InvalidOperationException("Selected item has no file payload.");
                }

                var fileDropList = new StringCollection();
                foreach (var reference in item.FileReferences)
                {
                    if (File.Exists(reference.Path) || Directory.Exists(reference.Path))
                    {
                        fileDropList.Add(reference.Path);
                    }
                }

                if (fileDropList.Count == 0)
                {
                    throw new InvalidOperationException("Selected files no longer exist.");
                }

                var fileData = new DataObject();
                fileData.SetFileDropList(fileDropList);
                Clipboard.SetDataObject(fileData, true);
                return;

            default:
                throw new InvalidOperationException("Unsupported clipboard item kind.");
        }
    }
}
