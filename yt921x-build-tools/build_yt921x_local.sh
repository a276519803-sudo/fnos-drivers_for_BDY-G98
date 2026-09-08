#!/bin/bash
#=============================================================================
# YT9215S 交换机驱动一键编译脚本（飞牛本地编译版）
# 适配飞牛 FNOS / BDY-G98 / RK3588 / 内核 6.18.x
# 支持内核升级后一键重新编译
#=============================================================================

set -e

#============================= 配置区 ======================================
WORK_DIR="${WORK_DIR:-/tmp/yt921x-build}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/yt921x-output}"
DRIVER_INSTALL_DIR="/lib/modules/$(uname -r)/updates/trim/yt921x"
KERNEL_VERSION="$(uname -r)"

# 驱动源码来源（Linux 6.19-rc1，YT9215S 驱动首次加入的版本）
DRIVER_SOURCE_URL="https://raw.githubusercontent.com/torvalds/linux/v6.19-rc1"
YT921X_C="$DRIVER_SOURCE_URL/drivers/net/dsa/yt921x.c"
YT921X_H="$DRIVER_SOURCE_URL/drivers/net/dsa/yt921x.h"
TAG_YT921X_C="$DRIVER_SOURCE_URL/net/dsa/tag_yt921x.c"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#============================= 函数区 ======================================

print_banner() {
    echo -e "${BLUE}"
    echo "================================================================"
    echo "  YT9215S 交换机驱动一键编译脚本（飞牛本地编译版）"
    echo "  适配: 飞牛 FNOS / BDY-G98 / RK3588 / 内核 6.18.x"
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

#============================= 主流程 ======================================

main() {
    print_banner

    # 步骤1: 检查编译环境
    print_step "1/7" "检查编译环境"
    echo "内核版本: $KERNEL_VERSION"
    echo "架构: $(uname -m)"

    local missing=()
    for tool in gcc make curl; do
        if ! command -v $tool &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ! -d "/lib/modules/$KERNEL_VERSION/build" ]; then
        missing+=("kernel-headers ($KERNEL_VERSION)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "缺少以下依赖: ${missing[*]}"
        echo "请安装: sudo apt install gcc make curl linux-headers-$KERNEL_VERSION"
        exit 1
    fi
    print_info "编译环境检查通过"

    # 步骤2: 准备工作目录
    print_step "2/7" "准备工作目录"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    print_info "工作目录: $WORK_DIR"

    # 步骤3: 下载驱动源码
    print_step "3/7" "下载驱动源码（Linux 6.19-rc1）"
    curl -sL -o yt921x.c "$YT921X_C"
    curl -sL -o yt921x.h "$YT921X_H"
    curl -sL -o tag_yt921x.c "$TAG_YT921X_C"

    if [ ! -s yt921x.c ] || [ ! -s yt921x.h ]; then
        print_error "驱动源码下载失败"
        exit 1
    fi
    echo "  yt921x.c: $(wc -l < yt921x.c) 行"
    echo "  yt921x.h: $(wc -l < yt921x.h) 行"
    echo "  tag_yt921x.c: $(wc -l < tag_yt921x.c) 行"
    print_info "驱动源码下载完成"

    # 步骤4: 创建兼容性补丁
    print_step "4/7" "创建兼容性补丁（适配 6.18 内核）"
    cat > compat.h << 'COMPAT_EOF'
/*
 * YT9215S 驱动兼容性补丁头文件
 * 用于在 6.18 内核上编译 6.19+ 的 YT9215S 驱动
 */
#ifndef __YT921X_COMPAT_H
#define __YT921X_COMPAT_H

#include <linux/if_ether.h>
#include <net/dsa.h>

/* 以太网协议号 - YT921X 专用标签协议 */
#ifndef ETH_P_YT921X
#define ETH_P_YT921X	0x00F9
#endif

/* DSA 标签协议枚举 - YT921X */
#ifndef DSA_TAG_PROTO_YT921X_VALUE
#define DSA_TAG_PROTO_YT921X_VALUE	20
#endif

#ifndef DSA_TAG_PROTO_YT921X
#define DSA_TAG_PROTO_YT921X		DSA_TAG_PROTO_YT921X_VALUE
#endif

/* HSR 相关函数 - 6.18 内核不支持，定义为空 */
#ifndef dsa_port_simple_hsr_leave
#define dsa_port_simple_hsr_leave	NULL
#endif

#ifndef dsa_port_simple_hsr_join
#define dsa_port_simple_hsr_join	NULL
#endif

#endif /* __YT921X_COMPAT_H */
COMPAT_EOF

    # 在源码开头包含 compat.h
    for f in yt921x.c tag_yt921x.c; do
        if ! head -1 "$f" | grep -q "compat.h"; then
            sed -i '1i #include "compat.h"' "$f"
        fi
    done
    print_info "兼容性补丁已创建"

    # 步骤5: 编译 yt921x.ko
    print_step "5/7" "编译 yt921x.ko"
    cat > Makefile << 'MAKEFILE_EOF'
obj-m += yt921x.o

KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean
MAKEFILE_EOF

    make clean 2>/dev/null || true
    make -j$(nproc)

    if [ ! -f yt921x.ko ]; then
        print_error "yt921x.ko 编译失败"
        exit 1
    fi

    local KO_SIZE=$(ls -lh yt921x.ko | awk '{print $5}')
    local KO_VERMAGIC=$(strings yt921x.ko | grep "^vermagic=" | head -1)
    echo "  文件大小: $KO_SIZE"
    echo "  vermagic: $KO_VERMAGIC"
    print_info "yt921x.ko 编译成功"

    # 步骤6: 处理 tag_yt921x.ko
    print_step "6/7" "处理 tag_yt921x.ko"
    # tag_yt921x.ko 需要 DSA 子系统内部头文件，飞牛内核头文件包不包含
    # 因此使用系统中已有的 tag_yt921x.ko（如果存在）
    if [ -f "$DRIVER_INSTALL_DIR/tag_yt921x.ko" ]; then
        cp "$DRIVER_INSTALL_DIR/tag_yt921x.ko" .
        print_info "使用系统已有的 tag_yt921x.ko"
    elif [ -f "/tmp/tag_yt921x.ko.bak" ]; then
        cp /tmp/tag_yt921x.ko.bak ./tag_yt921x.ko
        print_info "使用备份的 tag_yt921x.ko"
    else
        print_warn "未找到 tag_yt921x.ko，标签协议驱动将缺失"
        print_warn "请从有完整内核源码的环境编译 tag_yt921x.ko 后放入 $WORK_DIR"
    fi

    # 步骤7: 安装驱动
    print_step "7/7" "安装驱动"
    mkdir -p "$DRIVER_INSTALL_DIR"
    cp yt921x.ko "$DRIVER_INSTALL_DIR/"
    if [ -f tag_yt921x.ko ]; then
        cp tag_yt921x.ko "$DRIVER_INSTALL_DIR/"
    fi

    # 更新模块依赖
    depmod -a

    # 设置开机自动加载
    mkdir -p /etc/modules-load.d
    cat > /etc/modules-load.d/yt921x.conf << 'MODULES_EOF'
tag_yt921x
yt921x
MODULES_EOF

    # 重新加载驱动
    echo "重新加载驱动..."
    rmmod yt921x 2>/dev/null || true
    rmmod tag_yt921x 2>/dev/null || true
    modprobe tag_yt921x 2>/dev/null || true
    modprobe yt921x 2>/dev/null || true

    # 验证
    sleep 2
    echo ""
    echo -e "${GREEN}=== 验证结果 ===${NC}"
    echo "驱动模块:"
    lsmod | grep yt921 || echo -e "${RED}驱动未加载!${NC}"

    echo ""
    echo "物理网口数量:"
    ip -o link show | grep -v 'lo:\|br-\|docker\|veth' | wc -l

    echo ""
    echo "物理网口列表:"
    ls /sys/class/net/ | grep -E 'end|lan|eth|wan'

    # 整理输出
    mkdir -p "$OUTPUT_DIR"
    cp yt921x.ko "$OUTPUT_DIR/" 2>/dev/null || true
    [ -f tag_yt921x.ko ] && cp tag_yt921x.ko "$OUTPUT_DIR/" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}================================================================"
    echo "  编译安装完成!"
    echo "===============================================================${NC}"
    echo "  内核版本: $KERNEL_VERSION"
    echo "  驱动目录: $DRIVER_INSTALL_DIR"
    echo "  输出目录: $OUTPUT_DIR"
    echo "  开机自启: /etc/modules-load.d/yt921x.conf"
    echo ""
    echo "  注意: tag_yt921x.ko 使用系统已有版本"
    echo "  如需重新编译 tag_yt921x.ko，需要完整内核源码环境"
    echo -e "${GREEN}===============================================================${NC}"
}

main "$@"
