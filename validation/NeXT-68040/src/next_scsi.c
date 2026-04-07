/*
 * next_scsi.c
 * SCSI disk emulation backed by disk image file on SD card (FatFs).
 * Adapted from Previous emulator (previous/src/scsi.c).
 *
 * Single target (target 0) only. Read-only for now.
 */

#include "next_scsi.h"
#include "fatfs/ff.h"
#include "xil_printf.h"
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
/* Disk state                                                          */
/* ------------------------------------------------------------------ */
static struct {
    FIL     fil;
    uint64_t size;
    bool    mounted;
    uint8_t status;
    uint8_t message;
    uint8_t phase;
    uint8_t target;
    uint8_t lun;
    struct {
        uint8_t key, code;
        bool valid;
        uint32_t info;
    } sense;
    uint32_t lba;
    uint32_t blockcounter;
} disk;

/* Transfer buffer */
static struct {
    uint8_t data[SCSI_BLOCKSIZE];
    int limit;      /* total bytes loaded in this buffer */
    int size;       /* bytes remaining to send (DI) */
    bool is_disk;   /* true = multi-sector disk transfer */
} scsi_buf;

static FATFS fatfs_inst;

/* ------------------------------------------------------------------ */
/* INQUIRY response data                                               */
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
/* Internal: read one sector from SD card                              */
/* ------------------------------------------------------------------ */
static void scsi_read_one_sector(void)
{
    if (disk.blockcounter == 0) {
        disk.phase = SCSI_PHASE_ST;
        return;
    }

    uint64_t offset = (uint64_t)disk.lba * SCSI_BLOCKSIZE;

    if (offset < disk.size) {
        UINT br;
        FRESULT res = f_lseek(&disk.fil, (FSIZE_t)offset);
        if (res != FR_OK) {
            DPRINTF("[SCSI] f_lseek error %d at LBA %u\r\n", res, disk.lba);
            disk.status = STAT_CHECK_COND;
            disk.sense.code = SC_NOT_READY;
            disk.phase = SCSI_PHASE_ST;
            return;
        }
        res = f_read(&disk.fil, scsi_buf.data, SCSI_BLOCKSIZE, &br);
        if (res != FR_OK || br != SCSI_BLOCKSIZE) {
            DPRINTF("[SCSI] f_read error %d (got %u) at LBA %u\r\n", res, br, disk.lba);
            disk.status = STAT_CHECK_COND;
            disk.sense.code = SC_NOT_READY;
            disk.phase = SCSI_PHASE_ST;
            return;
        }
        scsi_buf.limit = scsi_buf.size = SCSI_BLOCKSIZE;
        disk.status = STAT_GOOD;
        disk.sense.code = SC_NO_ERROR;
        disk.sense.valid = false;
        disk.lba++;
        disk.blockcounter--;
    } else {
        disk.status = STAT_CHECK_COND;
        disk.sense.code = SC_INVALID_LBA;
        disk.sense.valid = true;
        disk.sense.info = disk.lba;
        disk.phase = SCSI_PHASE_ST;
    }
}

/* ------------------------------------------------------------------ */
/* SCSI command handlers                                               */
/* ------------------------------------------------------------------ */

static void scsi_test_unit_ready(void)
{
    if (!disk.mounted) {
        disk.status = STAT_CHECK_COND;
        disk.sense.code = SC_NOT_READY;
    } else {
        disk.status = STAT_GOOD;
        disk.sense.code = SC_NO_ERROR;
    }
    disk.phase = SCSI_PHASE_ST;
}

static void scsi_inquiry(uint8_t *cdb)
{
    int len = scsi_get_transfer_length(cdb[0], cdb);
    if (len > (int)sizeof(inquiry_bytes))
        len = (int)sizeof(inquiry_bytes);

    if (disk.lun != 0) {
        inquiry_bytes[0] = 0x7F; /* LUN not present */
    } else {
        inquiry_bytes[0] = 0x00; /* disk */
    }

    memcpy(scsi_buf.data, inquiry_bytes, len);
    scsi_buf.limit = scsi_buf.size = len;
    scsi_buf.is_disk = false;
    disk.status = STAT_GOOD;
    disk.phase = SCSI_PHASE_DI;
    disk.sense.code = SC_NO_ERROR;
    DPRINTF("[SCSI] Inquiry: %d bytes\r\n", len);
}

static void scsi_read_capacity(void)
{
    uint32_t sectors = (uint32_t)(disk.size / SCSI_BLOCKSIZE);
    if (sectors == 0) {
        disk.status = STAT_CHECK_COND;
        disk.sense.code = SC_NOT_READY;
        disk.phase = SCSI_PHASE_ST;
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
    disk.status = STAT_GOOD;
    disk.phase = SCSI_PHASE_DI;
    disk.sense.code = SC_NO_ERROR;
    DPRINTF("[SCSI] Read Capacity: %u sectors, last LBA=%u\r\n",
               (unsigned)(disk.size / SCSI_BLOCKSIZE), last_lba);
}

static void scsi_request_sense(uint8_t *cdb)
{
    int len = scsi_get_transfer_length(cdb[0], cdb);
    if (len <= 0) len = 4;
    if (len > 22)  len = 22;

    uint8_t retbuf[22];
    memset(retbuf, 0, sizeof(retbuf));

    retbuf[0] = 0x70;
    if (disk.sense.valid) {
        retbuf[0] |= 0x80;
        retbuf[3] = disk.sense.info >> 24;
        retbuf[4] = disk.sense.info >> 16;
        retbuf[5] = disk.sense.info >> 8;
        retbuf[6] = disk.sense.info;
    }

    switch (disk.sense.code) {
    case SC_NO_ERROR:    disk.sense.key = SK_NOSENSE;     break;
    case SC_NOT_READY:   disk.sense.key = SK_NOTREADY;    break;
    case SC_WRITE_PROTECT: disk.sense.key = SK_DATAPROTECT; break;
    case SC_INVALID_CMD:
    case SC_INVALID_LBA:
    case SC_INVALID_LUN: disk.sense.key = SK_ILLEGAL_REQ; break;
    default:             disk.sense.key = SK_HARDWARE;    break;
    }
    retbuf[2] = disk.sense.key;
    retbuf[7] = 14;
    retbuf[12] = disk.sense.code;

    memcpy(scsi_buf.data, retbuf, len);
    scsi_buf.limit = scsi_buf.size = len;
    scsi_buf.is_disk = false;
    disk.status = STAT_GOOD;
    disk.phase = SCSI_PHASE_DI;
}

static void scsi_mode_sense(uint8_t *cdb)
{
    uint8_t retbuf[64];
    memset(retbuf, 0, sizeof(retbuf));

    uint32_t sectors = (uint32_t)(disk.size / SCSI_BLOCKSIZE);
    uint8_t pagecode = cdb[2] & 0x3F;
    uint8_t dbd = cdb[1] & 0x08;

    /* Header */
    retbuf[0] = 0x00; /* length (filled later) */
    retbuf[1] = 0x00; /* medium type */
    retbuf[2] = 0x80; /* read-only */
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
        /* Simple geometry: 16 heads, 63 sectors/track */
        uint32_t heads = 16, spt = 63;
        uint32_t cyls = sectors / (heads * spt);
        if (cyls == 0) cyls = 1;
        retbuf[off++] = 0x04; retbuf[off++] = 0x12;
        retbuf[off++] = (cyls >> 16) & 0xFF;
        retbuf[off++] = (cyls >>  8) & 0xFF;
        retbuf[off++] = cyls & 0xFF;
        retbuf[off++] = heads;
        /* remaining 14 bytes are zero (already memset) */
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
    disk.status = STAT_GOOD;
    disk.phase = SCSI_PHASE_DI;
    disk.sense.code = SC_NO_ERROR;
}

static int scsi_read_log = 0;

/* Reset read log counter after kernel bus reset so we see exec-time reads */
void next_scsi_reset_read_log(void)
{
    scsi_read_log = 0;
}

static void scsi_read_sector(uint8_t *cdb)
{
    disk.lba = (uint32_t)scsi_get_offset(cdb[0], cdb);
    disk.blockcounter = scsi_get_count(cdb[0], cdb);
    scsi_buf.is_disk = true;
    scsi_buf.size = 0;
    disk.phase = SCSI_PHASE_DI;
    /* Log reads — counter resets after kernel bus reset */
    if (scsi_read_log < 200)
        xil_printf("[SCSI-RD] LBA=%u cnt=%u (byte=%llu)\r\n",
                   disk.lba, disk.blockcounter,
                   (unsigned long long)disk.lba * SCSI_BLOCKSIZE);
    scsi_read_log++;
    scsi_read_one_sector();
}

static void scsi_write_sector(uint8_t *cdb)
{
    /* Read-only for now */
    (void)cdb;
    DPRINTF("[SCSI] Write: rejected (read-only)\r\n");
    disk.status = STAT_CHECK_COND;
    disk.sense.code = SC_WRITE_PROTECT;
    disk.sense.valid = false;
    disk.phase = SCSI_PHASE_ST;
}

static void scsi_start_stop(uint8_t *cdb)
{
    (void)cdb;
    disk.status = STAT_GOOD;
    disk.phase = SCSI_PHASE_ST;
}

static void scsi_format_drive(uint8_t *cdb)
{
    (void)cdb;
    disk.status = STAT_GOOD;
    disk.phase = SCSI_PHASE_ST;
}

/* ------------------------------------------------------------------ */
/* Public API                                                          */
/* ------------------------------------------------------------------ */

int next_scsi_init(void)
{
    memset(&disk, 0, sizeof(disk));
    memset(&scsi_buf, 0, sizeof(scsi_buf));
    disk.phase = SCSI_PHASE_ST;

    /* Try to mount SD card and find a disk image */
    static const char *drives[] = { "1:/", "0:/" };
    FRESULT res;
    DIR dir;
    FILINFO fno;

    for (int d = 0; d < 2; d++) {
        xil_printf("[SCSI] Trying mount %s ...\r\n", drives[d]);
        res = f_mount(&fatfs_inst, drives[d], 1);
        if (res != FR_OK) continue;

        xil_printf("[SCSI] Mounted %s\r\n", drives[d]);

        /* Scan root for *.IMG file */
        res = f_opendir(&dir, drives[d]);
        if (res != FR_OK) { f_mount(NULL, drives[d], 0); continue; }

        bool found = false;
        while (f_readdir(&dir, &fno) == FR_OK && fno.fname[0] != '\0') {
            int len = strlen(fno.fname);
            if (len >= 4 &&
                fno.fname[len-4] == '.' &&
                (fno.fname[len-3] == 'I' || fno.fname[len-3] == 'i') &&
                (fno.fname[len-2] == 'M' || fno.fname[len-2] == 'm') &&
                (fno.fname[len-1] == 'G' || fno.fname[len-1] == 'g')) {
                char path[64];
                snprintf(path, sizeof(path), "%s%s", drives[d], fno.fname);
                f_closedir(&dir);

                res = f_open(&disk.fil, path, FA_READ);
                if (res == FR_OK) {
                    disk.size = f_size(&disk.fil);
                    disk.mounted = true;
                    xil_printf("[SCSI] Opened %s: %llu bytes (%u sectors)\r\n",
                               path, disk.size, (unsigned)(disk.size / SCSI_BLOCKSIZE));
                    return 0;
                }
                xil_printf("[SCSI] Failed to open %s (err %d)\r\n", path, res);
                f_mount(NULL, drives[d], 0);
                return -1;
            }
        }
        f_closedir(&dir);
        if (!found) {
            xil_printf("[SCSI] No .IMG file found on %s\r\n", drives[d]);
            f_mount(NULL, drives[d], 0);
        }
    }
    return -1;
}

#define SCSI_TARGET_ID  6   /* NeXT boot disk is always target 6 */

bool next_scsi_select(uint8_t target)
{
    if (target != SCSI_TARGET_ID || !disk.mounted) {
        DPRINTF("[SCSI] Select target %d: timeout\r\n", target);
        disk.phase = SCSI_PHASE_ST;  /* bus free — match Previous behavior */
        return true; /* timeout */
    }
    disk.target = target;
    return false;
}

void next_scsi_receive_command(uint8_t *cdb, int cdb_len, uint8_t identify)
{
    (void)cdb_len;

    /* Extract LUN from identify message or CDB */
    if (identify & MSG_IDENTIFY_MASK)
        disk.lun = identify & MSG_LUNMASK;
    else
        disk.lun = (cdb[1] & 0xE0) >> 5;

    uint8_t opcode = cdb[0];
    DPRINTF("[SCSI] Cmd $%02X target=%d lun=%d\r\n", opcode, disk.target, disk.lun);

    /* LUN-independent commands first */
    switch (opcode) {
    case CMD_INQUIRY:
        scsi_inquiry(cdb);
        disk.message = MSG_COMPLETE;
        return;
    case CMD_REQ_SENSE:
        scsi_request_sense(cdb);
        disk.message = MSG_COMPLETE;
        return;
    default:
        break;
    }

    /* Check LUN validity for other commands */
    if (disk.lun != 0) {
        disk.status = STAT_CHECK_COND;
        disk.sense.code = SC_INVALID_LUN;
        disk.sense.valid = false;
        disk.phase = SCSI_PHASE_ST;
        disk.message = MSG_COMPLETE;
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
        disk.status = STAT_GOOD;
        disk.phase = SCSI_PHASE_ST;
        break;
    default:
        DPRINTF("[SCSI] Unknown command $%02X\r\n", opcode);
        disk.status = STAT_CHECK_COND;
        disk.sense.code = SC_INVALID_CMD;
        disk.sense.valid = false;
        disk.phase = SCSI_PHASE_ST;
        break;
    }
    disk.message = MSG_COMPLETE;
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
            disk.phase = SCSI_PHASE_ST;
    }
    return val;
}

void next_scsi_receive_data(uint8_t val)
{
    /* Stub for write support */
    (void)val;
}

uint8_t next_scsi_send_status(void)
{
    disk.phase = SCSI_PHASE_MI;
    return disk.status;
}

uint8_t next_scsi_send_message(void)
{
    return disk.message;
}

uint8_t next_scsi_get_phase(void)
{
    return disk.phase;
}

void next_scsi_set_phase(uint8_t phase)
{
    disk.phase = phase;
}

uint8_t next_scsi_get_target(void)
{
    return disk.target;
}

int next_scsi_read_raw(uint32_t lba, uint8_t *buf, uint32_t nsect)
{
    if (!disk.mounted)
        return -1;
    uint64_t offset = (uint64_t)lba * 512;
    if (offset + (uint64_t)nsect * 512 > disk.size)
        return -1;
    /* Save and restore file position so diagnostic reads don't
     * interfere with in-flight SCSI operations. */
    FSIZE_t saved_pos = f_tell(&disk.fil);
    FRESULT res = f_lseek(&disk.fil, (FSIZE_t)offset);
    if (res != FR_OK) {
        f_lseek(&disk.fil, saved_pos);
        return -1;
    }
    UINT br;
    res = f_read(&disk.fil, buf, nsect * 512, &br);
    f_lseek(&disk.fil, saved_pos);
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
            disk.phase = SCSI_PHASE_ST;
    }
}
