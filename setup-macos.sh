#!/usr/bin/env bash
# dotfiles setup script for macOS
# Usage: bash ~/dotfiles/setup-macos.sh
# 何度実行しても同じ結果になる。sudo・chsh は使わない（macOS の既定シェルは zsh）

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
step()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
gray()  { printf '\033[0;37m  %s\033[0m\n' "$*"; }
warn()  { printf '\033[0;31m  [WARN] %s\033[0m\n' "$*"; }

info "=== dotfiles setup (macOS) ==="

# --- 1. Homebrew ---
step "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
    warn "Homebrew がない。https://brew.sh の手順で入れてから、もう一度実行する"
    exit 1
fi

# --- 2. Brewfile ---
step "Installing packages from macos/Brewfile..."
brew bundle --file="$DOTFILES_DIR/macos/Brewfile" --no-upgrade

# --- 3. Oh My Zsh ---
step "Installing Oh My Zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    gray "Oh My Zsh is already installed."
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    gray "Oh My Zsh installed."
fi

# --- 4. Oh My Zsh カスタムプラグイン ---
step "Installing Oh My Zsh custom plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
    name="${repo#*/}"
    if [ -d "$ZSH_CUSTOM/plugins/$name" ]; then
        gray "$name is already installed."
    else
        git clone "https://github.com/$repo" "$ZSH_CUSTOM/plugins/$name"
        gray "$name installed."
    fi
done

# --- 5. .zshrc シンボリックリンク ---
step "Linking .zshrc..."
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    backup="$HOME/.zshrc.bak-$(date +%Y%m%d-%H%M%S)"
    mv "$HOME/.zshrc" "$backup"
    gray "Backed up existing .zshrc to $backup"
    gray "マシン固有の設定（PATH・エイリアス・API キーなど）は ~/.zshrc.local に移す"
fi
ln -sf "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
gray "Linked ~/.zshrc -> $DOTFILES_DIR/shell/.zshrc"

# --- 6. ~/.zshrc.local（無ければ雛形だけ）---
if [ ! -f "$HOME/.zshrc.local" ]; then
    cat > "$HOME/.zshrc.local" <<'LOCAL'
# このマシンだけの zsh 設定（dotfiles の管理外。公開しない）
# 例: export PATH="$HOME/.volta/bin:$PATH"
# 秘密の値は 1Password から: export SOME_API_KEY="$(op read 'op://...')"
LOCAL
    chmod 600 "$HOME/.zshrc.local"
    gray "Created ~/.zshrc.local (template)"
fi

# --- 7. Git config ---
step "Setting up Git config..."
if [ -f "$DOTFILES_DIR/git/config" ]; then
    GIT_INCLUDE="~/dotfiles/git/config"
    if git config --global --get-all include.path 2>/dev/null | grep -qF "$GIT_INCLUDE"; then
        gray "Git include.path already configured."
    else
        git config --global --add include.path "$GIT_INCLUDE"
        gray "Added git include.path -> $GIT_INCLUDE"
    fi
else
    warn "git/config がまだ dotfiles に無いので飛ばす"
fi
git config --global core.autocrlf input
gray "Set core.autocrlf = input"

echo ""
info "=== Setup complete ==="
gray "新しいターミナルを開くと反映される。フォントは MesloLGS Nerd Font を選ぶとアイコンが出る"
