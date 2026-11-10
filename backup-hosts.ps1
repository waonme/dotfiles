# backup-hosts.ps1 — この PC の設定値を dotfiles-hosts/<COMPUTERNAME>/ に吸い上げて、コミット・push する
# 対象は lib/hosts.ps1 の Get-HostManifest に載っているファイルだけ。書くのもコミットするのも自分のフォルダだけ
# Usage:
#   pwsh -File ~/dotfiles/backup-hosts.ps1          # 差分を見せて確認してからコミット・push
#   pwsh -File ~/dotfiles/backup-hosts.ps1 -Yes     # 確認なし
#   pwsh -File ~/dotfiles/backup-hosts.ps1 -Auto    # タスクスケジューラ用。確認なし、失敗は印を置いて setup.ps1 で知らせる
#   -NoPush を付けるとコミットまで

param(
    [switch]$Auto,
    [switch]$Yes,
    [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\hosts.ps1")

function Write-Log {
    param([string]$Message, [string]$Color = "Gray")
    if (-not (Test-Path $DotfilesStateDir)) { New-Item -ItemType Directory -Force -Path $DotfilesStateDir | Out-Null }
    $mode = if ($Auto) { "auto" } else { "manual" }
    Add-Content -Path $BackupLog -Value ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $mode, $Message)
    Write-Host $Message -ForegroundColor $Color
}

# git は進捗を stderr に出す。Windows PowerShell 5.1 ではそれが例外になるので、終了コードで判断する
# 引数は配列で渡す（'--' や '-q' を PowerShell 自身の引数として解釈させないため）
function Invoke-Git {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & git -C $HostsRoot @GitArgs 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($code -ne 0) { throw "git $($GitArgs -join ' ') failed ($code): $($out -join ' / ')" }
    return $out
}

# 吸い上げたコピーを取り消す（コミット済みの中身に戻す。まだ一度もコミットしていない新しいファイルは残る）
function Undo-Capture {
    Invoke-Git @('reset', '-q', '--', "$HostName/") | Out-Null
    $tracked = @(Invoke-Git @('ls-files', '--', "$HostName/"))
    if ($tracked.Count -gt 0) { Invoke-Git @('checkout', '-q', '--', "$HostName/") | Out-Null }
}

try {
    if ([string]::IsNullOrWhiteSpace($HostName)) { throw "COMPUTERNAME is empty; refusing to guess the host folder." }
    if (-not (Test-Path (Join-Path $HostsRoot ".git"))) { throw "$HostsRoot is not a git clone of dotfiles-hosts." }

    # 自分のフォルダ以外に未コミットの変更があれば止める（ほかの PC の値を巻き込まない）
    $hostPrefix = "$HostName/"
    $dirty = @(Invoke-Git @('status', '--porcelain', '--untracked-files=all') | Where-Object { $_ -and -not $_.Substring(3).Trim('"').StartsWith($hostPrefix) })
    if ($dirty.Count -gt 0) { throw "Uncommitted changes outside $hostPrefix in ${HostsRoot}: $($dirty -join ', ')" }

    $hasRemote = [bool](Invoke-Git @('remote'))
    if ($hasRemote) { Invoke-Git @('pull', '--rebase', '--autostash', '--quiet') | Out-Null }

    $hostDir = Join-Path $HostsRoot $HostName
    if (-not (Test-Path $hostDir)) { New-Item -ItemType Directory -Force -Path $hostDir | Out-Null }

    $captured = @()
    foreach ($entry in Get-HostManifest) {
        if (Test-Path $entry.Dest) {
            Copy-Item $entry.Dest (Get-HostFilePath $entry.Name) -Force
            $captured += $entry
        } else {
            Write-Log "  skip $($entry.Name): $($entry.Dest) does not exist"
        }
    }

    Invoke-Git @('add', '--', $hostPrefix) | Out-Null
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & git -C $HostsRoot diff --cached --quiet '--' $hostPrefix
    $changed = ($LASTEXITCODE -ne 0)
    $ErrorActionPreference = $prev

    if (-not $changed) {
        Write-Log "No changes for $HostName."
    } else {
        Write-Host ""
        Invoke-Git @('diff', '--cached', '--stat', '--', $hostPrefix) | Write-Host
        if (-not $Auto) { Invoke-Git @('diff', '--cached', '--', $hostPrefix) | Write-Host }

        if (-not ($Auto -or $Yes)) {
            $answer = Read-Host "Commit and push these changes? [y/N]"
            if ($answer -notmatch '^[yY]') {
                Undo-Capture
                Write-Host "Cancelled; nothing committed." -ForegroundColor Yellow
                exit 0
            }
        }

        # 秘密の値が混じっていないか（値は表示しない）。gitleaks が無ければコミットしない
        if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) { throw "gitleaks not found; refusing to commit (scoop install gitleaks)." }
        $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & gitleaks git --pre-commit --staged --redact --no-banner $HostsRoot 2>&1 | ForEach-Object { "$_" } | Write-Host
        $leakCode = $LASTEXITCODE
        $ErrorActionPreference = $prev
        if ($leakCode -ne 0) {
            Undo-Capture
            throw "gitleaks found something that looks like a secret; nothing committed."
        }

        $names = ($captured | ForEach-Object { $_.Name }) -join ", "
        $mode = if ($Auto) { "auto" } else { "manual" }
        Invoke-Git @('commit', '-q', '-m', "backup ${HostName}: $names ($mode)", '--', $hostPrefix) | Out-Null
        Write-Log "Committed backup for $HostName ($names)." "Green"

        if ($hasRemote -and -not $NoPush) {
            try {
                Invoke-Git @('push', '-q') | Out-Null
            } catch {
                # ほかの PC が先に push していた → 取り込んでからもう一度だけ
                Invoke-Git @('pull', '--rebase', '--quiet') | Out-Null
                Invoke-Git @('push', '-q') | Out-Null
            }
            Write-Log "Pushed." "Green"
        }
    }

    # 吸い上げた中身を控えにする（次の setup.ps1 が「手で直された」と誤って警告しないように）
    foreach ($entry in $captured) { Save-DeployedState (Get-HostFilePath $entry.Name) $entry.Name }
    if (Test-Path $BackupFailedMarker) { Remove-Item $BackupFailedMarker -Force }
    exit 0
} catch {
    Write-Log "[ERROR] $($_.Exception.Message)" "Red"
    if ($Auto) {
        Set-Content -Path $BackupFailedMarker -Value ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $_.Exception.Message)
    }
    exit 1
}
