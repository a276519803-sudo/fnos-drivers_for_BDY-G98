# YT9215S 交换机驱动一键编译工具（飞牛本地编译版）

## 概述

本工具用于在飞牛 FNOS 系统（BDY-G98 / RK3588）上本地编译 YT9215S 交换机驱动，支持内核升级后一键重新编译。

**适用环境**：飞牛 FNOS / BDY-G98 / RK3588 / 内核 6.18.x / arm64

## 工作原理

1. 从 Linux 6.19-rc1 下载 YT9215S 驱动源码（驱动首次加入的版本）
2. 自动应用兼容性补丁，适配飞牛 6.18 内核
3. 使用飞牛本地 gcc + 内核头文件编译 `yt921x.ko`
4. `tag_yt921x.ko` 使用系统已有版本（该模块需要 DSA 内部头文件，飞牛内核头文件包不包含）
5. 自动安装驱动并设置开机自启

## 文件说明

| 文件 | 说明 |
|------|------|
| `build_yt921x_local.sh` | 一键编译安装脚本 |
| `README.md` | 本说明文档 |

## 使用方法

### 快速开始

```bash
# 1. 上传脚本到飞牛
scp build_yt921x_local.sh user@飞牛IP:/tmp/

# 2. SSH 登录飞牛
ssh user@飞牛IP

# 3. 执行脚本（需要 root 权限）
sudo bash /tmp/build_yt921x_local.sh
```

### 脚本执行流程

1. **检查编译环境** - 验证 gcc、make、curl、内核头文件
2. **准备工作目录** - 创建 `/tmp/yt921x-build`
3. **下载驱动源码** - 从 Linux 6.19-rc1 下载 yt921x.c、yt921x.h、tag_yt921x.c
4. **创建兼容性补丁** - 生成 `compat.h`，定义 6.18 内核缺失的常量
5. **编译 yt921x.ko** - 使用本地 gcc + 内核头文件编译
6. **处理 tag_yt921x.ko** - 使用系统已有版本
7. **安装驱动** - 复制到 `/lib/modules/$(uname -r)/updates/trim/yt921x/`，更新模块依赖，设置开机自启

### 验证安装

```bash
# 查看驱动是否加载
lsmod | grep yt921

# 查看网口数量（正常应为 12 个：end0-end3 + lan1-lan8）
ip -o link show | grep -v 'lo:\|br-\|docker\|veth' | wc -l

# 查看网口列表
ls /sys/class/net/ | grep -E 'end|lan'
```

预期输出：
```
yt921x                 57344  8
tag_yt921x             12288  2
dsa_core              147456  2 yt921x,tag_yt921x
```

## 内核升级后重新编译

当飞牛系统升级内核后，只需重新运行脚本：

```bash
sudo bash /tmp/build_yt921x_local.sh
```

脚本会自动检测新内核版本并编译适配的驱动。

## 注意事项

### 关于 tag_yt921x.ko

`tag_yt921x.ko`（标签协议驱动）需要 DSA 子系统的内部头文件（`tag.h`、`port.h`、`user.h` 等），而飞牛的内核头文件包不包含这些内部文件。因此：

- 脚本会使用系统中已有的 `tag_yt921x.ko`
- 如果系统中没有该文件，需要从有完整内核源码的环境编译
- 一般情况下，`tag_yt921x.ko` 跨小版本内核兼容（如 6.18.18 → 6.18.20）

### 编译依赖

脚本需要以下工具，飞牛系统通常已预装：
- gcc
- make
- curl
- 内核头文件（`linux-headers-$(uname -r)`）

如缺少，可执行：
```bash
sudo apt install gcc make curl linux-headers-$(uname -r)
```

### 驱动文件位置

- 安装目录：`/lib/modules/$(uname -r)/updates/trim/yt921x/`
- 开机自启配置：`/etc/modules-load.d/yt921x.conf`
- 编译输出：`/tmp/yt921x-output/`

## 常见问题

**Q: 编译失败，提示缺少头文件？**
A: 请确认内核头文件已安装：`sudo apt install linux-headers-$(uname -r)`

**Q: 驱动加载后网口数量不对？**
A: 正常应为 12 个物理网口（end0-end3 + lan1-lan8）。如数量不对，检查驱动是否正确加载：`lsmod | grep yt921`

**Q: 重启后驱动丢失？**
A: 脚本已设置开机自动加载（`/etc/modules-load.d/yt921x.conf`）。如未生效，手动执行：`sudo modprobe yt921x`

**Q: tag_yt921x.ko 版本不匹配？**
A: 从有完整内核源码的环境重新编译 tag_yt921x.ko，替换到 `/lib/modules/$(uname -r)/updates/trim/yt921x/` 目录

## 技术细节

- 驱动源码来源：Linux 6.19-rc1（YT9215S 驱动首次合入主线的版本）
- 兼容性补丁：定义 `ETH_P_YT921X`、`DSA_TAG_PROTO_YT921X` 等 6.18 内核缺失的常量
- 编译器版本：gcc 12.2.0（与内核编译版本一致）
- vermagic：自动匹配当前内核版本
