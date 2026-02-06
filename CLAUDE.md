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

## When Adding New Content

1. Place the file in the appropriate directory
2. Update the directory's README.md if needed
3. Update the root README.md if adding a new category
4. Include usage instructions and any dependencies
5. Test scripts locally before committing

## Sensitive Information

- NEVER commit API keys, tokens, or secrets
- Configuration examples should use placeholder values where credentials would appear
