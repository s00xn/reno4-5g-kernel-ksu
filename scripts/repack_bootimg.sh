#!/usr/bin/env bash
# ============================================================================
# repack_bootimg.sh —— 用新内核替换原厂 boot.img 里的内核
#
# 只替换内核，保留 <原厂 boot.img> 自带的 ramdisk 与 dtb（因此不会分发任何
# 原厂专有文件：请使用你自己设备导出的原厂 boot.img）。
#
# 用法：
#   scripts/repack_bootimg.sh <原厂boot.img> <新内核Image> [输出.img]
#
# 需要 magiskboot（Linux x86_64）。用环境变量指定，或放进 PATH：
#   MAGISKBOOT=/path/to/magiskboot scripts/repack_bootimg.sh ...
#
# 注意：不要给 unpack 传 -h（会锁定旧尺寸，重打包后 kernel_size 不更新）。
# ============================================================================
set -euo pipefail

die() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

if [ $# -lt 2 ]; then
    echo "用法: $0 <原厂boot.img> <新内核Image> [输出.img]" >&2
    exit 2
fi

# magiskboot：优先环境变量，其次 PATH；都没有就明确失败
if [ -n "${MAGISKBOOT:-}" ]; then
    [ -x "$MAGISKBOOT" ] || die "MAGISKBOOT 不可执行：$MAGISKBOOT"
else
    MAGISKBOOT="$(command -v magiskboot || true)"
    [ -n "$MAGISKBOOT" ] || die "找不到 magiskboot：请设置 MAGISKBOOT=/path/to/magiskboot，或把它放进 PATH"
fi

STOCK="$(readlink -f "$1")"
KERNEL="$(readlink -f "$2")"
OUT="$(readlink -f "${3:-new-boot.img}")"

[ -f "$STOCK" ]  || die "找不到原厂 boot.img：$STOCK"
[ -f "$KERNEL" ] || die "找不到内核 Image：$KERNEL"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo ">>> unpack $STOCK"
(cd "$WORK" && "$MAGISKBOOT" unpack "$STOCK" >/dev/null)

echo ">>> 替换内核"
cp "$KERNEL" "$WORK/kernel"

echo ">>> repack -> $OUT"
(cd "$WORK" && "$MAGISKBOOT" repack "$STOCK" "$OUT" >/dev/null)

# 校验 header 里的 kernel_size 是否等于新内核长度
python3 - "$OUT" "$KERNEL" <<'PY'
import struct, sys
img, kern = sys.argv[1], sys.argv[2]
data = open(img, "rb").read()
header_ksz = struct.unpack("<I", data[8:12])[0]
real_ksz = len(open(kern, "rb").read())
print(f"header kernel_size = {header_ksz}")
print(f"新内核实际大小      = {real_ksz}")
if header_ksz != real_ksz:
    print("警告：header 的 kernel_size 与新内核大小不一致！", file=sys.stderr)
    sys.exit(1)
print("OK：kernel_size 一致")
PY

echo ">>> 完成：$OUT"
ls -lh "$OUT"
echo
echo "刷入（确认机型无误后再执行）："
echo "  adb reboot bootloader && fastboot flash boot '$OUT' && fastboot reboot"
