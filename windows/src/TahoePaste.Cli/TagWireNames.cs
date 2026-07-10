using TahoePaste.Windows.Models;

namespace TahoePaste.Cli;

/// <summary>
/// The agent-facing wire format uses the Swift raw values (camelCase:
/// "text", "dateTime", "pdf") on both platforms, so agents see one format
/// even though each platform's history.json serializes enums differently.
/// </summary>
public static class TagWireNames
{
    public static string ToWire(ClipboardTag tag)
    {
        var name = tag.ToString();
        return char.ToLowerInvariant(name[0]) + name[1..];
    }

    public static string ToWire(ClipboardKind kind)
    {
        var name = kind.ToString();
        return char.ToLowerInvariant(name[0]) + name[1..];
    }

    public static string ToWire(ClipboardFileCategory category)
    {
        var name = category.ToString();
        return char.ToLowerInvariant(name[0]) + name[1..];
    }

    public static bool TryParseTag(string raw, out ClipboardTag tag)
    {
        foreach (var candidate in Enum.GetValues<ClipboardTag>())
        {
            if (string.Equals(ToWire(candidate), raw, StringComparison.OrdinalIgnoreCase))
            {
                tag = candidate;
                return true;
            }
        }

        tag = default;
        return false;
    }

    public static bool TryParseKind(string raw, out ClipboardKind kind)
    {
        foreach (var candidate in Enum.GetValues<ClipboardKind>())
        {
            if (string.Equals(ToWire(candidate), raw, StringComparison.OrdinalIgnoreCase))
            {
                kind = candidate;
                return true;
            }
        }

        kind = default;
        return false;
    }
}
