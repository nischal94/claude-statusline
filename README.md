# claude-statusline

A Claude Code statusline showing real-time rate limits, model info, context usage, git info, and session duration.

## Preview

```
Claude Sonnet 4.6 │ ✍️ 41% │ myproject (main) │ ⏱ 12m │ ◑ default

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

**Line 1:** Model name · Context usage % · Directory (git branch) · Session duration · Effort level

**Lines 2–3:** Live rate limit data fetched from the Anthropic API (cached for 60s)
- `current` — 5-hour window utilization with reset time
- `weekly` — 7-day window utilization with reset date
- `extra` — paid credit usage (shown only if enabled on your account)

## Uninstall

```bash
npx @nischal94/claude-statusline --uninstall
```

Restores your previous statusline if one was backed up, otherwise removes the script and cleans up settings.

## License

MIT
