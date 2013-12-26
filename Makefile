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

all: $(addsuffix .srec, $(PROGRAMS))

%.o: %.S
	$(CC)gcc -c -o $@ $<

define ELF_RULE
$(strip $(1))_OBJS = $$(addsuffix .o, $(1) $$($(strip $(1))_MODULES))
$(1).elf: $$($(strip $(1))_OBJS)
	$(CC)ld -T packed.ld -o $$@ $$^
OBJS += $$($(strip $(1))_OBJS)
endef
$(foreach p, $(PROGRAMS), $(eval $(call ELF_RULE, $(p))))

%.srec: %.elf
	$(CC)objcopy -O srec $< $@

clean:
	rm -f $(OBJS)
	rm -f $(addsuffix .elf, $(PROGRAMS))
	rm -f $(addsuffix .srec, $(PROGRAMS))
