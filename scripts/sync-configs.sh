#!/bin/bash
# Sync Local Claude Configs with Repository
# 双向同步 ~/.claude/ 配置文件到仓库 configs/ 目录
# 用法: bash scripts/sync-configs.sh [push|pull|status]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_HOME="${HOME}/.claude"
CONFIGS_DIR="${REPO_ROOT}/configs"

# ─── 同步文件清单 ───
# 格式: "本地路径:仓库路径:描述"
SYNC_FILES=(
  "${CLAUDE_HOME}/CLAUDE.md:${CONFIGS_DIR}/CLAUDE.md:Global instructions"
  "${CLAUDE_HOME}/settings.json:${CONFIGS_DIR}/settings.json:Global settings (hooks, plugins, model)"
  "${CLAUDE_HOME}/settings.local.json:${CONFIGS_DIR}/settings.local.json:Local permission overrides"
)

# ─── 目录同步清单 ───
# 格式: "本地目录:仓库目录:是否脱敏"
SYNC_DIRS=(
  "${CLAUDE_HOME}/commands:${REPO_ROOT}/commands:sanitize"
)

# ─── 脱敏规则 ───
# 匹配密码、token、凭证等敏感信息，替换为 <REDACTED>
sanitize_file() {
  local src="$1" dst="$2"
  sed \
    -e 's|pw=[^"&[:space:]]*|pw=<REDACTED>|g' \
    -e 's|://[^:@]*:[^@]*@|://<USER>:<REDACTED>@|g' \
    -e 's|-f [a-z0-9]\{20,\}:[0-9]\{5,\}|-f <REDACTED>|g' \
    -e 's|socks5://[^[:space:]"]*|socks5://<REDACTED>|g' \
    -e 's|密码[：:][[:space:]]*`[^`]*`|密码: `<REDACTED>`|g' \
    -e 's|secret[：:][[:space:]]*`[^`]*`|secret: `<REDACTED>`|g' \
    "$src" > "$dst"
}

# ─── 颜色输出 ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${CYAN}[sync]${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}[sync]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[sync]${NC} %s\n" "$1"; }
err()   { printf "${RED}[sync]${NC} %s\n" "$1" >&2; }

# ─── 文件比较 ───
files_differ() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ] || [ ! -f "$dst" ]; then
    return 0  # differ if either missing
  fi
  ! diff -q "$src" "$dst" >/dev/null 2>&1
}

# ─── Status: 显示同步状态 ───
do_status() {
  info "Comparing local ~/.claude/ with repo configs/"
  echo ""

  local any_diff=false
  for entry in "${SYNC_FILES[@]}"; do
    IFS=':' read -r local_path repo_path desc <<< "$entry"
    local local_name
    local_name=$(basename "$local_path")

    if [ ! -f "$local_path" ] && [ ! -f "$repo_path" ]; then
      printf "  %-25s  ${YELLOW}MISSING${NC} (both)\n" "$local_name"
      continue
    fi

    if [ ! -f "$local_path" ]; then
      printf "  %-25s  ${YELLOW}LOCAL MISSING${NC} — exists only in repo\n" "$local_name"
      any_diff=true
      continue
    fi

    if [ ! -f "$repo_path" ]; then
      printf "  %-25s  ${YELLOW}REPO MISSING${NC} — exists only locally\n" "$local_name"
      any_diff=true
      continue
    fi

    if files_differ "$local_path" "$repo_path"; then
      printf "  %-25s  ${RED}OUT OF SYNC${NC}\n" "$local_name"

      # 显示简短 diff 统计
      local added removed
      added=$(diff "$repo_path" "$local_path" 2>/dev/null | grep -c '^>' || true)
      removed=$(diff "$repo_path" "$local_path" 2>/dev/null | grep -c '^<' || true)
      printf "    ${GREEN}+%s${NC} / ${RED}-%s${NC} lines (local vs repo)\n" "$added" "$removed"

      any_diff=true
    else
      printf "  %-25s  ${GREEN}IN SYNC${NC}\n" "$local_name"
    fi
  done

  echo ""
  # 检查目录同步
  for dir_entry in "${SYNC_DIRS[@]}"; do
    IFS=':' read -r local_dir repo_dir mode <<< "$dir_entry"
    local dirname
    dirname=$(basename "$local_dir")

    if [ ! -d "$local_dir" ]; then
      printf "  %-25s  ${YELLOW}LOCAL DIR MISSING${NC}\n" "$dirname/"
      continue
    fi

    local local_count repo_count
    local_count=$(find "$local_dir" -maxdepth 1 -name "*.md" -not -name "README.md" 2>/dev/null | wc -l | tr -d ' ')
    repo_count=$(find "$repo_dir" -maxdepth 1 -name "*.md" -not -name "README.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$local_count" != "$repo_count" ]; then
      printf "  %-25s  ${RED}OUT OF SYNC${NC} (local: %s, repo: %s files)\n" "$dirname/" "$local_count" "$repo_count"
      any_diff=true
    else
      # Check if any files differ in content
      local dir_diff=false
      for f in "$local_dir"/*.md; do
        [ -f "$f" ] || continue
        local bname
        bname=$(basename "$f")
        [ "$bname" = "README.md" ] && continue
        local repo_f="$repo_dir/$bname"
        if [ ! -f "$repo_f" ]; then
          dir_diff=true
          break
        fi
        # For sanitized dirs, compare sanitized version
        if [ "$mode" = "sanitize" ]; then
          local tmp_sanitized
          tmp_sanitized=$(mktemp)
          sanitize_file "$f" "$tmp_sanitized"
          if files_differ "$tmp_sanitized" "$repo_f"; then
            dir_diff=true
          fi
          rm -f "$tmp_sanitized"
        else
          if files_differ "$f" "$repo_f"; then
            dir_diff=true
          fi
        fi
        $dir_diff && break
      done

      if $dir_diff; then
        printf "  %-25s  ${RED}OUT OF SYNC${NC} (content differs)\n" "$dirname/"
        any_diff=true
      else
        printf "  %-25s  ${GREEN}IN SYNC${NC} (%s files)\n" "$dirname/" "$local_count"
      fi
    fi
  done

  echo ""
  if $any_diff; then
    warn "Run 'sync-configs.sh push' to update repo from local"
    warn "Run 'sync-configs.sh pull' to update local from repo"
  else
    ok "All configs are in sync!"
  fi
}

# ─── Push: 本地 → 仓库 ───
do_push() {
  info "Pushing local configs to repo..."

  local changed=false
  for entry in "${SYNC_FILES[@]}"; do
    IFS=':' read -r local_path repo_path desc <<< "$entry"
    local fname
    fname=$(basename "$local_path")

    if [ ! -f "$local_path" ]; then
      warn "Skip $fname — not found at $local_path"
      continue
    fi

    if [ -f "$repo_path" ] && ! files_differ "$local_path" "$repo_path"; then
      ok "$fname — already in sync"
      continue
    fi

    cp "$local_path" "$repo_path"
    ok "$fname — copied to configs/"
    changed=true
  done

  # 同步目录
  for dir_entry in "${SYNC_DIRS[@]}"; do
    IFS=':' read -r local_dir repo_dir mode <<< "$dir_entry"
    local dirname
    dirname=$(basename "$local_dir")

    if [ ! -d "$local_dir" ]; then
      warn "Skip $dirname/ — directory not found"
      continue
    fi

    for f in "$local_dir"/*.md; do
      [ -f "$f" ] || continue
      local bname
      bname=$(basename "$f")
      [ "$bname" = "README.md" ] && continue

      local repo_f="$repo_dir/$bname"

      if [ "$mode" = "sanitize" ]; then
        local tmp_sanitized
        tmp_sanitized=$(mktemp)
        sanitize_file "$f" "$tmp_sanitized"

        if [ -f "$repo_f" ] && ! files_differ "$tmp_sanitized" "$repo_f"; then
          rm -f "$tmp_sanitized"
          continue
        fi

        cp "$tmp_sanitized" "$repo_f"
        rm -f "$tmp_sanitized"
        ok "$dirname/$bname — sanitized and copied"
        changed=true
      else
        if [ -f "$repo_f" ] && ! files_differ "$f" "$repo_f"; then
          continue
        fi
        cp "$f" "$repo_f"
        ok "$dirname/$bname — copied"
        changed=true
      fi
    done
  done

  if $changed; then
    echo ""
    info "Files updated. Review changes with:"
    echo "  cd $REPO_ROOT && git diff"
    echo ""
    info "To commit and deploy:"
    echo "  git add configs/ commands/ && git commit -m 'sync: update local Claude configs'"
    echo "  git push"
  else
    ok "Nothing to push — all configs already in sync"
  fi
}

# ─── Pull: 仓库 → 本地 ───
do_pull() {
  info "Pulling repo configs to local..."

  local changed=false
  for entry in "${SYNC_FILES[@]}"; do
    IFS=':' read -r local_path repo_path desc <<< "$entry"
    local fname
    fname=$(basename "$local_path")

    if [ ! -f "$repo_path" ]; then
      warn "Skip $fname — not found in repo configs/"
      continue
    fi

    if [ -f "$local_path" ] && ! files_differ "$local_path" "$repo_path"; then
      ok "$fname — already in sync"
      continue
    fi

    # 备份原文件
    if [ -f "$local_path" ]; then
      local backup_dir="${CLAUDE_HOME}/backups"
      mkdir -p "$backup_dir"
      local timestamp
      timestamp=$(date +%Y%m%d-%H%M%S)
      cp "$local_path" "${backup_dir}/${fname}.${timestamp}.bak"
      info "$fname — backed up to backups/${fname}.${timestamp}.bak"
    fi

    cp "$repo_path" "$local_path"
    ok "$fname — updated from repo"
    changed=true
  done

  # Pull 目录（注意：pull 不脱敏，仓库里的脱敏内容覆盖本地没意义，跳过 sanitize 目录）
  for dir_entry in "${SYNC_DIRS[@]}"; do
    IFS=':' read -r local_dir repo_dir mode <<< "$dir_entry"
    local dirname
    dirname=$(basename "$local_dir")

    if [ "$mode" = "sanitize" ]; then
      warn "Skip $dirname/ — sanitized directory, pull not supported (would overwrite originals with redacted content)"
      continue
    fi

    if [ ! -d "$repo_dir" ]; then
      continue
    fi

    mkdir -p "$local_dir"
    for f in "$repo_dir"/*.md; do
      [ -f "$f" ] || continue
      local bname
      bname=$(basename "$f")
      [ "$bname" = "README.md" ] && continue
      local local_f="$local_dir/$bname"

      if [ -f "$local_f" ] && ! files_differ "$f" "$local_f"; then
        continue
      fi

      if [ -f "$local_f" ]; then
        local backup_dir="${CLAUDE_HOME}/backups"
        mkdir -p "$backup_dir"
        local timestamp
        timestamp=$(date +%Y%m%d-%H%M%S)
        cp "$local_f" "${backup_dir}/${bname}.${timestamp}.bak"
      fi

      cp "$f" "$local_f"
      ok "$dirname/$bname — updated from repo"
      changed=true
    done
  done

  if $changed; then
    echo ""
    ok "Local configs updated. Changes take effect in new Claude Code sessions."
  else
    ok "Nothing to pull — all configs already in sync"
  fi
}

# ─── Diff: 显示完整差异 ───
do_diff() {
  for entry in "${SYNC_FILES[@]}"; do
    IFS=':' read -r local_path repo_path desc <<< "$entry"
    local fname
    fname=$(basename "$local_path")

    if [ ! -f "$local_path" ] || [ ! -f "$repo_path" ]; then
      continue
    fi

    if files_differ "$local_path" "$repo_path"; then
      echo ""
      printf "${CYAN}━━━ %s (%s) ━━━${NC}\n" "$fname" "$desc"
      diff --color=auto -u "$repo_path" "$local_path" \
        --label "repo: configs/$fname" \
        --label "local: ~/.claude/$fname" || true
    fi
  done
}

# ─── Main ───
case "${1:-status}" in
  push)
    do_push
    ;;
  pull)
    do_pull
    ;;
  status)
    do_status
    ;;
  diff)
    do_diff
    ;;
  *)
    echo "Usage: $(basename "$0") [push|pull|status|diff]"
    echo ""
    echo "  status  Show sync state (default)"
    echo "  push    Copy local ~/.claude/ configs to repo"
    echo "  pull    Copy repo configs to local ~/.claude/"
    echo "  diff    Show full diff between local and repo"
    exit 1
    ;;
esac
