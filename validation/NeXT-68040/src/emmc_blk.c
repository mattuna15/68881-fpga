/*
 * emmc_blk.c
 * Raw block access to the AXU3EG on-board eMMC, layered on FatFS's
 * low-level disk_read/disk_write functions.  See emmc_blk.h for the
 * interface contract and the safety-window definitions.
 */

#include "emmc_blk.h"
#include "fatfs/ff.h"
#include "fatfs/diskio.h"
#include "xil_printf.h"

static int emmc_ready;

int emmc_blk_init(void)
{
    if (emmc_ready)
        return 0;

    DSTATUS st = disk_initialize(EMMC_PDRV);
    if (st & STA_NOINIT) {
        xil_printf("[EMMC] disk_initialize(%d) failed: status=0x%02X\r\n",
                   EMMC_PDRV, st);
        return -1;
    }

    emmc_ready = 1;
    xil_printf("[EMMC] Ready: pdrv=%d base_lba=0x%08X window=%u sectors (%llu bytes)\r\n",
               EMMC_PDRV, (unsigned)EMMC_TARGET_BASE_LBA,
               (unsigned)EMMC_TARGET_MAX_SECTORS,
               (unsigned long long)emmc_blk_window_bytes());
    return 0;
}

int emmc_blk_ready(void)
{
    return emmc_ready;
}

/* Bounds-check helper.  Returns 0 if [lba, lba+n) lies inside the
 * allowed target window; -1 otherwise. */
static int emmc_blk_check_range(uint32_t lba, uint32_t n_sectors)
{
    if (n_sectors == 0) return 0;
    if (lba >= EMMC_TARGET_MAX_SECTORS) return -1;
    if (n_sectors > EMMC_TARGET_MAX_SECTORS - lba) return -1;
    return 0;
}

int emmc_blk_read(uint32_t lba, uint32_t n_sectors, void *buf)
{
    if (!emmc_ready) return -1;
    if (emmc_blk_check_range(lba, n_sectors) < 0) {
        xil_printf("[EMMC] READ out of range: lba=%u n=%u window=%u\r\n",
                   (unsigned)lba, (unsigned)n_sectors,
                   (unsigned)EMMC_TARGET_MAX_SECTORS);
        return -1;
    }

    LBA_t phys = (LBA_t)EMMC_TARGET_BASE_LBA + (LBA_t)lba;
    DRESULT res = disk_read(EMMC_PDRV, buf, phys, n_sectors);
    if (res != RES_OK) {
        xil_printf("[EMMC] disk_read err=%d phys=%llu n=%u\r\n",
                   res, (unsigned long long)phys, (unsigned)n_sectors);
        return -1;
    }
    return 0;
}

int emmc_blk_write(uint32_t lba, uint32_t n_sectors, const void *buf)
{
    if (!emmc_ready) return -1;
    if (emmc_blk_check_range(lba, n_sectors) < 0) {
        xil_printf("[EMMC] WRITE out of range: lba=%u n=%u window=%u\r\n",
                   (unsigned)lba, (unsigned)n_sectors,
                   (unsigned)EMMC_TARGET_MAX_SECTORS);
        return -1;
    }

    LBA_t phys = (LBA_t)EMMC_TARGET_BASE_LBA + (LBA_t)lba;
    DRESULT res = disk_write(EMMC_PDRV, buf, phys, n_sectors);
    if (res != RES_OK) {
        xil_printf("[EMMC] disk_write err=%d phys=%llu n=%u\r\n",
                   res, (unsigned long long)phys, (unsigned)n_sectors);
        return -1;
    }
    return 0;
}
