# Build NeXTMach standalone boot for 68040 using m68k-elf-gcc
#
# Cross-compiles stand/ sources from mk-108.1 into a flat ROM binary.

CC      = m68k-elf-gcc
AS      = m68k-elf-as
LD      = m68k-elf-ld
OBJCOPY = m68k-elf-objcopy

# Source tree
NEXT    = ../../../NeXTMach/mk-108.1

# Include paths: stand/, kernel headers, mon/
INCPATH = -I$(NEXT)/stand -I$(NEXT) -I$(NEXT)/mon -I./shim

# GCC flags: 68040, standalone, treat #import as #include
CFLAGS  = -m68040 -nostdinc -ffreestanding -fno-builtin \
          -DSTANDALONE -DSUN_NFS -DMONITOR -DKERNEL \
          -include shim/import_shim.h \
          $(INCPATH) -O1 -Wall -Wno-implicit-function-declaration \
          -Wno-implicit-int -Wno-return-type -Wno-parentheses

ASFLAGS = -m68040

# Link at NeXT standalone address
LDFLAGS = -Ttext=0x04380000 -nostdlib

# Objects
OBJS    = sacrt0.o boot.o sainit.o sys.o conf.o prf.o dma.o \
          sc.o sd.o cksum.o od.o zs.o en.o ctype_.o misc.o

all: nextboot.bin

# Assembly files need cpp preprocessing
sacrt0.o: $(NEXT)/stand/sacrt0.s
	$(CC) $(CFLAGS) -DASSEMBLER -c -x assembler-with-cpp $< -o $@

misc.o: $(NEXT)/stand/misc.s
	$(CC) $(CFLAGS) -DASSEMBLER -c -x assembler-with-cpp $< -o $@

# C files from stand/
%.o: $(NEXT)/stand/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link
nextboot.elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

# Flat binary
nextboot.bin: nextboot.elf
	$(OBJCOPY) -O binary $< $@
	@ls -la $@
	@echo "ROM image ready: $@ (load at 0x04380000)"

# C header for embedding in ARM firmware
nextboot.h: nextboot.bin
	xxd -i $< > $@
	@echo "Generated $@"

clean:
	rm -f *.o *.elf *.bin *.h

.PHONY: all clean
