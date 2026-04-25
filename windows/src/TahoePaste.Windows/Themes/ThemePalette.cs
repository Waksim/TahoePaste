using System.Windows.Media;
using TahoePaste.Windows.Services;

namespace TahoePaste.Windows.Themes;

public sealed class ThemePalette
{
    public required Brush OverlayGradientTop { get; init; }
    public required Brush OverlayGradientBottom { get; init; }
    public required Brush OverlayEdgeHighlight { get; init; }
    public required Brush OverlayPrimaryText { get; init; }
    public required Brush OverlaySecondaryText { get; init; }
    public required Brush OverlayBubbleFill { get; init; }
    public required Brush OverlayBubbleBorder { get; init; }
    public required Brush OverlayToolbarIcon { get; init; }
    public required Brush CardGradientTop { get; init; }
    public required Brush CardGradientBottom { get; init; }
    public required Brush CardBorder { get; init; }
    public required Brush CardPrimaryText { get; init; }
    public required Brush CardSecondaryText { get; init; }
    public required Brush CardTextMetadata { get; init; }
    public required Brush CardTextTag { get; init; }
    public required Brush CardDeleteIcon { get; init; }
    public required Brush CardLinkText { get; init; }
    public required Brush ImageMetadataText { get; init; }
    public required Brush ImageTagText { get; init; }
    public required Brush ImageFallbackText { get; init; }

    public static ThemePalette For(Theme theme) => theme == Theme.Night ? Night : Day;

    private static readonly ThemePalette Day = new()
    {
        OverlayGradientTop = Brush("#F2F7FF", 0.96),
        OverlayGradientBottom = Brush("#DBE8FA", 0.99),
        OverlayEdgeHighlight = Brushes.White,
        OverlayPrimaryText = Brush("#263347"),
        OverlaySecondaryText = Brush("#4C5E7A"),
        OverlayBubbleFill = Brush("#FAFCFF", 0.96),
        OverlayBubbleBorder = Brush("#AABFE1", 0.55),
        OverlayToolbarIcon = Brush("#4F668A"),
        CardGradientTop = Brushes.White,
        CardGradientBottom = Brush("#EBF5FF"),
        CardBorder = Brush("#AABFE1", 0.65),
        CardPrimaryText = Brush("#2E384D"),
        CardSecondaryText = Brush("#637A9C"),
        CardTextMetadata = Brush("#6D85A3"),
        CardTextTag = Brush("#40618F"),
        CardDeleteIcon = Brush("#567094"),
        CardLinkText = Brush("#1C66BD"),
        ImageMetadataText = Brushes.White,
        ImageTagText = Brushes.White,
        ImageFallbackText = Brush("#567094")
    };

    private static readonly ThemePalette Night = new()
    {
        OverlayGradientTop = Brush("#141A22", 0.94),
        OverlayGradientBottom = Brush("#21262F", 0.98),
        OverlayEdgeHighlight = Brush("#FFFFFF", 0.05),
        OverlayPrimaryText = Brushes.White,
        OverlaySecondaryText = Brush("#FFFFFF", 0.68),
        OverlayBubbleFill = Brush("#292E38", 0.98),
        OverlayBubbleBorder = Brush("#FFFFFF", 0.08),
        OverlayToolbarIcon = Brush("#B8BFCB"),
        CardGradientTop = Brush("#333B4A"),
        CardGradientBottom = Brush("#1A1F29"),
        CardBorder = Brush("#FFFFFF", 0.10),
        CardPrimaryText = Brushes.White,
        CardSecondaryText = Brush("#B8BFCB"),
        CardTextMetadata = Brush("#B8BFCB"),
        CardTextTag = Brush("#E6EDF9"),
        CardDeleteIcon = Brush("#B8BFCB"),
        CardLinkText = Brush("#D6EBFF"),
        ImageMetadataText = Brushes.White,
        ImageTagText = Brushes.White,
        ImageFallbackText = Brush("#FFFFFF", 0.66)
    };

    private static SolidColorBrush Brush(string hex, double opacity = 1)
    {
        var color = (Color)ColorConverter.ConvertFromString(hex);
        var brush = new SolidColorBrush(color) { Opacity = opacity };
        brush.Freeze();
        return brush;
    }
}
