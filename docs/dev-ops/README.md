# 集群操作记录

所有对集群的操作必须记录在此处。

## 日志模板

- 日期时间（UTC+8）:
- 变更:
- 验证:
- 回滚:

## 2026-03-04 镜像缓存部署（已执行）

- 日期时间（UTC+8）:
- 2026-03-04
- 变更:
- 应用 `manifests/infra/registry-cache/registry-cache.yaml`。
- 创建: namespace `infra`、PV/PVC、Deployment `registry-cache`、Service `registry-cache`（NodePort 32080）。
- 验证:
- `kubectl get svc -n infra registry-cache` 显示 `NodePort 32080`。
- `kubectl get pods -n infra -o wide` 已调度到 `worker01`。
- 集群内验证: `curl -I http://registry-cache.infra.svc.cluster.local:5000/v2/` 返回 `200 OK`。
- 回滚:
- `kubectl delete -f manifests/infra/registry-cache/registry-cache.yaml`
