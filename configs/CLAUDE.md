# Global Rules

## Git Commit Rules
- Code changes and related documentation updates must be in the same commit — never split them into separate commits

## Agent Teams Rules
- Team Lead: always use `model: "opus"`
- Teammates: default to `model: "sonnet"`, use `model: "opus"` for complex tasks (architecture, multi-file refactoring, deep debugging)
- Never use haiku for teammates
