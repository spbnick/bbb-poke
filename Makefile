CC=arm-linux-gnueabi-

all: $(patsubst %.S,%.srec,$(wildcard *.S))

%.o: %.S
	$(CC)as -o $@ $<

%.elf: %.o
	$(CC)ld -Ttext=0x80300000 -e start -o $@ $<

%.srec: %.elf
	$(CC)objcopy -O srec $< $@

clean:
	rm -f *.o
	rm -f *.elf
	rm -f *.srec
