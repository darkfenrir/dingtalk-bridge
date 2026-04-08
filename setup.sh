#!/bin/bash

# ============================================
# 钉钉桥接中间件 - 交互式安装配置脚本
# ============================================
# 功能：
# 1. 自动检测 Node.js 环境
# 2. 交互式配置钉钉和 OpenClaw 参数
# 3. 自动安装依赖
# 4. 一键启动服务
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印横幅
print_banner() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}        钉钉桥接中间件 - 安装配置向导            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}        DingTalk Bridge for OpenClaw              ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 检查 Node.js
check_node() {
    log_info "检查 Node.js 环境..."
    
    if ! command -v node &> /dev/null; then
        log_error "未检测到 Node.js，请先安装 Node.js (建议 v18+)"
        echo "安装指南：https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node -v)
    log_success "Node.js 已安装：$NODE_VERSION"
    
    # 检查版本
    NODE_MAJOR=$(node -v | cut -d'.' -f1 | sed 's/v//')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        log_warn "Node.js 版本较低，建议使用 v18 或更高版本"
    fi
}

# 检查 npm
check_npm() {
    if ! command -v npm &> /dev/null; then
        log_error "未检测到 npm"
        exit 1
    fi
    
    log_success "npm 已安装：$(npm -v)"
}

# 安装依赖
install_dependencies() {
    echo ""
    log_info "安装项目依赖..."
    
    if [ -d "node_modules" ]; then
        log_warn "检测到已安装的依赖"
        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "跳过依赖安装"
            return
        fi
    fi
    
    npm install
    
    if [ $? -eq 0 ]; then
        log_success "依赖安装完成"
    else
        log_error "依赖安装失败"
        exit 1
    fi
}

# 生成 .env 文件
generate_env() {
    echo ""
    log_info "配置环境变量"
    echo ""
    
    # 检查是否已有 .env 文件
    if [ -f ".env" ]; then
        log_warn "检测到已存在的 .env 文件"
        read -p "是否重新配置？(y/N): " reconfig
        if [ "$reconfig" != "y" ] && [ "$reconfig" != "Y" ]; then
            log_info "使用现有配置"
            return
        fi
        mv .env .env.backup.$(date +%Y%m%d%H%M%S)
        log_info "原配置已备份为 .env.backup.*"
    fi
    
    echo ""
    echo -e "${YELLOW}=== 钉钉配置 ===${NC}"
    echo "请在钉钉开放平台 (https://open.dingtalk.com/) 创建应用获取以下信息"
    echo ""
    
    # 钉钉 AppKey
    read -p "请输入钉钉 AppKey: " DINGTALK_APP_KEY
    while [ -z "$DINGTALK_APP_KEY" ]; do
        log_error "AppKey 不能为空"
        read -p "请输入钉钉 AppKey: " DINGTALK_APP_KEY
    done
    
    # 钉钉 AppSecret
    read -p "请输入钉钉 AppSecret: " DINGTALK_APP_SECRET
    while [ -z "$DINGTALK_APP_SECRET" ]; do
        log_error "AppSecret 不能为空"
        read -p "请输入钉钉 AppSecret: " DINGTALK_APP_SECRET
    done
    
    # 钉钉 AgentId
    read -p "请输入钉钉 AgentId: " DINGTALK_AGENT_ID
    while [ -z "$DINGTALK_AGENT_ID" ]; do
        log_error "AgentId 不能为空"
        read -p "请输入钉钉 AgentId: " DINGTALK_AGENT_ID
    done
    
    echo ""
    echo -e "${YELLOW}=== OpenClaw 配置 ===${NC}"
    echo ""
    
    # OpenClaw API URL
    read -p "请输入 OpenClaw API URL (默认：http://localhost:3000): " OPENCLAW_API_URL
    if [ -z "$OPENCLAW_API_URL" ]; then
        OPENCLAW_API_URL="http://localhost:3000"
    fi
    
    # OpenClaw API Key
    read -p "请输入 OpenClaw API Key: " OPENCLAW_API_KEY
    while [ -z "$OPENCLAW_API_KEY" ]; do
        log_error "API Key 不能为空"
        read -p "请输入 OpenClaw API Key: " OPENCLAW_API_KEY
    done
    
    echo ""
    echo -e "${YELLOW}=== 服务配置 ===${NC}"
    echo ""
    
    # 服务端口
    read -p "请输入服务端口 (默认：3001): " PORT
    if [ -z "$PORT" ]; then
        PORT="3001"
    fi
    
    # 日志级别
    echo ""
    echo "日志级别选项："
    echo "  1) debug   - 详细日志"
    echo "  2) info    - 普通日志 (推荐)"
    echo "  3) warn    - 仅警告和错误"
    echo "  4) error   - 仅错误"
    read -p "请选择日志级别 (1-4, 默认 2): " LOG_CHOICE
    
    case $LOG_CHOICE in
        1) LOG_LEVEL="debug" ;;
        2) LOG_LEVEL="info" ;;
        3) LOG_LEVEL="warn" ;;
        4) LOG_LEVEL="error" ;;
        *) LOG_LEVEL="info" ;;
    esac
    
    # 生成 .env 文件
    cat > .env << EOF
# 钉钉机器人配置
DINGTALK_APP_KEY=$DINGTALK_APP_KEY
DINGTALK_APP_SECRET=$DINGTALK_APP_SECRET
DINGTALK_AGENT_ID=$DINGTALK_AGENT_ID

# OpenClaw 配置
OPENCLAW_API_URL=$OPENCLAW_API_URL
OPENCLAW_API_KEY=$OPENCLAW_API_KEY

# 服务配置
PORT=$PORT
BIND_ADDRESS=0.0.0.0

# 日志配置
LOG_LEVEL=$LOG_LEVEL

# 临时文件配置
TEMP_DIR=./temp
TEMP_FILE_TTL_MS=3600000
EOF
    
    log_success ".env 文件已生成"
}

# 测试连接
test_connection() {
    echo ""
    log_info "测试服务启动..."
    
    # 创建临时目录
    if [ ! -d "temp" ]; then
        mkdir -p temp
        log_info "创建临时目录：temp/"
    fi
    
    # 启动服务（后台）
    log_info "启动服务..."
    node index.js &
    SERVICE_PID=$!
    
    # 等待服务启动
    sleep 3
    
    # 检查服务是否运行
    if kill -0 $SERVICE_PID 2>/dev/null; then
        log_success "服务启动成功 (PID: $SERVICE_PID)"
        
        # 测试健康检查
        log_info "测试健康检查端点..."
        HEALTH_RESPONSE=$(curl -s http://localhost:$PORT/health 2>/dev/null)
        
        if [ -n "$HEALTH_RESPONSE" ]; then
            log_success "健康检查通过"
            echo "响应：$HEALTH_RESPONSE"
        else
            log_warn "健康检查无响应，但服务正在运行"
        fi
        
        # 停止服务
        echo ""
        read -p "是否保持服务运行？(Y/n): " keep_running
        if [ "$keep_running" != "n" ] && [ "$keep_running" != "N" ]; then
            log_info "服务将继续在后台运行"
            log_info "停止服务：kill $SERVICE_PID"
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║${NC}  🎉 配置完成！服务已启动                         ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}                                                    ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}  健康检查：http://localhost:$PORT/health              ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}  钉钉回调：http://YOUR_IP:$PORT/dingtalk/callback     ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}  服务 PID:  $SERVICE_PID                              ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}                                                    ${GREEN}║${NC}"
            echo -e "${GREEN}║${NC}  停止服务：kill $SERVICE_PID                           ${GREEN}║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
            return 0
        else
            kill $SERVICE_PID
            log_info "服务已停止"
        fi
    else
        log_error "服务启动失败，请检查日志"
        echo ""
        log_info "尝试手动启动查看详细错误："
        echo "  npm start"
        return 1
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo -e "${YELLOW}=== 下一步操作 ===${NC}"
    echo ""
    echo "1. 配置钉钉回调地址："
    echo "   登录钉钉开放平台 → 事件订阅 → 配置回调地址"
    echo "   回调地址：http://YOUR_SERVER_IP:$PORT/dingtalk/callback"
    echo ""
    echo "2. 订阅 IM 消息事件"
    echo ""
    echo "3. 发布应用并授权给用户"
    echo ""
    echo "4. 启动服务："
    echo "   npm start"
    echo ""
    echo "5. 测试消息："
    echo "   在钉钉中发送消息给机器人"
    echo ""
    echo -e "${YELLOW}=== 常用命令 ===${NC}"
    echo ""
    echo "  npm start          - 启动服务"
    echo "  npm run dev        - 开发模式（自动重启）"
    echo "  ./start.sh         - 快速启动"
    echo "  curl http://localhost:$PORT/health  - 健康检查"
    echo ""
}

# 主函数
main() {
    print_banner
    
    echo -e "${BLUE}本向导将帮助你完成以下配置：${NC}"
    echo "  1. 检查 Node.js 环境"
    echo "  2. 安装项目依赖"
    echo "  3. 配置钉钉和 OpenClaw 参数"
    echo "  4. 测试服务启动"
    echo ""
    
    read -p "是否继续？(Y/n): " confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        log_info "已取消"
        exit 0
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 检查环境
    check_node
    check_npm
    
    # 安装依赖
    install_dependencies
    
    # 生成配置
    generate_env
    
    # 测试连接
    test_connection
    
    # 显示使用说明
    show_usage
    
    log_success "配置完成！"
    echo ""
}

# 运行主函数
main
