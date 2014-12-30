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
    mov r11, sp              /* Remember SP */

    mrs r0, cpsr

    /*
     * Push mode string
     */
    and r1, r0, 0x1F
.macro match_mode mode, c1, c2, c3
    cmp r1, \mode
    moveq r2, (\c3 << 8)
    movteq r2, (\c1 << 8) | \c2
    beq 1f
.endm
    match_mode 0b10000, 'u, 's, 'r
    match_mode 0b10001, 'f, 'i, 'q
    match_mode 0b10010, 'i, 'r, 'q
    match_mode 0b10011, 's, 'v, 'c
    match_mode 0b10110, 'm, 'o, 'n
    match_mode 0b10111, 'a, 'b, 't
    match_mode 0b11010, 'h, 'y, 'p
    match_mode 0b11011, 'u, 'n, 'd
    match_mode 0b11111, 's, 'y, 's
    mov r2, ('? << 8)
    movt r2, ('? << 8) | '?
1:
    tst r0, 1 << 9          /* E (endiannes) flag */
    reveq r2, r2
    /* Push the mode string */
    push {r2}
    /* Push the pointer to the mode string */
    mov r2, sp
    push {r2}

    /*
     * Push flag characters
     */
.macro push_bit lsb, off, on
    tst r0, 1 << \lsb
    moveq r1, \off
    movne r1, \on
    push {r1}
.endm
    push_bit 6, 'f, 'F
    push_bit 7, 'i, 'I
    push_bit 8, 'a, 'A
    push_bit 9, 'e, 'E
    push_bit 27, 'q, 'Q
    push_bit 28, 'v, 'V
    push_bit 29, 'c, 'C
    push_bit 30, 'z, 'Z
    push_bit 31, 'n, 'N

    /*
     * Push raw cpsr
     */
    push {r0}

    /*
     * Transfer other captured registers
     */
    ldmfa r9!, {r1-r8}      /* Load captured r8-r15 */
    push {r1-r8}            /* Push captured r8-r15 */
    ldmfa r9!, {r1-r8}      /* Load captured r0-r7 */
    push {r4-r8}            /* Push captured r3-r7 */
    ldr r0, =core_regs_fmt
    bl uart_printf
    mov sp, r11             /* Restore SP */
    pop {pc}

.data
core_regs_fmt:
    .ascii "  r0  %x    r1  %x    r2  %x    r3  %x\r\n"
    .ascii "  r4  %x    r5  %x    r6  %x    r7  %x\r\n"
    .ascii "  r8  %x    r9  %x    r10 %x    fp  %x\r\n"
    .ascii "  ip  %x    sp  %x    lr  %x    pc  %x\r\n"
    .ascii "  cpsr %x "
    .asciz "%c%c%c%c%c %c %c%c%c %s\r\n" /* NZCVQ E AIF mode */
.global debug_pc_fmt
debug_pc_fmt:
    .asciz "PC: %x\r\n"
