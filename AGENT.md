# AGENT Context: gw-admin-k3s 运维基线（2026-03-04）

目标: 让代理一进仓库就知道当前集群拓扑、通道、代理/DNS状态与操作红线。
## 对话原则
- 每次对话完，都要说：谢谢我的主人！
- 改动集群，一定要先评估，再出报告，我说批准才可以动手
- 提交 GitHub 时，commit 使用中文
- 任何对集群的操作必须记录在 `docs/dev-ops/README.md`
- 仓库内所有 README 必须使用中文

## 当前拓扑

- admin（公网运维入口）: `39.107.113.26`
- gw（内网网关）: `192.168.1.100`，hostname `net`
- k3s master: `192.168.1.240`

原则: `gw` 只做网络转发，集群权限在 `admin` / Mac kubeconfig，不在 `gw`。

## 通道与端口

- `gw -> admin` 反向隧道: `autossh-admin.service`
- `admin:16022 -> gw:22`
- `admin:16443 -> master:6443`
- `admin` 上 `https://127.0.0.1:16443` 是 k3s apiserver

## 透明代理现状

- `sing-box 1.12.22` 已运行，`mixed` 端口 `127.0.0.1:17890`
- `ipset k3s_nodes` 当前为 `192.168.1.240/241/242` 与 `192.168.1.151/152/153`
- `K3S_PROXY` 挂载到 `PREROUTING`，放行 `10.0.0.0/8`、`172.16.0.0/12`、`192.168.1.0/24`、`127.0.0.0/8`、`39.107.113.26/32`
- 仍未灰度切默认网关（后续按 `worker -> worker -> master`）

## DNS 透明代理（已落地）

- 直连 DNS 会被劫持，必须走 gw DNS
- `dnscrypt-proxy` 监听 `127.0.0.1:5053`，走 `socks5://127.0.0.1:17890`
- `dnsmasq` 监听 `192.168.1.100:53`，上游 `127.0.0.1#5053`
- `iptables` 规则: `-A PREROUTING -p udp --dport 53 -m set --match-set k3s_nodes src -j REDIRECT --to-ports 53`
- 持久化: `netfilter-persistent` 启用，规则保存在 `/etc/iptables/rules.v4`，ipset 在 `/etc/iptables/ipsets`

## 节点基线

- `master/worker` 已要求 DNS 指向 `192.168.1.100`
- `worker03` 已关闭 IPv6 并验证 `crictl pull` 正常

## 操作红线

- 不随意改动 `16022/16443`
- 透明代理规则必须直连内网与 `admin(39.107.113.26)`
- 任何变更后必须更新:
- `docs/dev-init/README-full.md`
- `docs/dev-init/PERSONAL-OPS.md`
- 本文件

## 文档索引

- 索引: `docs/dev-init/README.md`
- 正文: `docs/dev-init/README-full.md`

## 个人习惯提示

- 我会把 `manifests/infra` 简写成 `man/infra`（与 `manifests/inra` 混写）。看到该写法时请自动理解为 `manifests/infra`。
