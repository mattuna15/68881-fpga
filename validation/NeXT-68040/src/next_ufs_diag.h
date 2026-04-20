#ifndef NEXT_UFS_DIAG_H
#define NEXT_UFS_DIAG_H

/* Parse the raw NeXT disk image and verify /etc/mach_init inode.
 * Call after next_scsi_init() succeeds. */
void next_ufs_diagnose(void);

#endif
