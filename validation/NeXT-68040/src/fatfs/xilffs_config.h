/*
 * xilffs_config.h
 * Local FatFs configuration for SD card floppy image loading.
 * Included by ffconf.h when SDT is defined.
 */

#ifndef XILFFS_CONFIG_H
#define XILFFS_CONFIG_H

#define FILE_SYSTEM_INTERFACE_SD
#define FILE_SYSTEM_NUM_LOGIC_VOL  2
#define FILE_SYSTEM_WORD_ACCESS    1

#endif /* XILFFS_CONFIG_H */
