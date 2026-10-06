# CHANGELOG

## v1.0.0 — OPPO Reno4 5G (PDPM00 / SM7250 lito) 4.19.157 + KernelSU

基线：

- 内核 `oppo-source/android_kernel_oppo_sm7250` @ `oppo/sm7250_s_12.1_reno4_5g` (`554371ac`)
- modules/devicetree `oppo-source/android_kernel_modules_and_devicetree_oppo_sm7250` @ 同分支 (`ee75bb30`)
- KernelSU `tiann/KernelSU` @ `62e88ca9`（`KSU_VERSION=32584`）

### 内核树

- 并入 techpack `camera` / `display` / `video`（来自 modules 仓库），并调整 `.gitignore`
  使这些子目录被跟踪
- 4.19 兼容回移（供 KernelSU 使用）：`path_mount` / `path_umount` 及其 `EXPORT`、
  `strscpy_pad`、`TASK_WORK` 的 `TWA_RESUME`、`seccomp_filter_release` 与
  `SECCOMP_ARCH_NATIVE_NR`、`uaccess` 的 `nofault` 别名、`selinux_inode` / `selinux_cred`
  内联、`MODULE_IMPORT_NS` 空宏、`fallthrough` 与 SCTP 中的 `fallthrough` 用法修正
- 新增转发头：`include/linux/minmax.h`、`include/linux/pgtable.h`、`include/uapi/linux/mount.h`
- `drivers/gpu/trace/Kconfig`：为 `TRACE_GPU_MEM` 恢复 prompt 与 `depends on TRACEPOINTS`
  （4.19 中它是无 prompt 的隐藏 bool，无法在 defconfig 中启用）
- `techpack/display/oplus/oplus_display_panel.c`：修正编译问题
- `OplusKernelEnvConfig.mk`：导出 `OPLUS_FEATURE_*`（kbuild 递归子 make 不继承变量）

### defconfig（`stock_lito_defconfig`）

- 以原厂提取配置为基础（替代会卡第一屏的调试开关全开的 `lito_defconfig`）
- 启用 `CONFIG_KSU`、`CONFIG_KPROBES`
- 启用 `CONFIG_TRACE_GPU_MEM`、`CONFIG_XFRM_MIGRATE`、`CONFIG_CRYPTO_CHACHA20POLY1305`
- 关闭 `CONFIG_MODULE_SIG`（保留 `CONFIG_MODVERSIONS`）
- 禁用 `CONFIG_ARCH_LAGOON`（官方 devicetree 缺 lagoon dtb 源）

### KernelSU 适配（`patches/kernelsu/`）

- **SELinux 策略注入（4.19 真正实现）**：`add_type()` 按 4.19 的 `flex_array` 语义重写；
  `apply_kernelsu_rules()` 改为模仿 `security_load_policy()` 的就地替换流程
  （`write_lock_irq` + `memcpy` + `latest_granting` + `avc_ss_reset` + `selnl/status/xfrm`
  通知），并完成 `ksu_dup_sepolicy` 在 4.19 上的首次跑通
- `sepolicy.h`：`#define selinux_policy selinux_ss`（`< 5.7`）
- `runtime/ksud_integration.c`：注入成功保持 enforcing，失败才 `setenforce(false)`
- 版本守卫与头文件修正：`selinux_hide.c`、`sucompat.c`、`file_wrapper.c`、
  `pkg_observer.c`、`allowlist.c`、`app_profile.c`、`supercall/dispatch.c`
- 详细原理见 `docs/SELINUX-4.19.md`

### vendor 树

- 20 个 devicetree 变体 Makefile：`dtb-$(CONFIG_ARCH_LITO) += kona-mtp.dtb` 改为 `dtb-$(CONFIG_ARCH_KONA) += ...`
  （本设备 DEFCONFIG 里 `CONFIG_ARCH_KONA` 未开启，这样可避免 20 个变体同时为 LITO 生成同名 `kona-mtp.dtb` 目标）
- `oplus/kernel/system/misc/bootloader_log.c`：去掉 `__init`
- `oplus/kernel/touchpanel/.../touchpanel_common_driver.c`：编译修正

### 脚本与文档

- `scripts/prepare-tree.sh`：按 OPPO 构建系统的目录期望拼装内核树与 `vendor/`
- `scripts/fetch-toolchain.sh`：固定上游地址下载 clang-r399163b 与 GCC 4.9
- `scripts/prepare-kernelsu.sh`：固定 KernelSU 提交并应用补丁（保持版本号不变）
- `scripts/build.sh`、`scripts/repack_bootimg.sh`、`scripts/extract-ksud.sh`
- `docs/BUILD.md`、`docs/FLASH.md`、`docs/SELINUX-4.19.md`、`SOURCE.md`、`NOTICE.md`
