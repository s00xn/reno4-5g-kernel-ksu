# 在内核 4.19（非 GKI）上实现 KernelSU 的 SELinux 策略注入

本文记录本发行版里最核心、也最容易被忽略的一块工作时：**让 KernelSU 的 root 在 SELinux
enforcing 状态下真正可用**。上游 KernelSU 对 `< 5.7` 的内核采取的是"依赖 ROM 自带策略"的
做法，本设备所用系统镜像里没有 `ksu` 域，因此必须自己实现 4.19 的策略注入。

> 涉及文件（KernelSU `kernel/` 目录，见 `patches/kernelsu/`）：
> `selinux/sepolicy.c`、`selinux/rules.c`、`selinux/sepolicy.h`、`runtime/ksud_integration.c`

## 1. 为什么需要注入

KernelSU 3.x 在非 GKI 内核上的机制：

1. kprobe hook `__arm64_sys_reboot`，用特定 magic 值装载"超级调用"文件描述符；
2. 系统调用 dispatcher 处理超级调用；
3. `sucompat` 拦截 `su` 的 exec，改为打开 `/data/adb/ksud`。

系统侧的 `init.rc` 里通常有：

```
exec u:r:ksu:s0 root -- /data/adb/ksud services
```

也就是说运行时需要满足两个前提：策略里存在 **`ksu` 域** 与 **`ksu_file` 类型**。
上游对 `< 5.7` 的做法是把 `apply_kernelsu_rules()` / `handle_sepolicy()` 直接 stub 掉，
假设 ROM 的 sepolicy 已自带这些定义。**本设备所用镜像缺这两个定义**，照抄上游会导致：

- `ksud` 启动时创建进程域失败（`ksu_cred` 相关时域不存在）；
- `sucompat` 打开 `/data/adb/ksud` 时 `EACCES`。

因此本项目**真正实现了 4.19 的策略注入**：注入成功则保持 enforcing，只有在注入失败时才
兜底 `setenforce(false)`。

## 2. `sepolicy.c`：4.19 的 `add_type()`

4.19 的 SELinux 内部数据结构和 5.x 差异很大，`add_type()` 需要按 `struct flex_array` 重写：

| 结构 | 4.19 形态 | 处理要点 |
|---|---|---|
| `type_attr_map_array` | `struct flex_array *` | 容量在策略加载时固定，扩容要走 flex_array 流程 |
| `type_val_to_struct_array` | `struct flex_array *` | 同上 |
| `sym_val_to_name` | `struct flex_array **` | 按符号表分别扩容 |
| `role_val_to_struct` | 普通数组 | 新类型要加入**所有** role 的授权类型位图 |

踩坑记录：

- 4.19 的 `flex_array_prealloc()` 在越界时返回 `-ENOSPC`，不会自动扩容。必须先手动设置
  `fa->total_nr_elements = value`，再 `flex_array_prealloc()` 新的 part 页，最后用
  `flex_array_put()` 填入新槽位；
- 需要显式 `#include <linux/flex_array.h>`；
- 新类型除了插入 `type_val_to_struct_array`，还要同步更新每个 role 的授权位图，
  否则 `type_transition` / `allow` 规则校验会失败。

## 3. `rules.c`：4.19 的 `apply_kernelsu_rules()`（返回 `bool`）

5.x 的写法依赖 RCU：构造好新的 `policydb` 后做指针交换。**4.19 不能这样做**，因为读路径是

```c
read_lock(&ss->policy_rwlock);
... ss->policydb ...
read_unlock(&ss->policy_rwlock);
```

即直接访问 `ss->policydb`，没有 RCU 解引用。正确做法是模仿 `security_load_policy()`：

1. `write_lock_irq(&ss->policy_rwlock)`；
2. **就地 `memcpy`** 把新 policydb 覆盖到 `ss->policydb`；
3. `++latest_granting`；
4. 依次通知各子系统：

```c
avc_ss_reset(avc, seqno);
selnl_notify_policyload(latest_granting);
selinux_status_update_policyload(latest_granting);
selinux_xfrm_notify_policyload();
```

配套要点：

- `ksu_dup_sepolicy()`（policydb 的 write→read 深拷贝）在 4.19 上是**第一次真正跑通**；
  其中配置位 `offset 20` 的 fixup 与 4.19 的头部布局吻合；
- `sepolicy.h` 里加 `#define selinux_policy selinux_ss`（`< 5.7`），让 `sepolicy.c` 与
  `rules.c` 共用一致声明（放在头文件里，避免两个文件各写一份而互相不一致）。

### 注入的策略内容

- 类型 `ksu_file`：属性 `file_type` + `mlstrustedobject`；
- 域 `ksu`：`permissive` + 属性 `domain`、`netdomain`、`mlstrustedsubject`、`bluetoothdomain`；
- 规则：`allow domain ksu_file file *`、`allow ksu * * *`；
- `init` → `ksu` 的域转换；
- `servicemanager` / `logd` / `domain` / `system_server` 的全套规则与 xperm ioctl
  （与 5.x 版本保持一致）。

## 4. 兜底逻辑

`runtime/ksud_integration.c` 在 init 的 second stage：

```c
if (!apply_kernelsu_rules())
        setenforce(false);      /* 仅注入失败时才回退 permissive */
```

这样在正常情况下设备保持 **enforcing**，同时避免"注入失败导致完全无法使用"。

## 5. KernelSU 侧的其它 4.19 适配

| 文件 | 适配内容 |
|---|---|
| `feature/selinux_hide.c` | `>= 5.7` 守卫 + 5 个 stub |
| `feature/sucompat.c` | `filp_open` 前后 `setenforce` 兜底 |
| `infra/file_wrapper.c` | `iopoll`（≥5.3）、`remap`（≥5.0）、`anon`（≥5.13）守卫 |
| `manager/pkg_observer.c` | `fsnotify` 的 `handle_event`（≥5.2）回退 |
| `policy/allowlist.c` | 补 `sched/task.h` |
| `policy/app_profile.c` | `filter_count`（≥5.9）守卫 |
| `supercall/dispatch.c` | 补 `pid`/`sched`/`signal`/`task` 头文件 |

## 6. 内核侧的 4.19 兼容回移

KernelSU 需要的若干新内核 API 在 4.19 上不存在，本项目做了最小回移：

| 文件 | 内容 |
|---|---|
| `include/linux/module.h` | `MODULE_IMPORT_NS` 空宏 |
| `include/linux/minmax.h`、`include/linux/pgtable.h` | 新增转发头 |
| `include/uapi/linux/mount.h` | 新增转发头 |
| `include/linux/uaccess.h` + `mm/maccess.c` | `nofault` 别名（`probe_*`） |
| `fs/namespace.c` | 回移 `path_mount` / `path_umount` 并 `EXPORT` |
| `security/selinux/include/objsec.h` | `selinux_inode` / `selinux_cred` inline |
| `include/linux/seccomp.h` + `kernel/seccomp.c` | `SECCOMP_ARCH_NATIVE_NR`、`seccomp_filter_release` |
| `include/linux/string.h` + `lib/string.c` | `strscpy_pad` |
| `include/linux/task_work.h` | `TWA_RESUME` 枚举 |
| `include/linux/compiler_types.h` | `fallthrough` |
| `net/sctp/sm_make_chunk.c` | `fallthrough` 语义修正（5 处） |
| `drivers/gpu/trace/Kconfig` | 为 `TRACE_GPU_MEM` 恢复可配置的 prompt（4.19 里它是无 prompt 的隐藏 bool，且全树无人 `select`，否则无法在 defconfig 中启用） |

## 7. 验证结果（设备实测）

| 检查项 | 结果 |
|---|---|
| `getenforce` | Enforcing |
| root shell 域 | `u:r:ksu:s0` |
| root 授权 | Manager `debug su` → uid 0 |
| KernelSU 功能 | Feature 查询 / Module List / adb_root 安装均正常 |
| ksu 相关 AVC 拒绝 | 0 条 |

已知现象：少数 `debug su` 子进程会出现 SIGSYS（app 域 seccomp 拦截 `reboot` 系统调用 142，
发生在 ksud 安装超级调用 FD 的路径上）。这与 SELinux 模式无关，在 permissive 下同样存在，
且不影响 root 可用性。
