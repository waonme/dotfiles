# dotfiles

Windows 開発環境のセットアップ用。

## 含まれるもの

- `scoopfile.json` — [Scoop](https://scoop.sh/) パッケージ一覧
- `setup.ps1` — 新環境での一括セットアップスクリプト
- `windows-terminal/color-schemes.json` — Windows Terminal カスタム配色 (Midnight Mint, Slate Mist, Warm Earth)
- `windows-terminal/defaults.json` — Windows Terminal デフォルトプロファイル・キーバインド・グローバル設定
- `keyboard/capslock-to-ctrl.reg` — CapsLock → Ctrl キーリマップ
- `explorer/settings.reg` — エクスプローラー設定（拡張子表示、隠しファイル表示、コンパクト表示、PCで開く）
- `mouse/no-acceleration.reg` — マウス加速無効化
- `powertoys/settings.json` — PowerToys 機能の ON/OFF・テーマ設定

## セットアップ

```powershell
git clone https://github.com/waonme/dotfiles ~/dotfiles
powershell -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1
```

## レジストリ設定の適用

管理者権限で実行する。CapsLock リマップは再起動が必要。

```powershell
reg import ~/dotfiles/keyboard/capslock-to-ctrl.reg
reg import ~/dotfiles/explorer/settings.reg
reg import ~/dotfiles/mouse/no-acceleration.reg
```

## Windows Terminal 配色の適用

`windows-terminal/color-schemes.json` の内容を Windows Terminal の `settings.json` > `"schemes"` 配列にマージする。

## Windows Terminal デフォルト設定の適用

`windows-terminal/defaults.json` から以下を Windows Terminal の `settings.json` にマージする：

- `profiles.defaults` — フォント、透明度、カーソル形状、配色、padding
- `actions` / `keybindings` — Ctrl+C/V, Ctrl+Shift+F, Alt+Shift+D
- `copyFormatting`, `copyOnSelect` — グローバル設定

## PowerToys 設定の適用

`powertoys/settings.json` を `%LOCALAPPDATA%\Microsoft\PowerToys\settings.json` にコピーする。

```powershell
Copy-Item ~/dotfiles/powertoys/settings.json "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
```

## パッケージ更新時

```bash
scoop export > ~/dotfiles/scoopfile.json
cd ~/dotfiles && git add -A && git commit -m "update scoopfile" && git push
```
