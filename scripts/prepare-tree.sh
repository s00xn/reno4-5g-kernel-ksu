#!/usr/bin/env bash
# ============================================================================
# prepare-tree.sh —— 拉取 OPPO 官方源码树并打上本项目的补丁
#
# 产出目录结构（与 OPPO 构建系统的期望一致）：
#   kernel/msm-4.19/   官方内核 + techpack/{camera,display,video} + 本项目内核补丁
#   vendor/            官方 modules 仓库的 vendor/ + 本项目 vendor 补丁
#
# 用法：
#   scripts/prepare-tree.sh            # 首次执行 / 已就绪则跳过
#   scripts/prepare-tree.sh --force    # 删除已拉取的树后重新来一遍
#
# 说明：官方内核与 vendor 树合计约 1.5 G，均不入库；补丁见 patches/。
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KERNEL_REPO="${KERNEL_REPO:-https://github.com/oppo-source/android_kernel_oppo_sm7250.git}"
MODULES_REPO="${MODULES_REPO:-https://github.com/oppo-source/android_kernel_modules_and_devicetree_oppo_sm7250.git}"
BRANCH="${BRANCH:-oppo/sm7250_s_12.1_reno4_5g}"
KERNEL_DIR="$ROOT/kernel/msm-4.19"
MODULES_SRC="$ROOT/.modules-src"

log()  { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

apply_patch() {   # apply_patch <工作目录> <补丁> [--git]
    local dir="$1" patch="$2"
    if [ ! -f "$patch" ]; then warn "补丁不存在：$patch"; return 0; fi
    if ( cd "$dir" && git apply --check --reverse "$patch" >/dev/null 2>&1 ); then
        log "补丁已应用过，跳过：$(basename "$patch")"
        return 0
    fi
    if ( cd "$dir" && git apply --check "$patch" >/dev/null 2>&1 ); then
        ( cd "$dir" && git apply "$patch" )
        log "已应用 $(basename "$patch")"
        return 0
    fi
    if ( cd "$dir" && patch -p1 --dry-run -s -i "$patch" >/dev/null 2>&1 ); then
        ( cd "$dir" && patch -p1 -s -i "$patch" )
        log "已应用（patch）$(basename "$patch")"
        return 0
    fi
    warn "补丁无法应用：$(basename "$patch")"
    return 1
}

if [ "${1:-}" = "--force" ]; then
    log "--force：删除已拉取的源码树"
    rm -rf "$KERNEL_DIR" "$ROOT/vendor" "$MODULES_SRC"
fi

# 1) 官方内核
if [ -d "$KERNEL_DIR/.git" ]; then
    log "内核树已存在，跳过 clone：kernel/msm-4.19"
else
    log "clone 官方内核（$BRANCH，浅克隆）..."
    mkdir -p "$ROOT/kernel"
    git clone --depth 1 -b "$BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"
fi

# 2) modules + devicetree 仓库
if [ -d "$MODULES_SRC/.git" ]; then
    log "modules 仓库已存在，跳过 clone：.modules-src"
else
    log "clone modules/devicetree 仓库（$BRANCH，浅克隆）..."
    git clone --depth 1 -b "$BRANCH" "$MODULES_REPO" "$MODULES_SRC"
fi

# 3) 并入 techpack/{camera,display,video}
for d in camera display video; do
    src="$MODULES_SRC/kernel/msm-4.19/techpack/$d"
    dst="$KERNEL_DIR/techpack/$d"
    if [ -d "$src" ] && [ ! -d "$dst" ]; then
        log "并入 techpack/$d"
        mkdir -p "$KERNEL_DIR/techpack"
        cp -a "$src" "$dst"
    fi
done

# 4) .gitignore 调整（让 techpack 子目录被跟踪）
apply_patch "$KERNEL_DIR" "$ROOT/patches/kernel/0000-techpack-gitignore.patch" \
    || die "techpack .gitignore 补丁应用失败"

# 5) vendor 树（拷出子目录，不带 .git）
if [ -d "$ROOT/vendor/qcom" ]; then
    log "vendor 已存在，跳过复制：vendor/"
else
    log "复制 vendor/（来自 modules 仓库）"
    mkdir -p "$ROOT/vendor"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --exclude '.git' "$MODULES_SRC/vendor/" "$ROOT/vendor/"
    else
        cp -a "$MODULES_SRC/vendor/." "$ROOT/vendor/"
        rm -rf "$ROOT/vendor/.git"
    fi
fi

# 6) 本项目补丁
apply_patch "$KERNEL_DIR" "$ROOT/patches/kernel/0001-reno4-5g-kernel-4.19-kernelsu.patch" \
    || die "内核补丁应用失败"
apply_patch "$ROOT/vendor" "$ROOT/patches/vendor/0001-lito-devicetree-and-oplus-fixes.patch" \
    || die "vendor 补丁应用失败"

# 7) 补丁新增的文件（defconfig 与头文件）
if [ -d "$ROOT/patches/kernel/new-files" ]; then
    log "拷入补丁新增文件（stock_lito_defconfig 等）"
    cp -a "$ROOT/patches/kernel/new-files/." "$KERNEL_DIR/"
fi

log "完成。"
echo
echo "  内核树 : $KERNEL_DIR   ($(git -C "$KERNEL_DIR" rev-parse --short HEAD 2>/dev/null || echo '?'))"
echo "  vendor : $ROOT/vendor"
echo "  下一步 : scripts/fetch-toolchain.sh 与 scripts/prepare-kernelsu.sh"
