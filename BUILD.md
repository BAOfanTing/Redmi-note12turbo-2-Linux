# 构建过程记录

> 红米 Note 12 Turbo（`xiaomi-marble`）从零构建 postmarketOS (Nura) 镜像的完整过程。
> 记录日期：**2026-11-09**，全部为实测结果，不是理论推导。
> 踩到的每个坑和对应的修复都在这里，复现时按顺序读即可。

---

## 0. 时间线总览

| 时间 | 阶段 | 耗时 |
|---|---|---|
| 10:04 | 开始，探测环境 | — |
| 10:14 – 10:15 | 安装构建依赖 + 注册 aarch64 binfmt | ~2 min |
| 10:15 – 10:22 | 克隆 pmaports（失败 2 次）+ pmbootstrap | ~7 min |
| 10:22 – 10:26 | 写 pmbootstrap 配置（绕过交互向导） | ~4 min |
| 10:27 – 11:12 | **编译 firmware-xiaomi-marble** | **35 min** |
| 11:13 – 11:55 | **编译 linux-xiaomi-marble（内核）** | **42 min** |
| 11:56 – 12:01 | 编译 device-xiaomi-marble（失败 1 次后成功） | ~5 min |
| 11:57 – 12:32 | **install --split 装包 + 组装镜像** | **31 min** |
| 12:34 – 12:36 | 镜像深度校验 | ~2 min |
| 12:48 – 12:50 | 手机上备份关键分区 | ~2 min |
| 12:53 – 12:56 | fastboot 刷 U-Boot 到 `boot_b` | ~3 min |

构建机：Windows 10 19045（家庭中文版）+ WSL2 Ubuntu 24.04，12 核 / 31 GB 内存，构建目录在 ext4 上共占约 **4.6 GB**。

---

## 1. 环境事实（决定了后面所有选择）

```
主机        : Windows 10 19045，AMD64，12 核 / 31GB
WSL         : 3.0.3.0，发行版 Ubuntu 24.04.4 LTS，内核 6.18.54.1-microsoft-standard-WSL2
文件系统    : /  → /dev/sdd ext4（953G 可用）
              /mnt/e → 9p (drvfs)，映射 Windows E: 盘
```

探测脚本：`scripts/00-probe.sh`、`scripts/01-probe2.sh`、`scripts/02-probe-fs.sh`

---

## 2. 坑 1：`/mnt/e` 是 9p，不能在上面构建

实测：

```
mknod on /mnt/e  → FAILED
mknod on ext4    → OK
chown on /mnt/e  → 被强制成 1001:1001
```

pmbootstrap 的 chroot 必须创建 `/dev/null`、`/dev/zero` 等设备节点，9p 不支持 `mknod`，所以**构建目录必须放在 WSL 的 ext4 上**，产物最后再拷回 Windows。

```
构建目录 : /home/<user>/marble-build     （ext4）
交付目录 : /mnt/e/Cache/shuaji/out        （Windows，9p）
```

---

## 3. 坑 2：binfmt 与 sudo

WSL 默认 `sudo` 要密码，而任务是无人值守跑的。用 root 身份（`wsl -u root`）写入：

```
/etc/sudoers.d/90-pmb-nopasswd:
    <user> ALL=(ALL) NOPASSWD: ALL
```

aarch64 跨架构执行需要 binfmt。`apt install qemu-user-static` 会自动注册，注册信息必须带 **`F`（fix binary）标志**，否则 chroot 内部找不到解释器：

```
$ cat /proc/sys/fs/binfmt_misc/qemu-aarch64
enabled
interpreter /usr/libexec/qemu-binfmt/aarch64-binfmt-P
flags: POF          ← F 是关键
```

安装的包（`scripts/10-setup-host.sh`）：

```
git python3 python3-venv python3-pip qemu-user-static binfmt-support
build-essential flex bison bc libssl-dev libelf-dev ccache
e2fsprogs util-linux cryptsetup-bin dosfstools mtools kpartx
android-tools-adb android-tools-fastboot device-tree-compiler
rsync curl wget unzip xz-utils openssh-client kmod
```

> `kpartx` 是 pmbootstrap 的硬性依赖，漏装会启动失败。
> 后面还补装了 `zstd`（解 initramfs 用）。

---

## 4. 坑 3：github.com 直连不稳

`git clone https://github.com/iLtanaka/pmaports.git` 连续两次失败：

```
fatal: unable to access ...: GnuTLS recv error (-110): The TLS connection was non-properly terminated.
fatal: unable to access ...: Failed to connect to github.com port 443 after 130266 ms
```

修复：`-c http.version=HTTP/1.1`，并在脚本里做 4 次重试 + tarball 兜底（`scripts/21-clone-retry.sh`）。第 3 次成功。

固件 tarball（82 MB）下载更慢，实测约 **37 KB/s**，花了 35 分钟。

---

## 5. 坑 4：pmaports 必须加 upstream remote

设备包读 `channels.cfg` 时执行的是：

```bash
git show <upstream>/main:channels.cfg
```

而 pmbootstrap 通过**URL 匹配**来找 upstream remote，克隆自 GitHub 的仓库没有这个 remote，报：

```
ERROR: pmaports: could not find remote name for any URL
       '['https://gitlab.postmarketos.org/postmarketOS/pmaports.git', ...]'
```

修复：

```bash
git -C pmaports remote add upstream https://gitlab.postmarketos.org/postmarketOS/pmaports.git
git -C pmaports fetch --depth=1 upstream main
```

> 顺带：`gitlab.postmarketos.org` 会 301/308 到 `gitlab.nura.eco`，git 会自动跟随，不用手改。

另外这个仓库是 root 建目录、普通用户跑 pmbootstrap，会触发 git 的 `dubious ownership`，需要 `git config --global --add safe.directory` 并 `chown -R`。

---

## 6. 坑 5：`pmbootstrap init` 是纯交互向导

pmbootstrap 3.12.1 的 `init` 子命令**只接受** `--shallow-initial-clone`，所有问题都是交互式的，无法脚本化。而 `pmbootstrap config` 又要求配置文件已存在。

绕过办法：**手写配置文件 + 手建 work 目录**（`scripts/57-writecfg.sh`）。

```ini
# ~/.config/pmbootstrap_v3.cfg
[pmbootstrap]
aports = /home/<user>/marble-build/pmaports
device = xiaomi-marble
kernel = mainline
ui = console
user = marble
hostname = marble
timezone = Asia/Shanghai
locale = en_US.UTF-8
jobs = 12
ccache_size = 5G
extra_packages = openssh,htop,curl
build_default_device_arch = True
build_pkgs_on_install = True
boot_size = 512
extra_space = 0
keymap =
qemu_redir_stdio = False
service_manager = default
ssh_key_glob = ~/.ssh/*.pub
ssh_keys = False
sudo_timer = False
ui_extras = False
auto_zap_misconfigured_chroots = no
work = /home/<user>/marble-build/work

[providers]

[mirrors]
```

work 目录还必须手动初始化（`work_version = 8`）：

```bash
mkdir -p $WORK/cache_git
echo 8 > $WORK/version
```

---

## 7. 关键决策：systemd 是被迫的，不是选择

`pmbootstrap status` 一开始就显示：

```
Channel: systemd-edge (pmaports: marble)
systemd: yes (default selected in pmbootstrap init, postmarketos-ui-console defaults to systemd)
```

原因：`device-xiaomi-marble` 的 APKBUILD **只安装 systemd 单元**，没有任何 OpenRC init 脚本：

```
/usr/lib/systemd/system/marble-hardware-tuning.service
/usr/lib/systemd/system/marble-touchboost.service
/usr/lib/systemd/system/hexagonrpcd-sdsp.service.d/50-marble.conf
/usr/lib/systemd/system/iio-sensor-proxy.service.d/50-marble.conf
```

所以这套移植就是 systemd 路线。`ui=console` 恰好默认 systemd，天然对齐，不需要额外干预。

---

## 8. 编译顺序（有三处强制依赖）

```bash
CI=1 pmbootstrap -y build firmware-xiaomi-marble                              # 必须最先
CI=1 pmbootstrap -y build linux-xiaomi-marble                                 # 内核
CI=1 pmbootstrap --no-cross -y build device-xiaomi-marble                     # 见坑 6
CI=1 pmbootstrap --no-cross -y install --split --password '<pw>'               # 见坑 7
```

**为什么 firmware 必须先单独编**：`pmbootstrap install` 不会自动构建它，直接 install 会报：

```
no such package firmware-xiaomi-marble-*
```

firmware 包产出 9 个子包（`adreno adsp audio bluetooth hexagonfs modem slpi venus wlan`），共 99 个固件文件。

内核 `linux-xiaomi-marble` 7.2.8-r7 的源：

```
https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.8.tar.xz   (160 MB)
+ 60 多个 marble 补丁（SM8475 pinctrl、UFS 850MHz、WCD9385、aw88261、Iris VPU …）
用 clang/lld 编译
```

---

## 9. 坑 6：crossdirect 在 WSL2 下必失败

第一次编设备包：

```
cc: fatal error: cannot execute 'cc1': posix_spawnp: No such file or directory
>>> ERROR: device-xiaomi-marble: build failed
```

排查过程：

1. `cc1` 确实存在于 `chroot_buildroot_aarch64/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/cc1`
2. 在 chroot 里手动编译 hello world **成功**
3. 抓到实际命令行后发现关键：

```
PMB_CROSS=crossdirect
PATH=/native/usr/lib/crossdirect/aarch64:/usr/lib/ccache/bin:...
```

pmbootstrap 默认用 **crossdirect**：在 aarch64 chroot 里通过 **`/native` 绑定挂载**调用宿主机的交叉 gcc。而 WSL2 下这个挂载没生效：

```
$ ls -A chroot_buildroot_aarch64/native
（空）
```

`cc1` 在 `/native/usr/libexec/...` 下找不到 → ENOENT。

**修复**：pmbootstrap 有全局开关

```bash
pmbootstrap --no-cross build device-xiaomi-marble
# 帮助原文: disable cross compiler, build only with QEMU and gcc (slow!)
```

改成纯 QEMU 编译后**一次通过**。设备包只有一个几百行的 C 文件（`marble-touchboost.c`），QEMU 慢一点无所谓。

> 内核包自带 `pmb:cross-native` 选项，走的是另一条路径，不受这个 bug 影响，正常编译即可。
> 没有修改任何上游 pmaports 文件。

---

## 10. 坑 7：`install` 在无 TTY 环境卡密码

```
Choose a password for the user 'marble':
termios.error: (25, 'Inappropriate ioctl for device')
EOFError
```

`pmbootstrap install` 会交互式 `getpass()` 要密码。后台/管道环境下必然崩溃。必须：

```bash
pmbootstrap -y install --split --password '<pw>'
```

> ⚠️ `--password` 是**明文**传递，会写进 pmbootstrap 日志。所以本次用随机生成的密码，装完应立刻 `passwd` 改掉。

install 阶段装了 **279 个包**，耗时约 31 分钟，产出：

```
chroot_native/home/pmos/rootfs/xiaomi-marble-boot.img   512 MB
chroot_native/home/pmos/rootfs/xiaomi-marble-root.img   997 MB
```

---

## 11. 镜像校验（`scripts/A8-verify.sh`、`A9-pkgcheck.sh`、`B0-initramfs.sh`）

| 检查项 | 结果 |
|---|---|
| boot 文件系统 | ext2，块大小 **4096**，label `pmOS_boot` |
| root 文件系统 | ext4，块大小 **4096**，label `pmOS_root` |
| **UUID 双向匹配** | `extlinux.conf` 里 `pmos_boot_uuid` / `pmos_root_uuid` 与两个镜像的实际 UUID 完全一致 |
| `extlinux.conf` | 存在，指向 `/vmlinuz`、`/sm8475-xiaomi-marble.dtb`、`/initramfs` |
| boot 内容 | vmlinuz 19 187 120 B、initramfs 13 394 924 B、DTB 122 692 B |
| initramfs | zstd + newc cpio，含 `hooks/50-marble-display-on.sh` 与 `pmos_root_uuid` 解析 |
| 已安装包数 | **391** |
| 关键包 | `device-xiaomi-marble`、`-nonfree-firmware`、`linux-xiaomi-marble`、`firmware-xiaomi-marble-{wlan,bluetooth,adreno,modem,adsp,slpi}`、`openssh`、`networkmanager`、`systemd` 全部在册 |
| Wi-Fi 固件 | `/lib/firmware/ath11k/WCN6855/hw2.1/{amss,m3,board,regdb}.bin` 齐全 |
| 固件总数 | 99（`/lib/firmware/qcom/sm8475/xiaomi/marble/`） |
| 内核模块 | `/usr/lib/modules/7.2.8` |

> 4096 字节块是**硬性要求**：手机 UFS 逻辑扇区是 4096，块大小 512/1024/2048 的镜像挂不上。
> `deviceinfo_rootfs_image_sector_size="4096"` 让 pmbootstrap 自动处理（`pmb/install/format.py` 用它算 mke2fs 的 `-b`）。

---

## 12. U-Boot 镜像

```
来源   : https://github.com/iLtanaka/u-boot-marble/releases/tag/v20261008
大小   : 745 472 字节
类型   : Android bootimg (kernel + ramdisk 0x630)
SHA256 : 81d9e7bce88b43f39262198590ce686a0c6544585ab4dbe668a8c2b3deaadb00
```

已核对与官方 release 完全一致。

---

## 13. 真机阶段踩的坑

### 13.1 `backup-marble.sh` 在 Android 上语法错误

```
/data/local/tmp/backup-marble.sh[21]: syntax error: unexpected '('
```

原因：第一版用了 bash 的关联数组 `declare -A PARTS=(...)`，而 Android 的 shell 是 **mksh / toybox**，不支持。

修复：整篇改写成纯 POSIX sh（`#!/system/bin/sh`），并适配：

- 不用 `declare -A`，改成 `for` 循环 + `find_part()` 按候选路径查找
- 不用 `dd status=progress`（toybox 不支持）
- 不用 `date -Is`，改 `date '+%Y-%m-%d %H:%M:%S %z'`
- 校验和用 `command -v sha256sum` 探测后再用

### 13.2 `adb pull` 报 `0 files pulled`

脚本以 root 建目录（`700`），而 `adb pull` 以 `shell` 用户运行，读不进去。

修复：脚本结尾 `chmod 755` 目录 / `chmod 644` 文件。

### 13.3 备份结果（已校验）

```
persist.img   33 554 432 B  (32MB)
modemst1.img   8 388 608 B  (8MB)
modemst2.img   8 388 608 B  (8MB)
fsg.img        8 388 608 B  (8MB)
```

- 4 个 SHA256 全部与设备端生成的一致
- 非零字节占比：persist 3%、modemst1/2 31%、fsg 31% → 是真实数据不是空盘
- `modemst1` 头部可见 `IMGEFS1`、`fsg` 头部可见 `IMGEFSG` → 确认是正确的 EFS 分区

### 13.4 `C:\Android\fastboot.exe` 太老，没有 `set_active`

```
fastboot set_active b
→ usage: fastboot [<option>] <command> ...   （列表里根本没有 set_active）
```

修复：下载官方最新 platform-tools（实测 37.0.1-15733141）：

```
https://dl.google.com/android/repository/platform-tools-latest-windows.zip
```

之后：

```
fastboot flash boot_b boot-uboot.img   → OKAY
fastboot set_active b                  → OKAY
fastboot getvar current-slot           → b（查两次都是 b）
```

### 13.5 U-Boot 菜单的键位（真机实测）

这机器只有三个物理键，U-Boot 菜单靠它们操作：

- **音量键**：上下移动光标
- **音量上**：确认选中（`Enable USB mass storage` 用这个确认，不是电源键）

> 选中 `Enable USB mass storage` 之后**不要再按任何键** —— U-Boot 里「按键」就是退出大容量存储模式的指令。

---

## 14. 尝试过但没走通的路径（留给后来者）

| 方案 | 结论 |
|---|---|
| `pmbootstrap` 装在 Windows 原生跑 | 不可能，需要 Linux chroot |
| 在 `/mnt/e`（9p）上建 chroot | 失败，不支持 `mknod` |
| 用 PyPI 的 pmbootstrap | 2.1.0 已 yanked 且过时，必须从 git 装 |
| crossdirect 交叉编译设备包 | WSL2 下 `/native` 挂载失效，改用 `--no-cross` |
| 用旧版 fastboot 切 slot | 不支持，必须换新版 platform-tools |
| usbipd-win 直通 USB | 未使用；改用 WSL 原生 `wsl --mount --bare`（内核已带 `usb-storage`/`uas`/`usbip-core`/`vhci-hcd`） |

---

## 15. 复现命令（一条龙）

```bash
# 1. 环境
bash scripts/10-setup-host.sh          # root 执行

# 2. 克隆 + 装 pmbootstrap
bash scripts/20-clone.sh
bash scripts/21-clone-retry.sh         # github 不稳时用这个
bash scripts/30-install-pmbootstrap.sh
bash scripts/54-fix-git.sh             # 加 upstream remote + 修 ownership

# 3. 配置（绕过交互向导）
bash scripts/57-writecfg.sh
su - <user> -c 'export PATH=$HOME/.local/bin:$PATH; pmbootstrap status'

# 4. 编译
bash scripts/70-build-firmware.sh
bash scripts/90-build-kernel.sh
bash scripts/A6-devpkg-nocross.sh      # --no-cross
bash scripts/A7-install.sh             # 自动生成随机密码，--password

# 5. 校验 + 收集
bash scripts/96-collect.sh
bash scripts/A8-verify.sh
bash scripts/A9-pkgcheck.sh
bash scripts/B0-initramfs.sh
bash scripts/B5-checksums.sh
```

真机阶段见仓库根目录 `README.md` 和 `out/手册.md`。
