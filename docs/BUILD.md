# 构建说明（OPPO Reno4 5G / SM7250 lito，内核 4.19.157 + KernelSU）

## 1. 主机要求

- Linux x86_64（本项目在 Ubuntu 上验证）
- 约 20 GB 磁盘：源码树 ~1.5 G、工具链 ~1.8 G、`out/` 构建中间件 ~3 G 以上
- 内存建议 ≥ 8 GB（`-j` 太高容易 OOM）
- 依赖包：

```bash
sudo apt update
sudo apt install -y build-essential bc bison flex libssl-dev libncurses-dev \
  libelf-dev cpio perl python3 kmod lz4 xz-utils zstd device-tree-compiler \
  git curl unzip rsync
```

## 2. 一次性准备

在仓库根目录依次执行（全部脚本都可重复执行）：

```bash
scripts/prepare-tree.sh        # clone 官方内核 + vendor/modules 树，并入 techpack，打补丁
scripts/fetch-toolchain.sh     # 下载 clang-r399163b + GCC 4.9（约 1.8 G）到 toolchain/
scripts/prepare-kernelsu.sh    # clone KernelSU@62e88ca9、打 4.19 补丁、建 drivers/kernelsu 链接
```

`prepare-tree.sh` 结束后目录应当是这样（与 OPPO 构建系统的期望一致）：

```
./
├── kernel/msm-4.19/     ← 官方内核 + techpack/camera|display|video + 本项目补丁
└── vendor/              ← 官方 modules 仓库的 vendor/ + 本项目补丁
```

## 3. 编译

```bash
scripts/build.sh
```

等价的原始命令（脚本内部就是这些，可按需覆盖变量）：

```bash
cd kernel/msm-4.19
export ARCH=arm64
export PATH="$PWD/../../toolchain/clang-r399163b/bin:\
$PWD/../../toolchain/aarch64-linux-android-4.9/bin:\
$PWD/../../toolchain/arm-linux-androideabi-4.9/bin:$PATH"

make O=out CC=clang \
     CROSS_COMPILE=aarch64-linux-android- \
     CROSS_COMPILE_ARM32=arm-linux-androideabi- \
     CLANG_TRIPLE=aarch64-linux-gnu- \
     KCFLAGS="-Wno-error=strict-prototypes" \
     -j"$(nproc)"
```

产物：`kernel/msm-4.19/out/arch/arm64/boot/Image`（模块如需使用则在 `out/` 下另找）。

可用环境变量覆盖：`KERNEL_DIR`、`TOOLCHAIN_DIR`、`DEFCONFIG`、`OUT_DIR`、`JOBS`、`KCFLAGS`。

### 3.1 为什么要有这些"特殊"参数

| 参数 / 改动 | 原因 |
|---|---|
| `KCFLAGS=-Wno-error=strict-prototypes` | OPPO vendor 代码里有大量旧式 `foo()` 定义，clang 的 `-Werror` 会直接报错（GCC 4.9 只警告） |
| `DEFCONFIG=vendor/stock_lito_defconfig` | **不要**用仓库自带的 `lito_defconfig`：它把 145 项调试开关全开（含 `DEBUG_PANIC_ON_OOM` + `PANIC_TIMEOUT=-1`），实测会卡在第一屏 |
| 关闭 `CONFIG_MODULE_SIG` | 原厂 `WLAN.ko` 带厂商签名，开着 `MODULE_SIG_FORCE` 会拒载（`Required key not available`） |
| 保留 `CONFIG_MODVERSIONS=y` | vermagic 里含 `modversions`，关掉会导致原厂模块不匹配 |
| 禁用 `CONFIG_ARCH_LAGOON` | 官方发布的 devicetree 缺少 lagoon 的 dtb 源，开着会编译失败（Reno4 5G 是 LITO only） |
| `OplusKernelEnvConfig.mk` 里 export `OPLUS_FEATURE_*` | kbuild 递归子 make 不继承这些变量 |

## 4. 打包 boot.img

```bash
scripts/repack_bootimg.sh <你的原厂 boot.img> \
    kernel/msm-4.19/out/arch/arm64/boot/Image \
    boot_Reno4_5G_KSU.img
```

- 脚本只替换内核，保留原厂 `boot.img` 里的 ramdisk 与 dtb；
- 需要 `magiskboot`（Linux x86_64）。通过环境变量指定：`MAGISKBOOT=/path/to/magiskboot`，
  或把它放进 `PATH`；
- 脚本会校验 header 里的 `kernel_size` 是否等于新内核长度；
- **注意**：不要用 `magiskboot unpack -h`（会锁定旧尺寸，重打包后 `kernel_size` 不更新）。

## 5. 常见问题

| 症状 | 原因 / 处理 |
|---|---|
| 卡在第一屏 / 开机 logo 死机 | 用了 `lito_defconfig`（调试开关全开）→ 换 `stock_lito_defconfig` 并 `rm -rf out` 重编 |
| Wi-Fi 打不开 | `CONFIG_MODULE_SIG_FORCE` 拒绝加载原厂 `WLAN.ko` → 关掉 `CONFIG_MODULE_SIG`，保留 `MODVERSIONS` |
| `Required key not available` | 同上（模块签名） |
| 编译报 `strict-prototypes` 错误 | 确认 `KCFLAGS` 生效 |
| 工具链脚本报 `python: not found` | AOSP GCC/binutils 的 wrapper 原本是 python2 shebang，本项目已改为 python3；若自行下载旧版请手动修 |
| `make` 报 devicetree 缺 lagoon | 确认 `CONFIG_ARCH_LAGOON` 已禁用 |
| 构建中途中断、`out/` 疑似损坏 | `rm -rf out` 后重编（增量偶发不一致） |
| KernelSU Manager 提示 `kernel too low` / `manager too low` | KernelSU 版本号不匹配：确认 `scripts/prepare-kernelsu.sh` 正常执行（`KernelSU` 必须是一个 git 仓库且 checkout 在 `62e88ca9`），配合 Manager `32584` |

## 6. 构建完成后

1. 记录 `Image` 的 SHA256，填写到 `SOURCE.md` 的 Release 对照表；
2. 用自备原厂 `boot.img` 打包并**先在设备上验证**：`getenforce`、root 域、AVC 日志；
3. 需要刷机包时执行：

```bash
scripts/make-ak3-zip.sh kernel/msm-4.19/out/arch/arm64/boot/Image v1.0.0
```

   脚本会从上游拉取 AnyKernel3 模板、套用 `release/anykernel.sh`（设备相关配置）、
   放入 `Image` 并生成 zip 与 `SHA256SUMS`。zip 内保留 AnyKernel3 的 `LICENSE`，
   且**不含**原厂 ramdisk/dtb（刷机时从设备自身 boot 分区读取）。
4. 发布时把 zip 与 `SHA256SUMS` 上传到 Release，并在 Release notes 里写明对应的源码 commit。
