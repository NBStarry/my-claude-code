# Claude Code Dashboard — 设计文档

## 概述

基于 GitHub Pages 的个人配置浏览页面，用于查看 Claude Code 的 skills、memory、hooks、configs、scripts 和验证状态。纯 HTML/CSS/JS 单页应用，零 Node.js 依赖，通过 GitHub Actions 自动部署。

**受众：** 个人工具（仅 NBStarry 使用）
**地址：** `https://nbstarry.github.io/my-claude-code/`

## 关键决策

| 决策项 | 选择 | 原因 |
|--------|------|------|
| 技术栈 | 原生 HTML/CSS/JS + marked.js (CDN) | 零依赖，保持仓库作为配置/脚本仓库的定位 |
| 数据来源 | Shell 脚本扫描仓库生成 `data.json` | 解析 YAML frontmatter、统计行数、提取 VERIFY.md 状态 |
| Memory 隐私 | 私有 GitHub Gist + 客户端 token 鉴权 | Memory JSON 导出到 Gist；页面通过 token 拉取 |
| 部署方式 | GitHub Actions（push 到 dev/main 时触发） | 运行数据生成脚本 → 部署 `site/` 到 Pages |
| 主题 | CSS 变量实现亮暗切换 | localStorage 保存偏好，默认暗色 |
| Markdown 渲染 | marked.js (CDN) | 轻量，无需构建，直接渲染 SKILL.md 内容 |

## 架构

```
Push 到 dev/main
       │
       ▼
GitHub Actions 工作流
       │
       ├── 1. 运行 scripts/generate-site-data.sh
       │      ├── 扫描 skills/ → 提取 YAML frontmatter + 正文
       │      ├── 扫描 hooks/ → 解析 JSON 配置
       │      ├── 扫描 configs/ → 列出文件 + 元数据
       │      ├── 扫描 scripts/ → 统计行数 + 提取头部注释
       │      ├── 解析 VERIFY.md → 提取条目和状态
       │      ├── 读取 configs/recommended-plugins.json → 插件列表
       │      └── 输出: site/data.json
       │
       ├── 2. (可选) 运行 scripts/export-memory.sh
       │      ├── 读取 ~/.claude/projects/*/memory/*.md
       │      ├── 解析 frontmatter (name, description, type)
       │      ├── 输出: memory-data.json → 上传到私有 Gist
       │      └── 注意: 仅在本地运行或有 MEMORY_GIST_TOKEN secret 时
       │
       └── 3. 部署 site/ 到 GitHub Pages

site/
├── index.html          # SPA 壳 + 所有页面模板
├── css/
│   └── style.css       # 主题系统 (CSS 变量) + 布局 + 组件
├── js/
│   ├── app.js          # 路由、页面渲染、搜索
│   ├── data-loader.js  # 加载 data.json + 从 Gist 加载 memory
│   └── markdown.js     # marked.js 封装，渲染 SKILL.md
├── data.json           # 自动生成，已 gitignore
└── favicon.ico
```

## 数据结构

### data.json

```json
{
  "generated_at": "2026-03-30T12:00:00Z",
  "git_branch": "dev",
  "git_commit": "abc1234",

  "skills": [
    {
      "name": "brainstorming",
      "description": "Turn ideas into designs through dialogue",
      "version": "5.0.6",
      "source": "superpowers",
      "path": "skills/superpowers/brainstorming/SKILL.md",
      "content_md": "# Brainstorming Ideas Into Designs\n\n..."
    }
  ],

  "hooks": [
    {
      "name": "notification.telegram",
      "file": "hooks/notification.telegram.json",
      "events": ["Notification", "Stop"],
      "description": "Telegram Bot API 通知：权限请求、空闲、任务完成",
      "content": "{...}"
    }
  ],

  "configs": [
    {
      "name": "settings.json",
      "file": "configs/settings.json",
      "description": "全局配置：Telegram hooks + statusline",
      "content": "{...}"
    }
  ],

  "scripts": [
    {
      "name": "telegram-bridge.sh",
      "file": "scripts/telegram-bridge.sh",
      "lines": 641,
      "description": "Telegram 消息桥接守护进程",
      "dependencies": ["jq", "tmux", "curl"]
    }
  ],

  "plugins": [
    {
      "name": "superpowers",
      "description": "Enhanced development workflows",
      "author": "anthropics",
      "install": "claude plugin add @anthropics/claude-code-superpowers"
    }
  ],

  "verify": {
    "pending": [
      {
        "title": "CLAUDE.md 改进",
        "commit": "pending",
        "date": "2026-02-10",
        "method": "阅读 CLAUDE.md，确认新增内容准确",
        "expected": "Quick Start 有依赖说明"
      }
    ],
    "verified": [
      {
        "title": "CLAUDE.md 质量优化",
        "commit": "abf0ecc",
        "date": "2026-02-10",
        "result": "验证通过"
      }
    ],
    "deprecated": []
  },

  "stats": {
    "total_skills": 22,
    "total_scripts_lines": 1036,
    "total_verified": 14,
    "total_pending": 2,
    "total_plugins": 10
  }
}
```

### memory-data.json（私有 Gist）

```json
{
  "exported_at": "2026-03-30T12:00:00Z",
  "memories": [
    {
      "name": "Testing approach",
      "description": "Integration tests must hit real database",
      "type": "feedback",
      "file": "feedback_testing.md",
      "content_md": "---\nname: Testing approach\n...\n---\n\nIntegration tests must..."
    }
  ],
  "stats": {
    "feedback": 3,
    "project": 2,
    "reference": 2,
    "user": 1
  }
}
```

## 页面设计

### 1. Dashboard（首页 /）

- **统计卡片**：4 张卡片（Skills 数量、已验证数、脚本行数、推荐插件数）— 来自 `data.stats`
- **最近动态**：最近 5 条 VERIFY.md 条目，按日期排序，显示 pending/verified 状态
- **快捷跳转**：点击统计卡片跳转到对应页面

### 2. Skills 列表（/skills）

- **过滤栏**：Chip 按钮按来源过滤（all / superpowers / plugin-dev / claude-md / custom）
- **列表视图**：每行显示 名称、来源、描述、版本
- **点击行** → 跳转到 Skill 详情页
- 数据来自 `data.skills`

### 3. Skill 详情（/skills/:name）

- **返回链接** → 回到 Skills 列表
- **头部**：Skill 名称、来源 collection、版本号、文件路径
- **Frontmatter 区块**：等宽字体渲染，key/value 颜色区分
- **正文**：完整 SKILL.md 通过 marked.js 渲染
- 数据来自 `data.skills[n].content_md`

### 4. Hooks（/hooks）

- **每个 Hook 一张卡片**：名称、文件路径、事件类型标签、描述
- **事件标签**：按类型上色（PreToolUse=蓝、Notification=黄、Stop=红）
- **点击卡片** → 展开显示完整 JSON 配置（语法高亮）
- 数据来自 `data.hooks`

### 5. Configs（/configs）

- **列表视图**：文件名、描述、路径
- **点击** → 展开显示配置内容（JSON 语法高亮）
- **特殊区块**：configs/CLAUDE.md 的全局规则摘要（Markdown 渲染）
- 数据来自 `data.configs`

### 6. Memory（/memory）

- **鉴权门**（默认状态）：锁图标 + 密码输入框 + Unlock 按钮
- **鉴权流程**：
  1. 输入 Gist token（或通过 URL 参数 `?token=xxx` 传入）
  2. JS 用 token 作为 Bearer header 请求 `https://api.github.com/gists/{GIST_ID}`
  3. 解析响应 → 渲染 memory 内容
  4. Token 存入 sessionStorage（关闭标签页自动清除，不持久化）
- **解锁后视图**：
  - 类型统计条（feedback / project / reference / user 各多少条）
  - 表格：类型标签、名称、描述、文件名
  - 点击行 → 展开显示完整 memory 内容（Markdown 渲染）

### 7. Verification（/verify）

- **进度条**：已验证 / 总数 比例，绿色填充
- **标签页**：待验证 | 已验证 | 已废弃
- **待验证条目**：黄色勾选框、标题、commit 引用、日期、验证方法、预期效果
- **已验证条目**：绿色勾选框、标题、commit 引用、日期、实际效果
- **已废弃条目**：删除线、废弃原因
- 数据来自 `data.verify`

### 8. Scripts（/scripts）

- **每个脚本一张卡片**：名称、行数标签、描述段落、依赖标签
- **点击卡片** → 展开显示源码头部注释 + 前 50 行（语法高亮）
- 数据来自 `data.scripts`

## 公共组件

### 侧边栏

- 固定 260px 宽度
- 分组：Overview、Extensions（Skills/Hooks/Configs）、Runtime（Memory/Verification/Scripts）
- 每项：彩色圆点 + 名称 + 角标（数量或锁图标）
- Skills 项：可展开子导航，按 collection 过滤
- 底部：当前分支 + 最后更新时间
- 选中态：高亮背景 + 右侧强调色边框

### 顶部栏

- 面包屑导航（路径可点击）
- 搜索框（Ctrl+K 快捷键）：跨所有页面全文搜索
- 主题切换按钮（月亮/太阳图标）

### 主题系统

- CSS 自定义属性，`:root` 定义暗色默认值，`[data-theme="light"]` 覆盖为亮色
- 切换时更新 `<html>` 的 `data-theme` 属性
- 偏好存 `localStorage('theme')`
- 过渡动画：0.3s background/color

### 搜索

- 全局搜索，覆盖所有数据类型
- Ctrl+K 或点击搜索框触发
- 下拉结果按类型分组（Skills、Hooks、Configs、Memory）
- 点击结果 → 跳转到对应页面/条目

## 数据生成脚本

### scripts/generate-site-data.sh

```bash
#!/bin/bash
# 从仓库内容生成 site/data.json
# 依赖: jq, bash 4+

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$REPO_ROOT/site/data.json"

# 从 Markdown 文件解析 YAML frontmatter
parse_frontmatter() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

# 主流程: 扫描目录 → 构建 JSON → 写入输出
```

核心操作：
1. `find skills/ -name "SKILL.md"` → 解析每个 frontmatter + 读取正文内容
2. `find hooks/ -name "*.json" -not -path "*/examples/*"` → 解析 hook 配置
3. `find configs/ -not -name "*.example"` → 列出配置文件
4. `wc -l scripts/*.sh` → 统计脚本行数
5. 用正则解析 VERIFY.md 提取条目和状态
6. 直接读取 `configs/recommended-plugins.json`
7. 通过 `jq` 组装为 JSON

### scripts/export-memory.sh

```bash
#!/bin/bash
# 导出 memory 文件为 JSON 并上传到私有 Gist
# 本地运行: ./scripts/export-memory.sh
# 依赖: jq

MEMORY_DIR="$HOME/.claude/projects/*/memory"
```

核心操作：
1. Glob 匹配 `~/.claude/projects/*/memory/*.md`
2. 解析每个文件的 frontmatter（name、description、type）
3. 读取完整内容
4. 组装为 JSON
5. 通过 GitHub Gist API 上传（需要 `MEMORY_GIST_TOKEN`）

## GitHub Actions 工作流

### .github/workflows/deploy-dashboard.yml

```yaml
name: Deploy Dashboard
on:
  push:
    branches: [dev, main]

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate site data
        run: bash scripts/generate-site-data.sh

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./site
```

注意：Memory 导出仅在本地运行（需要访问 `~/.claude/`）。CI 工作流只生成公开数据。

## 安全性

- **Memory 数据不进仓库**：`memory-data.json` 只存在于私有 Gist
- **Token 处理**：纯客户端，存 sessionStorage（关闭标签页即清除）
- **无服务端代码**：纯静态站，无后端可攻击
- **Gist API**：用 personal access token 鉴权，仅需 `gist` scope
- **site/data.json 在 .gitignore 中**：每次部署重新生成，不提交到仓库

## 需要创建的文件

| 文件 | 用途 |
|------|------|
| `site/index.html` | SPA 壳 + 页面模板 |
| `site/css/style.css` | 主题系统 + 所有组件样式 |
| `site/js/app.js` | 路由、页面渲染、搜索 |
| `site/js/data-loader.js` | 加载 data.json 和 memory Gist |
| `site/js/markdown.js` | marked.js 封装 |
| `scripts/generate-site-data.sh` | 从仓库构建 data.json |
| `scripts/export-memory.sh` | 导出 memory 到 Gist（仅本地） |
| `.github/workflows/deploy-dashboard.yml` | CI/CD 流水线 |
| `.gitignore` 更新 | 添加 `site/data.json` |

## 不在范围内

- 服务端渲染或构建工具
- Gist token 之外的用户认证
- 实时数据（页面显示最后一次 push 时的快照）
- 移动端适配（个人桌面工具）
- Agents 和 Commands 页面（目前只有示例/模板文件 — 显示空状态 "暂无内容"）
