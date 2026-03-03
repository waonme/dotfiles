# dotfiles

Windows 開発環境のセットアップ用。

## 含まれるもの

- `scoopfile.json` — [Scoop](https://scoop.sh/) パッケージ一覧
- `setup.ps1` — 新環境での一括セットアップスクリプト
- `windows-terminal/color-schemes.json` — Windows Terminal カスタム配色 (Midnight Mint, Slate Mist, Warm Earth)

## セットアップ

```powershell
git clone https://github.com/waonme/dotfiles ~/dotfiles
powershell -ExecutionPolicy Bypass -File ~/dotfiles/setup.ps1
```

## Windows Terminal 配色の適用

`windows-terminal/color-schemes.json` の内容を Windows Terminal の `settings.json` > `"schemes"` 配列にマージする。

## パッケージ更新時

```bash
scoop export > ~/dotfiles/scoopfile.json
cd ~/dotfiles && git add -A && git commit -m "update scoopfile" && git push
```
