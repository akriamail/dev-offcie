# Insightful Dev 运维说明

本目录用于维护 `gw <-> admin` 反向隧道与 K3s 管理通道，以及 Mac 本机直管集群的操作基线。

## 1. 拓扑与职责

- `admin`（公网运维入口）: `39.107.113.26`
- `gw`（内网网关）: `192.168.1.100`（hostname: `net`）
- `master`（k3s 控制面）: `192.168.1.240`
- 架构原则:
- 集群管理权限在 `admin/Mac kubeconfig`，不在 `gw`。
- `gw` 仅承担网络转发与跳板职责。

## 2. 固定通道

- 反向隧道方向: `gw -> admin`
- `admin:16022 -> gw:22`
- `admin:16443 -> master:6443`

## 3. 执行位置约定

- 在 **Mac 本地** 执行:
- `kuse dev|prod`
- `kubectl ...`
- `ssh -fN admin-k8s-dev`（dev 隧道）
- 在 **admin** 执行:
- `kubectl`（作为兜底入口）
- `ss -lntp | grep -E '16022|16443'`
- 在 **gw** 执行:
- `systemctl/journalctl` 检查 `autossh-admin.service`

## 4. 当前状态（2026-02-28）

- `admin` 侧 `kubectl` 已修复并可用（`v1.35.2`）。
- `admin` 侧 kubeconfig 已指向 `https://127.0.0.1:16443`。
- Mac 已完成免密登录 `admin`（`Host admin-k8s`）。
- Mac 已完成 dev 隧道别名（`Host admin-k8s-dev`，本地 `16444 -> admin:16443`）。
- Mac 已落地环境切换:
- `kuse prod -> ~/.kube/prod.yaml`
- `kuse dev -> ~/.kube/dev.yaml`

## 5. Mac 本机直管（推荐）

### 5.1 切换到 prod

```bash
kuse prod
kubectl get nodes -o wide
```

### 5.2 切换到 dev

```bash
# 先确保 dev 隧道在线（不在线就启动）
ssh -fN admin-k8s-dev

kuse dev
kubectl get nodes -o wide
kubectl get pods -A
```

### 5.3 防误操作检查

```bash
echo "$KUBECONFIG"
kubectl config current-context
```

## 6. admin / gw 兜底检查

### 6.1 admin 侧

```bash
ss -lntp | grep -E '16022|16443'
kubectl get nodes -o wide
kubectl get pods -A
```

### 6.2 gw 侧

```bash
sudo systemctl status autossh-admin --no-pager
sudo journalctl -u autossh-admin -n 100 --no-pager
```

## 7. 手册入口

- 团队上手与日常操作手册（新成员必读）: `OPS-TEAM-HANDBOOK.md`
- 个人详细操作与变更日志: `PERSONAL-OPS.md`

## 8. 维护约定（强制）

- 每次运维操作后，必须更新 `PERSONAL-OPS.md` 的“运维日志”。
- 最少记录:
- 日期时间（UTC+8）
- 变更项
- 验证结果
- 回滚点
