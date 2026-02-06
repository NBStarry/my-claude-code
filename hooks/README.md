# Hooks

Claude Code Hook 配置与示例。

## Overview / 概述

Hooks 允许你在 Claude Code 的特定事件点执行自定义逻辑，用于实施安全规则、代码质量检查或工作流强制要求。

## Event Types / 事件类型

| 事件 | 说明 | 常见用途 |
|------|------|----------|
| `PreToolUse` | 工具调用之前触发 | 阻止危险命令、文件保护 |
| `PostToolUse` | 工具调用之后触发 | 结果验证、日志记录 |
| `Stop` | Claude 准备结束会话时触发 | 完成检查清单、测试提醒 |
| `UserPromptSubmit` | 用户提交提示词时触发 | 输入预处理、工作流路由 |

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

## Examples / 示例

参见 `examples/` 目录。
