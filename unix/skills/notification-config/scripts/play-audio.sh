#!/bin/bash
AUDIO_FILE="$1"
DIR="${2:-$CLAUDE_PROJECT_DIR}"

[ -z "$AUDIO_FILE" ] || [ ! -f "$AUDIO_FILE" ] && exit 0

AUDIO_ENABLED="true"
AUDIO_ALWAYS="false"

if [ -n "$DIR" ]; then
    CONFIG="$DIR/.claude/claude-notification.local.md"
    if [ -f "$CONFIG" ]; then
        AUDIO_ENABLED_VAL=$(grep -m1 '^audio_enabled:' "$CONFIG" | awk '{print $2}')
        [ "$AUDIO_ENABLED_VAL" = "false" ] && exit 0
        AUDIO_ALWAYS_VAL=$(grep -m1 '^audio_always:' "$CONFIG" | awk '{print $2}')
        [ "$AUDIO_ALWAYS_VAL" = "true" ] && AUDIO_ALWAYS="true"
    fi
fi

if [[ "$AUDIO_ALWAYS" != "true" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
        TERMINALS="Terminal|iTerm|iTerm2|Alacritty|kitty|Warp|Hyper|Code|Cursor|VSCodium"
        if [[ "$FRONT_APP" =~ ^($TERMINALS)$ ]]; then
            exit 0
        fi
    fi
    # Linux: no reliable foreground detection, always play
fi

if command -v afplay &>/dev/null; then
    afplay "$AUDIO_FILE"
elif command -v aplay &>/dev/null; then
    aplay -q "$AUDIO_FILE"
elif command -v paplay &>/dev/null; then
    paplay "$AUDIO_FILE"
fi
