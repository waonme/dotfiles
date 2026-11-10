# lib/hosts.ps1 — PC ごとの設定値（非公開リポジトリ dotfiles-hosts）を扱う共通部分
# setup.ps1（配る）と backup-hosts.ps1（吸い上げる）が dot-source する
# 初回は Windows PowerShell 5.1 で読まれることがある（BOM なし UTF-8 → CP932）。文字列リテラルは ASCII に保つ

$DotfilesRoot = Split-Path $PSScriptRoot -Parent
# 既定は dotfiles と同じ階層の dotfiles-hosts。別の場所なら環境変数 DOTFILES_HOSTS
$HostsRoot = if ($env:DOTFILES_HOSTS) { $env:DOTFILES_HOSTS } else { Join-Path (Split-Path $DotfilesRoot -Parent) "dotfiles-hosts" }
$HostName = $env:COMPUTERNAME
$DotfilesStateDir = Join-Path $(if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $env:HOME }) "dotfiles"
# 最後に配った（または吸い上げた）中身の控え。配り先が控えと同じなら手で直されていないので、上書きしてよい
$DeployedStateDir = Join-Path $DotfilesStateDir "deployed"
# 自動バックアップが失敗したときに置く印。setup.ps1 が見つけたら知らせる
$BackupFailedMarker = Join-Path $DotfilesStateDir "backup-failed.txt"
$BackupLog = Join-Path $DotfilesStateDir "backup.log"

# --- PC ごとに管理するファイルの一覧 -------------------------------------------
# 配るのも吸い上げるのも、ここに載っているものだけ。増やすときはここに足す
#   Name     : dotfiles-hosts/<COMPUTERNAME>/ の中のファイル名
#   Dest     : この PC での置き場所
#   Template : dotfiles 側の型（この PC 用のファイルがまだ無いときだけ配る）
function Get-HostManifest {
    @(
        [pscustomobject]@{
            Name     = ".wslconfig"
            Dest     = Join-Path $env:USERPROFILE ".wslconfig"
            Template = Join-Path $DotfilesRoot "wsl\.wslconfig"
        }
    )
}

function Get-HostFilePath {
    param([Parameter(Mandatory = $true)][string]$Name)
    Join-Path (Join-Path $HostsRoot $HostName) $Name
}

function Save-DeployedState {
    param([string]$From, [string]$Name)
    if (-not (Test-Path $DeployedStateDir)) { New-Item -ItemType Directory -Force -Path $DeployedStateDir | Out-Null }
    Copy-Item $From (Join-Path $DeployedStateDir $Name) -Force
}

function Install-HostFile {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Template,
        [Parameter(Mandatory = $true)][string]$Dest
    )
    $hostFile = Get-HostFilePath $Name
    $stateFile = Join-Path $DeployedStateDir $Name

    if (Test-Path $hostFile) {
        $src = Get-Content -Raw $hostFile
        $state = if (Test-Path $stateFile) { Get-Content -Raw $stateFile } else { $null }
        if (Test-Path $Dest) {
            $cur = Get-Content -Raw $Dest
            if ($cur -eq $src) {
                Write-Host "  Up to date: $Dest" -ForegroundColor Gray
                Save-DeployedState $hostFile $Name
                return
            }
            if ($null -eq $state -or $cur -ne $state) {
                # 配ったあとに手で直された（または控えが無く判断できない）→ 上書きしない
                Write-Host "  [WARN] $Dest differs from $hostFile and was not written by this script; left untouched." -ForegroundColor Yellow
                Write-Host "         Keep yours: run backup-hosts.ps1. Take the repo's: delete $Dest and re-run." -ForegroundColor Yellow
                return
            }
        }
        Copy-Item $hostFile $Dest -Force
        Save-DeployedState $hostFile $Name
        Write-Host "  Deployed $hostFile -> $Dest" -ForegroundColor Gray
        return
    }

    # この PC 用のファイルが無い。別の PC のものは使わない
    if (-not (Test-Path $HostsRoot)) {
        Write-Host "  [WARN] $HostsRoot not found. Clone the private dotfiles-hosts repo there, or set DOTFILES_HOSTS." -ForegroundColor Yellow
    }
    if (-not (Test-Path $Dest)) {
        Copy-Item $Template $Dest
        Write-Host "  [WARN] No $hostFile; copied the template to $Dest." -ForegroundColor Yellow
        Write-Host "         Fill in this machine's values, then run backup-hosts.ps1." -ForegroundColor Yellow
    } else {
        Write-Host "  [WARN] No $hostFile; existing $Dest left untouched. Run backup-hosts.ps1 to save it." -ForegroundColor Yellow
    }
}
