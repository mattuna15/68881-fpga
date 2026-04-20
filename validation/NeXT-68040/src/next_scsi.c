/*
 * next_scsi.c
 * SCSI disk emulation with two backing stores:
 *   target 6 LUN 0 - SD-hosted installer image (FatFS, read-mostly)
 *   target 0 LUN 0 - eMMC raw block window (writable HDD; install target)
 *
 * Adapted from Previous emulator (previous/src/scsi.c).  The single
 * `disk` global of the original has been split into:
 *   - disks[SCSI_NUM_TARGETS]: per-disk backing state (FIL / eMMC window)
 *   - req:                     per-request state (LBA, counter, phase, ...)
 *
 * SCSI supports only one in-flight command at a time - the request state
 * is therefore single-instance.  Selection latches req.target, and every
 * subsequent disk access uses disks[req.target] via current_disk().
 */

#include "next_scsi.h"
#include "emmc_blk.h"
#include "led_disk.h"
#include "fatfs/ff.h"
#include "xil_printf.h"
#include <stdio.h>
#include <string.h>

extern int next_debug_scsi;
#define DPRINTF(...) do { if (next_debug_scsi) xil_printf(__VA_ARGS__); } while(0)

/* ------------------------------------------------------------------ */
/* SCSI status/message codes                                           */
/* ------------------------------------------------------------------ */
#define STAT_GOOD           0x00
#define STAT_CHECK_COND     0x02

#define MSG_COMPLETE        0x00
#define MSG_IDENTIFY_MASK   0x80
#define MSG_LUNMASK         0x07

/* Sense keys */
#define SK_NOSENSE          0x00
#define SK_NOTREADY         0x02
#define SK_ILLEGAL_REQ      0x05
#define SK_DATAPROTECT      0x07
#define SK_HARDWARE         0x04

/* Additional sense codes */
#define SC_NO_ERROR         0x00
#define SC_NOT_READY        0x04
#define SC_INVALID_CMD      0x20
#define SC_INVALID_LBA      0x21
#define SC_INVALID_LUN      0x25
#define SC_WRITE_PROTECT    0x27

/* SCSI commands */
#define CMD_TEST_UNIT_RDY   0x00
#define CMD_REQ_SENSE       0x03
#define CMD_FORMAT_DRIVE    0x04
#define CMD_READ_SECTOR     0x08
#define CMD_INQUIRY         0x12
#define CMD_MODESELECT      0x15
#define CMD_MODESENSE       0x1A
#define CMD_SHIP            0x1B
#define CMD_READ_CAPACITY1  0x25
#define CMD_READ_SECTOR1    0x28
#define CMD_WRITE_SECTOR    0x0A
#define CMD_WRITE_SECTOR1   0x2A

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */
#define READ_INT16(a, i)  (((unsigned)(a)[i] << 8) | (a)[(i)+1])
#define READ_INT24(a, i)  (((unsigned)(a)[i] << 16) | ((unsigned)(a)[(i)+1] << 8) | (a)[(i)+2])
#define READ_INT32(a, i)  (((unsigned)(a)[i] << 24) | ((unsigned)(a)[(i)+1] << 16) | ((unsigned)(a)[(i)+2] << 8) | (a)[(i)+3])

static uint64_t scsi_get_offset(uint8_t opcode, uint8_t *cdb)
{
    return opcode < 0x20 ?
        (READ_INT24(cdb, 1) & 0x1FFFFF) :
        READ_INT32(cdb, 2);
}

static int scsi_get_count(uint8_t opcode, uint8_t *cdb)
{
    return opcode < 0x20 ?
        ((cdb[4] == 0) ? 0x100 : cdb[4]) :
        READ_INT16(cdb, 7);
}

static int scsi_get_transfer_length(uint8_t opcode, uint8_t *cdb)
{
    return opcode < 0x20 ? cdb[4] : READ_INT16(cdb, 7);
}

/* ------------------------------------------------------------------ */
/* Per-disk state: indexed by SCSI target ID                           */
/* ------------------------------------------------------------------ */
typedef enum {
    DISK_BACKING_NONE = 0,
    DISK_BACKING_FATFS,       /* SD card, file-in-FAT backing */
    DISK_BACKING_EMMC_RAW,    /* eMMC, raw sector window via emmc_blk_* */
} disk_backing_t;

typedef struct {
    disk_backing_t backing;
    FIL       fatfs_fil;      /* valid when backing == FATFS */
    uint64_t  size_bytes;     /* total usable size */
    bool      mounted;        /* backing is ready to serve I/O */
    bool      writable;       /* accept WRITE(6)/WRITE(10) */
    bool      label_valid;    /* LBA 0 holds a valid NeXT disk label */
    bool      label_checked;  /* label_valid is up to date */
    char      label[32];      /* short diagnostic name for logs */
} scsi_disk_t;

/* First 4 bytes of a NeXT disk label at sector 0: "dlV3" big-endian. */
#define NEXT_DISK_LABEL_MAGIC  0x646C5633u

#define SCSI_NUM_TARGETS 8
static scsi_disk_t disks[SCSI_NUM_TARGETS];

static inline scsi_disk_t *current_disk(void);

/* ------------------------------------------------------------------ */
/* Per-request state (one in-flight SCSI command at a time)            */
/* ------------------------------------------------------------------ */
static struct {
    uint8_t  status;
    uint8_t  message;
    uint8_t  phase;
    uint8_t  target;
    uint8_t  lun;
    struct { uint8_t key, code; bool valid; uint32_t info; } sense;
    uint32_t lba;
    uint32_t blockcounter;
    uint32_t write_pending;  /* bytes remaining for Data-Out */
} req;

static inline scsi_disk_t *current_disk(void)
{
    return &disks[req.target & 0x07];
}

/* Transfer buffer */
static struct {
    uint8_t data[SCSI_BLOCKSIZE];
    int limit;      /* total bytes loaded in this buffer */
    int size;       /* bytes remaining to send (DI) */
    bool is_disk;   /* true = multi-sector disk transfer */
} scsi_buf;

static FATFS fatfs_inst;

/* Write-staging buffer: bytes delivered by the ESP DMA engine are
 * accumulated here until a full SCSI_BLOCKSIZE is collected, then
 * flushed to the backing store.  The storage lives further down the
 * file; we forward-declare the fill counter here so that
 * scsi_write_sector() can zero it at every WRITE command boundary
 * (prevents stale tail bytes from a prior aborted transfer bleeding
 * into the first sector of the next write, which corrupts the fs
 * deterministically on every boot). */
static uint32_t wr_sector_fill;

/* ------------------------------------------------------------------ */
/* Sector cache - direct-mapped, 4096 slots x 512 B = 2 MB.            */
/* The kernel demand-pages heavily from the SD installer image during  */
/* boot; the cache turns repeat reads into memcpy hits.  Tag encodes   */
/* target id in the high 4 bits and LBA in the low 28 bits so the two  */
/* disks can coexist in the same table without flushing each other.    */
/* ------------------------------------------------------------------ */
#define SCACHE_SLOTS      4096u
#define SCACHE_EMPTY_TAG  0xFFFFFFFFu
static uint32_t scache_tag[SCACHE_SLOTS];
static uint8_t  scache_data[SCACHE_SLOTS][SCSI_BLOCKSIZE];

static inline uint32_t scache_make_tag(uint8_t target, uint32_t lba)
{
    /* 4-bit target + 28-bit LBA. LBAs up to 256M = 128 GB per disk. */
    return ((uint32_t)(target & 0x0F) << 28) | (lba & 0x0FFFFFFFu);
}

static void scache_reset(void)
{
    for (unsigned i = 0; i < SCACHE_SLOTS; i++)
        scache_tag[i] = SCACHE_EMPTY_TAG;
}

static inline unsigned scache_slot(uint32_t tag)
{
    uint32_t h = tag ^ (tag >> 13);
    return h & (SCACHE_SLOTS - 1);
}

static bool scache_try_read(uint8_t target, uint32_t lba)
{
    uint32_t tag = scache_make_tag(target, lba);
    unsigned s = scache_slot(tag);
    if (scache_tag[s] == tag) {
        memcpy(scsi_buf.data, scache_data[s], SCSI_BLOCKSIZE);
        return true;
    }
    return false;
}

static void scache_install(uint8_t target, uint32_t lba)
{
    uint32_t tag = scache_make_tag(target, lba);
    unsigned s = scache_slot(tag);
    scache_tag[s] = tag;
    memcpy(scache_data[s], scsi_buf.data, SCSI_BLOCKSIZE);
}

static void scache_invalidate(uint8_t target, uint32_t lba)
{
    uint32_t tag = scache_make_tag(target, lba);
    unsigned s = scache_slot(tag);
    if (scache_tag[s] == tag)
        scache_tag[s] = SCACHE_EMPTY_TAG;
}

/* ------------------------------------------------------------------ */
/* INQUIRY response data - same descriptor for both backings          */
/* (they're both reported as Direct-Access Device so the installer's  */
/* disk-selection menu lists both as plain SCSI disks)                */
/* ------------------------------------------------------------------ */
static uint8_t inquiry_bytes[] = {
    0x00,             /* 0: device type: disk */
    0x00,             /* 1: not removable */
    0x01,             /* 2: ANSI SCSI-1 */
    0x02,             /* 3: Response format */
    0x31,             /* 4: additional length */
    0x00, 0x00,       /* 5,6: reserved */
    0x1C,             /* 7: Sync=1, Linked=1, RSVD=1 */
    'F','P','G','A',' ',' ',' ',' ',   /*  8-15: Vendor */
    'N','e','X','T','D','i','s','k',   /* 16-23: Product */
    ' ',' ',' ',' ',' ',' ',' ',' ',   /* 24-31: Blank */
    '0','0','0','0','0','0','0','1',   /* 32-39: Revision */
    '0','0','0','0','0','0','0','0',   /* 40-47: Serial */
    ' ',' ',' ',' ',' ',' '           /* 48-53: Blank */
};

/* ------------------------------------------------------------------ */
/* Low-level per-backing sector I/O                                    */
/* ------------------------------------------------------------------ */
static int disk_backing_read(scsi_disk_t *d, uint32_t lba, uint8_t *buf)
{
    switch (d->backing) {
    case DISK_BACKING_FATFS: {
        uint64_t offset = (uint64_t)lba * SCSI_BLOCKSIZE;
        FRESULT res = f_lseek(&d->fatfs_fil, (FSIZE_t)offset);
        if (res != FR_OK) return -1;
        UINT br;
        res = f_read(&d->fatfs_fil, buf, SCSI_BLOCKSIZE, &br);
        if (res != FR_OK || br != SCSI_BLOCKSIZE) return -1;
        led_disk_note_activity();
        return 0;
    }
    case DISK_BACKING_EMMC_RAW:
        /* emmc_blk_read() pulses the LED itself. */
        return emmc_blk_read(lba, 1, buf);
    default:
        return -1;
    }
}

static int disk_backing_write(scsi_disk_t *d, uint32_t lba, const uint8_t *buf)
{
    if (!d->writable) return 0;  /* silently discard writes on RO disks */
    switch (d->backing) {
    case DISK_BACKING_FATFS: {
        uint64_t offset = (uint64_t)lba * SCSI_BLOCKSIZE;
        FRESULT res = f_lseek(&d->fatfs_fil, (FSIZE_t)offset);
        if (res != FR_OK) return -1;
        UINT bw;
        res = f_write(&d->fatfs_fil, buf, SCSI_BLOCKSIZE, &bw);
        if (res != FR_OK || bw != SCSI_BLOCKSIZE) return -1;
        led_disk_note_activity();
        return 0;
    }
    case DISK_BACKING_EMMC_RAW:
        return emmc_blk_write(lba, 1, buf);
    default:
        return -1;
    }
}

/* ------------------------------------------------------------------ */
/* Disk-label validity check                                           */
/*                                                                     */
/* A NeXT-format disk has "dlV3" (0x646C5633) as the first 4 bytes of  */
/* sector 0.  Fresh eMMC is all zeros, so target 0 initially looks     */
/* "present but medium not formatted".  We read LBA 0 once at init,    */
/* cache the result, and reuse it - any WRITE(6)/WRITE(10) to sector   */
/* 0 flips label_checked=false so the next TUR re-reads.               */
/*                                                                     */
/* Used by TUR: if target 0's label is invalid the NeXT Turbo ROM's    */
/* auto-boot (`b sd`) gets CHECK_COND/NOT_READY and skips to target 6  */
/* (the SD installer image).  Once the installer formats eMMC and      */
/* writes a valid label, TUR starts succeeding and `b sd` will auto-   */
/* boot target 0.                                                      */
/* ------------------------------------------------------------------ */
static void refresh_disk_label(scsi_disk_t *d, uint8_t target)
{
    uint8_t sector0[SCSI_BLOCKSIZE];
    if (disk_backing_read(d, 0, sector0) < 0) {
        d->label_valid = false;
    } else {
        uint32_t magic = ((uint32_t)sector0[0] << 24) |
                         ((uint32_t)sector0[1] << 16) |
                         ((uint32_t)sector0[2] <<  8) |
                         ((uint32_t)sector0[3]      );
        /* NeXT disklabel has dl_size at byte offset 8 (4 bytes, BE,
         * in media-sectors).  If the magic matches, clamp the reported
         * device size to (dl_size * 512) so READ CAPACITY matches what
         * the fs was laid down for -- Previous reports 1919 MB because
         * it honours dl_size; we were reporting the full eMMC window
         * (2047 MB) which tricks fsck into scanning past fs end into
         * uninitialised eMMC space and reporting bogus structural
         * errors. */
        if (magic == NEXT_DISK_LABEL_MAGIC &&
            d->backing == DISK_BACKING_EMMC_RAW) {
            uint32_t dl_size = ((uint32_t)sector0[8]  << 24) |
                               ((uint32_t)sector0[9]  << 16) |
                               ((uint32_t)sector0[10] <<  8) |
                               ((uint32_t)sector0[11]      );
            xil_printf("[SCSI] target %u: disklabel bytes 0-15 = "
                       "%02X %02X %02X %02X  %02X %02X %02X %02X  "
                       "%02X %02X %02X %02X  %02X %02X %02X %02X\r\n",
                       target,
                       sector0[0],sector0[1],sector0[2],sector0[3],
                       sector0[4],sector0[5],sector0[6],sector0[7],
                       sector0[8],sector0[9],sector0[10],sector0[11],
                       sector0[12],sector0[13],sector0[14],sector0[15]);
            xil_printf("[SCSI] target %u: dl_size (raw) = %u ($%08X)\r\n",
                       target, dl_size, dl_size);
            if (dl_size > 0 && dl_size < EMMC_TARGET_MAX_SECTORS) {
                uint64_t fs_bytes = (uint64_t)dl_size * SCSI_BLOCKSIZE;
                if (fs_bytes < d->size_bytes) {
                    xil_printf("[SCSI] target %u: clamping size %llu MB -> %llu MB\r\n",
                               target,
                               d->size_bytes / (1024u*1024u),
                               fs_bytes / (1024u*1024u));
                    d->size_bytes = fs_bytes;
                }
            }
        }
        d->label_valid = (magic == NEXT_DISK_LABEL_MAGIC);
        if (d->backing == DISK_BACKING_EMMC_RAW) {
            xil_printf("[SCSI] target %u: LBA 0 magic $%08X => %s\r\n",
                       target, magic,
                       d->label_valid ? "valid NeXT label"
                                      : "blank/unformatted");
        }
    }
    d->label_checked = true;
}

static bool disk_is_boot_ready(scsi_disk_t *d, uint8_t target)
{
    if (!d->mounted) return false;
    /* FatFS-backed installer image (target 6) is always treated as ready:
     * it is known to carry the NEXTSTEP install volume. */
    if (d->backing == DISK_BACKING_FATFS) return true;
    /* eMMC-raw: ready only once a NeXT disk label exists, so a fresh
     * blank disk stays invisible to the ROM auto-boot AND to the kernel
     * SCSI autoconf (NeXT assigns sdN by probe order, so exposing a
     * blank target 0 would renumber sd0 and break root mount). */
    if (!d->label_checked)
        refresh_disk_label(d, target);
    return d->label_valid;
}

/* ------------------------------------------------------------------ */
/* Internal: read one sector from the current disk                     */
/* ------------------------------------------------------------------ */
static void scsi_read_one_sector(void)
{
    if (req.blockcounter == 0) {
        req.phase = SCSI_PHASE_ST;
        return;
    }
    scsi_disk_t *d = current_disk();
    uint64_t offset = (uint64_t)req.lba * SCSI_BLOCKSIZE;

    if (offset < d->size_bytes) {
        if (!scache_try_read(req.target, req.lba)) {
            if (disk_backing_read(d, req.lba, scsi_buf.data) < 0) {
                DPRINTF("[SCSI] backing read error tgt=%d LBA=%u\r\n",
                        req.target, req.lba);
                req.status = STAT_CHECK_COND;
                req.sense.code = SC_NOT_READY;
                req.phase = SCSI_PHASE_ST;
                return;
            }
            scache_install(req.target, req.lba);
        }
        scsi_buf.limit = scsi_buf.size = SCSI_BLOCKSIZE;
        req.status = STAT_GOOD;
        req.sense.code = SC_NO_ERROR;
        req.sense.valid = false;
        req.lba++;
        req.blockcounter--;
    } else {
        req.status = STAT_CHECK_COND;
        req.sense.code = SC_INVALID_LBA;
        req.sense.valid = true;
        req.sense.info = req.lba;
        req.phase = SCSI_PHASE_ST;
    }
}

/* ------------------------------------------------------------------ */
/* SCSI command handlers                                               */
/* ------------------------------------------------------------------ */

static void scsi_test_unit_ready(void)
{
    scsi_disk_t *d = current_disk();
    if (!disk_is_boot_ready(d, req.target)) {
        req.status = STAT_CHECK_COND;
        req.sense.code = SC_NOT_READY;
    } else {
        req.status = STAT_GOOD;
        req.sense.code = SC_NO_ERROR;
    }
    req.phase = SCSI_PHASE_ST;
}

static void scsi_inquiry(uint8_t *cdb)
{
    int len = scsi_get_transfer_length(cdb[0], cdb);
    if (len > (int)sizeof(inquiry_bytes))
        len = (int)sizeof(inquiry_bytes);

    if (req.lun != 0) {
        inquiry_bytes[0] = 0x7F; /* LUN not present */
    } else {
        inquiry_bytes[0] = 0x00; /* disk */
    }

    memcpy(scsi_buf.data, inquiry_bytes, len);
    scsi_buf.limit = scsi_buf.size = len;
    scsi_buf.is_disk = false;
    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_DI;
    req.sense.code = SC_NO_ERROR;
    DPRINTF("[SCSI] Inquiry tgt=%d: %d bytes\r\n", req.target, len);
}

static void scsi_read_capacity(void)
{
    scsi_disk_t *d = current_disk();
    uint32_t sectors = (uint32_t)(d->size_bytes / SCSI_BLOCKSIZE);
    if (sectors == 0) {
        req.status = STAT_CHECK_COND;
        req.sense.code = SC_NOT_READY;
        req.phase = SCSI_PHASE_ST;
        return;
    }
    uint32_t last_lba = sectors - 1;

    scsi_buf.data[0] = (last_lba >> 24) & 0xFF;
    scsi_buf.data[1] = (last_lba >> 16) & 0xFF;
    scsi_buf.data[2] = (last_lba >>  8) & 0xFF;
    scsi_buf.data[3] = last_lba & 0xFF;
    scsi_buf.data[4] = 0;
    scsi_buf.data[5] = 0;
    scsi_buf.data[6] = (SCSI_BLOCKSIZE >> 8) & 0xFF;
    scsi_buf.data[7] = SCSI_BLOCKSIZE & 0xFF;

    scsi_buf.limit = scsi_buf.size = 8;
    scsi_buf.is_disk = false;
    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_DI;
    req.sense.code = SC_NO_ERROR;
    DPRINTF("[SCSI] Read Capacity tgt=%d: %u sectors, last LBA=%u\r\n",
            req.target, sectors, last_lba);
}

static void scsi_request_sense(uint8_t *cdb)
{
    int len = scsi_get_transfer_length(cdb[0], cdb);
    if (len <= 0) len = 4;
    if (len > 22)  len = 22;

    uint8_t retbuf[22];
    memset(retbuf, 0, sizeof(retbuf));

    retbuf[0] = 0x70;
    if (req.sense.valid) {
        retbuf[0] |= 0x80;
        retbuf[3] = req.sense.info >> 24;
        retbuf[4] = req.sense.info >> 16;
        retbuf[5] = req.sense.info >> 8;
        retbuf[6] = req.sense.info;
    }

    switch (req.sense.code) {
    case SC_NO_ERROR:    req.sense.key = SK_NOSENSE;     break;
    case SC_NOT_READY:   req.sense.key = SK_NOTREADY;    break;
    case SC_WRITE_PROTECT: req.sense.key = SK_DATAPROTECT; break;
    case SC_INVALID_CMD:
    case SC_INVALID_LBA:
    case SC_INVALID_LUN: req.sense.key = SK_ILLEGAL_REQ; break;
    default:             req.sense.key = SK_HARDWARE;    break;
    }
    retbuf[2] = req.sense.key;
    retbuf[7] = 14;
    retbuf[12] = req.sense.code;

    memcpy(scsi_buf.data, retbuf, len);
    scsi_buf.limit = scsi_buf.size = len;
    scsi_buf.is_disk = false;
    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_DI;
}

static void scsi_mode_sense(uint8_t *cdb)
{
    uint8_t retbuf[64];
    memset(retbuf, 0, sizeof(retbuf));

    scsi_disk_t *d = current_disk();
    uint32_t sectors = (uint32_t)(d->size_bytes / SCSI_BLOCKSIZE);
    uint8_t pagecode = cdb[2] & 0x3F;
    uint8_t dbd = cdb[1] & 0x08;

    /* Header */
    retbuf[0] = 0x00; /* length (filled later) */
    retbuf[1] = 0x00; /* medium type */
    retbuf[2] = d->writable ? 0x00 : 0x80; /* bit 7 = WP */
    retbuf[3] = dbd ? 0x00 : 0x08; /* block descriptor length (0 when DBD set) */

    uint8_t hdr_size = 4;
    if (!dbd) {
        retbuf[4] = 0x00;
        retbuf[5] = (sectors >> 16) & 0xFF;
        retbuf[6] = (sectors >>  8) & 0xFF;
        retbuf[7] = sectors & 0xFF;
        retbuf[8] = 0x00;
        retbuf[9]  = 0x00;
        retbuf[10] = (SCSI_BLOCKSIZE >> 8) & 0xFF;
        retbuf[11] = SCSI_BLOCKSIZE & 0xFF;
        hdr_size = 12;
    }
    retbuf[0] = hdr_size - 1;

    /* Mode page 0x00: operating page */
    uint8_t off = hdr_size;
    if (pagecode == 0x00 || pagecode == 0x3F) {
        retbuf[off++] = 0x00; retbuf[off++] = 0x02;
        retbuf[off++] = 0x80; retbuf[off++] = 0x00;
    }
    /* Mode page 0x01: error recovery */
    if (pagecode == 0x01 || pagecode == 0x3F) {
        retbuf[off++] = 0x01; retbuf[off++] = 0x06;
        retbuf[off++] = 0x00; retbuf[off++] = 0x1B;
        retbuf[off++] = 0x0B; retbuf[off++] = 0x00;
        retbuf[off++] = 0x00; retbuf[off++] = 0xFF;
    }
    /* Mode page 0x04: rigid disk geometry */
    if (pagecode == 0x04 || pagecode == 0x3F) {
        uint32_t heads = 16, spt = 63;
        uint32_t cyls = sectors / (heads * spt);
        if (cyls == 0) cyls = 1;
        retbuf[off++] = 0x04; retbuf[off++] = 0x12;
        retbuf[off++] = (cyls >> 16) & 0xFF;
        retbuf[off++] = (cyls >>  8) & 0xFF;
        retbuf[off++] = cyls & 0xFF;
        retbuf[off++] = heads;
        off += 14;
    }

    retbuf[0] = off - 1;

    int xfer_len = scsi_get_transfer_length(cdb[0], cdb);
    int rlen = retbuf[0] + 1;
    if (rlen > xfer_len) rlen = xfer_len;
    if (rlen > (int)sizeof(retbuf)) rlen = (int)sizeof(retbuf);

    memcpy(scsi_buf.data, retbuf, rlen);
    scsi_buf.limit = scsi_buf.size = rlen;
    scsi_buf.is_disk = false;
    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_DI;
    req.sense.code = SC_NO_ERROR;
}

static int scsi_read_log = 0;

void next_scsi_reset_read_log(void)
{
    scsi_read_log = 0;
}

bool next_scsi_emmc_is_blank(void)
{
    scsi_disk_t *d = &disks[0];
    if (!d->mounted || d->backing != DISK_BACKING_EMMC_RAW)
        return false;
    if (!d->label_checked)
        refresh_disk_label(d, 0);
    return !d->label_valid;
}

void next_scsi_emmc_refresh_label(void)
{
    scsi_disk_t *d = &disks[0];
    if (!d->mounted || d->backing != DISK_BACKING_EMMC_RAW)
        return;
    d->label_checked = false;
    refresh_disk_label(d, 0);
}

int scsi_read_log_count(void)
{
    return scsi_read_log;
}

static void scsi_read_sector(uint8_t *cdb)
{
    req.lba = (uint32_t)scsi_get_offset(cdb[0], cdb);
    req.blockcounter = scsi_get_count(cdb[0], cdb);
    scsi_buf.is_disk = true;
    scsi_buf.size = 0;
    req.phase = SCSI_PHASE_DI;
    scsi_read_one_sector();
}

static void scsi_write_sector(uint8_t *cdb)
{
    /* Enter Data-Out phase.  The ESP DMA layer delivers bytes via
     * next_scsi_write_bytes(), which accumulates into a sector buffer
     * and commits to the backing via disk_backing_write(). */
    req.lba = (uint32_t)scsi_get_offset(cdb[0], cdb);
    req.blockcounter = scsi_get_count(cdb[0], cdb);
    req.write_pending = req.blockcounter * SCSI_BLOCKSIZE;

    /* Reset the staging buffer at every WRITE command boundary.  A prior
     * command that ended with a partial-sector tail or was aborted
     * mid-transfer may have left wr_sector_fill non-zero, which would
     * prepend stale bytes to this command's first sector and corrupt
     * the backing store deterministically. */
    wr_sector_fill = 0;

    /* Invalidate the cache for the write range so subsequent reads see
     * the freshly-written data. */
    for (uint32_t i = 0; i < req.blockcounter; i++)
        scache_invalidate(req.target, req.lba + i);

    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_DO;  /* host sends data to us */
}

static void scsi_start_stop(uint8_t *cdb)
{
    (void)cdb;
    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_ST;
}

static void scsi_format_drive(uint8_t *cdb)
{
    (void)cdb;
    req.status = STAT_GOOD;
    req.phase = SCSI_PHASE_ST;
}

/* ------------------------------------------------------------------ */
/* Target population                                                   */
/* ------------------------------------------------------------------ */

/* Mount the SD installer image (existing behaviour) and register it
 * as target 6.  Returns 0 on success, -1 if no .IMG found. */
static int register_sd_installer_at_target6(void)
{
    scsi_disk_t *d = &disks[6];
    d->backing = DISK_BACKING_NONE;
    d->mounted = false;

    /* With FF_MULTI_PARTITION=1 the logical drive -> (pdrv, part) map
     * becomes: 0-4 => eMMC partitions (unused), 5-9 => SD partitions.
     * We try every SD partition that might be FAT; Linux/UFS partitions
     * fail f_mount cleanly and we move on. */
    static const char *drives[] = {
        "6:/", "7:/", "8:/", "9:/", "5:/"
    };
    FRESULT res;
    DIR dir;
    FILINFO fno;

    for (int i = 0; i < (int)(sizeof(drives) / sizeof(drives[0])); i++) {
        xil_printf("[SCSI] Trying mount %s ...\r\n", drives[i]);
        res = f_mount(&fatfs_inst, drives[i], 1);
        if (res != FR_OK) continue;

        xil_printf("[SCSI] Mounted %s\r\n", drives[i]);

        res = f_opendir(&dir, drives[i]);
        if (res != FR_OK) { f_mount(NULL, drives[i], 0); continue; }

        while (f_readdir(&dir, &fno) == FR_OK && fno.fname[0] != '\0') {
            int len = strlen(fno.fname);
            if (len >= 4 &&
                fno.fname[len-4] == '.' &&
                (fno.fname[len-3] == 'I' || fno.fname[len-3] == 'i') &&
                (fno.fname[len-2] == 'M' || fno.fname[len-2] == 'm') &&
                (fno.fname[len-1] == 'G' || fno.fname[len-1] == 'g')) {
                char path[64];
                snprintf(path, sizeof(path), "%s%s", drives[i], fno.fname);
                f_closedir(&dir);

                res = f_open(&d->fatfs_fil, path, FA_READ);
                if (res == FR_OK) {
                    d->backing   = DISK_BACKING_FATFS;
                    d->size_bytes = f_size(&d->fatfs_fil);
                    d->mounted   = true;
                    d->writable  = false;
                    snprintf(d->label, sizeof(d->label), "SD %s", fno.fname);
                    xil_printf("[SCSI] target 6: %s (%llu bytes, %u sectors) read-only\r\n",
                               path, d->size_bytes,
                               (unsigned)(d->size_bytes / SCSI_BLOCKSIZE));
                    return 0;
                }
                xil_printf("[SCSI] Failed to open %s (err %d)\r\n", path, res);
                f_mount(NULL, drives[i], 0);
                return -1;
            }
        }
        f_closedir(&dir);
        xil_printf("[SCSI] No .IMG file found on %s\r\n", drives[i]);
        f_mount(NULL, drives[i], 0);
    }
    return -1;
}

/* Register the eMMC raw-block window as SCSI target 0.  Returns 0 on
 * success, -1 if eMMC init failed (target 0 stays absent). */
static int register_emmc_at_target0(void)
{
    scsi_disk_t *d = &disks[0];
    d->backing = DISK_BACKING_NONE;
    d->mounted = false;

    if (emmc_blk_init() != 0) {
        xil_printf("[SCSI] target 0: eMMC init failed, target 0 not present\r\n");
        return -1;
    }

    d->backing    = DISK_BACKING_EMMC_RAW;
    d->size_bytes = emmc_blk_window_bytes();
    d->mounted    = true;
    d->writable   = true;
    snprintf(d->label, sizeof(d->label), "eMMC raw 2GB");
    xil_printf("[SCSI] target 0: eMMC raw window (%llu bytes, %u sectors) writable\r\n",
               d->size_bytes, (unsigned)(d->size_bytes / SCSI_BLOCKSIZE));
    /* Eagerly probe the disk label so the init log reports whether
     * target 0 is going to intercept the ROM's auto-boot or not. */
    refresh_disk_label(d, 0);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Public API                                                          */
/* ------------------------------------------------------------------ */

int next_scsi_init(void)
{
    memset(&disks, 0, sizeof(disks));
    memset(&req, 0, sizeof(req));
    memset(&scsi_buf, 0, sizeof(scsi_buf));
    req.phase = SCSI_PHASE_ST;
    scache_reset();

    int rc_sd   = register_sd_installer_at_target6();
    int rc_emmc = register_emmc_at_target0();

    /* Return 0 if at least one disk came up so the old caller in
     * main.c continues to consider SCSI initialised. */
    return (rc_sd == 0 || rc_emmc == 0) ? 0 : -1;
}

#define BOOT_TARGET_ID  6   /* NeXT ROM's default boot target (MO/install) */

bool next_scsi_select(uint8_t target)
{
    if (target >= SCSI_NUM_TARGETS || !disks[target].mounted) {
        DPRINTF("[SCSI] Select target %d: timeout (not present)\r\n", target);
        req.phase = SCSI_PHASE_ST;
        return true; /* timeout */
    }
    /* A blank eMMC-raw disk is reported absent from the bus (select
     * timeout) rather than present-but-not-ready.  NeXT ROM interprets
     * NOT_READY as "spinning up, poll TUR forever" - that stalls the
     * auto-boot.  Reporting absent lets `b sd` fall through to the
     * next target (6 = installer).  Once a valid disk label is laid
     * down (wr_flush_sector clears label_checked and refresh_disk_label
     * flips label_valid), the device re-appears on the bus. */
    if (!disk_is_boot_ready(&disks[target], target)) {
        DPRINTF("[SCSI] Select target %d: timeout (blank, no label)\r\n", target);
        req.phase = SCSI_PHASE_ST;
        return true;
    }
    req.target = target;
    DPRINTF("[SCSI] Select target %d: OK (%s)\r\n", target, disks[target].label);
    return false;
}

void next_scsi_receive_command(uint8_t *cdb, int cdb_len, uint8_t identify)
{
    (void)cdb_len;

    /* Extract LUN from identify message or CDB */
    if (identify & MSG_IDENTIFY_MASK)
        req.lun = identify & MSG_LUNMASK;
    else
        req.lun = (cdb[1] & 0xE0) >> 5;

    uint8_t opcode = cdb[0];
    DPRINTF("[SCSI] Cmd $%02X target=%d lun=%d\r\n", opcode, req.target, req.lun);

    /* LUN-independent commands first */
    switch (opcode) {
    case CMD_INQUIRY:
        scsi_inquiry(cdb);
        req.message = MSG_COMPLETE;
        return;
    case CMD_REQ_SENSE:
        scsi_request_sense(cdb);
        req.message = MSG_COMPLETE;
        return;
    default:
        break;
    }

    /* Check LUN validity for other commands (we only ever expose LUN 0
     * on each target). */
    if (req.lun != 0) {
        req.status = STAT_CHECK_COND;
        req.sense.code = SC_INVALID_LUN;
        req.sense.valid = false;
        req.phase = SCSI_PHASE_ST;
        req.message = MSG_COMPLETE;
        return;
    }

    switch (opcode) {
    case CMD_TEST_UNIT_RDY:  scsi_test_unit_ready(); break;
    case CMD_READ_CAPACITY1: scsi_read_capacity();   break;
    case CMD_READ_SECTOR:
    case CMD_READ_SECTOR1:   scsi_read_sector(cdb);  break;
    case CMD_WRITE_SECTOR:
    case CMD_WRITE_SECTOR1:  scsi_write_sector(cdb); break;
    case CMD_MODESENSE:      scsi_mode_sense(cdb);   break;
    case CMD_SHIP:           scsi_start_stop(cdb);   break;
    case CMD_FORMAT_DRIVE:   scsi_format_drive(cdb); break;
    case CMD_MODESELECT:
        /* Accept but ignore */
        req.status = STAT_GOOD;
        req.phase = SCSI_PHASE_ST;
        break;
    default:
        DPRINTF("[SCSI] Unknown command $%02X\r\n", opcode);
        req.status = STAT_CHECK_COND;
        req.sense.code = SC_INVALID_CMD;
        req.sense.valid = false;
        req.phase = SCSI_PHASE_ST;
        break;
    }
    req.message = MSG_COMPLETE;
}

uint8_t next_scsi_send_data(void)
{
    if (scsi_buf.size <= 0) {
        DPRINTF("[SCSI] send_data: buffer empty!\r\n");
        return 0;
    }
    uint8_t val = scsi_buf.data[scsi_buf.limit - scsi_buf.size];
    scsi_buf.size--;
    if (scsi_buf.size == 0) {
        if (scsi_buf.is_disk)
            scsi_read_one_sector();
        else
            req.phase = SCSI_PHASE_ST;
    }
    return val;
}

/* ------------------------------------------------------------------ */
/* Data-Out (write) path                                               */
/*                                                                     */
/* ESP DMA feeds us host-side bytes via next_scsi_write_bytes().  We   */
/* accumulate into wr_sector and commit to the backing once a full     */
/* SCSI_BLOCKSIZE has been delivered.  When req.write_pending reaches  */
/* zero we pad any trailing partial sector and transition to STATUS.   */
/* ------------------------------------------------------------------ */
static uint8_t  wr_sector[SCSI_BLOCKSIZE];
/* wr_sector_fill is declared/forward-declared near the top of the file
 * so scsi_write_sector() can zero it at every WRITE command boundary. */

uint32_t wr_flush_sector_count = 0;
uint32_t wr_flush_sector_ok    = 0;
uint32_t wr_flush_sector_err   = 0;
uint32_t wr_flush_sector_oor   = 0;
uint32_t wr_lba_lt_1M   = 0;   /* LBA < 1M sectors (~512 MB) */
uint32_t wr_lba_lt_2M   = 0;   /* LBA 1M..2M sectors */
uint32_t wr_lba_lt_4M   = 0;   /* LBA 2M..4M sectors */
uint32_t wr_lba_ge_4M   = 0;   /* LBA >= 4M sectors (outside our 2GB window) */
uint32_t wr_max_lba     = 0;

static void wr_flush_sector(void)
{
    wr_flush_sector_count++;
    if      (req.lba < 1u*1024*1024) wr_lba_lt_1M++;
    else if (req.lba < 2u*1024*1024) wr_lba_lt_2M++;
    else if (req.lba < 4u*1024*1024) wr_lba_lt_4M++;
    else                              wr_lba_ge_4M++;
    if (req.lba > wr_max_lba) wr_max_lba = req.lba;
    scsi_disk_t *d = current_disk();
    if (req.lba * (uint64_t)SCSI_BLOCKSIZE < d->size_bytes) {
        if (disk_backing_write(d, req.lba, wr_sector) < 0) {
            wr_flush_sector_err++;
            DPRINTF("[SCSI] backing write err tgt=%d LBA=%u\r\n",
                    req.target, req.lba);
            req.status = STAT_CHECK_COND;
            req.sense.code = SC_NOT_READY;
        } else {
            wr_flush_sector_ok++;
            /* Successful write invalidates any stale cache entry. */
            scache_invalidate(req.target, req.lba);
            /* Any write to LBA 0 may have changed the NeXT disk label,
             * so invalidate the cached label-validity result.  The next
             * TUR will re-read and re-evaluate. */
            if (req.lba == 0)
                d->label_checked = false;
        }
    } else {
        wr_flush_sector_oor++;
        DPRINTF("[SCSI] write out of range tgt=%d LBA=%u\r\n",
                req.target, req.lba);
        req.status = STAT_CHECK_COND;
        req.sense.code = SC_INVALID_LBA;
    }
    req.lba++;
    wr_sector_fill = 0;
}

void next_scsi_receive_data(uint8_t val)
{
    /* Single-byte PIO fallback.  ESP DMA uses next_scsi_write_bytes. */
    next_scsi_write_bytes(&val, 1);
}

uint8_t next_scsi_send_status(void)
{
    return req.status;
}

uint8_t next_scsi_send_message(void)
{
    return req.message;
}

uint8_t next_scsi_get_phase(void)
{
    return req.phase;
}

void next_scsi_set_phase(uint8_t phase)
{
    req.phase = phase;
}

uint8_t next_scsi_get_target(void)
{
    return req.target;
}

int next_scsi_read_raw(uint32_t lba, uint8_t *buf, uint32_t nsect)
{
    /* Diagnostic raw-read helper used by next_ufs_diag.c. Reads from the
     * current SD installer image (target 6) since that's where UFS diag
     * runs.  If target 6 isn't mounted, refuse. */
    scsi_disk_t *d = &disks[6];
    if (!d->mounted || d->backing != DISK_BACKING_FATFS)
        return -1;
    uint64_t offset = (uint64_t)lba * 512;
    if (offset + (uint64_t)nsect * 512 > d->size_bytes)
        return -1;

    FSIZE_t saved_pos = f_tell(&d->fatfs_fil);
    FRESULT res = f_lseek(&d->fatfs_fil, (FSIZE_t)offset);
    if (res != FR_OK) {
        f_lseek(&d->fatfs_fil, saved_pos);
        return -1;
    }
    UINT br;
    res = f_read(&d->fatfs_fil, buf, nsect * 512, &br);
    f_lseek(&d->fatfs_fil, saved_pos);
    if (res != FR_OK || br != nsect * 512)
        return -1;
    return 0;
}

uint8_t *next_scsi_get_buffer_ptr(void)
{
    if (scsi_buf.size <= 0) return NULL;
    return &scsi_buf.data[scsi_buf.limit - scsi_buf.size];
}

int next_scsi_get_buffer_remaining(void)
{
    return scsi_buf.size;
}

void next_scsi_consume_bytes(int n)
{
    if (n > scsi_buf.size) n = scsi_buf.size;
    scsi_buf.size -= n;
    if (scsi_buf.size <= 0) {
        scsi_buf.size = 0;
        if (scsi_buf.is_disk)
            scsi_read_one_sector();
        else
            req.phase = SCSI_PHASE_ST;
    }
}

int next_scsi_get_write_remaining(void)
{
    return (int)req.write_pending;
}

int next_scsi_write_bytes(const uint8_t *src, int n)
{
    /* ESP DMA hands off a run of host-side bytes.  We collect into
     * wr_sector and commit to the backing store each time a full
     * SCSI_BLOCKSIZE accumulates.  When the total write_pending count
     * reaches zero (whole command drained), pad any trailing partial
     * sector with zeros, flush, and transition to Status phase. */
    if (n <= 0) return 0;
    if ((uint32_t)n > req.write_pending)
        n = (int)req.write_pending;

    int consumed = 0;
    while (n > 0) {
        uint32_t room = SCSI_BLOCKSIZE - wr_sector_fill;
        uint32_t take = ((uint32_t)n < room) ? (uint32_t)n : room;
        memcpy(&wr_sector[wr_sector_fill], src, take);
        wr_sector_fill += take;
        src += take;
        n   -= (int)take;
        consumed += (int)take;
        req.write_pending -= (uint32_t)take;

        if (wr_sector_fill == SCSI_BLOCKSIZE)
            wr_flush_sector();
    }

    if (req.write_pending == 0) {
        if (wr_sector_fill > 0) {
            memset(&wr_sector[wr_sector_fill], 0,
                   SCSI_BLOCKSIZE - wr_sector_fill);
            wr_flush_sector();
        }
        req.phase = SCSI_PHASE_ST;
    }
    return consumed;
}
