STARTUP(merlin2-crt0.o)
OUTPUT_ARCH(m68k)
OUTPUT_FORMAT(srec)

SEARCH_DIR(.)
GROUP(-lmerlin2 -lc -lgcc)
__DYNAMIC  =  0;

/*
 * Memory map of the Merlin 2 emulator:
 *
 * +--------------------+ 0x000000  Exception vectors (ROM alias)
 * | BIOS workspace     |
 * +--------------------+ 0x002000  Program RAM starts here
 * | .text              |
 * |        _etext      |
 * |        ctor list   |
 * |        dtor list   |
 * +--------------------+
 * | .data              |
 * |        _edata      |
 * +--------------------+
 * | .bss               |
 * |        __bss_start |
 * |        _end        | start of heap, used by sbrk()
 * +--------------------+
 * .         ...        .
 * .       (heap)       .
 * .         ...        .
 * |        __stack     | 0x7FDFFC  top of stack (grows down)
 * +--------------------+ 0x7FE000
 * .    (reserved gap)  .
 * +--------------------+ 0x800000  Graphics framebuffer (3.6 MB)
 * .         ...        .
 * +--------------------+ 0xFD0000  I/O registers
 * +--------------------+ 0xFE0000  BIOS ROM
 */

MEMORY
{
  ram (rwx) : ORIGIN = 0x2000, LENGTH = 0x7FC000
}

/*
 * Stack at top of program RAM, below the framebuffer region.
 * Aligned to longword boundary.
 */
PROVIDE (__stack = 0x7FDFFC);

/*
 * Provide zero-valued hooks so crt0 can reference them safely.
 */
PROVIDE (hardware_init_hook = 0);
PROVIDE (_hardware_init_hook = 0);
PROVIDE (software_init_hook = 0);
PROVIDE (_software_init_hook = 0);

SECTIONS
{
  .text :
  {
    *(.text .text.*)
    . = ALIGN(0x4);
     __CTOR_LIST__ = .;
    ___CTOR_LIST__ = .;
    LONG((__CTOR_END__ - __CTOR_LIST__) / 4 - 2)
    *(.ctors)
    LONG(0)
    __CTOR_END__ = .;
    __DTOR_LIST__ = .;
    ___DTOR_LIST__ = .;
    LONG((__DTOR_END__ - __DTOR_LIST__) / 4 - 2)
    *(.dtors)
     LONG(0)
    __DTOR_END__ = .;
    *(.rodata .rodata.*)
    *(.gcc_except_table)

    . = ALIGN(0x2);
    __INIT_SECTION__ = . ;
    LONG (0x4e560000)	/* linkw %fp,#0 */
    *(.init)
    SHORT (0x4e5e)	/* unlk %fp */
    SHORT (0x4e75)	/* rts */

    __FINI_SECTION__ = . ;
    LONG (0x4e560000)	/* linkw %fp,#0 */
    *(.fini)
    SHORT (0x4e5e)	/* unlk %fp */
    SHORT (0x4e75)	/* rts */

    _etext = .;
    *(.lit)
  } > ram

  .data :
  {
    __data_start = .;
    *(.got.plt) *(.got)
    *(.shdata)
    *(.data .data.*)
    _edata = .;
  } > ram

  .bss :
  {
    . = ALIGN(0x4);
    __bss_start = . ;
    *(.shbss)
    *(.bss .bss.*)
    *(COMMON)
    _end =  ALIGN (0x8);
    __end = _end;
  } > ram

  .stab 0 (NOLOAD) :
  {
    *(.stab)
  }

  .stabstr 0 (NOLOAD) :
  {
    *(.stabstr)
  }
}
