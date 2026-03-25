#!/bin/bash
# Claude Code Notification Script for macOS/Linux

TITLE="${1:-Claude Code}"
MESSAGE="${2:-通知}"
DIR="${3:-}"

# 默认配置
BARK_URL=""
SYSTEM_NOTIFICATION_ENABLED="true"
NOTIFY_ALWAYS="false"

# 读取配置文件
CONFIG_FILE="$DIR/.claude/claude-notification.local.md"
if [[ -f "$CONFIG_FILE" ]]; then
    FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$CONFIG_FILE")

    if [[ -n "$FRONTMATTER" ]]; then
        BARK_URL=$(echo "$FRONTMATTER" | grep '^bark_url:' | sed 's/bark_url: *//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
        SYSTEM_NOTIFICATION_ENABLED_VAL=$(echo "$FRONTMATTER" | grep '^system_notification_enabled:' | sed 's/system_notification_enabled: *//')
        if [[ "$SYSTEM_NOTIFICATION_ENABLED_VAL" == "false" ]]; then
            SYSTEM_NOTIFICATION_ENABLED="false"
        fi
        NOTIFY_ALWAYS_VAL=$(echo "$FRONTMATTER" | grep '^notify_always:' | sed 's/notify_always: *//')
        if [[ "$NOTIFY_ALWAYS_VAL" == "true" ]]; then
            NOTIFY_ALWAYS="true"
        fi
    fi
fi

# 检测前台应用是否是终端
send_notification() {
    local should_notify=false
    local terminal_name=""

    # 如果配置了 always_notify，直接发送通知
    if [[ "$NOTIFY_ALWAYS" == "true" ]]; then
        should_notify=true
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - 检测前台应用
        FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
        TERMINALS="Terminal|iTerm|iTerm2|Alacritty|kitty|Warp|Hyper|Code|Cursor|VSCodium"

        # 获取终端名称
        terminal_name="$FRONT_APP"

        if [[ ! "$FRONT_APP" =~ ^($TERMINALS)$ ]]; then
            should_notify=true
        fi
    else
        # Linux - 始终发送通知
        should_notify=true
        # 尝试获取终端名称
        if [[ -n "$TERM_PROGRAM" ]]; then
            terminal_name="$TERM_PROGRAM"
        elif [[ -n "$TERMINAL_EMULATOR" ]]; then
            terminal_name="$TERMINAL_EMULATOR"
        else
            # 从父进程获取
            terminal_name=$(ps -o comm= -p $PPID 2>/dev/null || echo "Terminal")
        fi
    fi

    if [[ "$should_notify" == "true" ]]; then
        # 添加目录信息
        if [ -n "$DIR" ]; then
            SHORT_DIR=$(echo "$DIR" | rev | cut -d'/' -f1-2 | rev)
            MESSAGE="$MESSAGE - $SHORT_DIR"
        fi

        # 添加终端名称
        if [ -n "$terminal_name" ]; then
            MESSAGE="$MESSAGE [$terminal_name]"
        fi

        # 发送 Bark 通知
        if [[ -n "$BARK_URL" ]]; then
            ENCODED_TITLE=$(printf '%s' "$TITLE" | jq -sRr @uri 2>/dev/null || echo "$TITLE")
            ENCODED_MESSAGE=$(printf '%s' "$MESSAGE" | jq -sRr @uri 2>/dev/null || echo "$MESSAGE")
            curl -s -m 5 "$BARK_URL/$ENCODED_TITLE/$ENCODED_MESSAGE" >/dev/null 2>&1 || true
        fi

        # 发送系统通知（除非 system_notification_enabled 为 false）
        if [[ "$SYSTEM_NOTIFICATION_ENABLED" == "true" ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
            else
                # Linux
                if command -v notify-send &> /dev/null; then
                    notify-send "$TITLE" "$MESSAGE" -t 5000
                fi
            fi
        fi
    fi
}

send_notification
