# ~/.zshrc — dotfiles 管理下のポータブル設定 (Oh My Zsh + Starship)
# 使い方: シンボリックリンクまたはソース読み込み
#   ln -sf ~/dotfiles/shell/.zshrc ~/.zshrc
#   または既存 .zshrc に: source ~/dotfiles/shell/.zshrc

# --- PATH ---
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# --- エイリアス ---
command -v eza &>/dev/null && alias ls='eza --icons --group-directories-first'
command -v eza &>/dev/null && alias ll='eza --icons --group-directories-first -la'
command -v eza &>/dev/null && alias la='eza -a'
command -v eza &>/dev/null && alias lt='eza --icons --tree --level=2'
command -v bat &>/dev/null && alias cat='bat --paging=never'
command -v rg  &>/dev/null && alias grep='rg'
command -v fd  &>/dev/null && alias find='fd'
command -v trash &>/dev/null && alias rm='trash'

# --- fzf ---
if command -v fzf &>/dev/null; then
    eval "$(fzf --zsh 2>/dev/null)" || source <(fzf --zsh 2>/dev/null) || true

    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
fi

# --- zoxide ---
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# --- Starship ---
command -v starship &>/dev/null && eval "$(starship init zsh)"

# --- 補完カスタマイズ (OMZ source 後) ---
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# --- zsh オプション ---
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt NO_CLOBBER

# --- 履歴 ---
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
