/*
 * Debugging support
 */
.syntax unified

.text
/*
 * Dump core registers to UART0.
 * Expect to be invoked by the debug_dump_core_regs macro.
 */
.global _debug_dump_core_regs
_debug_dump_core_regs:
    add r9, sp, 15 * 4      /* Point r9 to r15 on the stack */
    push {lr}
    ldr r0, =core_regs_fmt
    ldmfa r9!, {r1-r8}      /* Load captured r8-r15 */
    push {r1-r8}            /* Push captured r8-r15 */
    ldmfa r9!, {r1-r8}      /* Load captured r0-r7 */
    push {r4-r8}            /* Push captured r3-r7 */
    bl uart_printf
    add sp, sp, 13 * 4      /* Discard copies of captured r3-r15 */
    pop {pc}

.data
core_regs_fmt:
    .ascii "  r0  %x    r1  %x    r2  %x    r3  %x\r\n"
    .ascii "  r4  %x    r5  %x    r6  %x    r7  %x\r\n"
    .ascii "  r8  %x    r9  %x    r10 %x    fp  %x\r\n"
    .asciz "  ip  %x    sp  %x    lr  %x    pc  %x\r\n"
