<!-- managed by dotfiles: ~/dotfiles/ai/AGENTS.md (edit there, then re-run setup.sh / setup.ps1) -->
## Preferred CLI Tools

Use these instead of standard tools in shell commands. If a preferred tool is missing (`command -v <tool>` fails), fall back to the standard one without asking.

| Priority | Instead of | Use | Why | Usage |
|---|---|---|---|---|
| 1 | `grep` | `rg` | Fast recursive search, respects .gitignore | `rg -n 'pattern'`; `-l` files only; `-t py` by type; `-uu` include ignored/hidden; `--json` for structured output |
| 1 | `find` | `fd` | Simple syntax, respects .gitignore | `fd -e ts`; `-t f` files only; `-H` hidden; `-I` no-ignore |
| 1 | regex on JSON | `jq` | Parse JSON structurally, never with regex | `jq -r '.items[].name'`; `-c` one object per line |
| 1 | regex for code structure | `ast-grep` | Syntax-aware search/rewrite; ignores matches in strings and comments | `ast-grep -p 'console.log($A)' -l ts`; `--rewrite` for refactors. Always call `ast-grep`, not `sg` (name clash on Linux) |
| 2 | `sed` | `sd` | Familiar regex syntax, no escaping traps | `sd 'old' 'new' file`; `-F` for literal strings. Edits in place: only on git-tracked files |
| 2 | regex on YAML/TOML | `yq` (Go version) | jq syntax for YAML, TOML, XML | `yq '.services' file.yaml`; `-o json` to pipe into jq |
| 3 | `diff` | `difft` | Structural diff, ignores formatting-only changes | `difft --display inline --color never a b` |
| 3 | `sed -n` / `head`+`tail` | `bat` | Print exact line ranges | `bat -pp -r 40:80 file` (plain, no pager) |
| 3 | `tree` / `ls -R` | `eza` | Directory tree that respects .gitignore | `eza --tree --git-ignore -L 2` |
| 3 | `time` | `hyperfine` | Repeated runs with statistics | `hyperfine --warmup 3 --export-json out.json 'cmd'` |

### Rules
- Never launch interactive tools or pagers. Use `git --no-pager` or `GIT_PAGER=cat`.
- Parse JSON/YAML with `jq`/`yq`, not `grep`/`sed`.
- Prefer `ast-grep` over `rg` when the match depends on code structure (calls, imports, function signatures).
