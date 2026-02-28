# Master 安装记录（可复用）

> 适用于 Ubuntu 24.04 纯净机，角色为 K3s control-plane。

## 1. 基本信息（按实际填写）

- master：`192.168.1.240`
- gw：`192.168.1.100`
- admin：`39.107.113.26`

## 2. 先切默认网关到 gw（若需走透明代理）

```bash
OLD_GW=$(ip route | awk '/default/ {print $3; exit}')
DEV=$(ip route | awk '/default/ {print $5; exit}')

# 保底：到 admin 直连
ip route replace 39.107.113.26 via "$OLD_GW" dev "$DEV"

# 切默认网关到 gw
ip route replace default via 192.168.1.100 dev "$DEV"

# 验证
curl -4 -m 8 https://api.ipify.org; echo
curl -4 -m 8 -I https://registry.k8s.io/v2/
```

## 3. 安装 K3s server

```bash
curl -sfL https://get.k3s.io | sh -
```

检查服务：

```bash
systemctl status k3s --no-pager
kubectl get nodes -o wide
```

## 4. 清理本机代理（重要）

避免 `http_proxy` 抢走透明代理流量：

```bash
sed -i.bak '/proxy/Id' /etc/environment
for v in http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY; do unset $v; done

# 如果本机有 sing-box 监听 1083，需要停掉
systemctl disable --now sing-box
pkill -f '/usr/local/bin/sing-box' || true
ss -lntp 'sport = :1083' || true
```

## 5. 获取节点加入 token

```bash
cat /var/lib/rancher/k3s/server/node-token
```

## 6. 回滚点

```bash
# 节点侧回滚默认网关
ip route replace default via "$OLD_GW" dev "$DEV"

# 卸载 k3s server（如需）
/usr/local/bin/k3s-uninstall.sh
```
