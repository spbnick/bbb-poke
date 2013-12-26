/*
 * Debugging macros
 */
#ifndef __DEBUG_H
#define __DEBUG_H

#ifdef __ASSEMBLY__

/* Dump core register to UART0 */
.macro debug_dump_core_regs
    stmfd sp, {r0-r15}
    sub sp, sp, 16 * 4
    bl _debug_dump_core_regs
    pop {r0-r12}
    add sp, sp, 4   /* Skip SP */
    pop {lr}
    add sp, sp, 4   /* Skip PC */
.endm

#endif

#endif
