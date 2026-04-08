#!/bin/bash

# 钉钉桥接服务启动脚本

echo "========================================"
echo "  钉钉桥接中间件 - 启动脚本"
echo "========================================"

# 检查 .env 文件
if [ ! -f .env ]; then
    echo "[警告] .env 文件不存在!"
    echo "请复制 .env.example 并填写配置:"
    echo "  cp .env.example .env"
    echo ""
    exit 1
fi

# 检查依赖
if [ ! -d "node_modules" ]; then
    echo "[信息] 安装依赖..."
    npm install
fi

# 启动服务
echo "[信息] 启动服务..."
npm start
