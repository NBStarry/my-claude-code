#!/bin/bash
# 导出 Claude Code memory 文件为 JSON 并上传到私有 GitHub Gist
# 本地运行: MEMORY_GIST_TOKEN=ghp_xxx bash scripts/export-memory.sh
# 可选: MEMORY_GIST_ID=<existing-gist-id> 更新已有 Gist
# 依赖: jq, curl

set -euo pipefail

TOKEN="${MEMORY_GIST_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "Error: MEMORY_GIST_TOKEN not set" >&2
  exit 1
fi

# Check dependencies
for cmd in jq curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed" >&2
    exit 1
  fi
done

GIST_ID="${MEMORY_GIST_ID:-}"
MEMORY_DIR="$HOME/.claude/projects"

if [ ! -d "$MEMORY_DIR" ]; then
  echo "Error: Memory directory $MEMORY_DIR not found" >&2
  exit 1
fi

# Collect memory files
memories_json="[]"
count_feedback=0
count_project=0
count_reference=0
count_user=0

while IFS= read -r -d '' file; do
  filename="$(basename "$file")"

  # Skip MEMORY.md index files
  if [ "$filename" = "MEMORY.md" ]; then
    continue
  fi

  # Parse YAML frontmatter
  name=""
  description=""
  mem_type=""
  in_frontmatter=false
  frontmatter_done=false
  content_lines=""

  while IFS= read -r line; do
    if [ "$frontmatter_done" = true ]; then
      content_lines="${content_lines}${line}
"
      continue
    fi

    if [ "$in_frontmatter" = false ] && [ "$line" = "---" ]; then
      in_frontmatter=true
      continue
    fi

    if [ "$in_frontmatter" = true ] && [ "$line" = "---" ]; then
      in_frontmatter=false
      frontmatter_done=true
      continue
    fi

    if [ "$in_frontmatter" = true ]; then
      key="${line%%:*}"
      val="${line#*: }"
      # Strip surrounding quotes if present
      val="${val#\"}"
      val="${val%\"}"
      val="${val#\'}"
      val="${val%\'}"
      case "$key" in
        name) name="$val" ;;
        description) description="$val" ;;
        type) mem_type="$val" ;;
      esac
    fi
  done < "$file"

  # If no frontmatter found, use filename as name and read entire file as content
  if [ -z "$name" ] && [ "$frontmatter_done" = false ]; then
    name="${filename%.md}"
    content_lines="$(cat "$file")"
  fi

  # Get relative path from MEMORY_DIR
  rel_path="${file#"$MEMORY_DIR"/}"

  # Count by type
  case "$mem_type" in
    feedback)  count_feedback=$((count_feedback + 1)) ;;
    project)   count_project=$((count_project + 1)) ;;
    reference) count_reference=$((count_reference + 1)) ;;
    user)      count_user=$((count_user + 1)) ;;
    *)         count_reference=$((count_reference + 1)) ;;
  esac

  # Add to JSON array
  entry="$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --arg type "$mem_type" \
    --arg file "$rel_path" \
    --arg content "$content_lines" \
    '{name: $name, description: $description, type: $type, file: $file, content: $content}'
  )"
  memories_json="$(echo "$memories_json" | jq --argjson entry "$entry" '. + [$entry]')"
done < <(find "$MEMORY_DIR" -path "*/memory/*.md" -print0 2>/dev/null)

# Assemble final JSON
exported_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
final_json="$(jq -n \
  --arg exported_at "$exported_at" \
  --argjson memories "$memories_json" \
  --argjson feedback "$count_feedback" \
  --argjson project "$count_project" \
  --argjson reference "$count_reference" \
  --argjson user "$count_user" \
  '{
    exported_at: $exported_at,
    memories: $memories,
    stats: {
      feedback: $feedback,
      project: $project,
      reference: $reference,
      user: $user
    }
  }'
)"

total="$(echo "$memories_json" | jq 'length')"
echo "Found $total memory files (feedback=$count_feedback, project=$count_project, reference=$count_reference, user=$count_user)"

# Prepare Gist payload
gist_payload="$(jq -n \
  --arg content "$final_json" \
  '{
    description: "Claude Code Memory Export",
    public: false,
    files: {
      "memory-data.json": {
        content: $content
      }
    }
  }'
)"

if [ -n "$GIST_ID" ]; then
  # PATCH existing Gist
  echo "Updating existing Gist: $GIST_ID"
  response="$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "$gist_payload" \
    "https://api.github.com/gists/$GIST_ID"
  )"
  http_code="$(echo "$response" | tail -1)"
  body="$(echo "$response" | sed '$d')"

  if [ "$http_code" -eq 200 ]; then
    echo "Gist updated successfully."
    echo "URL: $(echo "$body" | jq -r '.html_url')"
  else
    echo "Error updating Gist (HTTP $http_code):" >&2
    echo "$body" | jq -r '.message // .' >&2
    exit 1
  fi
else
  # POST new Gist
  echo "Creating new private Gist..."
  response="$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "$gist_payload" \
    "https://api.github.com/gists"
  )"
  http_code="$(echo "$response" | tail -1)"
  body="$(echo "$response" | sed '$d')"

  if [ "$http_code" -eq 201 ]; then
    new_id="$(echo "$body" | jq -r '.id')"
    echo "Gist created successfully."
    echo "Gist ID: $new_id"
    echo "URL: $(echo "$body" | jq -r '.html_url')"
    echo ""
    echo "Set MEMORY_GIST_ID in site/js/app.js:"
    echo "  var MEMORY_GIST_ID = '$new_id';"
  else
    echo "Error creating Gist (HTTP $http_code):" >&2
    echo "$body" | jq -r '.message // .' >&2
    exit 1
  fi
fi
