# my-claude-code

> NBStarry 的 Claude Code 配置、脚本与扩展合集

## About

这是一个公开的 Claude Code 配置仓库，用于存储和分享日常使用 Claude Code 时积累的配置文件、自定义脚本、hooks、skills、agents 和 commands。

如果你也在使用 Claude Code，希望这些配置能为你提供参考和灵感。

## Repository Structure

```
my-claude-code/
├── configs/          # 配置文件（settings.json 等）
├── scripts/          # 自定义脚本（statusline 等）
├── hooks/            # Hook 配置与示例
├── skills/           # Skill 定义与示例
├── agents/           # Agent 定义与示例
├── commands/         # Slash command 定义与示例
├── CLAUDE.md         # 本项目的 Claude Code 约定
└── README.md         # 本文件
```

## Configs

存放 Claude Code 的全局和项目级配置文件。

| 文件 | 说明 |
|------|------|
| `configs/settings.json` | 全局配置示例，包含模型选择和 statusline 设置 |
| `configs/settings.local.json` | 项目级配置示例，包含输出风格和权限设置 |

```bash
# 全局配置
cp configs/settings.json ~/.claude/settings.json

# 项目级配置
mkdir -p .claude
cp configs/settings.local.json .claude/settings.local.json
```

## Scripts

### statusline.sh

自定义状态栏脚本，在 Claude Code 底部显示丰富的上下文信息：

- **用户名@主机名:当前目录** - 绿色和蓝色高亮
- **模型名称** - 青色显示（如 Claude Opus 4.6）
- **Git 分支** - 黄色显示当前分支名
- **上下文使用率** - 颜色编码（绿色 < 50% / 黄色 50-80% / 红色 >= 80%）

**效果预览：**

```
user@mac:~/projects/myapp Claude Opus 4.6 (main) [ctx:34%]
```

**安装：**

```bash
cp scripts/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

**依赖：** `jq`（`brew install jq` 或 `apt-get install jq`）

### qq-bridge.sh

QQ → Claude Code 消息桥接守护进程，与 `notify-qq.sh` 形成**双向通信**：

- **出站**（notify-qq.sh）：Claude Code 事件 → QQ 通知到手机
- **入站**（qq-bridge.sh）：手机 QQ 消息 → 注入 Claude Code 终端

功能：
- 监听 QQ 私聊消息，通过 `tmux send-keys` 注入到 Claude Code
- 支持授权快速回复（1/2/3）和特殊命令（`/cancel`、`/status`、`/restart`、`/log`、`/pane` 等）
- 转发后自动发送 QQ 确认回复
- Claude Code 启动时自动启动（`UserPromptSubmit` hook）
- 连接前检查 LLOneBot 可用性，无进程泄漏
- 守护进程模式，断线自动重连 + 重连通知

**安装：**

```bash
brew install websocat  # WebSocket 客户端
cp scripts/qq-bridge.sh ~/.claude/qq-bridge.sh
chmod +x ~/.claude/qq-bridge.sh
~/.claude/qq-bridge.sh start  # 启动守护进程
```

**依赖：** `websocat`、`jq`、`tmux`

详见 [scripts/README.md](scripts/README.md)。

## Hooks

Hooks 允许你在 Claude Code 的特定事件点执行自定义逻辑。

### notification.json — QQ 推送通知

当 Claude 完成任务、需要授权或等待输入时，通过 QQ 私聊发送格式化通知到手机：

| 事件 | 通知格式 |
|------|----------|
| 权限请求 | `[需要授权] 项目名 [ctx:XX%]` + 工具详情 + 授权选项 |
| 空闲等待 | `[等待输入] 项目名 [ctx:XX%]` + Claude 回复 + 上下文 |
| 任务完成 | `[任务完成] 项目名 [ctx:XX%]` + Claude 回复 + 上下文 |

**前提条件：** LiteLoaderQQNT + LLOneBot + 双 QQ 号

**安装：** 安装 `scripts/notify-qq.sh`，将 `hooks/notification.json` 中的 hooks 合并到 `~/.claude/settings.json`。

详见 [hooks/README.md](hooks/README.md)。

## Skills

Skills 是 Claude 根据任务上下文自动调用的能力模块，不需要用户手动触发。

详见 [skills/README.md](skills/README.md)。

## Agents

Agents 是可由 Claude 派生的子任务执行器，用于处理特定类型的分析或操作任务。

详见 [agents/README.md](agents/README.md)。

## Commands

Commands 是用户通过 `/command-name` 手动触发的斜杠命令。

详见 [commands/README.md](commands/README.md)。

## Agent Teams / 团队协作

Claude Code 实验性功能，支持多 agent 协同工作。已在本项目中实践验证。

### 启用

```json
// ~/.claude/settings.json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }
}

// .claude/settings.local.json
{
  "teammateMode": "in-process"
}
```

### 推荐配置

| 参数 | 推荐值 | 原因 |
|------|--------|------|
| `mode` | `acceptEdits` | `default` 会导致 teammate 卡在权限审批 |
| `model` | `sonnet` | haiku idle 后反复发冗长消息浪费 token |
| `teammateMode` | `in-process` | tmux 分 pane 太挤，Shift+上/下切换更方便 |

### 踩坑经验

- **`mode: "default"` 会卡死** — 权限请求通过邮箱发送但 lead 收不到交互式提示，必须用 `acceptEdits`
- **Teammate 可能崩溃** — 需要检查进程存活（`ps aux | grep 'claude.*team'`），重新生成
- **明确 Git 规则** — 在 prompt 中写 "不要自行 commit"，否则 teammate 可能擅自提交
- **邮箱路由** — 消息可能发到错误团队，调试看 `~/.claude/teams/{name}/inboxes/`

## Remote Access / 远程访问

通过 SSH + Tailscale + tmux 实现手机远程控制 Claude Code，配合 QQ 双向通信形成完整的移动工作流：

| 方式 | 适用场景 |
|------|----------|
| **QQ 消息** | 快速回复授权（1/2/3）、发送简短指令 |
| **SSH + tmux** | 完整终端界面，查看输出、复杂交互 |

### 架构

```
手机
├── QQ → qq-bridge.sh → tmux send-keys → Claude Code（轻量指令）
├── SSH → tmux attach → Claude Code（完整终端）
└── Tailscale（内网穿透，任何网络均可访问）
```

### 配置步骤

1. **macOS 开启 SSH**：系统设置 → 通用 → 共享 → 远程登录
2. **安装 Tailscale**：`brew install --cask tailscale`，登录账号
3. **手机安装 Tailscale**：同一账号登录，获得 `100.x.x.x` 虚拟 IP
4. **手机 SSH 客户端**（Termius / Blink Shell）连接 Mac 的 Tailscale IP
5. **连接后**：`tmux attach -t <session>` 接管 Claude Code 会话

### tmux 配置建议

```bash
# ~/.tmux.conf
set -g mouse on  # 启用鼠标/触屏滚动
```

### 手机终端常见问题

- **中文乱码**：确保 `LANG=en_US.UTF-8`（添加到 `~/.zprofile`）
- **无法滚动**：Termius 可设置音量键翻页；或 `Ctrl+B [` 进入 tmux 复制模式
- **Tailscale SSH 不可用**：GUI 版本（App Store/cask）是沙盒化的，不支持 `tailscale set --ssh`，需用标准 SSH

## Environment

| 项目 | 详情 |
|------|------|
| 操作系统 | macOS (Darwin) |
| 默认模型 | Claude Opus |
| 输出风格 | Explanatory |

## Contributing

欢迎通过 Issue 或 Pull Request 贡献你的 Claude Code 配置和脚本！

## License

MIT License - 详见 [LICENSE](LICENSE) 文件。

---

*Made with Claude Code by NBStarry*
