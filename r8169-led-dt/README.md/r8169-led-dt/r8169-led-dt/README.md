# r8169 RTL8125 LED 设备树补丁（BDY-G98 / 飞牛 FNOS）

## 概述

通过修改 r8169 驱动源码，添加 `realtek,led-mode` 设备树属性支持，实现内核态直接控制 RTL8125 2.5G 网口 LED，替代用户空间脚本。

## 原理

- r8169 驱动已有 LED 控制框架（`r8169_leds.c`），支持 4 个 LED 的 sysfs 接口
- 但驱动初始化时不设置默认 LED 模式，导致 LED 不亮
- 本补丁在 `rtl8125_init_leds()` 中添加设备树属性读取，probe 时自动配置 LED 模式
- 属性值 `0x200` 启用 LED 数据活动指示（与原用户空间脚本效果一致）

## 文件说明

| 文件 | 说明 |
|------|------|
| `build_and_deploy.sh` | 一键编译部署脚本（系统升级后使用） |
| `fix_dtb_led_mode.sh` | DTB 修复脚本（将 led-data 改为 led-mode） |
| `../r8169-upstream-patch/` | 上游提交材料（正式补丁 + 绑定文档） |

## 当前状态（已部署）

- ✅ 带补丁的 r8169 驱动已安装
- ✅ DTB 已配置 `realtek,led-mode = <0x200 0x0 0x0 0x0>`
- ✅ 用户空间 `rtl8125-led-fix.service` 已禁用
- ✅ LED 正常亮起，2.5G 协商正常

## 系统升级后操作

每次飞牛系统升级后，内核版本变化，需要重新编译部署：

```bash
# 1. 编译并安装带补丁的 r8169 驱动
sudo bash build_and_deploy.sh

# 2. 如果 DTB 被升级覆盖，修复 DTB 属性
sudo bash fix_dtb_led_mode.sh
sudo reboot
```

## 设备树配置

在 DTS 的 RTL8125 PCIe 节点下添加：

```dts
ethernet@0 {
    compatible = "pci10ec,8125";
    reg = <0x0000 0 0 0 0>;
    realtek,led-mode = <0x200 0x0 0x0 0x0>;
};
```

## LED 模式值说明

每个值对应一个 LED（LED0-LED3），有效位掩码 `0x23f`：

| 值 | 说明 |
|----|------|
| `0x200` | 启用数据活动指示（推荐） |
| `0x0` | 保持硬件默认 |

## 回滚方案

如驱动异常，恢复用户空间脚本方案：

```bash
# 恢复原驱动
sudo cp /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/realtek/r8169.ko.bak.* \
        /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/realtek/r8169.ko
sudo modprobe -r r8169 && sudo modprobe r8169

# 重新启用用户空间脚本
sudo systemctl enable --now rtl8125-led-fix.service
```

## 上游提交

补丁已整理为上游提交格式，详见 `../r8169-upstream-patch/` 目录。
