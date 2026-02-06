# Skills

Claude Code Skill 定义与示例。

## Overview / 概述

Skills 是 Claude 根据任务上下文自动调用的能力模块。与 slash commands 不同，skills 不需要用户手动触发，Claude 会根据请求内容自动判断是否需要使用某个 skill。

## Skill Structure / 目录结构

每个 skill 是一个目录，包含一个必需的 `SKILL.md` 文件：

```
skills/
└── my-skill/
    ├── SKILL.md          # Skill 定义（必需）
    ├── references/       # 参考资料（可选）
    └── scripts/          # 辅助脚本（可选）
```

## SKILL.md Format / 格式

```markdown
---
name: skill-name
description: 描述何时应该触发此 skill
version: 1.0.0
---

# Skill Title

Skill 的具体指令和知识内容...
```

## Key Points / 要点

- `description` 字段决定 Claude 何时调用此 skill，务必写清楚触发条件
- Skill 内容会被注入到 Claude 的上下文中
- 保持每个 skill 聚焦于单一领域
- 避免不同 skill 之间的触发条件重叠

## Examples / 示例

参见 `examples/` 目录。
