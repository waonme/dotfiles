#!/usr/bin/env bash
# dotfiles setup script for Linux / WSL (Ubuntu/Debian)
# Usage: bash ~/dotfiles/setup.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { printf '\033[0;36m%s\033[0m\n' "$*"; }
step()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
gray()  { printf '\033[0;37m  %s\033[0m\n' "$*"; }
warn()  { printf '\033[0;31m  [WARN] %s\033[0m\n' "$*"; }

info "=== dotfiles setup (Linux/WSL) ==="

# --- 1. apt パッケージ ---
step "Installing apt packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq zsh bat fd-find ripgrep fzf zoxide trash-cli

# --- 2. eza (gierens PPA) ---
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

# --- 3. git-delta (GitHub releases) ---
step "Installing git-delta..."
if command -v delta &>/dev/null; then
    gray "delta is already installed."
else
    DELTA_VERSION="0.18.2"
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

# --- 4. Oh My Zsh ---
step "Installing Oh My Zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    gray "Oh My Zsh is already installed."
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    gray "Oh My Zsh installed."
fi

# --- 5. Oh My Zsh カスタムプラグイン ---
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

# --- 6. Starship ---
step "Installing Starship..."
if command -v starship &>/dev/null; then
    gray "Starship is already installed."
else
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    gray "Starship installed."
fi

# --- 7. シンボリックリンク (Debian 互換) ---
step "Creating symlinks in ~/.local/bin..."
mkdir -p "$HOME/.local/bin"

# batcat -> bat
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    gray "batcat -> bat"
fi

# fdfind -> fd
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    gray "fdfind -> fd"
fi

# --- 8. .zshrc シンボリックリンク ---
step "Linking .zshrc..."
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
    gray "Backed up existing .zshrc to .zshrc.bak"
fi
ln -sf "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
gray "Linked ~/.zshrc -> $DOTFILES_DIR/shell/.zshrc"

# --- 9. Git config ---
step "Setting up Git config..."
GIT_INCLUDE="~/dotfiles/git/config"
CURRENT_INCLUDES="$(git config --global --get-all include.path 2>/dev/null || true)"
if echo "$CURRENT_INCLUDES" | grep -qF "$GIT_INCLUDE"; then
    gray "Git include.path already configured."
else
    git config --global --add include.path "$GIT_INCLUDE"
    gray "Added git include.path -> $GIT_INCLUDE"
fi
git config --global core.autocrlf input
gray "Set core.autocrlf = input (Linux)"

# --- 10. デフォルトシェルを zsh に変更 ---
step "Setting default shell to zsh..."
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" = "$ZSH_PATH" ]; then
    gray "zsh is already the default shell."
else
    chsh -s "$ZSH_PATH"
    gray "Default shell changed to zsh. Re-login to take effect."
fi

echo ""
info "=== Setup complete ==="
echo ""
step "Next steps:"
gray "Re-login or run 'zsh' to start using your new shell."
gray "Run 'zsh' to verify the configuration."
