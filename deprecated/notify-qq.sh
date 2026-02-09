#!/bin/bash
# Claude Code QQ Notification Script
# 通过 LLOneBot (OneBot 11 HTTP API) 发送 QQ 私聊通知
# 从 stdin 读取 Claude Code hook JSON 输入，解析工具调用详情

# 配置
QQ_API="http://localhost:3000"
QQ_USER="794426422"
HOOK_TYPE="${1:-unknown}"  # permission_prompt / idle_prompt / stop

# 日志
LOG_FILE="${HOME}/.claude/notify-qq.log"
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 从父进程链提取 agent 名称（team 模式）
get_agent_name() {
    local pid=$PPID
    local depth=0
    # 向上遍历进程链，最多 10 层
    while [ -n "$pid" ] && [ "$pid" -ne 1 ] && [ "$depth" -lt 10 ]; do
        local cmdline=$(ps -p "$pid" -o command= 2>/dev/null)
        # 检查是否包含 --agent-name 参数
        if echo "$cmdline" | grep -q -- '--agent-name'; then
            # 提取 agent 名称
            echo "$cmdline" | awk '{
                for (i=1; i<=NF; i++) {
                    if ($i == "--agent-name" && i < NF) {
                        print $(i+1)
                        exit
                    }
                }
            }'
            return 0
        fi
        # 获取父进程 PID
        pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
        depth=$((depth + 1))
    done
    return 1
}

log "Hook triggered: ${HOOK_TYPE}"

# 读取 stdin JSON
INPUT=$(cat)
log "Input: $INPUT"

# 解析基本字段
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)

# 提取项目名（CWD 最后一级目录）
PROJECT=$(basename "$CWD" 2>/dev/null)

# 检测 agent 名称（team 模式）
AGENT_NAME=$(get_agent_name)
AGENT_INFO=""
if [ -n "$AGENT_NAME" ]; then
    AGENT_INFO=" (${AGENT_NAME})"
fi

# 从 transcript 计算上下文使用百分比
CTX_INFO=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    USAGE=$(tail -r "$TRANSCRIPT_PATH" 2>/dev/null | while read -r line; do
        INPUT_TOKENS=$(echo "$line" | jq -r '.message.usage.input_tokens // empty' 2>/dev/null)
        if [ -n "$INPUT_TOKENS" ] && [ "$INPUT_TOKENS" != "0" ]; then
            CACHE_READ=$(echo "$line" | jq -r '.message.usage.cache_read_input_tokens // 0' 2>/dev/null)
            echo "$((INPUT_TOKENS + CACHE_READ))"
            break
        fi
    done)
    if [ -n "$USAGE" ] && [ "$USAGE" -gt 0 ] 2>/dev/null; then
        CTX_PCT=$((USAGE * 100 / 200000))
        CTX_INFO=" [ctx:${CTX_PCT}%]"
    fi
fi

# 提取最近的用户请求作为上下文（仅纯文本消息，跳过 tool_result）
CONTEXT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    CONTEXT=$(grep '"type":"user"' "$TRANSCRIPT_PATH" \
        | jq -rs '[.[] | select(.message.content | type == "string") | .message.content] | last // empty' 2>/dev/null)
    # 只取第一行，去掉粘贴的长内容
    CONTEXT=$(echo "$CONTEXT" | head -1)
    [ -n "$CONTEXT" ] && CONTEXT="${CONTEXT:0:200}"
fi

# 提取 Claude 最后的回复（仅文本部分）
REPLY=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    REPLY=$(tail -r "$TRANSCRIPT_PATH" 2>/dev/null | while read -r line; do
        TYPE=$(echo "$line" | jq -r '.type // ""' 2>/dev/null)
        if [ "$TYPE" = "assistant" ]; then
            TEXT=$(echo "$line" | jq -r '
                [.message.content[]? | select(.type == "text") | .text] | join("\n")
            ' 2>/dev/null)
            if [ -n "$TEXT" ]; then
                echo "$TEXT"
                break
            fi
        fi
    done)
    [ -n "$REPLY" ] && REPLY="${REPLY:0:300}"
fi

# ─── 根据 hook 类型构建消息 ───

if [ "$HOOK_TYPE" = "stop" ]; then
    NOTIFICATION_TEXT="[任务完成] ${PROJECT}${CTX_INFO}${AGENT_INFO}"

    [ -n "$REPLY" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

[回复] ${REPLY}"

    [ -n "$CONTEXT" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

[上下文] ${CONTEXT}"

elif [ "$HOOK_TYPE" = "idle_prompt" ]; then
    NOTIFICATION_TEXT="[等待输入] ${PROJECT}${CTX_INFO}${AGENT_INFO}"

    [ -n "$REPLY" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

[回复] ${REPLY}"

    [ -n "$CONTEXT" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

[上下文] ${CONTEXT}"

elif [ "$HOOK_TYPE" = "permission_prompt" ]; then
    # Permission hook: 授权请求，解析工具调用详情

    TOOL_NAME=""
    TOOL_DETAILS=""

    # 从 transcript 提取工具调用信息
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        TOOL_INFO=$(tail -r "$TRANSCRIPT_PATH" 2>/dev/null | head -20 | while read -r line; do
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

    NOTIFICATION_TEXT="[需要授权] ${PROJECT}${CTX_INFO}${AGENT_INFO}

${TOOL_DETAILS}"

    [ -n "$CONTEXT" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

[上下文] ${CONTEXT}"

    NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

━━━ 授权选项 ━━━
❯ 1. Yes
  2. Yes, don't ask again
  3. No"

else
    NOTIFICATION_TEXT="[通知] ${PROJECT}${CTX_INFO}${AGENT_INFO}
${MESSAGE:-Claude Code 通知}"
fi

log "Sending: ${NOTIFICATION_TEXT:0:200}..."

# 发送 QQ 消息（后台，不阻塞 hook）
curl -s -X POST "${QQ_API}/send_private_msg" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg text "$NOTIFICATION_TEXT" --argjson uid "$QQ_USER" \
    '{user_id: $uid, message: [{type: "text", data: {text: $text}}]}')" \
  > /dev/null 2>&1 &

exit 0
