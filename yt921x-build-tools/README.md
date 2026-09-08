# YT9215S 交换机驱动编译与部署工具（飞牛本地版）

## 概述

本工具用于在飞牛 FNOS 系统（BDY-G98 / RK3588）上编译和部署 YT9215S 交换机驱动，支持内核升级后一键重新编译或部署完整版驱动。

**适用环境**：飞牛 FNOS / BDY-G98 / RK3588 / 内核 6.18.x / arm64

## 鸣谢

完整版驱动由 [大雕 (coolsnowwolf)](https://github.com/coolsnowwolf) 编译维护，包含硬件流卸载等高级功能。本仓库仅提供部署脚本和使用说明，驱动版权归原作者所有。

## 文件说明

| 文件 | 说明 |
|------|------|
| `build_yt921x_local.sh` | 从源码编译驱动（基础功能版） |
| `deploy_full_yt921x.sh` | 部署大雕完整版驱动（推荐，含高级功能） |
| `README.md` | 本说明文档 |

## 两种方案对比

| 特性 | 源码编译版 | 大雕完整版（推荐） |
|------|-----------|------------------|
| 驱动大小 | ~995 KB | ~1.27 MB |
| 依赖符号 | 32 个 | 59 个 |
| 基本交换 | ✅ | ✅ |
| VLAN 支持 | ✅ | ✅ |
| 硬件流卸载（TC flower） | ❌ | ✅ |
| QoS/DSCP 映射 | ❌ | ✅ |
| DSA 高级功能 | ❌ | ✅ |
| 需要编译环境 | 是 | 否（直接使用二进制） |
| 适用场景 | 无旧内核驱动时 | 系统升级后有旧内核驱动时 |

**推荐使用大雕完整版**，只需系统中保留了旧版本内核的驱动文件即可。

## 使用方法

### 快速开始（推荐：大雕完整版）

```bash
# 1. 上传脚本到飞牛
scp deploy_full_yt921x.sh user@飞牛IP:/tmp/

# 2. SSH 登录飞牛
ssh user@飞牛IP

# 3. 执行脚本（需要 root 权限）
sudo bash /tmp/deploy_full_yt921x.sh
```

如果旧内核版本不是默认的 `6.18.18.c951-trim`，通过环境变量指定：
```bash
sudo OFFICIAL_KERNEL=6.18.18.cXXX-trim bash /tmp/deploy_full_yt921x.sh
```

### 备选：源码编译版

当系统中没有旧内核驱动时，使用源码编译：

```bash
sudo bash /tmp/build_yt921x_local.sh
```

### 脚本执行流程（大雕完整版）

1. **检查驱动源文件** - 验证旧内核目录中的驱动文件
2. **验证 Tag EtherType** - 确认驱动使用 0x9988（与硬件默认值匹配）
3. **准备工作目录** - 复制驱动文件
4. **修改 vermagic** - 适配当前内核版本
5. **备份当前驱动** - 备份到带时间戳的目录
6. **安装驱动** - 复制到模块目录，更新依赖，设置开机自启
7. **重新加载并验证** - 检查模块加载和网口数量

### 验证安装

```bash
# 查看驱动是否加载
lsmod | grep yt921

# 查看网口数量（正常应为 12 个：end0-end3 + lan1-lan8）
ip -o link show | grep -vE 'lo:|br-|docker|veth' | wc -l

# 查看高级功能符号（完整版应为59个依赖）
nm -u /lib/modules/$(uname -r)/updates/trim/yt921x/yt921x.ko | wc -l
```

## 内核升级后重新部署

当飞牛系统升级内核后，只需重新运行脚本：

```bash
# 推荐：大雕完整版
sudo bash /tmp/deploy_full_yt921x.sh

# 或源码编译版
sudo bash /tmp/build_yt921x_local.sh
```

脚本会自动检测新内核版本并部署适配的驱动。

## 重要：Tag EtherType 0x9988

飞牛设备使用的 YT9215S 交换机芯片，其 CPU_TAG_TPID 寄存器默认值为 **0x9988**（定义见 `YT921X_CPU_TAG_TPID_TPID_DEFAULT`）。

Linux 主线驱动定义的 `ETH_P_YT921X` 为 0x00F9，与硬件默认值不匹配，会导致 probe 失败：
```
yt921x stmmac-0:1d: Tag type 0x9988 != 0xf9
yt921x stmmac-0:1d: probe with driver yt921x failed with error -22
```

大雕完整版驱动已适配 0x9988，可直接使用。源码编译版也已强制将 `ETH_P_YT921X` 替换为 0x9988。

## 注意事项

### 关于 tag_yt921x.ko

`tag_yt921x.ko`（标签协议驱动）需要 DSA 子系统的内部头文件，飞牛的内核头文件包不包含这些内部文件。大雕完整版部署脚本会直接从旧内核目录复制已编译好的 `tag_yt921x.ko`。

### 编译依赖（源码编译版需要）

- gcc
- make
- curl
- 内核头文件（`linux-headers-$(uname -r)`）

### 驱动文件位置

- 安装目录：`/lib/modules/$(uname -r)/updates/trim/yt921x/`
- 开机自启配置：`/etc/modules-load.d/yt921x.conf`

## 常见问题

**Q: 大雕完整版驱动找不到旧内核文件？**
A: 系统升级后通常会保留旧内核模块。可用 `ls /lib/modules/` 查看所有内核版本，通过 `OFFICIAL_KERNEL` 环境变量指定。

**Q: 驱动加载后网口数量不对？**
A: 正常应为 12 个物理网口（end0-end3 + lan1-lan8）。如数量不对，检查驱动是否正确加载：`lsmod | grep yt921`

**Q: 重启后驱动丢失？**
A: 脚本已设置开机自动加载（`/etc/modules-load.d/yt921x.conf`）。如未生效，手动执行：`sudo modprobe yt921x`

## 版本历史

- **v1.0.2**：初始飞牛本地编译版，ETH_P_YT921X = 0x00F9
- **v1.0.3**：修复 Tag EtherType 为 0x9988，解决升级后交换机 probe 失败问题
- **v1.0.4**：新增大雕完整版驱动部署脚本 `deploy_full_yt921x.sh`，支持硬件流卸载、QoS、DSA 高级功能；鸣谢原作者 coolsnowwolf
