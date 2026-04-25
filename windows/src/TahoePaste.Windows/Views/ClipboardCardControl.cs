using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;
using TahoePaste.Windows.Themes;

namespace TahoePaste.Windows.Views;

public sealed class ClipboardCardControl : Border
{
    private readonly ClipboardItem _item;

    public ClipboardCardControl(
        ClipboardItem item,
        BitmapImage? image,
        AppSettings settings,
        ClipboardTag? activeTagFilter)
    {
        _item = item;
        var palette = ThemePalette.For(settings.ActiveTheme);
        var metrics = CardMetrics.For(settings.CardSizePreset);

        Width = metrics.TotalCardWidth;
        Height = metrics.TotalCardHeight;
        CornerRadius = new CornerRadius(Math.Max(settings.CornerRadiusIntensity, 10));
        ClipToBounds = true;
        Background = Gradient(palette.CardGradientTop, palette.CardGradientBottom);
        BorderBrush = palette.CardBorder;
        BorderThickness = new Thickness(1);
        Margin = new Thickness(0, 0, 16, 0);
        Effect = new System.Windows.Media.Effects.DropShadowEffect
        {
            BlurRadius = 12,
            ShadowDepth = 4,
            Opacity = 0.18
        };
        Cursor = Cursors.Hand;

        Child = item.IsImage
            ? BuildImageCard(item, image, settings, palette, metrics, activeTagFilter)
            : BuildTextCard(item, settings, palette, metrics, activeTagFilter);

        MouseLeftButtonUp += (_, args) =>
        {
            if (IsInsideButton(args.OriginalSource as DependencyObject))
            {
                return;
            }

            SelectRequested?.Invoke(_item);
        };
    }

    public event Action<ClipboardItem>? SelectRequested;
    public event Action<ClipboardItem>? DeleteRequested;
    public event Action<ClipboardTag>? TagRequested;

    private Grid BuildTextCard(
        ClipboardItem item,
        AppSettings settings,
        ThemePalette palette,
        CardMetrics metrics,
        ClipboardTag? activeTagFilter)
    {
        var grid = RootGrid();
        var body = new StackPanel
        {
            Margin = new Thickness(metrics.Padding, metrics.Padding, metrics.Padding, metrics.Padding * 0.55)
        };

        body.Children.Add(Header(item, settings, palette, item.MetadataText(settings.AppLanguage.Culture()), isImage: false));
        body.Children.Add(new TextBlock
        {
            Text = item.DisplayPreviewText,
            FontFamily = new FontFamily(item.IsCode ? "Cascadia Mono, Consolas" : "Segoe UI Variable, Segoe UI"),
            FontSize = item.IsCode ? metrics.TextFontSize - 1 : metrics.TextFontSize,
            FontWeight = FontWeights.Medium,
            Foreground = item.IsLink ? palette.CardLinkText : palette.CardPrimaryText,
            TextWrapping = TextWrapping.Wrap,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(0, 8, 24, 0)
        });

        grid.Children.Add(body);
        AddChrome(grid, item, palette, metrics, activeTagFilter, isImage: false);
        return grid;
    }

    private Grid BuildImageCard(
        ClipboardItem item,
        BitmapImage? image,
        AppSettings settings,
        ThemePalette palette,
        CardMetrics metrics,
        ClipboardTag? activeTagFilter)
    {
        var grid = RootGrid();

        if (image is not null)
        {
            grid.Children.Add(new Image
            {
                Source = image,
                Stretch = Stretch.UniformToFill,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                VerticalAlignment = VerticalAlignment.Stretch
            });
        }
        else
        {
            grid.Children.Add(new TextBlock
            {
                Text = L10n.Tr("card.preview_unavailable"),
                Foreground = palette.ImageFallbackText,
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            });
        }

        grid.Children.Add(new Border
        {
            Background = new LinearGradientBrush(
                Color.FromArgb(160, 0, 0, 0),
                Color.FromArgb(48, 0, 0, 0),
                new Point(0, 0),
                new Point(0, 1))
        });

        var header = Header(item, settings, palette, item.MetadataText(settings.AppLanguage.Culture()), isImage: true);
        header.Margin = new Thickness(metrics.Padding, 12, metrics.Padding + 24, 0);
        header.VerticalAlignment = VerticalAlignment.Top;
        grid.Children.Add(header);

        AddChrome(grid, item, palette, metrics, activeTagFilter, isImage: true);
        return grid;
    }

    private static Grid RootGrid() => new()
    {
        ClipToBounds = true
    };

    private static FrameworkElement Header(
        ClipboardItem item,
        AppSettings settings,
        ThemePalette palette,
        string? metadataText,
        bool isImage)
    {
        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };

        if (settings.ShowMetadataOnCards && string.IsNullOrEmpty(metadataText) == false)
        {
            panel.Children.Add(SmallMetaText(metadataText, isImage ? palette.ImageMetadataText : palette.CardTextMetadata));
        }

        if (settings.ShowTimestampsOnCards)
        {
            panel.Children.Add(SmallMetaText(item.TimestampText(settings.AppLanguage.Culture()), isImage ? palette.ImageMetadataText : palette.CardTextMetadata));
        }

        return panel;
    }

    private static TextBlock SmallMetaText(string text, Brush foreground) => new()
    {
        Text = text,
        Foreground = foreground,
        FontSize = 10,
        FontWeight = FontWeights.Medium,
        Margin = new Thickness(8, 0, 0, 0),
        TextTrimming = TextTrimming.CharacterEllipsis
    };

    private void AddChrome(
        Grid grid,
        ClipboardItem item,
        ThemePalette palette,
        CardMetrics metrics,
        ClipboardTag? activeTagFilter,
        bool isImage)
    {
        var tagPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(Math.Max(metrics.Padding - 6, 8), Math.Max(metrics.Padding - 6, 8), 0, 0)
        };

        foreach (var tag in item.DisplayTags)
        {
            var tagButton = ChromeButton(L10n.Tr(tag.TitleKey()), isImage ? palette.ImageTagText : palette.CardTextTag);
            tagButton.Opacity = activeTagFilter == tag ? 0.98 : 0.78;
            tagButton.Click += (_, args) =>
            {
                args.Handled = true;
                TagRequested?.Invoke(tag);
            };
            tagPanel.Children.Add(tagButton);
        }

        grid.Children.Add(tagPanel);

        var deleteButton = ChromeButton("x", isImage ? Brushes.White : palette.CardDeleteIcon);
        deleteButton.Width = 22;
        deleteButton.Height = 22;
        deleteButton.HorizontalAlignment = HorizontalAlignment.Right;
        deleteButton.VerticalAlignment = VerticalAlignment.Top;
        deleteButton.Margin = new Thickness(0, Math.Max(metrics.Padding - 7, 8), Math.Max(metrics.Padding - 7, 8), 0);
        deleteButton.Click += (_, args) =>
        {
            args.Handled = true;
            DeleteRequested?.Invoke(item);
        };
        grid.Children.Add(deleteButton);
    }

    private static Button ChromeButton(string text, Brush foreground) => new()
    {
        Content = new TextBlock
        {
            Text = text,
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = foreground
        },
        Background = Brushes.Transparent,
        BorderBrush = Brushes.Transparent,
        Padding = new Thickness(4, 0, 4, 0),
        Margin = new Thickness(0, 0, 6, 0),
        Cursor = Cursors.Hand
    };

    private static LinearGradientBrush Gradient(Brush top, Brush bottom)
    {
        return new LinearGradientBrush(BrushColor(top), BrushColor(bottom), new Point(0, 0), new Point(1, 1))
        {
            Opacity = Math.Min(BrushOpacity(top), BrushOpacity(bottom))
        };
    }

    private static Color BrushColor(Brush brush) => brush is SolidColorBrush solid ? solid.Color : Colors.Transparent;
    private static double BrushOpacity(Brush brush) => brush is SolidColorBrush solid ? solid.Opacity : brush.Opacity;

    private static bool IsInsideButton(DependencyObject? source)
    {
        while (source is not null)
        {
            if (source is Button)
            {
                return true;
            }

            source = VisualTreeHelper.GetParent(source);
        }

        return false;
    }

    private sealed record CardMetrics(
        double CardWidth,
        double CardHeight,
        double Padding,
        double TextFontSize)
    {
        public double TotalCardWidth => CardWidth + Padding * 2;
        public double TotalCardHeight => CardHeight + Padding * 2;

        public static CardMetrics For(CardSizePreset preset) => preset switch
        {
            CardSizePreset.Compact => new CardMetrics(252, 148, 14, 15),
            CardSizePreset.Large => new CardMetrics(320, 188, 18, 18),
            _ => new CardMetrics(280, 164, 16, 17)
        };
    }
}
