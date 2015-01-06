ENTRY(start)

SECTIONS {
    . = 0x402f0400;
    .text : { *(.text) }
    .data : { *(.data) }
}
