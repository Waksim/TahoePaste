using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Forms = System.Windows.Forms;
using TahoePaste.Windows.Localization;
using TahoePaste.Windows.Services;
using TahoePaste.Windows.Themes;
using TahoePaste.Windows.ViewModels;

namespace TahoePaste.Windows.Views;

public partial class OverlayWindow : Window
{
    private const double CardKeyboardScrollStep = 260;
    private readonly ClipboardHistoryViewModel _viewModel;
    private readonly AppSettings _settings;

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
    }

    public void ShowOverlay()
    {
        DiagnosticLog.Write($"Overlay.ShowOverlay enter isVisible={IsVisible}");
        PositionOnActiveScreen();
        Render();

        if (IsVisible == false)
        {
            Show();
        }

        Activate();
        Focus();
        Keyboard.Focus(this);
        CardsScroll.ScrollToLeftEnd();
        DiagnosticLog.Write($"Overlay.ShowOverlay exit isVisible={IsVisible} isActive={IsActive} left={Left:0} top={Top:0} width={ActualWidth:0}/{Width:0} height={ActualHeight:0}/{Height:0}");
    }

    public void HideOverlay()
    {
        if (IsVisible)
        {
            Hide();
        }
    }

    private void PositionOnActiveScreen()
    {
        var screen = Forms.Screen.FromPoint(Forms.Cursor.Position);
        var area = screen.WorkingArea;
        var dpiScale = CurrentDpiScale();
        var left = area.Left / dpiScale.X;
        var top = area.Top / dpiScale.Y;
        var width = area.Width / dpiScale.X;
        var height = area.Height / dpiScale.Y;

        Height = _settings.OverlayHeight;
        Width = width;
        Left = left;
        Top = top + height - Height;
        OverlayBorder.CornerRadius = new CornerRadius(0, 0, _settings.CornerRadiusIntensity, _settings.CornerRadiusIntensity);
        DiagnosticLog.Write($"Overlay positioned screen={screen.DeviceName} areaPx={area.Left},{area.Top},{area.Width},{area.Height} dpiScale={dpiScale.X:0.###},{dpiScale.Y:0.###} cursorPx={Forms.Cursor.Position.X},{Forms.Cursor.Position.Y} left={Left:0} top={Top:0} width={Width:0} height={Height:0}");
    }

    private static Point CurrentDpiScale()
    {
        using var graphics = System.Drawing.Graphics.FromHwnd(IntPtr.Zero);
        return new Point(graphics.DpiX / 96.0, graphics.DpiY / 96.0);
    }

    private void Render()
    {
        ApplyTheme();
        SearchBubble.Visibility = _viewModel.IsSearchBubbleVisible ? Visibility.Visible : Visibility.Collapsed;
        SearchText.Text = _viewModel.SearchDisplayText;

        CardsPanel.Children.Clear();

        var visibleItems = _viewModel.VisibleItems;
        EmptyPanel.Visibility = visibleItems.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        CardsScroll.Visibility = visibleItems.Count == 0 ? Visibility.Collapsed : Visibility.Visible;

        if (visibleItems.Count == 0)
        {
            EmptyTitle.Text = _viewModel.IsSearching ? L10n.Tr("overlay.no_matches_title") : L10n.Tr("overlay.empty_title");
            EmptySubtitle.Text = _viewModel.IsSearching ? L10n.Tr("overlay.no_matches_subtitle") : L10n.Tr("overlay.empty_subtitle");
            return;
        }

        foreach (var item in visibleItems)
        {
            var card = new ClipboardCardControl(item, _viewModel.ImageFor(item), _settings, _viewModel.ActiveTagFilter);
            card.SelectRequested += selected => _viewModel.Select(selected);
            card.DeleteRequested += selected => _viewModel.Delete(selected);
            card.TagRequested += tag => _viewModel.ToggleTagFilter(tag);
            CardsPanel.Children.Add(card);
        }

        DiagnosticLog.Write($"Overlay.Render theme={_settings.ActiveTheme} visibleItems={visibleItems.Count} cards={CardsPanel.Children.Count} empty={EmptyPanel.Visibility} cardsScroll={CardsScroll.Visibility}");
    }

    private void ApplyTheme()
    {
        var palette = ThemePalette.For(_settings.ActiveTheme);
        OverlayBorder.Background = new LinearGradientBrush(
            BrushColor(palette.OverlayGradientTop),
            BrushColor(palette.OverlayGradientBottom),
            new Point(0, 0),
            new Point(1, 1));
        Background = new SolidColorBrush(BrushColor(palette.OverlayGradientTop));
        OverlayBorder.Opacity = 1;
        OverlayBorder.BorderBrush = palette.OverlayEdgeHighlight;
        SearchBubble.Background = palette.OverlayBubbleFill;
        SearchBubble.BorderBrush = palette.OverlayBubbleBorder;
        SearchText.Foreground = palette.OverlayPrimaryText;
        EmptyTitle.Foreground = palette.OverlayPrimaryText;
        EmptySubtitle.Foreground = palette.OverlaySecondaryText;
        SetButtonForeground(SettingsButton, palette.OverlayToolbarIcon);
        SetButtonForeground(SearchButton, palette.OverlayToolbarIcon);
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
        if (e.PropertyName is nameof(ClipboardHistoryViewModel.VisibleItems)
            or nameof(ClipboardHistoryViewModel.SearchDisplayText)
            or nameof(ClipboardHistoryViewModel.IsSearchBubbleVisible)
            or nameof(ClipboardHistoryViewModel.OverlayPresentationId))
        {
            Render();
            CardsScroll.ScrollToLeftEnd();
        }
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(AppSettings.ActiveTheme)
            or nameof(AppSettings.CardSizePreset)
            or nameof(AppSettings.CornerRadiusIntensity)
            or nameof(AppSettings.ShowMetadataOnCards)
            or nameof(AppSettings.ShowTimestampsOnCards)
            or nameof(AppSettings.OverlayHeight))
        {
            if (IsVisible)
            {
                PositionOnActiveScreen();
            }

            Render();
        }
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
        DiagnosticLog.Write("Overlay deactivated");
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

    private void OnScrollStartClick(object sender, RoutedEventArgs e)
    {
        CardsScroll.ScrollToLeftEnd();
    }
}
