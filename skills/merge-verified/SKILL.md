---
name: merge-verified
description: Use when all VERIFY.md items are verified and ready to merge dev to main — enforces verification gates, syntax checks, and safe merge workflow
version: 1.0.0
---

# Merge Verified Branch

## Overview

Safe merge workflow that enforces verification gates before merging `dev` to `main`. Prevents unverified code from reaching the stable branch.

**Core principle:** Verify everything → Syntax check → Merge → Confirm.

**Announce at start:** "I'm using the merge-verified skill to safely merge dev to main."

## The Process

### Step 1: Check VERIFY.md

Read `VERIFY.md` and confirm all items are marked complete:

```bash
# Check for any unchecked items
grep -c '^\- \[ \]' VERIFY.md
```

**If unchecked items exist:**
```
Cannot merge — VERIFY.md has <N> unverified items:

[List unchecked items]

Please verify these items first, then run this skill again.
```

Stop. Do not proceed.

**If all items are `[x]`:** Continue to Step 2.

### Step 2: Syntax Check All Shell Scripts

Run `bash -n` on every `.sh` file that was modified on `dev` since the last merge:

```bash
# Find changed .sh files between main and dev
git diff main...dev --name-only --diff-filter=ACM | grep '\.sh$'

# Syntax check each one
for f in $(git diff main...dev --name-only --diff-filter=ACM | grep '\.sh$'); do
    bash -n "$f" || { echo "Syntax error in $f"; exit 1; }
done
```

**If any syntax check fails:**
```
Cannot merge — syntax errors found:

[Show errors]

Fix these errors on dev first.
```

Stop. Do not proceed.

**If all pass:** Continue to Step 3.

### Step 3: Show Merge Summary

Present a summary for user confirmation:

```
Ready to merge dev → main

Commits to merge:
[git log main..dev --oneline]

Files changed:
[git diff main...dev --stat]

VERIFY.md: All <N> items verified ✓
Syntax check: All .sh files pass ✓

Proceed with merge?
```

Wait for user confirmation before proceeding.

### Step 4: Execute Merge

```bash
# Stash any uncommitted changes
git stash --include-untracked

# Switch to main and merge
git checkout main
git merge dev

# Switch back to dev
git checkout dev

# Restore stash if any
git stash pop 2>/dev/null || true
```

### Step 5: Post-Merge Verification

```bash
# Confirm merge was successful
git log main -1 --oneline

# Confirm dev is still intact
git log dev -1 --oneline
```

Report:
```
Merge complete ✓
- main is now at: [commit hash and message]
- dev branch preserved

Note: Changes are local only. Push with `git push origin main` when ready.
```

## Common Mistakes

**Merging with unchecked VERIFY.md items**
- **Problem:** Unverified code reaches main
- **Fix:** Always check VERIFY.md first, refuse to proceed if any `[ ]` exists

**Skipping syntax check**
- **Problem:** Broken scripts on main branch
- **Fix:** Always run `bash -n` on all changed `.sh` files

**Auto-pushing after merge**
- **Problem:** User may want to review before pushing
- **Fix:** Never push automatically — only merge locally

**Forgetting to stash**
- **Problem:** Uncommitted changes block checkout
- **Fix:** Always stash before switching branches

## Red Flags

**Never:**
- Merge with any unchecked VERIFY.md items
- Skip the syntax check step
- Push to remote without explicit user request
- Force merge or use `--no-ff` unless requested

**Always:**
- Read VERIFY.md before anything else
- Run `bash -n` on all modified `.sh` files
- Show merge summary and wait for confirmation
- Stash uncommitted changes before switching branches
- Switch back to dev after merge
