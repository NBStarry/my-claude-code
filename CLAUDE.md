# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A public repository for sharing Claude Code configurations, custom scripts, hooks, skills, agents, and commands. Documentation is written in Chinese with English section headers. No build system or tests — this is a configuration/documentation repo.

**Tech stack**: Shell (bash scripts), Markdown, JSON, HTML/CSS/JavaScript. Primary deployment target is GitHub Pages. All `.sh` files must pass `bash -n` syntax check before committing.

## Architecture

### Bidirectional Communication System (Telegram)

The most complex feature spans `scripts/` and `hooks/`:

- **Outbound** (`scripts/notify-telegram.sh`): Hook-triggered script that sends formatted notifications via Telegram Bot API
- **Inbound** (`scripts/telegram-bridge.sh`): Long-polling daemon that fetches Telegram messages and injects them into Claude Code's tmux pane via `tmux send-keys`. Supports multi-pane routing — detects all Claude Code instances across tmux sessions, with `/list` and `/connect <session>` commands for switching
- **Hook wiring** (`hooks/notification.telegram.json`): Connects `Notification` (permission_prompt, idle_prompt) and `Stop` events to `notify-telegram.sh`
- **Config** (`configs/telegram.conf.example`): Shared configuration for bot token and chat ID

Both scripts load config from `~/.claude/telegram.conf`. QQ variant has been deprecated to `deprecated/`.

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

## Editing Rules

- Before editing any file, always re-read its current content with a fresh `Read` — never assume content from memory or previous reads
- For multi-section edits, re-read between edits if the file structure may have shifted

## Shell Scripts & Debugging

- When fixing shell scripts, always test the actual runtime behavior with a real invocation — do not rely solely on reading the code
- For tmux-related operations: remember `capture-pane -S -` for full scrollback, `-t` for pane targeting
- When extracting data from process command lines (e.g., agent names via `ps`/`sed`/`awk`), build and test the regex incrementally in a Bash one-liner before embedding it in the script
- All `.sh` files must pass `bash -n` syntax check before committing

## Approach-First Workflow

- For shell script fixes, regex extraction, and any non-trivial implementation: propose the approach in 3-5 bullet points (including specific commands/flags) before executing
- Do not jump directly into implementation for debugging tasks — identify root cause first, then propose fix

## Agent Teams / Multi-Agent Workflow

- Always verify file existence on disk (not just in memory) before claiming a file exists or was created
- Never merge to `main` without explicit VERIFY.md confirmation — all items must be `[x]`
- Confirm teammate permissions and routing before assigning tasks
- Break complex multi-agent setups into smaller validated steps — do not launch all roles simultaneously
- After completing each major step, provide a checkpoint summary: (1) what was done, (2) files changed and status, (3) what's next
