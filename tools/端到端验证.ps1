# 端到端验证：真实前台文本框 + 真实按键（Shift 触发工具）+ 真实候选上屏
[CmdletBinding()]
param(
    [string]$Text = 'wo ming tian qu bei jing',
    [switch]$NoSelection,
    [string]$CommitKey = 'space',        # space | 2 | none
    [int]$WaitAfterShiftMs = 2600,
    [int]$WaitAfterCommitMs = 900,
    [string]$LogPath = ''
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class E {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);
    [DllImport("imm32.dll")] public static extern IntPtr ImmGetContext(IntPtr hWnd);
    [DllImport("imm32.dll")] public static extern bool ImmReleaseContext(IntPtr hWnd, IntPtr hIMC);
    [DllImport("imm32.dll")] public static extern bool ImmGetConversionStatus(IntPtr hIMC, out int conversion, out int sentence);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [StructLayout(LayoutKind.Sequential)] public struct GUITHREADINFO {
        public int cbSize; public int flags; public IntPtr hwndActive; public IntPtr hwndFocus;
        public IntPtr hwndCapture; public IntPtr hwndMenuOwner; public IntPtr hwndMoveSize;
        public IntPtr hwndCaret; public int a; public int b; public int c; public int d;
    }
    public static void Down(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); }
    public static void Up(byte vk) { keybd_event(vk, 0, 2, UIntPtr.Zero); }
    public static void Tap(byte vk) { Down(vk); System.Threading.Thread.Sleep(30); Up(vk); }
    public static void ReleaseAll() {
        byte[] keys = { 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 };
        foreach (byte k in keys) keybd_event(k, 0, 2, UIntPtr.Zero);
    }
    public static bool ForceForeground(IntPtr hwnd) {
        uint pid; IntPtr fg = GetForegroundWindow();
        uint fgThread = GetWindowThreadProcessId(fg, out pid);
        uint myThread = GetCurrentThreadId();
        bool att = AttachThreadInput(myThread, fgThread, true);
        bool ok = SetForegroundWindow(hwnd);
        BringWindowToTop(hwnd);
        if (att) AttachThreadInput(myThread, fgThread, false);
        return ok;
    }
    public static IntPtr FocusHwnd() {
        IntPtr fg = GetForegroundWindow();
        uint pid; uint tid = GetWindowThreadProcessId(fg, out pid);
        GUITHREADINFO g = new GUITHREADINFO(); g.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
        if (!GetGUIThreadInfo(tid, ref g)) return IntPtr.Zero;
        return g.hwndFocus;
    }
    public static string Conv(IntPtr hwnd) {
        IntPtr himc = ImmGetContext(hwnd);
        if (himc == IntPtr.Zero) return "no-context";
        int conv, sent;
        bool ok = ImmGetConversionStatus(himc, out conv, out sent);
        ImmReleaseContext(hwnd, himc);
        return ok ? (conv & 1) == 1 ? "CH" : "EN" : "fail";
    }
}
'@

function Pump([int]$ms) {
    $deadline = [DateTime]::Now.AddMilliseconds($ms)
    while ([DateTime]::Now -lt $deadline) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 }
}

$logLines = @()
if ($LogPath -and (Test-Path $LogPath)) { $logLines = @(Get-Content $LogPath -Encoding UTF8) }
$logStart = $logLines.Count

$form = $null
try {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = '拼音选中回改 · 端到端验证'
    $form.Width = 860; $form.Height = 200
    $form.StartPosition = 'CenterScreen'; $form.TopMost = $true
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.Dock = 'Fill'
    $tb.Font = New-Object System.Drawing.Font('Consolas', 15)
    $form.Controls.Add($tb)
    $form.Show(); Pump 300

    $fgOk = $false
    for ($i = 1; $i -le 6; $i++) {
        [E]::ForceForeground($form.Handle) | Out-Null
        Pump 100
        $tb.Focus() | Out-Null
        Pump 100
        if (([E]::GetForegroundWindow() -eq $form.Handle) -and ([E]::FocusHwnd() -eq $tb.Handle)) { $fgOk = $true; break }
    }
    if (-not $fgOk) { throw '无法把验证窗口提到前台' }

    # 先确保英文态（此时文本框为空，避免每次都触发工具），再填内容
    $tb.Text = ''
    $tb.Focus() | Out-Null; Pump 120
    $guard = 0
    while (([E]::Conv($tb.Handle) -ne 'EN') -and $guard -lt 4) { [E]::Tap(0xA0); Pump 300; $guard++ }
    Pump 1700                     # 等工具上一次处理跑完（切态那一下也可能触发工具）
    $tb.Text = $Text
    $tb.Focus() | Out-Null; Pump 150
    "准备: conv=$([E]::Conv($tb.Handle)) text='$($tb.Text)'"

    if ($NoSelection) { $tb.SelectionStart = $tb.Text.Length; $tb.SelectionLength = 0 }
    else { $tb.SelectAll() }
    Pump 150
    "选区: start=$($tb.SelectionStart) len=$($tb.SelectionLength)"

    # 用户单按 Shift（工具应在这一步动作）
    [E]::Down(0xA0); Start-Sleep -Milliseconds 35; [E]::Up(0xA0)
    Pump $WaitAfterShiftMs
    "Shift 后: conv=$([E]::Conv($tb.Handle))"

    switch ($CommitKey) {
        'space' { [E]::Tap(0x20) }
        '2' { [E]::Tap(0x32) }
        'none' { }
    }
    Pump $WaitAfterCommitMs
    "结果文本: '$($tb.Text)'"
    "IME 状态: $([E]::Conv($tb.Handle))"
}
finally {
    [E]::ReleaseAll()
    if ($form) { $form.Close() }
    Start-Sleep -Milliseconds 150
}

if ($LogPath -and (Test-Path $LogPath)) {
    $lines = @(Get-Content $LogPath -Encoding UTF8)
    "--- 工具日志新增 ---"
    if ($lines.Count -gt $logStart) { $lines[$logStart..($lines.Count - 1)] }
}
