#!/bin/bash
set -e

echo "OrbStack Kubernetes 环境设置助手"
echo "================================"

# 检查 OrbStack 是否运行
if ! command -v orbctl &> /dev/null; then
  echo "错误: 未找到 orbctl 命令。请确保 OrbStack 已安装。"
  echo "您可以从 https://orbstack.dev/ 下载并安装 OrbStack。"
  exit 1
fi

echo "检查 OrbStack 状态..."
if ! orbctl status | grep -q "Running"; then
  echo "错误: OrbStack 未运行。请启动 OrbStack 后再试。"
  exit 1
fi

# 检查 Kubernetes 是否启用
echo "检查 Kubernetes 状态..."
if ! kubectl cluster-info &> /dev/null; then
  echo "错误: Kubernetes 未启用或无法连接。"
  echo "请在 OrbStack 中启用 Kubernetes 功能后再试。"
  echo "1. 打开 OrbStack 应用"
  echo "2. 点击 'Kubernetes' 选项卡"
  echo "3. 点击 'Enable Kubernetes' 按钮"
  exit 1
fi

echo "✅ OrbStack Kubernetes 已启用并正常运行"

# 检查本地 Registry
echo "检查本地 Docker Registry..."
if ! docker ps | grep -q "registry:2"; then
  echo "本地 Docker Registry 未运行，正在启动..."
  ./setup-registry.sh
else
  echo "✅ 本地 Docker Registry 已在运行"
fi

# 测试 Registry 连接
echo "测试 Registry 连接..."
if curl -s http://localhost:5000/v2/ > /dev/null; then
  echo "✅ Registry API 可以访问"
else
  echo "警告: 无法连接到 Registry API。请运行 './setup-registry.sh' 检查问题。"
fi

# 创建测试镜像
echo "创建测试镜像并推送到本地 Registry..."
docker pull hello-world
docker tag hello-world localhost:5000/hello-world
if docker push localhost:5000/hello-world; then
  echo "✅ 成功推送测试镜像到本地 Registry"
else
  echo "警告: 推送测试镜像失败。请检查 Registry 配置。"
fi

# 验证 OrbStack 中的 Kubernetes 可以访问本地 Registry
echo "验证 Kubernetes 可以访问本地 Registry..."
cat <<EOF > test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: registry-test
  namespace: default
spec:
  containers:
  - name: registry-test
    image: registry.orb.local:5000/hello-world
    imagePullPolicy: Always
  restartPolicy: Never
EOF

kubectl apply -f test-pod.yaml
echo "等待测试 Pod 启动..."
sleep 5

# 检查 Pod 状态
POD_STATUS=$(kubectl get pod registry-test -o jsonpath='{.status.phase}')
if [[ "$POD_STATUS" == "Succeeded" ]]; then
  echo "✅ 测试成功! Kubernetes 可以从本地 Registry 拉取镜像"
else
  echo "❌ 测试失败。Pod 状态: $POD_STATUS"
  echo "查看 Pod 详情:"
  kubectl describe pod registry-test
  echo ""
  echo "可能的问题:"
  echo "1. OrbStack 中的 Kubernetes 无法访问宿主机上的 Registry"
  echo "2. 镜像拉取策略问题"
  echo "3. Registry 配置问题"
  echo ""
  echo "解决方案:"
  echo "- 确保在 Kubernetes 部署中使用 'registry.orb.local:5000' 而不是 'localhost:5000'"
  echo "- 检查 Registry 是否正常运行: docker logs registry"
fi

# 清理测试资源
kubectl delete -f test-pod.yaml

echo ""
echo "环境设置完成!"
echo "您现在可以运行 './deploy.sh' 来部署应用"
echo "如果遇到问题，请参考 DEMO.md 中的故障排除部分" 