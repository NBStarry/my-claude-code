# Claude Code Dashboard 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 GitHub Pages 静态站点，用于浏览 Claude Code 的 skills、hooks、configs、scripts、memory 和验证状态。

**Architecture:** 数据层（Shell 脚本扫描仓库生成 `site/data.json`）+ 展示层（纯 HTML/CSS/JS SPA，marked.js CDN 渲染 Markdown）。Memory 数据通过私有 Gist 隔离，客户端 token 鉴权。GitHub Actions 自动部署。

**Tech Stack:** Bash + jq（数据生成）、HTML/CSS/JS（前端）、marked.js CDN（Markdown 渲染）、GitHub Actions + peaceiris/actions-gh-pages（部署）

**设计文档:** `docs/superpowers/specs/2026-03-30-dashboard-design.md`

---

### Task 1: 数据生成脚本 — generate-site-data.sh

**Files:**
- Create: `scripts/generate-site-data.sh`
- Modify: `.gitignore`

这是整个项目的基础 — 所有前端页面依赖此脚本的输出。

- [ ] **Step 1: 创建脚本骨架和辅助函数**

```bash
#!/bin/bash
# 从仓库内容生成 site/data.json
# 依赖: jq
# 用法: bash scripts/generate-site-data.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/site"
OUTPUT="$OUTPUT_DIR/data.json"

mkdir -p "$OUTPUT_DIR"

# 从 Markdown 文件中提取 YAML frontmatter 的指定字段
# 用法: get_frontmatter_field <file> <field>
get_frontmatter_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d' | grep "^${field}:" | sed "s/^${field}:[[:space:]]*//"
}

# 读取文件内容，去掉 frontmatter 部分
# 用法: get_content_after_frontmatter <file>
get_content_after_frontmatter() {
  local file="$1"
  awk 'BEGIN{c=0} /^---$/{c++; if(c==2){found=1; next}} found{print}' "$file"
}

# 转义字符串为 JSON 安全格式
# 用法: json_escape <string>
json_escape() {
  printf '%s' "$1" | jq -Rs .
}

echo "Generating site data from $REPO_ROOT ..."
```

- [ ] **Step 2: 实现 skills 扫描**

在脚本末尾追加：

```bash
# ─── Skills ───
echo "  Scanning skills..."
skills_json="[]"
while IFS= read -r -d '' skill_file; do
  name=$(get_frontmatter_field "$skill_file" "name")
  description=$(get_frontmatter_field "$skill_file" "description")
  version=$(get_frontmatter_field "$skill_file" "version")

  # 从路径推断 source: skills/<source>/...SKILL.md 或 skills/<name>/SKILL.md
  rel_path="${skill_file#$REPO_ROOT/}"
  # skills/superpowers/brainstorming/SKILL.md → superpowers
  # skills/merge-verified/SKILL.md → custom
  path_parts=(${rel_path//\// })
  if [ "${#path_parts[@]}" -ge 4 ]; then
    source="${path_parts[1]}"
  else
    source="custom"
  fi

  content_md=$(get_content_after_frontmatter "$skill_file")

  skills_json=$(echo "$skills_json" | jq \
    --arg name "$name" \
    --arg desc "$description" \
    --arg ver "$version" \
    --arg src "$source" \
    --arg path "$rel_path" \
    --arg content "$content_md" \
    '. + [{name: $name, description: $desc, version: $ver, source: $src, path: $path, content_md: $content}]')
done < <(find "$REPO_ROOT/skills" -name "SKILL.md" -not -path "*/examples/*" -print0 2>/dev/null)
```

- [ ] **Step 3: 实现 hooks 扫描**

```bash
# ─── Hooks ───
echo "  Scanning hooks..."
hooks_json="[]"
while IFS= read -r -d '' hook_file; do
  rel_path="${hook_file#$REPO_ROOT/}"
  filename=$(basename "$hook_file" .json)

  # 提取事件类型 (顶层 hooks 对象的 key)
  events=$(jq -r '.hooks | keys[]' "$hook_file" 2>/dev/null | jq -Rs 'split("\n") | map(select(. != ""))')

  # 提取 description 字段（如果有）
  desc=$(jq -r '.description // ""' "$hook_file" 2>/dev/null)

  # 读取完整内容
  content=$(cat "$hook_file")

  hooks_json=$(echo "$hooks_json" | jq \
    --arg name "$filename" \
    --arg file "$rel_path" \
    --argjson events "$events" \
    --arg desc "$desc" \
    --arg content "$content" \
    '. + [{name: $name, file: $file, events: $events, description: $desc, content: $content}]')
done < <(find "$REPO_ROOT/hooks" -name "*.json" -not -path "*/examples/*" -print0 2>/dev/null)
```

- [ ] **Step 4: 实现 configs、scripts、plugins 扫描**

```bash
# ─── Configs ───
echo "  Scanning configs..."
configs_json="[]"
for config_file in "$REPO_ROOT"/configs/*.json "$REPO_ROOT"/configs/*.md; do
  [ -f "$config_file" ] || continue
  rel_path="${config_file#$REPO_ROOT/}"
  filename=$(basename "$config_file")
  content=$(cat "$config_file")

  configs_json=$(echo "$configs_json" | jq \
    --arg name "$filename" \
    --arg file "$rel_path" \
    --arg content "$content" \
    '. + [{name: $name, file: $file, content: $content}]')
done

# ─── Scripts ───
echo "  Scanning scripts..."
scripts_json="[]"
for script_file in "$REPO_ROOT"/scripts/*.sh; do
  [ -f "$script_file" ] || continue
  filename=$(basename "$script_file")

  # 跳过 generate-site-data.sh 和 export-memory.sh（元脚本）
  [[ "$filename" == "generate-site-data.sh" || "$filename" == "export-memory.sh" ]] && continue

  rel_path="${script_file#$REPO_ROOT/}"
  lines=$(wc -l < "$script_file" | tr -d ' ')

  # 提取头部注释作为描述（第2-4行通常是 # 注释）
  desc=$(sed -n '2,4p' "$script_file" | sed 's/^#[[:space:]]*//' | tr '\n' ' ' | sed 's/[[:space:]]*$//')

  # 提取依赖（从注释中找 "依赖" 或 "Dependencies" 行）
  deps_line=$(grep -i '^\(#.*依赖\|#.*dependenc\)' "$script_file" | head -1 | sed 's/^#[^:]*:[[:space:]]*//')
  # 解析为 JSON 数组: "jq, curl, tmux" → ["jq","curl","tmux"]
  if [ -n "$deps_line" ]; then
    deps=$(echo "$deps_line" | tr '、,' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
      sed 's/`//g' | jq -Rs 'split("\n") | map(select(. != "" and . != " "))')
  else
    deps="[]"
  fi

  scripts_json=$(echo "$scripts_json" | jq \
    --arg name "$filename" \
    --arg file "$rel_path" \
    --argjson lines "$lines" \
    --arg desc "$desc" \
    --argjson deps "$deps" \
    '. + [{name: $name, file: $file, lines: $lines, description: $desc, dependencies: $deps}]')
done

# ─── Plugins ───
echo "  Reading plugins..."
plugins_json="[]"
plugins_file="$REPO_ROOT/configs/recommended-plugins.json"
if [ -f "$plugins_file" ]; then
  plugins_json=$(jq '.plugins' "$plugins_file")
fi
```

- [ ] **Step 5: 实现 VERIFY.md 解析**

```bash
# ─── Verify ───
echo "  Parsing VERIFY.md..."
verify_pending="[]"
verify_verified="[]"
verify_deprecated="[]"
verify_file="$REPO_ROOT/VERIFY.md"

if [ -f "$verify_file" ]; then
  current_section=""
  current_title=""
  current_commit=""
  current_date=""
  current_method=""
  current_expected=""
  current_result=""
  current_reason=""

  flush_item() {
    [ -z "$current_title" ] && return
    case "$current_section" in
      pending)
        verify_pending=$(echo "$verify_pending" | jq \
          --arg t "$current_title" --arg c "$current_commit" --arg d "$current_date" \
          --arg m "$current_method" --arg e "$current_expected" \
          '. + [{title: $t, commit: $c, date: $d, method: $m, expected: $e}]')
        ;;
      verified)
        verify_verified=$(echo "$verify_verified" | jq \
          --arg t "$current_title" --arg c "$current_commit" --arg d "$current_date" \
          --arg r "$current_result" \
          '. + [{title: $t, commit: $c, date: $d, result: $r}]')
        ;;
      deprecated)
        verify_deprecated=$(echo "$verify_deprecated" | jq \
          --arg t "$current_title" --arg d "$current_date" --arg r "$current_reason" \
          '. + [{title: $t, date: $d, reason: $r}]')
        ;;
    esac
    current_title="" current_commit="" current_date="" current_method="" current_expected="" current_result="" current_reason=""
  }

  while IFS= read -r line; do
    # 检测 section 标题
    if echo "$line" | grep -qi "^## Pending"; then
      flush_item; current_section="pending"
    elif echo "$line" | grep -qi "^## Verified"; then
      flush_item; current_section="verified"
    elif echo "$line" | grep -qi "^## Deprecated"; then
      flush_item; current_section="deprecated"
    # 解析条目行: - [ ] **标题** (commit: xxx, date: YYYY-MM-DD) 或 - [x] 或 - [-]
    elif echo "$line" | grep -qE '^\- \[[ x\-]\] \*\*'; then
      flush_item
      current_title=$(echo "$line" | sed 's/^- \[.\] \*\*\([^*]*\)\*\*.*/\1/')
      current_commit=$(echo "$line" | grep -oP 'commit: \K[^,)]+' || echo "")
      current_date=$(echo "$line" | grep -oP 'date: \K[0-9-]+' || echo "")
    elif echo "$line" | grep -q '验证方法'; then
      current_method=$(echo "$line" | sed 's/.*验证方法[：:][[:space:]]*//')
    elif echo "$line" | grep -q '预期效果'; then
      current_expected=$(echo "$line" | sed 's/.*预期效果[：:][[:space:]]*//')
    elif echo "$line" | grep -q '实际效果'; then
      current_result=$(echo "$line" | sed 's/.*实际效果[：:][[:space:]]*//')
    elif echo "$line" | grep -q '原因'; then
      current_reason=$(echo "$line" | sed 's/.*原因[：:][[:space:]]*//')
    fi
  done < "$verify_file"
  flush_item
fi
```

- [ ] **Step 6: 组装最终 JSON 并输出**

```bash
# ─── Stats ───
total_skills=$(echo "$skills_json" | jq 'length')
total_verified=$(echo "$verify_verified" | jq 'length')
total_pending=$(echo "$verify_pending" | jq 'length')
total_plugins=$(echo "$plugins_json" | jq 'length')
total_scripts_lines=0
for script_file in "$REPO_ROOT"/scripts/*.sh; do
  [ -f "$script_file" ] || continue
  filename=$(basename "$script_file")
  [[ "$filename" == "generate-site-data.sh" || "$filename" == "export-memory.sh" ]] && continue
  lines=$(wc -l < "$script_file" | tr -d ' ')
  total_scripts_lines=$((total_scripts_lines + lines))
done

git_branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "unknown")
git_commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

# ─── 组装输出 ───
jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg git_branch "$git_branch" \
  --arg git_commit "$git_commit" \
  --argjson skills "$skills_json" \
  --argjson hooks "$hooks_json" \
  --argjson configs "$configs_json" \
  --argjson scripts "$scripts_json" \
  --argjson plugins "$plugins_json" \
  --argjson verify_pending "$verify_pending" \
  --argjson verify_verified "$verify_verified" \
  --argjson verify_deprecated "$verify_deprecated" \
  --argjson total_skills "$total_skills" \
  --argjson total_verified "$total_verified" \
  --argjson total_pending "$total_pending" \
  --argjson total_plugins "$total_plugins" \
  --argjson total_scripts_lines "$total_scripts_lines" \
  '{
    generated_at: $generated_at,
    git_branch: $git_branch,
    git_commit: $git_commit,
    skills: $skills,
    hooks: $hooks,
    configs: $configs,
    scripts: $scripts,
    plugins: $plugins,
    verify: {pending: $verify_pending, verified: $verify_verified, deprecated: $verify_deprecated},
    stats: {total_skills: $total_skills, total_scripts_lines: $total_scripts_lines, total_verified: $total_verified, total_pending: $total_pending, total_plugins: $total_plugins}
  }' > "$OUTPUT"

echo "Done! Output: $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
```

- [ ] **Step 7: 更新 .gitignore**

在 `.gitignore` 末尾追加：

```
# Dashboard auto-generated data
site/data.json
```

- [ ] **Step 8: 运行脚本验证输出**

运行: `bash scripts/generate-site-data.sh`
预期: 输出 `Done! Output: site/data.json (xxxxx bytes)`

运行: `jq '.stats' site/data.json`
预期: 显示 total_skills >= 1, total_scripts_lines > 0

运行: `jq '.skills[0].name' site/data.json`
预期: 有 skill 名称输出

运行: `bash -n scripts/generate-site-data.sh`
预期: 无语法错误

- [ ] **Step 9: 提交**

```bash
git add scripts/generate-site-data.sh .gitignore
git commit -m "feat: add generate-site-data.sh for dashboard data generation"
```

---

### Task 2: 前端基础 — SPA 壳 + 主题系统 + 路由

**Files:**
- Create: `site/index.html`
- Create: `site/css/style.css`
- Create: `site/js/app.js`

构建 SPA 骨架：侧边栏 + 顶部栏 + 内容区 + 主题切换 + hash 路由。此 Task 完成后，页面可以在各页面间导航（内容暂为占位）。

- [ ] **Step 1: 创建 site/css/style.css — CSS 变量 + 布局**

完整文件内容（从 mockup 中提炼的主题系统 + 布局框架）:

```css
/* ─── CSS Custom Properties (Theme) ─── */
:root {
  --bg-primary: #0f1117;
  --bg-secondary: #161b22;
  --bg-tertiary: #0d1117;
  --border: #30363d;
  --border-light: #21262d;
  --text-primary: #e1e4e8;
  --text-secondary: #c9d1d9;
  --text-muted: #8b949e;
  --text-faint: #484f58;
  --accent: #58a6ff;
  --green: #3fb950;
  --yellow: #d29922;
  --purple: #bc8cff;
  --orange: #f0883e;
  --red: #f85149;
  --cyan: #39d2c0;
  --green-bg: #238636;
  --hover-bg: #1f2937;
  --badge-bg: #30363d;
}

[data-theme="light"] {
  --bg-primary: #f6f8fa;
  --bg-secondary: #ffffff;
  --bg-tertiary: #f0f3f6;
  --border: #d0d7de;
  --border-light: #e1e4e8;
  --text-primary: #1f2328;
  --text-secondary: #32383f;
  --text-muted: #656d76;
  --text-faint: #8b949e;
  --accent: #0969da;
  --green: #1a7f37;
  --yellow: #9a6700;
  --purple: #8250df;
  --orange: #bc4c00;
  --red: #cf222e;
  --cyan: #0598a3;
  --green-bg: #1a7f37;
  --hover-bg: #eef1f5;
  --badge-bg: #e1e4e8;
}

/* ─── Reset & Base ─── */
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: var(--bg-primary);
  color: var(--text-primary);
  display: flex;
  height: 100vh;
  transition: background 0.3s, color 0.3s;
}

/* ─── Sidebar ─── */
.sidebar {
  width: 260px;
  background: var(--bg-secondary);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
}
/* ... 其余侧边栏、导航项、topbar、内容区样式从 mockup 中迁移 ... */
/* 完整样式见 Task 2 Step 1 交付文件 */
```

注意：完整 CSS 文件应包含 mockup 中已验证的所有样式（sidebar, nav-item, topbar, content, stat-card, skill-row, skill-detail, verify-list, memory-section, script-card, auth-gate, filter-chip 等），总计约 350-400 行。实现时从 `/tmp/claude-dashboard-mockup-pages.html` 的 `<style>` 标签中提取并整理到此文件。

- [ ] **Step 2: 创建 site/index.html — SPA 壳**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Claude Code Dashboard</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  <!-- 侧边栏 -->
  <div class="sidebar">
    <div class="sidebar-header">
      <h1 id="logo-link">&#9881; Claude Code Config</h1>
      <div class="subtitle">NBStarry's Dashboard</div>
    </div>
    <div class="nav-section">
      <div class="nav-section-title">Overview</div>
      <div class="nav-item" data-page="dashboard">
        <span class="dot dot-blue"></span> Dashboard <span class="badge">home</span>
      </div>
    </div>
    <div class="nav-section">
      <div class="nav-section-title">Extensions</div>
      <div class="nav-item" data-page="skills">
        <span class="dot dot-green"></span> Skills <span class="badge" id="badge-skills">-</span>
      </div>
      <div class="nav-item" data-page="hooks">
        <span class="dot dot-orange"></span> Hooks <span class="badge" id="badge-hooks">-</span>
      </div>
      <div class="nav-item" data-page="configs">
        <span class="dot dot-cyan"></span> Configs <span class="badge" id="badge-configs">-</span>
      </div>
    </div>
    <div class="nav-section">
      <div class="nav-section-title">Runtime</div>
      <div class="nav-item" data-page="memory">
        <span class="dot dot-red"></span> Memory <span class="badge">&#128274;</span>
      </div>
      <div class="nav-item" data-page="verify">
        <span class="dot dot-yellow"></span> Verification <span class="badge" id="badge-pending">-</span>
      </div>
      <div class="nav-item" data-page="scripts">
        <span class="dot dot-blue"></span> Scripts <span class="badge" id="badge-scripts">-</span>
      </div>
    </div>
    <div class="sidebar-footer">
      <div class="status"><span class="online"></span> <span id="footer-branch">-</span></div>
      <div id="footer-updated">-</div>
    </div>
  </div>

  <!-- 主内容区 -->
  <div class="main">
    <div class="topbar">
      <div class="breadcrumb" id="breadcrumb"></div>
      <input class="search-box" id="searchBox" placeholder="Search... (Ctrl+K)" />
      <button class="theme-toggle" id="themeToggle">&#127769;</button>
    </div>
    <div class="content" id="content">
      <!-- JS 动态渲染页面内容 -->
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script src="js/app.js"></script>
</body>
</html>
```

- [ ] **Step 3: 创建 site/js/app.js — 路由 + 数据加载 + 主题切换**

```javascript
'use strict';

// ─── 全局状态 ───
var appData = null;
var memoryData = null;

// ─── 主题切换 ───
(function initTheme() {
  var toggle = document.getElementById('themeToggle');
  var saved = localStorage.getItem('theme') || 'dark';
  if (saved === 'light') {
    document.documentElement.setAttribute('data-theme', 'light');
    toggle.textContent = '\u2600\uFE0F';
  }
  toggle.addEventListener('click', function() {
    var isLight = document.documentElement.getAttribute('data-theme') === 'light';
    if (isLight) {
      document.documentElement.removeAttribute('data-theme');
      toggle.textContent = '\uD83C\uDF19';
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.setAttribute('data-theme', 'light');
      toggle.textContent = '\u2600\uFE0F';
      localStorage.setItem('theme', 'light');
    }
  });
})();

// ─── 路由 ───
function getRoute() {
  var hash = window.location.hash.replace('#', '') || 'dashboard';
  return hash.split('/');
}

function navigate(route) {
  window.location.hash = route;
}

window.addEventListener('hashchange', render);

// ─── 侧边栏导航 ───
document.querySelectorAll('.nav-item[data-page]').forEach(function(item) {
  item.addEventListener('click', function() {
    navigate(this.getAttribute('data-page'));
  });
});
document.getElementById('logo-link').addEventListener('click', function() {
  navigate('dashboard');
});

// ─── 面包屑更新 ───
function updateBreadcrumb(parts) {
  var bc = document.getElementById('breadcrumb');
  // 安全地用 DOM API 构建面包屑
  while (bc.firstChild) bc.removeChild(bc.firstChild);

  var homeLink = document.createElement('span');
  homeLink.className = 'bc-link';
  homeLink.textContent = 'Dashboard';
  homeLink.addEventListener('click', function() { navigate('dashboard'); });
  bc.appendChild(homeLink);

  for (var i = 0; i < parts.length; i++) {
    bc.appendChild(document.createTextNode(' / '));
    if (i < parts.length - 1) {
      var link = document.createElement('span');
      link.className = 'bc-link';
      link.textContent = parts[i].label;
      (function(route) {
        link.addEventListener('click', function() { navigate(route); });
      })(parts[i].route);
      bc.appendChild(link);
    } else {
      var current = document.createElement('span');
      current.className = 'current';
      current.textContent = parts[i].label;
      bc.appendChild(current);
    }
  }
}

// ─── 渲染主入口 ───
function render() {
  var route = getRoute();
  var page = route[0];

  // 更新侧边栏 active 状态
  document.querySelectorAll('.nav-item').forEach(function(n) { n.classList.remove('active'); });
  var activeKey = (page === 'skill-detail') ? 'skills' : page;
  var activeNav = document.querySelector('.nav-item[data-page="' + activeKey + '"]');
  if (activeNav) activeNav.classList.add('active');

  // 根据路由渲染对应页面
  if (!appData) {
    document.getElementById('content').textContent = 'Loading...';
    return;
  }

  switch(page) {
    case 'dashboard': renderDashboard(); break;
    case 'skills': renderSkills(); break;
    case 'skill-detail': renderSkillDetail(route[1]); break;
    case 'hooks': renderHooks(); break;
    case 'configs': renderConfigs(); break;
    case 'memory': renderMemory(); break;
    case 'verify': renderVerify(); break;
    case 'scripts': renderScripts(); break;
    default: renderDashboard();
  }
}

// ─── 数据加载 ───
fetch('data.json')
  .then(function(r) { return r.json(); })
  .then(function(data) {
    appData = data;
    updateSidebarBadges();
    render();
  })
  .catch(function(err) {
    document.getElementById('content').textContent = 'Failed to load data.json: ' + err.message;
  });

function updateSidebarBadges() {
  document.getElementById('badge-skills').textContent = appData.stats.total_skills;
  document.getElementById('badge-hooks').textContent = appData.hooks.length;
  document.getElementById('badge-configs').textContent = appData.configs.length;
  document.getElementById('badge-pending').textContent = appData.stats.total_pending;
  document.getElementById('badge-scripts').textContent = appData.scripts.length;
  document.getElementById('footer-branch').textContent = appData.git_branch + ' branch';
  document.getElementById('footer-updated').textContent = 'Updated: ' + appData.generated_at.split('T')[0];
}

// ─── 页面渲染函数占位（Task 3-6 实现） ───
function renderDashboard() {
  updateBreadcrumb([{label: 'Overview'}]);
  document.getElementById('content').textContent = 'Dashboard — 待实现 (Task 3)';
}
function renderSkills() {
  updateBreadcrumb([{label: 'Skills'}]);
  document.getElementById('content').textContent = 'Skills — 待实现 (Task 3)';
}
function renderSkillDetail(name) {
  updateBreadcrumb([{label: 'Skills', route: 'skills'}, {label: name || ''}]);
  document.getElementById('content').textContent = 'Skill Detail — 待实现 (Task 3)';
}
function renderHooks() {
  updateBreadcrumb([{label: 'Hooks'}]);
  document.getElementById('content').textContent = 'Hooks — 待实现 (Task 4)';
}
function renderConfigs() {
  updateBreadcrumb([{label: 'Configs'}]);
  document.getElementById('content').textContent = 'Configs — 待实现 (Task 4)';
}
function renderMemory() {
  updateBreadcrumb([{label: 'Memory'}]);
  document.getElementById('content').textContent = 'Memory — 待实现 (Task 5)';
}
function renderVerify() {
  updateBreadcrumb([{label: 'Verification'}]);
  document.getElementById('content').textContent = 'Verification — 待实现 (Task 4)';
}
function renderScripts() {
  updateBreadcrumb([{label: 'Scripts'}]);
  document.getElementById('content').textContent = 'Scripts — 待实现 (Task 4)';
}
```

- [ ] **Step 4: 本地验证**

运行: `bash scripts/generate-site-data.sh` （确保 data.json 存在）

运行: `cd site && python3 -m http.server 8080` （或 `npx serve .`）

在浏览器打开 `http://localhost:8080`，验证：
- 侧边栏导航可点击，路由切换正常（URL hash 变化）
- 面包屑随页面更新
- 主题切换生效
- 侧边栏角标显示正确数字

- [ ] **Step 5: 提交**

```bash
git add site/index.html site/css/style.css site/js/app.js
git commit -m "feat: add SPA shell with routing, theme toggle, and sidebar navigation"
```

---

### Task 3: Dashboard 首页 + Skills 页面 + Skill 详情页

**Files:**
- Modify: `site/js/app.js` — 实现 `renderDashboard()`、`renderSkills()`、`renderSkillDetail()`

- [ ] **Step 1: 实现 renderDashboard()**

在 `app.js` 中替换 `renderDashboard` 函数。用 DOM API 构建：
- 4 张统计卡片（Skills/Verified/Scripts/Plugins），点击跳转对应页面
- 最近动态列表：合并 `verify.pending` 和 `verify.verified` 的最近 5 条，按日期倒序
- 每条显示状态图标（黄色圆圈=pending / 绿色勾=verified）+ 标题 + 日期

关键代码模式（用 DOM API 构建，不用 innerHTML）：

```javascript
function renderDashboard() {
  updateBreadcrumb([{label: 'Overview'}]);
  var el = document.getElementById('content');
  while (el.firstChild) el.removeChild(el.firstChild);

  // 标题
  var title = document.createElement('div');
  title.className = 'page-title';
  title.textContent = 'Dashboard';
  el.appendChild(title);

  var desc = document.createElement('div');
  desc.className = 'page-desc';
  desc.textContent = 'Claude Code 配置一览 — 自动生成于每次 push';
  el.appendChild(desc);

  // 统计卡片网格
  var grid = document.createElement('div');
  grid.className = 'stats-grid';

  var stats = [
    {label: 'Skills', value: appData.stats.total_skills, sub: appData.skills.reduce(function(s,sk) { s[sk.source]=1; return s; }, {}), color: 'blue', page: 'skills'},
    {label: 'Verified', value: appData.stats.total_verified, sub: appData.stats.total_pending + ' pending', color: 'green', page: 'verify'},
    {label: 'Scripts', value: appData.stats.total_scripts_lines.toLocaleString(), sub: 'lines of bash', color: 'yellow', page: 'scripts'},
    {label: 'Plugins', value: appData.stats.total_plugins, sub: 'recommended', color: 'purple', page: 'configs'}
  ];
  // ... 为每个 stat 创建 .stat-card 并 appendChild
  el.appendChild(grid);

  // 最近动态
  // ... 合并 pending+verified，排序，取前5条，渲染列表
}
```

- [ ] **Step 2: 实现 renderSkills()**

构建过滤栏 + 列表。过滤逻辑：点击 chip 后遍历所有 `.skill-row` 并按 `data-source` 属性 toggle display。点击行时 `navigate('skill-detail/' + name)`。

- [ ] **Step 3: 实现 renderSkillDetail(name)**

根据 `name` 从 `appData.skills` 中查找对应 skill。渲染：
- 返回链接
- 头部元信息
- Frontmatter 区块（等宽字体，颜色高亮 key/value）
- 正文：`marked.parse(skill.content_md)` 渲染到一个 div

注意安全：marked.js 渲染结果需要设置到 `div.innerHTML`。由于 content_md 来自我们自己的 data.json（从仓库 SKILL.md 生成），不是用户输入，这里是可控的。配置 marked 禁用 HTML 标签：`marked.setOptions({sanitize: false, breaks: true})`。

- [ ] **Step 4: 本地验证**

在浏览器中验证：
- Dashboard 页 4 张卡片显示正确数据，点击可跳转
- Skills 列表显示所有 skills，过滤 chip 可用
- 点击 skill 行进入详情页，Markdown 正确渲染
- 返回链接可回到列表

- [ ] **Step 5: 提交**

```bash
git add site/js/app.js
git commit -m "feat: implement dashboard, skills list, and skill detail pages"
```

---

### Task 4: Hooks + Configs + Verification + Scripts 页面

**Files:**
- Modify: `site/js/app.js` — 实现 `renderHooks()`、`renderConfigs()`、`renderVerify()`、`renderScripts()`

- [ ] **Step 1: 实现 renderHooks()**

每个 hook 渲染为卡片：
- 名称 + 文件路径
- 事件类型作为彩色标签（遍历 `hook.events`，根据事件名着色）
- 描述文字
- 点击卡片 toggle 展开/折叠，显示完整 JSON 配置（等宽字体 `<pre>` 块）

```javascript
function renderHooks() {
  updateBreadcrumb([{label: 'Hooks'}]);
  var el = document.getElementById('content');
  while (el.firstChild) el.removeChild(el.firstChild);
  // ... 页面标题

  appData.hooks.forEach(function(hook) {
    var card = document.createElement('div');
    card.className = 'hook-card';
    // ... 构建卡片头部、事件标签、描述

    // 可折叠的 JSON 内容
    var pre = document.createElement('pre');
    pre.className = 'hook-content collapsed';
    pre.textContent = JSON.stringify(JSON.parse(hook.content), null, 2);
    card.appendChild(pre);

    card.addEventListener('click', function() {
      pre.classList.toggle('collapsed');
    });
    el.appendChild(card);
  });
}
```

- [ ] **Step 2: 实现 renderConfigs()**

类似 Hooks 模式：每个配置文件一个可展开卡片。特殊处理 `CLAUDE.md` — 用 marked.js 渲染 Markdown 内容而非 JSON。

- [ ] **Step 3: 实现 renderVerify()**

- 顶部进度条：`verified / (verified + pending)` 比例
- 三个标签页按钮（Pending / Verified / Deprecated）
- 点击标签页切换显示对应列表
- Pending 条目：黄色标记 + 标题 + commit + 日期 + 验证方法 + 预期效果
- Verified 条目：绿色勾 + 标题 + commit + 日期 + 实际效果
- Deprecated 条目：删除线 + 标题 + 原因

- [ ] **Step 4: 实现 renderScripts()**

每个脚本一张卡片：名称 + 行数标签 + 描述 + 依赖标签。无需展开功能（脚本内容未包含在 data.json 中，保持简洁）。

- [ ] **Step 5: 补充 CSS 样式**

在 `site/css/style.css` 中添加：
- `.hook-card` 卡片样式和 `.hook-content.collapsed { display: none; }` 折叠状态
- `.event-badge` 事件标签样式（按事件名着色）
- `.progress-bar` 进度条样式
- `.tab-bar` + `.tab-btn.active` 标签页按钮样式
- `.verify-item` 验证条目样式（pending/verified/deprecated 三种变体）

- [ ] **Step 6: 本地验证**

在浏览器中验证所有 4 个页面：
- Hooks：卡片展示正确，事件标签有颜色，点击展开 JSON
- Configs：文件列表正确，CLAUDE.md 渲染为 Markdown
- Verification：进度条比例正确，标签页切换正常，条目内容完整
- Scripts：卡片信息正确，依赖标签显示

- [ ] **Step 7: 提交**

```bash
git add site/js/app.js site/css/style.css
git commit -m "feat: implement hooks, configs, verification, and scripts pages"
```

---

### Task 5: Memory 页面 — 鉴权门 + Gist 数据加载

**Files:**
- Modify: `site/js/app.js` — 实现 `renderMemory()`
- Create: `scripts/export-memory.sh`

- [ ] **Step 1: 实现 renderMemory() — 鉴权门 UI**

```javascript
function renderMemory() {
  updateBreadcrumb([{label: 'Memory'}]);
  var el = document.getElementById('content');
  while (el.firstChild) el.removeChild(el.firstChild);

  // 标题
  var title = document.createElement('div');
  title.className = 'page-title';
  title.textContent = 'Memory';
  el.appendChild(title);

  var desc = document.createElement('div');
  desc.className = 'page-desc';
  desc.textContent = '跨会话持久记忆 — 私有数据需要鉴权';
  el.appendChild(desc);

  // 检查 sessionStorage 或 URL 参数中的 token
  var token = sessionStorage.getItem('memory_token');
  var urlParams = new URLSearchParams(window.location.search);
  if (!token && urlParams.has('token')) {
    token = urlParams.get('token');
    sessionStorage.setItem('memory_token', token);
  }

  if (token && memoryData) {
    renderMemoryContent(el);
    return;
  }

  if (token && !memoryData) {
    loadMemoryFromGist(token, el);
    return;
  }

  // 鉴权门
  var gate = document.createElement('div');
  gate.className = 'auth-gate';

  var lockIcon = document.createElement('div');
  lockIcon.className = 'lock-icon';
  lockIcon.textContent = '\uD83D\uDD12';
  gate.appendChild(lockIcon);

  var h2 = document.createElement('h2');
  h2.textContent = 'Private Memory Data';
  gate.appendChild(h2);

  var p = document.createElement('p');
  p.textContent = 'Memory 数据存储在私有 Gist 中。输入你的 access token 查看。';
  gate.appendChild(p);

  var inputWrap = document.createElement('div');
  inputWrap.className = 'auth-input';

  var input = document.createElement('input');
  input.type = 'password';
  input.placeholder = 'Enter GitHub token with gist scope...';

  var btn = document.createElement('button');
  btn.className = 'auth-btn';
  btn.textContent = 'Unlock';
  btn.addEventListener('click', function() {
    var t = input.value.trim();
    if (t) {
      sessionStorage.setItem('memory_token', t);
      loadMemoryFromGist(t, el);
    }
  });

  inputWrap.appendChild(input);
  inputWrap.appendChild(btn);
  gate.appendChild(inputWrap);

  var note = document.createElement('p');
  note.style.cssText = 'font-size:12px;color:var(--text-faint);margin-top:16px';
  note.textContent = 'Token 仅在客户端使用，关闭标签页自动清除';
  gate.appendChild(note);

  el.appendChild(gate);
}
```

- [ ] **Step 2: 实现 Gist 数据加载和渲染**

```javascript
// Gist ID — export-memory.sh 创建 Gist 后将 ID 写入此处
var MEMORY_GIST_ID = ''; // 部署时填入实际 Gist ID

function loadMemoryFromGist(token, containerEl) {
  if (!MEMORY_GIST_ID) {
    containerEl.textContent = 'MEMORY_GIST_ID not configured. Run export-memory.sh first.';
    return;
  }

  fetch('https://api.github.com/gists/' + MEMORY_GIST_ID, {
    headers: { 'Authorization': 'Bearer ' + token }
  })
  .then(function(r) {
    if (!r.ok) throw new Error('Auth failed (' + r.status + ')');
    return r.json();
  })
  .then(function(gist) {
    var file = gist.files['memory-data.json'];
    if (!file) throw new Error('memory-data.json not found in Gist');
    memoryData = JSON.parse(file.content);
    renderMemory(); // 重新渲染（此时有 memoryData）
  })
  .catch(function(err) {
    sessionStorage.removeItem('memory_token');
    memoryData = null;
    var errDiv = document.createElement('div');
    errDiv.style.cssText = 'color:var(--red);text-align:center;margin-top:20px';
    errDiv.textContent = 'Error: ' + err.message;
    containerEl.appendChild(errDiv);
  });
}

function renderMemoryContent(containerEl) {
  // 类型统计条
  var statsRow = document.createElement('div');
  statsRow.className = 'mem-stats';
  var types = ['feedback', 'project', 'reference', 'user'];
  var typeColors = {feedback: 's-feedback', project: 's-project', reference: 's-reference', user: 's-user'};
  types.forEach(function(type) {
    var card = document.createElement('div');
    card.className = 'mem-stat ' + typeColors[type];
    var val = document.createElement('div');
    val.className = 'ms-val';
    val.textContent = memoryData.stats[type] || 0;
    var label = document.createElement('div');
    label.className = 'ms-label';
    label.textContent = type.charAt(0).toUpperCase() + type.slice(1);
    card.appendChild(val);
    card.appendChild(label);
    statsRow.appendChild(card);
  });
  containerEl.appendChild(statsRow);

  // 表格
  var table = document.createElement('table');
  table.className = 'mem-table';
  // ... thead + tbody 构建（遍历 memoryData.memories）
  // 每行：type badge + name + description + file
  // 点击行 toggle 展开完整 content_md（marked 渲染）
  containerEl.appendChild(table);
}
```

- [ ] **Step 3: 创建 scripts/export-memory.sh**

```bash
#!/bin/bash
# 导出 Claude Code memory 文件为 JSON 并上传到私有 GitHub Gist
# 本地运行: bash scripts/export-memory.sh
# 依赖: jq, curl
# 环境变量: MEMORY_GIST_TOKEN (GitHub token with gist scope)

set -euo pipefail

TOKEN="${MEMORY_GIST_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "Error: MEMORY_GIST_TOKEN not set" >&2
  echo "Usage: MEMORY_GIST_TOKEN=ghp_xxx bash scripts/export-memory.sh" >&2
  exit 1
fi

# 查找所有 memory 目录
memories_json="[]"
mem_stats='{"feedback":0,"project":0,"reference":0,"user":0}'

for memory_dir in "$HOME"/.claude/projects/*/memory; do
  [ -d "$memory_dir" ] || continue

  for mem_file in "$memory_dir"/*.md; do
    [ -f "$mem_file" ] || continue
    filename=$(basename "$mem_file")
    [ "$filename" = "MEMORY.md" ] && continue  # 跳过索引文件

    # 解析 frontmatter
    name=$(sed -n '/^---$/,/^---$/p' "$mem_file" | sed '1d;$d' | grep "^name:" | sed 's/^name:[[:space:]]*//')
    desc=$(sed -n '/^---$/,/^---$/p' "$mem_file" | sed '1d;$d' | grep "^description:" | sed 's/^description:[[:space:]]*//')
    type=$(sed -n '/^---$/,/^---$/p' "$mem_file" | sed '1d;$d' | grep "^type:" | sed 's/^type:[[:space:]]*//')

    content=$(cat "$mem_file")

    memories_json=$(echo "$memories_json" | jq \
      --arg name "$name" \
      --arg desc "$desc" \
      --arg type "$type" \
      --arg file "$filename" \
      --arg content "$content" \
      '. + [{name: $name, description: $desc, type: $type, file: $file, content_md: $content}]')

    # 更新统计
    if echo "$mem_stats" | jq -e --arg t "$type" '.[$t] != null' > /dev/null 2>&1; then
      mem_stats=$(echo "$mem_stats" | jq --arg t "$type" '.[$t] += 1')
    fi
  done
done

# 组装最终 JSON
output=$(jq -n \
  --arg exported_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson memories "$memories_json" \
  --argjson stats "$mem_stats" \
  '{exported_at: $exported_at, memories: $memories, stats: $stats}')

echo "$output" > /tmp/memory-data.json
echo "Exported $(echo "$memories_json" | jq 'length') memories to /tmp/memory-data.json"

# 上传到 Gist
GIST_ID="${MEMORY_GIST_ID:-}"
if [ -n "$GIST_ID" ]; then
  # 更新已有 Gist
  payload=$(jq -n --arg content "$output" '{"files":{"memory-data.json":{"content": $content}}}')
  curl -s -X PATCH "https://api.github.com/gists/$GIST_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null
  echo "Updated Gist: $GIST_ID"
else
  # 创建新 Gist
  payload=$(jq -n --arg content "$output" '{"description":"Claude Code Memory Data","public":false,"files":{"memory-data.json":{"content": $content}}}')
  response=$(curl -s -X POST "https://api.github.com/gists" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload")
  new_id=$(echo "$response" | jq -r '.id')
  echo "Created new Gist: $new_id"
  echo "Set MEMORY_GIST_ID=$new_id in your environment or update app.js"
fi
```

- [ ] **Step 4: 验证 export-memory.sh 语法**

运行: `bash -n scripts/export-memory.sh`
预期: 无语法错误

- [ ] **Step 5: 本地验证 Memory 页面**

在浏览器中验证：
- 默认显示鉴权门（锁图标 + 输入框）
- 输入空 token 不触发请求
- MEMORY_GIST_ID 为空时显示配置提示

- [ ] **Step 6: 提交**

```bash
git add site/js/app.js scripts/export-memory.sh
git commit -m "feat: add memory page with Gist auth and export-memory.sh"
```

---

### Task 6: 全局搜索

**Files:**
- Modify: `site/js/app.js` — 添加搜索逻辑
- Modify: `site/css/style.css` — 添加搜索下拉样式

- [ ] **Step 1: 实现搜索 UI 和逻辑**

在 `app.js` 中添加：

```javascript
// ─── 搜索 ───
var searchBox = document.getElementById('searchBox');

// Ctrl+K 快捷键
document.addEventListener('keydown', function(e) {
  if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
    e.preventDefault();
    searchBox.focus();
  }
  if (e.key === 'Escape') {
    searchBox.blur();
    hideSearchResults();
  }
});

searchBox.addEventListener('input', function() {
  var query = this.value.trim().toLowerCase();
  if (query.length < 2) { hideSearchResults(); return; }
  showSearchResults(query);
});

searchBox.addEventListener('blur', function() {
  // 延迟隐藏，让点击结果的事件先触发
  setTimeout(hideSearchResults, 200);
});

function hideSearchResults() {
  var existing = document.getElementById('search-results');
  if (existing) existing.remove();
}

function showSearchResults(query) {
  hideSearchResults();
  if (!appData) return;

  var results = [];

  // 搜索 skills
  appData.skills.forEach(function(s) {
    if (s.name.toLowerCase().indexOf(query) !== -1 || s.description.toLowerCase().indexOf(query) !== -1) {
      results.push({type: 'Skill', name: s.name, desc: s.description, route: 'skill-detail/' + s.name});
    }
  });

  // 搜索 hooks
  appData.hooks.forEach(function(h) {
    if (h.name.toLowerCase().indexOf(query) !== -1 || h.description.toLowerCase().indexOf(query) !== -1) {
      results.push({type: 'Hook', name: h.name, desc: h.description, route: 'hooks'});
    }
  });

  // 搜索 configs
  appData.configs.forEach(function(c) {
    if (c.name.toLowerCase().indexOf(query) !== -1) {
      results.push({type: 'Config', name: c.name, desc: c.file, route: 'configs'});
    }
  });

  // 搜索 scripts
  appData.scripts.forEach(function(s) {
    if (s.name.toLowerCase().indexOf(query) !== -1 || s.description.toLowerCase().indexOf(query) !== -1) {
      results.push({type: 'Script', name: s.name, desc: s.description, route: 'scripts'});
    }
  });

  if (results.length === 0) return;

  // 构建下拉
  var dropdown = document.createElement('div');
  dropdown.id = 'search-results';
  dropdown.className = 'search-dropdown';

  results.slice(0, 10).forEach(function(r) {
    var item = document.createElement('div');
    item.className = 'search-result-item';

    var badge = document.createElement('span');
    badge.className = 'search-type-badge';
    badge.textContent = r.type;
    item.appendChild(badge);

    var name = document.createElement('span');
    name.className = 'search-result-name';
    name.textContent = r.name;
    item.appendChild(name);

    var desc = document.createElement('span');
    desc.className = 'search-result-desc';
    desc.textContent = r.desc;
    item.appendChild(desc);

    item.addEventListener('mousedown', function(e) {
      e.preventDefault();
      navigate(r.route);
      searchBox.value = '';
      hideSearchResults();
    });
    dropdown.appendChild(item);
  });

  // 定位到 searchBox 下方
  var topbar = document.querySelector('.topbar');
  topbar.appendChild(dropdown);
}
```

- [ ] **Step 2: 添加搜索下拉 CSS**

在 `style.css` 中添加：

```css
/* Search dropdown */
.search-dropdown {
  position: absolute;
  top: 52px;
  right: 60px;
  width: 400px;
  background: var(--bg-secondary);
  border: 1px solid var(--border);
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.3);
  max-height: 400px;
  overflow-y: auto;
  z-index: 100;
}
.search-result-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  cursor: pointer;
  border-bottom: 1px solid var(--border-light);
}
.search-result-item:last-child { border-bottom: none; }
.search-result-item:hover { background: var(--hover-bg); }
.search-type-badge {
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  background: var(--badge-bg);
  color: var(--text-muted);
  font-weight: 600;
  text-transform: uppercase;
  min-width: 50px;
  text-align: center;
}
.search-result-name { font-size: 13px; color: var(--text-secondary); font-weight: 500; }
.search-result-desc { font-size: 12px; color: var(--text-faint); margin-left: auto; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
```

- [ ] **Step 3: 本地验证搜索**

在浏览器中验证：
- Ctrl+K 聚焦搜索框
- 输入 "telegram" → 显示匹配的 hooks/scripts
- 输入 "brain" → 显示 brainstorming skill
- 点击结果跳转到对应页面
- Escape 关闭搜索

- [ ] **Step 4: 提交**

```bash
git add site/js/app.js site/css/style.css
git commit -m "feat: add global search with Ctrl+K shortcut"
```

---

### Task 7: GitHub Actions 部署

**Files:**
- Create: `.github/workflows/deploy-dashboard.yml`

- [ ] **Step 1: 创建 workflow 文件**

```yaml
name: Deploy Dashboard

on:
  push:
    branches: [dev, main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install jq
        run: which jq || sudo apt-get install -y jq

      - name: Generate site data
        run: bash scripts/generate-site-data.sh

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

注意：使用官方 `actions/deploy-pages` 而非第三方 `peaceiris/actions-gh-pages`，这是 GitHub 推荐的新方式，需要在仓库 Settings → Pages 中将 Source 设置为 "GitHub Actions"。

- [ ] **Step 2: 本地验证 workflow YAML 语法**

运行: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy-dashboard.yml'))"`
预期: 无错误

- [ ] **Step 3: 提交**

```bash
git add .github/workflows/deploy-dashboard.yml
git commit -m "ci: add GitHub Actions workflow for dashboard deployment"
```

---

### Task 8: 端到端验证 + 收尾

**Files:**
- Modify: `VERIFY.md` — 添加验证条目
- Modify: `CLAUDE.md` — 添加 Dashboard 架构说明（可选）

- [ ] **Step 1: 完整本地测试**

```bash
# 1. 生成数据
bash scripts/generate-site-data.sh

# 2. 验证 data.json 完整性
jq '.stats' site/data.json
jq '.skills | length' site/data.json
jq '.hooks | length' site/data.json
jq '.verify.pending | length' site/data.json

# 3. 启动本地服务器
cd site && python3 -m http.server 8080
```

在浏览器中逐页验证：
- Dashboard：统计数字正确，动态列表有内容
- Skills：列表完整，过滤可用，详情页 Markdown 渲染正确
- Hooks：2 个 hook 卡片，JSON 可展开
- Configs：配置文件列表，CLAUDE.md 渲染
- Memory：鉴权门显示正确
- Verification：进度条比例正确，标签页切换正常
- Scripts：3 个脚本卡片，信息正确
- 主题切换：亮暗模式都正常
- 搜索：Ctrl+K 可用，结果准确

- [ ] **Step 2: Shell 脚本语法检查**

```bash
bash -n scripts/generate-site-data.sh
bash -n scripts/export-memory.sh
```

预期: 两个脚本都无语法错误

- [ ] **Step 3: 添加 VERIFY.md 条目**

在 VERIFY.md 的 Pending 区域添加：

```markdown
- [ ] **Dashboard 站点：数据生成 + SPA 前端 + GitHub Actions 部署** (commit: pending, date: 2026-03-30)
  - 验证方法：
    1. `bash scripts/generate-site-data.sh` 成功生成 data.json
    2. 本地 `python3 -m http.server` 打开页面，所有页面渲染正确
    3. Push 到 dev 后 GitHub Actions 成功部署
    4. 访问 https://nbstarry.github.io/my-claude-code/ 页面加载正常
  - 预期效果：8 个页面全部可浏览，亮暗切换正常，搜索可用
  - 实际效果：（验证后填写）
```

- [ ] **Step 4: 最终提交**

```bash
git add VERIFY.md
git commit -m "docs: add dashboard verification entry"
```
