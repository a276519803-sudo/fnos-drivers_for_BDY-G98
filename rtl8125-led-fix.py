#!/usr/bin/env python3
"""
RTL8125 LED 修复脚本
设置 LEDSEL=0x0200，使 RTL8125 网口 LED 在所有速率下正常工作（有数据闪烁，无 link 熄灭）
"""
import mmap
import struct
import time
import os
import glob

LED_VALUE = 0x0200
CONFIG1_VALUE = 0xcf  # LEDS=11

def set_led(resource_path):
    """设置单个 RTL8125 设备的 LED 配置"""
    try:
        with open(resource_path, "r+b") as f:
            mm = mmap.mmap(f.fileno(), 0, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)
            
            def r16(off): return struct.unpack_from("<H", mm, off)[0]
            def w16(off, val): struct.pack_into("<H", mm, off, val)
            def r8(off): return struct.unpack_from("<B", mm, off)[0]
            def w8(off, val): struct.pack_into("<B", mm, off, val)
            
            # 解锁配置寄存器
            w8(0x50, 0xC0)
            time.sleep(0.05)
            
            # 设置 Config1 (LEDS=11)
            w8(0x52, CONFIG1_VALUE)
            
            # 设置所有 LEDSEL 寄存器
            w16(0x86, LED_VALUE)  # LEDSEL_1
            w16(0x84, LED_VALUE)  # LEDSEL_2
            w16(0x96, LED_VALUE)  # LEDSEL_3
            w16(0x18, LED_VALUE)  # CustomLED
            
            time.sleep(0.1)
            
            # 验证
            actual = r16(0x86)
            if actual == LED_VALUE:
                print(f"  {resource_path}: LEDSEL=0x{actual:04x} OK")
            else:
                print(f"  {resource_path}: LEDSEL=0x{actual:04x} (expected 0x{LED_VALUE:04x}) FAIL")
            
            # 恢复锁定
            w8(0x50, 0x11)
            mm.close()
            return True
    except Exception as e:
        print(f"  {resource_path}: ERROR - {e}")
        return False

def main():
    print("RTL8125 LED 修复启动")
    
    # 查找所有 RTL8125 设备 (PCI vendor 0x10ec, device 0x8125)
    devices = []
    for resource in glob.glob("/sys/bus/pci/devices/*/resource2"):
        device_dir = os.path.dirname(resource)
        try:
            with open(os.path.join(device_dir, "vendor")) as f:
                vendor = f.read().strip()
            with open(os.path.join(device_dir, "device")) as f:
                device = f.read().strip()
            if vendor == "0x10ec" and device == "0x8125":
                devices.append(resource)
        except:
            pass
    
    if not devices:
        print("未找到 RTL8125 设备")
        return 1
    
    print(f"找到 {len(devices)} 个 RTL8125 设备")
    success = 0
    for dev in devices:
        if set_led(dev):
            success += 1
    
    print(f"完成: {success}/{len(devices)} 成功")
    return 0 if success == len(devices) else 1

if __name__ == "__main__":
    exit(main())
