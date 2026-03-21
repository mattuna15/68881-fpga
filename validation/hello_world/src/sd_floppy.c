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

static FATFS fatfs_instance;

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

            /* Build full path */
            snprintf(path, sizeof(path), "%s%s", drives[d], filename);

            res = f_open(&fil, path, FA_READ);
            if (res != FR_OK) {
                xil_printf("[SD] File %s not found (err=%d)\r\n", path, res);
                f_mount(NULL, drives[d], 0); /* unmount */
                mounted = 0;
                continue;
            }

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
