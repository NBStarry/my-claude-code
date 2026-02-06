#!/bin/bash
# Claude Code QQ Notification Script
# 通过 LLOneBot (OneBot 11 HTTP API) 发送 QQ 私聊消息
#
# Usage: notify-qq.sh <message>
# 环境变量:
#   QQ_USER_ID  - 接收通知的 QQ 号（必需）
#   QQ_API_URL  - LLOneBot HTTP API 地址（默认 http://localhost:3000）
#
# 安装:
#   cp notify-qq.sh ~/.claude/notify-qq.sh
#   chmod +x ~/.claude/notify-qq.sh
#
# 前提条件:
#   1. 安装并运行 LLOneBot (NTQQ 插件)
#   2. LLOneBot 启用 HTTP API (默认端口 3000)
#   3. 在 ~/.zshrc 中配置: export QQ_USER_ID="你的QQ号"

QQ_API="${QQ_API_URL:-http://localhost:3000}"
QQ_USER="${QQ_USER_ID:-}"
MESSAGE="${1:-Claude Code 通知}"

# 未配置 QQ 号则静默跳过
if [ -z "$QQ_USER" ]; then
  exit 0
fi

# 后台发送，不阻塞 hook
curl -s -X POST "${QQ_API}/send_private_msg" \
  -H 'Content-Type: application/json' \
  -d "{\"user_id\": ${QQ_USER}, \"message\": \"[Claude Code] ${MESSAGE}\"}" \
  > /dev/null 2>&1 &
