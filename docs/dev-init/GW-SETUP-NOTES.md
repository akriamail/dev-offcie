# GW 安装与配置记录（可复用）

> 目的：一台新 `gw` 机器按此步骤完成透明代理与节点出网接管；与 K3s 控制面无关。

## 1. 角色与假设

- `gw`：`192.168.1.100`（内网网关）
- 节点源 IP（示例）：`192.168.1.240/241/242`
- `admin` 公网 IP：`39.107.113.26`
- `sing-box`：`/usr/local/bin/sing-box`，配置路径 `/etc/sing-box/config.json`
- 透明代理入站端口：`60080`（redirect）
- 本机联通测试端口：`17890`（mixed，仅供 `gw` 本机 `curl -x` 验证）

## 2. 安装与服务

```bash
# 安装 sing-box（按你的二进制来源）
install -m 0755 ./sing-box /usr/local/bin/sing-box

# systemd
cat >/etc/systemd/system/sing-box.service <<'SERVICE'
[Unit]
Description=sing-box
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now sing-box
```

## 3. sing-box 配置（关键字段）

- 必须包含：
- `inbound`：
- `mixed`：`127.0.0.1:17890`（本机测试）
- `redirect`：`0.0.0.0:60080`（透明代理 TCP 入口）
- `outbound`：`vmess`（HK 出口）+ `direct`
- `route`：`lan-tcp` 走 `vmess`

```json
{
  "inbounds": [
    { "type": "mixed", "tag": "ops-test", "listen": "127.0.0.1", "listen_port": 17890 },
    { "type": "redirect", "tag": "lan-tcp", "listen": "0.0.0.0", "listen_port": 60080 }
  ],
  "outbounds": [
    { "type": "vmess", "tag": "hk-vmess", "server": "<vmess-host>", "server_port": <port>, "uuid": "<uuid>", "security": "auto" },
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "rules": [
      { "inbound": "lan-tcp", "outbound": "hk-vmess" }
    ]
  }
}
```

## 4. 内核转发

```bash
# 启用转发并持久化
sysctl -w net.ipv4.ip_forward=1
cat >/etc/sysctl.d/99-gw-forward.conf <<'SYSCTL'
net.ipv4.ip_forward=1
SYSCTL
sysctl --system
```

## 5. ipset 与 iptables（透明代理）

```bash
# 安装 ipset
apt-get update && apt-get install -y ipset

# 创建节点集
ipset create k3s_nodes hash:ip -exist
ipset flush k3s_nodes
for ip in 192.168.1.240 192.168.1.241 192.168.1.242; do ipset add k3s_nodes $ip -exist; done
ipset list k3s_nodes

# NAT 透明代理链
iptables -t nat -N K3S_PROXY 2>/dev/null || true
iptables -t nat -F K3S_PROXY

# 放行内网与 admin 公网
iptables -t nat -A K3S_PROXY -d 10.0.0.0/8 -j RETURN
iptables -t nat -A K3S_PROXY -d 172.16.0.0/12 -j RETURN
iptables -t nat -A K3S_PROXY -d 192.168.1.0/24 -j RETURN
iptables -t nat -A K3S_PROXY -d 127.0.0.0/8 -j RETURN
iptables -t nat -A K3S_PROXY -d 39.107.113.26/32 -j RETURN

# 所有 TCP 重定向到 sing-box redirect 端口
iptables -t nat -A K3S_PROXY -p tcp -j REDIRECT --to-ports 60080

# 挂到 PREROUTING（仅匹配节点源 IP + TCP）
while iptables -t nat -C PREROUTING -p tcp -m set --match-set k3s_nodes src -j K3S_PROXY 2>/dev/null; do
  iptables -t nat -D PREROUTING -p tcp -m set --match-set k3s_nodes src -j K3S_PROXY
done
iptables -t nat -A PREROUTING -p tcp -m set --match-set k3s_nodes src -j K3S_PROXY

iptables -t nat -S | grep -E 'K3S_PROXY|PREROUTING'
```

## 6. 连通性验证

```bash
# sing-box 本机代理联通验证（应返回 HK 出口 IP）
curl -4 -x http://127.0.0.1:17890 https://api.ipify.org; echo

# registry 可达性（应 200 / 401）
curl -4 -I -x http://127.0.0.1:17890 https://registry.k8s.io/v2/
curl -4 -I -x http://127.0.0.1:17890 https://registry-1.docker.io/v2/

# 透明代理命中计数
iptables -t nat -L K3S_PROXY -n -v
```

## 7. 节点切换默认网关（灰度）

```bash
# 在节点上记录旧网关
OLD_GW=$(ip route | awk '/default/ {print $3; exit}')
DEV=$(ip route | awk '/default/ {print $5; exit}')

# 保底：到 admin 的路由保持直连
ip route replace 39.107.113.26 via "$OLD_GW" dev "$DEV"

# 切默认网关到 gw
ip route replace default via 192.168.1.100 dev "$DEV"

# 验证
curl -4 -m 8 https://api.ipify.org; echo
crictl pull registry.k8s.io/pause:3.10
```

## 8. 回滚

```bash
# 节点侧回滚默认网关
ip route replace default via <OLD_GW> dev <DEV>

# gw 侧回滚透明代理
iptables -t nat -D PREROUTING -p tcp -m set --match-set k3s_nodes src -j K3S_PROXY
iptables -t nat -F K3S_PROXY
ipset flush k3s_nodes
```

## 9. 常见问题

- `ipset` 里 IP 写错（如 `183.168.*`）：会导致所有流量不命中。
- `REDIRECT` 端口用错：必须是 `redirect` 入站端口（本例 `60080`），不是 `mixed` 的 `17890`。
- 节点本机 `http_proxy` 残留：会绕开透明代理（`curl --noproxy '*'` 验证）。
- 在 `gw` 上跑 `crictl` 是无效的（它只在 K3s 节点上）。
