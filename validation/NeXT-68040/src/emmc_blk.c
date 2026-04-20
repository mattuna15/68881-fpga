/*
 * emmc_blk.c
 * Raw block access to the AXU3EG on-board eMMC, layered on FatFS's
 * low-level disk_read/disk_write functions.  See emmc_blk.h for the
 * interface contract and the safety-window definitions.
 */

#include "emmc_blk.h"
#include "led_disk.h"
#include "fatfs/ff.h"
#include "fatfs/diskio.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include <string.h>

/* 32 sectors = 16 KiB per FatFS read / eMMC write.  Larger buffers
 * would speed the transfer but cost stack/BSS; 16 KiB is a reasonable
 * compromise.  Must be a multiple of EMMC_BLOCKSIZE. */
#define FLASH_CHUNK_SECTORS  32
#define FLASH_CHUNK_BYTES    (FLASH_CHUNK_SECTORS * EMMC_BLOCKSIZE)
static uint8_t flash_buf[FLASH_CHUNK_BYTES];

/* Diagnostic counters for the write path — accessible from main.c
 * through extern decls below so the flasher prompt can summarise them. */
uint32_t emmc_blk_write_calls   = 0;
uint32_t emmc_blk_write_ok      = 0;
uint32_t emmc_blk_write_oor     = 0;
uint32_t emmc_blk_write_diskerr = 0;
uint32_t emmc_blk_write_not_ready = 0;

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
    /* Pre-invalidate the destination so DMA-landed data replaces any
     * stale lines the CPU may have cached for this address range.
     * Flush-then-invalidate (Xil_DCacheFlushRange) handles the case
     * where the buffer had dirty CPU-written lines from a prior use. */
    Xil_DCacheFlushRange((INTPTR)buf, (INTPTR)n_sectors * EMMC_BLOCKSIZE);
    DRESULT res = disk_read(EMMC_PDRV, buf, phys, n_sectors);
    if (res != RES_OK) {
        xil_printf("[EMMC] disk_read err=%d phys=%llu n=%u\r\n",
                   res, (unsigned long long)phys, (unsigned)n_sectors);
        return -1;
    }
    /* Post-invalidate so the CPU reads the fresh DMA-delivered bytes,
     * not cache lines from before the DMA. */
    Xil_DCacheInvalidateRange((INTPTR)buf, (INTPTR)n_sectors * EMMC_BLOCKSIZE);
    led_disk_note_activity();
    return 0;
}

int emmc_blk_write(uint32_t lba, uint32_t n_sectors, const void *buf)
{
    emmc_blk_write_calls++;
    if (!emmc_ready) { emmc_blk_write_not_ready++; return -1; }
    if (emmc_blk_check_range(lba, n_sectors) < 0) {
        emmc_blk_write_oor++;
        xil_printf("[EMMC] WRITE out of range: lba=%u n=%u window=%u\r\n",
                   (unsigned)lba, (unsigned)n_sectors,
                   (unsigned)EMMC_TARGET_MAX_SECTORS);
        return -1;
    }

    LBA_t phys = (LBA_t)EMMC_TARGET_BASE_LBA + (LBA_t)lba;
    /* Flush the source buffer so DMA reads the actual CPU-written bytes
     * rather than older copies still sitting in L1/L2. */
    Xil_DCacheFlushRange((INTPTR)buf, (INTPTR)n_sectors * EMMC_BLOCKSIZE);
    DRESULT res = disk_write(EMMC_PDRV, buf, phys, n_sectors);
    if (res != RES_OK) {
        emmc_blk_write_diskerr++;
        xil_printf("[EMMC] disk_write err=%d phys=%llu n=%u\r\n",
                   res, (unsigned long long)phys, (unsigned)n_sectors);
        return -1;
    }
    emmc_blk_write_ok++;
    led_disk_note_activity();
    return 0;
}

int emmc_blk_flash_from_file(const char *path)
{
    if (!emmc_ready && emmc_blk_init() != 0)
        return -1;

    FIL fil;
    FRESULT fr = f_open(&fil, path, FA_READ);
    if (fr != FR_OK) {
        xil_printf("[EMMC] flash: f_open(%s) failed (err %d)\r\n", path, fr);
        return -1;
    }

    uint64_t src_size = f_size(&fil);
    uint64_t max_bytes = (uint64_t)EMMC_TARGET_MAX_SECTORS * EMMC_BLOCKSIZE;
    uint64_t to_copy = (src_size < max_bytes) ? src_size : max_bytes;

    xil_printf("[EMMC] flash: %s -> eMMC LBA 0 (%llu bytes, %u sectors)\r\n",
               path, to_copy, (unsigned)(to_copy / EMMC_BLOCKSIZE));
    if (src_size > max_bytes)
        xil_printf("[EMMC] flash: source exceeds window by %llu bytes - truncating\r\n",
                   src_size - max_bytes);

    uint32_t lba = 0;
    uint64_t done = 0;
    uint64_t next_progress = 64ull * 1024 * 1024;   /* first report at 64 MiB */
    int rc = 0;

    while (done < to_copy) {
        uint64_t remain = to_copy - done;
        UINT want = (remain >= FLASH_CHUNK_BYTES) ? FLASH_CHUNK_BYTES
                                                  : (UINT)remain;
        UINT got = 0;
        fr = f_read(&fil, flash_buf, want, &got);
        if (fr != FR_OK || got == 0) {
            xil_printf("[EMMC] flash: f_read err=%d got=%u at %llu/%llu\r\n",
                       fr, got, done, to_copy);
            rc = -1; break;
        }

        /* Zero-pad the tail of the final partial chunk so we write whole
         * sectors (FatFS f_read returns short at EOF). */
        if (got < want)
            memset(flash_buf + got, 0, want - got);

        uint32_t nsec = (got + EMMC_BLOCKSIZE - 1) / EMMC_BLOCKSIZE;
        if (emmc_blk_write(lba, nsec, flash_buf) < 0) {
            xil_printf("[EMMC] flash: write failed at lba=%u\r\n", (unsigned)lba);
            rc = -1; break;
        }
        lba  += nsec;
        done += got;

        if (done >= next_progress || done == to_copy) {
            xil_printf("[EMMC] flash: %llu / %llu bytes (%llu%%)\r\n",
                       done, to_copy, (done * 100) / to_copy);
            next_progress += 64ull * 1024 * 1024;
        }
    }

    f_close(&fil);
    if (rc == 0)
        xil_printf("[EMMC] flash: done, %llu bytes written\r\n", done);
    return rc;
}

/* Second buffer for verify so we don't trash flash_buf's last contents
 * and can compare two fresh reads. */
static uint8_t verify_buf[FLASH_CHUNK_BYTES];

int emmc_blk_verify_against_file(const char *path)
{
    if (!emmc_ready)
        return -1;

    FIL fil;
    FRESULT fr = f_open(&fil, path, FA_READ);
    if (fr != FR_OK) {
        xil_printf("[EMMC] verify: f_open(%s) failed (err %d)\r\n", path, fr);
        return -1;
    }

    uint64_t src_size = f_size(&fil);
    uint64_t max_bytes = (uint64_t)EMMC_TARGET_MAX_SECTORS * EMMC_BLOCKSIZE;
    uint64_t to_check = (src_size < max_bytes) ? src_size : max_bytes;

    xil_printf("[EMMC] verify: %s vs eMMC (%llu bytes, %u sectors)\r\n",
               path, to_check, (unsigned)(to_check / EMMC_BLOCKSIZE));

    uint32_t lba = 0;
    uint64_t done = 0;
    uint64_t next_progress = 64ull * 1024 * 1024;
    int bad_sectors = 0;
    int64_t first_bad_lba = -1;

    while (done < to_check) {
        uint64_t remain = to_check - done;
        UINT want = (remain >= FLASH_CHUNK_BYTES) ? FLASH_CHUNK_BYTES
                                                  : (UINT)remain;
        UINT got = 0;
        fr = f_read(&fil, flash_buf, want, &got);
        if (fr != FR_OK || got == 0) {
            xil_printf("[EMMC] verify: f_read err=%d at %llu\r\n", fr, done);
            f_close(&fil); return -1;
        }
        if (got < want)
            memset(flash_buf + got, 0, want - got);

        uint32_t nsec = (got + EMMC_BLOCKSIZE - 1) / EMMC_BLOCKSIZE;
        if (emmc_blk_read(lba, nsec, verify_buf) < 0) {
            xil_printf("[EMMC] verify: eMMC read failed at lba=%u\r\n", (unsigned)lba);
            f_close(&fil); return -1;
        }

        for (uint32_t s = 0; s < nsec; s++) {
            if (memcmp(flash_buf + s * EMMC_BLOCKSIZE,
                       verify_buf + s * EMMC_BLOCKSIZE,
                       EMMC_BLOCKSIZE) != 0) {
                if (first_bad_lba < 0) first_bad_lba = lba + s;
                bad_sectors++;
            }
        }

        lba  += nsec;
        done += got;

        if (done >= next_progress || done == to_check) {
            xil_printf("[EMMC] verify: %llu / %llu (%llu%%)  bad so far=%d\r\n",
                       done, to_check, (done * 100) / to_check, bad_sectors);
            next_progress += 64ull * 1024 * 1024;
        }
    }

    f_close(&fil);
    if (bad_sectors == 0) {
        xil_printf("[EMMC] verify: OK, image matches eMMC byte-for-byte\r\n");
        return 0;
    }
    xil_printf("[EMMC] verify: FAILED - %d bad sectors, first at LBA %lld\r\n",
               bad_sectors, first_bad_lba);
    return -1;
}
