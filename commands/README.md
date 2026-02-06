# Commands

Claude Code Slash Command（斜杠命令）定义与示例。

## Overview / 概述

Commands 是用户通过 `/command-name` 手动触发的功能。每个 command 是一个 markdown 文件，包含 YAML frontmatter 和执行指令。

## Command Format / 格式

```markdown
---
description: 命令的简短描述
argument-hint: <required-arg> [optional-arg]
allowed-tools: [Read, Glob, Grep, Bash]
---

# Command Title

当此命令被调用时的执行指令...

用户传入的参数：$ARGUMENTS
```

## Frontmatter Fields / 字段说明

| 字段 | 说明 |
|------|------|
| `description` | 命令简短描述，显示在 `/help` 列表中 |
| `argument-hint` | 参数提示（`<必需>` `[可选]`） |
| `allowed-tools` | 预授权工具列表 |
| `model` | 覆盖默认模型 |

## Examples / 示例

参见 `examples/` 目录。
