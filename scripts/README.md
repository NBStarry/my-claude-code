# Scripts

Claude Code 自定义脚本。

## statusline.sh

自定义状态栏脚本，在 Claude Code 终端底部显示丰富的上下文信息。

### Features / 功能

- 显示 `用户名@主机名:当前目录`（绿色/蓝色）
- 显示当前使用的模型名称（青色）
- 显示 Git 当前分支（黄色）
- 显示上下文窗口使用率，带颜色编码：
  - 绿色：< 50%（充裕）
  - 黄色：50%-80%（注意）
  - 红色：>= 80%（紧张）

### Preview / 效果预览

```
user@mac:~/projects/myapp Claude Opus 4.6 (main) [ctx:34%]
```

### Dependencies / 依赖

- `jq` - JSON 解析工具
- `git` - 用于获取分支信息

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Installation / 安装

```bash
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

确保 `~/.claude/settings.json` 中包含：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

### How It Works / 工作原理

Claude Code 通过 stdin 向状态栏脚本传入 JSON 数据，包含模型信息和上下文窗口用量等。脚本读取这些数据，结合本地环境信息（用户名、主机名、目录、Git 分支），组合输出带 ANSI 颜色编码的状态栏字符串。
