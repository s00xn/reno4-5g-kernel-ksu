# 刷机与验证（OPPO Reno4 5G / PDPM00）

> 风险自负：解锁 bootloader 会清空数据、失去保修；刷写 boot 分区错误会变砖。
> 请先确认机型为 **OPPO Reno4 5G (PDPM00 / SM7250 lito)**，不要跨机型刷。

## 1. 前置条件

- 设备已解锁 bootloader（`fastboot flashing unlock`，会清空数据）
- 电脑已装 `adb` / `fastboot`
- **你自己的原厂 `boot.img`**：从与当前系统版本一致的官方固件包中提取，或用
  `adb shell su -c "dd if=/dev/block/by-name/boot of=/sdcard/boot.img"`（需已 root）导出。
  本仓库**不提供**原厂 `boot.img`（内含 OPPO 专有 ramdisk/dtb，不在 GPL 授权范围内）。
- 已按 `docs/BUILD.md` 构建出 `Image`，并用 `scripts/repack_bootimg.sh` 打包好新的 `boot.img`

## 2. 刷入

```bash
# 进入 fastboot
adb reboot bootloader

# 刷入（替换成你自己的文件名）
fastboot flash boot boot_Reno4_5G_KSU_enforcing.img

# 重启
fastboot reboot
```

### 备选：AnyKernel3 zip

把构建好的 `Image` 放进 AnyKernel3 模板（保留其 `LICENSE`），在 recovery 中刷入 zip。
这种方式的好处是 zip 只带内核，ramdisk 从设备自身读取，不含任何原厂专有文件。

## 3. 刷后验证

```bash
adb shell getenforce            # 期望：Enforcing
adb shell su -c id              # 期望：uid=0(root)，且域为 u:r:ksu:s0
adb shell dmesg | grep -i avc   # 期望：ksu 相关 AVC 为 0 条
```

KernelSU Manager 版本需与内核匹配：内核 `KSU_VERSION=32584` ↔ Manager
`KernelSU_v3.2.5-59-g62e88ca9_32584`。若 Manager 报版本不匹配，请更换对应版本。

### 安装 `ksud`

`/data/adb/ksud` 需要从 KernelSU Manager APK 中提取（本仓库不附带该二进制）：

```bash
scripts/extract-ksud.sh KernelSU_v3.2.5-59-g62e88ca9_32584-release.apk
# 脚本会：解包 APK → 取 lib/arm64-v8a/libksud.so
#         → push 到 /data/adb/ksud（755 root:root, chcon u:object_r:ksu_file:s0）
```

## 4. 回退

```bash
adb reboot bootloader
fastboot flash boot <你的原厂 boot.img>
fastboot reboot
```

若只刷了 kernel 且系统仍可进入 recovery，也可直接刷回官方完整固件包。

## 5. 已知现象（非本次改动引入）

| 现象 | 说明 |
|---|---|
| 个别 `debug su` 子进程出现 SIGSYS | app 域的 seccomp 拦截了 `reboot`(142) 系统调用，发生在 ksud 安装超级调用 FD 的路径上。与 SELinux 模式无关，不影响 root 可用性 |
| 首次开机较慢 | 内核更换后首次启动会做一次 dalvik/缓存相关工作 |
| 部分银行/DRM 应用异常 | root/KernelSU 会降低安全模型，属预期 |

## 6. 安全提示

本内核为 KernelSU 关闭了 `CONFIG_MODULE_SIG`（模块签名校验失效），并在 SELinux 策略注入失败时
会回退到 permissive。请仅在自己的设备上使用，并自行评估风险。
