# Agents

Claude Code Agent（子代理）定义与示例。

## Overview / 概述

Agents 是可由 Claude 派生的子任务执行器。Claude 会根据需要自动派生 agent 来处理特定类型的分析或操作任务，每个 agent 运行在独立的上下文中。

## Agent Format / 格式

Agent 以 markdown 文件定义，使用 YAML frontmatter：

```markdown
---
name: agent-name
description: 描述 agent 的用途和触发条件
model: inherit
tools: ["Read", "Grep", "Glob"]
---

Agent 的系统指令和职责描述...
```

## Frontmatter Fields / 字段说明

| 字段 | 说明 |
|------|------|
| `name` | Agent 标识符 |
| `description` | 触发条件描述 |
| `model` | 使用的模型（`inherit`、`haiku`、`sonnet`、`opus`） |
| `tools` | 允许使用的工具列表 |

## Examples / 示例

参见 `examples/` 目录。
