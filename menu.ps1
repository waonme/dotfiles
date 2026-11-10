# menu.ps1 — setup.cmd から開く「状態一覧＋番号メニュー」（Windows）
# 文言が日本語なので、このファイルだけ BOM 付き UTF-8 で保存する（Windows PowerShell 5.1 が CP932 と誤読しないように）。BOM を消さないこと
# Usage:
#   setup.cmd をダブルクリック
#   pwsh -File $HOME\dotfiles\menu.ps1 -Status   # 状態だけ出して終わる

param([switch]$Status)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot "lib\hosts.ps1")

$PsExe = (Get-Process -Id $PID).Path
$OnWindows = ($env:OS -eq "Windows_NT")
$CapsLockReg = Join-Path $PSScriptRoot "keyboard\capslock-to-ctrl.reg"

function Test-IsAdmin {
    if (-not $OnWindows) { return $false }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# setup で入れたばかりのツール（scoop の pwsh / gitleaks など）が子プロセスから見えるよう、PATH を読み直す
function Update-SessionPath {
    if (-not $OnWindows) { return }
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

# git を呼んで出力を返す。失敗しても止めない（終了コードは $LASTEXITCODE）
function Invoke-GitQuiet {
    param([string]$Dir, [string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = @(& git -C $Dir @GitArgs 2>$null | ForEach-Object { "$_" })
    } finally {
        $ErrorActionPreference = $prev
    }
    return $out
}

function Get-RepoSummary {
    param([string]$Dir)
    if (-not (Test-Path (Join-Path $Dir ".git"))) { return [pscustomobject]@{ Exists = $false; Text = "ありません（$Dir）" } }
    $branch = @(Invoke-GitQuiet $Dir @("rev-parse", "--abbrev-ref", "HEAD")) | Select-Object -First 1
    $dirty = @(Invoke-GitQuiet $Dir @("status", "--porcelain")).Count
    $aheadOut = @(Invoke-GitQuiet $Dir @("rev-list", "--count", "@{u}..HEAD"))
    $ahead = if ($aheadOut.Count -gt 0) { [int]$aheadOut[0] } else { 0 }
    $parts = @("ブランチ $branch")
    $parts += if ($dirty -gt 0) { "未コミット $dirty 件" } else { "未コミットなし" }
    $parts += if ($ahead -gt 0) { "未 push $ahead 件" } else { "未 push なし" }
    return [pscustomobject]@{ Exists = $true; Branch = $branch; Dirty = $dirty; Ahead = $ahead; Text = ($parts -join " / ") }
}

function Get-HostFileState {
    param($Entry, [bool]$HostsCloned)
    $hostFile = Get-HostFilePath $Entry.Name
    if (-not $HostsCloned) { return "dotfiles-hosts が無いので未管理" }
    if (-not (Test-Path $hostFile)) {
        if (Test-Path $Entry.Dest) { return "Missing:まだバックアップしていない" }
        return "Missing:まだバックアップしていない（この PC にもまだ無い）"
    }
    if (-not (Test-Path $Entry.Dest)) { return "Differs:この PC に無い（setup で配られる）" }
    if ((Read-Normalized $Entry.Dest) -eq (Read-Normalized $hostFile)) { return "保存済み（リポジトリと一致）" }
    return "Differs:この PC とリポジトリで違う"
}

function Get-TaskText {
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return "確認できません（Windows 以外）" }
    $task = Get-ScheduledTask -TaskPath $BackupTaskPath -TaskName $BackupTaskName -ErrorAction SilentlyContinue
    if (-not $task) { return "未登録" }
    $info = Get-ScheduledTaskInfo -InputObject $task
    $result = switch ([int64]$info.LastTaskResult) {
        0          { "成功" }
        1          { "失敗（exit 1）" }
        267011     { "まだ一度も走っていない" }
        267009     { "実行中" }
        267014     { "時間切れで強制終了" }
        2147946720 { "拒否された（ログオンしていなかった等）" }
        default    { "結果コード 0x{0:X}" -f [int64]$info.LastTaskResult }
    }
    $last = if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $info.LastRunTime.ToString("yyyy-MM-dd HH:mm") } else { "-" }
    return "登録済み（毎日 12:00）/ 前回 $last $result"
}

# backup.log の最後の実行が end まで行ったか
function Get-LastBackupText {
    if (-not (Test-Path $BackupLog)) { return "まだ記録なし" }
    $lines = @(Get-Content $BackupLog -Tail 200)
    $startIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i] -match '\] start$') { $startIdx = $i; break } }
    if ($startIdx -lt 0) { return "まだ記録なし" }
    $when = $lines[$startIdx].Substring(0, 16)
    $mode = if ($lines[$startIdx] -match '\[auto\]') { "自動" } else { "手動" }
    for ($j = $startIdx + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match 'end exit=(\d+)$') {
            $r = if ($Matches[1] -eq "0") { "成功" } else { "失敗（exit $($Matches[1])）" }
            return "$when $mode $r"
        }
    }
    return "$when $mode 終わっていない（途中で強制終了された可能性）"
}

# 状態を表示し、勧める番号を返す
function Show-Status {
    $dot = Get-RepoSummary $DotfilesRoot
    $hosts = Get-RepoSummary $HostsRoot
    $email = @(Invoke-GitQuiet $DotfilesRoot @("config", "user.email")) | Select-Object -First 1
    $name = @(Invoke-GitQuiet $DotfilesRoot @("config", "user.name")) | Select-Object -First 1

    Write-Host ""
    Write-Host "=== dotfiles（この PC: $HostName）===" -ForegroundColor Cyan
    Write-Host ("  dotfiles        : " + $dot.Text)
    Write-Host ("  dotfiles-hosts  : " + $hosts.Text) -ForegroundColor $(if ($hosts.Exists) { "Gray" } else { "Yellow" })
    $ident = if ($name -and $email) { "$name <$email>" } else { "未設定" }
    Write-Host ("  git の名前      : " + $ident) -ForegroundColor $(if ($name -and $email) { "Gray" } else { "Yellow" })
    $missing = $false; $differs = $false
    foreach ($entry in Get-HostManifest) {
        $state = Get-HostFileState $entry $hosts.Exists
        if ($state.StartsWith("Missing:")) { $missing = $true; $state = $state.Substring(8); $color = "Yellow" }
        elseif ($state.StartsWith("Differs:")) { $differs = $true; $state = $state.Substring(8); $color = "Yellow" }
        else { $color = "Gray" }
        Write-Host ("  {0,-16}: {1}" -f $entry.Name, $state) -ForegroundColor $color
    }
    Write-Host ("  毎日のバックアップ: " + (Get-TaskText))
    Write-Host ("  前回のバックアップ: " + (Get-LastBackupText))
    $failed = Test-Path $BackupFailedMarker
    if ($failed) {
        Write-Host ""
        Write-Host "  [!] 自動バックアップが失敗しています:" -ForegroundColor Red
        Write-Host ("      " + (Get-Content -Raw $BackupFailedMarker).Trim()) -ForegroundColor Red
    }

    if (-not $hosts.Exists -or $missing) { return @{ Num = "1"; Why = "初回セットアップがまだです" } }
    if ($failed) { return @{ Num = "3"; Why = "失敗したバックアップをやり直します" } }
    if ($differs) { return @{ Num = "2"; Why = "この PC とリポジトリの値が違います" } }
    return @{ Num = "0"; Why = "やることはありません" }
}

# これから行うことを見せて確かめる
function Confirm-Plan {
    param([string[]]$Lines)
    Write-Host ""
    Write-Host "これから行うこと:" -ForegroundColor Cyan
    foreach ($l in $Lines) { Write-Host "  - $l" }
    $a = Read-Host "Enter で実行 / n で戻る"
    return ($a -notmatch '^[nN]')
}

# 子プロセスで流す。画面と入力（y/N など）は子がそのまま使う。終了コードを返す
function Invoke-Child {
    param([string]$Script, [string[]]$ScriptArgs = @())
    Update-SessionPath
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$(Join-Path $PSScriptRoot $Script)`"") + $ScriptArgs
    $p = Start-Process -FilePath $PsExe -ArgumentList $argList -NoNewWindow -Wait -PassThru
    Update-SessionPath
    return $p.ExitCode
}

# fast-forward できるときだけ pull する。できないときは理由を出して飛ばす
function Update-Repo {
    param([string]$Dir, [string]$Label)
    $r = Get-RepoSummary $Dir
    if (-not $r.Exists) { Write-Host "  $Label : ありません。飛ばします" -ForegroundColor Yellow; return }
    if ($r.Branch -notin @("master", "main")) { Write-Host "  $Label : ブランチ $($r.Branch) にいるので pull しません" -ForegroundColor Yellow; return }
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $out = @(& git -C $Dir pull --ff-only --quiet 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -eq 0) { Write-Host "  $Label : 最新にしました" -ForegroundColor Gray }
    else { Write-Host "  $Label : pull できませんでした（$($out -join ' / ')）" -ForegroundColor Yellow }
}

function Invoke-FirstTimeSetup {
    $hostsCloned = Test-Path (Join-Path $HostsRoot ".git")
    $plan = @("git の名前とメールアドレスを確かめる（未設定なら聞く）")
    if (-not $hostsCloned) { $plan += "非公開の dotfiles-hosts を $HostsRoot に clone する（GitHub にブラウザでサインイン）" }
    $plan += "setup.ps1 を流す（Scoop / レジストリ / プロファイル / アプリ / PC ごとのファイル）"
    $plan += "まだバックアップしていないファイルをメモ帳で開く（この PC に合わせて直し、閉じると次へ）"
    $plan += "バックアップする（差分を見せ、y で dotfiles-hosts にコミット・push。毎日の自動バックアップも用意される）"
    if (-not (Confirm-Plan $plan)) { return }

    [void](Confirm-GitIdentity)
    if (-not $hostsCloned) {
        Write-Host ""
        Write-Host "dotfiles-hosts を clone します..." -ForegroundColor Yellow
        $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & git clone https://github.com/waonme/dotfiles-hosts $HostsRoot
        $ErrorActionPreference = $prev
        if ($LASTEXITCODE -ne 0) { Write-Host "  clone できませんでした。setup は続けます（あとでメニューの 1 をもう一度）" -ForegroundColor Yellow }
    }
    [void](Invoke-Child "setup.ps1")

    $hostsCloned = Test-Path (Join-Path $HostsRoot ".git")
    if (-not $hostsCloned) { return }
    $edited = $false
    foreach ($entry in Get-HostManifest) {
        if ((Test-Path (Get-HostFilePath $entry.Name)) -or -not (Test-Path $entry.Dest)) { continue }
        Write-Host ""
        Write-Host "$($entry.Dest) をメモ帳で開きます。この PC に合わせて直し、保存して閉じてください。" -ForegroundColor Yellow
        if ($OnWindows) { Start-Process notepad.exe -ArgumentList "`"$($entry.Dest)`"" -Wait } else { Read-Host "直したら Enter" | Out-Null }
        $edited = $true
    }
    if ($edited -or (Test-Path $BackupFailedMarker)) { [void](Invoke-Child "backup-hosts.ps1") }
}

function Invoke-UpdateAndApply {
    if (-not (Confirm-Plan @("dotfiles と dotfiles-hosts を最新にする（master/main にいて fast-forward できるときだけ）", "setup.ps1 を流し直す（手で直したファイルは上書きしない）"))) { return }
    Write-Host ""
    Update-Repo $DotfilesRoot "dotfiles"
    Update-Repo $HostsRoot "dotfiles-hosts"
    [void](Invoke-Child "setup.ps1")
}

function Invoke-CapsLockToCtrl {
    if (-not (Confirm-Plan @("CapsLock を Ctrl にする（keyboard\capslock-to-ctrl.reg を取り込む）", "この段だけ管理者に昇格する（UAC の確認が出る）", "効くのは Windows を再起動した後"))) { return }
    if (-not $OnWindows) { Write-Host "  Windows 以外では使えません" -ForegroundColor Yellow; return }
    try {
        $p = Start-Process reg.exe -ArgumentList @("import", "`"$CapsLockReg`"") -Verb RunAs -Wait -PassThru
        if ($p.ExitCode -eq 0) { Write-Host "  取り込みました。再起動すると効きます" -ForegroundColor Green }
        else { Write-Host "  取り込みに失敗しました（exit $($p.ExitCode)）" -ForegroundColor Yellow }
    } catch {
        Write-Host "  キャンセルされました" -ForegroundColor Yellow
    }
}

# --- ここから ---------------------------------------------------------------
if ($Status) {
    $rec = Show-Status
    Write-Host ""
    Write-Host ("次のおすすめ: {0}（{1}）" -f $rec.Num, $rec.Why) -ForegroundColor Green
    exit 0
}

if (Test-IsAdmin) {
    Write-Host "管理者として開かれています。Scoop・設定・タスクが管理者側に入ってしまうので、" -ForegroundColor Yellow
    Write-Host "ふつうに setup.cmd をダブルクリックして開き直すのを勧めます（管理者の要る設定はメニューの 5 から）。" -ForegroundColor Yellow
    if ((Read-Host "それでも続けますか? [y/N]") -notmatch '^[yY]') { exit 0 }
}

while ($true) {
    $rec = Show-Status
    Write-Host ""
    Write-Host "  1) 初回セットアップ（clone → setup → 値を直す → バックアップ）"
    Write-Host "  2) 最新にして設定を適用し直す"
    Write-Host "  3) 今すぐバックアップ"
    Write-Host "  4) ログのフォルダを開く"
    Write-Host "  5) CapsLock → Ctrl（管理者）"
    Write-Host "  0) 終わる"
    Write-Host ""
    Write-Host ("次のおすすめ: {0}（{1}）" -f $rec.Num, $rec.Why) -ForegroundColor Green
    $choice = Read-Host "番号を入れて Enter（そのまま Enter でおすすめ）"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $rec.Num }
    switch ($choice.Trim()) {
        "1" { Invoke-FirstTimeSetup }
        "2" { Invoke-UpdateAndApply }
        "3" { [void](Invoke-Child "backup-hosts.ps1") }
        "4" {
            if (-not (Test-Path $DotfilesStateDir)) { New-Item -ItemType Directory -Force -Path $DotfilesStateDir | Out-Null }
            if ($OnWindows) { Start-Process explorer.exe -ArgumentList "`"$DotfilesStateDir`"" } else { Write-Host "  $DotfilesStateDir" }
        }
        "5" { Invoke-CapsLockToCtrl }
        "0" { exit 0 }
        default { Write-Host "  0〜5 の番号を入れてください" -ForegroundColor Yellow }
    }
    Write-Host ""
    Read-Host "Enter でメニューに戻る" | Out-Null
}
