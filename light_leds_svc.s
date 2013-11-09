/*
 * Light LEDs in an SVC (SWI) handler
 */
.syntax unified

ram_vector_base         = 0x4030ce00
ram_vector_svc          = 0x28 

gpio1_base              = 0x4804c000
gpio_oe                 = 0x0134
gpio_cleardataout       = 0x0190
gpio_setdataout         = 0x0194

.text
.global start
start:
    /*
     * Setup vectors
     */
    ldr r1, =ram_vector_base
    /* Set VBAR to point to the default (L3 RAM) vector table */
    mcr p15, 0, r1, c12, c0, 0
    /* Setup SVC vector */
    ldr r2, =svc
    str r2, [r1, ram_vector_svc]

    /* Call SVC */
    svc 0x0

    /* Wait for exceptions indefinitely */
loop:
    wfe
    b loop

    /*
     * SVC handler
     */
svc:
    /* Save registers */
    push {r1, r2}

    /* Light the LEDs */
    ldr r1, =gpio1_base
    ldr r2, =0xfe1fffff
    str r2, [r1, gpio_oe]
    mvn r2, r2
    str r2, [r1, gpio_cleardataout]
    str r2, [r1, gpio_setdataout]

    /* Restore registers */
    pop {r1, r2}

    /* Return from SVC exception */
    movs pc, lr

pool:
.pool
