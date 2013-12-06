/*
 * Print a fixed string on the serial port
 */
.syntax unified

uart0_base  = 0x44e09000
uart_dll    = 0x00
uart_dlh    = 0x04
uart_lcr    = 0x0c
uart_lsr    = 0x14
uart_sysc   = 0x54
uart_syss   = 0x58
uart_mdr1   = 0x20
uart_thr    = 0x00

.text
.global start
start:
    uart_base .req r0
    ldr uart_base, =uart0_base

    /* Reset: set UARTi.UART_SYSC[1] SOFTRESET to 1 */
    mov r1, 1
    str r1, [uart_base, uart_sysc]
    
    /* Wait for reset: poll for UARTi.UART_SYSS[0] RESETDONE == 1 */
uart_wait:
    ldr r1, [uart_base, uart_syss]
    cmp r1, 1
    bne uart_wait

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
    mov r1, 0x83
    str r1, [uart_base, uart_lcr]

    /* Set Baud Rate to 115200: assume DLH == 0 (default), set DLL = 0x1A */
    mov r1, 0x1a
    str r1, [uart_base, uart_dll]

    /* Enable UART 16x mode: set UARTi.UART_MDR1[2:0] MODESELECT to 0 */
    mov r1, 0
    str r1, [uart_base, uart_mdr1]

    /* Switch to Operational mode: clear UARTi.UART_LCR[7] DIV_EN */
    ldr r1, [uart_base, uart_lcr]
    bic r1, r1, 0x80
    str r1, [uart_base, uart_lcr]

    /*
     * Output the message 16 times
     */
    mov r3, 16
repeat_loop:
    ldr r2, =message
message_loop:
    ldrb r1, [r2], 1
    cmp r1, 0
    beq message_quit
    /* Wait for transmit hold register to clear (TXFIFOE == 1) */
tx_wait:
    ldr r4, [uart_base, uart_lsr]
    tst r4, 1 << 5                  /* TXFIFOE */
    beq tx_wait
    /* Output character */
    str r1, [uart_base, uart_thr]
    b message_loop
message_quit:
    subs r3, r3, 1
    bne repeat_loop
    
stop_loop:
    wfe
    b stop_loop

pool:
.pool

.data
message:
.asciz  "Hello, serial!\r\n"
