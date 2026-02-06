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

## notify-qq.sh

通过 QQ 发送 Claude Code 格式化通知消息，配合 hooks 实现远程手机推送提醒。

### Features / 功能

- 从 hook stdin 读取 JSON，解析工具调用、用户请求等上下文
- 三种通知类型，格式化显示：
  - `permission_prompt` — 授权请求（含工具名、参数、授权选项）
  - `idle_prompt` — 等待输入
  - `stop` — 任务完成
- 显示项目名、Claude 最后回复、用户最近请求
- 通过 LLOneBot OneBot 11 HTTP API 发送 QQ 私聊消息

### Preview / 效果预览

```
[任务完成] my-project

[回复] 已完成所有修改并推送到 dev 分支。

[上下文] 请帮我更新文档
```

```
[需要授权] my-project

Bash: npm install express

[授权选项]
❯ 1. Yes
  2. Yes, don't ask again
  3. No
```

### Dependencies / 依赖

- **LiteLoaderQQNT** — NTQQ 插件加载器
- **LLOneBot v4.9.2** — LiteLoaderQQNT 插件，提供 OneBot 11 HTTP API
- `jq` — JSON 解析
- `curl` — HTTP 请求（macOS/Linux 自带）

### Prerequisites / 前提条件

1. 安装 LiteLoaderQQNT 到 macOS QQ（详见项目 wiki）
2. 安装 LLOneBot 插件，HTTP API 默认端口 3000
3. **桌面 QQ 登录机器人号**（发送方），**手机 QQ 登录主号**（接收方）
4. 修改脚本中 `QQ_USER` 为接收通知的 QQ 号

> **注意：** 必须使用两个不同的 QQ 号。同一账号给自己发消息不会触发手机推送。

### Installation / 安装

```bash
cp notify-qq.sh ~/.claude/notify-qq.sh
chmod +x ~/.claude/notify-qq.sh
# 编辑 QQ_USER 为你的接收号
```

### Hook Configuration / Hook 配置

在 `~/.claude/settings.json` 中配置：

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [{"type": "command", "command": "bash ~/.claude/notify-qq.sh permission_prompt"}]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [{"type": "command", "command": "bash ~/.claude/notify-qq.sh idle_prompt"}]
      }
    ],
    "Stop": [
      {
        "hooks": [{"type": "command", "command": "bash ~/.claude/notify-qq.sh stop"}]
      }
    ]
  }
}
```

### How It Works / 工作原理

Claude Code 通过 hook 触发脚本，stdin 传入 JSON（含 `message`、`cwd`、`transcript_path`）。脚本从 transcript 文件中提取最近的工具调用信息和用户请求，格式化为可读的通知消息，通过 LLOneBot HTTP API 发送 QQ 私聊。
