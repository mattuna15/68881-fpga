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
LIB_GFX  = $(LIB_DIR)/merlin2_gfx.c $(LIB_DIR)/merlin2_rand.c
LIB_RTC  = $(LIB_DIR)/merlin2_gfx.c $(LIB_DIR)/merlin2_rtc.c

# FPU examples need -m68881
FPU_CFLAGS = $(CFLAGS) -m68881 -Wa,-mcpu=68020 -ffast-math -I$(LIB_DIR)

# Non-FPU C flags with lib include path
CFLAGS_LIB = $(CFLAGS) -I$(LIB_DIR)

all: hello.srec hello.lst fputest.srec fputest.lst fireworks.srec fireworks.lst rtctest.srec

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
fireworks.srec: fireworks.c $(LIB_GFX)
	$(CC) $(FPU_CFLAGS) $(LDFLAGS) -o $@ $< $(LIB_GFX) -lm

fireworks.lst: fireworks.c
	$(CC) $(FPU_CFLAGS) -S -fverbose-asm -o $@ $<

# RTC test (no FPU needed, uses gfx lib for char_ready + rtc lib)
rtctest.srec: rtctest.c $(LIB_RTC)
	$(CC) $(CFLAGS_LIB) $(LDFLAGS) -o $@ $< $(LIB_RTC)

clean:
	rm -f *.srec *.lst *.o
