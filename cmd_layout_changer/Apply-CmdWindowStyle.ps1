$ErrorActionPreference = 'Stop'
$logPath = Join-Path $env:TEMP 'CmdWindowStyle.log'

try {
    $styleMode = 'Style1'
    $styleModePath = 'HKCU:\Software\Microsoft\Command Processor'
    if (Test-Path -LiteralPath $styleModePath) {
        $styleModeValue = (Get-ItemProperty -LiteralPath $styleModePath -Name CmdWindowStyleMode -ErrorAction SilentlyContinue).CmdWindowStyleMode
        if ($styleModeValue -in @('Style1', 'Style2')) {
            $styleMode = $styleModeValue
        }
    }

    # Layout definitions are data. Add another entry to a style to extend its cycle.
    $layoutSets = [ordered]@{
        Style1 = @(
            [pscustomobject]@{ Label = 'Style 1 first layout';      Width = 121; Height = 49; Left = 155;  Top = 11; Background = [uint32]0x00000000 }
            [pscustomobject]@{ Label = 'Style 1 additional layout'; Width = 69;  Height = 48; Left = 1273; Top = 11; Background = [uint32]0x000C0C0C }
        )
        Style2 = @(
            [pscustomobject]@{ Label = 'Style 2 left layout';   Width = 62; Height = 48; Left = 168;  Top = 11; Background = [uint32]0x000C0C0C }
            [pscustomobject]@{ Label = 'Style 2 middle layout'; Width = 62; Height = 48; Left = 745;  Top = 11; Background = [uint32]0x000C0C0C }
            [pscustomobject]@{ Label = 'Style 2 right layout';  Width = 62; Height = 48; Left = 1322; Top = 11; Background = [uint32]0x000C0C0C }
        )
    }

    # Shared 1-based launch sequence -> 0-based layout entry rule.
    function Get-CyclicLayoutIndex {
        param(
            [int]$OpenNumber,
            [int]$LayoutCount
        )
        if ($LayoutCount -lt 1) { throw 'A style must define at least one layout.' }
        if ($OpenNumber -lt 1) { $OpenNumber = 1 }
        return (($OpenNumber - 1) % $LayoutCount)
    }

    # Count visible Console Host windows instead of cmd.exe processes. Windows can
    # create multiple cmd.exe /c processes for a single visible .cmd/.bat window.
    try {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class CmdConsoleWindowCounter
{
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    private static int _count;
    private static uint _currentSession;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder className, int maxCount);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ProcessIdToSessionId(uint processId, out uint sessionId);

    private static bool CountConsoleWindow(IntPtr hWnd, IntPtr lParam)
    {
        if (!IsWindowVisible(hWnd)) return true;

        StringBuilder className = new StringBuilder(128);
        if (GetClassName(hWnd, className, className.Capacity) <= 0 ||
            !String.Equals(className.ToString(), "ConsoleWindowClass", StringComparison.OrdinalIgnoreCase))
            return true;

        uint processId;
        if (GetWindowThreadProcessId(hWnd, out processId) == 0) return true;

        uint sessionId;
        if (ProcessIdToSessionId(processId, out sessionId) && sessionId == _currentSession)
            _count++;

        return true;
    }

    public static int CountVisibleConsoleWindows()
    {
        _count = 0;
        _currentSession = (uint)Process.GetCurrentProcess().SessionId;
        if (!EnumWindows(CountConsoleWindow, IntPtr.Zero))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Enumerate Console Host windows");
        return _count;
    }
}
'@ -ErrorAction Stop

        $activeConsoleCount = [CmdConsoleWindowCounter]::CountVisibleConsoleWindows()
    } catch {
        $currentSessionId = [Diagnostics.Process]::GetCurrentProcess().SessionId
        $activeConsoleCount = @(Get-Process -Name cmd -ErrorAction SilentlyContinue | Where-Object {
            $_.SessionId -eq $currentSessionId
        }).Count
    }
    if ($activeConsoleCount -lt 1) { $activeConsoleCount = 1 }
    $styleLayouts = @($layoutSets[$styleMode])
    $layoutIndex = Get-CyclicLayoutIndex -OpenNumber $activeConsoleCount -LayoutCount $styleLayouts.Count
    $selectedLayout = $styleLayouts[$layoutIndex]

    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class CmdWindowStyleNative
{
    [StructLayout(LayoutKind.Sequential)]
    private struct COORD
    {
        public short X;
        public short Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SMALL_RECT
    {
        public short Left;
        public short Top;
        public short Right;
        public short Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CONSOLE_FONT_INFOEX
    {
        public uint cbSize;
        public uint nFont;
        public COORD dwFontSize;
        public uint FontFamily;
        public uint FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct CONSOLE_SCREEN_BUFFER_INFOEX
    {
        public uint cbSize;
        public COORD dwSize;
        public COORD dwCursorPosition;
        public ushort wAttributes;
        public SMALL_RECT srWindow;
        public COORD dwMaximumWindowSize;
        public ushort wPopupAttributes;
        [MarshalAs(UnmanagedType.Bool)]
        public bool bFullscreenSupported;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public uint[] ColorTable;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleScreenBufferInfoEx(IntPtr hConsoleOutput, ref CONSOLE_SCREEN_BUFFER_INFOEX lpConsoleScreenBufferInfoEx);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleScreenBufferInfoEx(IntPtr hConsoleOutput, ref CONSOLE_SCREEN_BUFFER_INFOEX lpConsoleScreenBufferInfoEx);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleScreenBufferSize(IntPtr hConsoleOutput, COORD dwSize);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleWindowInfo(IntPtr hConsoleOutput, bool bAbsolute, ref SMALL_RECT lpConsoleWindow);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleTextAttribute(IntPtr hConsoleOutput, ushort wAttributes);

    [DllImport("kernel32.dll", EntryPoint = "FillConsoleOutputCharacterW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool FillConsoleOutputCharacter(IntPtr hConsoleOutput, char cCharacter, uint nLength, COORD dwWriteCoord, out uint lpNumberOfCharsWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool FillConsoleOutputAttribute(IntPtr hConsoleOutput, ushort wAttribute, uint nLength, COORD dwWriteCoord, out uint lpNumberOfAttrsWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleCursorPosition(IntPtr hConsoleOutput, COORD dwCursorPosition);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleCP(uint wCodePageID);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleOutputCP(uint wCodePageID);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    private static void Require(bool success, string operation)
    {
        if (!success)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), operation);
        }
    }

    public static string Apply(int width, int height, int left, int top, uint backgroundColor, string layoutLabel)
    {
        IntPtr output = GetStdHandle(-11);
        if (output == IntPtr.Zero || output == new IntPtr(-1))
        {
            throw new InvalidOperationException("CMD has no active console output handle.");
        }

        CONSOLE_FONT_INFOEX font = new CONSOLE_FONT_INFOEX();
        font.cbSize = (uint)Marshal.SizeOf(typeof(CONSOLE_FONT_INFOEX));
        font.nFont = 0;
        font.dwFontSize = new COORD { X = 9, Y = 20 };
        font.FontFamily = 54;
        font.FontWeight = 400;
        font.FaceName = "Consolas";
        Require(SetCurrentConsoleFontEx(output, false, ref font), "Set CMD font");

        Require(SetConsoleScreenBufferSize(output, new COORD { X = 121, Y = 61 }), "Set CMD screen buffer size");

        CONSOLE_SCREEN_BUFFER_INFOEX info = new CONSOLE_SCREEN_BUFFER_INFOEX();
        info.cbSize = (uint)Marshal.SizeOf(typeof(CONSOLE_SCREEN_BUFFER_INFOEX));
        info.ColorTable = new uint[16];
        Require(GetConsoleScreenBufferInfoEx(output, ref info), "Read CMD color settings");
        info.ColorTable[0] = backgroundColor;
        info.wAttributes = 0x000A;
        info.wPopupAttributes = 0x000C;
        Require(SetConsoleScreenBufferInfoEx(output, ref info), "Set CMD colors");

        SMALL_RECT window = new SMALL_RECT { Left = 0, Top = 0, Right = (short)(width - 1), Bottom = (short)(height - 1) };
        Require(SetConsoleWindowInfo(output, true, ref window), "Set CMD window size");
        Require(SetConsoleTextAttribute(output, 0x000A), "Set CMD text color");

        COORD origin = new COORD { X = 0, Y = 0 };
        uint written;
        FillConsoleOutputCharacter(output, ' ', 121U * 61U, origin, out written);
        FillConsoleOutputAttribute(output, 0x000A, 121U * 61U, origin, out written);
        Require(SetConsoleCursorPosition(output, origin), "Reset CMD cursor position");
        Require(SetConsoleCP(437), "Set CMD input code page");
        Require(SetConsoleOutputCP(437), "Set CMD output code page");

        IntPtr windowHandle = GetConsoleWindow();
        if (windowHandle != IntPtr.Zero)
        {
            Require(SetWindowPos(windowHandle, IntPtr.Zero, left, top, 0, 0, 0x0015), "Set CMD window position");
        }

        return layoutLabel;
    }
}
'@ -ErrorAction Stop

    $selectedStyle = [CmdWindowStyleNative]::Apply(
        [int]$selectedLayout.Width,
        [int]$selectedLayout.Height,
        [int]$selectedLayout.Left,
        [int]$selectedLayout.Top,
        [uint32]$selectedLayout.Background,
        [string]$selectedLayout.Label
    )
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format s) Applied $selectedStyle; active console windows=$activeConsoleCount; style layout count=$($styleLayouts.Count)"
} catch {
    Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format s) FAILED: $($_.Exception.Message)"
    exit 1
}
