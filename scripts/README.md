# Scripts

Claude Code 自定义脚本。

## statusline.sh

自定义状态栏脚本，在 Claude Code 终端底部显示丰富的上下文信息。

### Features / 功能

- 显示 `用户名@主机名:当前目录`（绿色/蓝色）
- 显示当前使用的模型名称（青色）
- 显示 Git 当前分支（黄色）
- 显示上下文窗口使用率，带颜色编码：
  - 绿色：< 50%（充裕）
  - 黄色：50%-80%（注意）
  - 红色：>= 80%（紧张）

### Preview / 效果预览

```
user@mac:~/projects/myapp Claude Opus 4.6 (main) [ctx:34%]
```

### Dependencies / 依赖

- `jq` - JSON 解析工具
- `git` - 用于获取分支信息

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Installation / 安装

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

确保 `~/.claude/settings.json` 中包含：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

### How It Works / 工作原理

Claude Code 通过 stdin 向状态栏脚本传入 JSON 数据，包含模型信息和上下文窗口用量等。脚本读取这些数据，结合本地环境信息（用户名、主机名、目录、Git 分支），组合输出带 ANSI 颜色编码的状态栏字符串。

---

## notify-telegram.sh

通过 Telegram Bot API 发送 Claude Code 格式化通知消息，配合 hooks 实现远程手机推送提醒。

### Features / 功能

- 从 hook stdin 读取 JSON，解析工具调用、用户请求等上下文
- 三种通知类型，格式化显示：
  - `permission_prompt` — 授权请求（含工具名、参数、授权选项）
  - `idle_prompt` — 等待输入
  - `stop` — 任务完成
- 显示项目名、上下文使用百分比、Claude 最后回复、用户最近请求
- 通过 Telegram Bot API 发送私聊消息
- 支持代理配置（TELEGRAM_PROXY 或 HTTPS_PROXY）
- 消息自动截断（Telegram 限制 4096 字符）

### Preview / 效果预览

```
[任务完成] my-project [ctx:34%]

[回复] 已完成所有修改并推送到 dev 分支。

[上下文] 请帮我更新文档
```

```
[需要授权] my-project [ctx:34%]

Bash: npm install express

[授权选项]
❯ 1. Yes
  2. Yes, don't ask again
  3. No
```

### Dependencies / 依赖

- **Telegram Bot** — 通过 @BotFather 创建的 Bot（免费）
- `jq` — JSON 解析
- `curl` — HTTP 请求（macOS/Linux 自带）

### Prerequisites / 前提条件

1. 在 Telegram 中与 @BotFather 对话，发送 `/newbot` 创建 Bot，获取 Bot Token
2. 向你的 Bot 发送任意消息（激活对话）
3. 访问 `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates` 获取你的 Chat ID
4. 创建配置文件 `~/.claude/telegram.conf`（参考 `configs/telegram.conf.example`）
5. 配置文件内容：
   ```bash
   TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
   TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"
   # TELEGRAM_PROXY="socks5://127.0.0.1:7890"  # 可选：代理配置
   ```

### Installation / 安装

```bash
cp notify-telegram.sh ~/.claude/notify-telegram.sh
chmod +x ~/.claude/notify-telegram.sh
# 配置 ~/.claude/telegram.conf
```

### Hook Configuration / Hook 配置

在 `~/.claude/settings.json` 中配置：

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [{"type": "command", "command": "bash ~/.claude/notify-telegram.sh permission_prompt"}]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [{"type": "command", "command": "bash ~/.claude/notify-telegram.sh idle_prompt"}]
      }
    ],
    "Stop": [
      {
        "hooks": [{"type": "command", "command": "bash ~/.claude/notify-telegram.sh stop"}]
      }
    ]
  }
}
```

### How It Works / 工作原理

Claude Code 通过 hook 触发脚本，stdin 传入 JSON（含 `message`、`cwd`、`transcript_path`）。脚本从 transcript 文件中提取最近的工具调用信息和用户请求，格式化为可读的通知消息，通过 Telegram Bot API (`sendMessage`) 发送到指定 Chat ID。相比 QQ 方案，无需本地运行第三方服务，只需配置 Bot Token。

---

## telegram-bridge.sh

Telegram → Claude Code 消息桥接守护进程。监听 Telegram 私聊消息，通过 tmux send-keys 注入到 Claude Code 终端，与 notify-telegram.sh 形成双向通信。

### Features / 功能

- 通过长轮询（`getUpdates`）实时接收 Telegram 消息
- 自动检测 Claude Code 所在的 tmux pane
- 支持授权选项快速回复（1/2/3）
- 特殊命令：`/cancel`、`/escape`、`/enter`、`/status`、`/restart`、`/log`、`/pane`、`/help`
- 转发成功后自动发送 Telegram 确认回复
- 守护进程管理（start/stop/restart/status/ensure）
- Claude Code 启动时自动启动（`UserPromptSubmit` hook + `ensure` 命令）
- 断线自动重连（指数退避）+ 重连成功通知
- 日志自动轮转（超过 500 行截断）
- `OFFSET_FILE` 持久化已处理的 update_id，防止重启后重复处理消息
- 架构简洁：无需 websocat、FIFO、keeper 进程、watchdog

### Preview / 效果预览

```
手机 Telegram 发送: 1
  → Claude Code 终端收到 "1" + Enter（选择授权）
  → 手机收到确认: [已选择] 1. Yes

手机 Telegram 发送: 请帮我写单元测试
  → Claude Code 终端收到 "请帮我写单元测试" + Enter
  → 手机收到确认: [已发送] 请帮我写单元测试

手机 Telegram 发送: /cancel
  → Claude Code 终端收到 Ctrl+C
  → 手机收到确认: [已发送] Ctrl+C
```

### Dependencies / 依赖

- `jq` — JSON 解析工具
- `tmux` — 终端复用器（Claude Code 需在 tmux 中运行）
- `curl` — HTTP 请求（macOS/Linux 自带）

```bash
# macOS
brew install jq tmux
```

### Installation / 安装

```bash
cp telegram-bridge.sh ~/.claude/telegram-bridge.sh
chmod +x ~/.claude/telegram-bridge.sh
```

确保 `~/.claude/telegram.conf` 已配置（与 notify-telegram.sh 共享）。

### Usage / 使用方式

```bash
# 启动守护进程
~/.claude/telegram-bridge.sh start

# 查看状态
~/.claude/telegram-bridge.sh status

# 重启
~/.claude/telegram-bridge.sh restart

# 停止
~/.claude/telegram-bridge.sh stop

# 幂等启动（已运行则跳过，用于 hook 集成）
~/.claude/telegram-bridge.sh ensure

# 前台运行（调试用）
~/.claude/telegram-bridge.sh run
```

Bridge 也可通过 `UserPromptSubmit` hook 自动启动，每次用户提交 prompt 时检查 bridge 是否运行。

### Special Commands / 特殊命令

| 命令 | 动作 |
|------|------|
| `/cancel`, `/c` | 发送 Ctrl+C |
| `/escape`, `/e` | 发送 Escape |
| `/enter` | 发送空回车 |
| `/status` | 查看桥接状态（含 PID、终端 pane、Bot 连通性） |
| `/restart` | 远程重启 bridge 守护进程 |
| `/log` | 查看最近 10 行日志 |
| `/pane` | 截取 Claude Code 终端当前显示内容 |
| `/help` | 显示命令列表 |

### How It Works / 工作原理

脚本通过 `curl` 长轮询调用 Telegram Bot API 的 `getUpdates` 方法（`timeout=30`），实时接收消息更新。收到私聊消息后，过滤 Chat ID，解析消息文本，通过 `tmux send-keys -l`（literal 模式）安全地注入到 Claude Code 所在的 tmux pane。注入成功后，通过 `sendMessage` API 发送确认回复。

**架构特点：**
- HTTP 长轮询，无需 WebSocket 或 `websocat` 依赖
- 单进程架构，无 FIFO 管道、keeper 进程、watchdog
- 连接检查通过 `getMe` API 验证 Bot 可用性
- `OFFSET_FILE` 持久化已处理消息的偏移量，避免重启后重复处理历史消息

> **注意：** 必须在 tmux 中运行 Claude Code，脚本通过 `pane_current_command` 自动检测包含 "claude" 的 pane。
