#!/bin/bash

SETTINGS="$HOME/.claude/settings.json"

current=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)

if [[ "$current" == *"statusline-command.sh"* ]]; then
    # Switch to API-driven
    jq '.statusLine.command = "bash \"$HOME/.claude/statusline.sh\""' "$SETTINGS" > /tmp/settings.tmp && mv /tmp/settings.tmp "$SETTINGS"
    echo "Switched to: API-driven (current/weekly rate limits)"
else
    # Switch to original
    jq '.statusLine.command = "bash \"$HOME/.claude/statusline-command.sh\""' "$SETTINGS" > /tmp/settings.tmp && mv /tmp/settings.tmp "$SETTINGS"
    echo "Switched to: original (project type, git details, plugins, cost)"
fi
