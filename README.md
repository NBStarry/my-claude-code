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
- 支持授权快速回复（1/2/3）和特殊命令（`/cancel`、`/status` 等）
- 转发后自动发送 QQ 确认回复
- 守护进程模式，断线自动重连

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
