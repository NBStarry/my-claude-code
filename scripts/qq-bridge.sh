#!/bin/bash
# QQ -> Claude Code Message Bridge
# 监听 QQ 私聊消息，通过 tmux send-keys 注入到 Claude Code 终端
# 与 notify-qq.sh（出站通知）形成双向通信

# ─── 配置 ───
QQ_WS="ws://127.0.0.1:3001"
QQ_API="http://localhost:3000"
QQ_USER="794426422"
PID_FILE="${HOME}/.claude/qq-bridge.pid"
LOG_FILE="${HOME}/.claude/qq-bridge.log"
MAX_BACKOFF=60
QQ_BRIDGE_SILENT="${QQ_BRIDGE_SILENT:-0}"

# ─── 日志 ───
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ─── 依赖检查 ───
check_deps() {
    local missing=()
    command -v websocat >/dev/null 2>&1 || missing+=("websocat (brew install websocat)")
    command -v jq >/dev/null 2>&1 || missing+=("jq (brew install jq)")
    command -v tmux >/dev/null 2>&1 || missing+=("tmux (brew install tmux)")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# ─── 自动检测 Claude Code 的 tmux pane ───
find_claude_pane() {
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}' 2>/dev/null \
        | grep -i 'claude' \
        | head -1 \
        | cut -d' ' -f1
}

# ─── 发送 QQ 确认回复 ───
send_qq_reply() {
    [ "$QQ_BRIDGE_SILENT" = "1" ] && return
    curl -s -X POST "${QQ_API}/send_private_msg" \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg text "$1" --argjson uid "$QQ_USER" \
            '{user_id: $uid, message: [{type: "text", data: {text: $text}}]}')" \
        > /dev/null 2>&1 &
}

# ─── 注入文本到 tmux ───
inject_to_tmux() {
    local text="$1"
    local pane
    pane=$(find_claude_pane)

    if [ -z "$pane" ]; then
        log "ERROR: No Claude Code pane found"
        send_qq_reply "[错误] 未找到 Claude Code 终端"
        return 1
    fi

    tmux send-keys -t "$pane" -l "$text"
    tmux send-keys -t "$pane" Enter
    log "Injected to ${pane}: ${text:0:100}"
}

# ─── 处理特殊命令 ───
handle_special() {
    local pane
    case "$1" in
        /cancel|/c)
            pane=$(find_claude_pane)
            if [ -n "$pane" ]; then
                tmux send-keys -t "$pane" C-c
                send_qq_reply "[已发送] Ctrl+C"
            else
                send_qq_reply "[错误] 未找到 Claude Code 终端"
            fi
            return 0 ;;
        /escape|/e)
            pane=$(find_claude_pane)
            if [ -n "$pane" ]; then
                tmux send-keys -t "$pane" Escape
                send_qq_reply "[已发送] Escape"
            else
                send_qq_reply "[错误] 未找到 Claude Code 终端"
            fi
            return 0 ;;
        /enter)
            pane=$(find_claude_pane)
            if [ -n "$pane" ]; then
                tmux send-keys -t "$pane" Enter
                send_qq_reply "[已发送] Enter"
            else
                send_qq_reply "[错误] 未找到 Claude Code 终端"
            fi
            return 0 ;;
        /status)
            pane=$(find_claude_pane)
            if [ -n "$pane" ]; then
                send_qq_reply "[状态] 已连接，目标终端: ${pane}"
            else
                send_qq_reply "[状态] 已连接，但未找到 Claude Code 终端"
            fi
            return 0 ;;
        /help)
            send_qq_reply "[命令列表]
/cancel, /c - 发送 Ctrl+C
/escape, /e - 发送 Escape
/enter - 发送空回车
/status - 查看桥接状态
/help - 显示此帮助
其他文本 - 直接注入终端"
            return 0 ;;
    esac
    return 1
}

# ─── 处理单条 WebSocket 事件 ───
handle_message() {
    local line="$1"
    local post_type msg_type user_id raw_msg

    post_type=$(echo "$line" | jq -r '.post_type // ""' 2>/dev/null)
    [ "$post_type" != "message" ] && return

    msg_type=$(echo "$line" | jq -r '.message_type // ""' 2>/dev/null)
    [ "$msg_type" != "private" ] && return

    user_id=$(echo "$line" | jq -r '.user_id // 0' 2>/dev/null)
    [ "$user_id" != "$QQ_USER" ] && return

    raw_msg=$(echo "$line" | jq -r '.raw_message // ""' 2>/dev/null)
    [ -z "$raw_msg" ] && return

    log "Received from QQ: ${raw_msg:0:200}"

    # 特殊命令
    if handle_special "$raw_msg"; then
        return
    fi

    # 授权选项的友好确认
    local confirm_text="[已发送] ${raw_msg:0:100}"
    case "$raw_msg" in
        1) confirm_text="[已选择] 1. Yes" ;;
        2) confirm_text="[已选择] 2. Yes, don't ask again" ;;
        3) confirm_text="[已选择] 3. No" ;;
    esac

    inject_to_tmux "$raw_msg"
    send_qq_reply "$confirm_text"
}

# ─── WebSocket 监听主循环 ───
listen_loop() {
    local backoff=2

    log "Bridge started (PID $$)"

    while true; do
        log "Connecting to ${QQ_WS}..."
        local got_message=0

        while IFS= read -r line; do
            got_message=1
            handle_message "$line"
        done < <(websocat -t "$QQ_WS" 2>/dev/null)

        # 收到过消息则重置退避
        [ "$got_message" -eq 1 ] && backoff=2

        log "WebSocket disconnected, reconnecting in ${backoff}s..."
        sleep "$backoff"
        backoff=$((backoff * 2))
        [ "$backoff" -gt "$MAX_BACKOFF" ] && backoff=$MAX_BACKOFF
    done
}

# ─── 守护进程管理 ───
cmd_start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Bridge already running (PID $(cat "$PID_FILE"))"
        exit 1
    fi
    check_deps
    echo "Starting QQ bridge daemon..."
    nohup "$0" run >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started (PID $!), log: ${LOG_FILE}"
}

cmd_stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No PID file found, bridge not running"
        exit 1
    fi
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        # 等待进程退出，同时清理子进程
        sleep 1
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
        rm -f "$PID_FILE"
        echo "Stopped bridge (PID ${pid})"
    else
        rm -f "$PID_FILE"
        echo "Bridge was not running (stale PID file removed)"
    fi
}

cmd_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Bridge running (PID $(cat "$PID_FILE"))"
        local pane
        pane=$(find_claude_pane)
        if [ -n "$pane" ]; then
            echo "Claude Code pane: ${pane}"
        else
            echo "Claude Code pane: not found"
        fi
    else
        echo "Bridge not running"
    fi
}

# ─── 入口 ───
case "${1:-}" in
    start)  cmd_start ;;
    stop)   cmd_stop ;;
    status) cmd_status ;;
    run)    check_deps; listen_loop ;;
    *)      echo "Usage: $0 {start|stop|status|run}"; exit 1 ;;
esac
