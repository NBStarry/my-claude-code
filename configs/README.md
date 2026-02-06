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

## Usage / 使用方式

```bash
# 全局配置
cp settings.json ~/.claude/settings.json

# 全局指令
cp CLAUDE.md ~/.claude/CLAUDE.md

# 项目级配置（在目标项目根目录下执行）
mkdir -p .claude
cp settings.local.json .claude/settings.local.json
```

> 注意：请根据你的实际环境修改配置中的路径和参数。
