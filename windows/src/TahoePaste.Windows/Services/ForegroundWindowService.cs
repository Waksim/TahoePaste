using System.Runtime.InteropServices;
using TahoePaste.Windows.Interop;

namespace TahoePaste.Windows.Services;

public sealed class ForegroundWindowService
{
    private IntPtr _previousWindow;

    public void CaptureCurrentForegroundWindow()
    {
        var handle = NativeMethods.GetForegroundWindow();
        if (handle == IntPtr.Zero)
        {
            return;
        }

        NativeMethods.GetWindowThreadProcessId(handle, out var processId);
        if (processId == Environment.ProcessId)
        {
            return;
        }

        _previousWindow = handle;
    }

    public void ReactivatePreviousWindow()
    {
        if (_previousWindow == IntPtr.Zero)
        {
            return;
        }

        NativeMethods.ShowWindow(_previousWindow, NativeMethods.SwRestore);
        NativeMethods.SetForegroundWindow(_previousWindow);
    }

    public void SendCtrlV()
    {
        var inputs = new[]
        {
            NativeMethods.KeyDown(NativeMethods.VkControl),
            NativeMethods.KeyDown(NativeMethods.VkV),
            NativeMethods.KeyUp(NativeMethods.VkV),
            NativeMethods.KeyUp(NativeMethods.VkControl)
        };

        NativeMethods.SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<NativeMethods.INPUT>());
    }
}
