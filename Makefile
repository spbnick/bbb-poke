CC=arm-linux-gnueabi-

all: light_leds.srec light_leds_svc.srec light_leds_softirq.srec

light_leds.srec: light_leds
	$(CC)objcopy -O srec $< $@
light_leds: light_leds.o
	$(CC)ld -Ttext=0x80300000 -e start -o $@ $<

light_leds_svc.srec: light_leds_svc
	$(CC)objcopy -O srec $< $@
light_leds_svc: light_leds_svc.o
	$(CC)ld -Ttext=0x80300000 -e start -o $@ $<

light_leds_softirq.srec: light_leds_softirq
	$(CC)objcopy -O srec $< $@
light_leds_softirq: light_leds_softirq.o
	$(CC)ld -Ttext=0x80300000 -e start -o $@ $<

clean:
	rm -f *.o
	rm -f light_leds
	rm -f light_leds_svc
	rm -f light_leds_softirq
	rm -f *.srec

.s.o:
	$(CC)as -o $@ $<
