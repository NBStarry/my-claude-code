# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A public repository for sharing Claude Code configurations, custom scripts, hooks, skills, agents, and commands. Documentation is written in Chinese with English section headers. No build system or tests — this is a configuration/documentation repo.

## Architecture

### QQ Bidirectional Communication System

The most complex feature spans `scripts/` and `hooks/`:

- **Outbound** (`scripts/notify-qq.sh`): Hook-triggered script that sends formatted notifications (permission requests, idle prompts, task completion) to phone via LLOneBot HTTP API
- **Inbound** (`scripts/qq-bridge.sh`): WebSocket daemon that listens for QQ messages and injects them into Claude Code's tmux pane via `tmux send-keys`
- **Hook wiring** (`hooks/notification.json`): Connects `Notification` (permission_prompt, idle_prompt) and `Stop` events to `notify-qq.sh`

Both scripts share config constants (`QQ_USER`, `LLONEBOT_PORT`, `LLONEBOT_WS_PORT`) that must match.

### Directory Structure Convention

Each content directory follows the same pattern:
- `README.md` — explains the directory's purpose and usage
- `examples/` — contains template files showing the expected format
- Production files live at the directory root (not in `examples/`)

### Extension Format Reference

| Type | Location | Format |
|------|----------|--------|
| Skills | `skills/<name>/SKILL.md` | Markdown with YAML frontmatter (`name`, `description`, `version`) |
| Agents | `agents/<name>.md` | Markdown with YAML frontmatter (`name`, `description`, `model`, `tools`) |
| Commands | `commands/<name>.md` | Markdown with YAML frontmatter (`description`, `argument-hint`, `allowed-tools`) |
| Hooks | `hooks/<name>.json` | JSON with `hooks` object keyed by event type |
| Configs | `configs/<name>.json` | Claude Code settings files |

### configs/CLAUDE.md

Contains global Claude Code instructions meant to be installed at `~/.claude/CLAUDE.md`. Currently enforces: code changes and related documentation updates must be in the same commit.

## Git Branching Workflow

- **`main`** — stable branch, only contains user-verified configurations
- **`dev`** — development branch, all changes go here first

### Rules

1. **All changes must go to `dev` first** — never commit unverified changes directly to `main`
2. Every `dev` commit must include a corresponding entry in `VERIFY.md` (in the same commit)
3. User manually tests, then checks off items in `VERIFY.md`
4. Only merge to `main` when all related `VERIFY.md` entries are marked `[x]`
5. Merge: `git checkout main && git merge dev`, then push

### VERIFY.md Entry Format

```markdown
- [ ] **Change summary** (commit: abc1234, date: YYYY-MM-DD)
  - 验证方法：how to test
  - 预期效果：expected result
  - 实际效果：（fill after verification）
```

## File Conventions

- Shell scripts: `#!/bin/bash` shebang, executable permission, comment header explaining purpose
- JSON: 2-space indentation
- Naming: `kebab-case` for all files (`.sh`, `.json`, `.md`)
- Markdown with YAML frontmatter for skills, agents, commands
- Configuration examples use placeholder values where credentials would appear
