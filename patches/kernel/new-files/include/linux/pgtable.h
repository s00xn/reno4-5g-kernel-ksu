/* SPDX-License-Identifier: GPL-2.0-only
 * KernelSU compatibility: 4.19 has no linux/pgtable.h (split out in 5.x);
 * forward to the arch header like upstream does.
 */
#ifndef _LINUX_PGTABLE_H
#define _LINUX_PGTABLE_H

#include <asm/pgtable.h>

#endif /* _LINUX_PGTABLE_H */
