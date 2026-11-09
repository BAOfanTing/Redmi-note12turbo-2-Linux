# 红米 Note 12 Turbo (xiaomi-marble) → Linux 服务器 · 构建产物

构建时间：2026-11-09　构建机：Windows 10 + WSL2 Ubuntu 24.04（12 核 / 31GB）
系统：postmarketOS (Nura) `edge` 通道 + **systemd**，UI = `console`（纯 headless，无桌面）
内核：Linux **7.2.8**（mainline 移植，SM8475 驱动 + marble 补丁）
架构：aarch64　根文件系统：ext4，**4096 字节块**

> 详细操作步骤见 **`手册.md`**。本文件只是产物清单和快速上手。

---

## 一、产物清单

### 刷机必需

| 文件 | 大小 | 用途 | SHA256（前 16 位） |
|---|---|---|---|
| `boot-uboot.img` | 728 KB | U-Boot 引导，fastboot 刷到 `boot_b` | `81d9e7bce88b43f3` |
| `xiaomi-marble-boot.img` | 512 MB | 内核+initramfs+DTB+extlinux → `esp` 分区 | `d923ba2449461447` |
| `xiaomi-marble-root.img` | 997 MB | 根文件系统 → `pmos` 分区 | `e18cc0989ae079e2` |
| `marble-install` | 24 KB | 官方分区/写盘脚本（Python，root 运行） | `7afca7f13ebbf150` |

### 辅助脚本

| 文件 | 在哪里跑 | 作用 |
|---|---|---|
| `backup-marble.sh` | **手机上**（root） | 备份 `persist`/`modemst1`/`modemst2`/`fsg`（IMEI+射频校准），**刷机前必做** |
| `flash-marble.sh` | Linux PC | 把 fastboot 刷 U-Boot + 写镜像两步封装起来 |
| `setup-server.sh` | **手机上**（root） | 首次启动后：装软件、建用户、配 SSH、温度监控 |
| `dashboard/install-dashboard.sh` | **手机上**（root） | 装 kiosk 状态面板（cage + cog）+ 空闲熄屏；屏上显示 CPU/温度/电池/网络 |
| `credentials.txt` | 自己看 | 初始用户名 `marble` 和随机密码，**首次登录后立刻改**（`passwd`） |
| `SHA256SUMS.txt` | — | 全部产物的校验和，`sha256sum -c SHA256SUMS.txt` 验证 |

`dashboard/` 里还有状态面板的生成脚本、2 个 systemd 单元，以及**空闲熄屏**相关的三个文件：

| 文件 | 作用 |
|---|---|
| `marble-dashboard.sh` | 采集状态 → 生成 HTML 到 `/run/marble-dashboard/index.html` |
| `marble-screen.sh` | 屏幕开关：`off` / `on` / `toggle` / `status`，控 `brightness` 或停 cage |
| `marble-screen-idle.sh` | 空闲检测守护：直接 `dd` 读 `/dev/input/eventN`，空闲 `IDLE_SEC` 秒熄屏，任何输入唤醒 |
| `99-marble-powerkey.conf` | logind drop-in：`HandlePowerKey=ignore`，电源键只唤醒、不关机 |
| `marble-screen-idle.service` | 上面守护进程的单元（默认 `IDLE_SEC=120`、`BLANK_MODE=backlight`） |

---

## 二、快速上手（5 步）

```bash
# ── 0. 校验产物（在 Linux PC 上）─────────────────────────────
sha256sum -c SHA256SUMS.txt

# ── 1. 手机上备份关键分区（用现有 Android 的 root）──────────
adb push backup-marble.sh /data/local/tmp/
adb shell 'su -c "sh /data/local/tmp/backup-marble.sh /sdcard/marble-backup"'
adb pull /sdcard/marble-backup ./
# 这 4 个 img 存三份，只有 56MB

# ── 2. 手机进 fastboot（关机 → 音量下 + 电源），刷 U-Boot ────
fastboot devices
fastboot getvar current-slot     # 查两次
fastboot flash boot_b boot-uboot.img
fastboot set_active b
fastboot reboot

# ── 3. U-Boot 菜单（按住音量下）→ Enable USB mass storage ────
sudo ./marble-install list                  # 确认找到手机
sudo ./marble-install install --layout single --dry-run \
     --boot-img xiaomi-marble-boot.img \
     --root-img xiaomi-marble-root.img      # 先看计划，不写盘
sudo ./marble-install install --layout single \
     --boot-img xiaomi-marble-boot.img \
     --root-img xiaomi-marble-root.img      # 正式写入

# ── 4. 手机按键退出 → 选 Boot Nura ──────────────────────────
#    用 USB 线连电脑，走 USB 网络首次登录：
sudo ip addr add 172.16.42.2/24 dev <新出现的网卡>
ssh marble@172.16.42.1          # 密码在 credentials.txt

# ── 5. 服务器化 + 可选状态面板 ──────────────────────────────
scp setup-server.sh dashboard/* marble@<手机IP>:~/
ssh marble@<手机IP>
sudo ./setup-server.sh
sudo ./install-dashboard.sh     # 可选：屏上面板 + 空闲 120s 熄屏、按键唤醒
```

---

## 三、已验证的项目

| 检查项 | 结果 |
|---|---|
| 镜像文件系统块大小 | boot=ext2/**4096**，root=ext4/**4096** ✅（手机 UFS 是 4096 字节扇区，必须如此） |
| 分区标签 | `pmOS_boot` / `pmOS_root` ✅ |
| `extlinux.conf` 存在且内容正确 | ✅ kernel=/vmlinuz、fdt=/sm8475-xiaomi-marble.dtb、initrd=/initramfs |
| boot/root UUID 与 cmdline 一致 | ✅ 两个 UUID 都匹配（不匹配会启动失败） |
| boot 分区内容 | vmlinuz 19.2MB、initramfs 13.4MB、DTB 122KB ✅ |
| initramfs | newc cpio + zstd，含 `hooks/50-marble-display-on.sh`、`pmos_root_uuid` 处理 ✅ |
| 根文件系统包数 | **391** 个 |
| device 包 | `device-xiaomi-marble` + `device-xiaomi-marble-nonfree-firmware` ✅ |
| 固件 | 99 个文件；`ath11k/WCN6855/hw2.1/{amss,m3,board,regdb}.bin` 齐全 → **Wi-Fi 可用** ✅ |
| 内核 | `linux-xiaomi-marble-7.2.8-r7`，模块目录 `/usr/lib/modules/7.2.8` ✅ |
| systemd / sshd / NetworkManager | 均已在镜像内 ✅ |
| U-Boot 镜像 | SHA256 与官方 release `v20261008` 完全一致 ✅ |

---

## 四、构建过程中踩到的坑（复现时参考）

1. **不能在 `/mnt/e`（9p）上构建** —— 不支持 `mknod`，chroot 起不来。必须在 WSL 的 ext4 上构建，最后把产物拷回。
2. **`pmbootstrap init` 是纯交互向导** —— 手写 `~/.config/pmbootstrap_v3.cfg` + 手动建 work 目录（`version` 文件内容 `8`）绕过。
3. **pmaports 必须加 upstream remote** —— 否则读 `channels.cfg` 报 `could not find remote name`。
4. **firmware 必须先单独编** —— 否则 install 报 `no such package firmware-xiaomi-marble-*`。
5. **github.com 直连不稳** —— 用 `-c http.version=HTTP/1.1`，失败退到 codeload tarball。
6. **crossdirect 在 WSL2 失效** —— `/native` 绑定挂载没生效，`cc1` 找不到。用全局 `--no-cross` 改纯 QEMU 编译。
7. **`install` 无 TTY 会卡密码输入** —— 必须 `--password '<pw>'`。
8. **4096 字节扇区** —— `deviceinfo_rootfs_image_sector_size="4096"` 已被 pmbootstrap 正确采用。

---

## 五、这个移植的硬限制（服务器场景影响）

- ❌ **快充不可用**（缺小米私有认证）；只能慢充，但发热低，算好事
- ❌ 指纹 / NFC / 红外 —— 无驱动，永久不可用
- ⚠️ 摄像头只有主摄+超广角（对服务器无影响）
- ⚠️ APN 要手动设（`mmcli`），蜂窝数据不会自动配好
- ⚠️ **电池**：长期满电会鼓包，必须做电源管理（见手册第 7 节）
- ⚠️ **散热**：无风扇，满载会降频
- ⚠️ ABL 连续启动失败会自动切回 slot A；救回来用 `fastboot set_active b`

---

## 六、镜像里的默认配置

| 项目 | 值 |
|---|---|
| 用户 | `marble`（密码见 `credentials.txt`，**请立刻改**） |
| 主机名 | `marble` |
| 时区 | `Asia/Shanghai` |
| locale | `en_US.UTF-8` |
| SSH | sshd 已启用，22 端口 |
| USB 网络 | RNDIS，手机端 `172.16.42.1` |
| 防火墙 | 已启用（pmOS 默认 nftables 规则） |
| 额外安装的包 | `openssh` `htop` `curl` |
| UI | `console` —— 无桌面，屏幕只显示文本控制台（装了 dashboard 后显示状态面板） |
| 根文件系统加密 | 未加密（要加密请用 `--fde` 重新构建） |

---

## 七、重新构建 / 更新

```bash
cd ~/marble-build
export PATH="$HOME/.local/bin:$PATH"

git -C pmaports pull                       # 拉取移植更新
pmbootstrap --no-cross -y build firmware-xiaomi-marble
pmbootstrap --no-cross -y build linux-xiaomi-marble
pmbootstrap --no-cross -y build device-xiaomi-marble
pmbootstrap --no-cross -y install --split --password '<pw>'

# 产物在：
#   work/chroot_native/home/pmos/rootfs/xiaomi-marble-boot.img
#   work/chroot_native/home/pmos/rootfs/xiaomi-marble-root.img
```

手机侧更新（不动 U-Boot、不动 Android slot A）：

```bash
# U-Boot -> Enable USB mass storage
sudo ./marble-install install --layout reinstall \
     --boot-img <新boot.img> --root-img <新root.img>
```

---

## 八、参考

- 设备 wiki（Nura / 原 postmarketOS）：https://wiki.nura.eco/wiki/Xiaomi_POCO_F5_/_Redmi_Note_12_Turbo_(xiaomi-marble)
- pmaports（marble 分支）：https://github.com/iLtanaka/pmaports/tree/marble
- 内核：https://github.com/iLtanaka/linux-marble
- U-Boot：https://github.com/iLtanaka/u-boot-marble
- 固件：https://github.com/iLtanaka/firmware-xiaomi-marble

*移植代码仍在活跃开发，遇到问题先看设备 wiki 的 Known issues 和仓库 commit 记录。*
