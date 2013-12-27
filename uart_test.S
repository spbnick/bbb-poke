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

.macro test1 fmt
    ldr r0, =\fmt
    bl uart_printf
.endm

.macro test2 fmt, arg1
    ldr r0, =\fmt
    ldr r1, =\arg1
    bl uart_printf
.endm

.macro test5 fmt, arg1, arg2, arg3, arg4
    ldr r0, =\arg4
    push {r0}
    ldr r0, =\fmt
    ldr r1, =\arg1
    ldr r2, =\arg2
    ldr r3, =\arg3
    bl uart_printf
    pop {r0}
.endm

.macro test6 fmt, arg1, arg2, arg3, arg4, arg5
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

    test1 str_empty
    test1 str_one_char
    test1 str_two_chars
    test1 str_many_chars
    test1 fmt_incomplete_spec
    test1 fmt_unknown_spec
    test1 fmt_percent_spec
    test1 fmt_mixed
    test2 fmt_str, str_empty
    test2 fmt_str, str_one_char
    test2 fmt_str, str_two_chars
    test2 fmt_str, str_many_chars
    test5 fmt_four_str, str_0, str_1, str_2, str_3
    test6 fmt_five_str, str_0, str_1, str_2, str_3, str_4
    test5 fmt_xxXX, 0x01234567, 0x89abcdef, 0x01234567, 0x89abcdef
    test2 fmt_c, 'A
    test2 fmt_c, 0x100 + 'A

    mov r0, 0
    pop {pc}
