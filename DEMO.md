# Chaos Mesh 混沌测试演示

本文档详细描述了如何使用 Chaos Mesh 进行混沌工程测试，包括环境准备、测试场景和结果分析。

## 环境准备

### 前提条件

- Kubernetes 集群 (v1.16+)
- Helm 3.0+
- kubectl 命令行工具
- Docker

### 设置本地 Docker Registry

在部署应用之前，我们需要设置一个本地的 Docker Registry 来存储我们的镜像：

1. 运行提供的脚本来设置本地 Registry：

```bash
chmod +x setup-registry.sh
./setup-registry.sh
```

2. 验证 Registry 是否正常运行：

```bash
curl http://localhost:5000/v2/_catalog
```

应该返回：`{"repositories":[]}`

#### 常见问题排查

如果 `curl http://localhost:5000/v2/_catalog` 没有返回任何内容或返回错误，可能存在以下问题：

1. **Docker 服务未运行**：
   - 确保 Docker 服务已启动
   - 运行 `docker info` 检查 Docker 状态

2. **Registry 容器未正确启动**：
   - 运行 `docker ps | grep registry` 检查容器是否运行
   - 如果未运行，尝试 `docker start registry` 或重新创建容器

3. **端口冲突**：
   - 检查端口 5000 是否被其他程序占用：`lsof -i :5000`
   - 如果有冲突，停止占用端口的程序或修改 Registry 端口

4. **网络问题**：
   - 检查防火墙设置
   - 尝试使用 `curl -v http://localhost:5000/v2/_catalog` 获取详细错误信息

5. **手动测试 Registry**：
   - 尝试推送测试镜像：
     ```bash
     docker pull hello-world
     docker tag hello-world localhost:5000/hello-world
     docker push localhost:5000/hello-world
     ```
   - 如果推送成功，再次检查 `curl http://localhost:5000/v2/_catalog`

6. **重启 Docker**：
   - 如果以上步骤都不能解决问题，尝试重启 Docker 服务

### [安装 Chaos Mesh](https://chaos-mesh.org/zh/docs/production-installation-using-helm/)

1. 添加 Chaos Mesh 的 Helm 仓库：

```bash
helm repo add chaos-mesh https://charts.chaos-mesh.org
```

2. 更新 Helm 仓库：

```bash
helm repo update
```

3. 创建命名空间：

```bash
kubectl create ns chaos-testing
```

4. 使用 Helm 安装 Chaos Mesh：

```bash
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock
```

5. 验证安装：

```bash
kubectl get pods -n chaos-testing
```

### 部署演示应用

我们将部署一个简单的应用程序，包含以下组件：
- Web 服务
- Redis 缓存
- MySQL 数据库

1. 部署应用：

```bash
# 使用部署脚本构建镜像并部署应用
chmod +x deploy.sh
./deploy.sh
```

如果部署过程中出现与 Registry 相关的错误，请参考上面的"常见问题排查"部分。

2. 验证应用部署状态：

```bash
kubectl get pods -n demo
```

3. 访问应用：

```bash
kubectl -n demo port-forward svc/web-service 8080:8080
```

然后在浏览器中访问 http://localhost:8080

## 混沌测试场景

### 1. Redis 服务不可用测试

#### 1.1 内存压力测试

1. 应用内存压力：

```bash
kubectl apply -f chaos/redis-memory-stress.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/redis-memory-stress.yaml
```

#### 1.2 CPU 压力测试

1. 应用 CPU 压力：

```bash
kubectl apply -f chaos/redis-cpu-stress.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/redis-cpu-stress.yaml
```

### 2. 数据库连接问题测试

1. 模拟数据库连接失败：

```bash
kubectl apply -f chaos/mysql-connection-failure.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/mysql-connection-failure.yaml
```

### 3. Pod 故障测试

#### 3.1 Pod 失败测试

1. 模拟 Pod 失败：

```bash
kubectl apply -f chaos/pod-failure.yaml
```

2. 观察应用行为：

```bash
kubectl get pods -n demo -w
```

3. 清理测试：

```bash
kubectl delete -f chaos/pod-failure.yaml
```

#### 3.2 Pod 终止测试

1. 模拟 Pod 终止：

```bash
kubectl apply -f chaos/pod-kill.yaml
```

2. 观察应用行为：

```bash
kubectl get pods -n demo -w
```

3. 清理测试：

```bash
kubectl delete -f chaos/pod-kill.yaml
```

#### 3.3 容器终止测试

1. 模拟容器终止：

```bash
kubectl apply -f chaos/container-kill.yaml
```

2. 观察应用行为：

```bash
kubectl get pods -n demo -w
```

3. 清理测试：

```bash
kubectl delete -f chaos/container-kill.yaml
```

### 4. 网络连接问题测试

#### 4.1 网络分区测试

1. 模拟网络分区：

```bash
kubectl apply -f chaos/network-partition.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/network-partition.yaml
```

#### 4.2 网络模拟测试

1. 模拟网络延迟和丢包：

```bash
kubectl apply -f chaos/network-emulation.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/network-emulation.yaml
```

### 5. JVM 应用故障测试

#### 5.1 JVM 异常注入测试

1. 向 Java 应用注入异常：

```bash
kubectl apply -f chaos/jvm-exception-injection.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/jvm-exception-injection.yaml
```

#### 5.2 JVM GC 压力测试

1. 模拟 JVM 垃圾回收压力：

```bash
kubectl apply -f chaos/jvm-gc-stress.yaml
```

2. 观察应用行为和性能指标：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/jvm-gc-stress.yaml
```

#### 5.3 JVM 方法延迟测试

1. 为特定 Java 方法添加延迟：

```bash
kubectl apply -f chaos/jvm-method-latency.yaml
```

2. 观察应用响应时间：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/jvm-method-latency.yaml
```

#### 5.4 JVM 方法返回值修改测试

1. 修改特定 Java 方法的返回值：

```bash
kubectl apply -f chaos/jvm-return-value-modification.yaml
```

2. 观察应用行为：

```bash
kubectl logs -f deployment/web-service -n demo
```

3. 清理测试：

```bash
kubectl delete -f chaos/jvm-return-value-modification.yaml
```

## 测试结果分析

每次测试后，我们需要分析以下指标：

1. 应用可用性：服务是否仍然可用
2. 错误率：请求失败的百分比
3. 响应时间：请求的平均响应时间
4. 恢复时间：系统从故障中恢复所需的时间

可以使用以下命令查看应用指标：

```bash
kubectl exec -it deployment/web-service -n demo -- curl localhost:8080/metrics
```

## 如何清理 Chaos 测试

1. 删除所有 Chaos 实验：

```bash
./cleanup-chaos.sh
```

或者手动执行：

```bash
kubectl -n demo delete podchaos,iochaos,networkchaos,stresschaos --all
```

2. 如果需要，可以卸载 Chaos Mesh：

```bash
helm uninstall chaos-mesh -n chaos-testing
kubectl delete ns chaos-testing
```

3. 清理应用和本地 Registry：

```bash
# 删除应用
kubectl delete -f k8s/demo-app.yaml

# 停止并删除本地 Registry
docker stop registry
docker rm registry
```

## 最佳实践

1. 始终在非生产环境中先测试 Chaos 实验
2. 设置合理的实验持续时间
3. 确保有监控和告警系统
4. 记录所有测试结果，用于后续分析和改进 