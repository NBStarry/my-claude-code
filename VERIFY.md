# Verification Checklist / 验证清单

所有新增或修改的配置在合并到 `main` 之前，必须经过用户亲自验证。

## How It Works / 工作流程

1. 所有改动提交到 `dev` 分支
2. 在本清单中记录改动内容和验证状态
3. 用户亲自测试改动效果后，勾选对应条目
4. 所有相关条目验证通过后，才可合并到 `main`

## Status Legend / 状态说明

- `[ ]` — 待验证：改动已提交，等待用户测试
- `[x]` — 已验证：用户确认改动效果符合预期
- `[-]` — 已废弃：改动不符合预期，需要修改或移除

---

## Pending Verification / 待验证项目

<!--
格式：
- [ ] **改动简述** (commit: abc1234, date: YYYY-MM-DD)
  - 验证方法：描述如何测试
  - 预期效果：描述预期结果
  - 实际效果：（验证后填写）
-->

- [ ] **notify-qq.sh 格式优化** (commit: 99adfce, date: 2026-02-06)
  - 验证方法：等待 hook 触发，检查 QQ 通知格式
  - 预期效果：`[任务完成] 项目名` 单行标题，空行分隔回复和上下文，无分割线，无 emoji
  - 实际效果：（待验证）

- [ ] **configs/CLAUDE.md 全局指令** (date: 2026-02-06)
  - 验证方法：在任意项目中确认 Claude Code 遵守 commit 规则
  - 预期效果：代码与相关文档始终在同一 commit 中提交
  - 实际效果：（待验证）

---

## Verified / 已验证项目

<!-- 已验证通过并合并到 main 的改动记录 -->

- [x] **statusline.sh 自定义状态栏** (commit: 3ad032f, date: 2026-02-06)
  - 验证方法：重启 Claude Code，检查底部状态栏
  - 预期效果：显示 user@host:dir + 模型名 + Git 分支 + 上下文用量
  - 实际效果：已确认正常工作（安装 jq 后）

- [x] **notification.json macOS 通知 hooks** (commit: 9db8d12, date: 2026-02-06)
  - 验证方法：重启 Claude Code，执行操作触发权限请求和任务完成
  - 预期效果：收到系统通知横幅 + 提示音
  - 实际效果：已确认工作正常

- [x] **QQ 消息通知 (notify-qq.sh)** (commit: aedcfff, date: 2026-02-06)
  - 前提：安装 LiteLoaderQQNT + LLOneBot，桌面 QQ 登录机器人号
  - 验证方法：手机 QQ 收到来自机器人号的通知消息
  - 预期效果：收到格式化的通知（含项目名、工具详情、授权选项）
  - 实际效果：已确认手机推送正常

---

## Deprecated / 已废弃项目

- [-] **通知改用 display alert 持久对话框** (date: 2026-02-06)
  - 原因：改用 QQ 通知方案，macOS 系统通知不再需要
