# OPS 团队使用与设计手册（Mac 本机双集群）

适用对象: 新加入的 OPS 同学（从 0 开始配置本机 Mac，获得与当前负责人一致的 `dev/prod` 操作体验）。

更新时间: 2026-02-28

---

## 1. 目标

- 在 **Mac 本机** 直接执行标准 Kubernetes 命令（`kubectl ...`）。
- 能在 `dev（公司内的dev）` 与 `prod（真实的外网dev）` 两个集群之间安全切换。
- 任何时候都能明确“当前在哪个集群”，降低误操作风险。

---

## 2. 设计说明（为什么这么做）

### 2.1 拓扑与职责

- `admin`（公网运维入口，阿里云的一台ecs，连接公网和公司dev的gw）: `39.107.113.26`
- `gw`（内网网关）: `192.168.1.100`
- `master`（dev k3s 控制面）: `192.168.1.240`

职责边界:

- `gw` 只做网络转发/跳板，不持有集群权限主体。
- 集群管理权限在 `kubeconfig`（admin 或 Mac 本机）。

### 2.2 通道设计

- 固定转发: `admin:16443 -> master:6443`
- Mac 本地再转发一层: `127.0.0.1:16444 -> admin:16443`

选择 `16444` 的原因:

- 避免与其他本地集群/工具默认端口冲突。
- 与 `prod` 本地配置隔离，降低误连概率。

### 2.3 配置设计

- `~/.kube/prod.yaml`: 生产集群配置
- `~/.kube/dev.yaml`: 开发集群配置
- 通过 `kuse dev|prod` 只切换 `KUBECONFIG`，后续仍使用标准 `kubectl`。

这样做的原因:

- 不混合配置文件，避免 context 名称覆盖（k3s 常见 `default`）。
- 切换动作可审计、可复现、可培训。

---

## 3. 执行位置约定（必须遵守）

- 在 **Mac 本地终端** 执行:
- `ssh-keygen`、`ssh/scp admin-k8s...`
- `kuse dev|prod`
- `kubectl ...`
- 在 **admin 网页终端** 执行:
- 写入 `/root/.ssh/authorized_keys`（首次授权）
- 在 **gw** 执行（仅排障）:
- `systemctl/journalctl` 查看 `autossh-admin.service`

---

## 4. 新成员首次初始化（一步一步）

## 4.1 Mac: 生成专用 SSH 密钥

```bash
ssh-keygen -t ed25519 -f ~/.ssh/admin_k8s -C "<your-name>-mac-to-admin"
cat ~/.ssh/admin_k8s.pub
```

保留 `cat` 输出，下一步贴到 admin。

## 4.2 admin 网页终端: 授权公钥

```bash
umask 077
mkdir -p /root/.ssh
cat >> /root/.ssh/authorized_keys
```

粘贴你在上一步复制的整行公钥，回车后按 `Ctrl + D` 结束。

```bash
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

## 4.3 Mac: 配置 SSH Host 别名

```bash
cat <<'EOF' >> ~/.ssh/config

Host admin-k8s
  HostName 39.107.113.26
  User root
  IdentityFile ~/.ssh/admin_k8s
  IdentitiesOnly yes
  ServerAliveInterval 30
  ServerAliveCountMax 3

Host admin-k8s-dev
  HostName 39.107.113.26
  User root
  IdentityFile ~/.ssh/admin_k8s
  IdentitiesOnly yes
  ExitOnForwardFailure yes
  LocalForward 16444 127.0.0.1:16443
EOF

chmod 600 ~/.ssh/config
ssh admin-k8s 'echo ok'
```

预期输出包含 `ok`。

## 4.4 Mac: 准备 `prod.yaml` 与 `dev.yaml`

```bash
mkdir -p ~/.kube
```

`prod.yaml`:

- 如果你的 `~/.kube/config` 已是生产可用配置:

```bash
cp ~/.kube/config ~/.kube/prod.yaml
```

`dev.yaml`:

```bash
scp admin-k8s:/root/.kube/config ~/.kube/dev.yaml
sed -i '' 's#https://127.0.0.1:6443#https://127.0.0.1:16444#g; s#https://127.0.0.1:16443#https://127.0.0.1:16444#g' ~/.kube/dev.yaml
```

## 4.5 Mac: 配置 `kuse` 切换函数

将下面内容追加到 `~/.zshrc`:

```bash
kuse() {
  local target="${1:-}"
  local file=""
  case "$target" in
    dev) file="$HOME/.kube/dev.yaml" ;;
    prod) file="$HOME/.kube/prod.yaml" ;;
    *)
      echo "Usage: kuse dev|prod"
      return 1
      ;;
  esac
  if [ ! -f "$file" ]; then
    echo "kubeconfig not found: $file"
    return 1
  fi
  export KUBECONFIG="$file"
  echo "KUBECONFIG=$KUBECONFIG"
  kubectl config current-context 2>/dev/null || true
}
```

生效:

```bash
source ~/.zshrc
```

## 4.6 验证（必须通过）

```bash
# dev: 先起隧道再切换
ssh -fN admin-k8s-dev
kuse dev
kubectl get nodes -o wide

# prod: 直接切换
kuse prod
kubectl get nodes -o wide
```

---

## 5. 日常使用规范

建议每次操作都遵循以下顺序:

```bash
kuse dev   # 或 kuse prod
echo "$KUBECONFIG"
kubectl config current-context
kubectl get nodes
```

变更前建议再确认:

- 当前 `KUBECONFIG` 是否符合预期。
- 当前节点列表是否符合目标集群特征（例如 dev 仅 `master` 单节点）。

---

## 6. Headlamp 使用（可选）

原则:

- Headlamp 显示的是其读取到的 kubeconfig/context，不会“自动发现集群”。

推荐:

- 用 `kuse` 切换后，从同一终端启动 Headlamp。

```bash
kuse dev
/Applications/Headlamp.app/Contents/MacOS/Headlamp
```

或:

```bash
kuse prod
/Applications/Headlamp.app/Contents/MacOS/Headlamp
```

---

## 7. 常见故障与处理

### 7.1 `kuse dev` 提示 `kubeconfig not found`

原因: `~/.kube/dev.yaml` 不存在。

处理:

```bash
scp admin-k8s:/root/.kube/config ~/.kube/dev.yaml
sed -i '' 's#https://127.0.0.1:6443#https://127.0.0.1:16444#g; s#https://127.0.0.1:16443#https://127.0.0.1:16444#g' ~/.kube/dev.yaml
```

### 7.2 `kubectl` 连接 `localhost:8080`

原因: 当前 `KUBECONFIG` 无效或没设置。

处理:

```bash
echo "$KUBECONFIG"
kubectl config current-context
```

若失败，重新执行 `kuse dev|prod`。

### 7.3 `kuse dev` 后连接超时/拒绝

原因: dev 隧道没起或断开。

处理:

```bash
ssh -fN admin-k8s-dev
lsof -nP -iTCP:16444 -sTCP:LISTEN
```

### 7.4 `ssh admin-k8s` 报 `Permission denied (publickey)`

原因: 公钥未正确写入 admin 或权限不对。

处理（在 admin 网页终端）:

```bash
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

并确认 `authorized_keys` 包含对应公钥。

---

## 8. 安全与审计要求

- 禁止共享私钥 `~/.ssh/admin_k8s`。
- 成员离组时，必须从 admin 删除其公钥。
- 端口 `16022/16443/16444` 不可私自改动；若改动需同步更新全部文档。
- 所有生产变更按团队变更流程记录，且同步更新 `PERSONAL-OPS.md` 运行日志。

---

## 9. 离组回收清单（Offboarding）

- 在 admin 删除该成员公钥。
- 在成员 Mac 删除:
- `~/.ssh/admin_k8s`
- `~/.ssh/admin_k8s.pub`
- `~/.kube/dev.yaml`
- 从 `~/.ssh/config` 删除 `admin-k8s/admin-k8s-dev` 段。
- 从 `~/.zshrc` 删除 `kuse` 函数。

