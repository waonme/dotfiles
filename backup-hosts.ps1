# backup-hosts.ps1 — この PC の設定値を dotfiles-hosts/<COMPUTERNAME>/ に吸い上げて、コミット・push する
# 対象は lib/hosts.ps1 の Get-HostManifest に載っているファイルだけ。書くのもコミットするのも自分のフォルダだけ
# ふだんは backup-hosts.cmd をダブルクリックする（下の 1 行目と同じ）
# Usage:
#   pwsh -File $HOME\dotfiles\backup-hosts.ps1          # 差分を見せて確認してからコミット・push
#   pwsh -File $HOME\dotfiles\backup-hosts.ps1 -Yes     # 確認なし
#   pwsh -File $HOME\dotfiles\backup-hosts.ps1 -Auto    # タスクスケジューラ用。確認なし、失敗は印を置いて setup.ps1 で知らせる
#                                                       # この PC の初回（repo にまだファイルが無い）は吸い上げない。初回は必ず手で
#   -NoPush を付けるとコミットまで

param(
    [switch]$Auto,
    [switch]$Yes,
    [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# git の出力（UTF-8）を CP932 として読んで化けないように
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot "lib\hosts.ps1")

function Write-Log {
    param([string]$Message, [string]$Color = "Gray", [switch]$LogOnly)
    if (-not (Test-Path $DotfilesStateDir)) { New-Item -ItemType Directory -Force -Path $DotfilesStateDir | Out-Null }
    $mode = if ($Auto) { "auto" } else { "manual" }
    Add-Content -Path $BackupLog -Value ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $mode, $Message)
    if (-not $LogOnly) { Write-Host $Message -ForegroundColor $Color }
}

# 終わるときは必ずここを通す。ログに end 行が無ければ、途中で強制終了された（タスクの時間切れなど）とわかる
function Stop-Backup {
    param([int]$Code)
    Write-Log "end exit=$Code" -LogOnly
    exit $Code
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

# 取り込みに失敗したら途中のまま残さない（残すと以後の自動実行が全部失敗する）
function Invoke-PullRebase {
    try {
        Invoke-Git @('pull', '--rebase', '--autostash', '--quiet') | Out-Null
    } catch {
        try { Invoke-Git @('rebase', '--abort') | Out-Null } catch { }
        throw
    }
}

Write-Log "start" -LogOnly
if ($Auto) {
    # 無人実行では資格情報の入力を待たない（待つと時間切れで何も残さず殺される）。認証切れはすぐ失敗にする
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GCM_INTERACTIVE = "never"
}

try {
    if ([string]::IsNullOrWhiteSpace($HostName)) { throw "COMPUTERNAME is empty; refusing to guess the host folder." }
    if (-not (Test-Path (Join-Path $HostsRoot ".git"))) {
        throw "$HostsRoot is not a git clone of dotfiles-hosts. Clone it there: git clone https://github.com/waonme/dotfiles-hosts `"$HostsRoot`""
    }

    # 自分のフォルダ以外に未コミットの変更があれば止める（ほかの PC の値を巻き込まない）
    $hostPrefix = "$HostName/"
    $dirty = @(Invoke-Git @('status', '--porcelain', '--untracked-files=all') | Where-Object { $_ -and -not $_.Substring(3).Trim('"').StartsWith($hostPrefix) })
    if ($dirty.Count -gt 0) { throw "Uncommitted changes outside $hostPrefix in ${HostsRoot}: $($dirty -join ', ')" }

    # コミットに要る名前とメールアドレス。手動ならその場で聞く。-Auto なら何も触らずに止める
    $hasIdentity = {
        foreach ($key in @('user.name', 'user.email')) {
            $v = @(try { Invoke-Git @('config', $key) } catch { })
            if ($v.Count -eq 0 -or [string]::IsNullOrWhiteSpace($v[0])) { return $false }
        }
        return $true
    }
    if (-not (& $hasIdentity)) {
        if (-not $Auto) { [void](Confirm-GitIdentity) }
        if (-not (& $hasIdentity)) { throw "git user.name / user.email are not set. Double-click backup-hosts.cmd (or run setup) to set them." }
    }

    $hasRemote = [bool](Invoke-Git @('remote'))
    if ($hasRemote) { Invoke-PullRebase }

    $hostDir = Join-Path $HostsRoot $HostName
    if (-not (Test-Path $hostDir)) { New-Item -ItemType Directory -Force -Path $hostDir | Out-Null }

    # 配り先（この PC）・リポジトリ・控え（前回配った／吸い上げた中身）の三つを比べて決める
    #   配り先 = 控え、リポジトリ != 控え → リポジトリ側が新しい。吸い上げない（setup.ps1 で配る）
    #   配り先 != 控え、リポジトリ = 控え → この PC で直された。吸い上げる
    #   両方とも控えと違う／控えが無い   → どちらを残すか人が決める。-Auto では触らず失敗として知らせる
    $captured = @()
    $problems = @()
    foreach ($entry in Get-HostManifest) {
        $name = $entry.Name
        $hostFile = Get-HostFilePath $name
        if (-not (Test-Path $entry.Dest)) {
            Write-Log "  skip ${name}: $($entry.Dest) does not exist"
            continue
        }
        $cur = Read-Normalized $entry.Dest
        if (-not (Test-Path $hostFile) -and $Auto) {
            # この PC の初回。型のまま（値を直す前）かもしれないので、無人では吸い上げない
            $problems += "${name}: first backup of this PC must be done by hand: fill in $($entry.Dest), then double-click backup-hosts.cmd"
            Write-Log "  [WARN] ${name}: no copy in the repo yet; the first backup must be done by hand." "Yellow"
            continue
        }
        if (Test-Path $hostFile) {
            $src = Read-Normalized $hostFile
            if ($cur -eq $src) {
                Save-DeployedState $hostFile $name
                continue
            }
            $stateFile = Join-Path $DeployedStateDir $name
            $state = if (Test-Path $stateFile) { Read-Normalized $stateFile } else { $null }
            if ($null -ne $state -and $cur -eq $state) {
                Write-Log "  ${name}: the repo has a newer version; run setup.ps1 to deploy it (not captured)." "Yellow"
                continue
            }
            $why = if ($null -eq $state) { "no record of what was last deployed here" } elseif ($src -ne $state) { "changed both on this machine and in the repo" } else { $null }
            if ($why) {
                if ($Auto) {
                    $problems += "${name}: $why; double-click backup-hosts.cmd (keep this machine's) or delete $($entry.Dest) and run setup (keep the repo's)"
                    Write-Log "  [WARN] ${name}: $why; left for a manual run." "Yellow"
                    continue
                }
                Write-Host "  [WARN] ${name}: $why. Capturing replaces the repo's version (see the diff below)." -ForegroundColor Yellow
            }
        }
        Copy-Item $entry.Dest $hostFile -Force
        $captured += $entry
    }

    Invoke-Git @('add', '--', $hostPrefix) | Out-Null
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & git -C $HostsRoot diff --cached --quiet '--' $hostPrefix
    $changed = ($LASTEXITCODE -ne 0)
    $ErrorActionPreference = $prev

    if (-not $changed) {
        Write-Log "No changes to capture for $HostName."
    } else {
        Write-Host ""
        Invoke-Git @('diff', '--cached', '--stat', '--', $hostPrefix) | Write-Host
        if (-not $Auto) { Invoke-Git @('diff', '--cached', '--', $hostPrefix) | Write-Host }

        if (-not ($Auto -or $Yes)) {
            $answer = Read-Host "Commit and push these changes? [y/N]"
            if ($answer -notmatch '^[yY]') {
                Undo-Capture
                Write-Host "Cancelled; nothing committed." -ForegroundColor Yellow
                Stop-Backup 0
            }
        }

        # 秘密の値が混じっていないか（値は表示しない）。gitleaks が無ければコミットしない
        if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
            Undo-Capture
            throw "gitleaks not found; refusing to commit (scoop install gitleaks)."
        }
        $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & gitleaks git --pre-commit --staged --redact --no-banner $HostsRoot 2>&1 | ForEach-Object { "$_" } | Write-Host
        $leakCode = $LASTEXITCODE
        $ErrorActionPreference = $prev
        if ($leakCode -ne 0) {
            Undo-Capture
            throw "gitleaks found something that looks like a secret; nothing committed."
        }

        # 実際にコミットされるファイル名（前回の失敗でステージに残っていた分も含む）
        $names = (@(Invoke-Git @('diff', '--cached', '--name-only', '--', $hostPrefix)) | ForEach-Object { $_.Substring($hostPrefix.Length) }) -join ", "
        $mode = if ($Auto) { "auto" } else { "manual" }
        try {
            Invoke-Git @('commit', '-q', '-m', "backup ${HostName}: $names ($mode)", '--', $hostPrefix) | Out-Null
        } catch {
            Undo-Capture
            throw
        }
        Write-Log "Committed backup for $HostName ($names)." "Green"
    }
    # 吸い上げた中身を控えにする（次の setup.ps1 が「手で直された」と誤って警告しないように）
    foreach ($entry in $captured) { Save-DeployedState (Get-HostFilePath $entry.Name) $entry.Name }

    # 前回 push できなかったコミットも含めて、未 push があれば push する
    if ($hasRemote -and -not $NoPush) {
        $ahead = try { [int](Invoke-Git @('rev-list', '--count', '@{u}..HEAD') | Select-Object -First 1) } catch { 1 }
        if ($ahead -gt 0) {
            try {
                Invoke-Git @('push', '-q') | Out-Null
            } catch {
                # ほかの PC が先に push していた → 取り込んでからもう一度だけ
                Invoke-PullRebase
                Invoke-Git @('push', '-q') | Out-Null
            }
            Write-Log "Pushed." "Green"
        }
    }

    if ($problems.Count -gt 0) { throw ($problems -join " | ") }
    if (Test-Path $BackupFailedMarker) { Remove-Item $BackupFailedMarker -Force }

    # 手で流して成功したら、毎日の自動バックアップも用意する（dotfiles-hosts を setup の後に clone した PC 向け）
    if (-not $Auto -and -not (Test-HostsBackupTask)) { Register-HostsBackupTask }
    Stop-Backup 0
} catch {
    Write-Log "[ERROR] $($_.Exception.Message)" "Red"
    if ($Auto) {
        Set-Content -Path $BackupFailedMarker -Value ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $_.Exception.Message)
    }
    Stop-Backup 1
}
