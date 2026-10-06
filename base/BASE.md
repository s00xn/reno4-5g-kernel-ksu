# base — 上游基线与补丁应用顺序

## 1. 上游

| 组件 | 仓库 | 分支 | 提交 |
|---|---|---|---|
| 内核树 | `oppo-source/android_kernel_oppo_sm7250` | `oppo/sm7250_s_12.1_reno4_5g` | `554371ac` |
| 模块与 devicetree 树 | `oppo-source/android_kernel_modules_and_devicetree_oppo_sm7250` | `oppo/sm7250_s_12.1_reno4_5g` | `ee75bb30` |
| KernelSU | `tiann/KernelSU` | — | `62e88ca9` |

OPPO 官方把内核与 "模块 + devicetree" 分成两个仓库，而它的构建系统（`OplusKernelEnvConfig.mk`）
期望在内核树同级看到 `../vendor/`，并且 techpack 的 camera/display/video 需要出现在内核树里。
因此本项目按下列顺序把两个仓库拼成一棵可构建的树。

## 2. 应用顺序（`scripts/prepare-tree.sh` 自动完成）

1. `git clone -b oppo/sm7250_s_12.1_reno4_5g <kernel 仓库> kernel/msm-4.19`
2. `git clone -b oppo/sm7250_s_12.1_reno4_5g <modules 仓库> .modules-src`
3. 把 `.modules-src/kernel/msm-4.19/techpack/{camera,display,video}` 拷入
   `kernel/msm-4.19/techpack/`
4. `git apply patches/kernel/0000-techpack-gitignore.patch`
   （效果：`.gitignore` 的 `techpack/` → `techpack/*`，并取消忽略 camera/display/video）
5. 把 `.modules-src/vendor/` 拷到仓库根目录的 `vendor/`
6. `git -C vendor apply ../patches/vendor/0001-lito-devicetree-and-oplus-fixes.patch`
7. `git -C kernel/msm-4.19 apply ../patches/kernel/0001-reno4-5g-kernel-4.19-kernelsu.patch`
8. 把 `patches/kernel/new-files/` 下的文件按相对路径拷进 `kernel/msm-4.19/`
9. `scripts/prepare-kernelsu.sh`：clone KernelSU @`62e88ca9` → apply `patches/kernelsu/`
   → 在 `kernel/msm-4.19/` 建 `drivers/kernelsu` 软链接指向 `KernelSU/kernel`

## 3. 为什么要 pin 死 KernelSU 的提交

`KernelSU/kernel/Kbuild` 用 `git rev-list --count HEAD` 计算版本号：

```make
KSU_GIT_VERSION := $(shell cd $(GIT_ROOT) && $(GIT) rev-list --count HEAD)
KSU_VERSION = 30000 + KSU_GIT_VERSION     # 62e88ca9 → 2584 → 32584
# 若 KernelSU 不是 git 仓库（例如被当普通目录拷进来）：
ccflags-y += -DKSU_VERSION=16
```

- 提交数变化 → `KSU_VERSION` 变化 → 需要匹配的新 Manager；
- 丢失 `.git` → 版本号跌到 16 → Manager 报 `kernel too low`。

所以本项目固定 checkout `62e88ca9` 并**以补丁方式**修改，而不是在 KernelSU 上加提交。

## 4. 构建产物与 defconfig

- defconfig：`arch/arm64/configs/vendor/stock_lito_defconfig`（由原厂 boot 内核提取的配置，
  加上必要开关：`CONFIG_KSU`/`CONFIG_KPROBES` 及若干配置项；关闭 `CONFIG_MODULE_SIG`，
  禁用 `CONFIG_ARCH_LAGOON`）
- 产物：`kernel/msm-4.19/out/arch/arm64/boot/Image`
- 打包：`scripts/repack_bootimg.sh`（替换原厂 `boot.img` 中的内核，保留设备自己的 ramdisk/dtb）

## 5. 备注

- 本仓库不保存官方树的 git 历史；需要历史时请直接 clone 上游仓库（`base/BASE.md` 记录了提交号）。
- `vendor/` 是从 modules 仓库拷出的子目录，其自身的历史请参考上游仓库。
