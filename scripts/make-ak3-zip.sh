#!/usr/bin/env bash
# ============================================================================
# make-ak3-zip.sh —— 用编译好的 Image 打一个 AnyKernel3 刷机包
#
# AnyKernel3 的脚本与预编译工具从上游 osm0sis/AnyKernel3 拉取（BSD-3-Clause 风格，
# 见 release/AnyKernel3_LICENSE.txt），本仓库只保留设备相关的 anykernel.sh。
# zip 里**不包含**原厂 ramdisk/dtb：刷机时从设备自身的 boot 分区读取。
#
# 用法：
#   scripts/make-ak3-zip.sh <Image> [版本号] [输出目录]
#   scripts/make-ak3-zip.sh kernel/msm-4.19/out/arch/arm64/boot/Image v1.0.0 out/
#
# 产物：
#   <输出目录>/Reno4_5G_KSU_kernel_<版本号>.zip
#   <输出目录>/SHA256SUMS
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${1:-}"
VERSION="${2:-$(date +%Y%m%d)}"
OUTDIR="${3:-$ROOT/out}"
AK3_REPO="${AK3_REPO:-https://github.com/osm0sis/AnyKernel3.git}"

log()  { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "$IMAGE" ] && [ -f "$IMAGE" ] || die "用法: $0 <Image> [版本号] [输出目录]"
[ -f "$ROOT/release/anykernel.sh" ] || die "缺少 release/anykernel.sh"
mkdir -p "$OUTDIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log "拉取 AnyKernel3 模板（$AK3_REPO）"
git clone --quiet --depth 1 "$AK3_REPO" "$WORK/ak3"
rm -rf "$WORK/ak3/.git"

log "写入设备相关配置与内核"
cp "$ROOT/release/anykernel.sh" "$WORK/ak3/anykernel.sh"
cp "$ROOT/release/AnyKernel3_LICENSE.txt" "$WORK/ak3/LICENSE"
# 版本号写入 kernel.string（便于在 recovery 日志里辨认）
sed -i "s|^kernel.string=.*|kernel.string=OPPO Reno4 5G (PDPM00, SM7250/lito) 4.19.157 kernel, KernelSU, ${VERSION}|" \
    "$WORK/ak3/anykernel.sh"
mkdir -p "$WORK/ak3/modules/system/lib/modules" "$WORK/ak3/ramdisk"
cp "$IMAGE" "$WORK/ak3/Image"

ZIP="$OUTDIR/Reno4_5G_KSU_kernel_${VERSION}.zip"
log "打包：$ZIP"
( cd "$WORK/ak3" && zip -q -r9 "$ZIP" . -x '*.git*' )

log "校验和"
( cd "$OUTDIR" && sha256sum "$(basename "$ZIP")" > SHA256SUMS )

ls -lh "$ZIP" "$OUTDIR/SHA256SUMS"
cat "$OUTDIR/SHA256SUMS"
echo
echo "发布时把这两个文件一起上传到 Release，并在说明里写明对应的源码 commit。"
