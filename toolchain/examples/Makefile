# Merlin 2 GCC examples
#
# Usage:
#   make              -- build all examples
#   make hello.srec   -- build just hello
#   make clean        -- remove build artifacts

PREFIX  ?= m68k-elf-
CC       = $(PREFIX)gcc
CFLAGS   = -m68000 -O2 -Wall
LDFLAGS  = -Tmerlin2.ld

# Library sources
LIB_DIR  = ../lib
LIB_SRCS = $(LIB_DIR)/merlin2_gfx.c $(LIB_DIR)/merlin2_rand.c

# FPU examples need -m68881
FPU_CFLAGS = $(CFLAGS) -m68881 -Wa,-mcpu=68020 -ffast-math -I$(LIB_DIR)

all: hello.srec hello.lst fputest.srec fputest.lst fireworks.srec fireworks.lst

# Non-FPU targets
hello.srec: hello.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

hello.lst: hello.c
	$(CC) $(CFLAGS) -S -fverbose-asm -o $@ $<

# FPU targets
fputest.srec: fputest.c
	$(CC) $(FPU_CFLAGS) $(LDFLAGS) -o $@ $< -lm

fputest.lst: fputest.c
	$(CC) $(FPU_CFLAGS) -S -fverbose-asm -o $@ $<

# Fireworks (FPU + graphics library)
fireworks.srec: fireworks.c $(LIB_SRCS)
	$(CC) $(FPU_CFLAGS) $(LDFLAGS) -o $@ $< $(LIB_SRCS) -lm

fireworks.lst: fireworks.c
	$(CC) $(FPU_CFLAGS) -S -fverbose-asm -o $@ $<

clean:
	rm -f *.srec *.lst *.o
