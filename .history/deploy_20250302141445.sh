#!/bin/bash
set -e

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
  echo "错误: Docker 服务未运行。请先启动 Docker 服务。"
  exit 1
fi

# 检查 Registry 是否可用
echo "检查本地 Registry 是否可用..."
if ! curl -s http://registry.orb.local:5000/v2/ > /dev/null; then
  echo "警告: 本地 Registry (localhost:5000) 不可用。"
  echo "尝试运行 './setup-registry.sh' 来设置本地 Registry。"
  
  read -p "是否继续尝试构建和推送镜像? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "部署已取消。"
    exit 1
  fi
  echo "继续部署，但可能会失败..."
fi

# 检查 Kubernetes 集群是否可用
echo "检查 Kubernetes 集群是否可用..."
if ! kubectl cluster-info > /dev/null 2>&1; then
  echo "错误: 无法连接到 Kubernetes 集群。请确保集群正在运行并且 kubectl 已正确配置。"
  exit 1
fi

# 设置 Registry 地址
# 对于 OrbStack 环境，我们需要使用两个不同的地址:
# - 构建和推送镜像时使用 localhost:5000
# - Kubernetes 部署中使用 registry.orb.local:5000
REGISTRY_HOST="registry.orb.local:5000"
KUBE_REGISTRY_HOST="registry.orb.local:5000"

# Build the Docker image
echo "构建 Docker 镜像..."
docker build -t ${REGISTRY_HOST}/demo-web-service:latest . || {
  echo "错误: 构建 Docker 镜像失败。"
  exit 1
}

# Push to local registry
echo "推送镜像到本地 Registry..."
if ! docker push ${REGISTRY_HOST}/demo-web-service:latest; then
  echo "错误: 推送镜像到本地 Registry 失败。"
  echo "可能的原因:"
  echo "1. 本地 Registry 未运行"
  echo "2. Registry 配置问题"
  echo "3. 网络问题"
  echo ""
  echo "请尝试以下步骤:"
  echo "1. 运行 './setup-registry.sh' 重新设置 Registry"
  echo "2. 检查 Docker 日志: 'docker logs registry'"
  echo "3. 手动测试 Registry: 'curl http://localhost:5000/v2/_catalog'"
  exit 1
fi

# Create namespace if it doesn't exist
echo "创建 demo 命名空间（如果不存在）..."
kubectl get namespace demo > /dev/null 2>&1 || kubectl create namespace demo

# 设置环境变量用于部署
export DOCKER_REGISTRY="${KUBE_REGISTRY_HOST}"

# Apply Kubernetes manifests
echo "部署应用..."
kubectl apply -f k8s/demo-app.yaml || {
  echo "错误: 应用 Kubernetes 配置失败。"
  exit 1
}

# Wait for deployment to be ready
echo "等待部署就绪..."
echo "等待 web-service 部署就绪..."
if ! kubectl -n demo wait --for=condition=available --timeout=300s deployment/web-service; then
  echo "警告: web-service 部署未在超时时间内就绪。"
  echo "检查 Pod 状态: 'kubectl get pods -n demo'"
  echo "查看 Pod 日志: 'kubectl logs -n demo deployment/web-service'"
fi

echo "等待 redis 部署就绪..."
if ! kubectl -n demo wait --for=condition=available --timeout=300s deployment/redis; then
  echo "警告: redis 部署未在超时时间内就绪。"
  echo "检查 Pod 状态: 'kubectl get pods -n demo'"
  echo "查看 Pod 日志: 'kubectl logs -n demo deployment/redis'"
fi

echo "等待 mysql Pod 就绪..."
if ! kubectl -n demo wait --for=condition=ready --timeout=300s pod -l app=mysql; then
  echo "警告: mysql Pod 未在超时时间内就绪。"
  echo "检查 Pod 状态: 'kubectl get pods -n demo -l app=mysql'"
  echo "查看 Pod 日志: 'kubectl logs -n demo -l app=mysql'"
fi

echo "应用部署完成！"
echo "您可以使用以下命令访问应用:"
echo "kubectl -n demo port-forward svc/web-service 8080:8080"
echo "然后在浏览器中访问 http://localhost:8080"
echo ""
echo "查看所有 Pod 状态:"
kubectl get pods -n demo 