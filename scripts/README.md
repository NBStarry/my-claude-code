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

通过 QQ 发送 Claude Code 通知消息，配合 hooks 实现远程提醒。

### Dependencies / 依赖

- **LLOneBot** — NTQQ 插件，提供 OneBot 11 HTTP API
- `curl` — HTTP 请求（macOS/Linux 自带）

### Installation / 安装

```bash
cp notify-qq.sh ~/.claude/notify-qq.sh
chmod +x ~/.claude/notify-qq.sh
```

在 `~/.zshrc` 中添加环境变量：

```bash
export QQ_USER_ID="你的QQ号"
export QQ_API_URL="http://localhost:3000"  # 可选，默认即可
```

### Usage / 使用方式

**手动测试：**

```bash
QQ_USER_ID=12345 bash ~/.claude/notify-qq.sh "测试消息"
```

**配合 hooks 使用：** 在 `~/.claude/settings.json` 的 hook 命令末尾追加：

```bash
bash ~/.claude/notify-qq.sh '任务已完成'
```

### How It Works / 工作原理

脚本通过 `curl` 向 LLOneBot 的 OneBot 11 HTTP API 发送 `send_private_msg` 请求。消息前缀 `[Claude Code]` 便于在 QQ 中识别。未配置 `QQ_USER_ID` 时静默跳过，不影响其他通知。
