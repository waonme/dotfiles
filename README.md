# dotfiles

Windows & Linux (WSL/Ubuntu) 開発環境のセットアップ用。

## 含まれるもの

### パッケージ
- `scoopfile.json` — [Scoop](https://scoop.sh/) パッケージ一覧（bat, eza, fd, ripgrep, fzf, delta, autohotkey, everything, sharex 等含む）

### レジストリ設定
- `keyboard/capslock-to-ctrl.reg` — CapsLock → Ctrl キーリマップ
- `explorer/settings.reg` — エクスプローラー（拡張子表示、隠しファイル表示、コンパクト表示、PCで開く）
- `mouse/no-acceleration.reg` — マウス加速無効化
- `taskbar/cleanup.reg` — タスクバー整理（検索アイコン化、Copilot/ウィジェット/タスクビュー/チャット非表示）
- `context-menu/classic.reg` — 右クリックメニューを旧式（フル表示）に戻す
- `windows/tweaks.reg` — ダークモード、スクロールバー常時表示、通知・おすすめ抑制、カーソル太さ
- `shell/Microsoft.PowerShell_profile.ps1` — PowerShell の入力体験最適化（PSReadLine/補完/ショートカット）

### Windows Terminal
- `windows-terminal/color-schemes.json` — カスタム配色 (Midnight Mint, Slate Mist, Warm Earth)
- `windows-terminal/defaults.json` — デフォルトプロファイル、キーバインド（ペイン操作含む）、グローバル設定

### アプリ設定
- `powertoys/settings.json` — PowerToys 機能の ON/OFF・テーマ設定
- `git/config` — Git エイリアス、delta ページャー、pull.rebase、rerere 等
- `shell/.zshrc` — zsh 設定（Oh My Zsh + Starship、エイリアス、fzf、zoxide、補完、履歴）
- `wsl/.wslconfig` — WSL2 リソース制限（メモリ、swap、プロセッサ数）

### セットアップ
- `setup.ps1` — Windows 一括セットアップスクリプト
- `setup.sh` — Linux/WSL (Ubuntu/Debian) 一括セットアップスクリプト

## クイックスタート (Windows)

```powershell
git clone https://github.com/waonme/dotfiles ~/dotfiles

# 初回セットアップ（Windows 標準の PowerShell で実行）
powershell -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1

# 2回目以降（pwsh が Scoop でインストール済み）
pwsh -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1
```

`setup.ps1` が以下を自動で行う：
1. Scoop インストール & パッケージインポート
2. 全レジストリ設定のインポート
3. PowerShell プロファイルの反映
4. Git の include.path 設定 + `autocrlf = true`
5. `.wslconfig` のコピー

## クイックスタート (Linux/WSL)

```bash
git clone https://github.com/waonme/dotfiles ~/dotfiles
bash ~/dotfiles/setup.sh
```

`setup.sh` が以下を自動で行う：
1. apt でツールインストール (zsh, bat, fd-find, ripgrep, fzf, zoxide, trash-cli, eza, delta)
2. Oh My Zsh + カスタムプラグイン (zsh-autosuggestions, zsh-syntax-highlighting) インストール
3. Starship プロンプトインストール
4. Debian 互換シンボリックリンク作成 (`batcat→bat`, `fdfind→fd`)
5. `.zshrc` のシンボリックリンク作成
6. Git の include.path 設定 + `autocrlf = input`
7. デフォルトシェルを zsh に変更

## 手動で必要な作業

### Windows Terminal 設定のマージ

`color-schemes.json` と `defaults.json` の内容を Windows Terminal の `settings.json` にマージする。

### zsh 設定のリンク

```bash
ln -sf ~/dotfiles/shell/.zshrc ~/.zshrc
```

### PowerShell 設定の反映

`setup.ps1` 実行時に `shell/Microsoft.PowerShell_profile.ps1` を自動反映します。手動の場合は以下。

```powershell
Copy-Item ~/dotfiles/shell/Microsoft.PowerShell_profile.ps1 "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force
Copy-Item ~/dotfiles/shell/Microsoft.PowerShell_profile.ps1 "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force
```

### PowerToys 設定のコピー

```powershell
Copy-Item ~/dotfiles/powertoys/settings.json "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
```

### 再起動が必要な項目

- CapsLock → Ctrl リマップ → **PC再起動**
- 旧式右クリックメニュー → **エクスプローラー再起動 or PC再起動**

```powershell
# エクスプローラー再起動
taskkill /f /im explorer.exe; Start-Process explorer.exe
```

## パッケージ更新時

```bash
scoop export > ~/dotfiles/scoopfile.json
cd ~/dotfiles && git add -A && git commit -m "update scoopfile" && git push
```

## 旧式右クリックメニューを元に戻す

```powershell
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f
taskkill /f /im explorer.exe; Start-Process explorer.exe
```
