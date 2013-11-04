CC=arm-linux-gnueabi-

asm_leds.srec: asm_leds
	$(CC)objcopy -O srec $< $@
asm_leds: asm_leds.o
	$(CC)ld -Ttext=0x80300000 -o $@ -e start $<

clean:
	rm *.o
	rm asm_leds
	rm *.srec

.s.o:
	$(CC)as -o $@ $<
