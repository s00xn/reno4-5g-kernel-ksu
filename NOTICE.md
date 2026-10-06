# Third-Party Notices / 第三方组件与许可清单

本仓库（OPPO Reno4 5G / SM7250 "lito" 内核发行版）包含或引用了以下第三方作品。
每一部分的版权与许可归其各自权利人所有；本文件不改变任何原始许可条款。

---

## 1. Linux 内核（OPPO / Qualcomm 发布树）

| 项目 | 说明 |
|---|---|
| 上游仓库 | <https://github.com/oppo-source/android_kernel_oppo_sm7250> |
| 分支 / 基线提交 | `oppo/sm7250_s_12.1_reno4_5g` @ `554371ac` |
| 许可 | **GPL-2.0-only**（该树 `COPYING`：`GPL-2.0 WITH Linux-syscall-note`，"version 2 only"） |
| 版权 | Copyright (C) OPPO 及各原始作者与贡献者 |

本仓库对该树的改动以补丁形式提供（`patches/kernel/`，含新增文件），同样按 GPL-2.0-only 发布，
并按 GPLv2 §2(a) 标注为修改版本。

## 2. OPPO 模块与 devicetree 树（vendor）

| 项目 | 说明 |
|---|---|
| 上游仓库 | <https://github.com/oppo-source/android_kernel_modules_and_devicetree_oppo_sm7250> |
| 分支 / 基线提交 | `oppo/sm7250_s_12.1_reno4_5g` @ `ee75bb30` |
| 许可 | 文件级版权头，绝大多数为 **GPL-2.0-only**；上游未提供顶层 COPYING |

本仓库**不修改**任何上游文件的原始版权头，改动以 `patches/vendor/` 中的补丁提供。

### 2.1 vendor 树内的第三方子目录

| 子目录 | 项目 | 许可 |
|---|---|---|
| `oplus/kernel_4.19/exfat/` | Samsung exFAT (sdFAT) | GPL-2.0（见该目录 `LICENSE`） |
| `qcom/opensource/audio-kernel/` | Qualcomm audio kernel | 见该目录 `NOTICE` |
| `qcom/opensource/wlan/` | qcacld-3.0 (WLAN driver) | 文件级许可各不相同（GPL-2.0 / 双许可 / ISC 风格头） |
| `qcom/opensource/data-kernel/` | Qualcomm data kernel | 文件级许可 |
| `oplus/*` | OPPO 自研驱动（charger / touchpanel / power / thermal / sensor / secure 等） | GPL-2.0-only（文件头 `Copyright (C) OPPO`） |

## 3. KernelSU

| 项目 | 说明 |
|---|---|
| 上游仓库 | <https://github.com/tiann/KernelSU> |
| 基线提交 | `62e88ca9` |
| 许可 | `kernel/` 目录：**GPL-2.0-only**（`kernel/LICENSE`）；仓库其余部分（manager / userspace / website / js / scripts）：**GPL-3.0-or-later**（根 `LICENSE`） |
| 本项目使用范围 | **仅** `kernel/` 目录被集成进内核（`drivers/kernelsu`）；本仓库不分发其 GPL-3.0 部分 |
| 本项目改动 | `patches/kernelsu/` —— 4.19 非 GKI 适配（SELinux 策略注入，`file_wrapper` / `pkg_observer` / `sucompat` 等版本守卫），同样按 GPL-2.0-only 发布 |

保留的上游版权声明示例（不得删除）：`kernel/hook/arm64/patch_memory.c` 中
`Copyright (C) 2023 bmax121. All Rights Reserved.`（该文件 SPDX: GPL-2.0-only）。

版本号：`KSU_VERSION = 30000 + git rev-list --count HEAD`；本项目在固定提交 `62e88ca9` 上应用补丁，
保持 `KSU_VERSION = 32584`（配套 Manager：`KernelSU_v3.2.5-59-g62e88ca9_32584`）。

## 4. AnyKernel3（刷机包骨架，仅 Release 资产）

| 项目 | 说明 |
|---|---|
| 上游仓库 | <https://github.com/osm0sis/AnyKernel3> |
| 许可 | BSD-3-Clause 风格（Release 内的 zip 中保留其 `LICENSE`） |
| 版权 | Copyright (c) 2019 Chris Renshaw (osm0sis @ xda-developers) 及贡献者 |

### 4.1 刷机包内捆绑的预编译工具

| 文件 | 来源 | 许可 |
|---|---|---|
| `tools/busybox` | BusyBox / AK3 预编译 | GPL-2.0 |
| `tools/magiskboot` | Magisk 项目 | GPL-3.0 |
| `tools/magiskpolicy` | Magisk 项目 | GPL-3.0 |
| `tools/fec` | AOSP (fec 工具) | Apache-2.0 |
| `tools/lptools_static` | AOSP (dynamic partitions) | Apache-2.0 |
| `tools/snapshotupdater_static` | AOSP (virtual A/B snapshot) | Apache-2.0 |
| `tools/httools_static` | 随 AnyKernel3 分发 | 参见 AnyKernel3 上游说明 |

以上文件的对应源码可从各自上游项目获取；本项目不对这些二进制做任何修改。

## 5. 构建工具链（不随本仓库分发）

| 组件 | 版本 | 来源 | 许可 |
|---|---|---|---|
| clang | `clang-r399163b` (clang 11.0.5, Android 6875598) | AOSP prebuilts（`master-kernel-build-2021`） | Apache-2.0 + BSD-like + MIT（见 `NOTICE`、`MODULE_LICENSE_*`） |
| aarch64 GCC | 4.9.x (20150123) | LineageOS prebuilts（`lineage-19.1`） | GPL-3.0 + GCC Runtime Library Exception（`COPYING` / `COPYING.LIB` / `COPYING.RUNTIME`） |
| arm (32-bit) GCC | 4.9.x (20150123) | LineageOS prebuilts（`lineage-19.1`） | 同上 |

工具链由 `scripts/fetch-toolchain.sh` 按固定上游地址下载，不进入本仓库 git 历史。
GCC 的对应源码可从 GNU 项目及上述 prebuilt 上游仓库获取；若再分发 GCC 二进制，请自行履行
GPLv3 §6 的源码提供义务。

> 已知本地修改：部分 AOSP GCC/binutils wrapper 脚本的 shebang 由 `#!/usr/bin/python` 改为
> `#!/usr/bin/python3`（GPLv3 §5a 要求标注修改）。

## 6. 未包含 / 不再分发的内容

| 内容 | 原因 |
|---|---|
| 原厂 `boot.img`（及由其重打包的镜像） | 内含 OPPO 专有 ramdisk、DTB 等二进制，不在 GPL 源码授权范围内 |
| `ksud` 二进制 / Manager APK | KernelSU userspace（GPL-3.0-or-later）；请从上游 Release 获取，或用 `scripts/extract-ksud.sh` 从你自备的 APK 提取 |
| OPPO / Qualcomm 专有 blobs（firmware、vendor 分区内容） | 未随 GPL 源码发布，需自行从设备 / 官方固件获取 |
| 第三方内核适配补丁集 / 配置清单 | 本仓库不分发任何第三方补丁、清单或脚本；本仓库的配置项改动均为本项目自行实现，按 GPL-2.0-only 发布 |
| LineageOS GSI 及 Google 应用 | 各自独立的许可与分发条款 |

---

## 7. 商标声明

`OPPO`、`Reno4`、`ColorOS`、`Qualcomm`、`Snapdragon`、`SM7250`、`lito`、`KernelSU`、`Magisk`、
`AnyKernel3`、`Android` 等名称与标识为其各自权利人的商标或注册商标。本项目为**非官方**社区
作品，与上述权利人无任何隶属或背书关系，相关名称仅用于兼容性描述。

## 8. GPL 源码获取

本仓库中每个发布二进制产物所对应的完整源码，与其 Release 位于同一页面，并在 `SOURCE.md` 中
标注对应的源码 commit 与构建方式。若需其它形式的源码副本或有合规问题，请联系仓库维护者。
