# Skills

Claude Code Skill 集合，来自官方插件和社区最佳实践。

## Overview / 概述

Skills 是 Claude Code 的能力扩展模块。与 slash commands 不同，Skills 可以被 Claude **自动检测并加载**（基于 `description` 字段匹配），也可以通过 `/skill-name` 手动调用。

本目录收录了 3 个插件的 22 个 Skills，涵盖开发工作流、调试、代码审查、插件开发等领域。

## Directory Structure / 目录结构

```
skills/
├── superpowers/              # 核心技能库 (Jesse Vincent, MIT)
│   ├── brainstorming/        # 创意探索
│   ├── test-driven-development/  # TDD 工作流
│   ├── systematic-debugging/     # 系统化调试
│   ├── writing-plans/            # 编写实施计划
│   ├── executing-plans/          # 执行计划
│   ├── dispatching-parallel-agents/  # 并行 Agent 调度
│   ├── subagent-driven-development/  # 子 Agent 驱动开发
│   ├── requesting-code-review/       # 请求代码审查
│   ├── receiving-code-review/        # 接收审查反馈
│   ├── verification-before-completion/   # 完成前验证
│   ├── finishing-a-development-branch/   # 完成开发分支
│   ├── using-git-worktrees/          # Git Worktree 隔离
│   ├── writing-skills/               # 编写 Skills
│   └── using-superpowers/            # Superpowers 入口
├── plugin-dev/               # 插件开发工具包 (Anthropic)
│   ├── plugin-structure/     # 插件结构
│   ├── skill-development/    # Skill 开发
│   ├── command-development/  # Command 开发
│   ├── agent-development/    # Agent 开发
│   ├── hook-development/     # Hook 开发
│   ├── mcp-integration/      # MCP 集成
│   └── plugin-settings/      # 插件配置
├── claude-md-management/     # CLAUDE.md 管理 (Anthropic)
│   └── claude-md-improver/   # CLAUDE.md 审计与优化
├── merge-verified/           # 安全合并工作流 (本仓库自定义)
└── examples/                 # 模板
    └── example-skill/        # Skill 模板
```

## SKILL.md Format / 格式

```markdown
---
name: skill-name
description: 触发条件描述（Claude 据此判断是否自动加载）
version: 1.0.0
---

# Skill Title

具体指令和知识内容...
```

**关键字段：**
- `name` — Skill 标识符，也是 `/slash-command` 名称
- `description` — **最重要的字段**，决定 Claude 何时自动调用此 Skill
- `tools` — 允许 Skill 使用的工具列表（可选）

---

## Superpowers — 核心技能库

> 来源：[obra/superpowers](https://github.com/obra/superpowers) (MIT License)
> 作者：Jesse Vincent | 版本：4.2.0

Superpowers 是一套经过实战验证的开发方法论，将软件工程最佳实践编码为 Claude 可自动调用的 Skills。

### brainstorming

**触发时机：** 任何创意工作之前——创建功能、构建组件、添加功能、修改行为

**核心理念：** 在写代码之前先探索用户意图、需求和设计。避免一上来就编码导致方向偏差。

**最佳实践：**
- 让 Claude 先提出 2-3 个不同的实现方案
- 讨论每个方案的 trade-off
- 确认需求后再进入实施

### test-driven-development

**触发时机：** 实现任何功能或修复 bug，在写实现代码之前

**核心理念：** 先写测试，再写实现。测试驱动设计，确保每个功能都有覆盖。

**最佳实践：**
- Red → Green → Refactor 循环
- 测试应描述行为而非实现细节
- 附带 `testing-anti-patterns.md` 参考，避免常见测试反模式

### systematic-debugging

**触发时机：** 遇到任何 bug、测试失败或意外行为，在提出修复之前

**核心理念：** 不要猜，要系统地追踪根因。收集证据 → 形成假设 → 验证 → 修复。

**最佳实践：**
- 先复现问题，确认稳定复现
- 使用二分法缩小问题范围
- 附带 `root-cause-tracing.md`、`defense-in-depth.md` 等参考资料
- 包含 `find-polluter.sh` 脚本用于查找测试污染

### writing-plans

**触发时机：** 有规格或需求要实现多步任务时，在动代码之前

**核心理念：** 将复杂任务拆解为清晰的、可执行的步骤。每步有明确的输入输出和验证标准。

**最佳实践：**
- 计划应包含验证检查点
- 每步足够小，可在一个 Agent turn 内完成
- 标注步骤间的依赖关系

### executing-plans

**触发时机：** 有写好的实施计划需要在独立会话中执行

**核心理念：** 按计划逐步执行，每步完成后验证，出现偏差时暂停审查。

**最佳实践：**
- 不要跳过验证步骤
- 遇到意外时回到计划而非即兴发挥
- 适合与 `writing-plans` 配合使用

### dispatching-parallel-agents

**触发时机：** 面对 2+ 个独立任务，可以并行处理且没有共享状态

**核心理念：** 将独立的子任务分配给并行 Agent，提高效率。

**最佳实践：**
- 确认任务之间真正独立（无共享文件、无执行顺序依赖）
- 为每个 Agent 提供清晰的上下文和目标
- 收集结果时做一致性检查

### subagent-driven-development

**触发时机：** 在当前会话中执行包含独立任务的实施计划

**核心理念：** 将计划中的每个独立任务委托给子 Agent，主 Agent 负责协调和质量把控。

**附带 Prompt 模板：**
- `implementer-prompt.md` — 实现者 Agent
- `spec-reviewer-prompt.md` — 规格审查 Agent
- `code-quality-reviewer-prompt.md` — 代码质量审查 Agent

### requesting-code-review

**触发时机：** 完成任务、实现主要功能或合并前

**核心理念：** 主动请求代码审查，确保工作符合要求。附带 `code-reviewer.md` 审查 Agent 模板。

### receiving-code-review

**触发时机：** 收到代码审查反馈时，特别是反馈不清晰或技术上有疑问时

**核心理念：** 不要盲目同意所有审查意见。保持技术严谨——验证建议的正确性，而非表演性地接受。

**最佳实践：**
- 对每条反馈独立评估技术可行性
- 不确定时先验证再实施
- 拒绝不正确的建议并给出理由

### verification-before-completion

**触发时机：** 即将声称工作完成、bug 已修复或测试通过时

**核心理念：** Evidence before assertions（先证据后断言）。必须运行验证命令并确认输出，然后才能声称成功。

**最佳实践：**
- 提交前必须运行测试
- 截取实际命令输出作为证据
- 永远不要假设"应该可以"——亲自验证

### finishing-a-development-branch

**触发时机：** 实现完成、所有测试通过、需要决定如何集成

**核心理念：** 提供结构化的完成选项：merge、PR 还是 cleanup。引导做出合理选择。

### using-git-worktrees

**触发时机：** 开始需要隔离的功能开发，或执行实施计划前

**核心理念：** 使用 `git worktree` 创建隔离的工作目录，避免污染当前工作区。

**最佳实践：**
- 自动选择合适的 worktree 目录
- 安全验证确保不覆盖已有工作
- 完成后清理 worktree

### writing-skills

**触发时机：** 创建新 Skill、编辑已有 Skill 或验证 Skill 部署前

**附带参考资料：**
- `anthropic-best-practices.md` — Anthropic 官方 Skill 编写指南
- `persuasion-principles.md` — 如何写出让 Claude 准确触发的 description
- `testing-skills-with-subagents.md` — 用子 Agent 测试 Skill

### using-superpowers

**触发时机：** 开始任何对话时（入口 Skill）

**核心理念：** 建立 Skill 发现和使用机制，确保在回复前先检查是否有适用的 Skill。

---

## Plugin Dev — 插件开发工具包

> 来源：claude-plugins-official (Anthropic)

为 Claude Code 插件开发者提供的完整指南，覆盖插件的每个组件类型。

### plugin-structure

**触发时机：** 创建插件、搭建脚手架、理解插件结构

**内容：** plugin.json manifest 配置、目录布局、`${CLAUDE_PLUGIN_ROOT}` 变量、组件自动发现机制。

**附带示例：** `minimal-plugin.md`、`standard-plugin.md`、`advanced-plugin.md`

### skill-development

**触发时机：** 创建 Skill、添加 Skill 到插件

**内容：** Skill 结构、YAML frontmatter、description 编写技巧、渐进式信息披露。

### command-development

**触发时机：** 创建斜杠命令、定义命令参数

**内容：** YAML frontmatter 字段、动态参数、Bash 执行、AskUserQuestion 交互模式。

**附带参考：** `frontmatter-reference.md`、`interactive-commands.md`、`testing-strategies.md`

### agent-development

**触发时机：** 创建 Agent、编写子 Agent

**内容：** Agent frontmatter、system prompt 设计、触发条件、工具权限、颜色配置。

**附带参考：** `system-prompt-design.md`、`triggering-examples.md`、`validate-agent.sh`

### hook-development

**触发时机：** 创建 Hook、实现事件自动化

**支持的事件类型：** PreToolUse、PostToolUse、Stop、SubagentStop、SessionStart、SessionEnd、UserPromptSubmit、PreCompact、Notification

**附带脚本：** `hook-linter.sh`、`test-hook.sh`、`validate-hook-schema.sh`

### mcp-integration

**触发时机：** 添加 MCP 服务器、集成外部服务

**内容：** `.mcp.json` 配置、服务器类型（SSE、stdio、HTTP、WebSocket）、认证方式。

**附带示例：** `stdio-server.json`、`sse-server.json`、`http-server.json`

### plugin-settings

**触发时机：** 插件需要用户配置

**内容：** `.claude/plugin-name.local.md` 模式、YAML frontmatter 存储配置、解析技巧。

**附带脚本：** `parse-frontmatter.sh`、`validate-settings.sh`

---

## Claude MD Management — CLAUDE.md 管理

> 来源：claude-plugins-official (Anthropic) | 版本：1.0.0

### claude-md-improver

**触发时机：** 用户要求检查、审计、更新、改进 CLAUDE.md 文件

**工作流：**
1. 扫描仓库中所有 CLAUDE.md 文件
2. 对照质量模板评估
3. 输出质量报告
4. 进行针对性更新

**附带参考：**
- `quality-criteria.md` — 质量评估标准
- `templates.md` — CLAUDE.md 模板
- `update-guidelines.md` — 更新指南

---

## Merge Verified — 安全合并工作流

> 来源：本仓库自定义 | 版本：1.0.0

### merge-verified

**触发时机：** 所有 VERIFY.md 项目验证通过，准备将 dev 合并到 main

**工作流：**
1. 检查 VERIFY.md，确认所有条目为 `[x]`
2. 对所有改动的 `.sh` 文件执行 `bash -n` 语法检查
3. 展示合并摘要，等待用户确认
4. 执行合并（stash → checkout main → merge → checkout dev → pop stash）
5. 验证合并结果

**核心理念：** 多重检查门控防止未验证代码进入稳定分支。任何一步失败立即停止。

**最佳实践：**
- 不要跳过 VERIFY.md 检查——哪怕只有一项未完成
- 合并后不自动 push，留给用户手动确认
- 配合 `bash-syntax-check` hook 使用效果更佳

---

## Best Practices / 最佳实践

### Skill 编写要点

1. **`description` 是灵魂** — Claude 根据 description 决定是否自动加载。写清楚具体的触发短语和场景
2. **渐进式披露** — SKILL.md 放核心指令，详细参考放 `references/`，示例放 `examples/`
3. **单一职责** — 每个 Skill 聚焦一个领域，避免触发条件重叠
4. **包含反模式** — 告诉 Claude 什么 **不该做** 和什么 **该做** 同样重要

### Superpowers 推荐工作流

```
brainstorming → writing-plans → executing-plans → verification-before-completion → finishing-a-development-branch
                                      ↑
                          test-driven-development
                          systematic-debugging
                          dispatching-parallel-agents
```

**典型开发流程：**
1. 新功能？先 **brainstorming** 探索需求
2. 复杂任务？用 **writing-plans** 拆解步骤
3. 写代码？按 **test-driven-development** 先测试后实现
4. 遇到 bug？用 **systematic-debugging** 系统排查
5. 独立子任务？**dispatching-parallel-agents** 并行处理
6. 完成了？**verification-before-completion** 确认证据
7. 准备合并？**finishing-a-development-branch** 选择集成方式

### 安装方式

这些 Skills 来自以下插件，在 Claude Code 中运行 `/plugin` 安装：

```
/plugin install superpowers@claude-plugins-official
/plugin install plugin-dev@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
```

或直接将本目录中的 Skill 复制到 `~/.claude/skills/` 使用：

```bash
# 安装单个 Skill（全局）
cp -R skills/superpowers/systematic-debugging ~/.claude/skills/

# 安装整套 Superpowers
cp -R skills/superpowers/* ~/.claude/skills/
```
