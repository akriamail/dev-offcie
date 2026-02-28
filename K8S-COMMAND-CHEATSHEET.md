# Kubernetes 集群命令速查手册

> 说明：以下示例默认使用 `kubectl`。可以先设置 `alias k=kubectl` 提升效率。

## 1. 上下文与命名空间

```bash
# 查看当前上下文
kubectl config current-context

# 查看所有上下文
kubectl config get-contexts

# 切换上下文
kubectl config use-context <context-name>

# 查看当前 namespace
kubectl config view --minify --output 'jsonpath={..namespace}'; echo

# 设置当前上下文默认 namespace
kubectl config set-context --current --namespace=<namespace>

# 查看所有命名空间
kubectl get ns

# 创建/删除命名空间
kubectl create ns <namespace>
kubectl delete ns <namespace>
```

## 2. 集群与节点管理

```bash
# 集群信息
kubectl cluster-info

# 查看节点
kubectl get nodes -o wide
kubectl describe node <node-name>

# 节点资源使用（需要 metrics-server）
kubectl top nodes

# 标记节点不可调度 / 恢复
kubectl cordon <node-name>
kubectl uncordon <node-name>

# 安全驱逐节点上的 Pod（维护前常用）
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## 3. 常用资源查看

```bash
# 查看当前命名空间所有资源
kubectl get all

# 查看指定命名空间所有资源
kubectl get all -n <namespace>

# 全集群查看 Pod
kubectl get pods -A -o wide

# 查看 API 资源类型
kubectl api-resources

# 查看资源详情
kubectl describe pod <pod-name> -n <namespace>
kubectl describe deploy <deploy-name> -n <namespace>
```

## 4. 工作负载（Deployment/StatefulSet）

```bash
# 应用/更新配置
kubectl apply -f <file-or-dir>

# 删除配置
kubectl delete -f <file-or-dir>

# 快速创建 deployment
kubectl create deploy <name> --image=<image>

# 扩缩容
kubectl scale deploy/<name> --replicas=<num> -n <namespace>

# 更新镜像
kubectl set image deploy/<name> <container-name>=<new-image> -n <namespace>

# 滚动重启
kubectl rollout restart deploy/<name> -n <namespace>

# 查看发布状态/历史
kubectl rollout status deploy/<name> -n <namespace>
kubectl rollout history deploy/<name> -n <namespace>

# 回滚到上一版本 / 指定 revision
kubectl rollout undo deploy/<name> -n <namespace>
kubectl rollout undo deploy/<name> --to-revision=<revision> -n <namespace>
```

## 5. Service / Ingress

```bash
# 查看服务与入口
kubectl get svc -n <namespace>
kubectl get ingress -n <namespace>
kubectl get endpoints -n <namespace>

# 暴露 deployment 为 ClusterIP/NodePort/LB
kubectl expose deploy <name> --port=80 --target-port=8080 --type=ClusterIP -n <namespace>

# 查看 service 详情
kubectl describe svc <svc-name> -n <namespace>
```

## 6. 日志、进入容器与调试

```bash
# 查看日志（实时跟随）
kubectl logs -f <pod-name> -n <namespace>

# 查看多容器 Pod 的指定容器日志
kubectl logs -f <pod-name> -c <container-name> -n <namespace>

# 查看上一次崩溃容器日志
kubectl logs <pod-name> --previous -n <namespace>

# 进入容器
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# 本地端口转发
kubectl port-forward pod/<pod-name> 8080:80 -n <namespace>
kubectl port-forward svc/<svc-name> 8080:80 -n <namespace>

# 拷贝文件（本地 <-> 容器）
kubectl cp ./local.txt <namespace>/<pod-name>:/tmp/remote.txt
kubectl cp <namespace>/<pod-name>:/tmp/remote.txt ./local.txt
```

## 7. 配置与密钥

```bash
# 创建 ConfigMap
kubectl create configmap <name> --from-literal=key=value -n <namespace>
kubectl create configmap <name> --from-file=./app.conf -n <namespace>

# 创建 Secret
kubectl create secret generic <name> --from-literal=username=admin --from-literal=password='***' -n <namespace>

# 查看（base64 编码）
kubectl get secret <name> -o yaml -n <namespace>
```

## 8. 事件与排障

```bash
# 查看事件（按时间排序）
kubectl get events -A --sort-by=.metadata.creationTimestamp

# 查看某个 Pod 详细状态（排障首选）
kubectl describe pod <pod-name> -n <namespace>

# 检查 RBAC 权限
kubectl auth can-i <verb> <resource> -n <namespace>
kubectl auth can-i create deployments --as=<user> -n <namespace>

# 字段说明查询
kubectl explain deployment.spec.template.spec.containers
```

## 9. 常用清理命令（谨慎执行）

```bash
# 删除单个 Pod（会被控制器重建）
kubectl delete pod <pod-name> -n <namespace>

# 删除命名空间下所有 Pod
kubectl delete pod --all -n <namespace>

# 删除命名空间下所有资源（不含 namespace 本身）
kubectl delete all --all -n <namespace>
```

## 10. 输出技巧

```bash
# YAML / JSON 输出
kubectl get pod <pod-name> -n <namespace> -o yaml
kubectl get pod <pod-name> -n <namespace> -o json

# JSONPath 提取字段
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.podIP}'; echo

# 宽表格 + 标签
kubectl get pods -n <namespace> -o wide --show-labels
```

## 11. 高频别名（可选）

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs -f'
```

