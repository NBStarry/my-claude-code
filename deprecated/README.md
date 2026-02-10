# Deprecated / 废案

已废弃的方案。保留代码供参考，不再维护。

## QQ 双向通信方案

**废弃原因：** 腾讯风控频繁检测机器人账号并强制下线，导致通知和消息桥接不可用。该方案依赖非官方的 LLOneBot 插件（NTQQ 插件），无法保证稳定性。已迁移到 Telegram Bot API（官方支持，无封号风险）。

**替代方案：** Telegram 双向通信（`scripts/notify-telegram.sh` + `scripts/telegram-bridge.sh`）

### 废弃文件

| 文件 | 原路径 | 说明 |
|------|--------|------|
| `notify-qq.sh` | `scripts/notify-qq.sh` | QQ 出站通知脚本（通过 LLOneBot HTTP API） |
| `qq-bridge.sh` | `scripts/qq-bridge.sh` | QQ 入站桥接守护进程（通过 LLOneBot WebSocket） |
| `notification-qq.json` | `hooks/notification.json` | QQ 通知 hook 配置模板 |
| `settings-qq.json` | `configs/settings.json` | QQ 版全局设置（含 hook 配置） |

### 相关提交历史

| Commit | 日期 | 说明 |
|--------|------|------|
| `aedcfff` | 2026-02-06 | feat: QQ 消息通知 (notify-qq.sh) |
| `99adfce` | 2026-02-06 | fix: notify-qq.sh 格式优化 |
| `6beec01` | 2026-02-06 | feat: QQ 消息桥接 (qq-bridge.sh) |
| `a90cd82` | 2026-02-07 | feat: QQ 通知显示上下文百分比 |
| `882cb8e` | 2026-02-07 | fix: qq-bridge.sh TCP 状态 watchdog |
| `218d27b` | 2026-02-09 | fix: qq-bridge.sh v2 全面改进（FIFO/keeper 架构） |
| `05ef7de` | 2026-02-09 | feat: qq-bridge.sh 自动启动 QQ + 启动通知 |
| `04771c7` | 2026-02-09 | feat: notify-qq.sh Agent Team 来源显示 |
| `4c8ce1d` | 2026-02-09 | feat: 迁移到 Telegram（QQ 方案被替代） |

### 依赖（已不再需要）

- **LiteLoaderQQNT** — NTQQ 插件加载器
- **LLOneBot** — OneBot 11 API 插件（HTTP 端口 3000 + WebSocket 端口 3001）
- **websocat** — CLI WebSocket 客户端（仅 qq-bridge.sh 需要）
- **双 QQ 号** — 机器人号（桌面登录）+ 主号（手机接收）
