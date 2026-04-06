#!/bin/bash

###############################################################################
# BilibiliLive Apple TV 部署脚本
#
# 功能:
#   - 自动检测已连接的 Apple TV 设备
#   - 构建 tvOS 应用
#   - 部署到 Apple TV
#
# 使用方法:
#   ./scripts/deploy_to_appletv.sh              # 自动检测设备
#   ./scripts/deploy_to_appletv.sh --clean      # 清理后构建
#   ./scripts/deploy_to_appletv.sh --list       # 列出可用设备
#   ./scripts/deploy_to_appletv.sh --help       # 显示帮助
#
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
PROJECT_NAME="BilibiliLive"
SCHEME="BilibiliLive"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
LOG_FILE="${BUILD_DIR}/deploy.log"
HISTORY_FILE="${BUILD_DIR}/deploy_history.log"

# 确保构建目录存在
mkdir -p "$BUILD_DIR"

# 打印函数
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_step() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📌 $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 显示帮助
show_help() {
    cat << EOF
BilibiliLive Apple TV 部署脚本

用法: $0 [选项]

选项:
  --clean       清理构建缓存后再构建
  --list        列出所有可用的 Apple TV 设备
  --device ID   指定设备 ID (UUID 格式)
  --release     使用 Release 配置构建
  --help        显示此帮助信息

示例:
  $0                                    # 自动检测并部署
  $0 --clean                            # 清理后部署
  $0 --device FBF5B599-37F2-5989-...    # 部署到指定设备
  $0 --list                             # 查看可用设备

EOF
}

# 列出可用设备
list_devices() {
    print_step "可用的 Apple TV 设备"

    if ! command -v xcrun &> /dev/null; then
        print_error "未找到 xcrun 命令，请确保已安装 Xcode"
        exit 1
    fi

    echo "设备列表:"
    echo ""
    xcrun devicectl list devices 2>/dev/null | grep -E "(Apple TV|Name)" || {
        print_warning "未检测到 Apple TV 设备"
        echo ""
        echo "请确保:"
        echo "  1. Apple TV 已开机"
        echo "  2. Mac 和 Apple TV 在同一网络"
        echo "  3. Apple TV 已在 Xcode 中配对"
    }
}

# 自动检测 Apple TV 设备
detect_device() {
    local device_info
    device_info=$(xcrun devicectl list devices 2>/dev/null | grep "Apple TV" | head -1)

    if [ -z "$device_info" ]; then
        return 1
    fi

    # 提取设备信息
    DEVICE_NAME=$(echo "$device_info" | awk '{print $1" "$2}' | sed 's/[[:space:]]*$//')
    DEVICE_ID=$(echo "$device_info" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}')
    DEVICE_STATE=$(echo "$device_info" | awk '{print $(NF-1)}')

    if [ -n "$DEVICE_ID" ]; then
        return 0
    fi
    return 1
}

# 检查设备连接
check_device() {
    print_step "检查 Apple TV 设备"

    if [ -n "$SPECIFIED_DEVICE_ID" ]; then
        DEVICE_ID="$SPECIFIED_DEVICE_ID"
        print_info "使用指定设备: $DEVICE_ID"
    else
        if ! detect_device; then
            print_error "未检测到 Apple TV 设备"
            echo ""
            echo "请检查:"
            echo "  1. Apple TV 是否已开机"
            echo "  2. Mac 和 Apple TV 是否在同一 Wi-Fi 网络"
            echo "  3. 在 Xcode → Window → Devices and Simulators 中配对设备"
            echo ""
            echo "运行 '$0 --list' 查看可用设备"
            return 1
        fi
    fi

    print_success "设备: ${DEVICE_NAME:-Unknown}"
    print_info "ID: $DEVICE_ID"

    # 检查设备状态
    local state
    state=$(xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_ID" | awk '{print $(NF-1)}')

    if [ "$state" = "unavailable" ]; then
        print_warning "设备当前不可用，可能需要唤醒 Apple TV"
    else
        print_success "设备状态: $state"
    fi

    return 0
}

# 清理构建
clean_build() {
    print_step "清理构建缓存"

    cd "$PROJECT_DIR"

    # 清理 DerivedData
    local derived_data="${HOME}/Library/Developer/Xcode/DerivedData"
    local project_derived=$(find "$derived_data" -maxdepth 1 -name "${PROJECT_NAME}-*" -type d 2>/dev/null)

    if [ -n "$project_derived" ]; then
        print_info "清理: $project_derived"
        rm -rf "$project_derived"
    fi

    # 清理本地构建目录
    if [ -d "${BUILD_DIR}/DerivedData" ]; then
        print_info "清理本地 DerivedData"
        rm -rf "${BUILD_DIR}/DerivedData"
    fi

    print_success "清理完成"
}

# 构建应用
build_app() {
    print_step "构建 tvOS 应用"

    cd "$PROJECT_DIR"

    print_info "项目: $PROJECT_NAME"
    print_info "Scheme: $SCHEME"
    print_info "配置: $BUILD_CONFIG"

    local destination="generic/platform=tvOS"
    local derived_data_path="${BUILD_DIR}/DerivedData"

    # 确保 tvOS 平台完整安装（SDK + runtime）
    # Apple TV 自动更新 tvOS 后，Xcode 可能有 SDK 但缺少 runtime，导致找不到 destination
    local tvos_destinations
    tvos_destinations=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME" -showdestinations 2>&1 | grep "platform:tvOS," | grep -v "error:" | head -1)
    if [ -z "$tvos_destinations" ]; then
        print_warning "tvOS 平台不完整，正在下载 SDK 和运行时..."
        if ! xcodebuild -downloadPlatform tvOS; then
            print_error "tvOS 平台下载失败"
            print_info "请手动安装: Xcode > Settings > Components > tvOS"
            return 1
        fi
        print_success "tvOS 平台下载完成"
    fi

    print_info "开始构建..."
    echo ""

    # 构建命令 - 使用 pipefail 确保正确检测构建失败
    set -o pipefail
    xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$BUILD_CONFIG" \
        -destination "$destination" \
        -derivedDataPath "$derived_data_path" \
        -allowProvisioningUpdates \
        build 2>&1 | tee "$LOG_FILE" | \
        grep -E --line-buffered "(BUILD SUCCEEDED|BUILD FAILED|error:|Compiling|Linking)"

    local build_result=${PIPESTATUS[0]}
    set +o pipefail

    echo ""

    # 检查构建结果
    if [ $build_result -eq 0 ] && grep -q "BUILD SUCCEEDED" "$LOG_FILE"; then
        print_success "构建成功!"
        return 0
    else
        print_error "构建失败!"
        print_info "查看完整日志: $LOG_FILE"
        echo ""
        print_info "错误信息:"
        grep "error:" "$LOG_FILE" | head -5
        return 1
    fi
}

# 安装应用
install_app() {
    print_step "安装应用到 Apple TV"

    local app_path="${BUILD_DIR}/DerivedData/Build/Products/${BUILD_CONFIG}-appletvos/${PROJECT_NAME}.app"

    if [ ! -d "$app_path" ]; then
        # 尝试查找其他位置
        app_path=$(find "${BUILD_DIR}/DerivedData" -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)
    fi

    if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
        print_error "未找到构建产物"
        print_info "请检查构建是否成功完成"
        return 1
    fi

    print_success "找到应用: $app_path"
    print_info "正在安装到设备..."

    if xcrun devicectl device install app --device "$DEVICE_ID" "$app_path" 2>&1; then
        print_success "安装成功!"
        return 0
    else
        print_error "安装失败"
        echo ""
        echo "可能的原因:"
        echo "  1. 设备未唤醒或不可用"
        echo "  2. 签名证书问题"
        echo "  3. 设备存储空间不足"
        return 1
    fi
}

# 记录部署历史
log_deployment() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Device: ${DEVICE_NAME:-$DEVICE_ID}, Config: $BUILD_CONFIG, Status: $1" >> "$HISTORY_FILE"
}

# 显示完成信息
show_success() {
    print_step "部署完成"

    echo -e "${GREEN}🎉 应用已成功部署到 Apple TV!${NC}"
    echo ""
    echo "设备信息:"
    echo "  • 名称: ${DEVICE_NAME:-Unknown}"
    echo "  • ID: $DEVICE_ID"
    echo ""
    echo "提示:"
    echo "  • 在 Apple TV 上打开应用即可使用"
    echo "  • 免费开发者证书签名的应用有效期为 7 天"
    echo "  • 过期后重新运行此脚本即可"
    echo ""

    log_deployment "SUCCESS"
}

# 主函数
main() {
    local start_time=$(date +%s)
    local do_clean=false
    BUILD_CONFIG="Debug"
    SPECIFIED_DEVICE_ID=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                do_clean=true
                shift
                ;;
            --list)
                list_devices
                exit 0
                ;;
            --device)
                SPECIFIED_DEVICE_ID="$2"
                shift 2
                ;;
            --release)
                BUILD_CONFIG="Release"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Banner
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║     BilibiliLive Apple TV 部署工具                    ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    # 检查项目
    if [ ! -f "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        print_error "未找到项目文件"
        print_info "请在项目根目录运行此脚本"
        exit 1
    fi

    # 检查设备
    if ! check_device; then
        log_deployment "FAILED:NO_DEVICE"
        exit 1
    fi

    # 清理（如果需要）
    if [ "$do_clean" = true ]; then
        clean_build
    fi

    # 构建
    if ! build_app; then
        log_deployment "FAILED:BUILD"
        exit 1
    fi

    # 安装
    if ! install_app; then
        log_deployment "FAILED:INSTALL"
        exit 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    show_success
    print_success "总耗时: ${duration} 秒"
}

main "$@"
