# OPPO Reno4 5G (PDPM00 / SM7250 "lito") — 4.19.157 kernel with KernelSU

面向 **OPPO Reno4 5G (PDPM00, Qualcomm SM7250 / lito)** 的内核源码发行版：基于 OPPO 官方
开源内核树，集成 [KernelSU](https://github.com/tiann/KernelSU)，并在 **SELinux enforcing**
状态下提供可用的 root。

本仓库是**设备专用发行版**（device-specific），不面向上游仓库合并。

## 特性

| 项目 | 说明 |
|---|---|
| 内核 | 4.19.157-perf（`4.19.157-perf+ ... clang 11.0.5`） |
| 平台 | Qualcomm SM7250 / lito（OPPO 内部名 Simba / Reno4 5G） |
| root | KernelSU，仅集成其 `kernel/` 目录（GPL-2.0-only），版本见下 |
| SELinux | **Enforcing** 下 root 可用；实现了完整的 4.19 非 GKI 策略注入，注入失败时才回退 permissive |
| 配置 | 原厂提取配置 + 必要开关（KSU/KPROBES），关闭 `CONFIG_MODULE_SIG`，禁用 `CONFIG_ARCH_LAGOON` |
| 工具链 | AOSP clang-r399163b (clang 11.0.5) + GCC 4.9 (aarch64/arm32) |

## 实测结果

| 检查项 | 结果 |
|---|---|
| `getenforce` | Enforcing |
| root shell 域 | `u:r:ksu:s0` |
| root 授权 | Manager `debug su` 成功，uid 0 |
| KernelSU 功能 | Feature 查询 / Module List / adb_root 安装均正常 |
| ksu 相关 AVC 拒绝 | 0 条 |

## 版本匹配（重要）

KernelSU 的版本号算法是 `KSU_VERSION = 30000 + git rev-list --count HEAD`，因此本仓库把
KernelSU 固定在一个确定的提交上，并用补丁方式引入改动：

- KernelSU 基线提交：`62e88ca9`（`rev-list --count` = 2584 → `KSU_VERSION = 32584`）
- 配套 Manager：`KernelSU_v3.2.5-59-g62e88ca9_32584`

> 若把 KernelSU 换成别的提交、或把它当普通目录拷进内核树（丢失 `.git`），版本号会变化并被
> Manager 拒绝（`manager too low` / `kernel too low`）。详见 `scripts/prepare-kernelsu.sh`。

## 仓库内容

```
patches/kernel/    内核改动补丁 + 新增文件（4.19 兼容回移、KernelSU 集成、defconfig）
patches/vendor/    vendor 树（devicetree / OPLUS 驱动）改动补丁
patches/kernelsu/  KernelSU 的 4.19 适配补丁（固定基线 62e88ca9）
scripts/           clone 官方树、下载工具链、构建、打包、提取 ksud
docs/              构建 / 刷机 / SELinux 4.19 实现说明 / 变更记录
base/              上游 base commit 与补丁应用顺序
```

本仓库**只包含补丁、脚本与文档**：官方内核树与 vendor 树（约 1.5 G）由 `scripts/prepare-tree.sh`
从 OPPO 官方仓库拉取后打补丁；1.8 G 的工具链由 `scripts/fetch-toolchain.sh` 下载（均不入库）。

## 快速开始

```bash
# 1) 拉取官方内核+vendor 树并打补丁
scripts/prepare-tree.sh

# 2) 下载工具链（clang + GCC 4.9，约 1.8 G）
scripts/fetch-toolchain.sh

# 3) 拉取 KernelSU 并应用 4.19 补丁
scripts/prepare-kernelsu.sh

# 4) 编译
scripts/build.sh

# 5) 用你自己设备的原厂 boot.img 重打包
scripts/repack_bootimg.sh <你的原厂boot.img> kernel/msm-4.19/out/arch/arm64/boot/Image new-boot.img
```

构建环境、依赖包与常见问题见 [`docs/BUILD.md`](docs/BUILD.md)；刷入与回退见 [`docs/FLASH.md`](docs/FLASH.md)。

## 许可

- 内核与 vendor 树的改动落在 GPL-2.0-only 文件上，按 **GPL-2.0-only** 发布
- 本仓库新增的脚本与文档：**GPL-2.0-only**
- 第三方组件（KernelSU、AnyKernel3、工具链等）的许可与来源见 [`NOTICE.md`](NOTICE.md)

## 免责声明

本项目为**非官方**社区作品，与 OPPO、Qualcomm、KernelSU 官方均无隶属或背书关系。
解锁 bootloader 会清空数据并可能失去保修；刷写 boot 分区有变砖风险；root/KernelSU 会降低
设备安全模型（本内核还关闭了模块签名校验）。**请在自有设备上自行承担风险使用。**
