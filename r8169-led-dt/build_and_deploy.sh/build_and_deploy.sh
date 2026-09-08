#!/bin/bash
# r8169 RTL8125 LED 设备树补丁 - 一键编译部署脚本
# 适用于飞牛 FNOS (BDY-G98) 系统升级后重新编译部署
#
# 使用方法:
#   sudo bash build_and_deploy.sh
#
# 功能:
#   1. 下载匹配内核版本的 r8169 驱动源码
#   2. 应用 realtek,led-mode 设备树补丁
#   3. 编译并安装驱动
#   4. 禁用用户空间 LED 脚本
#   5. 重新加载驱动

set -e

WORK_DIR="/tmp/r8169-led-build"
KERNEL_VERSION="$(uname -r)"
KERNEL_MAJOR="$(echo $KERNEL_VERSION | cut -d. -f1)"
KERNEL_MINOR="$(echo $KERNEL_VERSION | cut -d. -f2)"
DRIVER_PATH="/lib/modules/$KERNEL_VERSION/kernel/drivers/net/ethernet/realtek/r8169.ko"
LED_SERVICE="rtl8125-led-fix.service"

echo "=========================================="
echo " r8169 RTL8125 LED 设备树补丁部署工具"
echo "=========================================="
echo "内核版本: $KERNEL_VERSION"
echo "驱动路径: $DRIVER_PATH"
echo ""

# 检查 root
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行"
    exit 1
fi

# 检查编译环境
if ! command -v gcc &> /dev/null; then
    echo "错误: 未安装 gcc，请先安装 build-essential"
    exit 1
fi

if [ ! -d "/lib/modules/$KERNEL_VERSION/build" ]; then
    echo "错误: 未找到内核头文件 /lib/modules/$KERNEL_VERSION/build"
    exit 1
fi

echo "=== 1. 准备工作目录 ==="
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo ""
echo "=== 2. 下载 r8169 驱动源码 (Linux v${KERNEL_MAJOR}.${KERNEL_MINOR}) ==="
BASE_URL="https://raw.githubusercontent.com/torvalds/linux/v${KERNEL_MAJOR}.${KERNEL_MINOR}/drivers/net/ethernet/realtek"
for f in r8169_main.c r8169_leds.c r8169_firmware.c r8169_phy_config.c r8169.h r8169_firmware.h; do
    curl -sL -o "$f" "$BASE_URL/$f"
    if [ ! -s "$f" ] || [ "$(wc -l < "$f")" -lt 10 ]; then
        echo "错误: 下载 $f 失败"
        exit 1
    fi
    echo "  $f: $(wc -l < $f) 行"
done

echo ""
echo "=== 3. 应用 LED 设备树补丁 ==="
python3 << 'PYEOF'
with open('r8169_leds.c', 'r') as f:
    content = f.read()

# 添加头文件
if '#include <linux/property.h>' not in content:
    content = content.replace(
        '#include <linux/netdevice.h>',
        '#include <linux/netdevice.h>\n#include <linux/property.h>'
    )

# 定义新函数
new_func = '''
static void rtl8125_apply_led_default_mode(struct net_device *ndev)
{
	struct rtl8169_private *tp = netdev_priv(ndev);
	u32 modes[RTL8125_NUM_LEDS];
	int nval, i;

	nval = device_property_read_u32_array(&ndev->dev,
					      "realtek,led-mode",
					      modes, RTL8125_NUM_LEDS);
	if (nval == -ENODATA)
		return;

	if (nval < 0 && nval != -EOVERFLOW)
		return;

	if (nval == -EOVERFLOW)
		nval = RTL8125_NUM_LEDS;

	for (i = 0; i < nval; i++)
		rtl8125_set_led_mode(tp, i, modes[i]);
}

'''

old_func_sig = 'struct r8169_led_classdev *rtl8125_init_leds(struct net_device *ndev)'
if 'rtl8125_apply_led_default_mode' not in content:
    content = content.replace(old_func_sig, new_func + old_func_sig, 1)

if 'rtl8125_apply_led_default_mode(ndev);' not in content:
    content = content.replace(
        '\tfor (i = 0; i < RTL8125_NUM_LEDS; i++)\n\t\trtl8125_setup_led_ldev(leds + i, ndev, i);\n\n\treturn leds;',
        '\tfor (i = 0; i < RTL8125_NUM_LEDS; i++)\n\t\trtl8125_setup_led_ldev(leds + i, ndev, i);\n\n\trtl8125_apply_led_default_mode(ndev);\n\n\treturn leds;',
        1
    )

with open('r8169_leds.c', 'w') as f:
    f.write(content)
print("补丁应用成功")
PYEOF

echo ""
echo "=== 4. 编译 ==="
cat > Makefile << 'MAKEFILE_EOF'
obj-m += r8169.o
r8169-objs := r8169_main.o r8169_leds.o r8169_firmware.o r8169_phy_config.o

KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean
MAKEFILE_EOF

make -j$(nproc) 2>&1 | tail -5

if [ ! -f r8169.ko ]; then
    echo "编译失败！"
    exit 1
fi

echo "编译成功: $(stat -c%s r8169.ko) 字节"

echo ""
echo "=== 5. 备份原驱动 ==="
cp "$DRIVER_PATH" "$DRIVER_PATH.bak.$(date +%Y%m%d%H%M%S)"
echo "备份完成"

echo ""
echo "=== 6. 安装新驱动 ==="
cp r8169.ko "$DRIVER_PATH"
depmod -a 2>/dev/null || true
echo "驱动已安装"

echo ""
echo "=== 7. 禁用用户空间 LED 脚本 ==="
if systemctl is-enabled "$LED_SERVICE" &>/dev/null; then
    systemctl stop "$LED_SERVICE"
    systemctl disable "$LED_SERVICE"
    echo "用户空间脚本已停止并禁用"
else
    echo "用户空间脚本未启用，跳过"
fi

echo ""
echo "=== 8. 重新加载驱动 ==="
rmmod r8169 2>/dev/null || true
sleep 2
modprobe r8169
sleep 3

echo ""
echo "=== 9. 验证 ==="
echo "r8169 模块:"
lsmod | grep r8169

echo ""
echo "end3 速率:"
cat /sys/class/net/end3/speed 2>/dev/null || echo "N/A"

echo ""
echo "LED sysfs 设备:"
ls /sys/class/leds/enP* 2>/dev/null | wc -l
echo "个 LED 设备"

echo ""
echo "=========================================="
echo " 部署完成！"
echo "=========================================="
echo ""
echo "注意事项:"
echo "  1. 确保 DTB 中已配置 realtek,led-mode 属性"
echo "  2. 如 DTB 中仍是 realtek,led-data，请运行 fix_dtb_led_mode.sh"
echo "  3. 如驱动异常，恢复原驱动:"
echo "     sudo cp $DRIVER_PATH.bak.* $DRIVER_PATH"
echo "     sudo modprobe -r r8169 && sudo modprobe r8169"
echo "     sudo systemctl enable --now $LED_SERVICE"
