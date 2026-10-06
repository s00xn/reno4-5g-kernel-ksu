# SOURCE — 二进制与源码的对应关系

本文件说明本仓库发布的每个二进制产物对应哪一份源码、如何复现，以及 GPLv2 意义上的
"完整对应源码"在哪里获取。

---

## 1. 上游 base

| 组件 | 上游仓库 | 分支 | 基线提交 |
|---|---|---|---|
| 内核 | `https://github.com/oppo-source/android_kernel_oppo_sm7250` | `oppo/sm7250_s_12.1_reno4_5g` | `554371ac` |
| vendor + techpack | `https://github.com/oppo-source/android_kernel_modules_and_devicetree_oppo_sm7250` | `oppo/sm7250_s_12.1_reno4_5g` | `ee75bb30` |
| KernelSU | `https://github.com/tiann/KernelSU` | — | `62e88ca9` |

## 2. 本项目的改动（= 本仓库全部内容）

| 补丁 | 作用 |
|---|---|
| `patches/kernel/0000-techpack-gitignore.patch` | 让 `techpack/{camera,display,video}` 被内核树跟踪（从 modules 仓库并入的子目录） |
| `patches/kernel/0001-reno4-5g-kernel-4.19-kernelsu.patch` | 内核 4.19 兼容回移、KernelSU 集成、defconfig 调整 |
| `patches/kernel/new-files/` | 该补丁新增的文件（`stock_lito_defconfig` 与若干头文件），需按原路径拷入内核树 |
| `patches/vendor/0001-lito-devicetree-and-oplus-fixes.patch` | vendor 树改动（devicetree Makefile 的 LITO 修正、OPLUS 驱动修正） |
| `patches/kernelsu/0001-android-4.19-support.patch` | KernelSU 的 4.19 非 GKI 适配（对着 `62e88ca9` 应用，保持 `KSU_VERSION=32584`） |

应用的目录结构与顺序见 `base/BASE.md` 与 `scripts/prepare-tree.sh`。

## 3. 如何复现构建

```bash
scripts/prepare-tree.sh        # 1. clone 官方内核 + vendor/modules 树，并入 techpack，打补丁
scripts/fetch-toolchain.sh     # 2. 下载 clang-r399163b + GCC 4.9（约 1.8 G）
scripts/prepare-kernelsu.sh    # 3. clone KernelSU @62e88ca9，打补丁，建 drivers/kernelsu 软链接
scripts/build.sh               # 4. 生成 kernel/msm-4.19/out/arch/arm64/boot/Image
```

构建完成后记录 `Image` 的 SHA256，即为对应的内核二进制。

## 4. Release 产物对照表

> 每次发布时更新本表；**发布哪个二进制，就必须能从本文件描述的方式复现它**。

| Release 产物 | 对应源码 | 构建方式 | 内核 Image SHA256 |
|---|---|---|---|
| `Reno4_5G_KSU_kernel_<ver>.zip`（AnyKernel3） | 本仓库 tag `<ver>`（补丁全量） | 上面第 1–4 步 + `patches/` | 待填 |
| 完整源码包 `reno4-5g-ksu-src-<ver>.tar.gz`（可选） | 同上 | 官方树 + 本仓库补丁导出 | — |

完整源码亦可通过"按本文第 3 节用脚本重建"获得；对于只需要源码副本的下游使用者，
Release 中附带的源码包即为 GPLv2 §3 意义上的对应源码。

## 5. 已知偏差记录

| 位置 | 说明 |
|---|---|
| `drivers/gpu/trace/Kconfig` 的 help 文案 | 纯文档性改动，不进入编译产物，不影响 Image 二进制一致性 |
| 本仓库不含 `boot.img` | 原厂 ramdisk/DTB 属 OPPO 专有内容，见 `NOTICE.md` 第 6 节 |
