#!/bin/bash
# Telegram -> Claude Code Message Bridge
# 监听 Telegram 私聊消息，通过 tmux send-keys 注入到 Claude Code 终端
# 与 notify-telegram.sh（出站通知）形成双向通信

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
PID_FILE="${HOME}/.claude/telegram-bridge.pid"
LOG_FILE="${HOME}/.claude/telegram-bridge.log"
OFFSET_FILE="${HOME}/.claude/telegram-bridge.offset"
ACTIVE_PANE_FILE="${HOME}/.claude/telegram-bridge.active-pane"
FULL_CONTENT_FILE="${HOME}/.claude/telegram-bridge.full-content.txt"
POLL_TIMEOUT=30
MAX_LOG_LINES=500
TELEGRAM_BRIDGE_SILENT="${TELEGRAM_BRIDGE_SILENT:-0}"

# 代理设置
CURL_PROXY_ARGS=""
if [ -n "$TELEGRAM_PROXY" ]; then
    CURL_PROXY_ARGS="--proxy ${TELEGRAM_PROXY}"
elif [ -n "$HTTPS_PROXY" ]; then
    CURL_PROXY_ARGS="--proxy ${HTTPS_PROXY}"
fi

# ─── 日志 ───
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ─── 日志轮转 ───
rotate_log() {
    [ ! -f "$LOG_FILE" ] && return
    local lines
    lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$lines" -gt "$MAX_LOG_LINES" ]; then
        tail -200 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log "Log rotated (was ${lines} lines)"
    fi
}

# ─── 依赖检查 ───
check_deps() {
    local missing=()
    command -v jq >/dev/null 2>&1 || missing+=("jq (brew install jq)")
    command -v tmux >/dev/null 2>&1 || missing+=("tmux (brew install tmux)")
    command -v curl >/dev/null 2>&1 || missing+=("curl")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# ─── 发送 Telegram 确认回复 ───
send_telegram_reply() {
    [ "$TELEGRAM_BRIDGE_SILENT" = "1" ] && return
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
        $CURL_PROXY_ARGS \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg text "$1" --arg chat_id "$TELEGRAM_CHAT_ID" \
            '{chat_id: $chat_id, text: $text}')" \
        > /dev/null 2>&1 &
}

# ─── 发送 Telegram 文件 ───
send_telegram_file() {
    local file="$1"
    local caption="${2:-}"
    [ ! -f "$file" ] && return 1
    curl -s -X POST "${TELEGRAM_API}/sendDocument" \
        $CURL_PROXY_ARGS \
        -F "chat_id=${TELEGRAM_CHAT_ID}" \
        -F "document=@${file}" \
        -F "caption=${caption}" \
        > /dev/null 2>&1 &
}

# ─── 列出所有 Claude Code 的 tmux pane ───
# 通过 pane_title 检测（Claude Code 设置标题含 "Claude"）
# 输出格式: pane_id path (每行一条)
list_claude_panes() {
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_title}|#{pane_current_path}' 2>/dev/null \
        | grep -i 'claude' \
        | while IFS='|' read -r pane_id title path; do
            echo "$pane_id $path"
        done
}

# ─── 获取活跃 pane（核心路由） ───
# 返回码: 0=成功(pane_id via stdout), 1=无pane, 2=需用户选择
get_active_pane() {
    # 1. 检查状态文件中保存的 pane
    if [ -f "$ACTIVE_PANE_FILE" ]; then
        local saved_pane
        saved_pane=$(cat "$ACTIVE_PANE_FILE" 2>/dev/null)
        if [ -n "$saved_pane" ] && list_claude_panes | grep -q "^${saved_pane} "; then
            echo "$saved_pane"
            return 0
        fi
        # pane 已失效 — 尝试自动切换
        local old_session="${saved_pane%%:*}"
        rm -f "$ACTIVE_PANE_FILE"
        local panes
        panes=$(list_claude_panes)
        local count
        count=$(echo "$panes" | grep -c '.' 2>/dev/null || echo 0)
        if [ "$count" -ge 1 ]; then
            local new_pane new_session new_path
            new_pane=$(echo "$panes" | head -1 | awk '{print $1}')
            new_session="${new_pane%%:*}"
            new_path=$(echo "$panes" | head -1 | awk '{print $2}')
            echo "$new_pane" > "$ACTIVE_PANE_FILE"
            send_telegram_reply "[自动切换] ${old_session} 已断开
当前连接: ${new_session} (${new_pane})
工作目录: ${new_path}
发送 /list 查看所有终端"
            log "Auto-switched from ${old_session} to ${new_session} (${new_pane})"
            echo "$new_pane"
            return 0
        fi
        return 1
    fi

    # 2. 无状态文件 — 自动检测
    local panes
    panes=$(list_claude_panes)
    local count
    count=$(echo "$panes" | grep -c '.' 2>/dev/null || echo 0)

    if [ "$count" -eq 0 ]; then
        return 1
    elif [ "$count" -eq 1 ]; then
        local pane_id
        pane_id=$(echo "$panes" | awk '{print $1}')
        echo "$pane_id" > "$ACTIVE_PANE_FILE"
        echo "$pane_id"
        return 0
    else
        return 2
    fi
}

# ─── 格式化 pane 列表消息 ───
format_pane_list() {
    local panes active_pane
    panes=$(list_claude_panes)
    active_pane=""
    [ -f "$ACTIVE_PANE_FILE" ] && active_pane=$(cat "$ACTIVE_PANE_FILE" 2>/dev/null)

    local count
    count=$(echo "$panes" | grep -c '.' 2>/dev/null || echo 0)

    if [ "$count" -eq 0 ]; then
        echo "[会话列表] 未找到 Claude Code 终端"
        return
    fi

    local msg="[会话列表] 找到 ${count} 个 Claude Code 终端
"
    while IFS= read -r line; do
        local pane_id pane_path session_name dir_name marker
        pane_id=$(echo "$line" | awk '{print $1}')
        pane_path=$(echo "$line" | awk '{print $2}')
        session_name="${pane_id%%:*}"
        dir_name=$(basename "$pane_path" 2>/dev/null)
        if [ "$pane_id" = "$active_pane" ]; then
            marker="★"
        else
            marker=" "
        fi
        msg="${msg}
${marker} ${session_name}  ${pane_id}  ${dir_name}"
    done <<< "$panes"

    msg="${msg}

发送 /connect <session名> 切换目标"
    echo "$msg"
}

# ─── 注入文本到 tmux ───
inject_to_tmux() {
    local text="$1"
    local pane
    pane=$(get_active_pane)
    local ret=$?

    if [ $ret -eq 1 ]; then
        log "ERROR: No Claude Code pane found"
        send_telegram_reply "[错误] 未找到 Claude Code 终端"
        return 1
    elif [ $ret -eq 2 ]; then
        log "Multiple panes found, user must select"
        send_telegram_reply "$(format_pane_list)"
        return 1
    fi

    tmux send-keys -t "$pane" -l "$text"
    tmux send-keys -t "$pane" Enter
    log "Injected to ${pane}: ${text:0:100}"
}

# ─── 获取活跃 pane 并处理错误（用于特殊命令） ───
# 成功时设置 _pane 变量，失败时发送错误消息并返回 1
resolve_pane() {
    _pane=$(get_active_pane)
    local ret=$?
    if [ $ret -eq 1 ]; then
        send_telegram_reply "[错误] 未找到 Claude Code 终端"
        return 1
    elif [ $ret -eq 2 ]; then
        send_telegram_reply "$(format_pane_list)"
        return 1
    fi
    return 0
}

# ─── 处理特殊命令 ───
handle_special() {
    case "$1" in
        /cancel|/c)
            resolve_pane || return 0
            tmux send-keys -t "$_pane" C-c
            send_telegram_reply "[已发送] Ctrl+C"
            return 0 ;;
        /escape|/e)
            resolve_pane || return 0
            tmux send-keys -t "$_pane" Escape
            send_telegram_reply "[已发送] Escape"
            return 0 ;;
        /enter)
            resolve_pane || return 0
            tmux send-keys -t "$_pane" Enter
            send_telegram_reply "[已发送] Enter"
            return 0 ;;
        /list|/l)
            send_telegram_reply "$(format_pane_list)"
            return 0 ;;
        /connect\ *|/connect)
            local target_session="${1#/connect}"
            target_session="${target_session# }"
            if [ -z "$target_session" ]; then
                send_telegram_reply "[用法] /connect <session名>
发送 /list 查看可用终端"
                return 0
            fi
            local match match_path
            match=$(list_claude_panes | grep "^${target_session}:" | head -1 | awk '{print $1}')
            if [ -n "$match" ]; then
                match_path=$(list_claude_panes | grep "^${match} " | awk '{print $2}')
                echo "$match" > "$ACTIVE_PANE_FILE"
                send_telegram_reply "[已切换] 当前连接: ${target_session} (${match})
工作目录: ${match_path}"
                log "Switched to ${target_session} (${match})"
            else
                send_telegram_reply "[错误] 未找到 session: ${target_session}
发送 /list 查看可用终端"
            fi
            return 0 ;;
        /status)
            local bridge_status="未知"
            if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
                bridge_status="运行中 (PID $(cat "$PID_FILE"))"
            else
                bridge_status="未运行"
            fi
            local bot_status="未知"
            local bot_info
            bot_info=$(curl -s --max-time 5 $CURL_PROXY_ARGS "${TELEGRAM_API}/getMe" 2>/dev/null)
            if echo "$bot_info" | jq -e '.ok' >/dev/null 2>&1; then
                local bot_name
                bot_name=$(echo "$bot_info" | jq -r '.result.username // "unknown"')
                bot_status="在线 (@${bot_name})"
            else
                bot_status="离线"
            fi
            local active_pane active_session pane_count
            active_pane=$(get_active_pane 2>/dev/null)
            active_session="${active_pane%%:*}"
            pane_count=$(list_claude_panes | grep -c '.' 2>/dev/null || echo 0)
            local pane_info
            if [ -n "$active_pane" ]; then
                pane_info="当前连接: ${active_session} (${active_pane})"
            else
                pane_info="当前连接: 无"
            fi
            send_telegram_reply "[状态] Bridge: ${bridge_status}
Bot: ${bot_status}
${pane_info}
终端数量: ${pane_count}"
            return 0 ;;
        /help)
            send_telegram_reply "[命令列表]
/list, /l - 列出所有终端
/connect <session> - 切换目标终端
/cancel, /c - 发送 Ctrl+C
/escape, /e - 发送 Escape
/enter - 发送空回车
/status - 查看桥接状态
/restart - 重启 bridge
/log - 查看最近日志
/pane - 截取终端内容
/full - 发送完整终端内容（文件）
/help - 显示此帮助
其他文本 - 直接注入终端"
            return 0 ;;
        /restart)
            send_telegram_reply "[重启中] Bridge 正在重启..."
            log "Restart requested via Telegram"
            sleep 1
            exec "$0" run
            ;;
        /log)
            local recent
            recent=$(tail -10 "$LOG_FILE" 2>/dev/null || echo "无日志")
            send_telegram_reply "[最近日志]
${recent}"
            return 0 ;;
        /pane)
            resolve_pane || return 0
            local raw_content display_content
            raw_content=$(tmux capture-pane -t "$_pane" -p -S - 2>/dev/null)
            if [ -z "$raw_content" ]; then
                send_telegram_reply "[终端内容] ${_pane}: (空)"
                return 0
            fi
            # 保存完整内容到文件
            echo "$raw_content" > "$FULL_CONTENT_FILE"
            # 手机友好版：去装饰线 + 截断行宽 + 取最后 20 行
            display_content=$(echo "$raw_content" \
                | grep -v '^[─━═─-]\{10,\}$' \
                | sed 's/[[:space:]]*$//' \
                | grep -v '^$' \
                | cut -c1-60 \
                | tail -20)
            local hint=""
            local raw_lines
            raw_lines=$(echo "$raw_content" | wc -l | tr -d ' ')
            [ "$raw_lines" -gt 20 ] && hint="
发送 /full 查看完整内容 (${raw_lines} 行)"
            send_telegram_reply "[终端内容] ${_pane}
${display_content:0:2000}${hint}"
            return 0 ;;
        /full)
            if [ -f "$FULL_CONTENT_FILE" ]; then
                send_telegram_file "$FULL_CONTENT_FILE" "[完整内容]"
            else
                send_telegram_reply "[错误] 无缓存内容"
            fi
            return 0 ;;
    esac
    return 1
}

# ─── 处理单条 Telegram update ───
handle_update() {
    local update="$1"
    local chat_id text

    # 提取消息字段
    chat_id=$(echo "$update" | jq -r '.message.chat.id // ""' 2>/dev/null)
    [ -z "$chat_id" ] && return

    # 仅处理目标用户的消息
    [ "$chat_id" != "$TELEGRAM_CHAT_ID" ] && return

    text=$(echo "$update" | jq -r '.message.text // ""' 2>/dev/null)
    [ -z "$text" ] && return

    log "Received from Telegram: ${text:0:200}"

    # 特殊命令
    if handle_special "$text"; then
        return
    fi

    # 授权选项：用方向键导航（Claude Code 权限对话框是交互式列表选择器）
    case "$text" in
        1)
            resolve_pane && {
                tmux send-keys -t "$_pane" Enter
                send_telegram_reply "[已选择] 1. Yes"
            }
            return ;;
        2)
            resolve_pane && {
                tmux send-keys -t "$_pane" Down
                tmux send-keys -t "$_pane" Enter
                send_telegram_reply "[已选择] 2. Yes, don't ask again"
            }
            return ;;
        3)
            resolve_pane && {
                tmux send-keys -t "$_pane" Down
                tmux send-keys -t "$_pane" Down
                tmux send-keys -t "$_pane" Enter
                send_telegram_reply "[已选择] 3. No"
            }
            return ;;
    esac

    inject_to_tmux "$text"
    send_telegram_reply "[已发送] ${text:0:100}"
}

# ─── 长轮询主循环 ───
poll_loop() {
    log "Bridge started (PID $$)"

    trap 'log "Bridge shutting down"; exit 0' EXIT TERM INT

    # 读取上次处理的 offset
    local offset=0
    if [ -f "$OFFSET_FILE" ]; then
        offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
    fi

    local backoff=2
    local first_connect=1
    local MAX_BACKOFF=60

    while true; do
        rotate_log

        # 长轮询请求
        local response
        response=$(curl -s --max-time $((POLL_TIMEOUT + 10)) \
            $CURL_PROXY_ARGS \
            "${TELEGRAM_API}/getUpdates?offset=${offset}&timeout=${POLL_TIMEOUT}" \
            2>/dev/null)

        # 检查请求是否成功
        if [ -z "$response" ]; then
            log "Empty response from Telegram API, retrying in ${backoff}s..."
            sleep "$backoff"
            backoff=$((backoff * 2))
            [ "$backoff" -gt "$MAX_BACKOFF" ] && backoff=$MAX_BACKOFF
            continue
        fi

        local ok
        ok=$(echo "$response" | jq -r '.ok // false' 2>/dev/null)
        if [ "$ok" != "true" ]; then
            local error_desc
            error_desc=$(echo "$response" | jq -r '.description // "unknown error"' 2>/dev/null)
            log "API error: ${error_desc}, retrying in ${backoff}s..."
            sleep "$backoff"
            backoff=$((backoff * 2))
            [ "$backoff" -gt "$MAX_BACKOFF" ] && backoff=$MAX_BACKOFF
            continue
        fi

        # 首次连接成功通知
        if [ "$first_connect" -eq 1 ]; then
            send_telegram_reply "[Bridge] 已启动"
            first_connect=0
        elif [ "$backoff" -gt 2 ]; then
            send_telegram_reply "[Bridge] 已重新连接"
        fi

        # 重置退避
        backoff=2

        # 处理所有 update
        local update_count
        update_count=$(echo "$response" | jq '.result | length' 2>/dev/null)

        if [ "$update_count" -gt 0 ]; then
            local i=0
            while [ "$i" -lt "$update_count" ]; do
                local update
                update=$(echo "$response" | jq ".result[$i]" 2>/dev/null)

                # 提取 update_id 并更新 offset
                local update_id
                update_id=$(echo "$update" | jq -r '.update_id // 0' 2>/dev/null)
                if [ "$update_id" -gt 0 ]; then
                    offset=$((update_id + 1))
                    echo "$offset" > "$OFFSET_FILE"
                fi

                handle_update "$update"
                i=$((i + 1))
            done
        fi
    done
}

# ─── 守护进程管理 ───
cmd_start() {
    # 清理残留 PID 文件
    if [ -f "$PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null)
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "Bridge already running (PID ${old_pid})"
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    check_deps
    echo "Starting Telegram bridge daemon..."
    nohup "$0" run >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started (PID $!), log: ${LOG_FILE}"
}

cmd_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No PID file found, bridge not running"
        return 0
    fi
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        # 先发 TERM，让 trap 清理
        kill "$pid" 2>/dev/null
        # 等待进程退出
        local waited=0
        while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
            sleep 1
            waited=$((waited + 1))
        done
        # 如果还没退出，强制杀死
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
        echo "Stopped bridge (PID ${pid})"
    else
        rm -f "$PID_FILE"
        echo "Bridge was not running (stale PID file removed)"
    fi
}

cmd_restart() {
    echo "Restarting bridge..."
    cmd_stop
    sleep 1
    cmd_start
}

cmd_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
        echo "Bridge running (PID $(cat "$PID_FILE"))"
        local panes pane_count active_pane
        panes=$(list_claude_panes)
        pane_count=$(echo "$panes" | grep -c '.' 2>/dev/null || echo 0)
        echo "Claude Code panes: ${pane_count}"
        if [ "$pane_count" -gt 0 ]; then
            active_pane=""
            [ -f "$ACTIVE_PANE_FILE" ] && active_pane=$(cat "$ACTIVE_PANE_FILE" 2>/dev/null)
            while IFS= read -r line; do
                local pid ppath session_name marker
                pid=$(echo "$line" | awk '{print $1}')
                ppath=$(echo "$line" | awk '{print $2}')
                session_name="${pid%%:*}"
                if [ "$pid" = "$active_pane" ]; then marker="★"; else marker=" "; fi
                echo "  ${marker} ${session_name}  ${pid}  $(basename "$ppath" 2>/dev/null)"
            done <<< "$panes"
        fi
        local bot_info
        bot_info=$(curl -s --max-time 5 $CURL_PROXY_ARGS "${TELEGRAM_API}/getMe" 2>/dev/null)
        if echo "$bot_info" | jq -e '.ok' >/dev/null 2>&1; then
            local bot_name
            bot_name=$(echo "$bot_info" | jq -r '.result.username // "unknown"')
            echo "Telegram Bot: online (@${bot_name})"
        else
            echo "Telegram Bot: offline or unreachable"
        fi
    else
        echo "Bridge not running"
        [ -f "$PID_FILE" ] && rm -f "$PID_FILE" && echo "(stale PID file removed)"
    fi
}

cmd_ensure() {
    # 幂等启动：已运行则跳过（快速路径 ~5ms）
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
        return 0
    fi
    # 清理残留并启动
    rm -f "$PID_FILE"
    check_deps 2>/dev/null || return 0
    nohup "$0" run >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
}

# ─── 入口 ───
case "${1:-}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_restart ;;
    status)  cmd_status ;;
    ensure)  cmd_ensure ;;
    run)     check_deps; poll_loop ;;
    *)       echo "Usage: $0 {start|stop|restart|status|ensure|run}"; exit 1 ;;
esac
