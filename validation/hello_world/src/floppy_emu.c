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

static void fdc_execute_command(uint8_t cmd)
{
    uint8_t cmd_type = cmd & 0xF0;

    switch (cmd_type) {
    case 0x00: /* RESTORE — seek to track 0 */
        fdc_track = 0;
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | FDC_STAT_TRACK0;
        break;

    case 0x10: /* SEEK — seek to track in data register */
        fdc_track = fdc_data;
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        if (fdc_track == 0)
            fdc_status |= FDC_STAT_TRACK0;
        break;

    case 0x80: /* READ SECTOR */
    case 0x90: { /* READ SECTOR (variants) */
        int side = psg_get_side();
        if (st_image == NULL || disk_spt == 0) {
            fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10; /* RNF */
            break;
        }
        uint32_t offset = ((uint32_t)fdc_track * disk_sides + side) * disk_spt
                          + ((uint32_t)fdc_sector - 1);
        offset *= 512;
        if (offset + 512 <= st_image_size && dma_addr + 512 <= EMU_RAM_SIZE) {
            memcpy(&emu_ram[dma_addr], &st_image[offset], 512);
            dma_addr += 512;
            if (dma_sector_count > 0)
                dma_sector_count--;
        } else {
            fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x10; /* RNF */
            break;
        }
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        if (fdc_track == 0)
            fdc_status |= FDC_STAT_TRACK0;
        break;
    }

    case 0xA0: /* WRITE SECTOR */
    case 0xB0: /* WRITE SECTOR (variants) */
        /* .ST image is const — report write-protect */
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP | 0x40; /* WP */
        break;

    case 0xD0: /* FORCE INTERRUPT */
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        if (fdc_track == 0)
            fdc_status |= FDC_STAT_TRACK0;
        break;

    default:
        /* Unhandled command — just set motor on */
        fdc_status = FDC_STAT_MOTOR_ON | FDC_STAT_SPINUP;
        break;
    }
}

/* Read FDC register selected by DMA control bits */
static uint8_t fdc_read_reg(void)
{
    uint8_t reg_sel = (dma_control >> 1) & 3;
    switch (reg_sel) {
    case 0: return fdc_status;
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

    case 0x02: /* $FF8606 DMA control high byte */
        return (dma_control >> 8) & 0xFF;

    case 0x03: /* $FF8607 DMA control low byte — also DMA status in bit 0 */
        /* Bit 0 = DMA OK (no error), bit 1 = sector count != 0 */
        return 0x01; /* Always OK */

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

void floppy_write(uint32_t offset, uint8_t value)
{
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

    case 0x03: /* $FF8607 DMA control low byte — process word */
        dma_control = ((uint16_t)dma_ctrl_hi << 8) | value;
        break;

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
