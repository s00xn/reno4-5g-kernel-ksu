#!/usr/bin/env bash
# ============================================================================
# fetch-toolchain.sh —— 下载构建所需的工具链到 toolchain/（约 1.8 G，不入库）
#
#   clang : AOSP prebuilts clang-r399163b (clang 11.0.5, build 6875598)
#   GCC   : LineageOS prebuilts 4.9 (aarch64 / arm)，通过 git-lfs 获取
#
# 用法：
#   scripts/fetch-toolchain.sh
#
# 可选环境变量：
#   TOOLCHAIN_DIR   目标目录（默认 <repo>/toolchain）
#   CLANG_REV       AOSP prebuilts 的分支/引用（默认 master-kernel-build-2021）
#   GCC_BRANCH      LineageOS prebuilts 分支（默认 lineage-19.1）
#   CLANG_SHA256    若提供，则校验 clang 压缩包的 SHA256
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TC="${TOOLCHAIN_DIR:-$ROOT/toolchain}"
CLANG_REV="${CLANG_REV:-master-kernel-build-2021}"
GCC_BRANCH="${GCC_BRANCH:-lineage-19.1}"
CLANG_NAME="clang-r399163b"
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/${CLANG_REV}/${CLANG_NAME}.tar.gz"
GCC64_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9"
GCC32_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"

log() { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

mkdir -p "$TC"

# ---------------------------------------------------------------- clang
if [ -x "$TC/$CLANG_NAME/bin/clang" ]; then
    log "clang 已存在，跳过：$TC/$CLANG_NAME"
else
    log "下载 clang ($CLANG_NAME) ..."
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --retry 3 -o "$tmp/clang.tar.gz" "$CLANG_URL"
    if [ -n "${CLANG_SHA256:-}" ]; then
        echo "${CLANG_SHA256}  $tmp/clang.tar.gz" | sha256sum -c -
    else
        warn "未设置 CLANG_SHA256，跳过校验（内容可对照 AOSP prebuilts 的 manifest_6875598.xml）"
    fi
    mkdir -p "$TC/$CLANG_NAME"
    tar -xzf "$tmp/clang.tar.gz" -C "$TC/$CLANG_NAME"
    log "clang 解包完成：$TC/$CLANG_NAME"
fi

# ------------------------------------------------------------------ GCC
fetch_gcc() {
    local repo="$1" dest="$2" name="$3"
    if [ -x "$TC/$dest/bin/${name}-gcc" ]; then
        log "GCC 已存在，跳过：$TC/$dest"
        return 0
    fi
    if ! git lfs version >/dev/null 2>&1; then
        warn "缺少 git-lfs —— GCC prebuilt 仓库使用 LFS 存放二进制。"
        warn "请先安装：sudo apt install git-lfs && git lfs install"
        return 1
    fi
    log "克隆 GCC prebuilt：$dest（LFS，约 90–140 M）"
    git lfs install --local >/dev/null 2>&1 || true
    git clone --depth 1 -b "$GCC_BRANCH" "$repo" "$TC/$dest"
}

fetch_gcc "$GCC64_REPO" "aarch64-linux-android-4.9"   "aarch64-linux-android"
fetch_gcc "$GCC32_REPO" "arm-linux-androideabi-4.9"   "arm-linux-androideabi"

# ------------------------------------------- 修掉 python2 shebang（GPLv3 §5a）
log "修正 AOSP GCC/binutils wrapper 的 python2 shebang（记录于 NOTICE.md）"
fixed=0
while IFS= read -r -d '' f; do
    if head -n1 "$f" | grep -q '/usr/bin/python$'; then
        sed -i '1s|/usr/bin/python$|/usr/bin/python3|' "$f"
        fixed=$((fixed + 1))
    fi
done < <(find "$TC" -maxdepth 3 -type f -path '*/bin/*' -print0 2>/dev/null)
log "已修正 $fixed 个 wrapper 脚本"

log "完成。工具链目录：$TC"
ls -d "$TC"/*/ 2>/dev/null || true
