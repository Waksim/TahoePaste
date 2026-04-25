using System.Windows.Interop;
using TahoePaste.Windows.Interop;

namespace TahoePaste.Windows.Services;

public sealed class ClipboardMonitor : IDisposable
{
    private HwndSource? _source;
    private bool _suppressNextChange;

    public event EventHandler? ClipboardChanged;

    public void Start()
    {
        if (_source is not null)
        {
            return;
        }

        var parameters = new HwndSourceParameters("TahoePasteClipboardSink")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0
        };

        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);
        NativeMethods.AddClipboardFormatListener(_source.Handle);
    }

    public void SuppressNextChange()
    {
        _suppressNextChange = true;
    }

    public void Stop()
    {
        if (_source is null)
        {
            return;
        }

        NativeMethods.RemoveClipboardFormatListener(_source.Handle);
        _source.RemoveHook(WndProc);
        _source.Dispose();
        _source = null;
        _suppressNextChange = false;
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg != NativeMethods.WmClipboardUpdate)
        {
            return IntPtr.Zero;
        }

        if (_suppressNextChange)
        {
            _suppressNextChange = false;
            handled = true;
            return IntPtr.Zero;
        }

        ClipboardChanged?.Invoke(this, EventArgs.Empty);
        handled = true;
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        Stop();
    }
}
