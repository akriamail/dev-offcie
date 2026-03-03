# Infra 应用索引

- 镜像缓存（Docker Hub 代理缓存）: `registry-cache.yaml`

## registry-cache

用途:
- 缓存 `docker.io` 拉取，减少出网带宽消耗。

部署位置:
- Node: `worker01`
- HostPath: `/var/lib/registry`
- Service: `NodePort 32080`

部署:
```bash
kubectl apply -f manifests/infra/registry-cache/registry-cache.yaml
```

使用:
- 缓存地址: `http://<worker01-ip>:32080`
- 示例: `docker pull <worker01-ip>:32080/library/redis:7`

验证:
```bash
curl -I http://<worker01-ip>:32080/v2/
```
预期: `200` 或 `401`（均表示 registry 可达）。

备注:
- 若遇到 Docker Hub 限速，可配置 `REGISTRY_PROXY_USERNAME`/`REGISTRY_PROXY_PASSWORD`。
- 缓存会增长，清空 `/var/lib/registry` 会丢失缓存。
