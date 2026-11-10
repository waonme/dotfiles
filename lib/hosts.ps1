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

# 比べるための中身。改行は LF にそろえる（Windows の git は取り出すときに CRLF にするので、中身が同じでも違って見える）
function Read-Normalized {
    param([Parameter(Mandatory = $true)][string]$Path)
    $raw = Get-Content -Raw $Path
    if ($null -eq $raw) { return "" }
    return ($raw -replace "`r`n", "`n")
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
        $src = Read-Normalized $hostFile
        $state = if (Test-Path $stateFile) { Read-Normalized $stateFile } else { $null }
        if (Test-Path $Dest) {
            $cur = Read-Normalized $Dest
            if ($cur -eq $src) {
                Write-Host "  Up to date: $Dest" -ForegroundColor Gray
                Save-DeployedState $hostFile $Name
                return
            }
            if ($null -eq $state -or $cur -ne $state) {
                # 配ったあとに手で直された（または控えが無く判断できない）→ 上書きしない
                Write-Host "  [WARN] $Dest differs from $hostFile and was not written by this script; left untouched." -ForegroundColor Yellow
                Write-Host "         Keep yours: double-click backup-hosts.cmd. Take the repo's: delete $Dest and re-run setup." -ForegroundColor Yellow
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
        Write-Host "         Fill in this machine's values, then double-click backup-hosts.cmd." -ForegroundColor Yellow
    } else {
        Write-Host "  [WARN] No $hostFile; existing $Dest left untouched. Double-click backup-hosts.cmd to save it." -ForegroundColor Yellow
    }
}

# --- 毎日の自動バックアップ（タスク \dotfiles\hosts-backup） -------------------------
# setup.ps1 と、手動の backup-hosts.ps1 が成功したときの両方から呼ぶ（dotfiles-hosts をいつ clone しても登録される）
$BackupTaskPath = "\dotfiles\"
$BackupTaskName = "hosts-backup"

function Test-HostsBackupTask {
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return $false }
    return [bool](Get-ScheduledTask -TaskPath $BackupTaskPath -TaskName $BackupTaskName -ErrorAction SilentlyContinue)
}

function Register-HostsBackupTask {
    if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) { return }
    try {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $psExe = if ($pwshCmd) { $pwshCmd.Source } else { (Get-Command powershell).Source }
        $backupScript = Join-Path $DotfilesRoot "backup-hosts.ps1"
        # conhost --headless: 窓を一瞬も出さずに走らせる（Windows 11）
        $action = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$backupScript`" -Auto"
        # 12:00 に走り、PC が切れていたら次に起動したとき走る。ログオン中だけ（git の認証に Credential Manager を使うため）
        $trigger = New-ScheduledTaskTrigger -Daily -At "12:00"
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $BackupTaskName -TaskPath $BackupTaskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        Write-Host "  Registered task $BackupTaskPath$BackupTaskName (daily 12:00). Log: $BackupLog" -ForegroundColor Gray
    } catch {
        Write-Host "  [WARN] Could not register the backup task: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- git の名前とメールアドレス ----------------------------------------------------
# コミットに要る。公開リポジトリには書かず ~/.gitconfig に置く。未設定ならその場で聞く。全部そろえば $true
function Confirm-GitIdentity {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  [WARN] git is not installed; cannot set user.name / user.email." -ForegroundColor Yellow
        return $false
    }
    $ok = $true
    foreach ($key in @("user.name", "user.email")) {
        $current = git config --global --get $key 2>$null
        if (-not [string]::IsNullOrWhiteSpace($current)) {
            Write-Host "  git $key = $current" -ForegroundColor Gray
            continue
        }
        $value = Read-Host "  git $key is not set. Enter it (blank to skip)"
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "  [WARN] git $key left unset; commits and backups will fail until you set it." -ForegroundColor Yellow
            $ok = $false
        } else {
            git config --global $key $value
            Write-Host "  Set git $key in ~/.gitconfig" -ForegroundColor Gray
        }
    }
    return $ok
}
