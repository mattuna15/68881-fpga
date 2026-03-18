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

# FPU examples need -m68881
FPU_CFLAGS = $(CFLAGS) -m68881 -Wa,-mcpu=68020 -ffast-math

SRCS     = hello.c fputest.c
SRECS    = $(SRCS:.c=.srec)
LSTS     = $(SRCS:.c=.lst)

all: $(SRECS) $(LSTS)

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

clean:
	rm -f $(SRECS) $(LSTS) *.o
