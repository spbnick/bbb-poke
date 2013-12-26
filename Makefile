CC=arm-linux-gnueabihf-

PROGRAMS = \
    animate_leds        \
    blink_leds          \
    light_leds          \
    light_leds_hardirq  \
    light_leds_softirq  \
    light_leds_svc      \
    uart_test           \
    serial_hello

uart_test_MODULES = uart

all: $(PROGRAMS:=.srec)

%.o: %.S
	$(CC)gcc -D__ASSEMBLY__ -c -o $@ $<
	$(CC)gcc -D__ASSEMBLY__ -MM $< > $*.d

define ELF_RULE
$(strip $(1))_OBJS = $$(addsuffix .o, $(1) $$($(strip $(1))_MODULES))
$(1).elf: $$($(strip $(1))_OBJS)
	$(CC)ld -T packed.ld -o $$@ $$^
OBJS += $$($(strip $(1))_OBJS)
endef
$(foreach p, $(PROGRAMS), $(eval $(call ELF_RULE, $(p))))
DEPS = $(OBJS:.o=.d)
-include $(DEPS)

%.srec: %.elf
	$(CC)objcopy -O srec $< $@

clean:
	rm -f $(OBJS)
	rm -f $(DEPS)
	rm -f $(PROGRAMS:=.elf)
	rm -f $(PROGRAMS:=.srec)
