using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;
using TahoePaste.Windows.Themes;

namespace TahoePaste.Windows.Views;

public sealed class ClipboardCardControl : Border
{
    // Vertical room the top chrome row (tags + metadata) occupies; the text
    // card body starts below it so the preview never sits under the chrome.
    private const double TopRowReservedHeight = 24;
    private const double DeleteButtonSize = 22;

    private readonly ClipboardItem _item;

    public ClipboardCardControl(
        ClipboardItem item,
        BitmapImage? image,
        AppSettings settings,
        ClipboardTag? activeTagFilter)
    {
        _item = item;
        var palette = ThemePalette.For(settings.ActiveTheme);
        var layout = settings.OverlayLayout;

        Width = item.UsesImageCardLayout ? layout.TotalImageCardWidth : layout.TotalTextCardWidth;
        Height = layout.TotalCardHeight;
        var cardRadius = item.UsesImageCardLayout ? settings.ImageCardCornerRadius : settings.TextCardCornerRadius;
        CornerRadius = new CornerRadius(cardRadius);
        ClipToBounds = false;
        Background = palette.CardGradientTop;
        BorderBrush = palette.CardBorder;
        BorderThickness = new Thickness(1);
        Margin = new Thickness(0, 0, layout.CardSpacing, 0);
        Effect = CardShadow(item.UsesImageCardLayout ? settings.ImageCardShadowIntensity : settings.TextCardShadowIntensity);
        Cursor = Cursors.Hand;

        var content = item.UsesImageCardLayout
            ? BuildImageCard(item, image, settings, palette, layout, activeTagFilter)
            : BuildTextCard(item, settings, palette, layout, activeTagFilter);
        Child = content;
        ClipCardContent(content, cardRadius);
        SizeChanged += (_, _) => ClipCardContent(content, cardRadius);

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
        OverlayLayout layout,
        ClipboardTag? activeTagFilter)
    {
        var grid = RootGrid();
        var padding = layout.ContentPadding;
        var body = new StackPanel
        {
            Margin = new Thickness(padding, padding, padding, padding * 0.55)
        };

        body.Children.Add(new TextBlock
        {
            Text = item.DisplayPreviewText,
            FontFamily = new FontFamily(item.IsCode ? "Cascadia Mono, Consolas" : "Segoe UI Variable, Segoe UI"),
            FontSize = item.IsCode ? TextFontSize(settings) - 1 : TextFontSize(settings),
            FontWeight = FontWeights.Medium,
            Foreground = item.IsLink ? palette.CardLinkText : palette.CardPrimaryText,
            TextWrapping = TextWrapping.Wrap,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(0, TopRowReservedHeight, 24, 0)
        });

        grid.Children.Add(body);
        AddChrome(grid, item, settings, palette, layout, activeTagFilter, isImage: false);
        return grid;
    }

    private Grid BuildImageCard(
        ClipboardItem item,
        BitmapImage? image,
        AppSettings settings,
        ThemePalette palette,
        OverlayLayout layout,
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

        AddChrome(grid, item, settings, palette, layout, activeTagFilter, isImage: true);
        return grid;
    }

    private static double TextFontSize(AppSettings settings) => settings.CardSizePreset switch
    {
        CardSizePreset.Compact => 15,
        CardSizePreset.Large => 18,
        _ => 17
    };

    private static Grid RootGrid() => new()
    {
        ClipToBounds = true
    };

    private static TextBlock SmallMetaText(string text, Brush foreground) => new()
    {
        Text = text,
        Foreground = foreground,
        FontSize = 10,
        FontWeight = FontWeights.Medium,
        Margin = new Thickness(8, 0, 0, 0),
        TextTrimming = TextTrimming.CharacterEllipsis,
        VerticalAlignment = VerticalAlignment.Center,
        IsHitTestVisible = false
    };

    // Tags and metadata share one row so they truncate instead of overlapping
    // when both sides are long: tags take the leftover star column and clip
    // first, metadata and timestamp keep their measured width.
    private void AddChrome(
        Grid grid,
        ClipboardItem item,
        AppSettings settings,
        ThemePalette palette,
        OverlayLayout layout,
        ClipboardTag? activeTagFilter,
        bool isImage)
    {
        var inset = Math.Max(layout.ContentPadding - 6, 8);
        var deleteInset = Math.Max(layout.ContentPadding - 7, 8);

        var topRow = new Grid
        {
            VerticalAlignment = VerticalAlignment.Top,
            Height = TopRowReservedHeight,
            Margin = new Thickness(inset, inset, deleteInset + DeleteButtonSize, 0)
        };
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var tagPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Center,
            ClipToBounds = true
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

        Grid.SetColumn(tagPanel, 0);
        topRow.Children.Add(tagPanel);

        var metadataText = item.MetadataText(settings.AppLanguage.Culture());
        if (settings.ShowMetadataOnCards && string.IsNullOrEmpty(metadataText) == false)
        {
            var metadata = SmallMetaText(metadataText, isImage ? palette.ImageMetadataText : palette.CardTextMetadata);
            Grid.SetColumn(metadata, 1);
            topRow.Children.Add(metadata);
        }

        if (settings.ShowTimestampsOnCards)
        {
            var timestamp = SmallMetaText(
                item.TimestampText(settings.AppLanguage.Culture()),
                isImage ? palette.ImageMetadataText : palette.CardTextMetadata);
            Grid.SetColumn(timestamp, 2);
            topRow.Children.Add(timestamp);
        }

        grid.Children.Add(topRow);

        var deleteButton = ChromeButton("x", isImage ? Brushes.White : palette.CardDeleteIcon);
        deleteButton.Width = DeleteButtonSize;
        deleteButton.Height = DeleteButtonSize;
        deleteButton.HorizontalAlignment = HorizontalAlignment.Right;
        deleteButton.VerticalAlignment = VerticalAlignment.Top;
        deleteButton.Margin = new Thickness(0, deleteInset, deleteInset, 0);
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

    private static DropShadowEffect? CardShadow(double intensity)
    {
        if (intensity <= 0)
        {
            return null;
        }

        var strength = Math.Clamp(intensity / 100.0, 0, 1);
        return new DropShadowEffect
        {
            BlurRadius = 8 + 8 * strength,
            ShadowDepth = 1 + 4 * strength,
            Opacity = 0.06 + 0.18 * strength,
            Color = Colors.Black
        };
    }

    private void ClipCardContent(FrameworkElement content, double radius)
    {
        var width = content.ActualWidth > 0 ? content.ActualWidth : Width;
        var height = content.ActualHeight > 0 ? content.ActualHeight : Height;

        content.Clip = new RectangleGeometry(
            new Rect(0, 0, Math.Max(0, width), Math.Max(0, height)),
            radius,
            radius);
    }

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
}
