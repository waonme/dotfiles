# Microsoft.PowerShell_profile.ps1 — dotfiles 管理下の PowerShell プロファイル
# setup.ps1 が Documents\PowerShell と Documents\WindowsPowerShell の両方にコピーする
# PowerShell 7 (pwsh) 向け。Windows PowerShell 5.1 でも壊れないように、無い機能は飛ばす

# --- エンコーディング: UTF-8 で統一 ---
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# --- PSReadLine: 入力体験 ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 100000
    Set-PSReadLineOption -BellStyle None

    # 履歴からの予測入力（PSReadLine 2.1+）。Azure CLI などのプラグイン予測もあれば使う
    try {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
    } catch {
        try { Set-PSReadLineOption -PredictionSource History } catch { }
    }

    # ショートカット
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete                     # Tab で候補一覧
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward        # 入力中の文字で履歴を絞る
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit              # 空行で Ctrl+D → 終了
    Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+a -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Key Ctrl+e -Function EndOfLine
    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
}

# --- 補完 ---
# winget
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
# gh
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh completion -s powershell | Out-String | Invoke-Expression
}

# --- エイリアス（入っているときだけ） ---
# PowerShell はエイリアスが関数より優先されるので、組み込みの ls / cat (Get-ChildItem / Get-Content) を先に外す
if (Get-Command eza -ErrorAction SilentlyContinue) {
    if (Test-Path Alias:ls) { Remove-Item Alias:ls -Force }
    function ls  { eza --icons --group-directories-first @args }
    function ll  { eza --icons --group-directories-first -la @args }
    function la  { eza -a @args }
    function lt  { eza --icons --tree --level=2 @args }
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    if (Test-Path Alias:cat) { Remove-Item Alias:cat -Force }
    function cat { bat --paging=never @args }
}
Set-Alias -Name which -Value Get-Command -Option AllScope
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# --- fzf / zoxide / Starship（入っているときだけ） ---
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border'
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
    }
    if (Get-Module -ListAvailable -Name PSFzf) {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
