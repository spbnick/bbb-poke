/*
 * Animate LEDs with variable brightness within timer interrupt
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

intc_ilr                = 0x0100
intc_ilr_timer0         = intc_ilr + int_timer0

gpio1_base              = 0x4804c000
gpio_oe                 = 0x0134
gpio_dataout            = 0x013c
gpio_cleardataout       = 0x0190
gpio_setdataout         = 0x0194
gpio_leds_lsb           = 21
gpio_leds_num           = 4
gpio_leds_mask          = ((1 << gpio_leds_num) - 1) << gpio_leds_lsb

timer0_base             = 0x44e05000 
timer_tiocp_cfg         = 0x10
timer_irqstatus         = 0x28
timer_irqenable_set     = 0x2c
timer_irqenable_clr     = 0x30
timer_tclr              = 0x38
timer_tcrr              = 0x3c
timer_tldr              = 0x40

counter_tick            = 32000/8192     /* In 1/32000 of second */
step_lsb                = 10
step_width              = 5
br_max                  = 8

.text
.global start
start:

    /*
     * Interrupt controller setup
     */
    ldr r0, =intc_base

    /* Reset */
    mov r1, 2
    str r1, [r0, intc_sysconfig]

    /* Wait for reset */
intc_wait:
    ldr r1, [r0, intc_sysstatus]
    ands r1, 1
    beq intc_wait

    /* Enable timer interrupt */
    ldr r0, =intc_bank_timer0_base
    ldr r1, =intc_bank_timer0_mask
    str r1, [r0, intc_bank_mir_clear]

    /* Enable interrupts on the CPU */
    cpsie i

    /*
     * Vector table setup
     */
    ldr r0, =ram_vector_base
    /* Set VBAR to point to the default (L3 RAM) vector table */
    mcr p15, 0, r0, c12, c0, 0
    /* Setup IRQ vector */
    ldr r1, =isr
    str r1, [r0, ram_vector_irq]

    /*
     * Timer0 setup
     */
    ldr r0, =timer0_base

    /* Reset */
    mov r1, 1
    str r1, [r0, timer_tiocp_cfg]
timer0_wait:
    ldr r1, [r0, timer_tiocp_cfg]
    cmp r1, 0
    bne timer0_wait

    /* Prime the timer */
    mov r1, -counter_tick
    str r1, [r0, timer_tldr]
    str r1, [r0, timer_tcrr]

    /* Enable overflow interrupt */
    mov r1, 2                           /* Overflow interrupt */
    str r1, [r0, timer_irqenable_set]

    /*
     * Setup LEDs GPIO and turn them off
     */
    ldr r0, =gpio1_base
    ldr r1, =~gpio_leds_mask
    str r1, [r0, gpio_oe]
    mvn r1, r1
    str r1, [r0, gpio_cleardataout]

    /*
     * Start auto-reload timer
     */
    ldr r0, =timer0_base
    mov r1, 3                           /* Auto-reload, start */
    str r1, [r0, timer_tclr]

    /*
     * Wait for exceptions indefinitely
     */
loop:
    wfe
    b loop

    /*
     * Interrupt service routine
     */
isr:
    /* Save registers */
    push {r0, r1, r2, r3, r4, r5, r6, r7, r8}

    /* Check that this is the timer interrupt */
    ldr r0, =intc_base
    ldr r1, [r0, intc_sir_irq]
    and r1, r1, 0x7F                    /* ActiveIRQ field */
    cmp r1, int_timer0
    bne isr_exit

    /* Check that this is the overflow interrupt */
    ldr r0, =timer0_base
    ldr r1, [r0, timer_irqstatus]
    tst r1, 2                           /* Overflow */
    beq isr_timer_exit

    /*
     * Update LEDs
     */
    /* Load tick counter */
    r_counter .req r1
    ldr r0, =counter
    ldr r_counter, [r0]

    /* Extract step counter */
    r_step .req r2
    ubfx r_step, r_counter, step_lsb, step_width

    r_pulse_mask    .req r3
    mov r_pulse_mask, (1 << br_max) - 1
    r_led_mask      .req r4
    mov r_led_mask, 0
    r_led_num       .req r5
    mov r_led_num, gpio_leds_num

    r_led_sh        .req r6
    r_led_br        .req r7
    r_led_bit       .req r8
    /* For each LED and step */
isr_led_loop:
    /* Calculate LED brightness */
    ubfx r_led_sh, r_step, 0, step_width - 1
    subs r_led_sh, r_led_sh, 1 << (step_width - 2)
    rsbmi r_led_sh, r_led_sh, 0
    mov r_led_br, br_max
    lsr r_led_br, r_led_br, r_led_sh
    /* Apply pulse mask */
    tst r_counter, r_pulse_mask, lsr r_led_br
    moveq r_led_bit, 1
    movne r_led_bit, 0
    /* Append LED bit to the LED mask */
    orr r_led_mask, r_led_bit, r_led_mask, lsl 1
    /* Move next step */
    add r_step, r_step, 1
    /* Move next LED */
    subs r_led_num, r_led_num, 1
    bne isr_led_loop

    /* Increment and store tick counter */
    add r_counter, r_counter, 1
    str r_counter, [r0]

    /* Set the LEDs */
    ldr r0, =gpio1_base
    lsl r_led_mask, r_led_mask, gpio_leds_lsb
    str r_led_mask, [r0, gpio_dataout]

    .unreq r_led_bit
    .unreq r_led_br
    .unreq r_led_sh
    .unreq r_led_num
    .unreq r_led_mask
    .unreq r_pulse_mask
    .unreq r_step
    .unreq r_counter

isr_timer_exit:
    /* Clear timer interrupts */
    ldr r0, =timer0_base
    ldr r1, [r0, timer_irqstatus]
    mov r1, 7                           /* Capture, overflow, and match */
    str r1, [r0, timer_irqstatus]

isr_exit:
    /* Enable new IRQs */
    ldr r0, =intc_base
    mov r1, 1                           /* IRQ */
    str r1, [r0, intc_control]

    /* Data Synchronization Barrier mov r0, #0 */
    mcr p15, 0, r0, c7, c10, 4

    /* Restore registers */
    pop {r0, r1, r2, r3, r4, r5, r6, r7, r8}

    /* Return from IRQ exception */
    subs pc, lr, 4

pool:
.pool

.data
counter:
.word       0x00000000
