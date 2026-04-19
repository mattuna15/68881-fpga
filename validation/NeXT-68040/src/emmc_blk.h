/*
 * emmc_blk.h
 * Raw block access to the on-board AXU3EG eMMC (ZynqMP SDPS instance 0
 * at 0xFF160000), used as the backing store for the NeXTSTEP install
 * target disk (SCSI target 6 LUN 0 when the boot menu selects "eMMC",
 * LUN 1 when the boot menu selects "SD installer").
 *
 * The NeXT guest never hits eMMC directly - these calls are used by the
 * SCSI backing store (next_scsi.c) once the firmware has chosen which
 * disk maps to which LUN.
 *
 * All I/O goes through FatFS's low-level block layer (disk_read,
 * disk_write in fatfs/diskio.c) which owns the XSdPs instance.  We do
 * NOT call f_mount on eMMC: that would overlay a FAT filesystem and
 * block the LBAs we care about.  disk_initialize() is enough.
 *
 * Safety: every read/write LBA is offset by EMMC_TARGET_BASE_LBA and
 * bounds-checked against EMMC_TARGET_MAX_SECTORS to keep us from
 * stomping on whatever else lives on the eMMC (U-Boot, Linux rootfs,
 * factory partitions).
 */

#ifndef EMMC_BLK_H
#define EMMC_BLK_H

#include <stdint.h>

/* FatFS physical-drive number for the AXU3EG on-board eMMC.  Matches
 * XSdPs instance 0 (reg 0xFF160000, slot-type=embedded, bus-width=8) per
 * validation/platform-68-linux/.../bsp/libsrc/sdps/src/xsdps_g.c. */
#define EMMC_PDRV               0

/* Window on eMMC used for the NeXTSTEP target disk.  Chosen to sit past
 * any FSBL / U-Boot / factory data typically found at the start of the
 * eMMC on a Xilinx board.  2 GiB offset, 2 GiB window (4 * 1024 * 1024
 * 512-byte sectors = 2 GiB) matches the size of images/NS33_2GB.dd and
 * leaves headroom on the 8 GB part. */
#define EMMC_TARGET_BASE_LBA    0x00400000u    /* byte offset 2 GiB */
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

#endif /* EMMC_BLK_H */
