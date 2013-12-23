CC=arm-linux-gnueabi-

PROGRAMS = \
    animate_leds        \
    blink_leds          \
    light_leds          \
    light_leds_hardirq  \
    light_leds_softirq  \
    light_leds_svc      \
    serial_hello

all: $(addsuffix .srec, $(PROGRAMS))

%.o: %.S
	$(CC)as -o $@ $<

define ELF_RULE
$(strip $(1))_OBJS = $$(addsuffix .o, $(1) $$($(strip $(1))_MODULES))
$(1).elf: $$($(strip $(1))_OBJS)
	$(CC)ld -Ttext=0x80300000 -e start -o $$@ $$^
OBJS += $$($(strip $(1))_OBJS)
endef
$(foreach p, $(PROGRAMS), $(eval $(call ELF_RULE, $(p))))

%.srec: %.elf
	$(CC)objcopy -O srec $< $@

clean:
	rm -f $(OBJS)
	rm -f $(addsuffix .elf, $(PROGRAMS))
	rm -f $(addsuffix .srec, $(PROGRAMS))
