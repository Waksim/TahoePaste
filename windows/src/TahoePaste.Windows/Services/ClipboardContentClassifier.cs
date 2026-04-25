using System.Text.RegularExpressions;
using TahoePaste.Windows.Models;

namespace TahoePaste.Windows.Services;

public static partial class ClipboardContentClassifier
{
    public static ClipboardKind Classify(string text)
    {
        if (LooksLikeLink(text))
        {
            return ClipboardKind.Link;
        }

        if (LooksLikeCode(text))
        {
            return ClipboardKind.Code;
        }

        return ClipboardKind.Text;
    }

    public static IReadOnlyList<ClipboardTag> DetectedTags(string text)
    {
        var tags = new List<ClipboardTag>();

        AddIf(tags, ClipboardTag.Link, LooksLikeLink(text));
        AddIf(tags, ClipboardTag.Code, LooksLikeCode(text));
        AddIf(tags, ClipboardTag.Email, EmailRegex().IsMatch(text));
        AddIf(tags, ClipboardTag.Phone, PhoneRegex().IsMatch(text));
        AddIf(tags, ClipboardTag.Password, PasswordContextRegex().IsMatch(text));
        AddIf(tags, ClipboardTag.Token, LooksLikeToken(text));
        AddIf(tags, ClipboardTag.DateTime, DateRegex().IsMatch(text));
        AddIf(tags, ClipboardTag.Address, AddressRegex().IsMatch(text));

        return tags;
    }

    private static void AddIf(List<ClipboardTag> tags, ClipboardTag tag, bool condition)
    {
        if (condition && tags.Contains(tag) == false)
        {
            tags.Add(tag);
        }
    }

    private static bool LooksLikeLink(string text)
    {
        var trimmed = text.Trim();
        return Uri.TryCreate(trimmed, UriKind.Absolute, out var uri)
            && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeFtp)
            || UrlRegex().IsMatch(trimmed);
    }

    private static bool LooksLikeCode(string text)
    {
        if (text.Length < 8)
        {
            return false;
        }

        var codeSignals = new[]
        {
            "function ", "const ", "let ", "var ", "class ", "struct ", "enum ", "SELECT ", "INSERT ", "UPDATE ", "DELETE ",
            "FROM ", "WHERE ", "import ", "using ", "#include", "public ", "private ", "return ", "=>", "fn ", "def ", "{", "};"
        };

        var signalCount = codeSignals.Count(signal => text.Contains(signal, StringComparison.Ordinal));
        var lineCount = text.Count(character => character == '\n') + 1;
        var punctuationDensity = text.Count(character => "{}[]();=<>".Contains(character)) / Math.Max(text.Length, 1d);

        return signalCount >= 2 || (lineCount >= 3 && signalCount >= 1) || punctuationDensity > 0.06;
    }

    private static bool LooksLikeToken(string text)
    {
        return TokenContextRegex().IsMatch(text)
            || BearerTokenRegex().IsMatch(text)
            || JwtRegex().IsMatch(text)
            || PrefixedTokenRegex().IsMatch(text)
            || HexSecretRegex().IsMatch(text);
    }

    [GeneratedRegex(@"https?://[^\s<>()]+", RegexOptions.IgnoreCase | RegexOptions.Compiled)]
    private static partial Regex UrlRegex();

    [GeneratedRegex(@"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", RegexOptions.IgnoreCase | RegexOptions.Compiled)]
    private static partial Regex EmailRegex();

    [GeneratedRegex(@"(?<!\w)(?:\+?\d[\d\s().-]{7,}\d)(?!\w)", RegexOptions.Compiled)]
    private static partial Regex PhoneRegex();

    [GeneratedRegex(@"(?i)\b(pass(word)?|pwd|secret|пароль|ключ)\b\s*[:=]")]
    private static partial Regex PasswordContextRegex();

    [GeneratedRegex(@"(?i)\b(token|api[_-]?key|access[_-]?key|bearer|credential|токен|секрет)\b")]
    private static partial Regex TokenContextRegex();

    [GeneratedRegex(@"(?i)\bbearer\s+[a-z0-9._~+/=-]{20,}\b")]
    private static partial Regex BearerTokenRegex();

    [GeneratedRegex(@"\beyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\b")]
    private static partial Regex JwtRegex();

    [GeneratedRegex(@"\b(?:sk|pk|ghp|github_pat|xoxb|xoxp|AKIA)[a-zA-Z0-9_\-]{16,}\b")]
    private static partial Regex PrefixedTokenRegex();

    [GeneratedRegex(@"\b[a-fA-F0-9]{32,}\b")]
    private static partial Regex HexSecretRegex();

    [GeneratedRegex(@"\b(?:\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\d{4}-\d{2}-\d{2})(?:\s+\d{1,2}:\d{2})?\b")]
    private static partial Regex DateRegex();

    [GeneratedRegex(@"(?i)\b(street|st\.|avenue|ave\.|road|rd\.|ул\.|улица|проспект|дом|квартира)\b")]
    private static partial Regex AddressRegex();
}
