/*
 * I2C handling
 */

.syntax unified

i2c_sysc            = 0x10
i2c_sysc_srst       = 1 << 1
i2c_irqstatus_raw   = 0x24
i2c_irqstatus_xdr   = 1 << 14
i2c_irqstatus_rdr   = 1 << 13
i2c_irqstatus_bb    = 1 << 12
i2c_irqstatus_rovr  = 1 << 11
i2c_irqstatus_xudf  = 1 << 10
i2c_irqstatus_aas   = 1 << 9
i2c_irqstatus_bf    = 1 << 8
i2c_irqstatus_aerr  = 1 << 7
i2c_irqstatus_stc   = 1 << 6
i2c_irqstatus_gc    = 1 << 5
i2c_irqstatus_xrdy  = 1 << 4
i2c_irqstatus_rrdy  = 1 << 3
i2c_irqstatus_ardy  = 1 << 2
i2c_irqstatus_nack  = 1 << 1
i2c_irqstatus_al    = 1 << 0
i2c_irqstatus       = 0x28
i2c_syss            = 0x90
i2c_syss_rdone      = 1
i2c_con             = 0xa4
i2c_con_en          = 1 << 15
i2c_con_stt         = 1 << 0
i2c_con_stp         = 1 << 1
i2c_con_trx         = 1 << 9
i2c_con_mst         = 1 << 10
i2c_oa              = 0xa8
i2c_psc             = 0xb0
i2c_scll            = 0xb4
i2c_sclh            = 0xb8
i2c_cnt             = 0x98
i2c_data            = 0x9c
i2c_sa              = 0xac

.text

/*
 * Initialize an I2C peripheral
 *
 * @param base  Register base address.
 */
.global i2c_init
i2c_init:

r_base      .req r0
r_tmp       .req r1

    /* Do soft reset */
    mov r_tmp, i2c_sysc_srst
    str r_tmp, [r_base, i2c_sysc]

    /* Set prescaler to obtain ICLK = 12 MHz from SCLK = 48 Mhz */
    mov r_tmp, 3 /* divisor = 4 */
    str r_tmp, [r_base, i2c_psc]

    /* Set low/high time to get SCL of 100 MHz and duty about 50% */
    mov r_tmp, 0x36 /* U-boot setup: 61 ICLK low, 59 ICLK high */
    str r_tmp, [r_base, i2c_scll]
    str r_tmp, [r_base, i2c_sclh]

    /* Set own address to 1 */
    mov r_tmp, 1
    str r_tmp, [r_base, i2c_oa]

    /* Enable the module */
    mov r_tmp, i2c_con_en
    str r_tmp, [r_base, i2c_con]

    /* Wait for reset */
1:
    ldr r_tmp, [r_base, i2c_syss]
    tst r_tmp, i2c_syss_rdone
    beq 1b

.unreq r_base
.unreq r_tmp

    mov r0, 0
    bx lr

/*
 * Read a number of bytes from an I2C slave at a 2-byte address.
 *
 * @param base          Register base address.
 * @param slave_addr    Slave address << 16 | address to read from.
 * @param ptr           Pointer to buffer for bytes read from the slave.
 * @param len           Number of bytes to read.
 *
 * @return Number of unwritten bytes.
 */
.global i2c_write
i2c_write:

r_base          .req r0
r_slave_addr    .req r1
r_ptr           .req r2
r_len           .req r3
r_tmp           .req r4

    push {r4-r11, lr}

    /* Clear all interrupt status bits */
    ldr r_tmp, =0xffff
    str r_tmp, [r_base, i2c_irqstatus]

    /*
     * Send the address
     */
    /* Set slave address */
    ubfx r_tmp, r_slave_addr, 16, 7
    str r_tmp, [r_base, i2c_sa]
    /* Set number of address bytes to transfer (2) */
    mov r_tmp, 2
    str r_tmp, [r_base, i2c_cnt]

    /* Start writing the address, don't stop (S A D D) */
    ldr r_tmp, =(i2c_con_en | i2c_con_mst | i2c_con_stt | i2c_con_trx)
    str r_tmp, [r_base, i2c_con]

    /* Wait for transmit-ready */
1:
    ldr r_tmp, [r_base, i2c_irqstatus_raw]
    tst r_tmp, i2c_irqstatus_xrdy
    beq 1b

    /* Write the first address byte */
    ubfx r_tmp, r_slave_addr, 8, 8
    str r_tmp, [r_base, i2c_data]

    /* Clear transmit-ready */
    mov r_tmp, i2c_irqstatus_xrdy
    str r_tmp, [r_base, i2c_irqstatus]

    /* Wait for transmit-ready */
1:
    ldr r_tmp, [r_base, i2c_irqstatus_raw]
    tst r_tmp, i2c_irqstatus_xrdy
    beq 1b

    /* Write the second address byte */
    ubfx r_tmp, r_slave_addr, 0, 8
    str r_tmp, [r_base, i2c_data]

    /* Clear transmit-ready */
    mov r_tmp, i2c_irqstatus_xrdy
    str r_tmp, [r_base, i2c_irqstatus]

    /* Wait for/clear end-of-transfer */
1:
    ldr r_tmp, [r_base, i2c_irqstatus_raw]
    tst r_tmp, i2c_irqstatus_ardy
    beq 1b
    mov r_tmp, i2c_irqstatus_ardy
    str r_tmp, [r_base, i2c_irqstatus]

    /*
     * Read the data
     */
    /* Set slave address */
    ubfx r_tmp, r_slave_addr, 16, 7
    str r_tmp, [r_base, i2c_sa]
    /* Set number of data bytes to transfer */
    ubfx r_tmp, r_len, 0, 16
    str r_tmp, [r_base, i2c_cnt]

    /* Start reading the data, stop (S A D * r_len P) */
    ldr r_tmp, =(i2c_con_en | i2c_con_mst | i2c_con_stt | i2c_con_stp)
    str r_tmp, [r_base, i2c_con]

1:
    /* Wait for receive-ready or transfer-done */
    ldr r_tmp, [r_base, i2c_irqstatus_raw]
    tst r_tmp, i2c_irqstatus_ardy
    bne i2c_write_exit
    tst r_tmp, i2c_irqstatus_rrdy
    beq 1b

    /* Transfer byte */
    ldr r_tmp, [r_base, i2c_data]
    strb r_tmp, [r_ptr], 1
    sub r_len, r_len, 1

    /* Clear receive-ready */
    mov r_tmp, i2c_irqstatus_rrdy
    str r_tmp, [r_base, i2c_irqstatus]

    /* Repeat */
    b 1b

i2c_write_exit:
    /* Clear all interrupt status bits */
    ldr r_tmp, =0xffff
    str r_tmp, [r_base, i2c_irqstatus]

    /* Exit */
    mov r0, r_len
    pop {r4-r11, pc}

.unreq  r_base
.unreq  r_slave_addr
.unreq  r_ptr
.unreq  r_len
.unreq  r_tmp

.data
pc_fmt:
    .asciz "PC: %x\r\n"
