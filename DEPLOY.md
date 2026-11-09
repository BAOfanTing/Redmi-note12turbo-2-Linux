# 真机部署记录（2026-11-09）

> 这份文档记录**在真实红米 Note 12 Turbo 上**从 Android 刷成 pmOS 服务器的完整过程，
> 包含所有与"纸面方案"不一致、必须现场修正的地方。
> 照 `手册.md` 直接做会踩的坑，这里都标出来了。

设备：Redmi Note 12 Turbo（`23049RAD8C`），Android 13 / SDK 33，Magisk root，bootloader 已解锁。

---

## 0. 结论速览

| 阶段 | 结果 |
|---|---|
| 备份 IMEI 分区 | ✅ 4 个分区 SHA256 全对 |
| 刷 U-Boot 到 `boot_b` | ✅ |
| **U-Boot 的 USB 大容量存储（UMS）** | ❌ **完全不可用**（详见第 3 节）→ 改用「GPT 手术 + fastboot 按分区名烧写」 |
| 分区表重排 | ✅ `userdata` → `esp`(1G) + `pmos`(223.2G) |
| 烧 `esp` / `pmos` | ✅（`pmos` 必须先转 **Android sparse**） |
| pmOS 启动 | ✅ 内核 7.2.8 / Nura edge / systemd 全绿 |
| 网络 | ✅ Wi-Fi 自动连接（Windows 无法对接 USB 网卡，详见第 6 节） |
| 状态面板 + 空闲熄屏 | ✅ 实测熄屏/唤醒正常 |

---

## 1. 备份（与手册一致，但脚本要改）

手册里的 `backup-marble.sh` 第一版用了 bash 的 `declare -A`，在 Android 的 **mksh/toybox** 上直接语法错误：

```
/data/local/tmp/backup-marble.sh[21]: syntax error: unexpected '('
```

→ 已改写为纯 POSIX sh。实测结果：

```
persist.img   33554432 B   SHA256 9c66ab6d...
modemst1.img   8388608 B   SHA256 e1ced4fd...
modemst2.img   8388608 B   SHA256 c8da794d...
fsg.img        8388608 B   SHA256 24b36f41...
```

`modemst1` 头部可见 `IMGEFS1`、`fsg` 可见 `IMGEFSG`，非零字节占比 31%，确认是真实 EFS 数据。

另一个坑：脚本以 root 建目录（`700`），`adb pull` 以 `shell` 用户运行 → `0 files pulled`。
→ 脚本结尾 `chmod 755/644` 解决。

---

## 2. 刷 U-Boot

```bash
fastboot flash boot_b boot-uboot.img     # OKAY
fastboot set_active b                    # OKAY
```

**坑：Windows 上的旧版 fastboot 不支持 `set_active`**（帮助列表里根本没有），必须用新版 platform-tools。

本次用 `fastboot 37.0.1-15733141`：
<https://dl.google.com/android/repository/platform-tools-latest-windows.zip>

---

## 3. U-Boot 菜单：按键映射 + UMS 不可用

### 3.1 按键映射（实测）

菜单底部写 `Press UP/DOWN to move, ENTER to select, ESC to quit`，实际对应：

| 操作 | 按键 |
|---|---|
| 移动光标 | **音量加 / 音量减** |
| 确认（ENTER） | **电源键** |

⚠️ 有一个致命混淆：菜单里 `8. Power off` 就在列表靠后。如果高亮停在那行时按电源键，表现就是"一按就黑屏关机"，非常像"电源键是关机键"。**按之前必须看清高亮在哪一行。**

菜单项（实测）：

```
 1. Boot postmarketOS
 2. Other systems...
 3. Serial console shell (USB ttyACM)
 4. Enable USB mass storage
 5. Enable fastboot mode
 6. Drop to shell
 7. Reset device
 8. Power off
 9. Dump environment
 a. Board info
 b. Dump bootargs
 0. Exit
```

### 3.2 UMS 在本机不可用

高亮确认在 `4. Enable USB mass storage` 后按电源：

- 屏幕立刻变黑
- **整个 USB 设备从总线上消失**（`Get-Disk` 看不到、`Get-PnpDevice` 连幻影记录都不新增）
- 反复试了多次，也换过"直插主板后置 USB 口、不经 hub"，结果相同

结论：这个 U-Boot 版本（u-boot-marble v20261008）的 UMS gadget 在本机起不来。
**所以手册里"导出 U 盘 → 跑 marble-install"这条路走不通。**

---

## 4. 替代方案：GPT 手术 + fastboot 按分区名烧写

既然拿不到整盘，就分两步：

### 4.1 在 Android 里直接改 GPT（`scripts/D0-make-gpt.py`）

思路：把 `userdata` 的 GPT 表项替换成 `esp`(1GiB) + `pmos`(剩余)，主/备 GPT 都改，CRC 重算。

```bash
# 手机（root）：dump 原始 GPT（LBA0..33，4096 字节扇区）
dd if=/dev/block/sda bs=4096 count=34 of=/data/local/tmp/gptwork/gpt-orig.bin

# PC：离线算出新表
python3 D0-make-gpt.py --gpt gpt-orig.bin --disk-size 253461790720 \
        --sector-size 4096 --esp-size 1G --prefix gpt-new --yes

# 手机（root）：写备用表 → 写主表 → flush
dd if=gpt-new-backup.bin  of=/dev/block/sda bs=4096 seek=61880317 conv=notrunc
dd if=gpt-new-primary.bin of=/dev/block/sda bs=4096 seek=1        conv=notrunc
blockdev --flushbufs /dev/block/sda
```

实测布局（本机 256GB 版）：

| 分区 | LBA | 大小 |
|---|---|---|
| `esp` | 3107328 – 3369471 | 1.00 GiB |
| `pmos` | 3369472 – 61880063 | 223.20 GiB |

校验（`scripts/D4-verify-gpt.py`）：主/备头 CRC、表 CRC、备份表与主表字节一致、`userdata` 已消失、`esp`/`pmos` 存在且 1MiB 对齐 —— 全部通过。

> 安全性：GPT 头在 LBA0..33，备份在磁盘末尾，**都不属于任何分区**，改它们不会破坏文件系统。
> 改完后 Android 无法启动（它依赖 userdata），这是预期行为（本来就要清空）。

### 4.2 用 fastboot 按分区名烧写

ABL 会读取新 GPT，`fastboot getvar partition-size:esp` 返回 `0x40000000`（1GiB），说明认到了。

```bash
fastboot flash esp  xiaomi-marble-boot.img     # 512MB，raw 直烧，OKAY
fastboot flash pmos root.simg                  # 必须先转 sparse，见下
fastboot set_active b
fastboot reboot
```

**坑：`pmos` 不能直接烧 raw ext4**

```
Invalid sparse file format at header magic
Sending sparse 'pmos' 1/1 (726925 KB)  OKAY
Writing 'pmos'                        OKAY [0.010s]
```

镜像 997MB 超过 ABL 单块上限（768MB），fastboot 会按 sparse 分块发送，但文件不是 sparse →
只发了 710MB、`Writing` 只用 0.01s，**数据被截断**。

`deviceinfo_flash_sparse="true"` 就是提示：要烧 sparse。

```bash
img2simg xiaomi-marble-root.img root.simg 1048576   # 1MiB 块
# 往返验证：simg2img root.simg back.raw 后 sha256 必须与原文件一致
fastboot flash pmos root.simg
# Sending sparse 'pmos' 1/2 (784384 KB) OKAY
# Sending sparse 'pmos' 2/2 (16384 KB)  OKAY
```

---

## 5. 首次启动

重启后 USB 上出现：

```
18D1:D001  serial=POSTMARKETOS   <- pmOS 的 USB 网络 gadget
```

`serial=POSTMARKETOS` 说明内核 + initramfs + 根文件系统全部加载成功。

---

## 6. Windows 接不上手机的 USB 网卡

手机暴露的是 **CDC-ECM**（`USB\Class_02&SubClass_06`），而 Windows 自带驱动只有：

| Windows INF | 支持 |
|---|---|
| `usbnet.inf` | 只匹配 `Class_02&SubClass_0c&Prot_07`（**CDC-NCM**） |
| `rndiscmp.inf` | 只匹配 RNDIS / `Class_EF&SubClass_04&Prot_01` |

**Windows 从来没有 CDC-ECM 驱动** —— 这是历史限制，不是配置问题。

另外 Windows 一开始把这个设备错绑成 "Android Composite ADB Interface"（因为 `android_winusb.inf` 里有 `VID_18D1&PID_D001`）。删掉该 INF 后露出真身：`RNDIS [Error]`。

### 最终解法：用 VMware 里的 Ubuntu 虚拟机烧写 + 靠 Wi-Fi 通信

1. 在 Ubuntu 虚拟机里把镜像预先写好（Wi-Fi 配置 + buffyboard + sshd）
2. 虚拟机把手机 USB 透传（VMware → Removable Devices → Connect）
3. 虚拟机里 `fastboot flash esp/pmos`（Linux 的 fastboot 不需要 Windows 驱动）
4. 手机启动后自动连 Wi-Fi
5. Windows 直接 `ssh marble@<PHONE_IP>`

> 顺带：`usbipd-win` 的 msi 下载被网络拦截（只返回 92 字节），所以没法走 WSL USB 直通。

---

## 7. 系统起来后修的四个问题

### 7.1 DNS 全挂

现象：`apk add` 报 `DNS: transient error`；`getent hosts` 失败；但 `ping 223.5.5.5` 正常。

原因：`/etc/resolv.conf` → `systemd-resolved` 的 stub（`127.0.0.53`），但 stub 不响应查询
（`nslookup xxx 223.5.5.5` 直接问外部 DNS 是好的）。

修复：换成静态文件

```bash
sudo rm -f /etc/resolv.conf
printf 'nameserver 223.5.5.5\nnameserver 223.6.6.6\n' | sudo tee /etc/resolv.conf
```

之后 `apk update` 正常（37511 个包）。

### 7.2 根分区没扩容

镜像里 rootfs 只有 997MB，分区有 223.2G：

```bash
sudo resize2fs /dev/sda34       # online resize
# 947.3M -> 216.4G，可用 206.7G
```

### 7.3 电池路径不是 `/sys/class/power_supply/battery`

本机是 **`/sys/class/power_supply/qcom-battmgr-bat`**：

```
capacity=100  status=Full  current_now=257000(µA)  voltage_now=4421000(µV)  power_now=1136197(µW)
```

→ 面板脚本已改成按 `type=Battery` 自动发现，不再写死路径。

### 7.4 触摸键盘 buffyboard 没启用

`/usr/bin/buffyboard` 在，但**没有任何 systemd 单元启动它**，所以屏幕上只有 `marble login:`，点屏幕没有键盘。

→ 新增 `buffyboard.service` 并 enable：

```ini
[Unit]
Description=buffyboard on-screen keyboard
After=getty@tty1.service
[Service]
ExecStart=/usr/bin/buffyboard --config /usr/share/buffyboard/buffyboard.conf
Restart=always
[Install]
WantedBy=multi-user.target
```

---

## 8. 状态面板：与纸面方案的差异

| 纸面方案 | 实际 |
|---|---|
| `cog`（WPE WebKit kiosk 浏览器） | **仓库里没有这个包** → 改用 **chromium**（297MB）。`netsurf` 虽只有 5.9MB，但不支持 CSS grid/JS，面板会渲染错 |
| `cage` 直接起 | `XDG_RUNTIME_DIR is not set` → 必须显式设置 |
| — | `libseat` 只有 `logind/seatd/noop` 后端，系统服务不属于带 seat 的 logind 会话 → **必须装 `seatd`** |
| — | `seatd` 包**不带 systemd 单元**（Alpine 走 OpenRC）→ 自建 `seatd.service`（`ExecStart=/usr/bin/seatd -g root`） |
| — | 服务以 root 跑 → chromium 必须 `--no-sandbox` |
| 面板用 `setTimeout(reload)` | 改用 `<meta http-equiv="refresh" content="2">`，不依赖 JS |
| — | `cage`/`chromium` 在 **`/usr/sbin/`**，不是 `/usr/bin/` |

最终单元（见 `out/dashboard/marble-dashboard-kiosk.service`）：

```ini
Environment=XDG_RUNTIME_DIR=/run/marble-dashboard/xdg
ExecStart=/usr/sbin/cage -- /usr/sbin/chromium --kiosk --no-sandbox ...
```

### 熄屏/唤醒实测

`marble-screen-idle.sh` 直接 `dd` 读 `/dev/input/eventN`（阻塞读 24 字节 `struct input_event`），不依赖任何 Wayland 空闲协议。

> 注意：脚本里设备节点是 **`/dev/input/eventN`**，第一版写成 `/dev/eventN` → 一个设备都找不到。已修。

日志证明工作正常：

```
15:27:12 空闲 120s >= 120s，熄屏
15:28:55 检测到输入，亮屏
15:31:57 空闲 120s >= 120s，熄屏
15:32:00 检测到输入，亮屏
```

电源键：`/etc/systemd/logind.conf.d/99-marble-powerkey.conf` 里 `HandlePowerKey=ignore`，
但**必须重启 logind 才生效**（`systemctl restart systemd-logind`，会断 SSH）。
验证：`busctl get-property ... HandlePowerKey` → `s "ignore"`。

---

## 9. 最终状态

```
marble · Nura edge · Linux 7.2.8 · aarch64 · 8 核 · 10.2G 内存
Wi-Fi wlan0 <PHONE_IP>/24（自动连接 <WIFI_SSID>）
根分区 216.4G（可用 206.7G）
温度 40°C 左右（待机）
电池 100% Full，功率 0.03W
服务：sshd / NetworkManager / seatd / marble-dashboard /
      marble-dashboard-kiosk / marble-screen-idle / avahi-daemon 全部 active
failed units：无
```

面板截图：1080×2400，深色，显示负载/内存/电池/网络/6 路温度/磁盘/服务状态。

---

## 9.5 追加功能（同一台机器，真机验证）

### 9.5.1 电源键切换熄屏（DPMS）

**关键结论：本机 AMOLED 只能靠 DRM DPMS 关屏，写 `brightness=0` 无效。**

- 写 `brightness=0` 后 **0.5 秒内就被改回 1842** —— 这个面板亮度是 DRM connector 属性，
  任何 DRM 提交（chromium 每 2 秒刷新页面就会提交）都会恢复默认值
- 一开始还加过"亮度看护"每秒把 0 压回去，结果变成 **屏幕一直在闪**（0/1842 反复横跳）
- 正确做法：`wlr-randr --output DSI-1 --off/--on`（实测 `Enabled: no/yes`）

复现路径（都是真机踩出来的）：

| 现象 | 原因 | 修法 |
|---|---|---|
| 按电源键没反应 | 熄屏分支没写 `blanked-at`，松开事件立刻把屏点亮 | 记录熄屏时间戳 + 只在 `value=1` 时算一次切换 |
| 屏幕一直闪 | 亮度看护与 DRM 提交在抢 brightness | 删掉看护，改用 DPMS |
| `cage` 占了所有 `/dev/input/*` | 实测只是 open 没有 EVIOCGRAB，不影响 dd 读取 | 无需处理（`WLR_LIBINPUT_NO_DEVICES=1` 在 cage 0.3.1 无效） |

### 9.5.2 平板模式（phosh）

同一套系统上装 phosh，**不用重刷**（内核/驱动已在跑）：

```bash
sudo apk add postmarketos-ui-phosh     # 约 493 个包 / +734MB，实测 10 分 44 秒
```

坑：

| 现象 | 原因 | 修法 |
|---|---|---|
| `phoc: connector DSI-1: Atomic commit failed: Resource busy` | `getty@tty1` 上的 fbcon 仍持有 DRM master | 切平板模式前必须 `systemctl disable --now getty@tty1` |
| phosh 起不来（一直停在 phrog 登录器） | `[initial_session]` 没生效 | 直接把 `[default_session]` 的 command 改成 `phosh-session`、user 改成 `marble`（自动登录） |
| 登录器数字键盘打不出密码 | phrog 默认只给数字键位 | 密码用纯数字；或直接自动登录 |
| 截图失败 `failed to create display` | `/run/user/110`、`/run/user/10000` 是 700，非 root 看不到 socket | 用 root + 正确的 `XDG_RUNTIME_DIR`/`WAYLAND_DISPLAY` 跑 `grim` |

两种模式互斥（都要独占 DRM / 都用 tty7），用 `marble-mode.sh` 切换：

```bash
marble-mode.sh server    # 无桌面 + 状态面板 + 电源键熄屏（省电）
marble-mode.sh tablet    # phosh 图形桌面（自动登录）
marble-mode.sh status
```

实测结果：phosh 桌面正常显示（Wi-Fi 已连、蓝牙开、电池 98%、亮度音量滑块可用），
截图见 `docs/phosh-desktop-screenshot.png`；登录器界面见 `docs/phrog-greeter-screenshot.png`。

---

### 9.5.3 把状态面板做成 phosh 里的 App

面板本质是个 HTML，所以做成「无浏览器边框的独立窗口 + 应用列表图标」最省事：

| 文件 | 装到 | 作用 |
|---|---|---|
| `marble-monitor` | `/usr/local/bin/` | 启动器脚本：调 `epiphany --new-window file:///run/marble-dashboard/index.html` |
| `marble-monitor.desktop` | `/usr/share/applications/` | phosh 应用列表里的入口（`Icon=marble-monitor`） |
| `marble-monitor.svg` | `/usr/share/icons/hicolor/scalable/apps/` | 自绘图标（手机 + 柱状图 + 温度点） |

实测坑：

| 现象 | 原因 | 修法 |
|---|---|---|
| 图标显示成「?」 | `Icon=utilities-system-monitor` 这个图标名在本机主题里不存在 | 自带 SVG 图标 + `gtk-update-icon-cache` |
| 打开后屏幕全黑、phoc 狂报 `Atomic commit failed: Resource busy` | **chromium 会抢 DRM master** | 换 **epiphany**（纯 Wayland 客户端，不碰 DRM） |
| `epiphany --application-mode URL` 报 `Invalid desktop file` | 这个版本的 `-a` 要求传 `.desktop` 而不是 URL | 用 `epiphany --new-window URL` |
| 从 SSH 里 `setsid sudo ... &` 启动 GUI 会把 SSH 通道挂住 | sudo 继承了终端的 fd | 用 `systemd-run --uid=10000 --setenv=XDG_RUNTIME_DIR=... --setenv=WAYLAND_DISPLAY=...` |
| 截图全是锁屏、`loginctl unlock-sessions` 无效 | phosh 的锁屏不归 logind 管 | 只能在屏幕上滑解锁；或先 `gsettings set org.gnome.desktop.screensaver lock-enabled false` |

面板生成器（`marble-dashboard.service`）在**两种模式下都常驻**，App 靠它每 2 秒刷新数据。

---

### 9.5.4 保证 SSH 永不掉线（禁止挂起）

**锁屏不影响 SSH** —— 实测锁屏期间 `ping` 0% 丢包、22 端口开放、`ssh` 正常登录。
锁屏只是 phosh 画的一层 UI，不碰 sshd 和网络。

真正的风险是**系统挂起**（suspend）会让网络断掉，所以全部封死：

```bash
# 1) 屏蔽所有睡眠 target
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 2) logind 空闲动作改成 ignore
/etc/systemd/logind.conf.d/99-marble-nosleep.conf:
[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandleSuspendKey=ignore

# 3) phosh/GSettings 里 AC 供电时不动休眠
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "nothing"

# 4) 顺便关掉自动锁屏
gsettings set org.gnome.desktop.screensaver lock-enabled false
```

> 副作用：平板模式下电源菜单里的「挂起」会失败。要让屏幕黑掉用 DPMS（服务器模式自动做，
> 平板模式下可以手动 `wlr-randr --off`），不影响 SSH。

---

## 10. 后续建议

- [x] ~~改密码~~ → 已改为 `<LOGIN_PASSWORD>`（纯数字，兼容 phrog 数字键盘）
- [x] ~~固化 DNS~~ → `/etc/resolv.conf` 静态 + NM `dns=none` + mask `systemd-resolved`
- [x] ~~电源键熄屏~~ → DPMS 方案，见 9.5.1
- [x] ~~装图形桌面~~ → phosh，见 9.5.2
- [ ] 电池管理：现在 98~100% 常充，建议定时插座或限充（手册第 7 节）
- [ ] 散热：加铜片/小风扇，满载时监控 `/sys/class/thermal`
- [ ] SSH 改公钥登录（现在还是密码）
- [ ] 把 Wi-Fi 密码从 git 历史里清掉（`nmconnection` 里是明文 PSK）
- [ ] 若想让默认开机就是平板模式：`systemctl enable greetd && systemctl disable marble-dashboard-kiosk marble-screen-idle`
- [ ] 电池管理：现在 100% 常充，建议定时插座或限充（手册第 7 节）
- [ ] 散热：加铜片/小风扇，满载时监控 `/sys/class/thermal`
- [ ] 固化 DNS：把静态 `resolv.conf` 写进镜像，或修好 systemd-resolved
- [ ] 把 Wi-Fi 密码从 git 历史里清掉（当前写在 `nmconnection` 里，含明文 PSK）
- [ ] 考虑把 `esp` 的 initramfs 里的 USB gadget 从 ECM 改成 NCM，方便 Windows 直接连
