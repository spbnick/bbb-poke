/*
 * Test uart.S module
 */
.syntax unified

.data
str_empty:
    .asciz ""
str_0:
    .asciz "0"
str_1:
    .asciz "1"
str_2:
    .asciz "2"
str_3:
    .asciz "3"
str_4:
    .asciz "4"
str_5:
    .asciz "5"
str_6:
    .asciz "6"
str_one_char:
    .asciz "a"
str_two_chars:
    .asciz "\r\n"
str_many_chars:
    .ascii "Lorem ipsum dolor sit amet, consectetur adipisicing elit, "
    .ascii "sed do eiusmod tempor incididunt ut labore et dolore magna "
    .asciz "aliqua.\r\n"
fmt_incomplete_spec:
    .asciz "%"
fmt_unknown_spec:
    .asciz "%Y"
fmt_percent_spec:
    .asciz "%%"
fmt_mixed:
    .asciz "\r\nabc%%def\r\n"
fmt_str:
    .asciz "%s"
fmt_four_str:
    .asciz "|%s|%s|%s|%s|\r\n"
fmt_five_str:
    .asciz "|%s|%s|%s|%s|%s|\r\n"
fmt_xxXX:
    .asciz "%x%x %X%X\r\n"
fmt_c:
    .asciz "%c\r\n"

.macro printf_test1 fmt
    ldr r0, =\fmt
    bl uart_printf
.endm

.macro printf_test2 fmt, arg1
    ldr r0, =\fmt
    ldr r1, =\arg1
    bl uart_printf
.endm

.macro printf_test5 fmt, arg1, arg2, arg3, arg4
    ldr r0, =\arg4
    push {r0}
    ldr r0, =\fmt
    ldr r1, =\arg1
    ldr r2, =\arg2
    ldr r3, =\arg3
    bl uart_printf
    pop {r0}
.endm

.macro printf_test6 fmt, arg1, arg2, arg3, arg4, arg5
    ldr r0, =\arg4
    ldr r1, =\arg5
    push {r0,r1}
    ldr r0, =\fmt
    ldr r1, =\arg1
    ldr r2, =\arg2
    ldr r3, =\arg3
    bl uart_printf
    add sp, sp, 8
.endm

.text
.global start
start:
    push {lr}

    /*
     * Test uart_printf
     */
    printf_test1 str_empty
    printf_test1 str_one_char
    printf_test1 str_two_chars
    printf_test1 str_many_chars
    printf_test1 fmt_incomplete_spec
    printf_test1 fmt_unknown_spec
    printf_test1 fmt_percent_spec
    printf_test1 fmt_mixed
    printf_test2 fmt_str, str_empty
    printf_test2 fmt_str, str_one_char
    printf_test2 fmt_str, str_two_chars
    printf_test2 fmt_str, str_many_chars
    printf_test5 fmt_four_str, str_0, str_1, str_2, str_3
    printf_test6 fmt_five_str, str_0, str_1, str_2, str_3, str_4
    printf_test5 fmt_xxXX, 0x01234567, 0x89abcdef, 0x01234567, 0x89abcdef
    printf_test2 fmt_c, 'A
    printf_test2 fmt_c, 0x100 + 'A

    /*
     * Test uart_hexdump
     */
    /* Output 0 bytes */
    mov r0, 0
    mov r1, 0
    bl uart_hexdump

    /* Output 1 byte */
    mov r0, 0
    push {r0}
    mov r0, sp
    mov r1, 1
    bl uart_hexdump
    add sp, sp, 4

    /* Output 256 bytes */
    mov r2, 0x100 / 4
    mrs r0, apsr
    tst r0, 1 << 9
    ldrne r0, =0xfcfdfeff
    ldreq r0, =0xfffefdfc
    ldr r1, =0x04040404
1:
    push {r0}
    usub8 r0, r0, r1
    subs r2, r2, 1
    bne 1b

    mov r0, sp
    mov r1, 0x100
    bl uart_hexdump
    add sp, sp, 0x100

    mov r0, 0
    pop {pc}
