<#
  拼音选中回改 · 一键安装
  用法:
    powershell -ExecutionPolicy Bypass -File .\安装.ps1
    powershell -ExecutionPolicy Bypass -File .\安装.ps1 -AutoStart   # 同时加入开机自启
    powershell -ExecutionPolicy Bypass -File .\安装.ps1 -Proxy http://127.0.0.1:7890
#>
[CmdletBinding()]
param(
    [switch]$AutoStart,
    [string]$Proxy = ''
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$binDir = Join-Path $root 'bin\AutoHotkey'
$exe = Join-Path $binDir 'AutoHotkey64.exe'
$scriptPath = Join-Path $root '拼音选中回改.ahk'
$ahkUrl = 'https://www.autohotkey.com/download/ahk-v2.zip'

if (-not (Test-Path $scriptPath)) { throw "找不到 拼音选中回改.ahk，请在项目根目录运行此脚本" }

function Download-AhkZip([string]$url, [string]$outFile, [string]$proxy) {
    # 优先 curl.exe（Windows 10 1803+ 自带；比 Invoke-WebRequest 稳）
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        $curlArgs = @('-sL', '--max-time', '180', '-o', $outFile)
        if ($proxy) { $curlArgs += @('--proxy', $proxy) }
        $curlArgs += $url
        & $curl.Source @curlArgs
    } else {
        $iwArgs = @{ Uri = $url; OutFile = $outFile; UseBasicParsing = $true }
        if ($proxy) { $iwArgs['Proxy'] = $proxy }
        Invoke-WebRequest @iwArgs
    }
    if (-not (Test-Path $outFile)) { throw '文件不存在' }
    if ((Get-Item $outFile).Length -lt 200000) { throw ('文件过小(' + (Get-Item $outFile).Length + ' 字节)，可能被代理/杀软拦截') }
}

if (-not (Test-Path $exe)) {
    Write-Host '正在下载 AutoHotkey v2 便携版（约 3MB）...'
    $zip = Join-Path $env:TEMP 'ahk-v2.zip'
    Remove-Item $zip -ErrorAction SilentlyContinue
    try {
        Download-AhkZip $ahkUrl $zip $Proxy
    } catch {
        Write-Host ('自动下载失败: ' + $_.Exception.Message)
        Write-Host '请手动下载: https://www.autohotkey.com/download/ahk-v2.zip'
        Write-Host ('解压后把 AutoHotkey64.exe 放到: ' + $binDir)
        exit 1
    }
    Write-Host '正在解压...'
    $tmp = Join-Path $root 'bin\_ahk_unzip'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $exeSrc = Get-ChildItem $tmp -Recurse -Filter 'AutoHotkey64.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exeSrc) { throw '压缩包里没找到 AutoHotkey64.exe，请手动下载 AutoHotkey v2 便携版' }
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    Copy-Item $exeSrc.FullName $exe -Force
    $licSrc = Get-ChildItem $tmp -Recurse -Filter 'license.txt' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($licSrc) { Copy-Item $licSrc.FullName (Join-Path $binDir 'license.txt') -Force }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ("AutoHotkey 已就位: {0}" -f $exe)
} else {
    Write-Host 'AutoHotkey 已存在，跳过下载。'
}

Write-Host '正在创建快捷方式...'
$lnkPath = Join-Path $root '拼音选中回改.lnk'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = $exe
$lnk.Arguments = '"' + $scriptPath + '"'
$lnk.WorkingDirectory = $root
$lnk.WindowStyle = 1
$lnk.Description = '拼音选中回改：选中拼音单按 Shift 变中文'
$lnk.IconLocation = ($exe + ',0')
$lnk.Save()
Write-Host ("快捷方式: {0}" -f $lnkPath)

if ($AutoStart) {
    $startup = [Environment]::GetFolderPath('Startup')
    Copy-Item $lnkPath (Join-Path $startup '拼音选中回改.lnk') -Force
    Write-Host '已加入开机自启。'
}

Write-Host ''
Write-Host '安装完成。双击「拼音选中回改.lnk」启动（托盘出现图标即成功）。'
Write-Host '用法：英文状态打出拼音 -> 选中 -> 单按 Shift -> 数字选词/空格上屏。'
Write-Host '如需卸载：托盘右键退出，删除本文件夹（以及开机自启里的快捷方式）。'
