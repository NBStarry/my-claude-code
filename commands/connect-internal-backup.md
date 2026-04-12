# 连接 4Paradigm 内网机器（备用方案）

Clash 代理不可用时的备用连接方式。优先使用 SakuraFrp，不行再试 Cloudflare Tunnel。

如果本方案也不可用，提示用户在云桌面启动 frpc 或 cloudflared。

## 方案 1：SakuraFrp（国内节点，10Mbit/s）

### 测试连通

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes soup13-frp "hostname" 2>&1
```

连通 -> 直接使用。不通 -> 执行 IP 认证 + 重试。超时 -> 提示用户在云桌面启动 frpc。

### IP 认证（frpc 重启后需执行一次）

```bash
curl -k -s --noproxy "*" -X POST -d "persist_auth=on" -d "pw=<REDACTED>" "https://frp-six.com:19095/"
```

认证后重试 `ssh soup13-frp`。仍然超时 -> 提示用户在云桌面执行：
```bash
nohup natfrp_frpc -f <REDACTED> > /tmp/natfrp.log 2>&1 &
```

### 操作天枢 K8s 集群

kubeconfig 在 soup-gpu13: `/root/.kube/config.tianshu`

```bash
ssh soup13-frp "kubectl --kubeconfig=/root/.kube/config.tianshu <command>"
```

例:
```bash
ssh soup13-frp "kubectl --kubeconfig=/root/.kube/config.tianshu get nodes"
ssh soup13-frp "kubectl --kubeconfig=/root/.kube/config.tianshu get pods -A wide | tail -20"
```

### 跳转到其他内网机器

```bash
ssh soup13-frp "ssh root@<内网IP>"
```

可达机器: 172.28.4.55, 172.28.4.23, 10.255.143.17

---

## 方案 2：Cloudflare Tunnel（兜底，延迟 100-300ms）

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes soup13-cf "hostname" 2>&1
```

失败则提示用户在云桌面启动：
```bash
nohup cloudflared tunnel --url ssh://localhost:22 > /tmp/cloudflared.log 2>&1 &
grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log
```

获取新地址后更新 `~/.ssh/config` 中 `soup13-cf` 的 HostName，并清除旧 host key：
```bash
ssh-keygen -R <旧地址>
```

---

## 关键信息

- SakuraFrp 认证密码: `<REDACTED>`
- SakuraFrp 节点: `frp-six.com:19095`
- frpc 路径: `/usr/local/bin/natfrp_frpc`
- 天枢 K8s API: `10.255.143.11:6443`
- 文档: `~/Documents/4Paradigm/机器资源使用/网络代理/内网穿透.md`
