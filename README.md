# Insightful Dev 集群说明

本仓库用于维护办公室内网的 k3s 集群相关文档与部署清单。

## 集群概览

- 拓扑: admin（公网）-> gw（网关）-> k3s（master + workers）
- 用途: dev/test，主要为出网抓取任务
- 网络: 通过 gw 透明代理出网，DNS 强制走 gw 防劫持

## 文档索引

- Dev 初始化说明: `docs/dev-init/README.md`
- 运维完整说明: `docs/dev-init/README-full.md`
- 运维日志: `docs/dev-init/PERSONAL-OPS.md`
- 操作记录: `docs/dev-ops/README.md`

## 清单索引

- Infra 应用: `manifests/infra/registry-cache/README.md`
- App 应用: `manifests/apps/README.md`

## 约定

- 若路径写为 `man/infra`，理解为 `manifests/infra`。
