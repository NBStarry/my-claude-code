# Hooks

Claude Code Hook 配置与示例。

## Overview / 概述

Hooks 允许你在 Claude Code 的特定事件点执行自定义逻辑，用于实施安全规则、代码质量检查或工作流强制要求。

## Event Types / 事件类型

| 事件 | 说明 | 常见用途 |
|------|------|----------|
| `PreToolUse` | 工具调用之前触发 | 阻止危险命令、文件保护 |
| `PostToolUse` | 工具调用之后触发 | 结果验证、日志记录 |
| `Notification` | Claude 发送通知时触发 | 系统通知、声音提醒 |
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
- Hook 脚本通过 stdin 接收 JSON 格式的上下文数据
- 测试 hook 时先用 `warn` 动作，确认无误后再改为 `block`

## notification.json — macOS 自动通知

开箱即用的通知配置，覆盖三个场景：

| 事件 | 提示音 | 通知内容 |
|------|--------|----------|
| 权限请求 (`permission_prompt`) | Ping | "Claude 需要你的授权" |
| 空闲等待 (`idle_prompt`) | Blow | "Claude 正在等待你的输入" |
| 任务完成 (`Stop`) | Glass | "任务已完成，请查看结果" |

**安装方式：** 将 `notification.json` 中的 `hooks` 内容合并到 `~/.claude/settings.json`。

**Notification Matchers：**

| Matcher | 触发时机 |
|---------|---------|
| `permission_prompt` | Claude 请求工具权限 |
| `idle_prompt` | Claude 空闲 60 秒以上 |
| `elicitation_dialog` | MCP 工具需要输入 |

**依赖：** macOS 内置命令 `osascript`（系统通知）和 `afplay`（音效），无需额外安装。

## Examples / 示例

参见 `examples/` 目录和 `notification.json`。
