# 连接 4Paradigm 内网机器（Clash 代理）

通过 Clash Verge Internal 代理组连接内网资源。这是主要连接方式。

如果本方案失效，提示用户使用 `/connect-internal-backup` 切换到备用方案。

## 前提

- Clash Verge Rev 已启动，mixed port 7897 可用
- 全局 Script.js 已注入 Internal 代理组（4pd-aliyun-B / C）
- 规则路由：`*.4paradigm.com` → DIRECT；`172.28.0.0/16`(wlcb) → Internal-WLCB(C)；其余内网 → Internal(B)

## 连接前检查

先验证 Clash 代理和内网连通性：

```bash
# 1. 检查 Internal 组状态
curl -s --unix-socket /tmp/verge/verge-mihomo.sock -H "Authorization: Bearer set-your-secret" http://localhost/proxies/Internal | python3 -m json.tool | grep -E '"now"|"all"'

# 2. 测试 SSH 连通
ssh -o ConnectTimeout=5 -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "hostname"
```

如果上述命令失败，提示用户：**"Clash 代理连接失败，请检查 Clash Verge 是否运行。如无法恢复，可使用 `/connect-internal-backup` 切换备用方案。"**

## SSH 到内网机器

```bash
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@<内网IP>
```

### 可达机器

| IP | 备注 | 4pd-aliyun-B | 4pd-aliyun-C |
|----|------|:---:|:---:|
| 172.26.1.45 | soup-gpu13 (3x A100-80GB) | OK | OK |
| 172.28.4.55 | ucloud-wlcb-gpu-055 (user: **hanzebei**) | OK | OK |
| 172.28.4.23 | ucloud-wlcb-gpu-023 (user: **hanzebei**) | OK | OK |
| 10.255.143.17 | 天枢集群节点 | OK | OK |

**Clash 代理组路由策略（2026-04-12 更新）**
- **Internal** 组（默认 B）：soup-gpu13、天枢集群等非 wlcb 内网
- **Internal-WLCB** 组（默认 C）：wlcb 机房 `172.28.0.0/16`
- **DIRECT**：`*.4paradigm.com` 公司域名直连（浏览器访问 s-hr 等内网站点）

**B / C 代理说明**
- **4pd-aliyun-B**（port 231，SOCKS5）：全部内网段可达
- **4pd-aliyun-C**（port 241，SOCKS5+TLS）：全部内网段可达

**注意**：B/C 是 SOCKS5 代理，无法解析内网域名（如 `s-hr.4paradigm.com`）。公司域名走 DIRECT 直连，不走代理。

## wlcb-055 / wlcb-023 连接注意事项 ⚠️

**必须用 `hanzebei` 用户，不是 `root`**——这两台是 ucloud 环境，root 的 authorized_keys 里没有本机 key，会直接 `Permission denied (publickey)`。

已在 `~/.ssh/config` 配好 alias，直接用：

```bash
ssh wlcb-55   # → hanzebei@172.28.4.55
ssh wlcb-23   # → hanzebei@172.28.4.23
```

手动形式：
```bash
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" hanzebei@172.28.4.55
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" hanzebei@172.28.4.23
```

### 公网访问（55 / 23 无公网，必须走 soup13 代理）

**国内公网**（apt / pip / 国内站点）：
```bash
export http_proxy="http://172.26.1.45:10022"
export https_proxy="http://172.26.1.45:10022"
```

**境外网络**（GitHub raw、Google、HuggingFace 等）：
```bash
export http_proxy="http://<USER>:<REDACTED>@172.26.1.45:226"
export https_proxy="http://<USER>:<REDACTED>@172.26.1.45:226"
```

同时提供 SOCKS5：`socks5://<REDACTED>

**代理不通的修复**：登 soup-gpu13 检查容器，必要时重启：
```bash
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "docker ps | grep 4pd-P-server"

# 重建（境外出口走 ss 上游）
docker run -d \
    -e GOST_LOGGER_LEVEL=error \
    --net host \
    --restart always \
    --name 4pd-P-server \
    harbor-contest.4pd.io/zhangyiqun/public/gogost/gost:latest \
    -L "http://<USER>:<REDACTED>@:226" \
    -L "socks5://<REDACTED>" \
    -F "ss://<USER>:<REDACTED>@lganenc9enhy.yangliq.com:36005"
```
修不好就直接把状态告诉用户。

**踩坑记录（2026-04-09）**
- 用 `root@` 直连 55/23 → `Permission denied (publickey)`，这是用户错，不是网络错
- 从 soup-gpu13 跳转到 55/23 也不通（soup13 的 key 没授权）
- 新机器首次配置需要把本机 `~/.ssh/id_rsa.pub` 追加到目标机 `~hanzebei/.ssh/authorized_keys`，通常走公司 jumpserver（`ulcb-23-2A` alias → `system-jumpserver.4paradigm.com:10022`）一次性灌入

## 天枢 K8s 集群

kubeconfig 在 soup-gpu13: `/root/.kube/config.tianshu`

```bash
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "kubectl --kubeconfig=/root/.kube/config.tianshu <command>"
```

例:
```bash
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "kubectl --kubeconfig=/root/.kube/config.tianshu get nodes"
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "kubectl --kubeconfig=/root/.kube/config.tianshu get pods -A wide | tail -20"
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "kubectl --kubeconfig=/root/.kube/config.tianshu top nodes"
```

## 从 soup-gpu13 跳转到其他内网机器

```bash
ssh -o ProxyCommand="nc -X connect -x 127.0.0.1:7897 %h %p" root@172.26.1.45 "ssh root@<目标IP> '<命令>'"
```

## 腾讯云 K8s 集群（从 Mac 直接操作）

kubeconfig: `~/Documents/4Paradigm/机器资源使用/集群配置/kubeconfig_腾讯云.yaml`

```bash
KUBECONFIG="~/Documents/4Paradigm/机器资源使用/集群配置/kubeconfig_腾讯云.yaml" kubectl <command>
```

## 关键信息

- Clash mixed port: `127.0.0.1:7897`
- Clash API socket: `/tmp/verge/verge-mihomo.sock`，secret: `<REDACTED>`
- Internal 代理组（默认 B）: `4pd-aliyun-B`(port 231) — 非 wlcb 内网
- Internal-WLCB 代理组（默认 C）: `4pd-aliyun-C`(port 241/TLS) — wlcb 机房 172.28.0.0/16
- `*.4paradigm.com` 域名 → DIRECT 直连（B/C 无法解析内网域名）
- SOCKS5 server: `39.104.81.144`
- 天枢 K8s API: `10.255.143.11:6443`
- 腾讯云 K8s API: `43.144.255.95`
