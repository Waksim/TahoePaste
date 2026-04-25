using System.ComponentModel;
using System.Windows.Interop;
using TahoePaste.Windows.Interop;

namespace TahoePaste.Windows.Services;

public sealed class HotkeyManager : IDisposable
{
    private const int ToggleHotkeyId = 0x54485043;
    private HwndSource? _source;
    private bool _registered;

    public event EventHandler? TogglePressed;

    public void Register()
    {
        Unregister();

        var parameters = new HwndSourceParameters("TahoePasteHotkeySink")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0
        };

        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);

        _registered = NativeMethods.RegisterHotKey(
            _source.Handle,
            ToggleHotkeyId,
            NativeMethods.ModControl | NativeMethods.ModShift,
            NativeMethods.VkC);

        if (_registered == false)
        {
            var error = new Win32Exception();
            Unregister();
            throw error;
        }
    }

    public void Unregister()
    {
        if (_source is not null)
        {
            if (_registered)
            {
                NativeMethods.UnregisterHotKey(_source.Handle, ToggleHotkeyId);
            }

            _source.RemoveHook(WndProc);
            _source.Dispose();
            _source = null;
            _registered = false;
        }
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WmHotkey && wParam.ToInt32() == ToggleHotkeyId)
        {
            TogglePressed?.Invoke(this, EventArgs.Empty);
            handled = true;
        }

        return IntPtr.Zero;
    }

    public void Dispose()
    {
        Unregister();
    }
}
