#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract basic info
user=$(whoami)
host=$(hostname -s)
current_dir=$(pwd)

# Get model display name
model_name=$(echo "$input" | jq -r '.model.display_name // empty')

# Get git branch if in a git repository (skip optional locks)
git_branch=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git --no-optional-locks branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        git_branch=" \033[01;33m($branch)\033[00m"
    fi
fi

# Get context usage information
ctx_info=""
# 优先使用 Claude Code 官方提供的百分比字段（与内置警告计算方式一致）
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

if [ -n "$remaining_pct" ] && [ "$remaining_pct" != "null" ]; then
    # 使用官方剩余百分比，转换为已使用百分比
    used_pct=$(awk "BEGIN {printf \"%.0f\", 100 - $remaining_pct}")

    # Color code based on usage: green < 50%, yellow < 80%, red >= 80%
    if [ "$used_pct" -lt 50 ]; then
        ctx_color="\033[01;32m"  # green
    elif [ "$used_pct" -lt 80 ]; then
        ctx_color="\033[01;33m"  # yellow
    else
        ctx_color="\033[01;31m"  # red
    fi

    ctx_info=" ${ctx_color}[ctx:${used_pct}%]\033[00m"
fi

# Build model info (cyan color)
model_info=""
if [ -n "$model_name" ]; then
    model_info=" \033[01;36m${model_name}\033[00m"
fi

# Output: user@host:directory model-name (git-branch) [ctx:X%]
printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m%b%b%b" "$user" "$host" "$current_dir" "$model_info" "$git_branch" "$ctx_info"
