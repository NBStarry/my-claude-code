# Global Rules
<!-- Install: cp configs/CLAUDE.md ~/.claude/CLAUDE.md -->

## Git Commit Rules
- Code changes and related documentation updates must be in the same commit — never split them into separate commits

## Editing Rules
- Before editing any file, always re-read its current content with a fresh `Read` — never edit based on assumed or stale content

## Shell Scripts & Debugging
- When fixing shell scripts, always test runtime behavior with a real invocation — do not rely solely on reading the code
- For tmux operations: use `capture-pane -S -` for full scrollback
- Build and test regex patterns incrementally in Bash one-liners before embedding in scripts
- All `.sh` files must pass `bash -n` syntax check before committing

## Approach-First Workflow
- For shell script fixes, regex extraction, and non-trivial debugging: propose the approach (with specific commands/flags) before executing
- Identify root cause first, then propose fix — do not jump directly into implementation

## Agent Teams Rules
- Team Lead: always use `model: "opus"`
- Teammates: default to `model: "sonnet"`, use `model: "opus"` for complex tasks (architecture, multi-file refactoring, deep debugging)
- Never use haiku for teammates
- Verify file existence on disk before claiming files exist
- Never merge to `main` without all VERIFY.md items marked `[x]`
- Confirm teammate permissions before assigning tasks
- Break complex multi-agent setups into smaller validated steps
- Provide checkpoint summaries after each major step
