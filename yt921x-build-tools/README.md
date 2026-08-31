# YT9215S 交换机驱动编译与安装指南

> 适用于飞牛 FNOS / BDY-G98 / RK3588 平台  
> 支持内核升级后一键重新编译

---

## 目录

1. [概述](#1-概述)
2. [驱动说明](#2-驱动说明)
3. [编译环境准备](#3-编译环境准备)
4. [一键编译脚本使用](#4-一键编译脚本使用)
5. [手动编译步骤](#5-手动编译步骤)
6. [安装方法](#6-安装方法)
7. [验证方法](#7-验证方法)
8. [内核升级后重新编译](#8-内核升级后重新编译)
9. [故障排除](#9-故障排除)
10. [常见问题](#10-常见问题)

---

## 1. 概述

### 1.1 背景

BDY-G98 设备采用 Rockchip RK3588 处理器，配备两颗 Motorcomm YT9215S 千兆以太网交换机芯片，提供 12 个网口（4 个 CPU 直连 + 8 个交换机扩展）。

飞牛 FNOS 系统升级后，可能出现交换机驱动未编译或版本不匹配，导致仅识别 4 个网口的问题。本文档提供完整的驱动编译和安装方法。

### 1.2 适用场景

- 系统升级后交换机 8 个网口无法识别
- 内核版本变更后需要重新编译驱动
- 自定义内核需要集成 YT9215S 驱动
- 驱动模块丢失或损坏需要重新编译

---

## 2. 驱动说明

### 2.1 驱动组成

YT9215S 驱动由两个内核模块组成：

| 模块 | 源码路径 | 说明 |
|------|----------|------|
| `yt921x.ko` | `drivers/net/dsa/yt921x.c` | DSA 交换机主驱动，负责硬件初始化和端口管理 |
| `tag_yt921x.ko` | `net/dsa/tag_yt921x.c` | 标签协议驱动，负责 DSA 帧标签的添加和移除 |

**两个模块必须同时编译和加载**，缺一不可。

### 2.2 内核配置项

| 配置项 | 说明 | 推荐值 |
|--------|------|--------|
| `CONFIG_NET_DSA` | Distributed Switch Architecture 支持 | `y` 或 `m` |
| `CONFIG_NET_DSA_YT921X` | Motorcomm YT9215S 交换机驱动 | `m`（模块） |
| `CONFIG_NET_DSA_TAG_YT921X` | YT921X 标签协议 | `m`（模块） |

### 2.3 硬件信息

- **芯片型号**: Motorcomm YT9215S
- **端口数量**: 每颗 8 口，BDY-G98 共 2 颗 = 16 口（实际使用 12 口）
- **接口类型**: RGMII（与 CPU 连接）
- **最大速率**: 10/100/1000 Mbps 自适应

---

## 3. 编译环境准备

### 3.1 编译服务器要求

推荐使用 Ubuntu 20.04 / 22.04 / 24.04 x86_64 系统进行交叉编译。

**硬件要求**:
- CPU: 4 核以上（编译速度更快）
- 内存: 4GB 以上
- 磁盘: 20GB 以上空闲空间（内核源码约 2-5GB）

### 3.2 安装依赖

```bash
sudo apt update
sudo apt install -y \
    gcc-aarch64-linux-gnu \
    build-essential \
    libssl-dev \
    libelf-dev \
    bison \
    flex \
    bc \
    kmod \
    cpio \
    python3 \
    git \
    wget
```

### 3.3 验证交叉编译器

```bash
aarch64-linux-gnu-gcc --version
# 预期输出:
# aarch64-linux-gnu-gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
```

### 3.4 获取内核源码

#### 方法一：从 GitHub 克隆（推荐）

```bash
cd ~
git clone --depth=1 -b linux-6.18.y-rockchip \
    https://github.com/radxa/kernel.git kernel
```

#### 方法二：从飞牛设备获取配置

```bash
# 在目标设备上导出内核配置
ssh jun@192.168.100.107
zcat /proc/config.gz > /tmp/kernel.config
# 或
cp /boot/config-$(uname -r) /tmp/kernel.config

# 下载到编译服务器
scp jun@192.168.100.107:/tmp/kernel.config ~/kernel/.config
```

---

## 4. 一键编译脚本使用

### 4.1 脚本特性

`build_yt921x.sh` 一键编译脚本提供以下功能：

- ✅ 自动检查和安装编译依赖
- ✅ 自动从目标设备检测内核版本
- ✅ 自动准备内核源码和配置
- ✅ 自动启用 YT9215S 驱动配置
- ✅ 自动编译两个驱动模块
- ✅ 自动修正 vermagic（适配目标内核）
- ✅ 自动生成安装脚本和版本信息
- ✅ 可选上传到目标设备

### 4.2 快速开始

```bash
# 1. 赋予执行权限
chmod +x build_yt921x.sh

# 2. 执行编译（使用默认配置）
./build_yt921x.sh
```

### 4.3 命令行参数

```bash
./build_yt921x.sh [选项]

选项:
  --kernel-dir DIR     内核源码目录 (默认: ~/kernel)
  --output-dir DIR     输出目录 (默认: ~/yt921x-output)
  --target-ip IP       目标设备 IP (默认: 192.168.100.107)
  --kernel-version VER 手动指定目标内核版本
  --cross-compile PRE  交叉编译器前缀 (默认: aarch64-linux-gnu-)
  -h, --help           显示帮助
```

### 4.4 环境变量

也可以通过环境变量配置：

```bash
export KERNEL_DIR=~/my-kernel
export OUTPUT_DIR=~/my-output
export TARGET_IP=192.168.1.100
export TARGET_USER=root
export KERNEL_VERSION=6.18.18.c963-trim
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

./build_yt921x.sh
```

### 4.5 使用示例

#### 示例 1：默认编译（自动检测目标设备）

```bash
./build_yt921x.sh
```

#### 示例 2：指定内核版本（设备不可达时）

```bash
./build_yt921x.sh --kernel-version 6.18.18.c963-trim
```

#### 示例 3：指定内核源码目录

```bash
./build_yt921x.sh --kernel-dir /opt/linux-6.18
```

#### 示例 4：指定目标设备 IP

```bash
./build_yt921x.sh --target-ip 192.168.1.100
```

#### 示例 5：完整自定义

```bash
./build_yt921x.sh \
    --kernel-dir ~/custom-kernel \
    --output-dir ~/yt921x-v2 \
    --target-ip 192.168.1.100 \
    --kernel-version 6.18.18.c999-trim
```

### 4.6 编译输出

编译完成后，输出目录包含以下文件：

```
~/yt921x-output/
├── yt921x.ko       # DSA 交换机主驱动
├── tag_yt921x.ko   # 标签协议驱动
├── install.sh       # 一键安装脚本
└── version.txt      # 版本信息
```

---

## 5. 手动编译步骤

如果需要手动控制编译过程，可以按以下步骤操作。

### 5.1 设置环境变量

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
cd ~/kernel
```

### 5.2 配置内核

```bash
# 使用设备配置（如果已获取）
cp /tmp/kernel.config .config
make olddefconfig

# 或使用默认配置
make defconfig

# 启用 YT9215S 驱动
scripts/config --enable CONFIG_NET_DSA
scripts/config --module CONFIG_NET_DSA_YT921X
scripts/config --module CONFIG_NET_DSA_TAG_YT921X
make olddefconfig

# 验证配置
grep YT921X .config
# 预期输出:
# CONFIG_NET_DSA_YT921X=m
# CONFIG_NET_DSA_TAG_YT921X=m
```

### 5.3 准备模块编译环境

```bash
make modules_prepare -j$(nproc)
```

### 5.4 编译驱动模块

```bash
# 编译主驱动
make drivers/net/dsa/yt921x.ko -j$(nproc)

# 编译标签协议
make net/dsa/tag_yt921x.ko -j$(nproc)
```

### 5.5 验证编译产物

```bash
ls -lh drivers/net/dsa/yt921x.ko net/dsa/tag_yt921x.ko

# 查看 vermagic
modinfo drivers/net/dsa/yt921x.ko | grep vermagic
modinfo net/dsa/tag_yt921x.ko | grep vermagic
```

### 5.6 修正 vermagic（如需要）

如果编译产物的 vermagic 与目标内核不匹配：

```bash
# 目标内核版本
TARGET_KERNEL=6.18.18.c963-trim

# 当前 vermagic
CURRENT_VERMAGIC=$(modinfo drivers/net/dsa/yt921x.ko | grep vermagic | awk '{print $2}')

# 二进制替换
sed -i "s/$CURRENT_VERMAGIC/$TARGET_KERNEL/g" drivers/net/dsa/yt921x.ko
sed -i "s/$CURRENT_VERMAGIC/$TARGET_KERNEL/g" net/dsa/tag_yt921x.ko

# 验证
modinfo drivers/net/dsa/yt921x.ko | grep vermagic
```

---

## 6. 安装方法

### 6.1 一键安装（推荐）

使用编译脚本生成的 `install.sh`：

```bash
# 1. 上传到目标设备
scp -r ~/yt921x-output jun@192.168.100.107:/tmp/

# 2. 登录设备
ssh jun@192.168.100.107

# 3. 执行安装
cd /tmp/yt921x-output
sudo ./install.sh
```

安装脚本会自动完成：
- 创建驱动目录
- 复制驱动文件
- 修正 vermagic（如需要）
- 更新模块依赖
- 加载驱动模块
- 设置开机自动加载
- 验证安装结果

### 6.2 手动安装

```bash
# 1. 上传驱动文件
scp yt921x.ko tag_yt921x.ko jun@192.168.100.107:/tmp/

# 2. 登录设备
ssh jun@192.168.100.107
sudo -i

# 3. 创建驱动目录
KERNEL_VERSION=$(uname -r)
mkdir -p /lib/modules/$KERNEL_VERSION/updates/trim/yt921x

# 4. 复制驱动
cp /tmp/yt921x.ko /lib/modules/$KERNEL_VERSION/updates/trim/yt921x/
cp /tmp/tag_yt921x.ko /lib/modules/$KERNEL_VERSION/updates/trim/yt921x/

# 5. 修正 vermagic（如需要）
CURRENT_VERMAGIC=$(modinfo /lib/modules/$KERNEL_VERSION/updates/trim/yt921x/yt921x.ko | grep vermagic | awk '{print $2}')
if [ "$CURRENT_VERMAGIC" != "$KERNEL_VERSION" ]; then
    sed -i "s/$CURRENT_VERMAGIC/$KERNEL_VERSION/g" /lib/modules/$KERNEL_VERSION/updates/trim/yt921x/*.ko
fi

# 6. 更新模块依赖
depmod -a

# 7. 加载驱动（注意顺序）
modprobe tag_yt921x
modprobe yt921x

# 8. 设置开机自动加载
echo "tag_yt921x" > /etc/modules-load.d/yt921x.conf
echo "yt921x" >> /etc/modules-load.d/yt921x.conf
```

---

## 7. 验证方法

### 7.1 检查驱动模块

```bash
lsmod | grep yt921
```

**预期输出**:
```
yt921x                32768  0
tag_yt921x            16384  1 yt921x
```

### 7.2 检查网口数量

```bash
# 统计网口数量（排除 lo）
ip -o link show | grep -v 'lo:' | wc -l
# 预期输出: 12

# 列出所有网口
ls /sys/class/net/ | grep -v lo
```

**预期输出**（12 个网口）:
```
eth0
eth1
eth2
eth3
lan1
lan2
lan3
lan4
lan5
lan6
lan7
lan8
```

### 7.3 检查驱动日志

```bash
dmesg | grep -i yt921
```

**预期输出**:
```
[    2.345678] yt921x 0-005c: YT9215S switch detected
[    2.345789] yt921x 0-005c: 8 ports detected
[    2.456789] yt921x 1-005c: YT9215S switch detected
[    2.456890] yt921x 1-005c: 8 ports detected
```

### 7.4 检查网络连通性

```bash
# 检查网口状态
ip link show

# 测试网口（根据实际配置）
ping -I eth0 192.168.1.1
ping -I lan1 192.168.1.1
```

---

## 8. 内核升级后重新编译

飞牛系统升级后，内核版本可能变化，需要重新编译驱动。

### 8.1 检查内核版本

```bash
# 在目标设备上
uname -r
# 示例输出: 6.18.18.c999-trim
```

### 8.2 一键重新编译

```bash
# 方法一：自动检测新版本（推荐）
./build_yt921x.sh

# 方法二：手动指定新版本
./build_yt921x.sh --kernel-version 6.18.18.c999-trim
```

脚本会自动：
1. 从目标设备检测新内核版本
2. 使用现有内核源码重新编译
3. 修正 vermagic 为新版本
4. 生成新的安装包

### 8.3 重新安装

```bash
# 上传新编译的驱动
scp -r ~/yt921x-output jun@192.168.100.107:/tmp/

# 登录设备重新安装
ssh jun@192.168.100.107
cd /tmp/yt921x-output
sudo ./install.sh

# 重启验证
sudo reboot
```

### 8.4 注意事项

- 内核大版本升级（如 6.18 → 6.19）可能需要更新内核源码
- 小版本升级（如 c963 → c999）通常只需重新编译并修正 vermagic
- 建议在系统升级前备份当前可用的驱动模块

---

## 9. 故障排除

### 9.1 编译错误

#### 错误：`yt921x.h: No such file or directory`

**原因**: 内核源码版本不包含 YT9215S 驱动。

**解决**:
```bash
# 检查驱动源码是否存在
ls drivers/net/dsa/yt921x.c

# 如果不存在，使用包含该驱动的内核版本
# 或从其他内核版本移植驱动源码
```

#### 错误：`scripts/basic/fixdep: No such file or directory`

**原因**: 未执行 `make modules_prepare`。

**解决**:
```bash
make modules_prepare -j$(nproc)
```

#### 错误：`openssl/bio.h: No such file or directory`

**原因**: 缺少 libssl-dev。

**解决**:
```bash
sudo apt install -y libssl-dev
```

### 9.2 安装错误

#### 错误：`Invalid module format`

**原因**: vermagic 与当前内核不匹配。

**解决**:
```bash
# 查看当前内核版本
uname -r

# 查看驱动 vermagic
modinfo /lib/modules/$(uname -r)/updates/trim/yt921x/yt921x.ko | grep vermagic

# 修正 vermagic
cd /lib/modules/$(uname -r)/updates/trim/yt921x/
sudo sed -i 's/旧版本/新版本/g' *.ko
sudo depmod -a
sudo modprobe yt921x
```

#### 错误：`Unknown symbol in module`

**原因**: 依赖模块未加载，或内核配置不匹配。

**解决**:
```bash
# 先加载标签协议
sudo modprobe tag_yt921x

# 再加载主驱动
sudo modprobe yt921x

# 查看详细错误
dmesg | tail -20
```

#### 错误：`Operation not permitted`

**原因**: Secure Boot 启用，阻止未签名模块加载。

**解决**:
- 在 BIOS/UEFI 中禁用 Secure Boot
- 或对模块进行签名（参考内核文档）

### 9.3 运行时问题

#### 问题：只识别 4 个网口

**原因**: 交换机驱动未加载或探测失败。

**解决**:
```bash
# 检查驱动是否加载
lsmod | grep yt921

# 如果未加载，手动加载
sudo modprobe tag_yt921x
sudo modprobe yt921x

# 检查驱动日志
dmesg | grep -i yt921

# 检查 I2C 设备（YT9215S 通过 I2C 配置）
sudo i2cdetect -l
sudo i2cdetect -y 0
```

#### 问题：网口无法连接

**原因**: 网口配置问题或物理连接问题。

**解决**:
```bash
# 检查网口状态
ip link show eth0
ethtool eth0

# 检查网口是否启用
sudo ip link set eth0 up

# 检查网线和交换机
```

#### 问题：驱动加载后系统崩溃

**原因**: 驱动与硬件不兼容，或设备树配置错误。

**解决**:
- 检查设备树中 YT9215S 节点配置
- 确认硬件连接（I2C 地址、中断引脚、RGMII 接口）
- 查看内核崩溃日志（`dmesg` 或串口日志）

---

## 10. 常见问题

### Q1: 为什么需要两个模块？可以只编译一个吗？

A: 不可以。`yt921x.ko` 负责交换机硬件初始化和端口管理，`tag_yt921x.ko` 负责 DSA 帧标签处理。DSA（Distributed Switch Architecture）架构要求两者配合工作，缺少任何一个都无法正常使用交换机端口。

### Q2: 编译时必须使用与目标设备完全相同的内核源码吗？

A: 建议使用相同大版本的内核源码。小版本差异可以通过修正 vermagic 解决，但大版本差异（如 6.18 → 6.19）可能导致 API 不兼容，编译失败。

### Q3: 可以直接在目标设备上编译吗？

A: 理论上可以，但不推荐。BDY-G98 的 ARM64 处理器编译速度较慢，且需要安装完整的编译工具链和内核源码，占用大量存储空间。建议在 x86_64 服务器上交叉编译。

### Q4: 驱动安装后需要重启吗？

A: 不一定。`modprobe` 可以动态加载驱动，无需重启。但如果之前有旧版本驱动加载，建议重启以确保干净加载。设置开机自动加载后，重启会自动加载驱动。

### Q5: 如何备份当前可用的驱动？

A:
```bash
# 备份驱动文件
sudo cp -r /lib/modules/$(uname -r)/updates/trim/yt921x ~/yt921x-backup/

# 备份配置
sudo cp /etc/modules-load.d/yt921x.conf ~/yt921x-backup/
```

### Q6: 系统升级后驱动会丢失吗？

A: 可能会。系统升级可能会覆盖 `/lib/modules/` 目录或更新内核版本。建议：
1. 升级前备份驱动文件
2. 升级后重新编译和安装驱动
3. 使用本文档的一键编译脚本快速重新编译

### Q7: 如何确认 YT9215S 硬件正常？

A:
```bash
# 检查 I2C 设备（YT9215S 通常在 I2C 总线 0，地址 0x5c）
sudo i2cdetect -y 0

# 预期输出包含 5c:
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:                         -- -- -- -- -- -- -- -- --
# 10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# ...
# 50: -- -- -- -- -- -- -- -- -- -- -- -- 5c -- -- --
```

### Q8: 编译产物可以在多个相同设备间共享吗？

A: 可以，只要设备的内核版本完全相同。如果内核版本不同，需要修正 vermagic 或重新编译。

---

## 附录

### A. 相关文件路径

| 文件 | 路径 |
|------|------|
| 驱动源码 | `drivers/net/dsa/yt921x.c` |
| 标签协议源码 | `net/dsa/tag_yt921x.c` |
| 编译脚本 | `build_yt921x.sh` |
| 安装脚本（生成） | `install.sh` |
| 驱动安装目录 | `/lib/modules/$(uname -r)/updates/trim/yt921x/` |
| 开机加载配置 | `/etc/modules-load.d/yt921x.conf` |

### B. 参考链接

- [Linux Kernel DSA Documentation](https://www.kernel.org/doc/html/latest/networking/dsa/index.html)
- [Motorcomm YT9215S Datasheet](https://www.motorcomm.com/)
- [Rockchip RK3588 Documentation](https://www.rock-chips.com/)

### C. 修改记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-08-31 | 1.0 | 初始版本，整理 YT9215S 驱动编译方法 |

---

**如有问题，请检查故障排除章节，或查看内核日志 (`dmesg`) 获取详细错误信息。**
