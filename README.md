# 红米 Note 12 Turbo → Linux 服务器

> **仓库名：`Redmi-note12turbo-2-Linux`**

把 **红米 Note 12 Turbo / POCO F5**（代号 `xiaomi-marble`，骁龙 7+ Gen 2 / SM7475）刷成 **postmarketOS (Nura)**，当一台 headless Linux 服务器用；同一套系统还能切到 **phosh 图形桌面** 当平板。

仓库里包含：**可直接刷机的镜像构建产物说明** + **全部构建/部署脚本** + **完整踩坑记录** + **中文操作手册** + **状态面板（全屏 kiosk / phosh App 两种形态）**。

---

## ⚠️ 使用前：配置你自己的敏感信息

这个仓库**不含任何密码/Wi-Fi 凭据**。脚本从 `secrets.sh` 读取：

```bash
cp secrets.example.sh secrets.sh
chmod 600 secrets.sh
$EDITOR secrets.sh        # 填 MARBLE_PASSWORD / PHONE_IP / WIFI_SSID / WIFI_PSK
. ./secrets.sh            # 或让脚本自己 source
```

`secrets.sh` 已被 `.gitignore` 排除，**不要提交**。

> 如果你的仓库要公开，建议顺便把手机上的登录密码换掉，并改用 SSH 公钥登录。

---

## 这个方案的定位

| | |
|---|---|
| 系统 | postmarketOS (Nura) `edge` 通道 + **systemd** |
| 内核 | Linux **7.2.8**（mainline 移植 + SM8475/marble 补丁） |
| UI | `console` —— 无桌面，headless，SSH 管理 |
| 硬件 | 8/12/16 GB RAM，256 GB~1 TB UFS 3.1，自带电池（天然 UPS） |
| 功耗 | 待机约 1~1.5 W，满载约 8~12 W |

**能干什么**：nginx、PostgreSQL、Docker/Podman、编译、下载机、内网穿透……

**要接受的现实**：

- ❌ 快充不可用（缺小米私有认证协议，只能慢充；对服务器反而好，发热低）
- ❌ 指纹 / NFC / 红外 —— 无驱动，永久不可用
- ⚠️ 摄像头只有主摄 + 超广角
- ⚠️ APN 要手动设，蜂窝数据不会自动配好
- ⚠️ **电池**：长期满电会鼓包，必须做电源管理
- ⚠️ **散热**：无风扇，满载降频

---

## 目录结构

```
.
├── README.md                  ← 本文件：项目总览
├── BUILD.md                   ← 镜像构建过程 + 15 个坑与修复（复现必读）
├── DEPLOY.md                  ← **真机刷写与部署记录**（含所有纸面方案被证伪的地方）
├── .gitignore / .gitattributes
│
├── out/                       ← 交付物（刷机用什么、手机上跑什么，都在这）
│   ├── README.md              ←   产物清单 + 已验证项 + 快速上手 5 步
│   ├── 手册.md                ←   完整中文操作手册（电池/散热/救砖/排错）
│   ├── SHA256SUMS.txt         ←   全部产物的校验和
│   ├── boot-uboot.img         ←   U-Boot（fastboot 刷到 boot_b）        [git 不含]
│   ├── xiaomi-marble-boot.img ←   内核+initramfs+DTB+extlinux → esp     [git 不含]
│   ├── xiaomi-marble-root.img ←   根文件系统 → pmos                     [git 不含]
│   ├── marble-install         ←   上游官方分区/写盘脚本（GPL-2.0）
│   ├── flash-marble.sh        ←   fastboot 刷 U-Boot + 写盘封装
│   ├── backup-marble.sh       ←   手机上跑：备份 IMEI/射频分区（刷机前必做）
│   ├── setup-server.sh        ←   手机上跑：服务器化配置
│   ├── credentials.txt.example←   初始账号密码格式示例
│   └── dashboard/             ←   屏幕状态面板（cage + cog）+ 空闲熄屏
│       ├── install-dashboard.sh
│       ├── marble-dashboard.sh
│       ├── marble-screen.sh
│       ├── marble-screen-idle.sh
│       ├── marble-dashboard.service
│       ├── marble-dashboard-kiosk.service
│       ├── marble-screen-idle.service
│       └── 99-marble-powerkey.conf
│
└── scripts/                   ← 构建自动化（WSL2 里跑，按编号顺序）
    ├── 00-probe.sh … 02-probe-fs.sh    环境探测
    ├── 10-setup-host.sh                依赖 + 免密 sudo + binfmt
    ├── 20/21-clone*.sh                 克隆 pmaports
    ├── 30-install-pmbootstrap.sh       装 pmbootstrap
    ├── 50/57-writecfg.sh               写配置（绕过交互向导）
    ├── 54-fix-git.sh                   upstream remote + ownership
    ├── 70-build-firmware.sh            编译固件
    ├── 90-build-kernel.sh              编译内核
    ├── A6-devpkg-nocross.sh            编译设备包（--no-cross）
    ├── A7-install.sh                   生成 split 镜像
    ├── 96/A8/A9/B0/B5                  校验、收集、算校验和
    ├── C1-test-backup.sh               备份脚本离线功能测试
    └── B3/B4-test-*.sh                 屏幕脚本/设备枚举测试
```

> `marble-backup/`（IMEI 分区镜像）和 `logs/`（含明文密码）**已被 .gitignore 排除**，不要提交。

---

## 快速开始

完整步骤见 **`out/手册.md`**。这里只列骨架：

```bash
# ── 0. 校验下载的产物 ────────────────────────────────
sha256sum -c out/SHA256SUMS.txt

# ── 1. 手机备份 IMEI 分区（刷机前必做！）──────────────
adb push out/backup-marble.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/backup-marble.sh"
adb pull /data/local/tmp/marble-backup ./
#    存三份，只有 56MB

# ── 2. 刷 U-Boot 到 boot_b（不动 Android 的 slot A）──
fastboot getvar unlocked                # 必须是 yes
fastboot flash boot_b out/boot-uboot.img
fastboot set_active b

# ── 3. 手机重启，进 U-Boot 菜单（音量键移动，音量上确认）
#      选 Enable USB mass storage —— 之后不要再按键

# ── 4. 电脑写镜像 ───────────────────────────────────
cd out
sudo ./marble-install list
sudo ./marble-install install --layout single --dry-run \
     --boot-img xiaomi-marble-boot.img --root-img xiaomi-marble-root.img
sudo ./marble-install install --layout single \
     --boot-img xiaomi-marble-boot.img --root-img xiaomi-marble-root.img

# ── 5. 首次启动后：服务器化 +（可选）状态面板 ─────────
scp setup-server.sh dashboard/* marble@<手机IP>:~/
ssh marble@<手机IP>
sudo ./setup-server.sh
sudo ./install-dashboard.sh             # 面板 + 空闲 120s 熄屏、按键唤醒
```

---

## 已在本机验证过的东西

| 检查 | 结果 |
|---|---|
| 镜像文件系统块大小 | boot ext2/**4096**、root ext4/**4096**（手机 UFS 是 4096 字节扇区，硬性要求） |
| boot/root UUID 与 `extlinux.conf` | **双向一致**（不一致会启动失败） |
| `extlinux.conf` | 存在，指向 vmlinuz / DTB / initramfs |
| 已安装包 | 391 个 |
| Wi-Fi 固件 | `ath11k/WCN6855/hw2.1/{amss,m3,board,regdb}.bin` 齐全 → Wi-Fi 可用 |
| 内核 | `linux-xiaomi-marble-7.2.8-r7`，模块在 `/usr/lib/modules/7.2.8` |
| U-Boot 镜像 | SHA256 与官方 `v20261008` release 完全一致 |
| 备份脚本 | 纯 POSIX sh；离线用假分区跑通，4 个镜像 `cmp` 字节一致 |
| 屏幕/空闲脚本 | `dash -n` 通过；背光开关、输入设备枚举均用假 sysfs 实测通过 |
| 真机 | 备份已实跑并校验；`boot_b` 已刷入 U-Boot，slot 已切到 `b` |

**未验证**：~~真机首次启动 Linux~~ → **已完成真机部署，见 `DEPLOY.md`**。

---

## 真机部署结果（2026-11-09 实测）

已完整刷入并跑起来，详细过程与踩坑见 **`DEPLOY.md`**。

```
marble · Nura edge · Linux 7.2.8 · aarch64 · 8 核 · 10.2G 内存
Wi-Fi wlan0 <PHONE_IP>/24（自动连接）
根分区 216.4G（可用 206.7G，已 resize2fs 扩容）
温度 40°C 待机 · 电池 100% Full · 功率 0.03W
服务 sshd / NetworkManager / seatd / marble-dashboard /
     marble-dashboard-kiosk / marble-screen-idle / avahi-daemon 全 active
failed units：无
```

**纸面方案被真机证伪的地方（重要）**：

| 原方案 | 实际 |
|---|---|
| U-Boot 菜单选 `Enable USB mass storage` 导出磁盘 | ❌ 本机完全不可用，设备直接掉线 → 改用「GPT 手术 + fastboot 按分区名烧写」 |
| `root.img` 直接 `fastboot flash pmos` | ❌ 997MB 超 ABL 单块上限会被截断 → 必须先 `img2simg` 转 sparse |
| U-Boot 菜单"音量加确认" | ❌ 实测是 **电源键 = ENTER**，音量键只移动（误按 `8. Power off` 会关机） |
| 旧版 fastboot 切 slot | ❌ 不支持 `set_active`，需 platform-tools 37+ |
| `cog` 作 kiosk 浏览器 | ❌ 仓库无此包 → 改用 chromium（netsurf 不支持 CSS grid/JS） |
| `cage` 直接起 | ❌ 需 `XDG_RUNTIME_DIR` + `seatd`（libseat 无 builtin 后端） |
| 触摸键盘开箱可用 | ❌ buffyboard 在但没启用 → 自建 systemd 单元 |
| Windows 连手机 USB 网卡 | ❌ 手机是 CDC-ECM，Windows 从来就没有这个驱动 → 用 Linux 虚拟机烧写 + Wi-Fi 通信 |
| 电池 `/sys/class/power_supply/battery` | ❌ 本机是 `qcom-battmgr-bat` |
| 系统 DNS 可用 | ❌ systemd-resolved stub 不响应 → 换静态 `resolv.conf` |

**真机已验证可用**：空闲 120s 自动熄屏、任何输入唤醒、电源键短按只唤醒不关机
（`HandlePowerKey=ignore` 经 `busctl` 确认）。

---

## 重要提醒

1. **别丢 IMEI**。`persist` / `modemst1` / `modemst2` / `fsg` 必须先备份。刷坏后是「能开机、能连 Wi-Fi、但没信号」的半砖，小米 EDL 需要授权账号，救不回来。
2. **别碰引导链 LUN**。U-Boot 的 USB 大容量存储只导出 LUN 0，`xbl`/`abl` 所在 LUN 1/2/4/5 电脑根本看不到 —— 正常操作不会误伤。
3. **ABL 会回滚**。连续启动失败会自动切回 slot A（Android），救回来用 `fastboot set_active b`。
4. **电池必须管**。7×24 插电会鼓包，用定时插座或限充（手册第 7 节）。
5. **初始密码**在 `out/credentials.txt`（不入 git），首次登录后立刻 `passwd`。

---

## 上游与致谢

移植代码全部来自 [iLtanaka](https://github.com/iLtanaka)，不是本仓库的成果：

- 设备 wiki：https://wiki.nura.eco/wiki/Xiaomi_POCO_F5_/_Redmi_Note_12_Turbo_(xiaomi-marble)
- pmaports（`marble` 分支）：https://github.com/iLtanaka/pmaports/tree/marble
- 内核：https://github.com/iLtanaka/linux-marble
- U-Boot：https://github.com/iLtanaka/u-boot-marble
- 固件：https://github.com/iLtanaka/firmware-xiaomi-marble

本仓库的贡献只是：构建流水线自动化、踩坑记录、中文操作手册、以及屏幕状态面板/空闲熄屏这几个配套脚本。

> 移植仍在活跃开发，遇到问题先看设备 wiki 的 Known issues 和上游仓库的 commit 记录。
