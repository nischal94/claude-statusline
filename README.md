# claude-statusline

A Claude Code statusline showing real-time rate limits, model info, context usage, project type, git details, plugins, cost, and session duration.

## Preview

```
Claude Sonnet 4.6 [Explanatory] │ [████░░░░░░ 41% / 200k] │ nischal ⚛ React (main*) ↑2 +3 ~1 │ ⏱ 12m │ ◑ default │ 4 plugins │ 7 mcp │ $0.02

current ●●●●○○○○○○  45% ⟳ 47m
weekly  ●●●●●●○○○○  55% ⟳ 2d14h
```

**Yellow:** model name · `[style]` · directory · project type · session duration · effort · plugins · cost
**Green → Yellow → Red:** context bar (80%/90%) · current bar (80%/90%) · weekly bar (50%/90%)
**Green:** git branch · white: labels and reset times

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

**Line 1:** Model name · Output style (if non-default) · Context window bar `[████░░░░░░ 41% / 200k]` · Directory · Project type · Git branch + dirty flag · Ahead/behind remote · File change counts · Session duration · Effort level · Plugin count · Hook count · MCP server count · Cost

**Lines 2–3:** Live rate limit data fetched from the Anthropic API (cached for 60s)
- `current` — 5-hour window utilization with live countdown to reset (e.g. `47m`, `1h23m`)
- `weekly` — 7-day window utilization with live countdown to reset (e.g. `2d14h`)
- `extra` — paid credit usage (shown only if enabled on your account)

### Color scheme

Yellow is the primary accent color. Dynamic bars shift based on usage:

| Element | Green | Yellow | Red |
|---------|-------|--------|-----|
| Context window bar | < 80% | ≥ 80% | ≥ 90% |
| Current rate limit | < 80% | ≥ 80% | ≥ 90% |
| Weekly rate limit | < 50% | ≥ 50% | ≥ 90% |

**Always yellow:** model name · output style · directory · session duration · plugin count · hook count · MCP server count

**Always grey/dim:** project type · effort level · cost · labels · reset times · separators

**Always green:** git branch

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
