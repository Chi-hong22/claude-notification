#!/bin/bash
AUDIO_FILE="$1"

[ -z "$AUDIO_FILE" ] || [ ! -f "$AUDIO_FILE" ] && exit 0

if command -v afplay &>/dev/null; then
    afplay "$AUDIO_FILE"
elif command -v aplay &>/dev/null; then
    aplay -q "$AUDIO_FILE"
elif command -v paplay &>/dev/null; then
    paplay "$AUDIO_FILE"
fi
