bbb-poke
========

This is a collection of programs done as exercises for learning ARM
architecture, assembly, embedded hardware and BeagleBone Black in particular.
It is published in the hope that it will be useful for others learning the
same.

Building
--------

Run `make CC=<compiler-linker-prefix>`, where `<compiler-linker-prefix>` is a
compiler/linker prefix, e.g. `arm-linux-gnueabihf-`, or just run `make` if you
have compiler/linker with this prefix installed as it is the Makefile's
default.

Running
-------

All the programs expect to be run on bare hardware, from U-boot. In U-boot,
execute `loads` and paste the contents of the .srec file you wish to run. This
will load the program to RAM. Execute `go 80300000` to run it. Reset the board
to stop.
