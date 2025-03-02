#!/bin/bash
set -e

echo "检查 Docker Desktop 和 Kubernetes 状态..."

# 检查操作系统
OS=$(uname -s)
if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
  echo "警告: 此脚本主要为 macOS 和 Linux 设计。在其他操作系统上可能无法正常工作。"
fi

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
  echo "错误: Docker 服务未运行。请先启动 Docker Desktop。"
  exit 1
fi

# 检查是否是 Docker Desktop
if ! docker info | grep -q "Docker Desktop"; then
  echo "警告: 未检测到 Docker Desktop。此脚本主要用于 Docker Desktop 环境。"
  echo "如果您使用的是其他 Docker 环境，请手动设置 Kubernetes。"
  
  read -p "是否继续? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "设置已取消。"
    exit 1
  fi
fi

# 检查 Kubernetes 是否已启用
if kubectl cluster-info > /dev/null 2>&1; then
  echo "Kubernetes 已经在运行中。"
  kubectl cluster-info
  kubectl get nodes
  
  echo "您可以继续安装 Chaos Mesh 和部署演示应用。"
  exit 0
fi

echo "Kubernetes 未运行。请在 Docker Desktop 中启用 Kubernetes:"

if [[ "$OS" == "Darwin" ]]; then
  echo "1. 打开 Docker Desktop"
  echo "2. 点击右上角的齿轮图标 (设置)"
  echo "3. 在左侧菜单中选择 'Kubernetes'"
  echo "4. 勾选 'Enable Kubernetes'"
  echo "5. 点击 'Apply & Restart'"
  echo "6. 等待 Kubernetes 启动完成"
  
  # 尝试打开 Docker Desktop 设置
  open -a "Docker Desktop"
  
elif [[ "$OS" == "Linux" ]]; then
  echo "1. 打开 Docker Desktop"
  echo "2. 点击右上角的齿轮图标 (设置)"
  echo "3. 在左侧菜单中选择 'Kubernetes'"
  echo "4. 勾选 'Enable Kubernetes'"
  echo "5. 点击 'Apply & Restart'"
  echo "6. 等待 Kubernetes 启动完成"
fi

echo ""
echo "启用 Kubernetes 后，请运行以下命令验证集群状态:"
echo "kubectl cluster-info"
echo "kubectl get nodes"
echo ""
echo "然后继续安装 Chaos Mesh 和部署演示应用。" 