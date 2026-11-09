# 产物清单（大文件不入 git）

镜像文件共 **1.5 GB**，超过 GitHub 单文件 100 MB 限制，所以 `*.img` 已被 `.gitignore` 排除。
分发方式选一个：

- 传到 **GitHub Releases**（推荐，支持大附件）
- 网盘 / 对象存储
- 或者自己按 `BUILD.md` 重新构建

拿到文件后放在 `out/` 目录，然后：

```bash
cd out && sha256sum -c SHA256SUMS.txt
```

---

## 必须校验的四个文件

| 文件 | 大小（字节） | SHA256 |
|---|---|---|
| `boot-uboot.img` | 745 472 | `81d9e7bce88b43f39262198590ce686a0c6544585ab4dbe668a8c2b3deaadb00` |
| `xiaomi-marble-boot.img` | 536 870 912 | `d923ba24494614470b2f6d9161d7edfc23df3249455eb82e7019be16b114c487` |
| `xiaomi-marble-root.img` | 1 045 430 272 | `3f6a69877c76c481e7763df12a8d153e874dd731b53335a12381f925cfb45b18` ← 已含 Wi-Fi 配置 + buffyboard |
| `marble-install` | 24 466 | `7afca7f13ebbf1507c466ef093ffbe8a97eca4f9e740d1c2ad369262d1d1c9e1` |

> ⚠️ **`root.img` 不能直接 `fastboot flash`**：997MB 超过 ABL 单块上限（768MB），
> 会被当作 sparse 分块发送而截断（只写 710MB）。必须先转换：
>
> ```bash
> img2simg xiaomi-marble-root.img root.simg 1048576
> fastboot flash pmos root.simg      # 分 2 块，约 27 秒
> ```
>
> 转换后 `root.simg` ≈ 821 MB，`simg2img` 还原后 SHA256 必须与原文件一致（已验证）。

> ⚠️ 当前 `root.img` 里**含明文 Wi-Fi PSK**（`/etc/NetworkManager/system-connections/`），
> 分发镜像前请自行决定是否清掉。

> `boot-uboot.img` 的 SHA256 与上游 [u-boot-marble v20261008](https://github.com/iLtanaka/u-boot-marble/releases/tag/v20261008) 官方 release 完全一致，可直接从上游下载后核对。

---

## 镜像内部事实（便于核对是否拿到正确的包）

| 项目 | 值 |
|---|---|
| boot 文件系统 | ext2，块大小 4096，label `pmOS_boot`，UUID `e50977bc-e1de-4579-bd33-206e65807de4` |
| root 文件系统 | ext4，块大小 4096，label `pmOS_root`，UUID `855ced09-5f92-4f48-bb62-f435cc4d3157` |
| 内核 | `linux-xiaomi-marble` **7.2.8**-r7 |
| 固件 | `firmware-xiaomi-marble` 20261008-r0（99 个文件） |
| 已安装包数 | 391 |
| UI | `console`（无桌面） |
| 服务管理器 | systemd |

校验命令（不需要真机）：

```bash
blkid out/xiaomi-marble-boot.img              # 应显示 TYPE=ext2 LABEL=pmOS_boot
blkid out/xiaomi-marble-root.img              # 应显示 TYPE=ext4 LABEL=pmOS_root
dumpe2fs -h out/xiaomi-marble-root.img | grep -i 'Block size'   # 必须是 4096
debugfs -R "cat /extlinux/extlinux.conf" out/xiaomi-marble-boot.img
```

---

## 代码文件的校验和

脚本和文档改动频繁，校验和每次生成都会变，所以不在这里硬编码。
需要时生成：

```bash
cd out && find . -type f ! -name 'SHA256SUMS.txt' -printf '%P\n' | sort | xargs -d '\n' sha256sum > SHA256SUMS.txt
```
