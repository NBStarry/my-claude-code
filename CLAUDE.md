# CLAUDE.md - Project Conventions

This is a public repository for sharing Claude Code configurations, scripts, and extensions.

## Project Overview

- **Purpose**: Store and share Claude Code configurations, custom scripts, hooks, skills, agents, and commands
- **Language**: Documentation is written in Chinese with English section headers for international discoverability
- **Audience**: Claude Code users looking for configuration references and inspiration

## Directory Conventions

- `configs/` - Configuration files (settings.json, settings.local.json)
- `scripts/` - Executable scripts (statusline, utilities)
- `hooks/` - Hook configurations and examples (PreToolUse, PostToolUse, Stop, UserPromptSubmit)
- `skills/` - Skill definitions following the SKILL.md pattern
- `agents/` - Agent definitions as markdown files with YAML frontmatter
- `commands/` - Slash command definitions as markdown files with YAML frontmatter

## File Conventions

- All shell scripts must have `#!/bin/bash` shebang and be marked executable
- All scripts must include a comment header explaining their purpose
- JSON files must be valid and properly formatted (2-space indentation)
- Markdown files use YAML frontmatter where applicable (skills, agents, commands)
- Use UTF-8 encoding for all files

## Documentation Style

- README files in each directory explain what the directory contains and how to use its contents
- The main README.md uses Chinese for descriptions with English section headers
- Code comments in scripts may be in Chinese or English

## Naming Conventions

- Scripts: `kebab-case.sh` (e.g., `statusline.sh`)
- Hook configs: `kebab-case.json` (e.g., `warn-dangerous-rm.json`)
- Skills: directory name matches skill name, `SKILL.md` inside
- Agents: `kebab-case.md` (e.g., `code-reviewer.md`)
- Commands: `kebab-case.md` (e.g., `deploy-check.md`)

## Git Branching Workflow

- **`main`** — 稳定分支，仅包含用户亲自验证通过的配置
- **`dev`** — 开发分支，所有新增和修改先提交到这里

### Rules / 规则

1. **所有改动必须先提交到 `dev` 分支**，禁止直接向 `main` 提交未验证的改动
2. 每次向 `dev` 提交前，必须先在 `VERIFY.md` 中添加对应的待验证记录，并包含在同一个 commit 中
3. 用户亲自测试改动效果后，在 `VERIFY.md` 中勾选对应条目
4. 只有 `VERIFY.md` 中相关条目全部标记为 `[x]` 后，才可将 `dev` 合并到 `main`
5. 合并方式：`git checkout main && git merge dev`，然后推送

### VERIFY.md Format / 验证记录格式

```markdown
- [ ] **改动简述** (commit: abc1234, date: YYYY-MM-DD)
  - 验证方法：如何测试
  - 预期效果：期望结果
  - 实际效果：（验证后填写）
```

## When Adding New Content

1. **Switch to `dev` branch first** (`git checkout dev`)
2. Place the file in the appropriate directory
3. Update the directory's README.md if needed
4. Update the root README.md if adding a new category
5. Include usage instructions and any dependencies
6. Add a verification entry in `VERIFY.md`（必须包含在同一个 commit 中）
7. Commit and push to `dev`
8. Wait for user verification before merging to `main`

## Sensitive Information

- NEVER commit API keys, tokens, or secrets
- Configuration examples should use placeholder values where credentials would appear
