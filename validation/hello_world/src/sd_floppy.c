/*
 * sd_floppy.c
 * Load .ST floppy image from FAT filesystem on SD card.
 *
 * Uses xilffs (FatFs) with the xsdps SD driver from the BSP.
 * Tries external SD slot ("1:/") first, then eMMC ("0:/").
 */

#include "sd_floppy.h"
#include "fatfs/ff.h"
#include "xil_printf.h"
#include <string.h>

static FATFS fatfs_instance;

/* Try to open a .ST file: first the exact name, then scan root for any *.ST */
static FRESULT try_open_st(const char *drive, const char *filename,
                           FIL *fil, char *found_path, int pathlen)
{
    FRESULT res;
    DIR dir;
    FILINFO fno;

    /* Try exact name first */
    snprintf(found_path, pathlen, "%s%s", drive, filename);
    res = f_open(fil, found_path, FA_READ);
    if (res == FR_OK)
        return FR_OK;

    /* Scan root directory for any .ST file */
    res = f_opendir(&dir, drive);
    if (res != FR_OK)
        return res;

    xil_printf("[SD] Root directory listing:\r\n");
    while (f_readdir(&dir, &fno) == FR_OK && fno.fname[0] != '\0') {
        xil_printf("[SD]   %s (%u bytes)%s\r\n", fno.fname, (unsigned)fno.fsize,
                   (fno.fattrib & AM_DIR) ? " <DIR>" : "");
        /* Check for .ST extension */
        int len = strlen(fno.fname);
        if (len >= 3 &&
            (fno.fname[len-3] == '.' || fno.fname[len-3] == '.') &&
            (fno.fname[len-2] == 'S' || fno.fname[len-2] == 's') &&
            (fno.fname[len-1] == 'T' || fno.fname[len-1] == 't')) {
            snprintf(found_path, pathlen, "%s%s", drive, fno.fname);
            f_closedir(&dir);
            return f_open(fil, found_path, FA_READ);
        }
    }
    f_closedir(&dir);
    return FR_NO_FILE;
}

uint32_t sd_floppy_load(const char *filename, uint8_t *buffer, uint32_t max_size)
{
    FRESULT res;
    FIL fil;
    UINT bytes_read = 0;
    char path[64];

    /* Try drive 1 first (external SD at 0xff170000), then drive 0 (eMMC) */
    static const char *drives[] = { "1:/", "0:/" };
    int mounted = 0;

    for (int d = 0; d < 2 && !mounted; d++) {
        xil_printf("[SD] Trying mount %s ...\r\n", drives[d]);
        res = f_mount(&fatfs_instance, drives[d], 1);
        if (res == FR_OK) {
            xil_printf("[SD] Mounted %s OK\r\n", drives[d]);
            mounted = 1;

            res = try_open_st(drives[d], filename, &fil, path, sizeof(path));
            if (res != FR_OK) {
                xil_printf("[SD] No .ST file found on %s\r\n", drives[d]);
                f_mount(NULL, drives[d], 0); /* unmount */
                mounted = 0;
                continue;
            }
            xil_printf("[SD] Opened %s\r\n", path);

            /* Read entire file */
            uint32_t fsize = f_size(&fil);
            if (fsize > max_size) {
                xil_printf("[SD] File too large (%u > %u)\r\n", fsize, max_size);
                f_close(&fil);
                f_mount(NULL, drives[d], 0);
                return 0;
            }

            res = f_read(&fil, buffer, fsize, &bytes_read);
            f_close(&fil);

            if (res != FR_OK || bytes_read != fsize) {
                xil_printf("[SD] Read error (res=%d, got %u/%u)\r\n",
                           res, bytes_read, fsize);
                f_mount(NULL, drives[d], 0);
                return 0;
            }

            xil_printf("[SD] Loaded %s: %u bytes\r\n", path, bytes_read);
            /* Leave filesystem mounted */
            return bytes_read;
        } else {
            xil_printf("[SD] Mount %s failed (err=%d)\r\n", drives[d], res);
        }
    }

    xil_printf("[SD] No SD card / no filesystem found\r\n");
    return 0;
}
