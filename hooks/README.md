# Hooks

Claude Code Hook 配置与示例。

## Overview / 概述

Hooks 允许你在 Claude Code 的特定事件点执行自定义逻辑，用于实施安全规则、代码质量检查或工作流强制要求。

## Event Types / 事件类型

| 事件 | 说明 | 常见用途 |
|------|------|----------|
| `PreToolUse` | 工具调用之前触发 | 阻止危险命令、文件保护 |
| `PostToolUse` | 工具调用之后触发 | 结果验证、日志记录 |
| `Notification` | Claude 发送通知时触发 | Telegram 推送、声音提醒 |
| `Stop` | Claude 准备结束会话时触发 | 完成检查清单、测试提醒 |
| `UserPromptSubmit` | 用户提交提示词时触发 | 输入预处理、工作流路由 |
| `SessionStart` | 会话开始时触发 | 加载上下文、环境初始化 |
| `SessionEnd` | 会话结束时触发 | 清理、日志归档 |

## Hook Configuration Format / 配置格式

在 `~/.claude/settings.json` 中配置：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "your-script.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## Tips / 使用建议

- Hook 脚本应保持简洁高效，避免超时
- Hook 脚本通过 stdin 接收 JSON 格式的上下文数据（含 `message`、`cwd`、`transcript_path`）
- 每个 hook 条目独立接收 stdin，需要读取 JSON 的脚本应作为单独的 hook 条目
- 测试 hook 时先用 `warn` 动作，确认无误后再改为 `block`

## notification.telegram.json — Telegram 推送通知

通过 Telegram Bot API 发送私聊消息，实现手机远程提醒，覆盖三个场景：

| 事件 | 通知格式 |
|------|----------|
| 权限请求 (`permission_prompt`) | `[需要授权] 项目名` + 工具详情 + 授权选项 |
| 空闲等待 (`idle_prompt`) | `[等待输入] 项目名` + Claude 回复 + 上下文 |
| 任务完成 (`Stop`) | `[任务完成] 项目名` + Claude 回复 + 上下文 |

**安装方式：** 将 `notification.telegram.json` 中的 `hooks` 内容合并到 `~/.claude/settings.json`，并安装 `scripts/notify-telegram.sh`。

**前提条件：** Telegram Bot（通过 @BotFather 创建，详见 [scripts/README.md](../scripts/README.md)）

**优势：**
- 官方 API，无封号风险
- 无需本地运行第三方服务（如 LLOneBot）
- 支持代理配置，适合网络受限环境
- 跨平台（Windows/macOS/Linux）

## bash-syntax-check.json — Shell 脚本语法检查

通过 prompt-based hook 在 `git commit` 前验证所有已暂存 `.sh` 文件的语法正确性。

| 配置项 | 值 |
|--------|-----|
| 事件 | `PreToolUse` (Bash) |
| 类型 | `prompt`（AI 判断） |
| 检查内容 | `git commit` 时，确认所有 `.sh` 文件已通过 `bash -n` |
| 触发动作 | 未检查则 BLOCK，已检查则 ALLOW |

**安装方式：** 将 `bash-syntax-check.json` 中的 hooks 内容合并到 `~/.claude/settings.json`。

**优势：**
- 防止语法错误的 Shell 脚本被提交
- 无需手动记住执行 `bash -n`
- 使用 prompt-based hook，智能判断上下文

## Examples / 示例

参见 `examples/` 目录、`notification.telegram.json` 和 `bash-syntax-check.json`。
