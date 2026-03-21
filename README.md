# nischal-statusline

A minimal Claude Code statusline showing model, context usage, git info, session duration, and cost.

## Preview

```
Claude Sonnet 4.6 │ in myproject (main*) │ ●●●●○○○○○○ 41%/200k │ ⏱ 12m │ $0.42

context ●●●○○○○○○○  32%  input tokens
total   ●●●●○○○○○○  41%  incl. cache
```

## Install

```bash
npx @nischal94/claude-statusline
```

## Requirements

- `jq` — for parsing JSON
- `git` — for branch info

On macOS:
```bash
brew install jq
```

## Uninstall

```bash
npx @nischal94/claude-statusline --uninstall
```

If you had a previous statusline, it restores it from the backup. Otherwise it removes the script and cleans up your settings.

## License

MIT
