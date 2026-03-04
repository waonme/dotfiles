# dotfiles setup script
# Usage:
#   初回: powershell -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1
#   2回目以降: pwsh -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1
#   pwsh -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1 -KeepOpen

param(
    [switch]$KeepOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host "=== dotfiles setup ===" -ForegroundColor Cyan

function Invoke-ScoopInstallFromFile {
    param(
        [Parameter(Mandatory = $true)][string]$ScoopFilePath
    )

    $scoopData = Get-Content -Raw $ScoopFilePath | ConvertFrom-Json
    Write-Host "  Using direct bucket/app install flow (scoop import is noisy in this environment)." -ForegroundColor Yellow

    if ($scoopData.buckets) {
        Write-Host "  Ensuring buckets..." -ForegroundColor Gray
        foreach ($bucket in $scoopData.buckets) {
            $bucketName = [string]$bucket.Name
            if ([string]::IsNullOrWhiteSpace($bucketName)) { continue }
            Add-ScoopBucketIfMissing -Name $bucketName -Source $bucket.Source
        }
    }

    if ($scoopData.apps) {
        Write-Host "  Installing apps listed in scoopfile..." -ForegroundColor Gray
        foreach ($app in $scoopData.apps) {
            if ([string]::IsNullOrWhiteSpace([string]$app)) { continue }
            try {
                scoop install $app | Out-Host
            } catch {
                Write-Host "  [WARN] Failed to install '$app'." -ForegroundColor Red
                Write-Host "         $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

function Invoke-RegImportWithFallback {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$RequiresAdmin,
        [switch]$NeedExplorerRestart
    )

    $fileName = Split-Path $Path -Leaf

    if (-not (Test-Path $Path)) {
        Write-Host "  Skip missing file: $fileName" -ForegroundColor Yellow
        return
    }

    if ($RequiresAdmin -and -not (Test-IsAdmin)) {
        Write-Host "  [WARN] $fileName requires administrator. Re-run setup as admin." -ForegroundColor Yellow
        return
    }

    Write-Host "  Importing $fileName ..." -ForegroundColor Gray
    $importOutput = (& reg import $Path 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        if ($NeedExplorerRestart) {
            $script:NeedExplorerRestart = $true
        }
    } else {
        Write-Host "  [WARN] Failed: $fileName (exit=$exitCode)" -ForegroundColor Yellow
        if ($importOutput.Trim()) {
            Write-Host "         $($importOutput.Trim())" -ForegroundColor Yellow
        }
        if ($NeedExplorerRestart) {
            Write-Host "  [INFO] Retrying $fileName after restarting explorer..." -ForegroundColor Gray
            try {
                taskkill /f /im explorer.exe 2>$null
                Start-Sleep -Milliseconds 700
                $retryOutput = (& reg import $Path 2>&1 | Out-String)
                $retryCode = $LASTEXITCODE
                if ($retryCode -eq 0) {
                    Write-Host "  [OK] Retried $fileName" -ForegroundColor Green
                    $script:NeedExplorerRestart = $true
                } else {
                    Write-Host "  [WARN] Retry failed: $fileName (exit=$retryCode)" -ForegroundColor Yellow
                    if ($retryOutput.Trim()) {
                        Write-Host "         $($retryOutput.Trim())" -ForegroundColor Yellow
                    }
                    $script:NeedExplorerRestart = $true
                }
            } catch {
                Write-Host "  [WARN] Retry failed to run: $($fileName)" -ForegroundColor Yellow
            } finally {
                Start-Process explorer.exe
            }
        }
    }
}

function Add-ScoopBucketIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)][string]$Source
    )

    $exists = $false
    try {
        $rawBuckets = (scoop bucket list 2>$null | Out-String)
        $normalized = $rawBuckets -replace "\\x1B\\[[0-9;]*[ -/]*[@-~]", ""
        $buckets = $normalized -split "`r?`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^([A-Za-z0-9\.\-_]+)\s+') { $matches[1] }
        } | Where-Object { $_ -and $_ -notin @('Name','----') }
        $exists = $buckets -contains $Name
    } catch {
        $exists = $false
    }
    if (-not $exists) {
        try {
            if ([string]::IsNullOrWhiteSpace($Source)) {
                scoop bucket add $Name | Out-Null
            } else {
                scoop bucket add $Name $Source | Out-Null
            }
            Write-Host "  Added bucket: $Name" -ForegroundColor Gray
        } catch {
            # some Scoop versions still emit warnings instead of throwing, so ignore duplicates.
            if ($_.Exception.Message -notmatch "already exists") {
                Write-Host "  [WARN] Failed to add bucket $Name" -ForegroundColor Yellow
            }
        }
    }
}

# 1. Install Scoop if not present
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "Scoop is already installed." -ForegroundColor Green
}

# 2. Import Scoop packages
$scoopfile = Join-Path $PSScriptRoot "scoopfile.json"
if (Test-Path $scoopfile) {
    Write-Host "Importing Scoop packages from scoopfile.json..." -ForegroundColor Yellow
    Invoke-ScoopInstallFromFile -ScoopFilePath $scoopfile
} else {
    Write-Host "scoopfile.json not found, skipping." -ForegroundColor Red
}

# 3. Import registry settings
Write-Host ""
Write-Host "Importing registry settings..." -ForegroundColor Yellow
$regFiles = @(
    @{ Path = "keyboard\capslock-to-ctrl.reg"; RequiresAdmin = $true; NeedExplorerRestart = $true }
    @{ Path = "explorer\settings.reg"; RequiresAdmin = $false; NeedExplorerRestart = $true }
    @{ Path = "mouse\no-acceleration.reg"; RequiresAdmin = $false; NeedExplorerRestart = $true }
    @{ Path = "taskbar\cleanup.reg"; RequiresAdmin = $false; NeedExplorerRestart = $true }
    @{ Path = "context-menu\classic.reg"; RequiresAdmin = $false; NeedExplorerRestart = $true }
    @{ Path = "windows\tweaks.reg"; RequiresAdmin = $false; NeedExplorerRestart = $true }
)
$script:NeedExplorerRestart = $false
foreach ($reg in $regFiles) {
    Invoke-RegImportWithFallback -Path (Join-Path $PSScriptRoot $reg.Path) -RequiresAdmin:($reg.RequiresAdmin) -NeedExplorerRestart:($reg.NeedExplorerRestart)
}

# 4. Set up PowerShell profile
Write-Host ""
Write-Host "Setting up PowerShell profile..." -ForegroundColor Yellow
$shellProfile = Join-Path $PSScriptRoot "shell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $shellProfile) {
$documentsRoot = [Environment]::GetFolderPath('MyDocuments')
$powershellProfilePath = Join-Path -Path $documentsRoot -ChildPath "PowerShell"
$legacyPowershellProfilePath = Join-Path -Path $documentsRoot -ChildPath "WindowsPowerShell"
$profileRoots = @(
    $powershellProfilePath
    $legacyPowershellProfilePath
)
    foreach ($root in $profileRoots) {
        if (-not (Test-Path $root)) {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
        }
        Copy-Item $shellProfile (Join-Path $root "Microsoft.PowerShell_profile.ps1") -Force
        Write-Host "  Updated profile: $root\\Microsoft.PowerShell_profile.ps1" -ForegroundColor Gray
    }
} else {
    Write-Host "  PowerShell profile not found, skipping." -ForegroundColor Red
}

# 5. Git config (include portable settings)
Write-Host ""
Write-Host "Setting up Git config..." -ForegroundColor Yellow
$gitConfig = Join-Path $PSScriptRoot "git\config"
if (Test-Path $gitConfig) {
    $gitIncludePath = "~/dotfiles/git/config"
    $currentIncludes = git config --global --get-all include.path 2>$null
    if ($currentIncludes -notcontains $gitIncludePath) {
        git config --global --add include.path $gitIncludePath
        Write-Host "  Added git include.path -> $gitIncludePath" -ForegroundColor Gray
    } else {
        Write-Host "  Git include.path already configured." -ForegroundColor Gray
    }
    git config --global core.autocrlf true
    Write-Host "  Set core.autocrlf = true (Windows)" -ForegroundColor Gray
}

# 6. Install winget apps
Write-Host ""
Write-Host "Installing winget apps..." -ForegroundColor Yellow
$wingetApps = @(
    @{ Id = "9NK4T08DHQ80";    Source = "msstore"; Name = "Dropbox" }
    @{ Id = "XPDBVSS44R0L9H";  Source = "msstore"; Name = "Notion" }
    @{ Id = "RustDesk.RustDesk"; Source = "winget"; Name = "RustDesk" }
    @{ Id = "ogdesign.Eagle";   Source = "winget"; Name = "Eagle" }
    @{ Id = "Anthropic.Claude"; Source = "winget"; Name = "Claude" }
    @{ Id = "Anthropic.ClaudeCode"; Source = "winget"; Name = "Claude Code" }
    @{ Id = "OpenAI.Codex";     Source = "winget"; Name = "Codex CLI" }
)
foreach ($app in $wingetApps) {
    $installed = winget list --id $app.Id --accept-source-agreements 2>$null | Out-String
    if ($installed -match [regex]::Escape($app.Id)) {
        Write-Host "  $($app.Name) is already installed." -ForegroundColor Gray
    } else {
        Write-Host "  Installing $($app.Name) ..." -ForegroundColor Gray
        winget install --id $app.Id --source $app.Source --accept-package-agreements --accept-source-agreements --silent
    }
}

# 7. Copy .wslconfig
Write-Host ""
Write-Host "Setting up WSL config..." -ForegroundColor Yellow
$wslConfig = Join-Path $PSScriptRoot "wsl\.wslconfig"
$wslDest = Join-Path $env:USERPROFILE ".wslconfig"
if (Test-Path $wslConfig) {
    Copy-Item $wslConfig $wslDest -Force
    Write-Host "  Copied .wslconfig to $wslDest" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
if ($NeedExplorerRestart) {
    Write-Host "  - Restart explorer: taskkill /f /im explorer.exe & start explorer.exe"
}
Write-Host "  - Restart PC for CapsLock remap and context menu changes"
Write-Host "  - Merge windows-terminal/*.json into Windows Terminal settings"
Write-Host "  - PowerShell profile: setup.ps1 already copied it"
Write-Host "  - zsh config: ln -sf ~/dotfiles/shell/.zshrc ~/.zshrc"

Write-Host "Installed packages:"
scoop list

if ($KeepOpen) {
    Write-Host ""
    Write-Host "Done. Press Enter to close this window..." -ForegroundColor Cyan
    Read-Host
}
