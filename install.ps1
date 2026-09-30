# Install (or update) hlabtop on Windows from the latest release on GitHub.
#
#   irm https://raw.githubusercontent.com/RVP-Techworks/hlabtop/main/install.ps1 | iex
#
# Puts hlabtop.exe in %LOCALAPPDATA%\Programs\hlabtop and adds a Start menu shortcut.
# No admin rights needed. Run it again to update. To remove it:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/RVP-Techworks/hlabtop/main/install.ps1))) -Uninstall
#
# Saved connections and workspaces (%APPDATA%\hlabtop) are kept either way.
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Windows PowerShell's progress bar makes downloads crawl
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = 'RVP-Techworks/hlabtop'
$api = if ($env:HLABTOP_API) { $env:HLABTOP_API } else { "https://api.github.com/repos/$repo/releases/latest" }
$dir = if ($env:HLABTOP_DIR) { $env:HLABTOP_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\hlabtop' }
$menu = if ($env:HLABTOP_MENU_DIR) { $env:HLABTOP_MENU_DIR } else { [Environment]::GetFolderPath('Programs') }
$exe = Join-Path $dir 'hlabtop.exe'
$shortcut = Join-Path $menu 'hlabtop.lnk'

function Say($text) { Write-Host $text -ForegroundColor Cyan }

function Stop-IfRunning {
    $running = Get-Process hlabtop -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }
    if ($running) { throw "hlabtop is running - close it first, then run this again." }
}

if ($Uninstall) {
    Stop-IfRunning
    $removed = $false
    if (Test-Path $shortcut) { Remove-Item $shortcut -Force; $removed = $true }
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force; $removed = $true }
    if ($removed) { Say 'hlabtop removed. (Saved connections and workspaces in %APPDATA%\hlabtop are kept.)' }
    else { Say "hlabtop isn't installed (by this script)." }
    return
}

Say 'Finding the latest hlabtop release...'
$release = Invoke-RestMethod -Uri $api -UseBasicParsing
$asset = $release.assets | Where-Object { $_.name -like '*-windows-x64.exe' } | Select-Object -First 1
if (-not $asset) { throw "No Windows download in release $($release.tag_name)." }

Stop-IfRunning
Say "Downloading hlabtop $($release.tag_name)..."
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$download = "$exe.download"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $download -UseBasicParsing
Move-Item -Force $download $exe
Unblock-File $exe  # you chose to install it: no "downloaded from the internet" prompt

New-Item -ItemType Directory -Force -Path $menu | Out-Null
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcut)
$link.TargetPath = $exe
$link.WorkingDirectory = $dir
$link.Description = 'hlabtop - top for your homelab'
$link.Save()

Say "Installed hlabtop $($release.tag_name). Open it from the Start menu (search for hlabtop)."
Write-Host 'Run this again any time to update.'
