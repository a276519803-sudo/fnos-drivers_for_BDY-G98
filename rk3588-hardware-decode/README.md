# RK3588 硬件解码驱动

## 说明

Rockchip RK3588 平台硬件视频编解码（硬解码）驱动修复包。

修复视频播放时无法使用硬件解码、CPU 占用率高、ffmpeg 报错 "rkmpp 设备未就绪" 等问题。

## 文件清单

| 文件 | 说明 |
|------|------|
| `rk_vcodec.ko` | Rockchip MPP 视频编解码驱动（核心） |
| `rga3.ko` | RGA 2D 图形加速驱动 |
| `rknpu.ko` | NPU 神经网络加速驱动 |
| `rockchip_opp_select.ko` | OPP 频率选择（依赖） |
| `rockchip_pvtm.ko` | PVTM 温度监测（依赖） |
| `rockchip_sip.ko` | SIP 调用接口（依赖） |
| `rockchip_system_monitor.ko` | 系统监控（依赖） |

## 适用环境

- 芯片平台：Rockchip RK3588 / RK3588S
- 设备：BDY-G98、飞牛 FNOS 设备及其他 RK3588 开发板
- 系统：Linux（飞牛 FNOS、Ubuntu、Debian 等）
- 内核：6.18.18.c951-trim / 6.18.18.c963-trim
- 架构：arm64 / aarch64

## 支持的硬件编解码格式

**解码**：H.264 / H.265(HEVC) / VP9 / AV1 / MPEG-2 / MPEG-4 / VC-1
**编码**：H.264 / H.265(HEVC)
**最大分辨率**：8K@60fps（解码），4K@60fps（编码）

## 安装方法

```bash
# 1. 创建驱动目录
sudo mkdir -p /lib/modules/$(uname -r)/updates/trim/rk_vcodec

# 2. 复制所有驱动文件
sudo cp *.ko /lib/modules/$(uname -r)/updates/trim/rk_vcodec/

# 3. （如内核版本不匹配）修正 vermagic
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
```

## 验证方法

```bash
# 1. 确认驱动已加载
lsmod | grep -iE 'rk_vcodec|rga3|rknpu'

# 2. 确认设备节点存在
ls -la /dev/mpp_service

# 3. 确认 ffmpeg 支持 rkmpp 硬件加速
/usr/trim/lib/mediasrv/ffmpeg -hwaccels | grep rkmpp

# 4. 测试硬件解码
/usr/trim/lib/mediasrv/ffmpeg -hwaccel rkmpp -hwaccel_device /dev/mpp_service \
    -i test.mp4 -f null -
```

## 驱动依赖关系

```
rockchip_sip.ko
 └── rockchip_pvtm.ko
 └── rockchip_opp_select.ko
 └── rockchip_system_monitor.ko
 ├── rk_vcodec.ko (视频编解码)
 ├── rga3.ko (2D 图形加速)
 └── rknpu.ko (NPU 加速)
```

## 故障排除

### 问题：驱动加载失败，提示 "Invalid module format"

**原因**：驱动 vermagic 与当前内核版本不匹配。

**解决**：
```bash
cd /lib/modules/$(uname -r)/updates/trim/rk_vcodec/
sudo sed -i 's/旧版本/'"$(uname -r)"'/g' *.ko
sudo depmod -a
```

### 问题：ffmpeg 报错 "mpp_platform: client X driver is not ready!"

**原因**：部分驱动模块未加载，或加载顺序错误。

**解决**：按正确顺序重新加载所有驱动，或重启系统。
