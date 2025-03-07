# 演示使用chaos mesh来做混沌测试

本项目演示如何使用 Chaos Mesh 进行混沌工程测试，帮助验证系统在各种故障场景下的弹性和稳定性。

## 环境准备

在开始之前，您需要准备以下环境：

1. **Docker Desktop**：用于运行容器和本地 Kubernetes 集群
2. **Kubernetes 集群**：可以使用 Docker Desktop 内置的 Kubernetes 或其他 Kubernetes 集群
3. **kubectl**：用于与 Kubernetes 集群交互
4. **Helm 3**：用于安装 Chaos Mesh

### Docker Registry 选项

您有两种方式可以设置 Docker Registry：

2. **Kubernetes 内的 Registry**：使用 `./setup-k8s-registry.sh` 在 Kubernetes 集群内部署 Registry（推荐）

使用 Kubernetes 内的 Registry 可以避免镜像拉取问题，特别是在使用 OrbStack 或其他环境时。

我们提供了以下脚本来帮助您快速设置环境：

- `setup-k8s.sh`：检查并帮助启用 Docker Desktop 的 Kubernetes 功能
- `setup-registry.sh`：在主机上设置本地 Docker Registry
- `setup-k8s-registry.sh`：在 Kubernetes 集群内部署 Registry（推荐）
- `setup-orbstack.sh`：为 OrbStack 用户设置环境并测试 Registry 连接

## 如何安装chaos mesh

Chaos Mesh 可以通过 Helm 安装到 Kubernetes 集群中：

```bash
# 添加 Chaos Mesh 的 Helm 仓库
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# 创建命名空间
kubectl create ns chaos-testing

# 安装 Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
```

详细的安装步骤请参考 [DEMO.md](DEMO.md) 文件。

## 测试的内容

本项目包含以下混沌测试场景：

1. redis服务不可用
   1. memory stress - 对 Redis 施加内存压力
   2. cpu stress - 对 Redis 施加 CPU 压力
2. 数据库连接不了 - 模拟 MySQL 数据库连接失败
3. 某个pod挂了
   1. pod failure - 模拟 Pod 暂时不可用
   2. pod kill - 模拟 Pod 被终止
   3. container kill - 模拟容器被终止
4. 网络连接问题
   1. network partition - 模拟网络分区
   2. network emulation - 模拟网络延迟和丢包

## 项目结构

```
.
├── app.py                      # 演示应用程序代码
├── requirements.txt            # Python 依赖
├── Dockerfile                  # 构建应用容器的 Dockerfile
├── deploy.sh                   # 部署应用的脚本
├── setup-k8s.sh                # 设置 Kubernetes 的脚本
├── setup-registry.sh           # 设置主机上的 Docker Registry 的脚本
├── setup-k8s-registry.sh       # 在 Kubernetes 中设置 Registry 的脚本
├── cleanup-chaos.sh            # 清理混沌实验的脚本
├── k8s/                        # Kubernetes 配置文件
│   ├── demo-app.yaml           # 演示应用的 Kubernetes 部署文件
│   └── registry.yaml           # Kubernetes Registry 部署文件
└── chaos/                      # Chaos Mesh 实验配置文件
    ├── redis-memory-stress.yaml
    ├── redis-cpu-stress.yaml
    ├── mysql-connection-failure.yaml
    ├── pod-failure.yaml
    ├── pod-kill.yaml
    ├── container-kill.yaml
    ├── network-partition.yaml
    └── network-emulation.yaml
```

## 如何运行

1. 确保您有一个正常运行的 Kubernetes 集群
   - 如果使用 Docker Desktop：`./setup-k8s.sh`
   - 如果使用 OrbStack：`./setup-orbstack.sh`
2. 设置 Docker Registry：
   - 选项 2（Kubernetes 内，推荐）：`./setup-k8s-registry.sh`
3. 安装 Chaos Mesh（见上文）
4. 运行部署脚本：`./deploy.sh`
5. 按照 [DEMO.md](DEMO.md) 中的步骤执行混沌测试

## 如何清理chaos 

要清理所有混沌实验，可以运行：

```bash
./cleanup-chaos.sh
```

或者手动执行：

```bash
kubectl -n demo delete podchaos,networkchaos,stresschaos --all
```

如需卸载 Chaos Mesh：

```bash
helm uninstall chaos-mesh -n chaos-testing
kubectl delete ns chaos-testing
```

如需清理应用和 Registry：

```bash
# 删除应用
kubectl delete -f k8s/demo-app.yaml

# 删除 Kubernetes 内的 Registry
kubectl delete -f k8s/registry.yaml

# 或停止并删除主机上的 Registry
docker stop registry
docker rm registry
```

