#!/usr/bin/env python3
"""校验写入后的 GPT：主/备头部 CRC、表 CRC、esp/pmos 是否存在、userdata 是否已删"""
import struct, sys, zlib, uuid

HDR = struct.Struct("<8sIIIIQQQQ16sQIII")
KEYS = ("sig rev hsize hcrc rsv cur bak first last guid ents n esz ecrc").split()
EFI = uuid.UUID("C12A7328-F81F-11D2-BA4B-00A0C93EC93B").bytes_le
LFS = uuid.UUID("0FC63DAF-8483-4772-8E79-3D69D8477DE4").bytes_le
SS = 4096

raw = open(sys.argv[1], "rb").read()
bak = open(sys.argv[2], "rb").read() if len(sys.argv) > 2 else None

def hcrc(b, n):
    x = bytearray(b[:n]); x[16:20] = bytes(4); return zlib.crc32(bytes(x))

h = dict(zip(KEYS, HDR.unpack(raw[SS:SS+92])))
ok = True
print("=== 主 GPT 头 ===")
print(f"  signature      : {h['sig']}")
print(f"  hsize          : {h['hsize']}")
print(f"  current_lba    : {h['cur']}")
print(f"  alternate_lba  : {h['bak']}")
print(f"  first_usable   : {h['first']}")
print(f"  last_usable    : {h['last']}")
print(f"  entries        : {h['n']} × {h['esz']}B @ LBA {h['ents']}")

c = hcrc(raw[SS:SS+h['hsize']], h['hsize'])
print(f"  header CRC     : stored={h['hcrc']:#010x} calc={c:#010x} -> {'OK' if c == h['hcrc'] else 'FAIL'}")
ok &= (c == h['hcrc'])
ok &= (h['sig'] == b"EFI PART")

esec = -(-h['n'] * h['esz'] // SS)
ents = raw[h['ents']*SS: h['ents']*SS + esec*SS][: h['n']*h['esz']]
c2 = zlib.crc32(ents)
print(f"  entries CRC    : stored={h['ecrc']:#010x} calc={c2:#010x} -> {'OK' if c2 == h['ecrc'] else 'FAIL'}")
ok &= (c2 == h['ecrc'])

print()
print("=== 分区表 ===")
found = {}
for i in range(h['n']):
    e = ents[i*h['esz']:(i+1)*h['esz']]
    if e[:16] == bytes(16):
        continue
    s, t, a = struct.unpack("<QQQ", e[32:56])
    name = e[56:128].decode("utf-16le").split("\0")[0]
    typ = "EF00" if e[:16] == EFI else ("8300" if e[:16] == LFS else e[:16].hex()[:8])
    print(f"  #{i+1:<3} {name:<14} LBA {s:>9}-{t:<9} {typ}")
    found[name] = (s, t)

print()
checks = []
checks.append(("userdata 已删除", "userdata" not in found))
checks.append(("esp 存在", "esp" in found))
checks.append(("pmos 存在", "pmos" in found))
if "esp" in found and "pmos" in found:
    esp, pmos = found["esp"], found["pmos"]
    checks.append(("esp == 1 GiB", (esp[1]-esp[0]+1)*SS == 1 << 30))
    checks.append(("esp 紧接 pmos", pmos[0] == esp[1]+1))
    checks.append(("esp 起点 1MiB 对齐", (esp[0]*SS) % (1<<20) == 0))
    checks.append(("pmos 起点 1MiB 对齐", (pmos[0]*SS) % (1<<20) == 0))
    print(f"  esp : LBA {esp[0]}-{esp[1]}  seek={(esp[0]*SS)}")
    print(f"  pmos: LBA {pmos[0]}-{pmos[1]}  seek={(pmos[0]*SS)}")

if bak:
    print()
    print("=== 备用 GPT ===")
    bh = dict(zip(KEYS, HDR.unpack(bak[-SS:][:92])))
    bc = hcrc(bak[-SS:][:bh['hsize']], bh['hsize'])
    bents = bak[:esec*SS][: h['n']*h['esz']]
    print(f"  signature      : {bh['sig']}")
    print(f"  current_lba    : {bh['cur']}  (应等于 {h['bak']})")
    print(f"  alternate_lba  : {bh['bak']}  (应等于 1)")
    print(f"  header CRC     : {'OK' if bc == bh['hcrc'] else 'FAIL'}")
    print(f"  entries 与主表一致: {'OK' if bents == ents else 'FAIL'}")
    ok &= (bc == bh['hcrc'])
    ok &= (bents == ents)
    ok &= (bh['cur'] == h['bak'] and bh['bak'] == 1)

print()
print("=== 结论 ===")
for name, r in checks:
    print(f"  {'OK  ' if r else 'FAIL'} {name}")
    ok &= r
print()
print("全部通过 ✅" if ok else "存在失败项 ❌")
sys.exit(0 if ok else 1)
