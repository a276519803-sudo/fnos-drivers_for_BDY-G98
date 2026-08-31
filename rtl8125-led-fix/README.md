# RTL8125 2.5G 网卡 LED 修复

## 说明

修复 Realtek RTL8125 2.5G 网卡网口指示灯不亮的问题。

通过 Python 脚本直接操作网卡寄存器，开启 LED 指示灯功能，并通过 systemd 服务实现开机自动运行。

## 文件清单

| 文件 | 说明 |
|------|------|
| `rtl8125-led-fix.py` | LED 修复 Python 脚本 |
| `rtl8125-led-fix.service` | systemd 服务文件 |
| `install.sh` | 一键安装脚本 |

## 适用环境

- 网卡：Realtek RTL8125 2.5G Ethernet
- 设备：BDY-G98、飞牛 FNOS 设备
- 系统：Linux（飞牛 FNOS、Ubuntu、Debian 等）
- 依赖：Python3、systemd

## 安装方法

### 方法一：一键安装（推荐）

```bash
chmod +x install.sh
sudo ./install.sh
```

### 方法二：手动安装

```bash
# 1. 复制脚本
sudo cp rtl8125-led-fix.py /usr/local/bin/
sudo chmod +x /usr/local/bin/rtl8125-led-fix.py

# 2. 安装服务
sudo cp rtl8125-led-fix.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rtl8125-led-fix.service
sudo systemctl start rtl8125-led-fix.service
```

## 验证方法

```bash
# 检查服务状态
sudo systemctl status rtl8125-led-fix.service

# 查看服务日志
sudo journalctl -u rtl8125-led-fix.service

# 观察网口指示灯是否亮起
```

## 卸载方法

```bash
sudo systemctl stop rtl8125-led-fix.service
sudo systemctl disable rtl8125-led-fix.service
sudo rm /etc/systemd/system/rtl8125-led-fix.service
sudo rm /usr/local/bin/rtl8125-led-fix.py
sudo systemctl daemon-reload
```
