# Worker 节点安装记录（可复用）

> 适用于 Ubuntu 24.04 纯净机，角色为 K3s worker（agent）。

## 1. 基本信息（按实际填写）

- 机器 IP：`192.168.1.xxx`
- 默认网关（切换前）：`192.168.1.1`
- gw（透明代理网关）：`192.168.1.100`
- master：`192.168.1.240`
- admin：`39.107.113.26`

## 2. 上线前准备

```bash
# 记录旧网关与网卡
OLD_GW=$(ip route | awk '/default/ {print $3; exit}')
DEV=$(ip route | awk '/default/ {print $5; exit}')
echo "OLD_GW=$OLD_GW DEV=$DEV"

# 保底：到 admin 永远直连
ip route replace 39.107.113.26 via "$OLD_GW" dev "$DEV"

# 切默认网关到 gw
ip route replace default via 192.168.1.100 dev "$DEV"

# 验证出网
curl -4 -m 8 https://api.ipify.org; echo
curl -4 -m 8 -I https://registry.k8s.io/v2/
```

> 若上述验证失败，先回滚默认网关。

```bash
ip route replace default via "$OLD_GW" dev "$DEV"
```

## 3. 加入集群（K3s agent）

在 `master` 上拿 token：

```bash
cat /var/lib/rancher/k3s/server/node-token
```

在 `worker` 上安装：

```bash
curl -sfL https://get.k3s.io | \
K3S_URL=https://192.168.1.240:6443 \
K3S_TOKEN="<TOKEN>" \
sh -
```

检查服务：

```bash
systemctl status k3s-agent --no-pager
```

## 4. 集群侧验证

在 `master` 或 Mac 上：

```bash
kubectl get nodes -o wide
```

## 5. 回滚点

```bash
# 节点侧回滚默认网关
ip route replace default via "$OLD_GW" dev "$DEV"

# 卸载 k3s-agent（如需）
/usr/local/bin/k3s-agent-uninstall.sh
```
