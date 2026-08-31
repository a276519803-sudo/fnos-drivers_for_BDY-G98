


---

## YT9215S 交换机驱动一键编译工具 (v1.0.1 新增)

### 说明

本工具用于在 x86_64 交叉编译环境中编译 YT9215S 交换机驱动，适用于飞牛 FNOS 系统升级后交换机网口无法识别、内核版本变更后需要重新编译驱动的场景。

**编译产物**：`yt921x.ko`（DSA 交换机主驱动）+ `tag_yt921x.ko`（标签协议驱动）

### 编译环境要求

| 项目 | 要求 |
|------|------|
| 编译系统 | Ubuntu 20.04 / 22.04 / 24.04 (x86_64) |
| 编译器 | aarch64-linux-gnu-gcc（交叉编译器） |
| 目标架构 | arm64 / aarch64（飞牛 BDY-G98 / RK3588） |
| 内存 | 4GB 以上 |
| 磁盘 | 20GB 以上空闲空间 |

**注意**：本编译脚本必须在 x86_64 交叉编译环境中运行，不能直接在飞牛设备上编译！

### 快速使用

```bash
# 1. 安装编译依赖
sudo apt update
sudo apt install -y gcc-aarch64-linux-gnu build-essential libssl-dev \
    libelf-dev bison flex bc kmod cpio python3 git

    # 2. 下载并解压编译工具
    unzip yt921x-build-tools-v1.0.1.zip
    cd yt921x-build-tools-v1.0.1
    chmod +x build_yt921x.sh

    # 3. 配置飞牛设备信息（三选一）
    # 方式一：修改脚本中的 TARGET_IP 和 TARGET_USER
    # 方式二：命令行参数
    ./build_yt921x.sh --target-ip <设备IP>
    # 方式三：环境变量
    TARGET_IP=<设备IP> TARGET_USER=<用户名> ./build_yt921x.sh

    # 4. 编译完成后，产物在 ~/yt921x-output/ 目录
    # 5. 上传到飞牛设备安装
    scp -r ~/yt921x-output <用户名>@<设备IP>:/tmp/
    ssh <用户名>@<设备IP>
    cd /tmp/yt921x-output
    sudo ./install.sh
    ```

    ### 命令行参数

    ```bash
    ./build_yt921x.sh [选项]

    选项:
      --kernel-dir DIR     内核源码目录 (默认: ~/kernel)
        --output-dir DIR     输出目录 (默认: ~/yt921x-output)
          --target-ip IP       飞牛设备 IP (用于自动检测内核版本)
            --kernel-version VER 手动指定目标内核版本
              --cross-compile PRE  交叉编译器前缀 (默认: aarch64-linux-gnu-)
                -h, --help           显示帮助
                ```

                ### 下载地址

                - [yt921x-build-tools-v1.0.1.zip](https://github.com/a276519803-sudo/fnos-drivers_for_BDY-G98/releases/download/v1.0.1/yt921x-build-tools-v1.0.1.zip)

                ---

                ## ⚠️ 隐私与安全说明

                本仓库所有文档和脚本中的 IP 地址、用户名等均为**示例占位符**，请在使用前替换为您自己的实际信息：

                - `<设备IP>` → 替换为您的飞牛设备实际 IP 地址（如 192.168.1.100）
                - `<用户名>` → 替换为您的飞牛设备登录用户名（如 root、admin 等）

                **请勿在公开仓库或 Issue 中泄露您的真实 IP 地址、用户名、密码等敏感信息！**

                ---

                ## 版本历史

                | 版本 | 发布日期 | 内容 |
                |------|----------|------|
                | v1.0.0 | 2026-08-27 | YT9215S驱动、RTL8125 LED修复、RK3588硬解码驱动 |
                | v1.0.1 | 2026-08-31 | 新增 YT9215S 一键编译工具，修复隐私信息泄露问题 |
