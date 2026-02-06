#!/bin/bash
# Claude Code QQ Notification Script
# 通过 LLOneBot (OneBot 11 HTTP API) 发送 QQ 私聊通知
# 从 stdin 读取 Claude Code hook JSON 输入，解析工具调用详情
#
# 安装:
#   cp notify-qq.sh ~/.claude/notify-qq.sh
#   chmod +x ~/.claude/notify-qq.sh
#
# 前提条件:
#   1. 安装 LiteLoaderQQNT + LLOneBot 插件
#   2. LLOneBot 启用 HTTP API (默认端口 3000)
#   3. 桌面 QQ 登录机器人号（发送方），手机登录主号（接收方）
#   4. 修改下方 QQ_USER 为接收通知的 QQ 号
#
# 使用方式 (在 hooks 中配置):
#   bash ~/.claude/notify-qq.sh permission_prompt
#   bash ~/.claude/notify-qq.sh idle_prompt
#   bash ~/.claude/notify-qq.sh stop

# ─── 配置（请根据自己的情况修改） ───
QQ_API="http://localhost:3000"
QQ_USER="YOUR_QQ_NUMBER"  # 接收通知的 QQ 号
HOOK_TYPE="${1:-unknown}"  # permission_prompt / idle_prompt / stop

# 日志
LOG_FILE="${HOME}/.claude/notify-qq.log"
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Hook triggered: ${HOOK_TYPE}"

# 读取 stdin JSON
INPUT=$(cat)
log "Input: $INPUT"

# 解析基本字段
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)

# 简化工作目录
SHORT_CWD=$(echo "$CWD" | sed "s|${HOME}/||")

# ─── 根据 hook 类型构建消息 ───

if [ "$HOOK_TYPE" = "stop" ]; then
    # Stop hook: 任务完成通知
    NOTIFICATION_TEXT="✅ 任务已完成

📁 工作目录: ${SHORT_CWD}
⏰ 时间: $(date +'%H:%M:%S')"

elif [ "$HOOK_TYPE" = "idle_prompt" ]; then
    # Idle hook: 等待输入
    NOTIFICATION_TEXT="💬 Claude 正在等待你的输入

📁 工作目录: ${SHORT_CWD}
⏰ 时间: $(date +'%H:%M:%S')"

elif [ "$HOOK_TYPE" = "permission_prompt" ]; then
    # Permission hook: 授权请求，解析工具调用详情

    TOOL_NAME=""
    TOOL_DETAILS=""

    # 从 transcript 提取工具调用信息
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        TOOL_INFO=$(tac "$TRANSCRIPT_PATH" 2>/dev/null | head -20 | while read -r line; do
            TYPE=$(echo "$line" | jq -r '.type // ""' 2>/dev/null)
            if [ "$TYPE" = "assistant" ]; then
                TOOL_CALL=$(echo "$line" | jq -r '
                    .message.content[]? | select(.type == "tool_use") |
                    {name: .name, input: .input} | @json
                ' 2>/dev/null | head -1)
                if [ -n "$TOOL_CALL" ]; then
                    echo "$TOOL_CALL"
                    break
                fi
            fi
        done)

        if [ -n "$TOOL_INFO" ]; then
            TOOL_NAME=$(echo "$TOOL_INFO" | jq -r '.name // empty')
            case "$TOOL_NAME" in
                Bash)
                    TOOL_DETAILS="Bash: $(echo "$TOOL_INFO" | jq -r '.input.command // empty')"
                    ;;
                WebSearch)
                    TOOL_DETAILS="Web Search: \"$(echo "$TOOL_INFO" | jq -r '.input.query // empty')\""
                    ;;
                WebFetch)
                    TOOL_DETAILS="Web Fetch: $(echo "$TOOL_INFO" | jq -r '.input.url // empty')"
                    ;;
                Read)
                    TOOL_DETAILS="Read: $(echo "$TOOL_INFO" | jq -r '.input.file_path // empty')"
                    ;;
                Write|Edit)
                    TOOL_DETAILS="${TOOL_NAME}: $(echo "$TOOL_INFO" | jq -r '.input.file_path // empty')"
                    ;;
                Grep)
                    TOOL_DETAILS="Grep: \"$(echo "$TOOL_INFO" | jq -r '.input.pattern // empty')\""
                    ;;
                Glob)
                    TOOL_DETAILS="Glob: \"$(echo "$TOOL_INFO" | jq -r '.input.pattern // empty')\""
                    ;;
                Task)
                    TOOL_DETAILS="Task: $(echo "$TOOL_INFO" | jq -r '.input.description // empty')"
                    ;;
                *)
                    FIRST_PARAM=$(echo "$TOOL_INFO" | jq -r '.input | to_entries[0].value // empty' 2>/dev/null)
                    if [ -n "$FIRST_PARAM" ]; then
                        TOOL_DETAILS="${TOOL_NAME}: ${FIRST_PARAM:0:100}"
                    else
                        TOOL_DETAILS="${TOOL_NAME}"
                    fi
                    ;;
            esac
        fi
    fi

    # 回退到 message 字段解析
    if [ -z "$TOOL_DETAILS" ] && [ -n "$MESSAGE" ]; then
        TOOL_DETAILS="$MESSAGE"
    fi

    # 提取用户请求
    USER_MSG=""
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        USER_MSG=$(grep '"type":"user"' "$TRANSCRIPT_PATH" \
            | grep -v "━━━" \
            | grep -v "Claude Code" \
            | tail -1 \
            | jq -r '.message.content // empty' 2>/dev/null)
        [ -n "$USER_MSG" ] && USER_MSG="${USER_MSG:0:300}"
    fi

    # 构建授权通知
    NOTIFICATION_TEXT="🔐 需要授权

${TOOL_DETAILS}"

    [ -n "$USER_MSG" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

📝 用户请求:
${USER_MSG}"

    NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

━━━ 授权选项 ━━━
❯ 1. Yes
  2. Yes, don't ask again for ${SHORT_CWD}
  3. No

📁 工作目录: ${SHORT_CWD}
⏰ 时间: $(date +'%H:%M:%S')"

else
    # 未知类型，直接转发消息
    NOTIFICATION_TEXT="[Claude Code] ${MESSAGE:-通知}

📁 ${SHORT_CWD}
⏰ $(date +'%H:%M:%S')"
fi

log "Sending: ${NOTIFICATION_TEXT:0:200}..."

# 发送 QQ 消息（后台，不阻塞 hook）
curl -s -X POST "${QQ_API}/send_private_msg" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg text "$NOTIFICATION_TEXT" --argjson uid "$QQ_USER" \
    '{user_id: $uid, message: [{type: "text", data: {text: $text}}]}')" \
  > /dev/null 2>&1 &

exit 0
