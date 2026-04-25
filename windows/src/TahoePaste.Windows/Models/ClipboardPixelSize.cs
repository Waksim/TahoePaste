using System.Text.Json.Serialization;

namespace TahoePaste.Windows.Models;

public sealed record ClipboardPixelSize(double Width, double Height)
{
    [JsonIgnore]
    public string DisplayText => $"{Math.Round(Width):0} x {Math.Round(Height):0}";
}
