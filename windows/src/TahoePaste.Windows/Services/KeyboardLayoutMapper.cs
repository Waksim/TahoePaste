namespace TahoePaste.Windows.Services;

public static class KeyboardLayoutMapper
{
    private static readonly IReadOnlyDictionary<char, char> RuToEn = new Dictionary<char, char>
    {
        ['й'] = 'q', ['ц'] = 'w', ['у'] = 'e', ['к'] = 'r', ['е'] = 't', ['н'] = 'y', ['г'] = 'u', ['ш'] = 'i', ['щ'] = 'o', ['з'] = 'p',
        ['х'] = '[', ['ъ'] = ']', ['ф'] = 'a', ['ы'] = 's', ['в'] = 'd', ['а'] = 'f', ['п'] = 'g', ['р'] = 'h', ['о'] = 'j',
        ['л'] = 'k', ['д'] = 'l', ['ж'] = ';', ['э'] = '\'', ['я'] = 'z', ['ч'] = 'x', ['с'] = 'c', ['м'] = 'v', ['и'] = 'b',
        ['т'] = 'n', ['ь'] = 'm', ['б'] = ',', ['ю'] = '.', ['ё'] = '`'
    };

    private static readonly IReadOnlyDictionary<char, char> EnToRu = RuToEn.ToDictionary(pair => pair.Value, pair => pair.Key);

    public static string SwappedLayout(string value)
    {
        return new string(value.Select(Swap).ToArray());
    }

    private static char Swap(char character)
    {
        var lower = char.ToLowerInvariant(character);
        char mapped;

        if (RuToEn.TryGetValue(lower, out mapped) || EnToRu.TryGetValue(lower, out mapped))
        {
            return char.IsUpper(character) ? char.ToUpperInvariant(mapped) : mapped;
        }

        return character;
    }
}
