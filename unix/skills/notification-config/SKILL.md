---
name: notification-config
description: |
  Use this skill to configure or send push notifications in Claude Code on Unix/macOS/Linux.
  Trigger when the user says things like: "configure notifications", "set up Bark", "set up WeChat push",
  "配置通知", "设置推送", "配置微信通知", "配置 Bark", "任务完成后通知我", "帮我开启通知",
  "make notifications persistent", "always notify", or mentions "Bark", "WeChat", "xtuis", "notification settings".
  Also trigger proactively when AI completes a long-running task and should notify the user.
---

# Claude Notification Configuration and Usage (Unix/macOS/Linux)

This skill handles two things: configuring notification channels, and proactively sending notifications.

## Configuration File

**Location**: `.claude/claude-notification.local.md` (project root)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `bark_url` | string | empty | Bark push URL, e.g., `https://api.day.app/your-key` |
| `wechat_token` | string | empty | WeChat Token from https://xtuis.cn/ |
| `wechat_hook_enabled` | boolean | false | Enable WeChat hook auto-trigger |
| `bark_hook_enabled` | boolean | false | Enable Bark hook auto-trigger |
| `system_notification_enabled` | boolean | true | Enable system notifications |
| `notify_always` | boolean | false | Notify even when terminal is in foreground |
| `audio_enabled` | boolean | true | Play audio on PermissionRequest/Stop hooks |
| `audio_always` | boolean | false | Play audio even when terminal is in foreground |

Template:
```markdown
---
bark_url: ""
wechat_token: ""
wechat_hook_enabled: false
bark_hook_enabled: false
system_notification_enabled: true
notify_always: false
audio_enabled: true
audio_always: false
---
```

## Available Scripts

Located in `scripts/` directory of this skill:

- `scripts/notify.sh` — System notification (osascript on macOS, notify-send on Linux)
- `scripts/bark.sh` — Bark push (rich parameters)
- `scripts/wechat.sh` — WeChat push
- `scripts/play-audio.sh` — Audio notification (afplay/aplay/paplay)
- `audio/warning.wav` — Warning sound (PermissionRequest hook)
- `audio/complete.wav` — Completion sound (Stop hook)

## Script Usage

### System Notification
```bash
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/notify.sh" "Title" "Content" "${CLAUDE_PROJECT_DIR}"
```

### Bark Push
```bash
# Simple
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/bark.sh" -u "URL" -m "Task completed"

# With title
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/bark.sh" -u "URL" -t "Claude" -m "Code review done"

# Urgent (ring 30s)
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/bark.sh" -u "URL" -m "Urgent!" -c

# Grouped
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/bark.sh" -u "URL" -m "Build done" -g "build"
```

Bark parameters: `-u/--url` (required), `-m/--message` (required), `-t/--title`, `-g/--group`, `-s/--sound`, `-c/--call`, `-l/--level`, `-i/--icon`, `-b/--badge`, `--copy`, `--auto-copy`, `--archive`, `--redirect`

### WeChat Push
```bash
# Simple
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/wechat.sh" -t "TOKEN" -x "Task completed"

# With description
"${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/wechat.sh" -t "TOKEN" -x "Claude Code" -d "Code review done"
```

WeChat parameters: `-t/--token` (required), `-x/--text` (required), `-d/--desp` (optional)

### Audio
```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/notification-config/scripts/play-audio.sh" "${CLAUDE_PLUGIN_ROOT}/audio/complete.wav"
```

---

## Checking and Upgrading Configuration

When the user runs `/notification-config` or asks to configure notifications, first check if the config file is up to date.

**Current expected fields** (as defined in the Configuration File section above):
`bark_url`, `wechat_token`, `wechat_hook_enabled`, `bark_hook_enabled`, `system_notification_enabled`, `notify_always`, `audio_enabled`, `audio_always`

Steps:

1. Read `.claude/claude-notification.local.md`. If it doesn't exist, skip to the relevant Configure section.
2. Compare the fields present in the file against the expected fields above.
   - Identify any **missing fields** (fields in the expected set but not in the file).
   - Identify any **obsolete fields** (fields in the file but not in the expected set, e.g., `bark_only`, `timeout`).
3. If there are differences, tell the user what changed and ask: "配置文件有以下字段需要更新，是否自动补全？"
   - List the missing fields and their default values.
   - List any obsolete fields that will be removed.
4. If the user agrees, update the file:
   - For missing `bark_url` or `wechat_token`: add with empty string `""` — do NOT ask the user to fill them in here.
   - For missing `_enabled` or `_always` fields: ask the user whether to enable each one (yes/no), since these control behavior.
   - Remove obsolete fields (e.g., `bark_only: true` → set `system_notification_enabled: false` before removing; `always_notify` → rename to `notify_always`).
   - Preserve all existing values unchanged.
5. If no differences, tell the user the config is already up to date.

---

## Configuring Bark

The goal is to save the user's Bark URL so hooks and proactive notifications work automatically.

1. Read `.claude/claude-notification.local.md` to check if `bark_url` is already set.
   - If it is, show the current value and ask if they want to change it. If not, skip to step 4.
2. If the user hasn't already provided a Bark URL in their message, ask: "请提供您的 Bark 推送 URL（例如：https://api.day.app/your-key/）"
   - If they already provided it, use that value directly.
3. Write/update `.claude/claude-notification.local.md`:
   - Set `bark_url` to the provided value and `bark_hook_enabled: true`
   - Preserve existing `wechat_token` and `wechat_hook_enabled` values if the file already exists
4. Check `.claude/CLAUDE.md`:
   - If the file doesn't exist, you can still offer to create it.
   - If it exists but doesn't contain "通知功能配置" or "notification", ask:
   "是否要将通知功能添加到项目的 CLAUDE.md 中？这样 AI 就能在完成重要任务时主动发送通知。"
   Options: "是，添加到 CLAUDE.md" / "否，暂时不需要"
   - If yes, append the Bark notification block below. For `{{PLUGIN_PATH}}`: use the path from `${CLAUDE_PLUGIN_ROOT}` if available, otherwise look for the plugin path in existing hook commands in `.claude/settings.json` or `.claude/settings.local.json`.

```markdown
## 通知功能配置

### Bark 推送配置
* Bark URL: `<user's bark url>`

### 主动通知场景
AI 应该在以下场景主动发送通知：
1. **长时间任务完成** - 构建、测试、部署等耗时任务完成时
2. **需要用户确认** - 重要决策或需要用户介入时（使用 `-c` 参数持续响铃）
3. **重要里程碑** - 代码审查完成、PR 创建成功等
4. **错误警报** - 构建失败、测试未通过等异常情况

### 发送通知方法
使用 Bash 工具调用 bark.sh 脚本：

\```bash
# 基础通知
bash "{{PLUGIN_PATH}}/skills/notification-config/scripts/bark.sh" -u "<user's bark url>" -t "Claude Code" -m "任务完成"

# 紧急通知（持续响铃30秒）
bash "{{PLUGIN_PATH}}/skills/notification-config/scripts/bark.sh" -u "<user's bark url>" -t "Claude Code" -m "需要确认" -c

# 分组通知
bash "{{PLUGIN_PATH}}/skills/notification-config/scripts/bark.sh" -u "<user's bark url>" -t "构建完成" -m "项目构建成功" -g "build"
\```

### 使用原则
* 在用户明确要求通知时发送
* 完成重要任务后主动发送（如代码审查、PR创建、长时间构建等）
* 紧急情况使用 `-c` 参数
* 相关任务使用 `-g` 参数分组
```

5. If config was created or modified, remind: "配置完成后需要重启 Claude Code 才能生效"

---

## Configuring System Notifications

System notifications are desktop popups (osascript on macOS, notify-send on Linux). No token or URL needed — just toggle on/off and front/background behavior.

1. Read `.claude/claude-notification.local.md` to get current values of `system_notification_enabled` and `notify_always`.
   - Show the current state to the user.
2. Ask what they want to change. Common requests:
   - "关掉系统弹窗" → set `system_notification_enabled: false`
   - "只用 Bark/微信，不要系统通知" → set `system_notification_enabled: false`
   - "终端在前台时也弹窗" → set `notify_always: true`
   - "恢复默认" → set `system_notification_enabled: true`, `notify_always: false`
3. Write/update `.claude/claude-notification.local.md` with the new values. Preserve all other fields.
4. Remind: "配置完成后需要重启 Claude Code 才能生效"

---

## Configuring Audio Notifications

Audio notifications play WAV files on hook events (PermissionRequest → warning.wav, Stop → complete.wav). Supports afplay (macOS), aplay/paplay (Linux). Same logic as system notifications — just toggle on/off and front/background behavior.

1. Read `.claude/claude-notification.local.md` to get current values of `audio_enabled` and `audio_always`.
   - Show the current state to the user.
2. Ask what they want to change. Common requests:
   - "关掉声音" / "静音" → set `audio_enabled: false`
   - "终端在前台时也播放声音" → set `audio_always: true`
   - "恢复默认" → set `audio_enabled: true`, `audio_always: false`
3. Write/update `.claude/claude-notification.local.md` with the new values. Preserve all other fields.
4. Remind: "配置完成后需要重启 Claude Code 才能生效"

---

## Configuring WeChat

Same flow as Bark, but for WeChat.

1. Read `.claude/claude-notification.local.md` to check if `wechat_token` is already set.
   - If it is, show the current value and ask if they want to change it. If not, skip to step 4.
2. If the user hasn't already provided a token, guide them to get one:
   - Visit https://xtuis.cn/
   - Scan QR code with WeChat to follow the account
   - Copy the token and provide it
3. Write/update `.claude/claude-notification.local.md`:
   - Set `wechat_token` to the provided value and `wechat_hook_enabled: true`
   - Preserve existing `bark_url` and `bark_hook_enabled` values if the file already exists
4. Check `.claude/CLAUDE.md`:
   - If the file doesn't exist, you can still offer to create it.
   - If it exists but doesn't contain "通知功能配置" or "notification", ask:
   "是否要将微信通知功能添加到项目的 CLAUDE.md 中？这样 AI 就能在完成重要任务时主动发送通知。"
   Options: "是，添加到 CLAUDE.md" / "否，暂时不需要"
   - If yes, append the WeChat notification block below. For `{{PLUGIN_PATH}}`: use the path from `${CLAUDE_PLUGIN_ROOT}` if available, otherwise look for the plugin path in existing hook commands in `.claude/settings.json` or `.claude/settings.local.json`.

```markdown
## 通知功能配置

### 微信推送配置
* WeChat Token: `<user's wechat token>`

### 主动通知场景
AI 应该在以下场景主动发送通知：
1. **长时间任务完成** - 构建、测试、部署等耗时任务完成时
2. **需要用户确认** - 重要决策或需要用户介入时
3. **重要里程碑** - 代码审查完成、PR 创建成功等
4. **错误警报** - 构建失败、测试未通过等异常情况

### 发送通知方法
使用 Bash 工具调用 wechat.sh 脚本：

\```bash
# 基础通知
bash "{{PLUGIN_PATH}}/skills/notification-config/scripts/wechat.sh" -t "<user's wechat token>" -x "任务完成"

# 带详细内容
bash "{{PLUGIN_PATH}}/skills/notification-config/scripts/wechat.sh" -t "<user's wechat token>" -x "Claude Code" -d "代码审查完成"

# 详细通知
bash "{{PLUGIN_PATH}}/skills/notification-config/scripts/wechat.sh" -t "<user's wechat token>" -x "构建完成" -d "项目构建成功，耗时 5 分钟"
\```

### 使用原则
* 在用户明确要求通知时发送
* 完成重要任务后主动发送（如代码审查、PR创建、长时间构建等）
* 使用 `-x` 参数设置标题，`-d` 参数设置详细内容
```

5. If config was created or modified, remind: "配置完成后需要重启 Claude Code 才能生效"

---

## Sending Notifications Proactively

When the user asks to send a notification, or after completing a significant task:

1. Read `.claude/claude-notification.local.md` to get `bark_url`, `wechat_token`, and `notify_always`.
   - If the file doesn't exist or both channel values are empty, tell the user no notification channel is configured and offer to set one up.
   - If `notify_always: false` (the default), only send notifications when the terminal is likely in the background (e.g., after a long task). Skip if the user is actively interacting.
2. If `bark_url` is set, call `bark.sh` using the command format from CLAUDE.md (or the format above).
3. If `wechat_token` is set, call `wechat.sh` using the command format from CLAUDE.md (or the format above).
4. Pick parameters that fit the situation: use `-c` for urgent Bark alerts, use `-d` for detailed WeChat messages.

Good times to send proactively (without being asked):
- Long build/test/deploy finished
- Need user decision on something important
- Code review or PR creation completed
- Build failed or tests not passing

## Platform Notes

- **macOS**: Uses `osascript` for native notifications, `afplay` for audio
- **Linux**: Uses `notify-send` (requires libnotify), `aplay` or `paplay` for audio
