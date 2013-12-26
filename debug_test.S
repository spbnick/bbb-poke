/*
 * Test debug.S module
 */

#include "debug.h"

.syntax unified

.text
.global start
start:
    push {r4-r11, lr}
    mov r0, 0x00000000
    ldr r1, =0x11111111
    ldr r2, =0x22222222
    ldr r3, =0x33333333
    ldr r4, =0x44444444
    ldr r5, =0x55555555
    ldr r6, =0x66666666
    ldr r7, =0x77777777
    ldr r8, =0x88888888
    ldr r9, =0x99999999
    ldr r10, =0xaaaaaaaa
    ldr r11, =0xbbbbbbbb
    ldr r12, =0xcccccccc
    ldr r14, =0xeeeeeeee
    debug_dump_core_regs
    pop {r4-r11, pc}
