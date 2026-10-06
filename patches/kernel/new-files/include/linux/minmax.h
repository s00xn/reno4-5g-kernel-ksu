/* SPDX-License-Identifier: GPL-2.0 */
/*
 * 4.19 compatibility shim (KernelSU): on 4.19 min/max/clamp macros live in
 * linux/kernel.h. 5.x moved them to this header; forward to the 4.19 location.
 */
#ifndef _LINUX_MINMAX_H
#define _LINUX_MINMAX_H

#include <linux/kernel.h>

#endif /* _LINUX_MINMAX_H */
