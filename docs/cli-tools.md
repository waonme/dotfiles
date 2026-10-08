# Modern CLI Tools

人間向けの一覧。AI エージェント向けの指示書は [`ai/AGENTS.md`](../ai/AGENTS.md)（`~/.claude/CLAUDE.md` と `~/.codex/AGENTS.md` に配られる）。

| Priority | Standard | Preferred | Why | Notes |
|---|---|---|---|---|
| ★★★ | `grep` | `rg` (ripgrep) | Fastest recursive search, respects .gitignore | `-uu` includes ignored/hidden; `-t py` filters by type |
| ★★★ | `find` | `fd` | Intuitive syntax, faster, respects .gitignore | `-H` hidden, `-I` no-ignore, `-x`/`-X` to exec |
| ★★★ | `grep`/`sed` on JSON | `jq` | Structured JSON query and transform | `-r` raw strings; `-c` compact |
| ★★★ | regex code search | `ast-grep` | Syntax-aware search/rewrite | `ast-grep -p 'console.log($A)' -l ts` |
| ★★☆ | `sed` | `sd` | Familiar regex syntax | `-F` literal; in-place by default |
| ★★☆ | `cat` | `bat` | Syntax highlighting, line numbers, git markers | `-p` plain, `-r 10:40` range |
| ★★☆ | `git diff` pager | `delta` | Side-by-side, highlighted diffs | Set as `core.pager` |
| ★★☆ | `diff` | `difftastic` (`difft`) | AST-aware diff | `GIT_EXTERNAL_DIFF=difft git diff` |
| ★★☆ | `ls` | `eza` | Git status, tree view | `eza --tree --git-ignore` |
| ★★☆ | `grep`/`sed` on YAML/TOML | `yq` | jq-style queries for YAML/TOML/XML | Go version (mikefarah) |
| ★☆☆ | `time` | `hyperfine` | Statistical benchmarking | `hyperfine 'cmd A' 'cmd B'` |
| ★☆☆ | `curl` | `xh` | Concise syntax, colorized JSON | Keep `curl` for portable scripts |
| ★☆☆ | `du` | `dust` | Visual disk usage tree | `-d 2` |
| ★☆☆ | `df` | `duf` | Readable disk table | — |
| ★☆☆ | `ps` | `procs` | Colored, searchable, shows ports | `procs --tree` |
| ★☆☆ | `top`/`htop` | `btm` (bottom) | Graphs for CPU/mem/net | Interactive |
| ★☆☆ | `cut`/`awk` | `choose` | Simple field selection | `choose 0 2` |
| ★☆☆ | `man` | `tldr` (tealdeer) | Practical examples | `tldr --update` once |
| ★☆☆ | `cd` | `zoxide` | Jump by fragment | Interactive |
| ★☆☆ | history / picking | `fzf` | Fuzzy finder | Pairs with `fd`, `rg` |

## Install

★★★ / ★★☆ のツールは `setup.sh`（Fedora / Ubuntu / Debian）・`setup.ps1`（Windows, scoop）・`setup-macos.sh`（Brewfile）が入れる。★☆☆ は手動。

macOS:
```sh
brew install ripgrep fd jq ast-grep sd bat git-delta difftastic eza yq \
  hyperfine xh dust duf procs bottom choose-rust tealdeer zoxide fzf
```

Fedora:
```sh
sudo dnf install --skip-unavailable ripgrep fd-find jq bat git-delta difftastic eza yq \
  hyperfine duf procs tealdeer zoxide fzf rust cargo
cargo install --locked sd ast-grep xh du-dust bottom choose
echo 'export PATH="$PATH:$HOME/.cargo/bin"' >> ~/.bashrc   # 末尾に足す（ast-grep の sg が /usr/bin/sg を隠さないように）
tldr --update
```

Ubuntu / Debian:
```sh
sudo apt-get install ripgrep fd-find jq bat sd hyperfine zoxide fzf
# apt の yq は Python 版なので使わない。yq (Go) / ast-grep / difftastic は setup.sh が GitHub release のバイナリを ~/.local/bin に置く
```
