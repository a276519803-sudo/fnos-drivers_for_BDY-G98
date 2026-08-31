# YT9215S 交换机驱动

## 说明

Motorcomm YT9215S 千兆以太网交换机驱动，用于 BDY-G98 / RK3588 平台。

修复飞牛 FNOS 系统升级后交换机 8 个网口无法识别的问题。

## 文件清单

| 文件 | 说明 |
|------|------|
| `yt921x.ko` | DSA 交换机主驱动 |
| `tag_yt921x.ko` | DSA 标签协议驱动 |

## 适用环境

- 芯片平台：Rockchip RK3588 / RK3588S
- 设备：BDY-G98、飞牛 FNOS 设备
- 内核：6.18.18.c951-trim / 6.18.18.c963-trim（其他版本需重新编译）
- 架构：arm64 / aarch64

## 安装方法

```bash
# 1. 创建驱动目录
sudo mkdir -p /lib/modules/$(uname -r)/updates/trim/yt921x

# 2. 复制驱动文件
sudo cp yt921x.ko tag_yt921x.ko /lib/modules/$(uname -r)/updates/trim/yt921x/

# 3. （如内核版本不匹配）修正 vermagic
cd /lib/modules/$(uname -r)/updates/trim/yt921x/
sudo sed -i 's/6\.18\.18\.c963-trim/'"$(uname -r)"'/g' *.ko

# 4. 更新模块依赖
sudo depmod -a

# 5. 加载驱动（注意顺序）
sudo modprobe tag_yt921x
sudo modprobe yt921x

# 6. 设置开机自动加载
echo "tag_yt921x" | sudo tee /etc/modules-load.d/yt921x.conf
echo "yt921x" | sudo tee -a /etc/modules-load.d/yt921x.conf
```

## 验证方法

```bash
# 检查驱动模块
lsmod | grep yt921
# 预期输出:
# yt921x                32768  0
# tag_yt921x            16384  1 yt921x

# 检查网口数量（应为 12 个）
ip link show | grep -c '^[0-9]'

# 列出所有网口
ls /sys/class/net/ | grep -v lo
```

## 内核升级后重新编译

如内核版本变更，使用 `yt921x-build-tools` 目录中的编译工具重新编译驱动。

详见：[../yt921x-build-tools/README.md](../yt921x-build-tools/README.md)
