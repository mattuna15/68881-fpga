/*
 * sd_floppy.h
 * Load .ST floppy image from SD card via FatFs.
 */

#ifndef SD_FLOPPY_H
#define SD_FLOPPY_H

#include <stdint.h>

/* Mount FAT filesystem on SD card and load a .ST image file.
 * filename: base filename to look for (e.g. "DISK_A.ST")
 * buffer: destination buffer for image data
 * max_size: maximum bytes to read
 * Returns: number of bytes read, or 0 on failure. */
uint32_t sd_floppy_load(const char *filename, uint8_t *buffer, uint32_t max_size);

#endif /* SD_FLOPPY_H */
