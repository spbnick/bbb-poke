gpio1_base          = 0x4804c000
gpio_oe             = 0x134
gpio_cleardataout   = 0x190
gpio_setdataout     = 0x194

.text
.global start
start:
    movw r1, (gpio1_base & 0xffff)
    movt r1, (gpio1_base >> 16)
    mov r2, #0xfe1fffff
    str r2, [r1, #gpio_oe]
    mvn r2, r2
    str r2, [r1, #gpio_cleardataout]
    str r2, [r1, #gpio_setdataout]
loop:
    wfe
    b loop
