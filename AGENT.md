# AGENT Context: gw-admin-k3s 运维基线

本文件用于让代理每次进入仓库时，快速理解当前管理方式并按既定路径操作。

## 1. 当前角色与拓扑

- admin（公网运维入口）: `39.107.113.26`
- gw（内网网关）: `192.168.1.100`，hostname `net`
- k3s master: `192.168.1.240`

架构原则:
- `gw` 负责网络汇聚/转发，不承担集群权限主体。
- 集群管理权限在 `admin`（通过 kubeconfig/RBAC），不是在 `gw`。

## 2. 已落地通道（反向隧道）

由 `gw` 主动连接 `admin`，systemd 服务:
- `autossh-admin.service`

端口映射:
- `admin:16022 -> gw:22`
- `admin:16443 -> master:6443`

说明:
- 在 `admin` 上连接 `127.0.0.1:16022` 实际是进 `gw`。
- 在 `admin` 上访问 `https://127.0.0.1:16443` 实际是到 k3s apiserver。

## 2.1 透明代理阶段状态（2026-02-28）

- 当前阶段目标:
- 让 `master/worker` 经 `gw` 透明代理访问外网镜像源，再灰度切换默认网关到 `192.168.1.100`。
- 已完成:
- `gw` 已安装 `sing-box 1.12.22`（`/usr/local/bin/sing-box`）。
- `gw` 代理出海已验证（通过 `VMess` 到 HK）:
- `curl -x http://127.0.0.1:17890 https://api.ipify.org` 返回 `38.47.106.216`。
- `registry.k8s.io`/`registry-1.docker.io` 可达。
- `gw` 透明代理规则已下发:
- `ipset k3s_nodes` = `183.168.1.240`、`183.168.1.241`、`183.168.1.242`
- `iptables nat` 链 `K3S_PROXY` 已挂载到 `PREROUTING`，并放行 `183.168.1.0/24` 与 `39.107.113.26/32`。
- 未完成:
- 尚未执行三台节点默认网关灰度切换（当前停在“准备切 worker”）。
- 尚未完成“切换后节点/集群验收”闭环。

## 3. 当前 SSH 约定

admin 侧 `~/.ssh/config` 已约定使用别名:
- `Host gw` -> `127.0.0.1:16022`

常用命令:
```bash
ssh gw
```

## 4. 当前 K3s 管理约定

- 在 `admin` 上执行 `kubectl`。
- 使用 `admin` 本地 kubeconfig（如 `~/.kube/config`）。
- kubeconfig 中 apiserver 地址应指向:
- `https://127.0.0.1:16443`

## 5. 服务检查与排障（首选）

在 gw:
```bash
sudo systemctl status autossh-admin --no-pager
sudo journalctl -u autossh-admin -n 100 --no-pager
```

在 admin:
```bash
ss -lntp | grep -E '16022|16443'
ssh gw
```

端口位置提示:
- `127.0.0.1:17890` 是 `gw` 本机测试代理口。
- 在 `admin` 上直接 `curl -x http://127.0.0.1:17890 ...` 失败属预期，应使用 `ssh gw '<cmd>'` 执行。

## 6. 操作红线

- 不将“gw 有集群权限”作为前提；gw 默认仅网络转发。
- 不随意改动端口 `16022/16443`，除非同步更新全部文档与脚本。
- 透明代理落地前，不得先改节点默认网关。
- 透明代理规则必须放行（直连）:
- `39.107.113.26/32`（admin）
- 内网网段 `10.0.0.0/8`、`172.16.0.0/12`、`183.168.1.0/24`
- k3s `10.42.0.0/16`、`10.43.0.0/16`、`.svc`、`.cluster.local`
- 任何变更后必须更新:
- `README.md`
- `PERSONAL-OPS.md`（运维日志）
- 本文件（若基线变化）

## 7. 变更记录

### 2026-02-27

- 固化当前管理基线:
- `gw -> admin` 反向隧道已启用并自启动。
- 运维登录入口统一为 admin 上 `ssh gw`。
- 集群管理入口统一为 admin 上 `kubectl` + `127.0.0.1:16443`。

### 2026-02-28

- 新增透明代理调试基线:
- `gw` 上 `sing-box + VMess(HK)` 已联通。
- `ipset/iptables` 规则已下发，仍处于“节点灰度切网关前”。
