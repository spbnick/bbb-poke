/*
 * Dump board identification from EEPROM.
 * Should be the same data as output by "i2c md 50 0.2 20".
 */

.syntax unified

i2c0_base                   = 0x44e0b000


.text
.global start
start:
    push {r4-r11, lr}

    /* Initialize UART0 */
    bl uart_init

    /* Initialize I2C0 */
    ldr r0, =i2c0_base
    bl i2c_init

    /* Clear the buffer */
    ldr r0, =buf
    mov r1, 32
    ldr r2, =0xefbeadde
1:
    str r2, [r0], 4
    subs r1, r1, 4
    bne 1b

    /*
     * Read the board identification EEPROM piece into a buffer
     */
    /* I2C0 base address */
    ldr r0, =i2c0_base
    /* 24LC32A chip I2C address, EEPROM address zero */
    mov r1, 0b1010000 << 16 | 0
    /* Output buffer pointer */
    ldr r2, =buf
    /* Output buffer length */
    mov r3, 32
    bl i2c_write

    /* Dump the buffer */
    ldr r0, =buf
    mov r1, 32
    bl uart_hexdump

    mov r0, 0
    pop {r4-r11, pc}

.data
/* Dump buffer */
.global buf
.align 2
buf:
.space 32
