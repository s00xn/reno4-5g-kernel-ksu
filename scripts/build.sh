#!/usr/bin/env bash
# ============================================================================
# build.sh —— 编译 OPPO Reno4 5G (SM7250 / lito) 内核 4.19.157
#
# 前置：scripts/prepare-tree.sh、scripts/fetch-toolchain.sh、scripts/prepare-kernelsu.sh
#
# 用法：
#   scripts/build.sh
#
# 可用环境变量覆盖：
#   KERNEL_DIR     内核树路径           (默认 <repo>/kernel/msm-4.19)
#   TOOLCHAIN_DIR  工具链路径           (默认 <repo>/toolchain)
#   DEFCONFIG      defconfig 相对路径    (默认 vendor/stock_lito_defconfig)
#   OUT_DIR        输出目录              (默认 <KERNEL_DIR>/out)
#   JOBS           并行度                (默认 nproc)
#   KCFLAGS        额外编译参数          (默认 -Wno-error=strict-prototypes)
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$ROOT/kernel/msm-4.19}"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$ROOT/toolchain}"
DEFCONFIG="${DEFCONFIG:-vendor/stock_lito_defconfig}"
OUT_DIR="${OUT_DIR:-$KERNEL_DIR/out}"
JOBS="${JOBS:-$(nproc)}"
# OPPO vendor 代码里有大量旧式 foo() 定义，clang 的 -Werror 会报 strict-prototypes
KCFLAGS="${KCFLAGS:--Wno-error=strict-prototypes}"

CLANG_BIN="$TOOLCHAIN_DIR/clang-r399163b/bin"
GCC64_BIN="$TOOLCHAIN_DIR/aarch64-linux-android-4.9/bin"
GCC32_BIN="$TOOLCHAIN_DIR/arm-linux-androideabi-4.9/bin"

log() { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$KERNEL_DIR" ]                || die "找不到内核树：$KERNEL_DIR（先运行 scripts/prepare-tree.sh）"
[ -x "$CLANG_BIN/clang" ]           || die "找不到 clang：$CLANG_BIN/clang（先运行 scripts/fetch-toolchain.sh）"
[ -x "$GCC64_BIN/aarch64-linux-android-gcc" ] || die "找不到 aarch64 GCC：$GCC64_BIN"
[ -x "$GCC32_BIN/arm-linux-androideabi-gcc" ] || die "找不到 arm32 GCC：$GCC32_BIN"
[ -f "$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG" ] || die "找不到 defconfig：$DEFCONFIG"
if [ ! -e "$KERNEL_DIR/drivers/kernelsu" ]; then
    die "缺少 drivers/kernelsu（先运行 scripts/prepare-kernelsu.sh）"
fi

export ARCH=arm64
export PATH="$CLANG_BIN:$GCC64_BIN:$GCC32_BIN:$PATH"

MAKE_CMD=(make -C "$KERNEL_DIR" O="$OUT_DIR" CC=clang
          CROSS_COMPILE=aarch64-linux-android-
          CROSS_COMPILE_ARM32=arm-linux-androideabi-
          CLANG_TRIPLE=aarch64-linux-gnu-
          KCFLAGS="$KCFLAGS")

log "defconfig: $DEFCONFIG"
"${MAKE_CMD[@]}" "$DEFCONFIG"

log "编译（-j$JOBS，KCFLAGS=\"$KCFLAGS\"）"
"${MAKE_CMD[@]}" -j"$JOBS"

log "完成："
ls -lh "$OUT_DIR/arch/arm64/boot/Image" 2>/dev/null || die "没有生成 Image，请检查上面的日志"
echo
echo "  下一步：scripts/repack_bootimg.sh <你的原厂 boot.img> $OUT_DIR/arch/arm64/boot/Image new-boot.img"
