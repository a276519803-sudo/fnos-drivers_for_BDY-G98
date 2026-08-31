# FNOS Drivers for BDY-G98 / RK3588

飞牛 FNOS 系统驱动修复工具集合，适用于 BDY-G98（Rockchip RK3588）平台。

## 项目目录

| 文件夹 | 项目 | 简要说明 |
|--------|------|----------|
| [`yt921x-switch-driver/`](./yt921x-switch-driver) | YT9215S 交换机驱动 | 修复系统升级后交换机 8 个网口无法识别问题，提供预编译的 `yt921x.ko` 和 `tag_yt921x.ko` 内核模块 |
| [`rtl8125-led-fix/`](./rtl8125-led-fix) | RTL8125 LED 修复 | 修复 Realtek RTL8125 2.5G 网卡网口指示灯不亮问题，通过 Python 脚本操作寄存器开启 LED，systemd 服务开机自启 |
| [`rk3588-hardware-decode/`](./rk3588-hardware-decode) | RK3588 硬解码驱动 | 修复硬件视频编解码异常问题，包含 `rk_vcodec`、`rga3`、`rknpu` 及依赖模块，恢复 `/dev/mpp_service` 设备节点和 ffmpeg rkmpp 硬件加速 |
| [`yt921x-build-tools/`](./yt921x-build-tools) | YT9215S 编译工具 | 一键编译脚本，在 x86_64 交叉编译环境中编译 YT9215S 驱动，支持内核升级后自动检测版本并重新编译 |

## 下载

预编译驱动包和编译工具请前往 [Releases](https://github.com/a276519803-sudo/fnos-drivers_for_BDY-G98/releases) 页面下载。

## 适用环境

- 芯片平台：Rockchip RK3588 / RK3588S
- 设备：BDY-G98、飞牛 FNOS 设备
- 系统：飞牛 FNOS（Linux）
- 架构：arm64 / aarch64

## 说明

- 各项目详细使用方法请点击对应文件夹查看 `README.md`
- 文档中所有 IP 地址、用户名均为示例占位符，使用前请替换为实际信息
- 本仓库主页仅作项目索引，详细更新记录见各项目目录及 Releases 页面
