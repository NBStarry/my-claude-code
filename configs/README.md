# Configs

Claude Code 配置文件示例。

## Files / 文件说明

### settings.json

全局配置文件，安装位置：`~/.claude/settings.json`

包含以下设置：
- **model**: 默认使用的模型
- **statusLine**: 自定义状态栏命令

### settings.local.json

项目级配置文件，安装位置：`<project-root>/.claude/settings.local.json`

包含以下设置：
- **outputStyle**: 输出风格（如 Explanatory）
- **permissions**: 工具权限预授权列表

### CLAUDE.md

全局用户级指令文件，安装位置：`~/.claude/CLAUDE.md`

所有项目的 Claude Code 会话都会加载此文件中的规则。包含：
- **Git Commit Rules**: 代码与文档同 commit 等全局约定
- **Agent Teams Rules**: Team Lead 用 Opus，Teammate 默认 Sonnet

### recommended-plugins.json

推荐的 Claude Code 插件列表。在 Claude Code 中运行 `/plugin` 安装。

| Plugin | Description | Author |
|--------|-------------|--------|
| **superpowers** | 核心技能库：TDD、系统化调试、并行 Agent、计划执行等 | Jesse Vincent |
| **commit-commands** | Git 工作流：/commit、/push、/pr | Anthropic |
| **code-review** | 自动化代码审查，多 Agent 协作 + 置信度评分 | Anthropic |
| **feature-dev** | 功能开发工作流：探索 → 架构 → 审查 | Anthropic |
| **code-simplifier** | 代码简化 Agent，提升可读性 | Anthropic |
| **security-guidance** | 安全提醒 Hook，警告注入/XSS 等隐患 | Anthropic |
| **claude-md-management** | CLAUDE.md 维护：审计、学习捕获、记忆更新 | Anthropic |
| **plugin-dev** | 插件开发工具包 | Anthropic |
| **github** | GitHub MCP 服务器：Issue、PR、搜索 | GitHub |
| **pyright-lsp** | Python Pyright LSP 类型检查 | Anthropic |

### telegram.conf.example

Telegram Bot 配置模板，安装位置：`~/.claude/telegram.conf`

## Usage / 使用方式

```bash
# 全局配置
cp settings.json ~/.claude/settings.json

# 全局指令
cp CLAUDE.md ~/.claude/CLAUDE.md

# 项目级配置（在目标项目根目录下执行）
mkdir -p .claude
cp settings.local.json .claude/settings.local.json

# 安装推荐插件（在 Claude Code 中逐个运行）
/plugin install superpowers@claude-plugins-official
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
# ... 完整列表见 recommended-plugins.json
```

> 注意：请根据你的实际环境修改配置中的路径和参数。
