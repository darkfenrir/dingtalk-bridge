#!/bin/bash

# ============================================
# 钉钉桥接中间件 - 快速启动脚本
# ============================================
# 用法：
#   ./quick-start.sh           - 正常启动
#   ./quick-start.sh setup     - 重新配置
#   ./quick-start.sh dev       - 开发模式
#   ./quick-start.sh stop      - 停止服务
#   ./quick-start.sh status    - 查看状态
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PID_FILE=".service.pid"
LOG_FILE="logs/app.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 创建日志目录
mkdir -p logs

# 检查 .env 文件
check_env() {
    if [ ! -f ".env" ]; then
        log_error "未找到 .env 配置文件"
        echo ""
        echo "请先运行配置向导："
        echo "  ./setup.sh"
        echo ""
        exit 1
    fi
    
    # 检查必需的配置
    if ! grep -q "DINGTALK_APP_KEY=" .env || \
       ! grep -q "DINGTALK_APP_SECRET=" .env || \
       ! grep -q "DINGTALK_AGENT_ID=" .env; then
        log_error ".env 文件配置不完整"
        echo "请运行配置向导："
        echo "  ./setup.sh"
        exit 1
    fi
}

# 检查依赖
check_deps() {
    if [ ! -d "node_modules" ]; then
        log_warn "未找到 node_modules，正在安装依赖..."
        npm install
    fi
}

# 启动服务
start_service() {
    check_env
    check_deps
    
    # 创建临时目录
    mkdir -p temp
    
    # 检查服务是否已在运行
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 $OLD_PID 2>/dev/null; then
            log_warn "服务已在运行 (PID: $OLD_PID)"
            echo ""
            echo "停止服务：$0 stop"
            echo "重启服务：$0 restart"
            exit 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    log_info "启动钉钉桥接服务..."
    
    # 后台启动
    nohup node index.js > "$LOG_FILE" 2>&1 &
    NEW_PID=$!
    
    echo $NEW_PID > "$PID_FILE"
    
    # 等待启动
    sleep 2
    
    # 检查是否启动成功
    if kill -0 $NEW_PID 2>/dev/null; then
        log_success "服务启动成功"
        echo ""
        echo "  PID:      $NEW_PID"
        echo "  日志：    tail -f $LOG_FILE"
        echo "  停止：    $0 stop"
        echo "  重启：    $0 restart"
        echo ""
        
        # 读取端口
        PORT=$(grep "^PORT=" .env | cut -d'=' -f2)
        PORT=${PORT:-3001}
        
        echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  服务已启动                                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                  ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  健康检查：http://localhost:$PORT/health              ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  钉钉回调：http://YOUR_IP:$PORT/dingtalk/callback     ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                  ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  查看日志：tail -f $LOG_FILE                         ${GREEN}║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    else
        log_error "服务启动失败"
        echo ""
        echo "查看日志："
        tail -20 "$LOG_FILE"
        exit 1
    fi
}

# 开发模式
dev_mode() {
    check_env
    check_deps
    
    log_info "开发模式启动（自动重启）..."
    echo ""
    
    # 使用 --watch 参数
    node --watch index.js
}

# 停止服务
stop_service() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            log_info "停止服务 (PID: $PID)..."
            kill $PID
            sleep 1
            
            # 强制停止
            if kill -0 $PID 2>/dev/null; then
                kill -9 $PID
            fi
            
            rm -f "$PID_FILE"
            log_success "服务已停止"
        else
            log_warn "服务未运行"
            rm -f "$PID_FILE"
        fi
    else
        # 尝试通过进程名查找
        PID=$(pgrep -f "node index.js" | head -1)
        if [ -n "$PID" ]; then
            log_info "停止服务 (PID: $PID)..."
            kill $PID
            sleep 1
            if kill -0 $PID 2>/dev/null; then
                kill -9 $PID
            fi
            log_success "服务已停止"
        else
            log_warn "未找到运行的服务"
        fi
    fi
}

# 重启服务
restart_service() {
    stop_service
    sleep 1
    start_service
}

# 查看状态
show_status() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  钉钉桥接服务状态                                ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 检查服务状态
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            echo -e "服务状态：${GREEN}运行中${NC}"
            echo "  PID:    $PID"
            
            # 读取端口
            PORT=$(grep "^PORT=" .env | cut -d'=' -f2)
            PORT=${PORT:-3001}
            echo "  端口：  $PORT"
            
            # 运行时间
            START_TIME=$(ps -p $PID -o lstart=)
            echo "  启动：  $START_TIME"
            
            # 健康检查
            echo ""
            log_info "健康检查..."
            curl -s http://localhost:$PORT/health | python3 -m json.tool 2>/dev/null || \
                curl -s http://localhost:$PORT/health
        else
            echo -e "服务状态：${YELLOW}已停止${NC} (PID 文件存在但进程不存在)"
            rm -f "$PID_FILE"
        fi
    else
        PID=$(pgrep -f "node index.js" | head -1)
        if [ -n "$PID" ]; then
            echo -e "服务状态：${GREEN}运行中${NC}"
            echo "  PID:    $PID"
        else
            echo -e "服务状态：${RED}未运行${NC}"
        fi
    fi
    
    echo ""
    
    # 检查配置
    if [ -f ".env" ]; then
        echo -e "配置文件：${GREEN}存在${NC}"
    else
        echo -e "配置文件：${RED}不存在${NC}"
    fi
    
    # 检查依赖
    if [ -d "node_modules" ]; then
        echo -e "项目依赖：${GREEN}已安装${NC}"
    else
        echo -e "项目依赖：${RED}未安装${NC}"
    fi
    
    # 临时目录
    if [ -d "temp" ]; then
        TEMP_SIZE=$(du -sh temp 2>/dev/null | cut -f1)
        echo -e "临时文件：${GREEN}$TEMP_SIZE${NC}"
    else
        echo -e "临时文件：${BLUE}无${NC}"
    fi
    
    echo ""
}

# 查看日志
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -50 "$LOG_FILE"
    else
        log_warn "日志文件不存在"
    fi
}

# 显示帮助
show_help() {
    echo ""
    echo -e "${BLUE}钉钉桥接中间件 - 快速启动脚本${NC}"
    echo ""
    echo "用法：$0 [命令]"
    echo ""
    echo "命令:"
    echo "  start       启动服务（默认）"
    echo "  stop        停止服务"
    echo "  restart     重启服务"
    echo "  status      查看服务状态"
    echo "  logs        查看日志"
    echo "  dev         开发模式（自动重启）"
    echo "  setup       运行配置向导"
    echo "  help        显示帮助"
    echo ""
    echo "示例:"
    echo "  $0              - 启动服务"
    echo "  $0 start        - 启动服务"
    echo "  $0 stop         - 停止服务"
    echo "  $0 restart      - 重启服务"
    echo "  $0 dev          - 开发模式"
    echo "  $0 setup        - 重新配置"
    echo ""
}

# 主逻辑
case "${1:-start}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    dev)
        dev_mode
        ;;
    setup)
        ./setup.sh
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        log_error "未知命令：$1"
        show_help
        exit 1
        ;;
esac
