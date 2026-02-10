#!/bin/bash
# Claude Code Telegram Notification Script
# 通过 Telegram Bot API 发送通知到 Telegram 私聊
# 从 stdin 读取 Claude Code hook JSON 输入，解析工具调用详情

# ─── 配置 ───
CONF_FILE="${HOME}/.claude/telegram.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "Config not found: ${CONF_FILE}" >&2
    exit 1
fi
source "$CONF_FILE"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ "$TELEGRAM_BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ]; then
    echo "TELEGRAM_BOT_TOKEN not configured in ${CONF_FILE}" >&2
    exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ] || [ "$TELEGRAM_CHAT_ID" = "YOUR_CHAT_ID_HERE" ]; then
    echo "TELEGRAM_CHAT_ID not configured in ${CONF_FILE}" >&2
    exit 1
fi

TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
HOOK_TYPE="${1:-unknown}"  # permission_prompt / idle_prompt / stop

# 代理设置
CURL_PROXY_ARGS=""
if [ -n "$TELEGRAM_PROXY" ]; then
    CURL_PROXY_ARGS="--proxy ${TELEGRAM_PROXY}"
elif [ -n "$HTTPS_PROXY" ]; then
    CURL_PROXY_ARGS="--proxy ${HTTPS_PROXY}"
fi

# 日志
LOG_FILE="${HOME}/.claude/notify-telegram.log"
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
# 使用 jq -sr 直接处理 JSONL，避免 bash while-read 对超长行截断
REPLY=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    REPLY=$(tail -20 "$TRANSCRIPT_PATH" 2>/dev/null | jq -sr '
        [.[] | select(.type == "assistant")] | last |
        [.message.content[]? | select(.type == "text") | .text] | join("\n") // ""
    ' 2>/dev/null)
fi

FULL_CONTENT_FILE="${HOME}/.claude/telegram-bridge.full-content.txt"

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

    # 从 transcript 提取工具调用信息（jq -sr 避免大行截断）
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        TOOL_INFO=$(tail -20 "$TRANSCRIPT_PATH" 2>/dev/null | jq -sr '
            [.[] | select(.type == "assistant")] | last |
            [.message.content[]? | select(.type == "tool_use") | {name: .name, input: .input}] |
            last // empty | @json
        ' 2>/dev/null)

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

    # 从终端截取实际授权选项（动态，非硬编码）
    PERM_OPTIONS=""
    PERM_PANE=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_title}|#{pane_current_path}' 2>/dev/null \
        | grep -i 'claude' | grep "|${CWD}$" | head -1 | cut -d'|' -f1)
    if [ -n "$PERM_PANE" ]; then
        # 只提取权限对话框范围内的选项（Do you want to proceed ~ Esc to cancel）
        PERM_OPTIONS=$(tmux capture-pane -t "$PERM_PANE" -p 2>/dev/null \
            | sed -n '/Do you want to proceed/,/Esc to cancel/p' \
            | grep -E '^\s*(❯\s+)?[0-9]+\.' \
            | sed 's/^\s*❯\s*/❯ /; s/^\s*/  /' \
            | head -5)
    fi
    if [ -n "$PERM_OPTIONS" ]; then
        NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

━━━ 授权选项 ━━━
${PERM_OPTIONS}"
    else
        # 回退：无法截取时使用默认选项
        NOTIFICATION_TEXT="${NOTIFICATION_TEXT}

━━━ 授权选项 ━━━
❯ 1. Yes
  2. Yes, don't ask again
  3. No"
    fi

else
    NOTIFICATION_TEXT="[通知] ${PROJECT}${CTX_INFO}${AGENT_INFO}
${MESSAGE:-Claude Code 通知}"
fi

# 多终端时附加 /connect 切换提示
CONNECT_HINT=""
PANE_COUNT=$(tmux list-panes -a -F '#{pane_title}' 2>/dev/null | grep -ic 'claude' || echo 0)
if [ "$PANE_COUNT" -gt 1 ]; then
    CURRENT_SESSION=$(tmux list-panes -a -F '#{session_name} #{pane_current_path}' 2>/dev/null \
        | grep "$CWD" | head -1 | awk '{print $1}')
    [ -n "$CURRENT_SESSION" ] && CONNECT_HINT="
/connect ${CURRENT_SESSION} 切换到此项目"
fi
[ -n "$CONNECT_HINT" ] && NOTIFICATION_TEXT="${NOTIFICATION_TEXT}${CONNECT_HINT}"

log "Sending: ${NOTIFICATION_TEXT:0:200}..."

# 保存完整内容供 /full 使用
printf '%s\n' "$NOTIFICATION_TEXT" > "$FULL_CONTENT_FILE"

# 权限请求时追加完整工具调用详情（代码修改、写入内容等）
if [ "$HOOK_TYPE" = "permission_prompt" ] && [ -n "$TOOL_INFO" ]; then
    {
        echo ""
        echo "━━━ 完整工具调用详情 ━━━"
        case "$TOOL_NAME" in
            Edit)
                echo "文件: $(echo "$TOOL_INFO" | jq -r '.input.file_path // ""')"
                echo ""
                echo "--- 原内容 ---"
                echo "$TOOL_INFO" | jq -r '.input.old_string // ""'
                echo ""
                echo "+++ 新内容 +++"
                echo "$TOOL_INFO" | jq -r '.input.new_string // ""'
                ;;
            Write)
                echo "文件: $(echo "$TOOL_INFO" | jq -r '.input.file_path // ""')"
                echo ""
                echo "--- 写入内容 ---"
                echo "$TOOL_INFO" | jq -r '.input.content // ""'
                ;;
            Bash)
                echo "命令:"
                echo "$TOOL_INFO" | jq -r '.input.command // ""'
                ;;
            *)
                echo "$TOOL_INFO" | jq '.' 2>/dev/null
                ;;
        esac
    } >> "$FULL_CONTENT_FILE"
fi

if [ ${#NOTIFICATION_TEXT} -le 4096 ]; then
    # 未超限：直接发送文本消息
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
        $CURL_PROXY_ARGS \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg text "$NOTIFICATION_TEXT" --arg chat_id "$TELEGRAM_CHAT_ID" \
            '{chat_id: $chat_id, text: $text}')" \
        > /dev/null 2>&1 &
else
    # 超限：发送摘要文本 + 自动发送完整内容文件
    # 摘要：标题行 + 截断提示
    SUMMARY=$(echo "$NOTIFICATION_TEXT" | head -1)
    SUMMARY="${SUMMARY}

(完整内容见附件)"
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
        $CURL_PROXY_ARGS \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg text "$SUMMARY" --arg chat_id "$TELEGRAM_CHAT_ID" \
            '{chat_id: $chat_id, text: $text}')" \
        > /dev/null 2>&1
    # 自动发送完整内容文件
    curl -s -X POST "${TELEGRAM_API}/sendDocument" \
        $CURL_PROXY_ARGS \
        -F "chat_id=${TELEGRAM_CHAT_ID}" \
        -F "document=@${FULL_CONTENT_FILE};filename=notification.txt" \
        > /dev/null 2>&1 &
fi

exit 0
