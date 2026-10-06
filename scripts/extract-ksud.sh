#!/usr/bin/env bash
# ============================================================================
# extract-ksud.sh —— 从 KernelSU Manager APK 中提取 ksud 并安装到设备
#
# 本仓库不附带 ksud 二进制（它属于 KernelSU userspace，GPL-3.0-or-later），
# 请自行准备与你内核版本匹配的 Manager APK，例如：
#   KernelSU_v3.2.5-59-g62e88ca9_32584-release.apk
#
# 用法：
#   scripts/extract-ksud.sh <Manager.apk>            # 提取 + 推送到设备
#   scripts/extract-ksud.sh <Manager.apk> --no-push  # 只提取到本地
#
# 安装位置：/data/adb/ksud（755 root:root, SELinux 类型 u:object_r:ksu_file:s0）
# 注意：不要对它执行 restorecon —— 部分系统的 file_contexts 会改坏该标签。
# ============================================================================
set -euo pipefail

die() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

APK="${1:-}"
PUSH=1
[ "${2:-}" = "--no-push" ] && PUSH=0
[ -n "$APK" ] && [ -f "$APK" ] || die "用法: $0 <Manager.apk> [--no-push]"

OUT="ksud_$(basename "$APK" .apk)"
unzip -p "$APK" lib/arm64-v8a/libksud.so > "$OUT" || die "APK 中没有 lib/arm64-v8a/libksud.so"
chmod 755 "$OUT"
echo ">>> 已提取：$OUT ($(stat -c%s "$OUT") 字节)"
sha256sum "$OUT"

if [ "$PUSH" = 0 ]; then
    echo ">>> --no-push：跳过设备安装"
    exit 0
fi

command -v adb >/dev/null 2>&1 || die "找不到 adb"
adb get-state >/dev/null 2>&1 || die "没有已连接的设备（adb devices 看看）"

echo ">>> 推送到 /data/adb/ksud"
adb push "$OUT" /data/adb/ksud
adb shell 'chmod 755 /data/adb/ksud && chown root:root /data/adb/ksud'
adb shell 'chcon u:object_r:ksu_file:s0 /data/adb/ksud || true'
adb shell 'ls -lZ /data/adb/ksud'
echo ">>> 完成"
