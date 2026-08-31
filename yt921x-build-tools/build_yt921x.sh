#!/bin/bash
#=============================================================================
# YT9215S 交换机驱动一键编译脚本
# 适配飞牛 FNOS / BDY-G98 / RK3588 平台
# 支持内核升级后一键重新编译
#=============================================================================

set -e

#============================= 配置区 ======================================
#
# ⚠️  使用前请配置以下参数（或通过命令行参数 / 环境变量指定）
#
#   TARGET_IP   - 飞牛设备 IP 地址（如 192.168.1.100），用于自动检测内核版本
#   TARGET_USER - 飞牛设备登录用户名（如 root、admin 等）
#
#   配置方式（三选一）：
#   1. 修改下方默认值
#   2. 命令行参数: ./build_yt921x.sh --target-ip 192.168.1.100
#   3. 环境变量: TARGET_IP=192.168.1.100 TARGET_USER=root ./build_yt921x.sh
#
#   注意：如不配置 TARGET_IP，将从内核源码读取版本，可能与飞牛实际版本不匹配
#
#=============================================================================

# 默认配置（可通过命令行参数覆盖）
KERNEL_DIR="${KERNEL_DIR:-$HOME/kernel}"           # 内核源码目录
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/yt921x-output}"    # 编译输出目录
TARGET_IP="${TARGET_IP:-}"                    # 目标设备 IP（请替换为你的飞牛设备IP）
TARGET_USER="${TARGET_USER:-user}"              # 目标设备用户名（请替换为你的用户名）
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}" # 交叉编译器前缀
ARCH="${ARCH:-arm64}"                                # 目标架构

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#============================= 函数区 ======================================

print_banner() {
    echo -e "${BLUE}"
    echo "================================================================"
    echo "  YT9215S 交换机驱动一键编译脚本"
    echo "  适配: 飞牛 FNOS / BDY-G98 / RK3588"
    echo "================================================================"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}[步骤 $1]${NC} $2"
    echo "----------------------------------------------------------------"
}

print_error() {
    echo -e "\n${RED}[错误]${NC} $1"
}

print_warn() {
    echo -e "\n${YELLOW}[警告]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

check_dependencies() {
    print_step "1/8" "检查编译依赖"

    local missing=()

    # 检查交叉编译器
    if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
        missing+=("${CROSS_COMPILE}gcc (交叉编译器)")
    fi

    # 检查基础工具
    for tool in make gcc bison flex bc; do
        if ! command -v $tool &> /dev/null; then
            missing+=("$tool")
        fi
    done

    # 检查开发库
    if [ ! -f /usr/include/openssl/ssl.h ] && [ ! -f /usr/include/x86_64-linux-gnu/openssl/ssl.h ]; then
        missing+=("libssl-dev")
    fi
    if [ ! -f /usr/include/elfutils/libelf.h ] && [ ! -f /usr/include/libelf.h ]; then
        missing+=("libelf-dev")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_warn "缺少以下依赖，正在自动安装..."
        echo "  - ${missing[*]}"
        sudo apt update
        sudo apt install -y gcc-aarch64-linux-gnu build-essential libssl-dev \
            libelf-dev bison flex bc kmod cpio python3
        print_info "依赖安装完成"
    else
        print_info "所有依赖已满足"
    fi

    # 验证交叉编译器
    ${CROSS_COMPILE}gcc --version | head -1
}

detect_target_kernel() {
    print_step "2/8" "检测目标内核版本"

    # 优先从目标设备获取
    if [ -n "$TARGET_IP" ] && command -v ssh &> /dev/null; then
        print_info "尝试从目标设备 $TARGET_IP 获取内核版本..."
        TARGET_KERNEL=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            ${TARGET_USER}@${TARGET_IP} "uname -r" 2>/dev/null || true)

        if [ -n "$TARGET_KERNEL" ]; then
            echo -e "  目标设备内核版本: ${GREEN}$TARGET_KERNEL${NC}"
        else
            print_warn "无法连接目标设备，将使用内核源码中的版本"
            TARGET_KERNEL=""
        fi
    fi

    # 如果无法从设备获取，从内核源码 Makefile 读取
    if [ -z "$TARGET_KERNEL" ] && [ -f "$KERNEL_DIR/Makefile" ]; then
        local VERSION=$(grep -m1 '^VERSION =' "$KERNEL_DIR/Makefile" | awk '{print $3}')
        local PATCHLEVEL=$(grep -m1 '^PATCHLEVEL =' "$KERNEL_DIR/Makefile" | awk '{print $3}')
        local SUBLEVEL=$(grep -m1 '^SUBLEVEL =' "$KERNEL_DIR/Makefile" | awk '{print $3}')
        local EXTRAVERSION=$(grep -m1 '^EXTRAVERSION =' "$KERNEL_DIR/Makefile" | awk '{print $3}')
        TARGET_KERNEL="${VERSION}.${PATCHLEVEL}.${SUBLEVEL}${EXTRAVERSION}"
        print_info "从内核源码读取版本: $TARGET_KERNEL"
    fi

    # 允许用户手动指定
    if [ -n "$KERNEL_VERSION" ]; then
        TARGET_KERNEL="$KERNEL_VERSION"
        print_info "使用手动指定版本: $TARGET_KERNEL"
    fi

    if [ -z "$TARGET_KERNEL" ]; then
        print_error "无法确定目标内核版本，请使用 KERNEL_VERSION=xxx 指定"
        exit 1
    fi

    echo "TARGET_KERNEL=$TARGET_KERNEL" > /tmp/yt921x_build.env
}

prepare_kernel_source() {
    print_step "3/8" "准备内核源码"

    # 检查内核源码目录
    if [ ! -d "$KERNEL_DIR" ]; then
        print_warn "内核源码目录不存在: $KERNEL_DIR"
        echo "  请选择获取方式:"
        echo "  1) 从 GitHub 克隆 Rockchip 6.18 内核"
        echo "  2) 手动指定内核源码路径"
        echo "  3) 退出"
        read -p "请选择 [1-3]: " choice

        case $choice in
            1)
                print_info "正在克隆内核源码（这可能需要几分钟）..."
                git clone --depth=1 -b linux-6.18.y-rockchip \
                    https://github.com/radxa/kernel.git "$KERNEL_DIR"
                ;;
            2)
                read -p "请输入内核源码路径: " custom_path
                KERNEL_DIR="$custom_path"
                if [ ! -d "$KERNEL_DIR" ]; then
                    print_error "目录不存在: $KERNEL_DIR"
                    exit 1
                fi
                ;;
            *)
                print_error "已取消"
                exit 1
                ;;
        esac
    fi

    cd "$KERNEL_DIR"
    print_info "内核源码目录: $KERNEL_DIR"

    # 检查 YT9215 驱动源码是否存在
    local DRIVER_FILE="drivers/net/dsa/yt921x.c"
    local TAG_FILE="net/dsa/tag_yt921x.c"

    if [ ! -f "$DRIVER_FILE" ]; then
        print_error "驱动源码不存在: $DRIVER_FILE"
        echo "  请确认内核源码版本包含 YT9215S 驱动支持"
        echo "  或手动将驱动源码放入 drivers/net/dsa/ 目录"
        exit 1
    fi

    if [ ! -f "$TAG_FILE" ]; then
        print_error "标签协议源码不存在: $TAG_FILE"
        exit 1
    fi

    print_info "驱动源码检查通过"
    echo "  - $DRIVER_FILE"
    echo "  - $TAG_FILE"
}

configure_kernel() {
    print_step "4/8" "配置内核"

    cd "$KERNEL_DIR"
    export ARCH=$ARCH
    export CROSS_COMPILE=$CROSS_COMPILE

    # 检查是否已有 .config
    if [ ! -f .config ]; then
        print_warn "未找到 .config，尝试从目标设备获取..."

        if [ -n "$TARGET_IP" ]; then
            # 尝试从设备获取配置
            ssh -o ConnectTimeout=5 ${TARGET_USER}@${TARGET_IP} \
                "zcat /proc/config.gz 2>/dev/null || cat /boot/config-$(ssh ${TARGET_USER}@${TARGET_IP} uname -r) 2>/dev/null" \
                > .config 2>/dev/null || true
        fi

        if [ ! -s .config ]; then
            print_warn "无法获取设备配置，使用默认 defconfig"
            make defconfig
        fi
    fi

    # 确保 YT9215 驱动配置为模块
    print_info "启用 YT9215S 驱动配置..."

    scripts/config --enable CONFIG_NET_DSA
    scripts/config --module CONFIG_NET_DSA_YT921X
    scripts/config --module CONFIG_NET_DSA_TAG_YT921X

    # 更新配置
    make olddefconfig

    # 验证配置
    local CONFIG_YT921X=$(grep -c 'CONFIG_NET_DSA_YT921X=m' .config || true)
    local CONFIG_TAG=$(grep -c 'CONFIG_NET_DSA_TAG_YT921X=m' .config || true)

    if [ "$CONFIG_YT921X" -gt 0 ] && [ "$CONFIG_TAG" -gt 0 ]; then
        print_info "内核配置已启用 YT9215S 驱动（模块方式）"
    else
        print_error "内核配置失败，请手动检查 .config"
        exit 1
    fi
}

build_modules() {
    print_step "5/8" "编译驱动模块"

    cd "$KERNEL_DIR"
    export ARCH=$ARCH
    export CROSS_COMPILE=$CROSS_COMPILE

    # 准备模块编译环境
    print_info "执行 modules_prepare..."
    make modules_prepare -j$(nproc)

    # 编译 yt921x.ko
    print_info "编译 yt921x.ko..."
    make drivers/net/dsa/yt921x.ko -j$(nproc)

    # 编译 tag_yt921x.ko
    print_info "编译 tag_yt921x.ko..."
    make net/dsa/tag_yt921x.ko -j$(nproc)

    # 验证编译产物
    if [ -f drivers/net/dsa/yt921x.ko ] && [ -f net/dsa/tag_yt921x.ko ]; then
        print_info "编译成功"
        ls -lh drivers/net/dsa/yt921x.ko net/dsa/tag_yt921x.ko
    else
        print_error "编译失败，未找到 .ko 文件"
        exit 1
    fi
}

fix_vermagic() {
    print_step "6/8" "修正 vermagic"

    source /tmp/yt921x_build.env 2>/dev/null || true

    cd "$KERNEL_DIR"

    # 获取当前编译产物的 vermagic
    local CURRENT_VERMAGIC=$(modinfo drivers/net/dsa/yt921x.ko 2>/dev/null | grep vermagic | awk '{print $2}')
    echo "  编译产物 vermagic: $CURRENT_VERMAGIC"
    echo "  目标内核 vermagic: $TARGET_KERNEL"

    if [ "$CURRENT_VERMAGIC" = "$TARGET_KERNEL" ]; then
        print_info "vermagic 已匹配，无需修改"
    else
        print_warn "vermagic 不匹配，正在修正..."

        # 二进制替换 vermagic
        sed -i "s/$CURRENT_VERMAGIC/$TARGET_KERNEL/g" drivers/net/dsa/yt921x.ko
        sed -i "s/$CURRENT_VERMAGIC/$TARGET_KERNEL/g" net/dsa/tag_yt921x.ko

        # 验证修正结果
        local NEW_VERMAGIC=$(modinfo drivers/net/dsa/yt921x.ko 2>/dev/null | grep vermagic | awk '{print $2}')
        if [ "$NEW_VERMAGIC" = "$TARGET_KERNEL" ]; then
            print_info "vermagic 修正成功: $NEW_VERMAGIC"
        else
            print_error "vermagic 修正失败"
            echo "  当前: $NEW_VERMAGIC"
            echo "  目标: $TARGET_KERNEL"
            exit 1
        fi
    fi
}

package_output() {
    print_step "7/8" "整理输出文件"

    source /tmp/yt921x_build.env 2>/dev/null || true

    mkdir -p "$OUTPUT_DIR"

    cd "$KERNEL_DIR"

    # 复制驱动文件
    cp drivers/net/dsa/yt921x.ko "$OUTPUT_DIR/"
    cp net/dsa/tag_yt921x.ko "$OUTPUT_DIR/"

    # 生成安装脚本
    cat > "$OUTPUT_DIR/install.sh" << 'INSTALL_EOF'
#!/bin/bash
# YT9215S 驱动一键安装脚本
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 权限运行: sudo ./install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VERSION=$(uname -r)
DRIVER_DIR="/lib/modules/$KERNEL_VERSION/updates/trim/yt921x"

echo -e "${GREEN}=== YT9215S 驱动安装 ===${NC}"
echo "内核版本: $KERNEL_VERSION"

# 1. 创建目录
mkdir -p "$DRIVER_DIR"

# 2. 复制驱动
cp "$SCRIPT_DIR/yt921x.ko" "$DRIVER_DIR/"
cp "$SCRIPT_DIR/tag_yt921x.ko" "$DRIVER_DIR/"

# 3. 修正 vermagic（如需要）
CURRENT_VERMAGIC=$(modinfo "$DRIVER_DIR/yt921x.ko" | grep vermagic | awk '{print $2}')
if [ "$CURRENT_VERMAGIC" != "$KERNEL_VERSION" ]; then
    echo "修正 vermagic: $CURRENT_VERMAGIC -> $KERNEL_VERSION"
    sed -i "s/$CURRENT_VERMAGIC/$KERNEL_VERSION/g" "$DRIVER_DIR/yt921x.ko"
    sed -i "s/$CURRENT_VERMAGIC/$KERNEL_VERSION/g" "$DRIVER_DIR/tag_yt921x.ko"
fi

# 4. 更新模块依赖
depmod -a

# 5. 加载驱动
echo "加载驱动模块..."
modprobe tag_yt921x
modprobe yt921x

# 6. 设置开机自动加载
mkdir -p /etc/modules-load.d
echo "tag_yt921x" > /etc/modules-load.d/yt921x.conf
echo "yt921x" >> /etc/modules-load.d/yt921x.conf

# 7. 验证
echo ""
echo -e "${GREEN}=== 验证结果 ===${NC}"
echo "驱动模块:"
lsmod | grep yt921 || echo -e "${RED}驱动未加载!${NC}"

echo ""
echo "网口数量:"
ip -o link show | grep -v 'lo:' | wc -l

echo ""
echo "网口列表:"
ls /sys/class/net/ | grep -v lo

echo ""
echo -e "${GREEN}安装完成!${NC}"
echo "驱动目录: $DRIVER_DIR"
echo "开机自动加载: /etc/modules-load.d/yt921x.conf"
INSTALL_EOF

    chmod +x "$OUTPUT_DIR/install.sh"

    # 生成版本信息
    cat > "$OUTPUT_DIR/version.txt" << EOF
YT9215S 交换机驱动编译产物
============================
编译时间: $(date '+%Y-%m-%d %H:%M:%S')
目标内核: $TARGET_KERNEL
目标架构: $ARCH
交叉编译器: $(${CROSS_COMPILE}gcc --version | head -1)
内核源码: $KERNEL_DIR

文件清单:
  - yt921x.ko      (DSA 交换机主驱动)
  - tag_yt921x.ko  (标签协议驱动)
  - install.sh      (一键安装脚本)

使用方法:
  1. 将本目录上传到目标设备
  2. 执行 sudo ./install.sh
  3. 重启或手动加载驱动
EOF

    # 显示输出
    echo ""
    print_info "输出目录: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR/"
}

upload_to_device() {
    print_step "8/8" "上传到目标设备（可选）"

    if [ -z "$TARGET_IP" ]; then
        print_info "未指定目标设备 IP，跳过上传"
        return 0
    fi

    read -p "是否上传到目标设备 $TARGET_IP? [y/N]: " upload_choice
    if [ "$upload_choice" != "y" ] && [ "$upload_choice" != "Y" ]; then
        print_info "跳过上传"
        return 0
    fi

    print_info "正在上传到 $TARGET_IP..."

    # 创建远程目录
    ssh -o StrictHostKeyChecking=no ${TARGET_USER}@${TARGET_IP} \
        "mkdir -p /tmp/yt921x-driver"

    # 上传文件
    scp -o StrictHostKeyChecking=no \
        "$OUTPUT_DIR/yt921x.ko" \
        "$OUTPUT_DIR/tag_yt921x.ko" \
        "$OUTPUT_DIR/install.sh" \
        ${TARGET_USER}@${TARGET_IP}:/tmp/yt921x-driver/

    print_info "上传完成"
    echo "  远程目录: /tmp/yt921x-driver/"
    echo "  安装命令: ssh ${TARGET_USER}@${TARGET_IP} 'cd /tmp/yt921x-driver && sudo ./install.sh'"
}

print_summary() {
    source /tmp/yt921x_build.env 2>/dev/null || true

    echo ""
    echo -e "${GREEN}================================================================"
    echo "  编译完成!"
    echo "===============================================================${NC}"
    echo ""
    echo "  目标内核: $TARGET_KERNEL"
    echo "  输出目录: $OUTPUT_DIR"
    echo ""
    echo "  文件清单:"
    echo "    - yt921x.ko      (DSA 交换机主驱动)"
    echo "    - tag_yt921x.ko  (标签协议驱动)"
    echo "    - install.sh      (一键安装脚本)"
    echo "    - version.txt     (版本信息)"
    echo ""
    echo "  快速安装:"
    echo "    scp -r $OUTPUT_DIR ${TARGET_USER}@${TARGET_IP}:/tmp/"
    echo "    ssh ${TARGET_USER}@${TARGET_IP}"
    echo "    cd /tmp/$(basename $OUTPUT_DIR) && sudo ./install.sh"
    echo ""
    echo -e "${GREEN}===============================================================${NC}"
}

#============================= 主流程 ======================================

main() {
    print_banner

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --kernel-dir)
                KERNEL_DIR="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --target-ip)
                TARGET_IP="$2"
                shift 2
                ;;
            --kernel-version)
                KERNEL_VERSION="$2"
                shift 2
                ;;
            --cross-compile)
                CROSS_COMPILE="$2"
                shift 2
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --kernel-dir DIR     内核源码目录 (默认: ~/kernel)"
                echo "  --output-dir DIR     输出目录 (默认: ~/yt921x-output)"
                echo "  --target-ip IP       目标设备 IP (如 192.168.1.100，用于自动检测内核版本)"
                echo "  --kernel-version VER 手动指定目标内核版本"
                echo "  --cross-compile PRE  交叉编译器前缀 (默认: aarch64-linux-gnu-)"
                echo "  -h, --help           显示帮助"
                echo ""
                echo "环境变量:"
                echo "  KERNEL_DIR, OUTPUT_DIR, TARGET_IP, TARGET_USER,"
                echo "  CROSS_COMPILE, ARCH, KERNEL_VERSION"
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                exit 1
                ;;
        esac
    done

    # 执行编译流程
    check_dependencies
    detect_target_kernel
    prepare_kernel_source
    configure_kernel
    build_modules
    fix_vermagic
    package_output
    upload_to_device
    print_summary
}

main "$@"
