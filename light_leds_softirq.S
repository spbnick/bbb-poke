/*
 * Light LEDs in an IRQ handler, triggered by software
 */
.syntax unified

ram_vector_base         = 0x4030ce00
ram_vector_irq          = 0x38 

int_timer0              = 66

intc_base               = 0x48200000
intc_sysconfig          = 0x10
intc_sysstatus          = 0x14
intc_sir_irq            = 0x40
intc_control            = 0x48
intc_bank_base          = 0x80
intc_bank_size          = 0x20
intc_bank_mir_clear     = 0x08
intc_bank_mir_set       = 0x0C
intc_bank_isr_set       = 0x10
intc_bank_isr_clear     = 0x14
intc_bank_timer0_base   = intc_base + intc_bank_base + int_timer0 / 32 * intc_bank_size
intc_bank_timer0_mask   = 1 << (int_timer0 % 32)

gpio1_base              = 0x4804c000
gpio_oe                 = 0x0134
gpio_cleardataout       = 0x0190
gpio_setdataout         = 0x0194

.text
.global start
start:

    /*
     * Interrupt controller setup
     */
    ldr r1, =intc_base

    /* Reset */
    mov r2, 2
    str r2, [r1, intc_sysconfig]

    /* Wait for reset */
intc_wait:
    ldr r2, [r1, intc_sysstatus]
    ands r2, 1
    beq intc_wait

    /* Enable timer interrupt */
    ldr r1, =intc_bank_timer0_base
    ldr r2, =intc_bank_timer0_mask
    str r2, [r1, intc_bank_mir_clear]

    /* Enable interrupts on the CPU */
    cpsie i

    /*
     * Vector table setup
     */
    ldr r1, =ram_vector_base
    /* Set VBAR to point to the default (L3 RAM) vector table */
    mcr p15, 0, r1, c12, c0, 0
    /* Setup IRQ vector */
    ldr r2, =isr
    str r2, [r1, ram_vector_irq]

    /*
     * Trigger timer interrupt
     */
    ldr r1, =intc_bank_timer0_base
    ldr r2, =intc_bank_timer0_mask
    str r2, [r1, intc_bank_isr_set]

    /* Wait for exceptions indefinitely */
loop:
    wfe
    b loop

    /*
     * Interrupt service routine
     */
isr:
    /* Save registers */
    push {r1, r2}

    /* Check that this is the timer interrupt */
    ldr r1, =intc_base
    ldr r2, [r1, intc_sir_irq]
    and r2, r2, 0x7F                    /* ActiveIRQ field */
    cmp r2, int_timer0
    bne isr_exit

    /* Light the LEDs */
    ldr r1, =gpio1_base
    ldr r2, =0xfe1fffff
    str r2, [r1, gpio_oe]
    mvn r2, r2
    str r2, [r1, gpio_cleardataout]
    str r2, [r1, gpio_setdataout]

    /* Deassert the software IRQ */
    ldr r1, =intc_bank_timer0_base
    ldr r2, =intc_bank_timer0_mask
    str r2, [r1, intc_bank_isr_clear]

isr_exit:
    /* Enable new IRQs */
    ldr r1, =intc_base
    mov r2, 1                           /* IRQ */
    str r2, [r1, intc_control]

    /* Data Synchronization Barrier mov r1, #0 */
    mcr p15, 0, r1, c7, c10, 4

    /* Restore registers */
    pop {r1, r2}

    /* Return from IRQ exception */
    subs pc, lr, 4

pool:
.pool
