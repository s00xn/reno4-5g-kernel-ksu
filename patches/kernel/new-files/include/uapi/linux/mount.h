/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note
 * KernelSU compatibility: 4.19 has no uapi/linux/mount.h (split from
 * linux/fs.h in 5.x); forward to fs.h which carries the MS_* mount flags.
 */
#ifndef _UAPI_LINUX_MOUNT_H
#define _UAPI_LINUX_MOUNT_H

#include <linux/fs.h>

#endif /* _UAPI_LINUX_MOUNT_H */
