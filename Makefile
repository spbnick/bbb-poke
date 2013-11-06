CC=arm-linux-gnueabi-

light_leds.srec: light_leds
	$(CC)objcopy -O srec $< $@
light_leds: light_leds.o
	$(CC)ld -Ttext=0x80300000 -o $@ -e start $<

clean:
	rm -f *.o
	rm -f light_leds
	rm -f *.srec

.s.o:
	$(CC)as -o $@ $<
