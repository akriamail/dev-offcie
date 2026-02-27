# 个人运维手册（gw-admin 隧道与 K3s 管理）

## 1. 目标

通过 `admin` 公网机稳定进入 `gw`，并经 `gw` 管理内网 K3s 集群。

## 2. 固定资产

- admin: `39.107.113.26`
- gw: `192.168.1.100`（`net`）
- master: `192.168.1.240`
- 隧道用户: `tunnel`
- systemd 服务: `autossh-admin.service`

## 3. 关键通道

- `admin:16022 -> gw:22`
- `admin:16443 -> master:6443`

说明:
- `127.0.0.1` 在 `admin` 上代表本机。
- 连接 `admin` 的 `127.0.0.1:16022` 实际会被反向隧道转发到 `gw:22`。

## 4. 日常操作

1. 登录 gw
```bash
ssh gw
```

2. 检查 gw 隧道服务
```bash
sudo systemctl status autossh-admin --no-pager
sudo journalctl -u autossh-admin -n 100 --no-pager
```

3. 验证 admin 侧端口
```bash
ss -lntp | grep -E '16022|16443'
```

## 5. 启停与自愈

1. 启动
```bash
sudo systemctl start autossh-admin
```

2. 停止
```bash
sudo systemctl stop autossh-admin
```

3. 重启
```bash
sudo systemctl restart autossh-admin
```

4. 开机自启检查
```bash
sudo systemctl is-enabled autossh-admin
```

## 6. 配置位置

- 服务文件: `/etc/systemd/system/autossh-admin.service`
- tunnel 私钥: `/home/tunnel/.ssh/id_ed25519`
- admin 授权公钥: `/home/tunnel/.ssh/authorized_keys`
- admin ssh 配置: `/etc/ssh/sshd_config`
- admin 用户别名: `~/.ssh/config`（`Host gw`）

## 7. 故障排查

1. `ssh gw` 不通
- 在 gw 查服务状态与日志。
- 在 admin 查 `16022` 是否监听。

2. 监听在但登录失败
- 检查 `authorized_keys` 是否存在正确公钥。
- 检查权限:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

3. 服务反复重启
- 查看:
```bash
sudo journalctl -u autossh-admin -f
```
- 重点看: 网络抖动、密钥权限、目标地址不可达。

## 8. 变更流程（每次必须）

1. 执行变更前
- 记录当前状态命令输出摘要。
- 备份配置文件（时间戳命名）。

2. 执行变更
- 一次只改一项，改完立即验证。

3. 执行变更后
- 记录验证结果。
- 记录回滚命令。
- 更新本文件“运维日志”。

## 9. 运维日志（持续追加）

### 2026-02-27 初始建链

- 变更:
- 完成 `gw -> admin(39.107.113.26)` 反向隧道部署。
- 创建并启用 `autossh-admin.service`。
- 打通端口映射 `16022` 与 `16443`。
- 在 admin 配置 SSH 安全参数与转发参数。
- 在 admin 配置 `Host gw` 登录别名。
- 验证:
- `systemctl is-enabled autossh-admin` 返回 `enabled`。
- `systemctl status autossh-admin` 返回 `active (running)`。
- `ssh -p 16022 root@127.0.0.1` 可登录到 `gw`。
- 回滚点:
- `/etc/systemd/system/autossh-admin.service` 删除并 `daemon-reload`。
- `/etc/ssh/sshd_config` 可从备份恢复。

### 2026-02-28 本机（Mac）直管集群打通

- 日期时间（UTC+8）:
- 2026-02-28 00:00 - 00:45
- 变更:
- 在 `admin` 发现 `kubectl` 二进制异常（`Segmentation fault`，原 `/usr/local/bin/kubectl` 损坏）。
- 在 `admin` 接入清华 Kubernetes APT 源并安装 `kubectl 1.35.2-1.1`，可执行路径为 `/usr/bin/kubectl`。
- 在 `admin` 修复 kubeconfig（`current-context` 缺失）:
- 通过 `admin:16022 -> gw:22 -> master(192.168.1.240)` 拉取 `/etc/rancher/k3s/k3s.yaml`。
- 将 apiserver 地址调整为 `https://127.0.0.1:16443`（匹配 `admin` 侧反向隧道端口）。
- 在 `admin` 验证通过：`kubectl get nodes -o wide`、`kubectl get pods -A`。
- 在 Mac 生成专用密钥 `~/.ssh/admin_k8s`，并通过 `admin` 网页终端写入 `/root/.ssh/authorized_keys`。
- 在 Mac 的 `~/.ssh/config` 增加:
- `Host admin-k8s`（免密登录 admin）。
- `Host admin-k8s-dev`（`LocalForward 16444 127.0.0.1:16443`）。
- 在 Mac 拉取 dev kubeconfig:
- `scp admin-k8s:/root/.kube/config ~/.kube/dev.yaml`
- 将 dev apiserver 地址改为 `https://127.0.0.1:16444`（对应 Mac 本地端口转发）。
- 在 Mac 启动隧道：`ssh -fN admin-k8s-dev`。
- 在 Mac 落地环境切换函数 `kuse dev|prod`（写入 `~/.zshrc`）:
- `prod -> ~/.kube/prod.yaml`
- `dev -> ~/.kube/dev.yaml`
- 在 Mac 备份并固化 `prod` 配置：`~/.kube/prod.yaml`。
- 验证:
- `ssh admin-k8s 'echo ok'` 返回 `ok`（Mac -> admin 免密可用）。
- `kuse dev && kubectl get nodes -o wide` 返回 `master Ready`（`192.168.1.240`）。
- `kuse prod && kubectl get nodes` 返回现网多节点集群。
- 回滚点:
- Mac 侧移除 `~/.ssh/config` 的 `admin-k8s/admin-k8s-dev` 段。
- Mac 侧删除 `~/.ssh/admin_k8s*`、`~/.kube/dev.yaml`、`~/.kube/prod.yaml`（按需保留）。
- Mac 侧从 `~/.zshrc` 移除 `kuse` 函数定义并 `source ~/.zshrc`。
- admin 侧从 `/root/.ssh/authorized_keys` 删除对应公钥 `mac-to-admin`。

### 日志模板（复制追加）

- 日期时间（UTC+8）:
- 变更:
- 验证:
- 回滚点:
