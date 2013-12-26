/*
 * UART0 handling
 */
.syntax unified

uart_base0  = 0x44e09000
uart_dll    = 0x00
uart_dlh    = 0x04
uart_lcr    = 0x0c
uart_lsr    = 0x14
uart_sysc   = 0x54
uart_syss   = 0x58
uart_mdr1   = 0x20
uart_thr    = 0x00

.text

/*
 * Initialize UART0
 */
.global uart_init
uart_init:

r_uart_base .req r0
r_tmp       .req r1

    ldr r_uart_base, =uart_base0

    /* Reset: set UARTi.UART_SYSC[1] SOFTRESET to 1 */
    mov r_tmp, 1
    str r_tmp, [r_uart_base, uart_sysc]
    
    /* Wait for reset: poll for UARTi.UART_SYSS[0] RESETDONE == 1 */
1:
    ldr r_tmp, [r_uart_base, uart_syss]
    cmp r_tmp, 1
    bne 1b

    /*
     * The default state:
     * interrupts:              disabled
     * FIFOs:                   disabled
     * hardware flow control:   disabled
     * software flow control:   disabled
     * mode:                    disabled
     */

    /*
     * Set frame formatting to 8N1:
     * UARTi.UART_LCR[1:0]  CHAR_LENGTH     = 3 (8 bit)
     * UARTi.UART_LCR[2]    NB_STOP         = 0 (1 stop bit)
     * UARTi.UART_LCR[5:3]  PARITY_EN       = 0 (no parity)
     *
     * Enable divisor latch (Configuration mode A) to access DLL and DLH:
     * UARTi.UART_LCR[7]    DIV_EN          = 1
     */
    mov r_tmp, 0x83
    str r_tmp, [r_uart_base, uart_lcr]

    /* Set Baud Rate to 115200: assume DLH == 0 (default), set DLL = 0x1A */
    mov r_tmp, 0x1a
    str r_tmp, [r_uart_base, uart_dll]

    /* Enable UART 16x mode: set UARTi.UART_MDR1[2:0] MODESELECT to 0 */
    mov r_tmp, 0
    str r_tmp, [r_uart_base, uart_mdr1]

    /* Switch to Operational mode: clear UARTi.UART_LCR[7] DIV_EN */
    ldr r_tmp, [r_uart_base, uart_lcr]
    bic r_tmp, r_tmp, 0x80
    str r_tmp, [r_uart_base, uart_lcr]

    bx lr

.unreq r_uart_base
.unreq r_tmp


/*
 * Output a printf-formatted string to UART0.
 *
 * @param fmt   Format string.
 * @param ...   Format arguments.
 *
 * Only conversion specifiers are supported:
 *  s   - string.
 *  x   - lowercase unsigned hex integer
 *  X   - uppercase unsigned hex integer
 *  %   - '%' character.
 */
.global uart_printf
uart_printf:

/* Format string pointer */
r_fmt       .req r0
/* Stack argument base, minus four registers */
r_arg_base  .req r8
/* Last retrieved argument offset in bytes */
r_arg_off   .req r4
/* Character being processed/printed */
r_c         .req r5
/* Multi-purpose temporary register */
r_tmp       .req r6
/* Argument value */
r_arg       .req r7
/* Counter register */
r_i         .req r9
/* Transmit polling register */
r_poll      .req r10
/* UART0 base address */
r_uart_base .req r11

    push {r4-r11, lr}
    add r_arg_base, sp, (11 - 4 + 1 /* r4-r11 */ + 1 /* lr */ - 4 /* reg args */) * 4
    mov r_arg_off, 0
    ldr r_uart_base, =uart_base0

/* For each character/conversion specification in the format string */
uart_printf_loop:
    ldrb r_c, [r_fmt], 1
    cmp r_c, 0
    beq uart_printf_exit
    cmp r_c, '%
    beq uart_printf_spec
    bl uart_printf_putc
    b uart_printf_loop

/* Sub: print character in r_c */
uart_printf_putc:
    /* Wait for transmit hold register to clear (TXFIFOE == 1) */
1:
    ldr r_poll, [r_uart_base, uart_lsr]
    tst r_poll, 1 << 5                  /* TXFIFOE */
    beq 1b
    /* Output character */
    str r_c, [r_uart_base, uart_thr]
    bx lr

/* Process conversion specification */
uart_printf_spec:
    ldrb r_c, [r_fmt], 1
    cmp r_c, 0
    beq uart_printf_spec_incomplete
    cmp r_c, '%
    beq uart_printf_spec_percent
    cmp r_c, 's
    beq uart_printf_spec_string
    cmp r_c, 'x
    beq uart_printf_spec_hex_lower
    cmp r_c, 'X
    beq uart_printf_spec_hex_upper
    /* Output unknown conversion specification */
    mov r_tmp, r_c
    mov r_c, '%
    bl uart_printf_putc
    mov r_c, r_tmp
    bl uart_printf_putc
    b uart_printf_loop

/* Process incomplete conversion specification */
uart_printf_spec_incomplete:
    mov r_c, '%
    bl uart_printf_putc
    b uart_printf_exit

/* Process '%%' conversion specification */
uart_printf_spec_percent:
    bl uart_printf_putc
    b uart_printf_loop

/* Process '%s' conversion specification */
uart_printf_spec_string:
    bl uart_printf_get_arg
1:
    ldrb r_c, [r_arg], 1
    cmp r_c, 0
    beq uart_printf_loop
    bl uart_printf_putc
    b 1b

/* Process '%X' conversion specification */
uart_printf_spec_hex_upper:
    mov r_tmp, 'A - 10
    b uart_printf_spec_hex

/* Process '%x' conversion specification */
uart_printf_spec_hex_lower:
    mov r_tmp, 'a - 10
    /* FALL-THROUGH */

/* Process '%x' or '%X' conversion specification */
uart_printf_spec_hex:
    bl uart_printf_get_arg
    mov r_i, 32
1:
    subs r_i, r_i, 4
    bcc uart_printf_loop
    mov r_c, 0xF
    and r_c, r_c, r_arg, LSR r_i
    cmp r_c, 9
    addls r_c, r_c, '0
    addhi r_c, r_c, r_tmp
    bl uart_printf_putc
    b 1b

/* Sub: retrieve next argument to r_arg */
uart_printf_get_arg:
    add r_arg_off, r_arg_off, 4

    cmp r_arg_off, 4
    moveq r_arg, r1
    bxeq lr

    cmp r_arg_off, 8
    moveq r_arg, r2
    bxeq lr

    cmp r_arg_off, 12
    moveq r_arg, r3
    bxeq lr

    ldr r_arg, [r_arg_base, r_arg_off]
    bx lr

/* Exit routine */
uart_printf_exit:
    pop {r4-r11, pc}
