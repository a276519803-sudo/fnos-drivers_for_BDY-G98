# Rockchip RK3588 硬解码驱动一键安装包

## 说明

本驱动包用于修复 Rockchip RK3588 平台的硬件视频编解码（硬解码）异常问题。

**问题现象**：
- 视频播放时无法使用硬件解码，CPU 占用率高
- ffmpeg 报错 "rkmpp 设备未就绪" 或 "driver is not ready"
- mediasrv / Jellyfin / Frigate 等应用无法调用硬件加速
- 系统升级后硬解码功能丢失
- `/dev/mpp_service` 设备节点不存在

**修复原理**：
重新安装 Rockchip MPP（Media Process Platform）内核驱动模块，包括视频编解码（rk_vcodec）、2D 图形加速（rga3）、NPU 加速（rknpu）及相关依赖模块，使硬件编解码功能恢复正常。

## 文件清单

```
rk_vcodec_driver/
├── install.sh              # 一键安装脚本
├── README.md               # 本说明文档
└── modules/                # 内核驱动模块目录
    ├── rk_vcodec.ko            # Rockchip MPP 视频编解码驱动（核心）
    ├── rga3.ko                 # RGA 2D 图形加速驱动
    ├── rknpu.ko                # NPU 神经网络加速驱动
    ├── rockchip_opp_select.ko  # OPP 频率选择（依赖）
    ├── rockchip_pvtm.ko        # PVTM 温度监测（依赖）
    ├── rockchip_sip.ko         # SIP 调用接口（依赖）
    └── rockchip_system_monitor.ko  # 系统监控（依赖）
```

| 文件 | 大小 | 说明 |
|------|------|------|
| `rk_vcodec.ko` | ~673KB | Rockchip MPP 服务驱动（视频编解码核心） |
| `rga3.ko` | ~263KB | RGA 2D 图形加速驱动 |
| `rknpu.ko` | ~120KB | NPU 神经网络加速驱动 |
| `rockchip_opp_select.ko` | ~68KB | OPP 频率选择模块 |
| `rockchip_pvtm.ko` | ~22KB | PVTM 温度监测模块 |
| `rockchip_sip.ko` | ~30KB | SIP 调用接口模块 |
| `rockchip_system_monitor.ko` | ~50KB | 系统监控模块 |
| `install.sh` | ~5.4KB | 一键安装脚本 |
| `README.md` | - | 使用说明文档 |

## 适用环境

- **芯片平台**：Rockchip RK3588 / RK3588S
- **设备**：BDY-G98、飞牛 FNOS 设备及其他 RK3588 开发板
- **系统**：Linux（飞牛 FNOS、Ubuntu、Debian 等）
- **内核**：6.18.18.c951-trim / 6.18.18.c963-trim（脚本自动适配其他版本）
- **架构**：arm64 / aarch64
- **权限**：需要 root 权限
- **依赖**：systemd（可选）、Python3（可选）

**已测试设备**：
- BDY-G98 / RK3588 平台
- 飞牛 FNOS 系统（c951 / c963 内核）

## 安装方法

### 方法一：一键安装（推荐）

```bash
# 1. 将本目录上传到设备
scp -r rk_vcodec_driver/ user@<设备IP>:/tmp/

# 2. 登录设备并执行安装
ssh user@<设备IP>
cd /tmp/rk_vcodec_driver
chmod +x install.sh
sudo ./install.sh
```

安装脚本会自动完成：
- 检查 7 个驱动文件完整性
- 检测当前内核版本，如不匹配自动修改 vermagic
- 安装驱动到 `/lib/modules/$(uname -r)/updates/trim/rk_vcodec/`
- 运行 `depmod` 更新模块依赖
- 按依赖顺序加载所有驱动模块
- 验证 `/dev/mpp_service` 设备节点
- 检测 mediasrv ffmpeg 的硬件加速支持

### 方法二：手动安装

```bash
# 1. 创建驱动目录
sudo mkdir -p /lib/modules/$(uname -r)/updates/trim/rk_vcodec

# 2. 复制所有驱动文件
sudo cp modules/*.ko /lib/modules/$(uname -r)/updates/trim/rk_vcodec/

# 3. （如内核版本不匹配）修改 vermagic
cd /lib/modules/$(uname -r)/updates/trim/rk_vcodec/
sudo sed -i 's/6\.18\.18\.c963-trim/'"$(uname -r)"'/g' *.ko

# 4. 更新模块依赖
sudo depmod -a

# 5. 按依赖顺序加载驱动
sudo modprobe rockchip_sip
sudo modprobe rockchip_pvtm
sudo modprobe rockchip_opp_select
sudo modprobe rockchip_system_monitor
sudo modprobe rk_vcodec
sudo modprobe rga3
sudo modprobe rknpu

# 6. 验证
ls -la /dev/mpp_service
lsmod | grep -iE 'rk_vcodec|rga|npu'
```

## 验证方法

```bash
# 1. 确认驱动已加载
lsmod | grep -iE 'rk_vcodec|rga3|rknpu'

# 预期输出:
# rknpu                  69632  0
# rga3                  143360  1
# rk_vcodec             393216  0
# rockchip_system_monitor    28672  3 rk_vcodec,rkgpu_bifrost_csf,rknpu
# rockchip_opp_select    40960  4 rockchip_system_monitor,rk_vcodec,...
# rockchip_sip           16384  3 rockchip_system_monitor,rk_vcodec,...

# 2. 确认设备节点存在
ls -la /dev/mpp_service
# 预期输出: crw------- 1 root root 237, 0 ... /dev/mpp_service

# 3. 确认 ffmpeg 支持 rkmpp 硬件加速
/usr/trim/lib/mediasrv/ffmpeg -hwaccels
# 预期输出包含: rkmpp

# 4. 测试硬件解码（替换为实际视频文件）
/usr/trim/lib/mediasrv/ffmpeg -hwaccel rkmpp -hwaccel_device /dev/mpp_service \
  -i test.mp4 -f null -

# 5. 查看驱动日志
dmesg | grep -iE 'rk_vcodec|mpp|rga|npu'

# 6. 查看 MPP 库
ls -la /usr/trim/lib/mediasrv/lib/librockchip_mpp*
```

## 常用命令

```bash
# 查看驱动状态
lsmod | grep -iE 'rk_vcodec|rga|npu|rockchip_'

# 查看设备节点
ls -la /dev/mpp_service

# 重新加载 rk_vcodec 驱动
sudo modprobe -r rk_vcodec
sudo modprobe rk_vcodec

# 重新加载所有驱动
sudo modprobe -r rknpu rga3 rk_vcodec rockchip_system_monitor rockchip_opp_select rockchip_sip
sudo modprobe rockchip_sip
sudo modprobe rockchip_pvtm
sudo modprobe rockchip_opp_select
sudo modprobe rockchip_system_monitor
sudo modprobe rk_vcodec
sudo modprobe rga3
sudo modprobe rknpu

# 查看内核日志
dmesg | grep -iE 'rk_vcodec|mpp|rga|npu'
dmesg | grep -i 'driver is not ready'

# 重启 mediasrv 服务（如硬解码仍不工作）
sudo systemctl restart mediasrv

# 查看 ffmpeg 硬件加速支持
/usr/trim/lib/mediasrv/ffmpeg -hwaccels

# 测试硬件解码
/usr/trim/lib/mediasrv/ffmpeg -hwaccel rkmpp -hwaccel_device /dev/mpp_service \
  -i /path/to/video.mp4 -f null -
```

## 卸载方法

```bash
# 1. 卸载驱动模块（按依赖逆序）
sudo modprobe -r rknpu
sudo modprobe -r rga3
sudo modprobe -r rk_vcodec
sudo modprobe -r rockchip_system_monitor
sudo modprobe -r rockchip_opp_select
sudo modprobe -r rockchip_pvtm
sudo modprobe -r rockchip_sip

# 2. 删除驱动文件
sudo rm -rf /lib/modules/$(uname -r)/updates/trim/rk_vcodec

# 3. 更新模块依赖
sudo depmod -a
```

## 故障排除

### 问题：驱动加载失败，提示 "Unknown symbol" 或 "Invalid module format"

**原因**：驱动 vermagic 与当前内核版本不匹配。

**解决**：
```bash
# 自动修改 vermagic（install.sh 会自动处理）
cd /lib/modules/$(uname -r)/updates/trim/rk_vcodec/
sudo sed -i 's/6\.18\.18\.c963-trim/'"$(uname -r)"'/g' *.ko
sudo depmod -a
sudo modprobe rk_vcodec
```

### 问题：驱动加载成功，但 /dev/mpp_service 不存在

**原因**：设备树配置问题，或驱动未正确探测硬件。

**解决**：
```bash
# 查看驱动日志
dmesg | grep -iE 'rk_vcodec|mpp'

# 检查设备树节点
ls /sys/firmware/devicetree/base/ | grep -i mpp
ls /sys/firmware/devicetree/base/ | grep -i vcodec

# 尝试手动创建设备节点（如驱动已加载但设备节点缺失）
sudo mknod /dev/mpp_service c 237 0
sudo chmod 600 /dev/mpp_service
```

### 问题：ffmpeg 报错 "mpp_platform: client X driver is not ready!"

**原因**：部分驱动模块未加载，或加载顺序错误。

**解决**：
```bash
# 按正确顺序重新加载所有驱动
sudo modprobe -r rknpu rga3 rk_vcodec rockchip_system_monitor rockchip_opp_select rockchip_sip 2>/dev/null
sleep 1
sudo modprobe rockchip_sip
sudo modprobe rockchip_pvtm
sudo modprobe rockchip_opp_select
sudo modprobe rockchip_system_monitor
sudo modprobe rk_vcodec
sudo modprobe rga3
sudo modprobe rknpu

# 重启系统（推荐）
sudo reboot
```

### 问题：硬解码仍不工作，CPU 占用率高

**原因**：
1. 应用未配置使用硬件加速
2. mediasrv 服务需要重启
3. 视频编码格式不支持硬件解码

**解决**：
```bash
# 1. 重启 mediasrv 服务
sudo systemctl restart mediasrv

# 2. 确认 ffmpeg 支持 rkmpp
/usr/trim/lib/mediasrv/ffmpeg -hwaccels | grep rkmpp

# 3. 手动测试硬件解码
/usr/trim/lib/mediasrv/ffmpeg -hwaccel rkmpp -hwaccel_device /dev/mpp_service \
  -i /path/to/video.mp4 -f null -

# 4. 检查视频编码格式（RK3588 支持 H.264/H.265/VP9/AV1 解码）
ffprobe /path/to/video.mp4 2>&1 | grep -i codec
```

### 问题：系统升级后硬解码再次丢失

**原因**：系统升级覆盖了驱动模块目录。

**解决**：重新运行安装脚本即可：
```bash
cd /path/to/rk_vcodec_driver
sudo ./install.sh
```

## 技术细节

### 驱动依赖关系

```
rockchip_sip.ko
    └── rockchip_pvtm.ko
         └── rockchip_opp_select.ko
              └── rockchip_system_monitor.ko
                   ├── rk_vcodec.ko (视频编解码)
                   ├── rga3.ko (2D 图形加速)
                   └── rknpu.ko (NPU 加速)
```

### 驱动信息

| 驱动 | 描述 | 作者 | 依赖 |
|------|------|------|------|
| rk_vcodec | Rockchip MPP 服务驱动 | Ding Wei <leo.ding@rock-chips.com> | rockchip_opp_select, rockchip_system_monitor, rockchip_sip |
| rga3 | RGA 2D 图形加速 | Rockchip | - |
| rknpu | NPU 神经网络加速 | Rockchip | rockchip_system_monitor |

### 设备节点

| 设备 | 主设备号 | 次设备号 | 说明 |
|------|----------|----------|------|
| /dev/mpp_service | 237 | 0 | MPP 服务设备节点 |

### 支持的硬件编解码格式

**解码**：H.264 / H.265(HEVC) / VP9 / AV1 / MPEG-2 / MPEG-4 / VC-1
**编码**：H.264 / H.265(HEVC)
**最大分辨率**：8K@60fps（解码），4K@60fps（编码）

### 用户态库（mediasrv 自带）

- `/usr/trim/lib/mediasrv/lib/librockchip_mpp.so` - MPP 用户态库
- `/usr/trim/lib/mediasrv/lib/librockchip_vpu.so` - VPU 用户态库
- `/usr/trim/lib/mediasrv/ffmpeg` - 支持 rkmpp 的 ffmpeg 二进制

## 修改记录

- 2026-08-27：初始版本，基于 BDY-G98 / RK3588 平台 c963 内核驱动整理
