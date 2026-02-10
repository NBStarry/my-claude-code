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
FIFO_FILE="${HOME}/.claude/qq-bridge.fifo"
STDIN_FIFO="${HOME}/.claude/qq-bridge-stdin.fifo"
MAX_BACKOFF=60
MAX_LOG_LINES=500
QQ_BRIDGE_SILENT="${QQ_BRIDGE_SILENT:-0}"

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

# ─── 等待 LLOneBot 上线 ───
wait_for_llonebot() {
    local qq_launched=0
    while ! lsof -i :3001 -sTCP:LISTEN >/dev/null 2>&1; do
        # QQ 未运行时尝试自动启动
        if [ "$qq_launched" -eq 0 ] && ! pgrep -x QQ >/dev/null 2>&1; then
            log "QQ not running, attempting to launch..."
            open -a QQ 2>/dev/null
            qq_launched=1
        fi
        log "LLOneBot not available (port 3001), waiting 10s..."
        sleep 10
    done
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
            local ws_status="未知"
            if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
                ws_status="运行中 (PID $(cat "$PID_FILE"))"
            else
                ws_status="未运行"
            fi
            if [ -n "$pane" ]; then
                send_qq_reply "[状态] Bridge: ${ws_status}
终端: ${pane}"
            else
                send_qq_reply "[状态] Bridge: ${ws_status}
终端: 未找到"
            fi
            return 0 ;;
        /help)
            send_qq_reply "[命令列表]
/cancel, /c - 发送 Ctrl+C
/escape, /e - 发送 Escape
/enter - 发送空回车
/status - 查看桥接状态
/restart - 重启 bridge
/log - 查看最近日志
/pane - 截取终端内容
/help - 显示此帮助
其他文本 - 直接注入终端"
            return 0 ;;
        /restart)
            send_qq_reply "[重启中] Bridge 正在重启..."
            log "Restart requested via QQ"
            # 先回复再重启，给 curl 时间发送
            sleep 1
            exec "$0" run
            ;;
        /log)
            local recent
            recent=$(tail -10 "$LOG_FILE" 2>/dev/null || echo "无日志")
            send_qq_reply "[最近日志]
${recent}"
            return 0 ;;
        /pane)
            pane=$(find_claude_pane)
            if [ -n "$pane" ]; then
                local content
                content=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -30)
                if [ -n "$content" ]; then
                    # QQ 消息有长度限制，截取最后部分
                    send_qq_reply "[终端内容] ${pane}
${content:0:1500}"
                else
                    send_qq_reply "[终端内容] ${pane}: (空)"
                fi
            else
                send_qq_reply "[错误] 未找到 Claude Code 终端"
            fi
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

# ─── 清理子进程 ───
cleanup() {
    log "Bridge shutting down"
    rm -f "$FIFO_FILE" "$STDIN_FIFO"
    # 杀死所有子进程（包括 keeper、watchdog、websocat）
    kill $(jobs -p) 2>/dev/null
    wait 2>/dev/null
}

# ─── WebSocket 监听主循环 ───
listen_loop() {
    local backoff=2
    local first_connect=1

    log "Bridge started (PID $$)"

    trap cleanup EXIT

    while true; do
        rotate_log

        # 连接前先检查 LLOneBot 是否可用
        wait_for_llonebot

        log "Connecting to ${QQ_WS}..."
        local got_message=0

        # 用 FIFO 解耦 websocat 输出和读取，方便 watchdog 控制生命周期
        rm -f "$FIFO_FILE" "$STDIN_FIFO"
        mkfifo "$FIFO_FILE"
        mkfifo "$STDIN_FIFO"

        # stdin keeper: exec sleep 替换子 shell，使 keeper_pid 就是 sleep 的 PID
        # fd 3 保持 STDIN_FIFO 写端打开，防止 websocat 收到 EOF
        (exec 3>"$STDIN_FIFO"; exec sleep 2147483647) &
        local keeper_pid=$!

        websocat -t "$QQ_WS" < "$STDIN_FIFO" > "$FIFO_FILE" 2>/dev/null &
        local ws_pid=$!

        # 短暂等待确认 websocat 成功启动
        sleep 0.5
        if ! kill -0 $ws_pid 2>/dev/null; then
            log "websocat failed to start"
            rm -f "$FIFO_FILE"
            sleep "$backoff"
            backoff=$((backoff * 2))
            [ "$backoff" -gt "$MAX_BACKOFF" ] && backoff=$MAX_BACKOFF
            continue
        fi

        log "Connected successfully"

        # 首次连接或重连成功时通知 QQ
        if [ "$first_connect" -eq 1 ]; then
            send_qq_reply "[Bridge] 已启动"
            first_connect=0
        elif [ "$backoff" -gt 2 ]; then
            send_qq_reply "[Bridge] 已重新连接"
        fi

        # Watchdog: 每 30 秒检查 TCP 连接状态，死连接则 kill websocat 触发重连
        # LLOneBot 不响应 WebSocket ping，需要用 lsof 检查 TCP 状态
        (while true; do
            sleep 30
            if ! kill -0 $ws_pid 2>/dev/null; then
                break
            fi
            if ! lsof -p $ws_pid -a -i TCP 2>/dev/null | grep -q 'ESTABLISHED'; then
                log "Dead connection detected, forcing reconnect"
                kill $ws_pid 2>/dev/null
                break
            fi
        done) &
        local wd_pid=$!

        # 从 FIFO 读取事件（websocat 退出时 write-end 关闭 → read 收到 EOF）
        while IFS= read -r line; do
            got_message=1
            handle_message "$line"
        done < "$FIFO_FILE"

        # 清理本轮子进程（keeper、watchdog、websocat）
        kill $keeper_pid $wd_pid $ws_pid 2>/dev/null
        wait $keeper_pid $wd_pid $ws_pid 2>/dev/null
        rm -f "$FIFO_FILE" "$STDIN_FIFO"

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
    echo "Starting QQ bridge daemon..."
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
        # 先发 TERM，让 trap 清理子进程
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
        # 杀死可能残留的子进程
        pkill -P "$pid" 2>/dev/null
        rm -f "$PID_FILE" "$FIFO_FILE" "$STDIN_FIFO"
        echo "Stopped bridge (PID ${pid})"
    else
        rm -f "$PID_FILE" "$FIFO_FILE" "$STDIN_FIFO"
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
        local pane
        pane=$(find_claude_pane)
        if [ -n "$pane" ]; then
            echo "Claude Code pane: ${pane}"
        else
            echo "Claude Code pane: not found"
        fi
        # 显示 LLOneBot 状态
        if lsof -i :3001 -sTCP:LISTEN >/dev/null 2>&1; then
            echo "LLOneBot: online (port 3001)"
        else
            echo "LLOneBot: offline"
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
    run)     check_deps; listen_loop ;;
    *)       echo "Usage: $0 {start|stop|restart|status|ensure|run}"; exit 1 ;;
esac
