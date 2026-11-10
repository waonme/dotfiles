# dotfiles

Windows / Linux (Fedora, Ubuntu/Debian, WSL) / macOS 開発環境のセットアップ用。

## 含まれるもの

### パッケージ
- `scoopfile.json` — [Scoop](https://scoop.sh/) パッケージ一覧（bat, eza, fd, ripgrep, fzf, delta, jq, yq, sd, ast-grep, difftastic, hyperfine 等含む）
- `macos/Brewfile` — macOS の Homebrew 一覧

### AI エージェント用の指示書
- `ai/AGENTS.md` — Claude Code / Codex CLI に現代的な CLI ツール（rg, fd, jq, ast-grep, sd, yq, difft, bat, eza, hyperfine）を優先して使わせる指示書。源はこの 1 ファイルで、セットアップスクリプトが次の 2 か所に配る
  - `~/.claude/CLAUDE.md`（Claude Code）
  - `~/.codex/AGENTS.md`（Codex CLI）
  - Linux はシンボリックリンク、Windows はコピー。既に自分で書いた中身があるファイルは触らず警告だけ出す（統合してから消して再実行）
- `docs/cli-tools.md` — 同じツール群の人間向け一覧とインストール方法

### レジストリ設定
- `keyboard/capslock-to-ctrl.reg` — CapsLock → Ctrl キーリマップ
- `explorer/settings.reg` — エクスプローラー（拡張子表示、隠しファイル表示、コンパクト表示、PCで開く）
- `mouse/no-acceleration.reg` — マウス加速無効化
- `taskbar/cleanup.reg` — タスクバー整理（検索アイコン化、Copilot/ウィジェット/タスクビュー/チャット非表示）
- `context-menu/classic.reg` — 右クリックメニューを旧式（フル表示）に戻す
- `windows/tweaks.reg` — ダークモード、スクロールバー常時表示、通知・おすすめ抑制、カーソル太さ
- `shell/Microsoft.PowerShell_profile.ps1` — PowerShell の入力体験最適化（PSReadLine/補完/ショートカット）

### キー操作
- `keyboard/mac-keys.ahk` — Mac 風のキー操作（[AutoHotkey v2](https://www.autohotkey.com/)）。Alt を ⌘ として扱い、⌘C/V/Z/S/T/W…→Ctrl、⌘Q で閉じる、⌘←→ で行頭・行末、⌘⇧4 で範囲スクショ、エクスプローラーでは ⌘↑ で親フォルダ・⌘⌫ でごみ箱。Alt+Tab・Alt+F4・Alt+Space（PowerToys Run）・IME 切替はそのまま

### Windows Terminal
- `windows-terminal/color-schemes.json` — カスタム配色 (Midnight Mint, Slate Mist, Warm Earth)
- `windows-terminal/defaults.json` — デフォルトプロファイル、キーバインド（ペイン操作含む）、グローバル設定

### アプリ設定
- `powertoys/settings.json` — PowerToys 機能の ON/OFF・テーマ設定
- `git/config` — Git エイリアス、delta ページャー、pull.rebase、rerere 等（user.name / email は書かない。`~/.gitconfig` へ）
- `git/ignore` — 全 PC 共通の無視ファイル（.DS_Store, Thumbs.db 等。`core.excludesFile`）
- `shell/.zshrc` — zsh 設定（Oh My Zsh + Starship、エイリアス、fzf、zoxide、補完、履歴）
- `wsl/.wslconfig` — WSL2 設定の型。memory / swap / processors は PC ごとなので、実際の値は非公開の dotfiles-hosts に置く（[マシンごとの設定](#マシンごとの設定)）

### セットアップ
- `setup.ps1` — Windows 一括セットアップスクリプト（`setup.cmd` はダブルクリック用の入口）
- `setup.sh` — Linux (Fedora / Ubuntu / Debian、WSL 含む) 一括セットアップスクリプト
- `setup-macos.sh` — macOS 一括セットアップスクリプト
- `backup-hosts.ps1` — この PC の設定値を非公開の dotfiles-hosts に吸い上げてコミット・push する（`backup-hosts.cmd` はダブルクリック用の入口）（[マシンごとの設定](#マシンごとの設定)）
- `lib/hosts.ps1` — PC ごとに管理するファイルの一覧と、配る・吸い上げる処理の共通部分

## クイックスタート (Windows)

コマンドを打つのは 2 の clone だけ。あとはエクスプローラーでダブルクリックする。管理者として実行する必要はない。

1. **git を入れる**（まだ無ければ）。PowerShell で `winget install --id Git.Git -e`、または [Git for Windows](https://git-scm.com/download/win) のインストーラ。GitHub へのブラウザ サインイン（Git Credential Manager）も一緒に入る
2. **PowerShell に貼る**（`~` は使わない。PowerShell は git の引数の `~` を展開しない）

   ```powershell
   git clone https://github.com/waonme/dotfiles $HOME\dotfiles
   git clone https://github.com/waonme/dotfiles-hosts $HOME\dotfiles-hosts   # 非公開。PC ごとの値。ブラウザで GitHub にサインインする
   ```

3. **`dotfiles\setup.cmd` をダブルクリック**。最初に git の名前とメールアドレスを聞かれる（未設定のときだけ。`~/.gitconfig` に書き、リポジトリには入れない）。最後の `Next steps` に、この PC で次にやることが出る
4. **初回バックアップ**: `%USERPROFILE%\.wslconfig` の memory / swap / processors をこの PC に合わせて直し、**`dotfiles\backup-hosts.cmd` をダブルクリック**。差分を見て `y` を押すと `dotfiles-hosts/<COMPUTERNAME>/` に保存され、毎日 12:00 の自動バックアップも用意される

- 初回だけは必ず手で（4）。自動バックアップは、この PC のファイルがまだ dotfiles-hosts に無いときは吸い上げない（直す前の型を push しないため）
- dotfiles-hosts を 3 の後に clone しても、4 が成功すればタスクは登録される。順番を間違えても壊れない
- 窓がすぐ閉じる・何も起きないときは、PowerShell で `pwsh -ExecutionPolicy Bypass -File $HOME\dotfiles\setup.ps1 -KeepOpen`（pwsh が無ければ `powershell`）
- CapsLock → Ctrl など管理者権限の要る設定も入れるときだけ、`setup.cmd` を右クリック →「管理者として実行」

`setup.ps1` が以下を自動で行う：
0. git の user.name / user.email が未設定ならその場で聞いて `~/.gitconfig` に書く（リポジトリには入れない）
1. Scoop インストール & パッケージインポート
2. 全レジストリ設定のインポート
3. PowerShell プロファイルの反映（自分で書いたプロファイルが既にあれば上書きせず警告だけ）
4. AI 指示書 `ai/AGENTS.md` を `~/.claude/CLAUDE.md` と `~/.codex/AGENTS.md` にコピー
5. Git の include.path 設定 + `autocrlf = true`（git が無ければ飛ばす）
6. winget アプリインストール（winget が無ければ飛ばす）(Dropbox, RustDesk, Eagle, Notion, Claude, Claude Code, Codex CLI, AutoHotkey v2)
7. `keyboard/mac-keys.ahk` をスタートアップに登録して起動
8. PC ごとの設定値（`.wslconfig`）を `dotfiles-hosts/<COMPUTERNAME>/` から配る（無ければ型を配って警告。手で直したものは上書きしない）
9. `backup-hosts.ps1 -Auto` を毎日 12:00 に走らせるタスク `\dotfiles\hosts-backup` を登録（dotfiles-hosts があるとき。無ければ初回の手動バックアップで登録される）
10. 最後に、この PC で次にやること（clone、初回バックアップ）と、前回の自動バックアップの失敗を表示する

## クイックスタート (Linux: Fedora / Ubuntu / Debian / WSL)

```bash
git clone https://github.com/waonme/dotfiles ~/dotfiles
bash ~/dotfiles/setup.sh
```

`/etc/os-release` の `ID` / `ID_LIKE` で Fedora 系か Debian 系かを判定し、何度実行しても同じ結果になる。

`setup.sh` が以下を自動で行う：
1. パッケージインストール
   - Fedora: `dnf install --skip-unavailable` で zsh, fzf, zoxide, trash-cli, ripgrep, fd-find, jq, yq, bat, git-delta, difftastic, eza, hyperfine, rust, cargo。リポジトリに無い `sd` と `ast-grep` は `cargo install --locked`
   - Ubuntu/Debian: apt で zsh, fzf, zoxide, trash-cli, ripgrep, fd-find, jq, bat, sd, hyperfine。eza は gierens PPA、delta は .deb。apt の `yq` は Python 版なので使わず、`yq` (Go 版) / `ast-grep` / `difft` は GitHub release のバイナリを `~/.local/bin` に置く（apt の rustc は古くて `cargo install` が通らない）
2. Oh My Zsh + カスタムプラグイン (zsh-autosuggestions, zsh-syntax-highlighting) インストール
3. Starship プロンプトインストール
4. Debian 互換シンボリックリンク作成 (`batcat→bat`, `fdfind→fd`)
5. `.zshrc` のシンボリックリンク作成
6. `~/.cargo/bin` があれば `~/.bashrc` の PATH **末尾**に 1 回だけ追記（`.zshrc` 側は dotfiles に入っている。末尾なのは ast-grep が置く `sg` で shadow-utils の `/usr/bin/sg` を隠さないため。`ast-grep` の名前で呼ぶ）
7. AI 指示書 `ai/AGENTS.md` を `~/.claude/CLAUDE.md` と `~/.codex/AGENTS.md` にシンボリックリンク
8. Git の include.path 設定 + `autocrlf = input`
9. デフォルトシェルを zsh に変更

実行後の確認：

```bash
for t in rg fd jq ast-grep sd yq difft bat eza hyperfine; do printf '%-10s ' "$t"; command -v "$t" || echo MISSING; done
ls -l ~/.claude/CLAUDE.md ~/.codex/AGENTS.md
```

## クイックスタート (macOS)

```bash
git clone https://github.com/waonme/dotfiles ~/dotfiles
bash ~/dotfiles/setup-macos.sh
```

`setup-macos.sh` が以下を自動で行う（sudo・chsh なし。何度実行してもよい）：
1. `macos/Brewfile` のパッケージとアプリを入れる（`brew bundle`）
2. Oh My Zsh + カスタムプラグイン (zsh-autosuggestions, zsh-syntax-highlighting)
3. `.zshrc` のシンボリックリンク作成（既存の `.zshrc` は `.zshrc.bak-<日時>` に退避）
4. `~/.zshrc.local` の雛形を作る（無いときだけ）
5. Git の include.path 設定 + `autocrlf = input`

## 秘密の値のコミットを止める（gitleaks）

`git/hooks/pre-commit-gitleaks` は、ステージした変更を gitleaks で調べ、API キー・トークン・秘密鍵などが入っていればコミットを止める pre-commit フック（値は表示しない）。守りたいリポジトリごとに入れる：

```bash
ln -sf ~/dotfiles/git/hooks/pre-commit-gitleaks <リポジトリ>/.git/hooks/pre-commit
```

誤検知で止まったときは、該当行に `gitleaks:allow` のコメントを付けるか、`git commit --no-verify`。履歴全体を調べるときは `gitleaks git <リポジトリ> --redact --log-opts=--all`。

## マシンごとの設定

値の種類で置き場所を分ける。

| 種類 | 例 | 置き場所 |
|---|---|---|
| 全 PC 共通 | git のエイリアス、zsh、mac-keys | このリポジトリ |
| PC ごと・秘密ではない | `.wslconfig` の memory / processors | 非公開リポジトリ dotfiles-hosts の `<ホスト名>/` |
| 秘密 | API キー、社用の email | dotfiles の外（`~/.zshrc.local`、`~/.gitconfig`、1Password） |

### dotfiles-hosts（PC ごとの値）

- dotfiles と同じ階層に clone する（`~/dotfiles-hosts`）。別の場所なら環境変数 `DOTFILES_HOSTS`
- `setup.ps1` は `<COMPUTERNAME>/` だけを読む。**別の PC のファイルは決して使わない**ので、値が混ざらない
- 扱うファイルは `lib/hosts.ps1` の `Get-HostManifest` に載っているものだけ。増やすときはそこに足す
- この PC 用のファイルが無いときは、型（例 `wsl/.wslconfig`）を配って `backup-hosts.cmd` を流すよう出す。既に配り先があれば触らない
- 前回配った（または吸い上げた）中身の控えを `%LOCALAPPDATA%\dotfiles\deployed\` に取る。配り先が控えと同じときだけ上書きし、手で直していたら上書きせずに警告する

### バックアップ（`backup-hosts.ps1`）

PC で直した値を dotfiles-hosts に吸い上げ、コミットして push する。ふだんは **`backup-hosts.cmd` をダブルクリック**（差分を見せ、`y` で確認してからコミット・push）。コマンドで流すなら:

```powershell
pwsh -File $HOME\dotfiles\backup-hosts.ps1        # 差分を見せて、確認してからコミット・push
pwsh -File $HOME\dotfiles\backup-hosts.ps1 -Yes   # 確認なし（-NoPush でコミットまで）
```

- 書くのもコミットするのも `<COMPUTERNAME>/` だけ。dotfiles-hosts の中で自分のフォルダ以外に未コミットの変更があれば止める
- この PC の値・リポジトリの値・控え（前回配った／吸い上げた中身）の三つを比べる
  - この PC でだけ変わった → 吸い上げる
  - リポジトリでだけ変わった（別の PC から直した等）→ 吸い上げない。`setup.ps1` で配る
  - 両方で変わった、または控えが無い（その PC で初めて流すとき）→ 手動なら差分を見せて確認、`-Auto` なら触らずに失敗として知らせる
  - リポジトリにまだこの PC のファイルが無い → 手動なら吸い上げる。`-Auto` は吸い上げない（初回は必ず手で）
- push できなかったコミットは、次に走ったときに push する。オフラインで取り込めないときは何もせず失敗として知らせる
- コミットの前に gitleaks で調べ、秘密の値らしきものがあれば何もコミットせずに止める（gitleaks が無ければコミットしない）
- 自動：`setup.ps1`（または初回の手動バックアップ）がタスク `\dotfiles\hosts-backup` を登録し、毎日 12:00（PC が切れていたら次の起動後）に `-Auto` で走る。ログオン中だけ走り、窓は出さない。資格情報の入力は待たず、認証切れはすぐ失敗にする
- git の user.name / user.email が未設定なら、手動では聞く。`-Auto` は何も触らずに失敗にする
- 自動で失敗したら `%LOCALAPPDATA%\dotfiles\backup-failed.txt` を置き、次に `setup.ps1` を流したときに知らせる。ログは同じ場所の `backup.log`（実行ごとに `start` と `end exit=N` の行。`end` が無ければ途中で強制終了された）
- 自動で push されるのは、この PC 自身が使う値だけ。誤った値が入っても影響はその PC に限られ、git の履歴から戻せる

### `~/.zshrc.local`

`shell/.zshrc` は `~/.config/theodore/env`（あれば。`~/theodore/install.sh` が書く `THEO_HOBBY_DIR`）を読んだあと、最後に `~/.zshrc.local` を読む。API キー・マシン固有の PATH・個人的なエイリアスはこちらに書き、dotfiles には入れない（このリポジトリは公開）。秘密の値は `op read 'op://...'` で 1Password から読むのがよい。

`grep→rg`・`find→fd`・`rm→trash`・`cat→bat` と `NO_CLOBBER` は、対話的なシェルで、かつ Claude Code の中（`CLAUDECODE` が立つ）でないときだけ有効にしている。エージェントやスクリプトが標準コマンドの書き方で動けるように。

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

### Mac 風キー操作の調整

- 効かせたくないアプリ（Alt を使うゲーム、リモート接続など）は `keyboard/mac-keys.ahk` 冒頭の `GroupAdd "MacOff", ...` に実行ファイル名を足す
- 編集後はタスクトレイの H アイコン →「Reload Script」、または `setup.ps1` を再実行
- 管理者権限のウィンドウ（タスクマネージャー等）では効かない。効かせたいときはスクリプトを管理者として実行する
- 止めるときはトレイアイコン →「Exit」。自動起動をやめるなら `shell:startup` の `mac-keys.lnk` を消す

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
