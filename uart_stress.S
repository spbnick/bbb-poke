/*
 * Stress test UART0 polled output
 */
.syntax unified

uart_base0          = 0x44e09000
uart_lsr            = 0x14
uart_lsr_txfifoe    = 1 << 5
uart_thr            = 0x00

.text
.global start

r_char  .req r4
r_col   .req r5

    /* Initialize UART */
    bl uart_init

    /*
     * Wait for Enter to be pressed
     */
1:
    bl uart_getc
    cmp r0, 0xd
    bne 1b

    /*
     * Output test pattern indefinitely
     */
    mov r_char, 'A
    mov r_col, 1
1:
    subs r_col, 1
    beq 2f
    mov r0, r_char
    bl uart_putc
    cmp r_char, 'Z
    moveq r_char, 'A
    addne r_char, 1
    b 1b
2:
    mov r0, 0xd
    bl uart_putc
    mov r0, 0xa
    bl uart_putc
    mov r_col, 'Z - 'A + 1
    b 1b

.unreq r_char
.unreq r_col
