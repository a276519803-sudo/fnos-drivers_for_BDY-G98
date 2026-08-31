#!/bin/bash
# Rockchip RK3588 硬解码驱动一键安装脚本
# 适用于 FNOS / BDY-G98 / RK3588 平台
# 包含: rk_vcodec, rga3, rknpu 及依赖模块
# 使用方法: sudo ./install.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
TARGET_KERNEL=$(uname -r)
INSTALL_PATH="/lib/modules/${TARGET_KERNEL}/updates/trim/rk_vcodec"

# 驱动文件列表
MODULES=(
    "rockchip_sip.ko"
    "rockchip_pvtm.ko"
    "rockchip_opp_select.ko"
    "rockchip_system_monitor.ko"
    "rk_vcodec.ko"
    "rga3.ko"
    "rknpu.ko"
)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Rockchip RK3588 硬解码驱动安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    echo "使用方法: sudo ./install.sh"
    exit 1
fi

# 检查模块文件
echo -e "${YELLOW}[1/7] 检查驱动文件...${NC}"
MISSING=0
for mod in "${MODULES[@]}"; do
    if [ ! -f "${MODULES_DIR}/${mod}" ]; then
        echo -e "${RED}  缺失: ${mod}${NC}"
        MISSING=1
    fi
done
if [ "${MISSING}" -eq 1 ]; then
    echo -e "${RED}错误: 部分驱动文件缺失，请检查 modules 目录${NC}"
    exit 1
fi
echo -e "${GREEN}  全部 ${#MODULES[@]} 个驱动文件检查通过${NC}"

# 检查内核版本并处理 vermagic
echo -e "${YELLOW}[2/7] 检查内核版本...${NC}"
echo "  当前内核: ${TARGET_KERNEL}"

# 检查驱动的 vermagic 是否匹配
SAMPLE_MOD="${MODULES_DIR}/rk_vcodec.ko"
MOD_VERMAGIC=$(/sbin/modinfo "${SAMPLE_MOD}" 2>/dev/null | grep vermagic | awk '{print $2}')
echo "  驱动 vermagic: ${MOD_VERMAGIC}"

if [ "${MOD_VERMAGIC}" != "${TARGET_KERNEL}" ]; then
    echo -e "${YELLOW}  警告: 驱动 vermagic 与当前内核不匹配${NC}"
    echo -e "${YELLOW}  将自动修改 vermagic 以适配当前内核${NC}"
    
    # 备份原始驱动
    BACKUP_DIR="${MODULES_DIR}/backup_${MOD_VERMAGIC}"
    mkdir -p "${BACKUP_DIR}"
    cp "${MODULES_DIR}"/*.ko "${BACKUP_DIR}/" 2>/dev/null || true
    
    # 修改所有驱动的 vermagic
    for mod in "${MODULES[@]}"; do
        sed -i "s/${MOD_VERMAGIC}/${TARGET_KERNEL}/g" "${MODULES_DIR}/${mod}"
    done
    
    # 验证修改
    NEW_VERMAGIC=$(/sbin/modinfo "${SAMPLE_MOD}" 2>/dev/null | grep vermagic | awk '{print $2}')
    echo "  修改后 vermagic: ${NEW_VERMAGIC}"
    
    if [ "${NEW_VERMAGIC}" = "${TARGET_KERNEL}" ]; then
        echo -e "${GREEN}  vermagic 修改成功${NC}"
    else
        echo -e "${RED}  错误: vermagic 修改失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}  vermagic 匹配，无需修改${NC}"
fi

# 安装驱动文件
echo -e "${YELLOW}[3/7] 安装驱动文件...${NC}"
mkdir -p "${INSTALL_PATH}"
cp "${MODULES_DIR}"/*.ko "${INSTALL_PATH}/"
chmod 644 "${INSTALL_PATH}"/*.ko
echo -e "${GREEN}  驱动已安装到: ${INSTALL_PATH}${NC}"
ls -lh "${INSTALL_PATH}/"

# 更新模块依赖
echo -e "${YELLOW}[4/7] 更新模块依赖...${NC}"
depmod -a "${TARGET_KERNEL}" 2>/dev/null || true
echo -e "${GREEN}  模块依赖已更新${NC}"

# 加载驱动模块
echo -e "${YELLOW}[5/7] 加载驱动模块...${NC}"

# 先卸载可能存在的旧模块（按依赖逆序）
modprobe -r rknpu 2>/dev/null || true
modprobe -r rga3 2>/dev/null || true
modprobe -r rk_vcodec 2>/dev/null || true
modprobe -r rockchip_system_monitor 2>/dev/null || true
modprobe -r rockchip_opp_select 2>/dev/null || true
modprobe -r rockchip_sip 2>/dev/null || true
sleep 1

# 按依赖顺序加载
echo "  加载 rockchip_sip..."
modprobe rockchip_sip 2>&1 || echo -e "${YELLOW}    (跳过或已加载)${NC}"

echo "  加载 rockchip_pvtm..."
modprobe rockchip_pvtm 2>&1 || echo -e "${YELLOW}    (跳过或已加载)${NC}"

echo "  加载 rockchip_opp_select..."
modprobe rockchip_opp_select 2>&1 || echo -e "${YELLOW}    (跳过或已加载)${NC}"

echo "  加载 rockchip_system_monitor..."
modprobe rockchip_system_monitor 2>&1 || echo -e "${YELLOW}    (跳过或已加载)${NC}"

echo "  加载 rk_vcodec..."
modprobe rk_vcodec 2>&1 || echo -e "${RED}    (加载失败)${NC}"

echo "  加载 rga3..."
modprobe rga3 2>&1 || echo -e "${YELLOW}    (跳过或已加载)${NC}"

echo "  加载 rknpu..."
modprobe rknpu 2>&1 || echo -e "${YELLOW}    (跳过或已加载)${NC}"

sleep 2

# 验证驱动加载
echo -e "${YELLOW}[6/7] 验证驱动加载...${NC}"
echo ""
echo "已加载模块:"
lsmod | grep -iE 'rk_vcodec|rga3|rknpu|rockchip_' || echo -e "${YELLOW}  (无匹配模块)${NC}"

echo ""
echo "设备节点:"
ls -la /dev/mpp_service 2>&1 || echo -e "${RED}  /dev/mpp_service 不存在${NC}"

# 验证硬解码支持
echo -e "${YELLOW}[7/7] 验证硬解码支持...${NC}"
echo ""

# 检查 mediasrv ffmpeg
FFMPEG_PATH="/usr/trim/lib/mediasrv/ffmpeg"
if [ -f "${FFMPEG_PATH}" ]; then
    echo "mediasrv ffmpeg 硬件加速方法:"
    "${FFMPEG_PATH}" -hwaccels 2>&1 | grep -iE 'rkmpp|v4l2|drm' || echo -e "${YELLOW}  (未检测到 rkmpp)${NC}"
else
    echo -e "${YELLOW}  未找到 mediasrv ffmpeg (${FFMPEG_PATH})${NC}"
fi

# 检查 MPP 库
echo ""
echo "MPP 库:"
ls -la /usr/trim/lib/mediasrv/lib/librockchip_mpp* 2>&1 || echo -e "${YELLOW}  (未找到 librockchip_mpp)${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "驱动说明:"
echo "  rk_vcodec  - Rockchip MPP 视频编解码服务驱动"
echo "  rga3       - RGA 2D 图形加速驱动"
echo "  rknpu      - NPU 神经网络加速驱动"
echo "  rockchip_* - Rockchip 平台依赖模块"
echo ""
echo "常用命令:"
echo "  查看驱动:   lsmod | grep -iE 'rk_vcodec|rga|npu'"
echo "  查看设备:   ls -la /dev/mpp_service"
echo "  重新加载:   sudo modprobe -r rk_vcodec && sudo modprobe rk_vcodec"
echo "  查看日志:   dmesg | grep -iE 'rk_vcodec|mpp|rga'"
echo ""
echo -e "${YELLOW}注意事项:${NC}"
echo "  1. 如硬解码仍不工作，请重启系统确保驱动完整加载"
echo "  2. mediasrv 服务可能需要重启: sudo systemctl restart mediasrv"
echo "  3. 如升级内核后驱动失效，重新运行此脚本即可"
echo "  4. 详细说明请参考 README.md"
echo ""
