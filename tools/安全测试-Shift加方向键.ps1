# 安全性测试 v2：用 SendKeys 造"Shift+方向键选中"，验证工具不会抢转换
[CmdletBinding()]
param()
Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class SB {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
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
}
'@
function Pump([int]$ms) {
    $deadline = [DateTime]::Now.AddMilliseconds($ms)
    while ([DateTime]::Now -lt $deadline) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 }
}
$logPath = Join-Path $PSScriptRoot '..\日志\运行日志.log'
$before = @(Get-Content $logPath -Encoding UTF8 -ErrorAction SilentlyContinue).Count

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Shift+方向键 安全性测试 v2'; $form.Width = 760; $form.Height = 180
$form.StartPosition = 'CenterScreen'; $form.TopMost = $true
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true; $tb.Dock = 'Fill'
$tb.Font = New-Object System.Drawing.Font('Consolas', 15)
$form.Controls.Add($tb)
$form.Show(); Pump 300
for ($i = 1; $i -le 6; $i++) {
    [SB]::ForceForeground($form.Handle) | Out-Null
    Pump 100; $tb.Focus() | Out-Null; Pump 100
    if ([SB]::GetForegroundWindow() -eq $form.Handle) { break }
}

try {
    $tb.Text = 'wo ming tian qu bei jing'
    $tb.Focus() | Out-Null; Pump 150
    $tb.SelectionStart = 0; $tb.SelectionLength = 0; Pump 200

    # SendKeys 造 Shift+右方向键（跨进程按键，工具钩子能看到）
    [System.Windows.Forms.SendKeys]::SendWait('+{RIGHT 5}')
    Pump 600
    "Shift+Right 后选区长度: $($tb.SelectionLength)（应大于 0，否则测试本身无效）"

    Pump 2200
    $after = @(Get-Content $logPath -Encoding UTF8 -ErrorAction SilentlyContinue)
    $new = if ($after.Count -gt $before) { $after[$before..($after.Count - 1)] } else { @() }
    "工具新增日志条数: $($new.Count)"
    $new | ForEach-Object { "  $_" }
    if ($new.Count -eq 0) { "结论: 没有触发转换（符合预期）" } else { "结论: 触发了工具，判定逻辑需修" }
}
finally {
    $form.Close()
}
