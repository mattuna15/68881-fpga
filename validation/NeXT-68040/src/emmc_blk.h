/*
 * emmc_blk.h
 * Raw block access to the on-board AXU3EG eMMC (ZynqMP SDPS instance 0
 * at 0xFF160000), used as the backing store for the NeXTSTEP install
 * target disk exposed as SCSI target 0 in next_scsi.c.
 *
 * The NeXT guest never hits eMMC directly - these calls are used by the
 * SCSI backing store once it's routed a target-0 CDB here.
 *
 * All I/O goes through FatFS's low-level block layer (disk_read,
 * disk_write in fatfs/diskio.c) which owns the XSdPs instance.  We do
 * NOT call f_mount on eMMC: that would overlay a FAT filesystem and
 * block the LBAs we care about.  disk_initialize() is enough.
 *
 * Safety: every read/write LBA is offset by EMMC_TARGET_BASE_LBA and
 * bounds-checked against EMMC_TARGET_MAX_SECTORS to keep us from
 * stomping on anything else that might live on the eMMC later.
 */

#ifndef EMMC_BLK_H
#define EMMC_BLK_H

#include <stdint.h>

/* FatFS physical-drive number for the AXU3EG on-board eMMC.  Matches
 * XSdPs instance 0 (reg 0xFF160000, slot-type=embedded, bus-width=8) per
 * validation/platform-68-linux/.../bsp/libsrc/sdps/src/xsdps_g.c. */
#define EMMC_PDRV               0

/* Window on eMMC used for the NeXTSTEP target disk.
 *   BASE_LBA = 0      : user confirmed eMMC is fresh (no FSBL/U-Boot/Linux
 *                       partition to avoid).  Start at LBA 0 for simplicity.
 *   MAX_SECTORS = 4M  : 2 GiB window (4*1024*1024 * 512 bytes), matches
 *                       images/NS33_2GB.dd for parity with period-realistic
 *                       installs; plenty of room for NEXTSTEP 3.3 Core +
 *                       Developer + user space. */
#define EMMC_TARGET_BASE_LBA    0u
#define EMMC_TARGET_MAX_SECTORS (4u * 1024u * 1024u)

/* Sector size (512 bytes - matches SCSI_BLOCKSIZE and FatFS). */
#define EMMC_BLOCKSIZE          512u

/* Initialise the eMMC physical drive.  Returns 0 on success, -1 on
 * error.  Safe to call multiple times; subsequent calls are no-ops. */
int emmc_blk_init(void);

/* True once emmc_blk_init has succeeded. */
int emmc_blk_ready(void);

/* Read n_sectors starting at lba (relative to EMMC_TARGET_BASE_LBA).
 * Returns 0 on success, -1 on range error or I/O failure. */
int emmc_blk_read(uint32_t lba, uint32_t n_sectors, void *buf);

/* Write n_sectors starting at lba (relative to EMMC_TARGET_BASE_LBA).
 * Returns 0 on success, -1 on range error or I/O failure. */
int emmc_blk_write(uint32_t lba, uint32_t n_sectors, const void *buf);

/* Size of the usable target window, in bytes. */
static inline uint64_t emmc_blk_window_bytes(void)
{
    return (uint64_t)EMMC_TARGET_MAX_SECTORS * EMMC_BLOCKSIZE;
}

/* One-shot flasher: copy a FatFS-hosted raw disk image to the eMMC
 * target window, starting at LBA 0.  The caller is expected to have
 * already mounted the FatFS volume that hosts `path` (register_sd_
 * installer_at_target6 does this for the SD card).  Contents beyond
 * EMMC_TARGET_MAX_SECTORS in the source file are silently truncated;
 * short source files leave the tail of the window untouched.  Returns
 * 0 on success, -1 on any FatFS or eMMC error.  Prints progress. */
int emmc_blk_flash_from_file(const char *path);

/* Read-back verify: re-open `path`, re-read eMMC in chunks, compare.
 * Reports the first mismatching LBA (if any) and the total count of
 * bad sectors.  Returns 0 if identical, -1 on any diff or error. */
int emmc_blk_verify_against_file(const char *path);

#endif /* EMMC_BLK_H */
