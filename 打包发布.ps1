<#
  拼音选中回改 · 打包发布脚本（维护者用）
  生成一个"解压即用"的便携版 zip：内含 AutoHotkey v2 运行时 + 生成无窗口启动器 + 使用说明。

  用法：
    powershell -ExecutionPolicy Bypass -File .\打包发布.ps1
    powershell -ExecutionPolicy Bypass -File .\打包发布.ps1 -Version v0.2 -SkipRuntime
  输出：dist\拼音选中回改-<Version>.zip
#>
[CmdletBinding()]
param(
    [string]$Version = 'v0.2',
    [switch]$SkipRuntime,
    [string]$AhkUrl = 'https://www.autohotkey.com/download/ahk-v2.zip'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

$distDir  = Join-Path $root 'dist'
$buildDir = Join-Path $distDir ("拼音选中回改-$Version")
$zipPath  = Join-Path $distDir ("拼音选中回改-$Version.zip")
$rtDir    = Join-Path $root 'bin\AutoHotkey'
$rtExe    = Join-Path $rtDir 'AutoHotkey64.exe'

# ---------- 0. 准备运行时 ----------
if (-not $SkipRuntime) {
    if (-not (Test-Path $rtExe)) {
        Write-Host '本地没有 AutoHotkey 运行时，先下载...'
        & (Join-Path $root '安装.ps1')
        if (-not (Test-Path $rtExe)) { throw '运行时准备失败，请先运行 安装.ps1' }
    }
}

# ---------- 1. 组装目录 ----------
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Copy-Item (Join-Path $root '拼音选中回改.ahk') $buildDir
Copy-Item (Join-Path $root '设置.ini') $buildDir
Copy-Item (Join-Path $root '黑名单.txt') $buildDir
Copy-Item (Join-Path $root '安装.ps1') $buildDir
Copy-Item (Join-Path $root 'README.md') $buildDir
Copy-Item (Join-Path $root 'LICENSE') $buildDir

if (-not $SkipRuntime) {
    $dstRt = Join-Path $buildDir 'bin\AutoHotkey'
    New-Item -ItemType Directory -Force -Path $dstRt | Out-Null
    Copy-Item $rtExe $dstRt
    $lic = Join-Path $rtDir 'license.txt'
    if (Test-Path $lic) { Copy-Item $lic $dstRt }
}

# ---------- 2. 生成无窗口启动器（VBS，UTF-16 LE + BOM） ----------
$vbs = @'
' 拼音选中回改 启动器（无窗口，双击即可）
Option Explicit
Dim fso, sh, base, exe, scr
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
base = fso.GetParentFolderName(WScript.ScriptFullName)
exe = base & "\bin\AutoHotkey\AutoHotkey64.exe"
scr = base & "\拼音选中回改.ahk"
If Not fso.FileExists(exe) Then
    MsgBox "缺少运行库：" & exe & vbCrLf & "请重新解压完整的 zip，或运行 安装.ps1 自动下载。", 16, "拼音选中回改"
    WScript.Quit 1
End If
If Not fso.FileExists(scr) Then
    MsgBox "缺少主程序：" & scr, 16, "拼音选中回改"
    WScript.Quit 1
End If
sh.Run """" & exe & """ """ & scr & """", 0, False
'@
[IO.File]::WriteAllText((Join-Path $buildDir '双击这里启动.vbs'), $vbs, [Text.Encoding]::Unicode)

# ---------- 3. 使用说明（UTF-8 BOM，记事本可读） ----------
$guide = @'
拼音选中回改 v0.2 · 使用说明（30 秒版）
========================================

【启动】
1. 先把整个文件夹解压到任意位置（不要只从压缩包里拖出单个文件）
2. 双击「双击这里启动.vbs」
3. 右下角托盘出现小图标 = 已启动。没有窗口、不联网，属正常现象。

【使用】
1. 在任意输入框里，用英文状态打出拼音，例如： wo ming tian qu bei jing
2. 用鼠标选中这段拼音
3. 单按一下 Shift（不要长按，也不要按住 Shift 再按别的键）
4. 出现中文候选后：空格/回车 上屏第一个，数字 1-9 选其它候选

【常用操作】
· 托盘图标右键：暂停/启用、诊断当前窗口、打开设置.ini、打开日志、退出
· 想开机自启：在本文件夹按住 Shift 右键 -> 「在此处打开 PowerShell 窗口」，
  执行： powershell -ExecutionPolicy Bypass -File .\安装.ps1 -AutoStart
  （安装.ps1 还可以帮你创建桌面/文件夹快捷方式）
· 改设置：用记事本打开 设置.ini，改完在托盘菜单点「重新加载」

【常见问题】
Q 按了 Shift 没反应？
  确认选中了文字；确认光标在输入框里；托盘右键 -> 打开日志，看最后一行写了什么。
Q 杀毒软件报毒？
  zip 里包含的是 AutoHotkey 便携运行时，部分杀软会误报。可以：
  ① 添加信任；② 删除 bin 文件夹，然后运行 安装.ps1 从官网重新下载运行时。
Q 我的输入法不是 Shift 切中英？
  打开 设置.ini，把 [ime] 下的 ToggleKey 改成你的切换键（例如 Ctrl+Space），
  然后在托盘菜单点「重新加载」。触发键仍可用 Shift。
Q 双拼/五笔能用吗？
  不能。本工具回灌的是全拼字母串，双拼/五笔会把字母按各自方案解析。只支持全拼。

【卸载】
托盘图标右键 -> 退出，然后删除整个文件夹即可。

【第三方组件】
AutoHotkey v2 便携运行时，GPL-2.0 许可。
源码：https://github.com/AutoHotkey/AutoHotkey
许可文本：bin\AutoHotkey\license.txt
'@
[IO.File]::WriteAllText((Join-Path $buildDir '使用说明.txt'), $guide, (New-Object System.Text.UTF8Encoding($true)))

# ---------- 4. 打 zip（条目用正斜杠，跨平台解压安全） ----------
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
Remove-Item $zipPath -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$baseLen = $buildDir.Length + 1
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    Get-ChildItem $buildDir -Recurse -File | ForEach-Object {
        $rel = ((Split-Path $buildDir -Leaf) + '/' + $_.FullName.Substring($baseLen)).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel) | Out-Null
    }
} finally { $zip.Dispose() }

$size = (Get-Item $zipPath).Length
Write-Host ''
Write-Host ('打包完成: ' + $zipPath)
Write-Host ('大小: {0:N0} 字节 ({1:N1} MB)' -f $size, ($size / 1MB))
Write-Host '内容:'
Get-ChildItem $buildDir -Recurse -File | ForEach-Object { '  ' + $_.FullName.Substring($baseLen) }
