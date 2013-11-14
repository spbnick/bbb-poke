CC=arm-linux-gnueabi-

all: $(patsubst %.s,%.srec,$(wildcard *.s))

%.o: %.s
	$(CC)as -o $@ $<

%.elf: %.o
	$(CC)ld -Ttext=0x80300000 -e start -o $@ $<

%.srec: %.elf
	$(CC)objcopy -O srec $< $@

clean:
	rm -f *.o
	rm -f *.elf
	rm -f *.srec
