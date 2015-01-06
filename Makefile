CC=arm-none-eabi-

TARGET_CFLAGS=-mcpu=cortex-a8 -mfloat-abi=hard -mfpu=vfpv3 -marm

PROGRAMS = \
    animate_leds        \
    blink_leds          \
    debug_test          \
    lcd_pattern         \
    lcd_static          \
    light_leds          \
    light_leds_hardirq  \
    light_leds_softirq  \
    light_leds_svc      \
    uart_test           \
    serial_hello        \
    eeprom_dump

uart_test_MODULES = uart
debug_test_MODULES = uart debug
eeprom_dump_MODULES = uart i2c

all: $(PROGRAMS:=.srec) $(PROGRAMS:=.bin) $(PROGRAMS:=.spl)

%.o: %.S
	$(CC)gcc $(TARGET_CFLAGS) -g3 -D__ASSEMBLY__ -c -o $@ $<
	$(CC)gcc $(TARGET_CFLAGS) -D__ASSEMBLY__ -MM $< > $*.d

define ELF_RULE
$(strip $(1))_OBJS = $$(addsuffix .o, $(1) $$($(strip $(1))_MODULES))
$(1).u-boot.elf: $$($(strip $(1))_OBJS)
	$(CC)ld -T u-boot.ld -o $$@ $$^
$(1).spl.elf: $$($(strip $(1))_OBJS)
	$(CC)ld -T spl.ld -o $$@ $$^
OBJS += $$($(strip $(1))_OBJS)
endef
$(foreach p, $(PROGRAMS), $(eval $(call ELF_RULE, $(p))))
DEPS = $(OBJS:.o=.d)
-include $(DEPS)

%.srec: %.u-boot.elf
	$(CC)objcopy -O srec $< $@

%.bin: %.spl.elf
	$(CC)objcopy -j .text -j .data -O binary $< $@

%.spl: %.bin
	mkimage -T omapimage -a 0x402F0400 -d $< $@

clean:
	rm -f $(OBJS)
	rm -f $(DEPS)
	rm -f $(PROGRAMS:=.u-boot.elf)
	rm -f $(PROGRAMS:=.spl.elf)
	rm -f $(PROGRAMS:=.srec)
	rm -f $(PROGRAMS:=.bin)
	rm -f $(PROGRAMS:=.spl)
