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

详见 [scripts/README.md](scripts/README.md)。

## Hooks

Hooks 允许你在 Claude Code 的特定事件点执行自定义逻辑。

| 事件 | 触发时机 |
|------|----------|
| `PreToolUse` | 工具调用之前 |
| `PostToolUse` | 工具调用之后 |
| `Stop` | Claude 准备结束时 |
| `UserPromptSubmit` | 用户提交提示词时 |

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
