#!/usr/bin/env bash
# dotfiles setup script for Linux (Fedora / Ubuntu / Debian, WSL も可)
# Usage: bash ~/dotfiles/setup.sh
# 何度実行しても同じ結果になる（冪等）

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"

# GitHub release から入れるツールの版（Debian/Ubuntu の apt に無い・古いもの）
DELTA_VERSION="0.18.2"
YQ_VERSION="4.54.1"
AST_GREP_VERSION="0.45.3"
DIFFTASTIC_VERSION="0.71.0"

info()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
step()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
gray()  { printf '\033[0;37m  %s\033[0m\n' "$*"; }
warn()  { printf '\033[0;31m  [WARN] %s\033[0m\n' "$*"; }

# このスクリプト内でも、入れたばかりのツールを command -v で見つけられるように
# （cargo は末尾: ast-grep が置く ~/.cargo/bin/sg で shadow-utils の /usr/bin/sg を隠さない）
export PATH="$LOCAL_BIN:$PATH:$HOME/.cargo/bin"

# --- OS 判定 ---
# /etc/os-release の ID / ID_LIKE で Fedora 系と Debian 系に分ける。
# OS_RELEASE=<file> で別のファイルを読ませると、他 OS の分岐を手元で確認できる
detect_os_family() {
    local os_release="${OS_RELEASE:-/etc/os-release}"
    local id="" id_like=""
    if [ -r "$os_release" ]; then
        # shellcheck source=/dev/null
        id="$(. "$os_release" && printf '%s' "${ID:-}")"
        # shellcheck source=/dev/null
        id_like="$(. "$os_release" && printf '%s' "${ID_LIKE:-}")"
    fi
    case " $id $id_like " in
        *" fedora "*|*" rhel "*|*" centos "*) echo fedora ;;
        *" debian "*|*" ubuntu "*)           echo debian ;;
        *)                                   echo unknown ;;
    esac
}

OS_FAMILY="$(detect_os_family)"

case "$(uname -m)" in
    x86_64)        RUST_ARCH="x86_64";  GO_ARCH="amd64" ;;
    aarch64|arm64) RUST_ARCH="aarch64"; GO_ARCH="arm64" ;;
    *)             RUST_ARCH="";        GO_ARCH="" ;;
esac

info "=== dotfiles setup (Linux: $OS_FAMILY) ==="

if [ "$OS_FAMILY" = "unknown" ]; then
    warn "/etc/os-release から Fedora 系か Debian 系か判定できない。対応外の OS"
    exit 1
fi

# --- ヘルパー ---

# GitHub release のアーカイブ（.zip / .tar.gz / 単体バイナリ）から 1 つだけ取り出して ~/.local/bin に置く
# install_release_binary <name> <url> [archive 内のファイル名]
install_release_binary() {
    local name="$1" url="$2" inner="${3:-}"
    local tmp
    if [ -z "$RUST_ARCH" ]; then
        warn "$name: 対応していない CPU ($(uname -m))。手動で入れる"
        return 0
    fi
    tmp="$(mktemp -d)"
    gray "Downloading $name from $url"
    curl -fsSL -o "$tmp/pkg" "$url"
    case "$url" in
        *.tar.gz) tar -xzf "$tmp/pkg" -C "$tmp" ;;
        *.zip)    unzip -q "$tmp/pkg" "$inner" -d "$tmp" ;;
        *)        inner="pkg" ;;
    esac
    install -m 755 "$tmp/$inner" "$LOCAL_BIN/$name"
    rm -rf "$tmp"
    gray "$name installed to $LOCAL_BIN/$name"
}

# cargo_install_if_missing <command> <crate>
cargo_install_if_missing() {
    local cmd="$1" crate="$2"
    if command -v "$cmd" &>/dev/null; then
        gray "$cmd is already installed."
    elif command -v cargo &>/dev/null; then
        gray "cargo install --locked $crate ..."
        cargo install --locked "$crate"
        gray "$crate installed."
    else
        warn "cargo が無いので $crate を飛ばす"
    fi
}

# apt の yq は Python 版（kislyuk）。欲しいのは Go 版（mikefarah）
have_go_yq() {
    command -v yq &>/dev/null && yq --version 2>&1 | grep -q mikefarah
}

mkdir -p "$LOCAL_BIN"

# --- 1. パッケージ ---
if [ "$OS_FAMILY" = "fedora" ]; then
    step "Installing dnf packages (Fedora)..."
    # --skip-unavailable: 1 つ名前が見つからなくても取引全体を失敗させない（dnf5）
    # fd-find は Fedora では fd の名で入る。yq は Go 版。util-linux-user は chsh
    # sd / ast-grep は Fedora のリポジトリに無いので rust / cargo を入れて後で cargo install
    sudo dnf install -y --skip-unavailable \
        git curl unzip zsh fzf zoxide trash-cli util-linux-user \
        ripgrep fd-find jq yq bat git-delta difftastic eza hyperfine \
        rust cargo
else
    step "Installing apt packages (Debian/Ubuntu)..."
    # yq は入れない（apt のは Python 版。後で Go 版を置く）
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        git curl wget unzip zsh fzf zoxide trash-cli \
        ripgrep fd-find jq bat sd hyperfine

    # --- eza (gierens PPA) ---
    step "Installing eza..."
    if command -v eza &>/dev/null; then
        gray "eza is already installed."
    else
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt-get update -qq
        sudo apt-get install -y -qq eza
        gray "eza installed."
    fi

    # --- git-delta (GitHub releases) ---
    step "Installing git-delta..."
    if command -v delta &>/dev/null; then
        gray "delta is already installed."
    else
        ARCH="$(dpkg --print-architecture)"
        DELTA_DEB="git-delta_${DELTA_VERSION}_${ARCH}.deb"
        DELTA_URL="https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/${DELTA_DEB}"
        TMP_DEB="$(mktemp /tmp/delta-XXXXXX.deb)"
        gray "Downloading delta ${DELTA_VERSION} (${ARCH})..."
        wget -qO "$TMP_DEB" "$DELTA_URL"
        sudo dpkg -i "$TMP_DEB"
        rm -f "$TMP_DEB"
        gray "delta installed."
    fi
fi

# --- 2. リポジトリに無いツール ---
step "Installing tools missing from the package repos..."
if [ "$OS_FAMILY" = "fedora" ]; then
    # Fedora の rust は新しいので cargo でよい（sd: rust 1.86+, ast-grep: 1.88+）
    cargo_install_if_missing sd sd
    cargo_install_if_missing ast-grep ast-grep
else
    # Debian/Ubuntu の rustc は sd / ast-grep の MSRV より古く cargo install が通らないので、
    # GitHub release のバイナリを ~/.local/bin に置く
    if have_go_yq; then
        gray "yq (Go) is already installed."
    else
        if command -v yq &>/dev/null; then
            warn "apt の yq (Python 版) が入っている。~/.local/bin の Go 版を優先させる"
        fi
        install_release_binary yq \
            "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${GO_ARCH}"
    fi
    if command -v ast-grep &>/dev/null; then
        gray "ast-grep is already installed."
    else
        # zip には sg も入っているが、/usr/bin/sg (shadow-utils) と名前が被るので ast-grep だけ取り出す
        install_release_binary ast-grep \
            "https://github.com/ast-grep/ast-grep/releases/download/${AST_GREP_VERSION}/app-${RUST_ARCH}-unknown-linux-gnu.zip" \
            ast-grep
    fi
    if command -v difft &>/dev/null; then
        gray "difft is already installed."
    else
        install_release_binary difft \
            "https://github.com/Wilfred/difftastic/releases/download/${DIFFTASTIC_VERSION}/difft-${DIFFTASTIC_VERSION}-${RUST_ARCH}-unknown-linux-gnu.tar.gz" \
            difft
    fi
fi

# --- 3. Oh My Zsh ---
step "Installing Oh My Zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    gray "Oh My Zsh is already installed."
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    gray "Oh My Zsh installed."
fi

# --- 4. Oh My Zsh カスタムプラグイン ---
step "Installing Oh My Zsh custom plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    gray "zsh-autosuggestions is already installed."
else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    gray "zsh-autosuggestions installed."
fi

if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    gray "zsh-syntax-highlighting is already installed."
else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    gray "zsh-syntax-highlighting installed."
fi

# --- 5. Starship ---
step "Installing Starship..."
if command -v starship &>/dev/null; then
    gray "Starship is already installed."
else
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    gray "Starship installed."
fi

# --- 6. シンボリックリンク (Debian 互換) ---
step "Creating symlinks in ~/.local/bin..."

# batcat -> bat
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
    gray "batcat -> bat"
fi

# fdfind -> fd
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
    gray "fdfind -> fd"
fi

# --- 7. .zshrc シンボリックリンク ---
step "Linking .zshrc..."
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
    gray "Backed up existing .zshrc to .zshrc.bak"
fi
ln -sf "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
gray "Linked ~/.zshrc -> $DOTFILES_DIR/shell/.zshrc"

# --- 8. cargo の PATH (bash 用) ---
# zsh 側は shell/.zshrc に入っている。bash で使うときのために ~/.bashrc にも 1 回だけ足す
step "Adding ~/.cargo/bin to PATH in ~/.bashrc..."
if [ -d "$HOME/.cargo/bin" ]; then
    if grep -qF '.cargo/bin' "$HOME/.bashrc" 2>/dev/null; then
        gray "$HOME/.bashrc already has $HOME/.cargo/bin in PATH."
    else
        # 末尾に足す: ast-grep が置く ~/.cargo/bin/sg で shadow-utils の /usr/bin/sg を隠さないため
        # shellcheck disable=SC2016  # 展開せず、この文字列のまま .bashrc に書く
        printf '\n# cargo (added by dotfiles/setup.sh)\nexport PATH="$PATH:$HOME/.cargo/bin"\n' >> "$HOME/.bashrc"
        gray "Appended ~/.cargo/bin to PATH in ~/.bashrc"
    fi
else
    gray "$HOME/.cargo/bin is not present, skipping."
fi

# --- 9. AI エージェント用の指示書 ---
# ai/AGENTS.md が源。Claude Code (~/.claude/CLAUDE.md) と Codex CLI (~/.codex/AGENTS.md) にリンクする
step "Linking AI agent instructions (ai/AGENTS.md)..."
AI_SRC="$DOTFILES_DIR/ai/AGENTS.md"
AI_MARKER="managed by dotfiles"   # ai/AGENTS.md の 1 行目。これが無い中身のあるファイルは自分で書いたもの

link_ai_instructions() {
    local dest="$1"
    mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$AI_SRC" ]; then
            gray "$dest is already linked."
        else
            warn "$dest は別の場所 ($(readlink "$dest")) を指すリンク。触らない。使うなら rm して再実行"
        fi
    elif [ -s "$dest" ] && ! grep -qF "$AI_MARKER" "$dest" && ! cmp -s "$dest" "$AI_SRC"; then
        # 自分で書いた中身がある → 上書きしない。統合は手で決める
        warn "$dest に独自の内容がある。触らない。$AI_SRC に統合してから rm $dest して再実行"
    else
        # 無い / 空 / 以前コピーしたもの → .bak に退避してリンク
        if [ -e "$dest" ]; then
            mv "$dest" "$dest.bak"
            gray "Backed up $dest to $dest.bak"
        fi
        ln -s "$AI_SRC" "$dest"
        gray "Linked $dest -> $AI_SRC"
    fi
}

link_ai_instructions "$HOME/.claude/CLAUDE.md"
link_ai_instructions "$HOME/.codex/AGENTS.md"

# --- 10. Git config ---
step "Setting up Git config..."
if [ -f "$DOTFILES_DIR/git/config" ]; then
    # shellcheck disable=SC2088  # git config には ~ のまま入れる（他の PC でも同じ文字列になるように）
    GIT_INCLUDE="~/dotfiles/git/config"
    CURRENT_INCLUDES="$(git config --global --get-all include.path 2>/dev/null || true)"
    if echo "$CURRENT_INCLUDES" | grep -qF "$GIT_INCLUDE"; then
        gray "Git include.path already configured."
    else
        git config --global --add include.path "$GIT_INCLUDE"
        gray "Added git include.path -> $GIT_INCLUDE"
    fi
else
    warn "git/config がまだ dotfiles に無いので include.path は飛ばす"
fi
git config --global core.autocrlf input
gray "Set core.autocrlf = input (Linux)"

# --- 11. デフォルトシェルを zsh に変更 ---
step "Setting default shell to zsh..."
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" = "$ZSH_PATH" ]; then
    gray "zsh is already the default shell."
elif ! command -v chsh &>/dev/null; then
    warn "chsh が無い (Fedora なら util-linux-user)。手動で: chsh -s $ZSH_PATH"
else
    chsh -s "$ZSH_PATH"
    gray "Default shell changed to zsh. Re-login to take effect."
fi

echo ""
info "=== Setup complete ==="
echo ""
step "Next steps:"
gray "Re-login or run 'zsh' to start using your new shell."
gray "Check tools: for t in rg fd jq ast-grep sd yq difft bat eza hyperfine; do printf '%-10s ' \"\$t\"; command -v \"\$t\" || echo MISSING; done"
