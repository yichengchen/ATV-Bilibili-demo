#!/bin/bash

###############################################################################
# BilibiliLive Apple TV 部署脚本
#
# 功能:
#   - 清理构建缓存
#   - 构建 tvOS 应用
#   - 部署到 Apple TV 4K
#
# 使用方法:
#   ./scripts/deploy_to_appletv.sh
#
# 作者: Claude Code Assistant
# 日期: 2025-10-01
###############################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="BilibiliLive"
SCHEME="BilibiliLive"
DEVICE_NAME="Jason room"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 自动检测设备 ID
detect_device_id() {
    # 优先使用 xcodebuild 的设备 ID
    local xcode_id=$(instruments -s devices 2>&1 | grep "$DEVICE_NAME" | grep -o '00008[0-9A-F-]*' | head -1)
    if [ -n "$xcode_id" ]; then
        echo "$xcode_id"
        return
    fi

    # 使用 devicectl 的设备标识符
    local devicectl_id=$(xcrun devicectl list devices 2>&1 | grep "$DEVICE_NAME" | awk '{print $3}' | head -1)
    if [ -n "$devicectl_id" ]; then
        echo "$devicectl_id"
        return
    fi

    echo ""
}

DEVICE_ID=$(detect_device_id)

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📌 $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     BilibiliLive Apple TV 自动部署工具                ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# 检查设备连接
check_device() {
    print_step "检查 Apple TV 设备连接"

    if [ -z "$DEVICE_ID" ]; then
        print_error "未检测到设备: $DEVICE_NAME"
        print_info "请检查:"
        echo "  1. Apple TV 是否开机"
        echo "  2. Mac 和 Apple TV 是否在同一 Wi-Fi 网络"
        echo "  3. Apple TV 的'远程App与设备'是否启用"
        echo "  4. 设备是否已在 Xcode 中配对"
        return 1
    fi

    print_info "检测到设备: $DEVICE_NAME"
    print_info "设备 ID: $DEVICE_ID"

    # 检查设备是否可用
    if xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE_ID"; then
        print_success "设备已连接并可用"
        return 0
    elif instruments -s devices 2>&1 | grep -q "$DEVICE_ID"; then
        print_success "设备已连接并可用"
        return 0
    else
        print_warning "设备已检测到但可能不可用,尝试继续..."
        return 0
    fi
}

# 清理构建缓存
clean_build() {
    print_step "清理构建缓存"

    local derived_data_path="${HOME}/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*"

    if ls ${derived_data_path} 1> /dev/null 2>&1; then
        print_info "清理 DerivedData: ${derived_data_path}"
        rm -rf ${derived_data_path}
        print_success "清理完成"
    else
        print_info "没有需要清理的缓存"
    fi
}

# 构建应用
build_app() {
    print_step "构建 tvOS 应用"

    print_info "项目: $PROJECT_NAME"
    print_info "Scheme: $SCHEME"
    print_info "目标设备: $DEVICE_NAME"

    cd "$PROJECT_DIR"

    print_info "开始构建..."

    # 根据设备 ID 类型选择目标
    local destination
    if [[ "$DEVICE_ID" =~ ^00008 ]]; then
        # 传统设备 ID
        destination="platform=tvOS,id=${DEVICE_ID}"
    else
        # devicectl 标识符,使用设备名称
        destination="platform=tvOS,name=${DEVICE_NAME}"
    fi

    print_info "构建目标: $destination"

    # 使用管道捕获输出,但保持实时显示关键信息
    if xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -allowProvisioningUpdates \
        clean build 2>&1 | \
        tee /tmp/xcodebuild.log | \
        grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:|Signing Identity:)" | \
        grep --line-buffered -v "warning:"; then

        print_success "构建成功!"
        return 0
    else
        print_error "构建失败!"
        print_info "完整日志已保存到: /tmp/xcodebuild.log"
        print_info "查看错误: cat /tmp/xcodebuild.log | grep error:"
        return 1
    fi
}

# 安装应用到 Apple TV
install_app() {
    print_step "安装应用到 Apple TV"

    local app_path="${HOME}/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*/Build/Products/Debug-appletvos/${PROJECT_NAME}.app"

    # 查找 .app 文件
    print_info "查找构建产物..."
    local found_app=$(ls -d ${app_path} 2>/dev/null | head -1)

    if [ -z "$found_app" ]; then
        print_error "未找到构建产物: ${app_path}"
        return 1
    fi

    print_success "找到应用: $found_app"
    print_info "开始安装到设备: $DEVICE_NAME"

    if xcrun devicectl device install app \
        --device "$DEVICE_ID" \
        "$found_app" 2>&1; then

        print_success "应用安装成功!"
        return 0
    else
        print_error "应用安装失败"
        return 1
    fi
}

# 显示部署信息
show_deployment_info() {
    print_step "部署信息"

    echo -e "${GREEN}🎉 部署成功!${NC}\n"
    echo "设备信息:"
    echo "  • 设备名称: $DEVICE_NAME"
    echo "  • 设备 ID: $DEVICE_ID"
    echo "  • Bundle ID: com.niuyp.BilibiliLive.demo"
    echo ""
    echo "注意事项:"
    echo "  • 免费 Apple ID 签名的应用有效期为 7 天"
    echo "  • 过期后需要重新运行此脚本部署"
    echo "  • 现在可以在 Apple TV 上打开并测试应用"
    echo ""
    print_warning "tvOS 平台字幕功能暂时禁用,视频播放功能正常"
}

# 主函数
main() {
    local start_time=$(date +%s)

    # 检查是否在项目根目录
    if [ ! -f "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        print_error "未找到项目文件,请确保在项目根目录运行此脚本"
        exit 1
    fi

    # 执行部署流程
    if ! check_device; then
        exit 1
    fi

    clean_build

    if ! build_app; then
        exit 1
    fi

    if ! install_app; then
        exit 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    show_deployment_info

    print_success "总耗时: ${duration} 秒"
}

# 执行主函数
main "$@"
