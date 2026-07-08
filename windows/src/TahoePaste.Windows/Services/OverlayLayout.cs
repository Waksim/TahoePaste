namespace TahoePaste.Windows.Services;

public sealed record OverlayLayout(
    double TopBarHeight,
    double BottomInset,
    double CardSpacing,
    double ContentPadding,
    double CardHeight,
    double TextCardWidth,
    double ImageCardWidth,
    double ToolbarIconSize,
    double ToolbarIconPadding,
    double ToolbarIconSpacing,
    double ToolbarVerticalOffset,
    double SearchBubbleWidth,
    double SearchBubbleHeight,
    double SearchBubbleHorizontalOffset,
    double SearchBubbleVerticalOffset,
    double OverlayHeight,
    double OverlayScreenHorizontalInset,
    double OverlayScreenBottomInset)
{
    public double TotalCardHeight => CardHeight + ContentPadding * 2;
    public double TotalTextCardWidth => TextCardWidth + ContentPadding * 2;
    public double TotalImageCardWidth => ImageCardWidth + ContentPadding * 2;

    // Card metrics were previously ClipboardCardControl.CardMetrics; they live
    // here now so AppSettings can derive the automatic layout from the preset.
    public static OverlayLayout Automatic(CardSizePreset preset)
    {
        var (cardWidth, cardHeight, contentPadding) = preset switch
        {
            CardSizePreset.Compact => (252d, 148d, 14d),
            CardSizePreset.Large => (320d, 188d, 18d),
            _ => (280d, 164d, 16d)
        };

        const double topBarHeight = 36;
        const double bottomInset = 16;
        var totalCardHeight = cardHeight + contentPadding * 2;

        return new OverlayLayout(
            TopBarHeight: topBarHeight,
            BottomInset: bottomInset,
            CardSpacing: 16,
            ContentPadding: contentPadding,
            CardHeight: cardHeight,
            TextCardWidth: cardWidth,
            ImageCardWidth: cardWidth,
            ToolbarIconSize: 12,
            ToolbarIconPadding: 4,
            ToolbarIconSpacing: 4,
            ToolbarVerticalOffset: 0,
            SearchBubbleWidth: 480,
            SearchBubbleHeight: 30,
            SearchBubbleHorizontalOffset: 0,
            SearchBubbleVerticalOffset: 0,
            OverlayHeight: topBarHeight + totalCardHeight + bottomInset,
            OverlayScreenHorizontalInset: 0,
            OverlayScreenBottomInset: 0);
    }
}
