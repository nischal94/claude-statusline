# claude-statusline

A Claude Code statusline showing real-time rate limits, model info, context usage, project type, git details, plugins, cost, and session duration.

## Preview

```
Claude Sonnet 4.6 [explanatory] │ ✍️ 41% │ myproject ⚡Next.js (main*) ↑2 +3 ~1 │ ⏱ 12m │ ◑ default │ 4 plugins │ 3 hooks

current ●●●●○○○○○○  45% ⟳ 2:30pm
weekly  ●●●●●●○○○○  65% ⟳ mar 28
```

## Install

```bash
npx @nischal94/claude-statusline
```

Backs up your existing statusline (if any), copies the script to `~/.claude/statusline.sh`, and configures Claude Code settings automatically.

## Requirements

- [jq](https://jqlang.github.io/jq/) — for parsing JSON
- `curl` — for fetching rate limit data from the Anthropic API
- `git` — for branch info

On macOS:

```bash
brew install jq
```

## What It Shows

**Line 1:** Model name · Output style (if non-default) · Context usage % · Directory · Project type · Git branch + dirty flag · Ahead/behind remote · File change counts · Session duration · Effort level · Plugin count · Hook count

**Lines 2–3:** Live rate limit data fetched from the Anthropic API (cached for 60s)
- `current` — 5-hour window utilization with reset time
- `weekly` — 7-day window utilization with reset date
- `extra` — paid credit usage (shown only if enabled on your account)

### Project types detected

| Icon | Type |
|------|------|
| ⚡ | Next.js |
| ⚛ | React |
| 💚 | Vue |
| 📦 | Node |
| 🐍 | Python |
| 🦀 | Rust |
| 🐹 | Go |
| 💎 | Ruby |
| ☕ | Java |
| 🐘 | PHP |

### Git indicators

- `(main*)` — dirty working tree
- `↑2` / `↓1` — commits ahead/behind remote
- `+3` — untracked files (red)
- `✓1` — staged files (green)
- `~2` — modified files (yellow)

## Uninstall

```bash
npx @nischal94/claude-statusline --uninstall
```

Restores your previous statusline if one was backed up, otherwise removes the script and cleans up settings.

## License

MIT
