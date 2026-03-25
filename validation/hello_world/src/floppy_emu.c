/*
 * floppy_emu.c
 * Atari ST floppy DMA controller + WD1772 FDC emulation.
 *
 * Serves sector data from a raw .ST floppy image stored in RAM.
 * Commands complete instantly (no BUSY state machine).
 *
 * .ST image layout: raw sectors, no header.
 *   byte_offset = ((track * sides + side) * spt + (sector - 1)) * 512
 * Geometry auto-detected from file size.
 */

#include <string.h>
#include "floppy_emu.h"
#include "psg_emu.h"
#include "emu_memory.h"
#include "xil_printf.h"

/* FDC status bits */
#define FDC_STAT_MOTOR_ON  0x80
#define FDC_STAT_SPINUP    0x20
#define FDC_STAT_TRACK0    0x04
#define FDC_STAT_BUSY      0x00  /* never busy — instant completion */

/* FDC interrupt state: set when command completes, cleared on status read */
static int fdc_irq_pending;

/* Last step direction: +1 = inward (higher tracks), -1 = outward */
static int step_direction;

/* Disk geometry (auto-detected) */
static uint32_t disk_sides;
static uint32_t disk_spt;       /* sectors per track */
static uint32_t disk_tracks;

/* FDC registers */
static uint8_t fdc_status;
static uint8_t fdc_track;
static uint8_t fdc_sector;
static uint8_t fdc_data;

/* DMA registers */
static uint16_t dma_control;
static uint16_t dma_sector_count;
static uint32_t dma_addr;       /* 24-bit DMA address */

/* Word-access latch: high byte buffered on even-offset write */
static uint8_t dma_data_hi;
static uint8_t dma_ctrl_hi;

/* .ST image */
static const uint8_t *st_image;
static uint32_t st_image_size;

static void detect_geometry(uint32_t size)
{
    /* Standard .ST image sizes:
     *   360 KB = 80*1*9*512   (SS/DD)
     *   720 KB = 80*2*9*512   (DS/DD)
     *   800 KB = 80*2*10*512  (DS/DD 10-sector)
     *   880 KB = 80*2*11*512  (DS/DD 11-sector)
     */
    uint32_t total_sectors = size / 512;
    if (total_sectors == 0) {
        disk_tracks = 0;
        disk_sides = 0;
        disk_spt = 0;
        return;
    }

    if (total_sectors == 720) {         /* 360 KB SS */
        disk_tracks = 80; disk_sides = 1; disk_spt = 9;
    } else if (total_sectors == 1440) { /* 720 KB DS */
        disk_tracks = 80; disk_sides = 2; disk_spt = 9;
    } else if (total_sectors == 1600) { /* 800 KB DS */
        disk_tracks = 80; disk_sides = 2; disk_spt = 10;
    } else if (total_sectors == 1760) { /* 880 KB DS */
        disk_tracks = 80; disk_sides = 2; disk_spt = 11;
    } else {
        /* Generic: assume DS, 9 spt */
        disk_sides = 2;
        disk_spt = 9;
        disk_tracks = total_sectors / (disk_sides * disk_spt);
    }
}

void floppy_init(const uint8_t *image_data, uint32_t image_size)
{
    st_image = image_data;
    st_image_size = image_size;

    fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | FDC_STAT_TRACK0;
    fdc_irq_pending = 0;
    step_direction = 1;
    fdc_track = 0;
    fdc_sector = 1;
    fdc_data = 0;

    dma_control = 0;
    dma_sector_count = 0;
    dma_addr = 0;
    dma_data_hi = 0;
    dma_ctrl_hi = 0;

    if (image_size > 0) {
        detect_geometry(image_size);
        xil_printf("[FDC] Floppy image: %u bytes, %u tracks, %u sides, %u spt\r\n",
                   image_size, disk_tracks, disk_sides, disk_spt);
    } else {
        disk_tracks = 0;
        disk_sides = 0;
        disk_spt = 0;
        xil_printf("[FDC] No floppy image loaded\r\n");
    }
}

static void fdc_set_type1_status(void)
{
    fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
    if (fdc_track == 0)
        fdc_status |= FDC_STAT_TRACK0;
}

static void fdc_execute_command(uint8_t cmd)
{
    uint8_t cmd_type = cmd & 0xF0;

    /* Clear previous IRQ — new command starting */
    fdc_irq_pending = 0;

    switch (cmd_type) {
    /* ---- Type I commands ---- */

    case 0x00: /* RESTORE — seek to track 0 */
        fdc_track = 0;
        step_direction = -1;  /* RESTORE steps outward toward track 0 */
        fdc_set_type1_status();
        break;

    case 0x10: /* SEEK — seek to track in data register */
        if (fdc_data > fdc_track)
            step_direction = 1;
        else if (fdc_data < fdc_track)
            step_direction = -1;
        fdc_track = fdc_data;
        fdc_set_type1_status();
        break;

    case 0x20: /* STEP (no update) */
    case 0x30: { /* STEP (update track register) */
        int old_trk = fdc_track;
        int new_trk = (int)fdc_track + step_direction;
        if (new_trk < 0)  new_trk = 0;
        if (new_trk > 83) new_trk = 83;
        if (cmd_type == 0x30) /* update flag (T bit) */
            fdc_track = (uint8_t)new_trk;
        fdc_set_type1_status();
        break;
    }

    case 0x40: /* STEP-IN (no update) */
    case 0x50: { /* STEP-IN (update track register) */
        step_direction = 1;
        int new_trk = (int)fdc_track + 1;
        if (new_trk > 83) new_trk = 83;
        if (cmd_type == 0x50) /* update flag */
            fdc_track = (uint8_t)new_trk;
        fdc_set_type1_status();
        break;
    }

    case 0x60: /* STEP-OUT (no update) */
    case 0x70: { /* STEP-OUT (update track register) */
        step_direction = -1;
        int new_trk = (int)fdc_track - 1;
        if (new_trk < 0) new_trk = 0;
        if (cmd_type == 0x70) /* update flag */
            fdc_track = (uint8_t)new_trk;
        fdc_set_type1_status();
        break;
    }

    /* ---- Type II commands ---- */

    case 0x80: /* READ SECTOR (single) */
    case 0x90: { /* READ SECTOR (multiple — bit 4 set) */
        int multi = (cmd & 0x10);
        int side = psg_get_side();
        if (st_image == NULL || disk_spt == 0) {
            fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10; /* RNF */
            break;
        }
        do {
            uint32_t offset = ((uint32_t)fdc_track * disk_sides + side)
                              * disk_spt + ((uint32_t)fdc_sector - 1);
            offset *= 512;
            if (fdc_sector < 1 || fdc_sector > disk_spt ||
                offset + 512 > st_image_size ||
                dma_addr + 512 > EMU_RAM_SIZE) {
                fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10; /* RNF */
                goto read_done;
            }
            memcpy(&emu_ram[dma_addr], &st_image[offset], 512);
            dma_addr += 512;
            if (dma_sector_count > 0)
                dma_sector_count--;
            if (!multi)
                break;
            fdc_sector++;
        } while (dma_sector_count > 0);
        /* Type II status: bit 2 = LOST DATA (NOT track0!), bit 5 = record type.
         * Do NOT set TRACK0 here — that's only for Type I commands. */
        fdc_status = FDC_STAT_MOTOR_ON;
    read_done:
        break;
    }

    case 0xA0: /* WRITE SECTOR */
    case 0xB0: /* WRITE SECTOR (variants) */
        /* .ST image is const — report write-protect */
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x40; /* WP */
        break;

    /* ---- Type III commands ---- */

    case 0xC0: { /* READ ADDRESS — return 6-byte ID field */
        int side = psg_get_side();
        if (st_image == NULL || disk_spt == 0) {
            fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10; /* RNF */
            break;
        }
        /* Fabricate an ID field for sector 1 on the current track.
         * WD1772 spec: sector register gets track address from ID. */
        uint8_t id[6];
        id[0] = fdc_track;       /* track */
        id[1] = (uint8_t)side;   /* side */
        id[2] = 1;               /* sector number (first sector on track) */
        id[3] = 2;               /* size code: 2 = 512 bytes */
        id[4] = 0;               /* CRC high (dummy) */
        id[5] = 0;               /* CRC low (dummy) */

        /* Transfer 6 bytes via DMA — only if sector count > 0.
         * Hatari: DMA with sector count = 0 rejects the transfer. */
        if (dma_sector_count > 0 && dma_addr + 6 <= EMU_RAM_SIZE) {
            memcpy(&emu_ram[dma_addr], id, 6);
            dma_addr += 6;
        }

        /* WD1772: after READ ADDRESS, sector register = track from ID.
         * BUT this overwrites fdc_sector with the track number, which
         * would make sector=0 at track 0 and break subsequent reads.
         * EmuTOS re-sets the sector register before READ SECTOR, so
         * this is harmless — but we must still do it for correctness. */
        fdc_sector = fdc_track;
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        break;
    }

    case 0xE0: { /* READ TRACK — transfer entire track of raw data */
        int side = psg_get_side();
        if (st_image == NULL || disk_spt == 0) {
            fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10;
            break;
        }
        /* Transfer all sectors on this track — only if DMA sector count > 0 */
        if (dma_sector_count > 0) {
            uint32_t track_offset = ((uint32_t)fdc_track * disk_sides + side)
                                    * disk_spt * 512;
            uint32_t track_bytes = disk_spt * 512;
            if (track_offset + track_bytes <= st_image_size &&
                dma_addr + track_bytes <= EMU_RAM_SIZE) {
                memcpy(&emu_ram[dma_addr], &st_image[track_offset], track_bytes);
                dma_addr += track_bytes;
                fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
            } else {
                fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10; /* RNF */
            }
        } else {
            fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        }
        break;
    }

    case 0xF0: /* WRITE TRACK (format) */
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x40; /* WP */
        break;

    /* ---- Type IV command ---- */

    case 0xD0: /* FORCE INTERRUPT */
        fdc_set_type1_status();
        /* WD1772: condition bits (3:0) determine IRQ behavior.
         * $D0 = no conditions → terminate, clear IRQ (GPIP5 goes high).
         * $D8 = immediate interrupt → assert IRQ.
         * $D4 = index pulse, $D2 = not-busy→busy transition, etc. */
        if ((cmd & 0x0F) == 0) {
            fdc_irq_pending = 0;  /* $D0: clear IRQ */
        } else {
            fdc_irq_pending = 1;  /* $D8+: assert IRQ */
        }
        return; /* skip the common IRQ assertion below */

    default:
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        break;
    }

    /* Assert FDC interrupt (GPIP5 low) unless Drive B is explicitly selected.
     * Drive A (0) or no drive (-1) both complete — on a real single-drive ST,
     * the FDC always responds when the physical drive exists.
     * Only Drive B (1) should timeout to indicate it's absent.
     * FORCE_INT handles IRQ itself and returns early above. */
    if (psg_get_drive() != 1) {
        fdc_irq_pending = 1;
    } else {
        /* Drive B not present — leave IRQ unasserted */
        fdc_status = FDC_STAT_MOTOR_ON;
    }
}

/* Read FDC register selected by DMA control bits */
static uint8_t fdc_read_reg(void)
{
    uint8_t reg_sel = (dma_control >> 1) & 3;
    switch (reg_sel) {
    case 0:
        /* On real WD1772, reading status clears IRQ.  But with instant
         * completion the IRQ would be consumed before the VBL handler
         * polls GPIP5.  Instead, clear IRQ only when a new command is
         * written (in fdc_execute_command).  This keeps GPIP5 low long
         * enough for EmuTOS's flopvbl() to detect completion. */
        return fdc_status;
    case 1: return fdc_track;
    case 2: return fdc_sector;
    case 3: return fdc_data;
    }
    return 0;
}

/* Write FDC register selected by DMA control bits */
static void fdc_write_reg(uint8_t value)
{
    uint8_t reg_sel = (dma_control >> 1) & 3;
    switch (reg_sel) {
    case 0: fdc_execute_command(value); break;
    case 1: fdc_track = value;          break;
    case 2: fdc_sector = value;         break;
    case 3: fdc_data = value;           break;
    }
}

uint8_t floppy_read(uint32_t offset)
{
    switch (offset) {
    case 0x00: /* $FF8604 DMA data high byte */
        if (dma_control & 0x10) {
            /* Sector count mode */
            return (dma_sector_count >> 8) & 0xFF;
        }
        return 0; /* FDC regs are in low byte only */

    case 0x01: /* $FF8605 DMA data low byte */
        if (dma_control & 0x10) {
            return dma_sector_count & 0xFF;
        }
        return fdc_read_reg();

    case 0x02: /* $FF8606 DMA status high byte (control reg is write-only) */
        return 0x00;

    case 0x03: { /* $FF8607 DMA status low byte */
        /* Hatari-matched bit definitions:
         * Bit 0: 1 = no DMA error, 0 = error
         * Bit 1: 1 = sector count NON-ZERO, 0 = sector count IS zero
         * Bit 2: DRQ (always 0 on ST — DMA services it before CPU sees it) */
        uint8_t stat = 0x01; /* no error */
        if (dma_sector_count != 0)
            stat |= 0x02;   /* sector count still non-zero */
        return stat;
    }

    case 0x05: /* $FF8609 DMA addr high */
        return (dma_addr >> 16) & 0xFF;

    case 0x07: /* $FF860B DMA addr mid */
        return (dma_addr >> 8) & 0xFF;

    case 0x09: /* $FF860D DMA addr low */
        return dma_addr & 0xFF;

    default:
        return 0;
    }
}

static int fdc_write_dbg_count;

void floppy_write(uint32_t offset, uint8_t value)
{
#ifdef DMA_DEBUG
    if (fdc_write_dbg_count < 50) {
        xil_printf("[DMA] W off=%02X val=%02X ctrl=%04X\r\n",
                   offset, value, dma_control);
        fdc_write_dbg_count++;
    }
#endif

    switch (offset) {
    case 0x00: /* $FF8604 DMA data high byte — latch */
        dma_data_hi = value;
        break;

    case 0x01: /* $FF8605 DMA data low byte — process word */
        if (dma_control & 0x10) {
            /* Sector count register */
            dma_sector_count = ((uint16_t)dma_data_hi << 8) | value;
        } else {
            /* FDC register access (low byte only) */
            fdc_write_reg(value);
        }
        break;

    case 0x02: /* $FF8606 DMA control high byte — latch */
        dma_ctrl_hi = value;
        break;

    case 0x03: { /* $FF8607 DMA control low byte — process word */
        uint16_t new_control = ((uint16_t)dma_ctrl_hi << 8) | value;
        /* Hatari: toggling bit 8 resets the DMA (clears FIFO, sector count) */
        if ((new_control ^ dma_control) & 0x100)
            dma_sector_count = 0;
        dma_control = new_control;
        break;
    }

    case 0x05: /* $FF8609 DMA addr high */
        dma_addr = (dma_addr & 0x00FFFF) | ((uint32_t)value << 16);
        break;

    case 0x07: /* $FF860B DMA addr mid */
        dma_addr = (dma_addr & 0xFF00FF) | ((uint32_t)value << 8);
        break;

    case 0x09: /* $FF860D DMA addr low */
        dma_addr = (dma_addr & 0xFFFF00) | value;
        break;

    default:
        break;
    }
}

int floppy_irq_active(void)
{
    return fdc_irq_pending;
}
