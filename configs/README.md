# Configs

Claude Code 配置文件，通过 `scripts/sync-configs.sh` 与本地 `~/.claude/` 保持双向同步。

## Sync / 同步机制

本目录中的配置文件是 `~/.claude/` 下实际运行配置的镜像。通过同步脚本和 Dashboard 实现远程管理：

```bash
# 查看同步状态
bash scripts/sync-configs.sh status

# 本地改了配置 → 推到仓库
bash scripts/sync-configs.sh push

# Dashboard 上编辑了 → 拉到本地
git pull && bash scripts/sync-configs.sh pull
```

## Files / 文件说明

### settings.json

全局配置文件，安装位置：`~/.claude/settings.json`

包含以下设置：
- **model**: 默认使用的模型（当前：`opus[1m]`）
- **env**: 环境变量（Agent Teams 开关、代理配置）
- **permissions**: 全局工具权限白名单
- **hooks**: 事件钩子（Notification、Stop、UserPromptSubmit）
- **statusLine**: 自定义状态栏命令
- **enabledPlugins**: 已启用插件列表（19 个）
- **extraKnownMarketplaces**: 第三方插件源
- **effortLevel**: 推理强度

### settings.local.json

本地权限覆盖文件，安装位置：`~/.claude/settings.local.json`

包含以下设置：
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

## Usage / 使用方式

```bash
# 推荐：使用 sync-configs.sh 一键同步
bash scripts/sync-configs.sh pull   # 从仓库安装到本地
bash scripts/sync-configs.sh push   # 从本地推送到仓库

# 或手动安装
cp settings.json ~/.claude/settings.json
cp CLAUDE.md ~/.claude/CLAUDE.md

# 安装推荐插件（在 Claude Code 中逐个运行）
/plugin install superpowers@claude-plugins-official
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
# ... 完整列表见 recommended-plugins.json
```

> 注意：`sync-configs.sh pull` 会自动备份原文件到 `~/.claude/backups/`。
