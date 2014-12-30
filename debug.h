/*
 * Debugging macros
 */
#ifndef __DEBUG_H
#define __DEBUG_H

#ifdef __ASSEMBLY__

/* Dump core register to UART0 */
.macro debug_dump_core_regs
    /* Store all registers on the stack */
    stmfd sp, {r0-r15}
    sub sp, sp, 16 * 4

    /* Output stored registers + CPSR */
    bl _debug_dump_core_regs

    /* Restore all registers except PC */
    pop {r0-r12}
    add sp, sp, 4   /* Skip SP */
    pop {lr}
    add sp, sp, 4   /* Skip PC */
.endm

/* Print PC register value */
.macro debug_print_pc
    push {r0-r3}
    ldr r0, =debug_pc_fmt
    mov r1, pc
    bl uart_printf
    pop {r0-r3}
.endm

#endif

#endif
