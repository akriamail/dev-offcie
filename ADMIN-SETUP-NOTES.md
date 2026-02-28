# Admin 安装与配置记录（可复用）

> 角色：公网运维入口，作为 `gw` 的反向隧道落点与 K3s 兜底入口。

## 1. 基本信息（按实际填写）

- admin 公网 IP：`39.107.113.26`
- gw：`192.168.1.100`
- master：`192.168.1.240`

## 2. 反向隧道端口

- `admin:16022 -> gw:22`
- `admin:16443 -> master:6443`

## 3. 确认端口监听

```bash
ss -lntp | grep -E '16022|16443'
```

## 4. kubeconfig（兜底入口）

```bash
# 确认指向本地转发端口
grep -n "server:" ~/.kube/config
# 期望: https://127.0.0.1:16443

kubectl get nodes -o wide
kubectl get pods -A
```

## 5. 常用排障

```bash
# 隧道是否存活（gw 侧会有 autossh-admin）
ssh -p 16022 root@127.0.0.1

# 直连到 master API（经过反向隧道）
curl -k https://127.0.0.1:16443/healthz
```

## 6. 回滚点

- 如需停止反向隧道：在 `gw` 停止 `autossh-admin.service`。
- 如需恢复 `kubeconfig`：改回 master 直连地址（不经 16443）。
