#!/bin/bash
set -e

echo "Setting up local Docker Registry..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "错误: Docker 服务未运行。请先启动 Docker 服务。"
  exit 1
fi

# Check if registry container is already running
if docker ps | grep -q "registry:2"; then
  echo "Registry 已经在运行中。"
  REGISTRY_CONTAINER_ID=$(docker ps | grep "registry:2" | awk '{print $1}')
  echo "Registry 容器 ID: $REGISTRY_CONTAINER_ID"
else
  # Check if registry container exists but is stopped
  if docker ps -a | grep -q "registry"; then
    echo "发现已停止的 Registry 容器，正在重新启动..."
    docker start registry
  else
    # Start a new registry container
    echo "正在启动新的 Registry 容器..."
    docker run -d -p 5000:5000 --restart=always --name registry registry:2
  fi
  echo "Registry 已启动在 localhost:5000"
fi

# Wait for registry to be ready
echo "等待 Registry 准备就绪..."
for i in {1..10}; do
  if curl -s http://localhost:5000/v2/ > /dev/null; then
    echo "Registry API 已就绪。"
    break
  fi
  if [ $i -eq 10 ]; then
    echo "警告: Registry API 未响应。继续执行，但可能会有问题。"
  fi
  echo "等待 Registry 启动... ($i/10)"
  sleep 2
done

# Verify the registry is working
echo "验证 Registry 是否正常工作..."
CATALOG_RESPONSE=$(curl -s http://localhost:5000/v2/_catalog)
if [ -z "$CATALOG_RESPONSE" ]; then
  echo "警告: Registry 目录 API 没有返回数据。"
  
  # Check if registry container is running
  if ! docker ps | grep -q "registry:2"; then
    echo "错误: Registry 容器不在运行状态。"
    echo "尝试以下步骤排查问题:"
    echo "1. 运行 'docker ps -a' 检查容器状态"
    echo "2. 运行 'docker logs registry' 查看容器日志"
    echo "3. 检查端口 5000 是否被其他程序占用: 'lsof -i :5000'"
    echo "4. 尝试手动启动: 'docker start registry' 或重新创建: 'docker rm -f registry && docker run -d -p 5000:5000 --name registry registry:2'"
  else
    echo "Registry 容器正在运行，但 API 无响应。可能是内部错误或网络问题。"
    echo "尝试以下步骤排查问题:"
    echo "1. 运行 'docker logs registry' 查看容器日志"
    echo "2. 检查防火墙设置是否阻止了本地连接"
    echo "3. 尝试使用 'docker exec -it registry sh' 进入容器检查内部状态"
    echo "4. 重启容器: 'docker restart registry'"
  fi
  
  # Try with different methods
  echo "尝试使用不同方法连接 Registry..."
  echo "使用 -v 选项获取详细输出:"
  curl -v http://localhost:5000/v2/_catalog
  
  echo "使用 Docker 命令测试 Registry:"
  docker info | grep Registry
  
  echo "尝试推送测试镜像到 Registry:"
  docker pull hello-world
  docker tag hello-world localhost:5000/hello-world
  docker push localhost:5000/hello-world || echo "推送测试镜像失败"
  
  echo "如果以上步骤都失败，请尝试重新启动 Docker 服务。"
else
  echo "Registry 目录 API 返回: $CATALOG_RESPONSE"
  echo "本地 Docker Registry 设置完成！"
  echo "您现在可以构建并推送镜像到 localhost:5000"
  
  # Show example commands
  echo ""
  echo "示例命令:"
  echo "构建镜像: docker build -t localhost:5000/myapp:latest ."
  echo "推送镜像: docker push localhost:5000/myapp:latest"
  echo "查看镜像列表: curl http://localhost:5000/v2/_catalog"
fi 