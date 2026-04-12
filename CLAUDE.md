# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A public repository for sharing Claude Code configurations, custom scripts, hooks, skills, agents, and commands. Documentation is written in Chinese with English section headers. No build system or tests — this is a configuration/documentation repo.

**Tech stack**: Shell (bash scripts), Markdown, JSON, HTML/CSS/JavaScript. Primary deployment target is GitHub Pages. All `.sh` files must pass `bash -n` syntax check before committing.

## Quick Start

**Prerequisites**: `jq`, `curl`, `tmux` (install via `brew install jq curl tmux` or `apt-get install jq curl tmux`)

```bash
# Clone and switch to dev branch
git clone https://github.com/NBStarry/my-claude-code.git
cd my-claude-code && git checkout dev

# Sync configs from repo to local (or use push to go the other way)
bash scripts/sync-configs.sh pull

# Install Telegram notifications
cp configs/telegram.conf.example ~/.claude/telegram.conf  # edit with your bot token + chat ID

# Start Telegram bridge daemon (in tmux)
bash scripts/telegram-bridge.sh &
```

## Architecture

### Bidirectional Communication System (Telegram)

The most complex feature spans `scripts/` and `hooks/`:

- **Outbound** (`scripts/notify-telegram.sh`): Hook-triggered script that sends formatted notifications via Telegram Bot API
- **Inbound** (`scripts/telegram-bridge.sh`): Long-polling daemon that fetches Telegram messages and injects them into Claude Code's tmux pane via `tmux send-keys`. Supports multi-pane routing — detects all Claude Code instances across tmux sessions, with `/list` and `/connect <session>` commands for switching
- **Hook wiring** (`hooks/notification.telegram.json`): Connects `Notification` (permission_prompt, idle_prompt) and `Stop` events to `notify-telegram.sh`
- **Config** (`configs/telegram.conf.example`): Shared configuration for bot token and chat ID

Both scripts load config from `~/.claude/telegram.conf`. Requires `jq`, `curl`, and `tmux`. QQ variant has been deprecated to `deprecated/`.

### Status Line

`scripts/statusline.sh` — Custom Claude Code status bar showing `user@host:dir`, model name, Git branch, and context usage percentage. Installed via Claude Code settings.

### Config Sync System

`scripts/sync-configs.sh` — Bidirectional sync between local `~/.claude/` and repo `configs/`. Keeps the GitHub Pages Dashboard in sync with the actual running configuration.

- **push**: Copy local configs to repo (for committing and deploying to Dashboard)
- **pull**: Copy repo configs to local (with automatic backup to `~/.claude/backups/`)
- **status**: Show colored sync state comparison
- **diff**: Show full unified diff between local and repo

Synced files: `CLAUDE.md`, `settings.json`, `settings.local.json`. The Dashboard at GitHub Pages provides browser-based CRUD editing via GitHub Contents API, enabling remote config management from any device.

### Dashboard (GitHub Pages)

`site/` — Single-page web dashboard deployed to GitHub Pages via GitHub Actions. Shows skills, hooks, configs, scripts, plugins, and verification status. Configs page displays metadata tags (model, plugin count, hook events) and supports inline editing via GitHub API with diff preview.

- **Data generation** (`scripts/generate-site-data.sh`): Scans repo directories, extracts metadata, outputs `site/data.json`
- **CRUD editor** (`site/js/editor.js`): GitHub Contents API integration with token auth, diff preview, and live Markdown preview
- **Deployment** (`.github/workflows/deploy-dashboard.yml`): Triggers on push to main, runs data generation, deploys to GitHub Pages

### Shell Script Safety Hook

`hooks/bash-syntax-check.json` — PreToolUse hook that blocks `git commit` if any staged `.sh` files haven't passed `bash -n` syntax check in the current conversation. This enforces the "syntax check before commit" rule at the tool level.

### Deprecated

`deprecated/` — Contains retired QQ-based scripts (`notify-qq.sh`, `qq-bridge.sh`, etc.) preserved for reference. Do not modify or extend these files.

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
| Plugins | `configs/recommended-plugins.json` | Recommended plugin list with install commands |

**Note on skills/**: Contains synced skill collections from official plugins (`superpowers`, `plugin-dev`, `claude-md-management`) plus custom skills like `merge-verified`. See `skills/README.md` for detailed documentation of each skill's trigger conditions and usage.

### Global Rules (configs/CLAUDE.md)

Contains global Claude Code instructions meant to be installed at `~/.claude/CLAUDE.md`. Currently enforces:
- Code changes and related documentation updates must be in the same commit
- Edit files only after fresh Read — never assume content
- Shell scripts: test runtime behavior, use `bash -n` before commit, incremental regex testing
- Approach-first workflow: propose approach before executing non-trivial fixes
- Agent Teams: Lead uses Opus, teammates default to Sonnet, verify files on disk, checkpoint summaries

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

## Behavioral Rules

Editing safety, shell debugging, approach-first workflow, and Agent Teams rules are defined in the global `~/.claude/CLAUDE.md` (source: `configs/CLAUDE.md`). Those rules apply to all projects and are not repeated here to avoid drift.
