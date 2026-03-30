#!/bin/bash
# Generate Site Data for Dashboard
# 扫描仓库中的 skills、hooks、configs、scripts、plugins、VERIFY.md
# 输出统一的 JSON 数据到 site/data.json，供前端 Dashboard 使用

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${REPO_ROOT}/site/data.json"
TMPDIR_DATA=$(mktemp -d)
trap 'rm -rf "$TMPDIR_DATA"' EXIT

# ─── 辅助函数 ───

# 从 Markdown 文件提取 YAML frontmatter 指定字段
get_frontmatter_field() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" || true
}

# 读取 frontmatter 之后的正文
get_content_after_frontmatter() {
  local file="$1"
  # Skip everything up to and including the second ---
  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$file"
}

# 用 jq 转义字符串为合法 JSON string
json_escape() {
  printf '%s' "$1" | jq -Rs .
}

# ─── Skills 扫描 ───

skills_dir="$TMPDIR_DATA/skills"
mkdir -p "$skills_dir"
skill_idx=0

while IFS= read -r skill_file; do
  name=$(get_frontmatter_field "$skill_file" "name")
  description=$(get_frontmatter_field "$skill_file" "description")
  version=$(get_frontmatter_field "$skill_file" "version")

  rel_path="${skill_file#${REPO_ROOT}/}"
  slash_count=$(echo "$rel_path" | tr -cd '/' | wc -c | tr -d ' ')
  if [ "$slash_count" -ge 3 ]; then
    source=$(echo "$rel_path" | cut -d'/' -f2)
  else
    source="custom"
  fi

  get_content_after_frontmatter "$skill_file" > "$TMPDIR_DATA/tmp_content"

  jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --arg version "$version" \
    --arg source "$source" \
    --arg file "$rel_path" \
    --rawfile content "$TMPDIR_DATA/tmp_content" \
    '{name: $name, description: $description, version: $version, source: $source, file: $file, content: $content}' \
    > "$skills_dir/$skill_idx.json"
  skill_idx=$((skill_idx + 1))

done < <(find "${REPO_ROOT}/skills" -name "SKILL.md" -not -path "*/examples/*" 2>/dev/null)

# 合并所有 skill JSON 对象为数组
if ls "$skills_dir"/*.json >/dev/null 2>&1; then
  skills_json=$(jq -s '.' "$skills_dir"/*.json)
else
  skills_json="[]"
fi

# ─── Hooks 扫描 ───

hooks_dir="$TMPDIR_DATA/hooks"
mkdir -p "$hooks_dir"
hook_idx=0

while IFS= read -r hook_file; do
  rel_path="${hook_file#${REPO_ROOT}/}"
  filename=$(basename "$hook_file" .json)
  events=$(jq -c '[.hooks | keys[]]' "$hook_file" 2>/dev/null || echo '[]')
  description=$(jq -r '.description // ""' "$hook_file" 2>/dev/null || echo "")
  cat "$hook_file" > "$TMPDIR_DATA/tmp_content"

  jq -n \
    --arg name "$filename" \
    --arg file "$rel_path" \
    --arg description "$description" \
    --argjson events "$events" \
    --rawfile content "$TMPDIR_DATA/tmp_content" \
    '{name: $name, file: $file, description: $description, events: $events, content: $content}' \
    > "$hooks_dir/$hook_idx.json"
  hook_idx=$((hook_idx + 1))

done < <(find "${REPO_ROOT}/hooks" -name "*.json" -not -path "*/examples/*" 2>/dev/null)

if ls "$hooks_dir"/*.json >/dev/null 2>&1; then
  hooks_json=$(jq -s '.' "$hooks_dir"/*.json)
else
  hooks_json="[]"
fi

# ─── Configs 扫描 ───

configs_dir="$TMPDIR_DATA/configs"
mkdir -p "$configs_dir"
config_idx=0

for config_file in "${REPO_ROOT}"/configs/*.json "${REPO_ROOT}"/configs/*.md; do
  [ -f "$config_file" ] || continue
  rel_path="${config_file#${REPO_ROOT}/}"
  filename=$(basename "$config_file")
  cat "$config_file" > "$TMPDIR_DATA/tmp_content"

  jq -n \
    --arg name "$filename" \
    --arg file "$rel_path" \
    --rawfile content "$TMPDIR_DATA/tmp_content" \
    '{name: $name, file: $file, content: $content}' \
    > "$configs_dir/$config_idx.json"
  config_idx=$((config_idx + 1))
done

if ls "$configs_dir"/*.json >/dev/null 2>&1; then
  configs_json=$(jq -s '.' "$configs_dir"/*.json)
else
  configs_json="[]"
fi

# ─── Scripts 扫描 ───

scripts_json="[]"
total_scripts_lines=0

for script_file in "${REPO_ROOT}"/scripts/*.sh; do
  [ -f "$script_file" ] || continue
  filename=$(basename "$script_file")

  # 跳过自身和 export-memory.sh
  if [ "$filename" = "generate-site-data.sh" ] || [ "$filename" = "export-memory.sh" ]; then
    continue
  fi

  rel_path="${script_file#${REPO_ROOT}/}"
  lines=$(wc -l < "$script_file")
  total_scripts_lines=$((total_scripts_lines + lines))

  # 提取第2-4行注释作为描述
  description=$(sed -n '2,4p' "$script_file" | grep '^#' | sed 's/^#[[:space:]]*//' | tr '\n' ' ' | sed 's/[[:space:]]*$//')

  # 从注释中提取依赖列表 (requires/depends: jq, curl, tmux 等)
  deps=$(grep -i 'requires\|depends\|依赖' "$script_file" | head -3 | sed 's/^#[[:space:]]*//' | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)

  scripts_json=$(jq -n \
    --argjson arr "$scripts_json" \
    --arg name "$filename" \
    --arg file "$rel_path" \
    --arg description "$description" \
    --argjson lines "$lines" \
    --arg deps "$deps" \
    '$arr + [{name: $name, file: $file, description: $description, lines: $lines, deps: $deps}]'
  )
done

# ─── Plugins 扫描 ───

plugins_json="[]"
plugins_file="${REPO_ROOT}/configs/recommended-plugins.json"
if [ -f "$plugins_file" ]; then
  plugins_json=$(jq '.plugins' "$plugins_file" 2>/dev/null || echo '[]')
fi

# ─── VERIFY.md 解析 ───

verify_pending="[]"
verify_verified="[]"
verify_deprecated="[]"

current_section=""
current_entry=""
current_title=""
current_commit=""
current_date=""
current_status=""
current_method=""
current_expected=""
current_actual=""
current_reason=""

flush_entry() {
  if [ -z "$current_title" ]; then
    return
  fi

  local target_arr
  case "$current_section" in
    pending)    target_arr="verify_pending" ;;
    verified)   target_arr="verify_verified" ;;
    deprecated) target_arr="verify_deprecated" ;;
    *) return ;;
  esac

  local entry
  entry=$(jq -n \
    --arg title "$current_title" \
    --arg commit "$current_commit" \
    --arg date "$current_date" \
    --arg status "$current_status" \
    --arg method "$current_method" \
    --arg expected "$current_expected" \
    --arg actual "$current_actual" \
    --arg reason "$current_reason" \
    '{title: $title, commit: $commit, date: $date, status: $status, method: $method, expected: $expected, actual: $actual, reason: $reason}'
  )

  case "$current_section" in
    pending)    verify_pending=$(jq --argjson arr "$verify_pending" --argjson entry "$entry" -n '$arr + [$entry]') ;;
    verified)   verify_verified=$(jq --argjson arr "$verify_verified" --argjson entry "$entry" -n '$arr + [$entry]') ;;
    deprecated) verify_deprecated=$(jq --argjson arr "$verify_deprecated" --argjson entry "$entry" -n '$arr + [$entry]') ;;
  esac

  # Reset entry fields
  current_title=""
  current_commit=""
  current_date=""
  current_status=""
  current_method=""
  current_expected=""
  current_actual=""
  current_reason=""
}

verify_file="${REPO_ROOT}/VERIFY.md"
in_comment=false
if [ -f "$verify_file" ]; then
  while IFS= read -r line; do
    # Skip HTML comments
    if [[ "$line" =~ \<\!-- ]]; then
      in_comment=true
      # Check if comment closes on same line
      [[ "$line" =~ --\> ]] && in_comment=false
      continue
    fi
    if $in_comment; then
      [[ "$line" =~ --\> ]] && in_comment=false
      continue
    fi

    # 检测 section 标题
    if [[ "$line" =~ ^##[[:space:]].*Pending ]]; then
      flush_entry
      current_section="pending"
      continue
    elif [[ "$line" =~ ^##[[:space:]].*Verified ]]; then
      flush_entry
      current_section="verified"
      continue
    elif [[ "$line" =~ ^##[[:space:]].*Deprecated ]]; then
      flush_entry
      current_section="deprecated"
      continue
    elif [[ "$line" =~ ^##[[:space:]] ]] && [[ ! "$line" =~ Pending|Verified|Deprecated ]]; then
      # Other section headers (e.g., How It Works, Status Legend) — skip
      flush_entry
      current_section=""
      continue
    fi

    # Skip if not in a valid section
    [ -z "$current_section" ] && continue

    # 解析条目行: - [ ] **标题** (commit: xxx, date: YYYY-MM-DD)
    #             - [x] **标题** (commit: xxx, date: YYYY-MM-DD)
    #             - [-] **标题** (date: YYYY-MM-DD)
    if [[ "$line" =~ ^-[[:space:]]\[(.)\][[:space:]]\*\*(.+)\*\*[[:space:]]*\((.+)\) ]]; then
      flush_entry
      local_marker="${BASH_REMATCH[1]}"
      current_title="${BASH_REMATCH[2]}"
      local_meta="${BASH_REMATCH[3]}"

      case "$local_marker" in
        " ") current_status="pending" ;;
        "x") current_status="verified" ;;
        "-") current_status="deprecated" ;;
        *)   current_status="unknown" ;;
      esac

      # Extract commit and date from meta
      if [[ "$local_meta" =~ commit:[[:space:]]*([^,]+) ]]; then
        current_commit="${BASH_REMATCH[1]}"
        # Trim trailing spaces
        current_commit="${current_commit%"${current_commit##*[![:space:]]}"}"
      fi
      if [[ "$local_meta" =~ date:[[:space:]]*([0-9-]+) ]]; then
        current_date="${BASH_REMATCH[1]}"
      fi
      continue
    fi

    # 解析子字段
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]验证方法：(.*) ]]; then
      current_method="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]预期效果：(.*) ]]; then
      current_expected="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]实际效果：(.*) ]]; then
      current_actual="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]原因：(.*) ]]; then
      current_reason="${BASH_REMATCH[1]}"
    fi

  done < "$verify_file"
  # Flush last entry
  flush_entry
fi

# ─── 统计数据 ───

total_skills=$(echo "$skills_json" | jq 'length')
total_hooks=$(echo "$hooks_json" | jq 'length')
total_configs=$(echo "$configs_json" | jq 'length')
total_scripts=$(echo "$scripts_json" | jq 'length')
total_plugins=$(echo "$plugins_json" | jq 'length')
total_verified=$(echo "$verify_verified" | jq 'length')
total_pending=$(echo "$verify_pending" | jq 'length')
total_deprecated=$(echo "$verify_deprecated" | jq 'length')

# Git info
git_branch=$(cd "$REPO_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
git_commit=$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── 组装最终 JSON ───

mkdir -p "${REPO_ROOT}/site"

# 将各数组写入临时文件，避免 --argjson 参数列表过长
echo "$skills_json" > "$TMPDIR_DATA/skills.json"
echo "$hooks_json" > "$TMPDIR_DATA/hooks.json"
echo "$configs_json" > "$TMPDIR_DATA/configs.json"
echo "$scripts_json" > "$TMPDIR_DATA/scripts.json"
echo "$plugins_json" > "$TMPDIR_DATA/plugins.json"
echo "$verify_pending" > "$TMPDIR_DATA/verify_pending.json"
echo "$verify_verified" > "$TMPDIR_DATA/verify_verified.json"
echo "$verify_deprecated" > "$TMPDIR_DATA/verify_deprecated.json"

jq -n \
  --slurpfile skills "$TMPDIR_DATA/skills.json" \
  --slurpfile hooks "$TMPDIR_DATA/hooks.json" \
  --slurpfile configs "$TMPDIR_DATA/configs.json" \
  --slurpfile scripts_arr "$TMPDIR_DATA/scripts.json" \
  --slurpfile plugins "$TMPDIR_DATA/plugins.json" \
  --slurpfile vp "$TMPDIR_DATA/verify_pending.json" \
  --slurpfile vv "$TMPDIR_DATA/verify_verified.json" \
  --slurpfile vd "$TMPDIR_DATA/verify_deprecated.json" \
  --argjson total_skills "$total_skills" \
  --argjson total_hooks "$total_hooks" \
  --argjson total_configs "$total_configs" \
  --argjson total_scripts "$total_scripts" \
  --argjson total_plugins "$total_plugins" \
  --argjson total_scripts_lines "$total_scripts_lines" \
  --argjson total_verified "$total_verified" \
  --argjson total_pending "$total_pending" \
  --argjson total_deprecated "$total_deprecated" \
  --arg git_branch "$git_branch" \
  --arg git_commit "$git_commit" \
  --arg generated_at "$generated_at" \
  '{
    stats: {
      total_skills: $total_skills,
      total_hooks: $total_hooks,
      total_configs: $total_configs,
      total_scripts: $total_scripts,
      total_plugins: $total_plugins,
      total_scripts_lines: $total_scripts_lines,
      total_verified: $total_verified,
      total_pending: $total_pending,
      total_deprecated: $total_deprecated
    },
    git: {
      branch: $git_branch,
      commit: $git_commit
    },
    generated_at: $generated_at,
    skills: $skills[0],
    hooks: $hooks[0],
    configs: $configs[0],
    scripts: $scripts_arr[0],
    plugins: $plugins[0],
    verify: {
      pending: $vp[0],
      verified: $vv[0],
      deprecated: $vd[0]
    }
  }' > "$OUTPUT"

echo "Generated: $OUTPUT"
echo "Stats: skills=$total_skills hooks=$total_hooks configs=$total_configs scripts=$total_scripts plugins=$total_plugins"
echo "Verify: pending=$total_pending verified=$total_verified deprecated=$total_deprecated"
