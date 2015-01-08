.syntax unified

cm_per_base             = 0x44e00000
cm_per_gpio1_clkctrl    = 0xac

ctrl_base               = 0x44e10000
ctrl_conf_gpmc_a5       = 0x854
ctrl_conf_gpmc_a6       = 0x858
ctrl_conf_gpmc_a7       = 0x85C
ctrl_conf_gpmc_a8       = 0x860

gpio1_base              = 0x4804c000
gpio_oe                 = 0x134
gpio_cleardataout       = 0x190
gpio_setdataout         = 0x194

.text
.global start
start:

    r_base .req r0
    r_tmp .req r1

    /* Set pinmux to GPIO1_21-24 */
    ldr r_base, =ctrl_base
    mov r_tmp, 0x27 /* Fast slew, mode 7 */
    str r_tmp, [r_base, ctrl_conf_gpmc_a5]
    str r_tmp, [r_base, ctrl_conf_gpmc_a6]
    str r_tmp, [r_base, ctrl_conf_gpmc_a7]
    str r_tmp, [r_base, ctrl_conf_gpmc_a8]

    /* Enable the GPIO1 module clock */
    ldr r_base, =cm_per_base
    mov r_tmp, 2   /* Enabled */
    str r_tmp, [r_base, cm_per_gpio1_clkctrl]

    /* Enable pins 21-24 for output */
    ldr r_base, =gpio1_base
    ldr r_tmp, =~(0xf << 21)
    str r_tmp, [r_base, gpio_oe]

    /* Turn on pins 21-24 */
    ldr r_tmp, =(0xf << 21)
    str r_tmp, [r_base, gpio_setdataout]

    .unreq r_base
    .unreq r_tmp
loop:
    wfe
    b loop
