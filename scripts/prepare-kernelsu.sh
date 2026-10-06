#!/usr/bin/env bash
# ============================================================================
# prepare-kernelsu.sh —— 拉取 KernelSU 并应用本项目的 4.19 适配补丁
#
# 关键：KernelSU 的版本号是 KSU_VERSION = 30000 + git rev-list --count HEAD，
#       所以必须固定在 BASE_COMMIT 上、并以补丁方式改动，
#       否则版本号变化会被 Manager 拒绝（manager too low / kernel too low）。
#
# 用法：
#   scripts/prepare-kernelsu.sh
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$ROOT/kernel/msm-4.19}"
KSU_REPO="${KSU_REPO:-https://github.com/tiann/KernelSU.git}"
KSU_PATCH="$ROOT/patches/kernelsu/0001-android-4.19-support.patch"
BASE_FILE="$ROOT/patches/kernelsu/BASE_COMMIT.txt"
EXPECTED_VERSION="${EXPECTED_VERSION:-32584}"

log()  { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$KERNEL_DIR" ] || die "找不到内核树：$KERNEL_DIR（先运行 scripts/prepare-tree.sh）"
[ -f "$BASE_FILE" ]  || die "缺少 $BASE_FILE"
BASE="$(tr -d '[:space:]' < "$BASE_FILE")"

KSU_DIR="$KERNEL_DIR/KernelSU"

# 1) 取得固定基线的 KernelSU
if [ -d "$KSU_DIR/.git" ]; then
    log "KernelSU 已存在，切换到基线提交"
    git -C "$KSU_DIR" fetch --all --tags --quiet || true
else
    log "clone KernelSU"
    git clone "$KSU_REPO" "$KSU_DIR"
fi
git -C "$KSU_DIR" checkout --quiet --detach "$BASE"

# 2) 应用 4.19 适配补丁（补丁路径相对于 KernelSU 仓库根）
if git -C "$KSU_DIR" apply --check "$KSU_PATCH" >/dev/null 2>&1; then
    git -C "$KSU_DIR" apply "$KSU_PATCH"
    log "已应用 $(basename "$KSU_PATCH")"
elif git -C "$KSU_DIR" apply --check --reverse "$KSU_PATCH" >/dev/null 2>&1; then
    log "补丁已应用过，跳过"
else
    die "补丁无法应用，请检查 KernelSU 是否停在 $BASE（当前 $(git -C "$KSU_DIR" rev-parse --short HEAD)）"
fi

# 3) drivers/kernelsu -> ../KernelSU/kernel 软链接
ln -sfn ../KernelSU/kernel "$KERNEL_DIR/drivers/kernelsu"
log "已创建软链接 drivers/kernelsu -> ../KernelSU/kernel"

# 4) 校验内核树里的接入点（由 patches/kernel/0001-*.patch 提供）
grep -q 'drivers/kernelsu/Kconfig' "$KERNEL_DIR/drivers/Kconfig" \
    || warn "drivers/Kconfig 里缺 source \"drivers/kernelsu/Kconfig\"（内核补丁是否已应用？）"
grep -q 'kernelsu' "$KERNEL_DIR/drivers/Makefile" \
    || warn "drivers/Makefile 里缺 obj-\$(CONFIG_KSU) += kernelsu/（内核补丁是否已应用？）"

# 5) 版本号自检
COUNT="$(git -C "$KSU_DIR" rev-list --count HEAD)"
VERSION="$((30000 + COUNT))"
log "KernelSU: $(git -C "$KSU_DIR" rev-parse --short HEAD) / 提交数 $COUNT → KSU_VERSION=$VERSION"
if [ "$VERSION" != "$EXPECTED_VERSION" ]; then
    warn "KSU_VERSION 与预期 ($EXPECTED_VERSION) 不一致 —— 请使用匹配的 Manager，或检查是否误改了 KernelSU 的提交历史"
else
    log "版本号正确：配套 Manager = KernelSU_v3.2.5-59-g62e88ca9_${VERSION}"
fi
