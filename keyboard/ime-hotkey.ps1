# IME hotkeys: Win+Shift+F11 = IME off, Win+Shift+F12 = IME on
# Runs hidden in the background. setup.ps1 registers it in the Startup folder.
# Log: %LOCALAPPDATA%\ime-hotkey.log
$log = Join-Path $env:LOCALAPPDATA 'ime-hotkey.log'
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.IO;
using System.Threading;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class ImeHotkey : Form {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint tid, ref GUITHREADINFO info);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("imm32.dll")] static extern IntPtr ImmGetDefaultIMEWnd(IntPtr h);

    [StructLayout(LayoutKind.Sequential)] struct RECT { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct GUITHREADINFO {
        public int cbSize; public int flags; public IntPtr active, focus, capture, menuOwner, moveSize, caret; public RECT rc;
    }

    const uint MOD_SHIFT = 0x4, MOD_WIN = 0x8, MOD_NOREPEAT = 0x4000;
    const int ID_OFF = 1, ID_ON = 2;
    string logPath;

    public ImeHotkey(string log) {
        logPath = log;
        ShowInTaskbar = false; WindowState = FormWindowState.Minimized; FormBorderStyle = FormBorderStyle.FixedToolWindow;
        Opacity = 0;
    }
    protected override void OnLoad(EventArgs e) {
        base.OnLoad(e); Hide();
        bool a = RegisterHotKey(Handle, ID_OFF, MOD_WIN | MOD_SHIFT | MOD_NOREPEAT, 0x7A); // F11
        bool b = RegisterHotKey(Handle, ID_ON,  MOD_WIN | MOD_SHIFT | MOD_NOREPEAT, 0x7B); // F12
        Log("started: F11(off)=" + a + " F12(on)=" + b);
    }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312) SetIme(m.WParam.ToInt32() == ID_ON);
        base.WndProc(ref m);
    }
    void SetIme(bool open) {
        IntPtr fg = GetForegroundWindow();
        IntPtr target = fg;
        var gti = new GUITHREADINFO(); gti.cbSize = Marshal.SizeOf(gti);
        if (GetGUIThreadInfo(GetWindowThreadProcessId(fg, IntPtr.Zero), ref gti) && gti.focus != IntPtr.Zero) target = gti.focus;
        IntPtr ime = ImmGetDefaultIMEWnd(target);
        // WM_IME_CONTROL (0x283), IMC_SETOPENSTATUS (0x6)
        SendMessage(ime, 0x283, (IntPtr)0x6, (IntPtr)(open ? 1 : 0));
        Log((open ? "on " : "off") + " hwnd=0x" + target.ToString("X") + " ime=0x" + ime.ToString("X"));
    }
    protected override void OnFormClosed(FormClosedEventArgs e) {
        UnregisterHotKey(Handle, ID_OFF); UnregisterHotKey(Handle, ID_ON); base.OnFormClosed(e);
    }
    void Log(string s) {
        try { File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ") + s + "\r\n"); } catch {}
    }
    public static void Start(string log) {
        bool created;
        using (var mx = new Mutex(true, @"Local\ImeHotkeyWinShiftF11F12", out created)) {
            if (!created) return;
            Application.Run(new ImeHotkey(log));
        }
    }
}
"@
[ImeHotkey]::Start($log)
