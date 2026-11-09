#!/usr/bin/env python3
"""
gpt-patch.py —— 在 PC 上改写 marble LUN0 的 GPT，把 userdata 换成 esp + pmos

用途：当 U-Boot 的 USB mass storage 不可用时，绕过 UMS，
      由 PC 生成新的 GPT 扇区内容，再由手机端用 dd 写回裸盘。

分区算法与上游 marble-install 的 --layout single 完全一致：
    esp_start  = userdata.start
    pmos_start = align_down(userdata.start, 1MiB) + esp_size
    pmos_end   = align_down(last_usable_lba + 1, 1MiB) - 1
    userdata   -> 删除
    esp        -> 类型 EFI System (C12A7328-...)，label "esp"
    pmos       -> 类型 Linux filesystem (0FC63DAF-...)，label "pmos"

输入：
    --gpt  从手机 dump 出来的原始扇区（LBA 0 起的连续字节，至少含主 GPT 头部+表）
    --disk-size  磁盘字节数（blockdev --getsize64 /dev/block/sda）
输出：
    <prefix>-primary.bin   要写到 LBA 1 起的连续扇区（头部 + 表）
    <prefix>-backup.bin    要写到备用表起点的连续扇区（表 + 头部）
    <prefix>-plan.json     各 LBA 与镜像 seek 偏移，供 dd 使用
"""
import argparse, json, struct, sys, uuid, zlib

HDR = struct.Struct("<8sIIIIQQQQ16sQIII")
HDR_KEYS = ("sig rev hsize hcrc rsv cur bak first last guid ents n esz ecrc").split()

EFI_SYSTEM = uuid.UUID("C12A7328-F81F-11D2-BA4B-00A0C93EC93B").bytes_le
LINUX_FS   = uuid.UUID("0FC63DAF-8483-4772-8E79-3D69D8477DE4").bytes_le

MIB = 1 << 20
GIB = 1 << 30


def parse_hdr(raw):
    return dict(zip(HDR_KEYS, HDR.unpack(raw[:92])))


def hdr_crc(raw, hsize):
    buf = bytearray(raw[:hsize])
    buf[16:20] = bytes(4)
    return zlib.crc32(bytes(buf))


def build_hdr(base, ents, cur, bak, ents_lba, hsize, ss):
    h = dict(base, cur=cur, bak=bak, ents=ents_lba, ecrc=zlib.crc32(bytes(ents)), hcrc=0)
    raw = bytearray(HDR.pack(*[h[k] for k in HDR_KEYS]))
    raw += bytes(hsize - len(raw))
    raw[16:20] = struct.pack("<I", zlib.crc32(bytes(raw)))
    return bytes(raw) + bytes(ss - len(raw))


def human(n):
    return f"{n / GIB:.2f} GiB" if n >= GIB else f"{n / MIB:.1f} MiB"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gpt", required=True, help="手机 dump 的原始 LBA0.. 扇区数据")
    ap.add_argument("--disk-size", required=True, type=int, help="磁盘字节数")
    ap.add_argument("--esp-size", default="1G")
    ap.add_argument("--prefix", default="gpt-new")
    ap.add_argument("--sector-size", type=int, default=4096)
    ap.add_argument("--yes", action="store_true", help="真的写出文件")
    args = ap.parse_args()

    ss = args.sector_size
    raw = open(args.gpt, "rb").read()

    # ---- 主头 ----
    hdr_raw = raw[ss:2 * ss]
    h = parse_hdr(hdr_raw)
    if h["sig"] != b"EFI PART":
        sys.exit("不是 GPT：LBA1 没有 EFI PART 签名")
    if hdr_crc(hdr_raw, h["hsize"]) != h["hcrc"]:
        sys.exit("主 GPT 头 CRC 不匹配")
    if h["esz"] != 128:
        sys.exit(f"意外的 entry size {h['esz']}")

    esec = -(-h["n"] * h["esz"] // ss)          # 表占多少扇区
    ents_off = h["ents"] * ss
    if len(raw) < ents_off + esec * ss:
        sys.exit("dump 的数据不够，读不到完整的分区表")

    ents = bytearray(raw[ents_off: ents_off + esec * ss][: h["n"] * h["esz"]])
    if zlib.crc32(bytes(ents)) != h["ecrc"]:
        sys.exit("主 GPT 分区表 CRC 不匹配")

    # ---- 列出现有分区 ----
    parts = []
    for i in range(h["n"]):
        e = ents[i * h["esz"]:(i + 1) * h["esz"]]
        if e[:16] == bytes(16):
            continue
        start, end, attr = struct.unpack("<QQQ", e[32:56])
        name = e[56:128].decode("utf-16le").split("\0")[0]
        parts.append(dict(slot=i, num=i + 1, start=start, end=end, name=name))

    print(f"磁盘 {args.disk_size} 字节，扇区 {ss}，共 {args.disk_size // ss} LBA")
    print(f"GPT 表 {h['n']} 项 × {h['esz']}B = {esec} 扇区，first_usable={h['first']} last_usable={h['last']}")
    for p in parts:
        print(f"  #{p['num']:<3} {p['name']:<24} LBA {p['start']:>10}-{p['end']:<10} "
              f"{human((p['end'] - p['start'] + 1) * ss)}")

    # ---- 找 userdata ----
    ud = next((p for p in parts if p["name"] == "userdata"), None)
    if not ud:
        sys.exit("没找到 userdata 分区")
    lastpart = max(parts, key=lambda p: p["end"])
    if lastpart["slot"] != ud["slot"]:
        sys.exit(f"userdata 不是最后一个分区（最后是 {lastpart['name']}），拒绝继续")

    if any(p["name"] in ("esp", "pmos") for p in parts):
        sys.exit("已存在 esp 或 pmos 分区，这是重装场景，本脚本不处理")

    # ---- 布局（与 marble-install --layout single 一致）----
    align = MIB // ss
    esp_n = (GIB if args.esp_size.upper().endswith("G") else MIB) // ss
    if args.esp_size.upper().endswith("G"):
        esp_n = int(float(args.esp_size[:-1]) * GIB) // ss

    top = (h["last"] + 1) // align * align
    esp_start = ud["start"]
    pmos_start = ud["start"] // align * align + esp_n
    pmos_end = top - 1

    if pmos_start <= esp_start:
        sys.exit("计算出的分区重叠")
    if (pmos_end - pmos_start + 1) * ss < 8 * GIB:
        sys.exit("pmos 剩余空间不足 8 GiB")

    print()
    print("计划：")
    print(f"  删除 userdata (#{ud['num']})  {human((ud['end'] - ud['start'] + 1) * ss)}")
    print(f"  新建 esp   LBA {esp_start}-{pmos_start - 1}  {human((pmos_start - esp_start) * ss)}")
    print(f"  新建 pmos  LBA {pmos_start}-{pmos_end}  {human((pmos_end - pmos_start + 1) * ss)}")

    # ---- 改表 ----
    esz = h["esz"]
    ents[ud["slot"] * esz:(ud["slot"] + 1) * esz] = bytes(esz)

    def free_slot():
        for i in range(h["n"]):
            if ents[i * esz:i * esz + 16] == bytes(16):
                return i
        sys.exit("GPT 没有空闲表项")

    def entry(ptype, start, end, name):
        e = bytearray(esz)
        e[:16] = ptype
        e[16:32] = uuid.uuid4().bytes_le
        e[32:56] = struct.pack("<QQQ", start, end, 0)
        e[56:128] = name.encode("utf-16le").ljust(72, b"\0")
        return e

    s1 = free_slot()
    ents[s1 * esz:(s1 + 1) * esz] = entry(EFI_SYSTEM, esp_start, pmos_start - 1, "esp")
    s2 = free_slot()
    ents[s2 * esz:(s2 + 1) * esz] = entry(LINUX_FS, pmos_start, pmos_end, "pmos")
    print(f"  esp 表项 #{s1 + 1}，pmos 表项 #{s2 + 1}")

    # ---- 生成要写的字节 ----
    pad = bytes(esec * ss - len(ents))
    ents_padded = bytes(ents) + pad

    # 主：LBA1 = 头，LBA2.. = 表
    primary = build_hdr(h, ents, 1, h["bak"], h["ents"], h["hsize"], ss) + ents_padded

    # 备：表在 alt-ents..alt-1，头在 alt
    alt = h["bak"]
    bak_ents_lba = alt - esec
    backup = ents_padded + build_hdr(h, ents, alt, 1, bak_ents_lba, h["hsize"], ss)

    plan = dict(
        sector_size=ss,
        primary_lba=1,
        primary_bytes=len(primary),
        backup_lba=bak_ents_lba,
        backup_header_lba=alt,
        backup_bytes=len(backup),
        esp_start_lba=esp_start,
        esp_bytes=(pmos_start - esp_start) * ss,
        pmos_start_lba=pmos_start,
        pmos_bytes=(pmos_end - pmos_start + 1) * ss,
        esp_img_seek_bytes=esp_start * ss,
        pmos_img_seek_bytes=pmos_start * ss,
    )

    print()
    print("写入计划：")
    print(f"  primary : LBA {plan['primary_lba']}   {plan['primary_bytes']} 字节")
    print(f"  backup  : LBA {plan['backup_lba']}   {plan['backup_bytes']} 字节")
    print(f"  boot.img -> LBA {esp_start}  ({human(plan['esp_bytes'])} 可用, seek {plan['esp_img_seek_bytes']} 字节)")
    print(f"  root.img -> LBA {pmos_start}  ({human(plan['pmos_bytes'])} 可用, seek {plan['pmos_img_seek_bytes']} 字节)")

    # 校验：偏移必须 1MiB 对齐（dd bs=1M 需要）
    for k in ("esp_img_seek_bytes", "pmos_img_seek_bytes"):
        if plan[k] % MIB:
            sys.exit(f"{k} = {plan[k]} 不是 1MiB 对齐，dd bs=1M 不能用")

    if not args.yes:
        print("\n（dry-run，未写文件；加 --yes 才输出）")
        return

    open(f"{args.prefix}-primary.bin", "wb").write(primary)
    open(f"{args.prefix}-backup.bin", "wb").write(backup)
    json.dump(plan, open(f"{args.prefix}-plan.json", "w"), indent=2)
    print(f"\n已写出 {args.prefix}-primary.bin / -backup.bin / -plan.json")


if __name__ == "__main__":
    main()
