using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using Forms = System.Windows.Forms;
using TahoePaste.Windows.Interop;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Models;
using TahoePaste.Windows.Services;
using TahoePaste.Windows.Themes;
using TahoePaste.Windows.ViewModels;

namespace TahoePaste.Windows.Views;

public partial class OverlayWindow : Window
{
    private const double CardKeyboardScrollStep = 260;
    private const int CardRenderBatchSize = 50;
    private const double MinimumOverlayWidth = 320;

    private readonly ClipboardHistoryViewModel _viewModel;
    private readonly AppSettings _settings;
    private IReadOnlyList<ClipboardItem> _renderedItems = [];
    private int _renderedCardCount;

    public OverlayWindow(ClipboardHistoryViewModel viewModel, AppSettings settings)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _settings = settings;
        DataContext = viewModel;
        DiagnosticLog.Write("OverlayWindow constructed");

        _viewModel.PropertyChanged += OnViewModelChanged;
        _settings.PropertyChanged += OnSettingsChanged;
        L10n.LanguageChanged += (_, _) => Render();
        CardsScroll.ScrollChanged += OnCardsScrollChanged;
    }

    public bool IsPreview { get; private set; }

    // Set while the settings window is open: interactive dismissals downgrade
    // the overlay to the live preview instead of hiding it.
    public bool FallsBackToPreview { get; set; }

    public void ShowOverlay()
    {
        DiagnosticLog.Write($"Overlay.ShowOverlay enter isVisible={IsVisible} wasPreview={IsPreview}");
        IsPreview = false;
        PositionOnActiveScreen();
        Render();

        if (IsVisible == false)
        {
            ShowActivated = true;
            Show();
        }

        SetNoActivate(false);
        Activate();
        Focus();
        Keyboard.Focus(this);
        CardsScroll.ScrollToLeftEnd();
        DiagnosticLog.Write($"Overlay.ShowOverlay exit isVisible={IsVisible} isActive={IsActive} left={Left:0} top={Top:0} width={ActualWidth:0}/{Width:0} height={ActualHeight:0}/{Height:0}");
    }

    // Preview keeps the overlay visible without taking focus, so the settings
    // window stays interactive while its layout sliders act on a live view.
    public void ShowPreview()
    {
        // Downgrading from the interactive overlay ends that session; grab its
        // anchor now because this path bypasses HideOverlay().
        if (IsVisible && IsPreview == false)
        {
            _viewModel.CaptureSessionAnchor();
        }

        IsPreview = true;
        PositionOnActiveScreen();
        Render();

        if (IsVisible == false)
        {
            ShowActivated = false;
            Show();
        }

        SetNoActivate(true);
    }

    public void HideOverlay()
    {
        if (IsVisible == false)
        {
            return;
        }

        // Only an interactive session leaves a "return to where I was" anchor;
        // dismissing the settings preview must not overwrite it.
        if (IsPreview == false)
        {
            _viewModel.CaptureSessionAnchor();
        }

        if (FallsBackToPreview)
        {
            ShowPreview();
            return;
        }

        IsPreview = false;
        Hide();
    }

    private void SetNoActivate(bool noActivate)
    {
        var handle = new WindowInteropHelper(this).Handle;
        if (handle == IntPtr.Zero)
        {
            return;
        }

        var style = NativeMethods.GetWindowLongPtr(handle, NativeMethods.GwlExStyle).ToInt64();
        var updated = noActivate
            ? style | NativeMethods.WsExNoActivate
            : style & ~NativeMethods.WsExNoActivate;

        if (updated != style)
        {
            NativeMethods.SetWindowLongPtr(handle, NativeMethods.GwlExStyle, new IntPtr(updated));
        }
    }

    private void PositionOnActiveScreen()
    {
        var screen = Forms.Screen.FromPoint(Forms.Cursor.Position);
        var area = screen.WorkingArea;
        var dpiScale = CurrentDpiScale();
        var screenLeft = area.Left / dpiScale.X;
        var screenTop = area.Top / dpiScale.Y;
        var screenWidth = area.Width / dpiScale.X;
        var screenHeight = area.Height / dpiScale.Y;

        var layout = _settings.OverlayLayout;
        var width = Math.Max(screenWidth - layout.OverlayScreenHorizontalInset * 2, MinimumOverlayWidth);

        Height = layout.OverlayHeight;
        Width = width;
        Left = screenLeft + (screenWidth - width) / 2;
        Top = screenTop + screenHeight - Height - layout.OverlayScreenBottomInset;

        // When the overlay hugs the bottom of the screen, the visible corners
        // are at the top edge. Once it floats, round all four.
        var radius = _settings.CornerRadiusIntensity;
        var isDetachedFromScreenEdges = layout.OverlayScreenBottomInset > 0 || layout.OverlayScreenHorizontalInset > 0;
        OverlayBorder.CornerRadius = isDetachedFromScreenEdges
            ? new CornerRadius(radius)
            : new CornerRadius(radius, radius, 0, 0);
        DiagnosticLog.Write($"Overlay positioned screen={screen.DeviceName} areaPx={area.Left},{area.Top},{area.Width},{area.Height} dpiScale={dpiScale.X:0.###},{dpiScale.Y:0.###} left={Left:0} top={Top:0} width={Width:0} height={Height:0}");
    }

    private static Point CurrentDpiScale()
    {
        using var graphics = System.Drawing.Graphics.FromHwnd(IntPtr.Zero);
        return new Point(graphics.DpiX / 96.0, graphics.DpiY / 96.0);
    }

    private void Render()
    {
        ApplyTheme();
        ApplyLayout();
        RenderSearchBubble();
        RenderToolbar();
        RenderCards();
    }

    private void RenderSearchBubble()
    {
        SearchBubble.Visibility = _viewModel.IsSearchBubbleVisible ? Visibility.Visible : Visibility.Collapsed;
        SearchText.Text = _viewModel.SearchDisplayText;
    }

    private void RenderToolbar()
    {
        SettingsButton.ToolTip = L10n.Tr("overlay.tooltip_settings");
        SearchButton.ToolTip = L10n.Tr("overlay.tooltip_search");
        ScrollStartButton.ToolTip = L10n.Tr("overlay.tooltip_newest");
        ReturnButton.ToolTip = L10n.Tr("overlay.return_to_previous_position");
        ReturnButton.Visibility = _viewModel.SessionReturnTargetId is null
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    private void ApplyLayout()
    {
        var layout = _settings.OverlayLayout;

        TopBar.Height = layout.TopBarHeight;

        SearchBubble.Width = Math.Min(layout.SearchBubbleWidth, Math.Max(Width - 32, MinimumOverlayWidth - 32));
        SearchBubble.Height = layout.SearchBubbleHeight;
        SearchBubble.RenderTransform = new TranslateTransform(
            layout.SearchBubbleHorizontalOffset,
            layout.SearchBubbleVerticalOffset);

        ToolbarPanel.RenderTransform = new TranslateTransform(0, layout.ToolbarVerticalOffset);

        var buttonSide = layout.ToolbarIconSize + 8 + layout.ToolbarIconPadding * 2;
        Button[] toolbarButtons = [SettingsButton, SearchButton, ReturnButton, ScrollStartButton];
        for (var index = 0; index < toolbarButtons.Length; index++)
        {
            var button = toolbarButtons[index];
            button.FontSize = layout.ToolbarIconSize;
            button.Width = buttonSide;
            button.Height = buttonSide;
            button.Margin = new Thickness(index == 0 ? 0 : layout.ToolbarIconSpacing, 0, 0, 0);
        }

        CardsPanel.Margin = new Thickness(layout.CardSpacing, 0, layout.CardSpacing, layout.BottomInset);
    }

    private void RenderCards()
    {
        CardsPanel.Children.Clear();
        _renderedItems = _viewModel.VisibleItems;
        _renderedCardCount = 0;

        EmptyPanel.Visibility = _renderedItems.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        CardsScroll.Visibility = _renderedItems.Count == 0 ? Visibility.Collapsed : Visibility.Visible;

        if (_renderedItems.Count == 0)
        {
            EmptyTitle.Text = _viewModel.IsSearching ? L10n.Tr("overlay.no_matches_title") : L10n.Tr("overlay.empty_title");
            EmptySubtitle.Text = _viewModel.IsSearching ? L10n.Tr("overlay.no_matches_subtitle") : L10n.Tr("overlay.empty_subtitle");
            return;
        }

        AppendCards(CardRenderBatchSize);
    }

    // Cards are materialized in batches: building a WPF control tree for every
    // history item on each result change stalls the UI with large histories.
    private void AppendCards(int count)
    {
        var limit = Math.Min(_renderedCardCount + count, _renderedItems.Count);

        for (var index = _renderedCardCount; index < limit; index++)
        {
            var item = _renderedItems[index];
            var card = new ClipboardCardControl(item, _viewModel.ImageFor(item), _settings, _viewModel.ActiveTagFilter);
            card.SelectRequested += selected => _viewModel.Select(selected);
            card.DeleteRequested += selected => _viewModel.Delete(selected);
            card.TagRequested += tag => _viewModel.ToggleTagFilter(tag);
            CardsPanel.Children.Add(card);
        }

        _renderedCardCount = limit;
        DiagnosticLog.Write($"Overlay.Render theme={_settings.ActiveTheme} visibleItems={_renderedItems.Count} cards={CardsPanel.Children.Count} empty={EmptyPanel.Visibility} cardsScroll={CardsScroll.Visibility}");
    }

    private void OnCardsScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        TrackScrollAnchor(e.HorizontalOffset);

        if (_renderedCardCount >= _renderedItems.Count)
        {
            return;
        }

        if (e.HorizontalOffset + e.ViewportWidth >= e.ExtentWidth - e.ViewportWidth)
        {
            AppendCards(CardRenderBatchSize);
        }
    }

    private void TrackScrollAnchor(double horizontalOffset)
    {
        if (CardsPanel.Children.Count == 0)
        {
            return;
        }

        _viewModel.CurrentScrollAnchorId = LeftmostVisibleItemId(horizontalOffset);
    }

    // The leftmost card still (partially) inside the viewport. Cards ahead of
    // the scroll position are always materialized, so the anchor is never in
    // the unrendered tail.
    private Guid? LeftmostVisibleItemId(double horizontalOffset)
    {
        var rightEdge = CardsPanel.Margin.Left;

        for (var index = 0; index < CardsPanel.Children.Count && index < _renderedItems.Count; index++)
        {
            if (CardsPanel.Children[index] is not FrameworkElement card)
            {
                continue;
            }

            rightEdge += card.Margin.Left + card.Width + card.Margin.Right;
            if (rightEdge > horizontalOffset + 1)
            {
                return _renderedItems[index].Id;
            }
        }

        return _renderedItems.Count > 0 ? _renderedItems[Math.Min(_renderedCardCount, _renderedItems.Count) - 1].Id : null;
    }

    private double CardLeftOffset(int index)
    {
        var offset = CardsPanel.Margin.Left;

        for (var childIndex = 0; childIndex < index && childIndex < CardsPanel.Children.Count; childIndex++)
        {
            if (CardsPanel.Children[childIndex] is FrameworkElement card)
            {
                offset += card.Margin.Left + card.Width + card.Margin.Right;
            }
        }

        return offset;
    }

    private void ApplyTheme()
    {
        var palette = ThemePalette.For(_settings.ActiveTheme);
        OverlayBorder.Background = new LinearGradientBrush(
            BrushColor(palette.OverlayGradientTop),
            BrushColor(palette.OverlayGradientBottom),
            new Point(0, 0),
            new Point(1, 1));
        // The window itself stays transparent so the rounded border corners
        // reveal the desktop instead of a solid window rectangle.
        Background = Brushes.Transparent;
        OverlayBorder.Opacity = 1;
        OverlayBorder.BorderBrush = palette.OverlayEdgeHighlight;
        SearchBubble.Background = palette.OverlayBubbleFill;
        SearchBubble.BorderBrush = palette.OverlayBubbleBorder;
        SearchText.Foreground = palette.OverlayPrimaryText;
        EmptyTitle.Foreground = palette.OverlayPrimaryText;
        EmptySubtitle.Foreground = palette.OverlaySecondaryText;
        SetButtonForeground(SettingsButton, palette.OverlayToolbarIcon);
        SetButtonForeground(SearchButton, palette.OverlayToolbarIcon);
        SetButtonForeground(ReturnButton, palette.OverlayToolbarIcon);
        SetButtonForeground(ScrollStartButton, palette.OverlayToolbarIcon);
    }

    private static void SetButtonForeground(Button button, Brush brush)
    {
        button.Foreground = brush;
    }

    private static Color BrushColor(Brush brush) => brush is SolidColorBrush solid ? solid.Color : Colors.Transparent;
    private static double BrushOpacity(Brush brush) => brush is SolidColorBrush solid ? solid.Opacity : brush.Opacity;

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(ClipboardHistoryViewModel.SearchDisplayText)
            or nameof(ClipboardHistoryViewModel.IsSearchBubbleVisible))
        {
            RenderSearchBubble();
        }
        else if (e.PropertyName is nameof(ClipboardHistoryViewModel.VisibleItems)
            or nameof(ClipboardHistoryViewModel.OverlayPresentationId))
        {
            RenderCards();
            // The return target depends on VisibleItems: deleting the anchor
            // item must retire the button, not leave it pointing at nothing.
            RenderToolbar();
            CardsScroll.ScrollToLeftEnd();
        }
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        // Whitelist instead of "any change": Render() rebuilds every card, so
        // unrelated settings (paste delay, autostart, ...) must not trigger it.
        var affectsOverlay = e.PropertyName is nameof(AppSettings.ActiveTheme)
            or nameof(AppSettings.CardSizePreset)
            or nameof(AppSettings.CornerRadiusIntensity)
            or nameof(AppSettings.TextCardCornerRadius)
            or nameof(AppSettings.ImageCardCornerRadius)
            or nameof(AppSettings.TextCardShadowIntensity)
            or nameof(AppSettings.ImageCardShadowIntensity)
            or nameof(AppSettings.ShowMetadataOnCards)
            or nameof(AppSettings.ShowTimestampsOnCards)
            or nameof(AppSettings.UseAutomaticOverlayLayout)
            || e.PropertyName?.StartsWith("Manual", StringComparison.Ordinal) == true;

        if (affectsOverlay == false)
        {
            return;
        }

        if (IsVisible)
        {
            PositionOnActiveScreen();
        }

        Render();
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (Keyboard.Modifiers == ModifierKeys.Control && e.Key == Key.OemComma)
        {
            _viewModel.OpenSettings();
            e.Handled = true;
            return;
        }

        switch (e.Key)
        {
            case Key.Left:
                ScrollCardsBy(-CardKeyboardScrollStep);
                e.Handled = true;
                return;

            case Key.Right:
                ScrollCardsBy(CardKeyboardScrollStep);
                e.Handled = true;
                return;

            case Key.PageUp:
                ScrollCardsBy(-Math.Max(CardKeyboardScrollStep, CardsScroll.ViewportWidth * 0.85));
                e.Handled = true;
                return;

            case Key.PageDown:
                ScrollCardsBy(Math.Max(CardKeyboardScrollStep, CardsScroll.ViewportWidth * 0.85));
                e.Handled = true;
                return;

            case Key.Home:
                CardsScroll.ScrollToLeftEnd();
                e.Handled = true;
                return;

            case Key.End:
                CardsScroll.ScrollToRightEnd();
                e.Handled = true;
                return;

            case Key.Escape:
                if (_viewModel.IsSearchBubbleVisible)
                {
                    _viewModel.ClearTransientState();
                }
                else
                {
                    _viewModel.HideOverlay();
                }

                e.Handled = true;
                return;

            case Key.Back:
            case Key.Delete:
                if (_viewModel.IsSearching)
                {
                    _viewModel.RemoveLastSearchCharacter();
                    e.Handled = true;
                }
                else if (_viewModel.IsSearchInterfaceVisible)
                {
                    _viewModel.DismissSearchInterface();
                    e.Handled = true;
                }

                return;
        }
    }

    private void OnCardsMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (CardsScroll.ScrollableWidth <= 0)
        {
            return;
        }

        ScrollCardsBy(-e.Delta);
        e.Handled = true;
    }

    private void ScrollCardsBy(double delta)
    {
        if (CardsScroll.ScrollableWidth <= 0)
        {
            return;
        }

        var previousOffset = CardsScroll.HorizontalOffset;
        var nextOffset = Math.Clamp(previousOffset + delta, 0, CardsScroll.ScrollableWidth);
        CardsScroll.ScrollToHorizontalOffset(nextOffset);
        DiagnosticLog.Write($"Overlay.ScrollCards previous={previousOffset:0} next={nextOffset:0} delta={delta:0} scrollable={CardsScroll.ScrollableWidth:0}");
    }

    private void OnTextInput(object sender, TextCompositionEventArgs e)
    {
        if ((Keyboard.Modifiers & (ModifierKeys.Control | ModifierKeys.Alt | ModifierKeys.Windows)) != 0)
        {
            return;
        }

        var searchableInput = new string(e.Text.Where(character => char.IsControl(character) == false).ToArray());
        if (string.IsNullOrEmpty(searchableInput))
        {
            return;
        }

        _viewModel.AppendSearchCharacter(searchableInput);
        e.Handled = true;
    }

    private void OnDeactivated(object sender, EventArgs e)
    {
        DiagnosticLog.Write($"Overlay deactivated isPreview={IsPreview}");

        // The preview never owns focus, so losing activation is its normal state.
        if (IsPreview)
        {
            return;
        }

        HideOverlay();
    }

    private void OnClearSearchClick(object sender, RoutedEventArgs e)
    {
        _viewModel.ClearTransientState();
    }

    private void OnSettingsClick(object sender, RoutedEventArgs e)
    {
        _viewModel.OpenSettings();
    }

    private void OnSearchClick(object sender, RoutedEventArgs e)
    {
        _viewModel.BeginSearch();
    }

    private void OnReturnClick(object sender, RoutedEventArgs e)
    {
        if (_viewModel.SessionReturnTargetId is not { } targetId)
        {
            return;
        }

        var targetIndex = -1;
        for (var index = 0; index < _renderedItems.Count; index++)
        {
            if (_renderedItems[index].Id == targetId)
            {
                targetIndex = index;
                break;
            }
        }

        if (targetIndex < 0)
        {
            return;
        }

        // The anchor may sit past the materialized batches; render up to it
        // before the offset of its card can mean anything.
        while (_renderedCardCount <= targetIndex && _renderedCardCount < _renderedItems.Count)
        {
            AppendCards(CardRenderBatchSize);
        }

        CardsScroll.UpdateLayout();
        var offset = Math.Max(CardLeftOffset(targetIndex) - CardsPanel.Margin.Left, 0);
        CardsScroll.ScrollToHorizontalOffset(Math.Min(offset, CardsScroll.ScrollableWidth));
    }

    private void OnScrollStartClick(object sender, RoutedEventArgs e)
    {
        CardsScroll.ScrollToLeftEnd();
    }
}
