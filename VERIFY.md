# Verification Checklist / 验证清单

所有新增或修改的配置在合并到 `main` 之前，必须经过用户亲自验证。

## How It Works / 工作流程

1. 每次向 `dev` 分支提交前，必须先在本清单中添加对应的待验证记录
2. VERIFY.md 的更新必须包含在同一个 commit 中（与代码/文档改动一起）
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

- [ ] **notify-qq.sh Agent Team 来源显示** (commit: 04771c7, date: 2026-02-09)
  - 验证方法：
    1. Team 模式测试：检查通知第一行是否包含 agent 名称，格式 `[任务完成] 项目名 [ctx:XX%] (agent-name)`
    2. 非 Team 模式测试：确保没有 agent 信息时通知格式保持不变
    3. 所有 hook 类型测试：stop、idle_prompt、permission_prompt 都能正确显示 agent 名称
  - 预期效果：Team 模式显示 agent 名称，非 team 模式向后兼容
  - 实际效果：（验证后填写）

- [ ] **qq-bridge.sh TCP 状态 watchdog** (commit: 882cb8e, date: 2026-02-07)
  - 验证方法：长时间运行后检查 bridge 是否自动重连（QQ 重启后仍能收发消息）
  - 预期效果：死连接在 30 秒内被检测并自动重连
  - 实际效果：（验证后填写）

- [ ] **qq-bridge.sh v2 全面改进** (commit: 218d27b, date: 2026-02-09)
  - 验证方法：
    1. 启动 bridge，发送 `/status`、`/log`、`/pane` 验证新命令
    2. 重启 Claude Code，检查 bridge 是否通过 hook 自动启动
    3. 长时间运行后检查 `sleep 2147483647` 进程数（应始终为 1）
    4. 关闭 QQ 后检查 bridge 不会疯狂重连（等待 LLOneBot 上线）
  - 预期效果：无进程泄漏、自动启动、新命令正常、日志自动轮转
  - 实际效果：（验证后填写）

- [ ] **qq-bridge.sh 自动启动 QQ + 启动通知** (commit: 05ef7de, date: 2026-02-09)
  - 验证方法：
    1. 关闭 QQ，重启 bridge，检查 QQ 是否自动被打开
    2. 发送 `/restart`，检查是否收到两条通知（重启中 + 已启动）
  - 预期效果：QQ 自动启动、/restart 有完整通知
  - 实际效果：（验证后填写）

---

## Verified / 已验证项目

<!-- 已验证通过并合并到 main 的改动记录 -->

- [x] **QQ 消息桥接 (qq-bridge.sh)** (commit: 6beec01+5198337, date: 2026-02-06)
  - 前提：websocat 已安装，tmux 中运行 Claude Code，LLOneBot 在线
  - 验证方法：手机 QQ 发送消息，检查是否注入到 Claude Code 终端
  - 预期效果：发送 "1" → Claude Code 选择授权；发送文本 → 作为输入；`/status` → 返回状态
  - 实际效果：`/status` 返回状态正常，文本消息成功注入终端

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

- [x] **notify-qq.sh 格式优化** (commit: 99adfce, date: 2026-02-06)
  - 验证方法：等待 hook 触发，检查 QQ 通知格式
  - 预期效果：`[任务完成] 项目名` 单行标题，空行分隔回复和上下文，无分割线，无 emoji
  - 实际效果：已确认格式正确

- [x] **configs/CLAUDE.md 全局指令** (commit: 448ec7c, date: 2026-02-06)
  - 验证方法：在任意项目中确认 Claude Code 遵守 commit 规则
  - 预期效果：代码与相关文档始终在同一 commit 中提交
  - 实际效果：已确认生效

- [x] **QQ 通知显示上下文百分比 (notify-qq.sh)** (commit: a90cd82, date: 2026-02-07)
  - 验证方法：等待 hook 触发，检查 QQ 通知第一行是否包含 `[ctx:XX%]`
  - 预期效果：`[任务完成] my-project [ctx:34%]`
  - 实际效果：上下文百分比显示正常，符合预期

- [x] **远程访问文档 (README.md)** (commit: e5deddc, date: 2026-02-09)
  - 验证方法：检查 README.md 中 Remote Access 章节内容是否准确
  - 预期效果：包含 SSH + Tailscale + tmux 配置步骤、架构图、常见问题
  - 实际效果：文档内容准确，符合预期

---

## Deprecated / 已废弃项目

- [-] **通知改用 display alert 持久对话框** (date: 2026-02-06)
  - 原因：改用 QQ 通知方案，macOS 系统通知不再需要
