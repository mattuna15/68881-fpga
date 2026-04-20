/*
 * next_ufs_diag.c
 * Diagnostic: read the raw NeXT disk image via FatFs and verify the UFS
 * inode for /etc/mach_init.  Helps debug errno 13 (EACCES) on exec.
 *
 * All on-disk data is big-endian (68K byte order).
 */

#include "next_ufs_diag.h"
#include "next_scsi.h"
#include "xil_printf.h"
#include <string.h>

/* ------------------------------------------------------------------ */
/* Big-endian helpers                                                   */
/* ------------------------------------------------------------------ */
static uint16_t be16(const uint8_t *p)
{
    return ((uint16_t)p[0] << 8) | p[1];
}

static uint32_t be32(const uint8_t *p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8)  | p[3];
}

static int32_t bes32(const uint8_t *p)
{
    return (int32_t)be32(p);
}

/* ------------------------------------------------------------------ */
/* NeXT disk label offsets (bytes from sector 0)                       */
/* ------------------------------------------------------------------ */
/* struct disk_label { int dl_version; int dl_label_blkno; int dl_size;
 *   char dl_label[24]; unsigned dl_flags; unsigned dl_tag;
 *   struct disktab dl_dt; ... } */
#define DL_VERSION_OFF      0
#define DL_LABEL_OFF        12  /* dl_label[24] */
#define DL_DT_OFF           44  /* start of struct disktab */

/* struct disktab offsets (from DL_DT_OFF) */
#define DT_SECSIZE_OFF      48
#define DT_FRONT_OFF        68  /* d_front (short) — front porch sectors */
#define DT_ROOTPART_OFF     144 /* d_rootpartition (char) */
/* d_partitions[0] starts at disktab offset 146 (after d_rwpartition) */
#define DT_PART0_OFF        146

/* struct partition: { int p_base; int p_size; short p_bsize; short p_fsize; ... } */
/* sizeof(struct partition) with 68K alignment — compute from struct */
#define PART_SIZE_EST       48  /* estimated; verify via p_size sanity */

/* NeXT label magics */
#define DL_V1   0x4e655854u
#define DL_V2   0x646c5632u
#define DL_V3   0x646c5633u

/* ------------------------------------------------------------------ */
/* UFS superblock offsets (bytes from start of superblock)             */
/* ------------------------------------------------------------------ */
/* struct fs: fs_link(4), fs_rlink(4), fs_sblkno(4), ... */
#define SB_SBLKNO_OFF       8
#define SB_IBLKNO_OFF       16
#define SB_CGOFFSET_OFF     24
#define SB_CGMASK_OFF       28
#define SB_BSIZE_OFF        48
#define SB_FSIZE_OFF        52
#define SB_FRAG_OFF         56
#define SB_FRAGSHIFT_OFF    96
#define SB_FSBTODB_OFF      100
#define SB_INOPB_OFF        120
#define SB_IPG_OFF          184
#define SB_FPG_OFF          188
/* fs_magic is deep in the struct, after fs_fsmnt[512], fs_cgrotor(4),
 * fs_csp[32 ptrs](128), fs_cpc(4), fs_postbl[32][8](512) */
#define SB_MAGIC_OFF        1372

#define FS_MAGIC_VAL        0x00011954u

/* UFS inode = 128 bytes on disk. */
#define DINODE_SIZE         128
/* dinode offsets */
#define DI_MODE_OFF         0   /* u_short */
#define DI_NLINK_OFF        2   /* short */
#define DI_UID_OFF          4   /* u_short */
#define DI_GID_OFF          6   /* u_short */
#define DI_SIZE_OFF         8   /* quad (8 bytes) */
#define DI_DB_OFF           40  /* daddr_t[12] (48 bytes) */
#define DI_IB_OFF           88  /* daddr_t[3] (12 bytes) */

/* Directory entry: d_ino(4), d_reclen(2), d_namlen(2), d_name[] */
#define DIR_INO_OFF         0
#define DIR_RECLEN_OFF      4
#define DIR_NAMLEN_OFF      6
#define DIR_NAME_OFF        8

/* ------------------------------------------------------------------ */
/* Parsed superblock                                                   */
/* ------------------------------------------------------------------ */
static struct {
    uint32_t sblkno, iblkno;
    int32_t  cgoffset, cgmask;
    uint32_t bsize, fsize, frag, fragshift, fsbtodb, inopb, ipg, fpg;
    uint32_t part_start;    /* partition start in 512-byte sectors */
} sb;

/* Sector buffer — large enough for one UFS block (up to 8192 bytes) */
static uint8_t diag_buf[8192];

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

/* Convert fragment number to byte offset from partition start */
static uint64_t frag_to_byte(uint32_t fragno)
{
    /* Each fragment is fsize bytes — avoids DEV_BSIZE assumptions */
    return (uint64_t)fragno * sb.fsize;
}

/* Read UFS data at a fragment-aligned offset into diag_buf.
 * Reads 'len' bytes. Returns 0 on success. */
static int read_ufs(uint32_t fragno, uint32_t len)
{
    uint64_t byte_off = frag_to_byte(fragno);
    uint32_t sect = (uint32_t)(byte_off / 512);
    uint32_t nsect = (len + 511) / 512;
    if (nsect > sizeof(diag_buf) / 512)
        nsect = sizeof(diag_buf) / 512;
    return next_scsi_read_raw(sb.part_start + sect, diag_buf, nsect);
}

/* Print file mode in hex + decoded type and permission bits */
static void print_mode(uint16_t mode)
{
    const char *types[] = {
        "FIFO", "CHR", "DIR", "BLK", "REG", "LNK", "SOCK", "BAD"
    };
    uint32_t t = (mode & 0xF000) >> 13;
    if (t > 7) t = 7;
    /* Show rwx permission decode */
    char perm[10];
    perm[0] = (mode & 0400) ? 'r' : '-';
    perm[1] = (mode & 0200) ? 'w' : '-';
    perm[2] = (mode & 0100) ? 'x' : '-';
    perm[3] = (mode & 040)  ? 'r' : '-';
    perm[4] = (mode & 020)  ? 'w' : '-';
    perm[5] = (mode & 010)  ? 'x' : '-';
    perm[6] = (mode & 04)   ? 'r' : '-';
    perm[7] = (mode & 02)   ? 'w' : '-';
    perm[8] = (mode & 01)   ? 'x' : '-';
    perm[9] = '\0';
    xil_printf("mode=$%04X (%s %s)", mode, types[t], perm);
}

/* Find a name in a directory data block. Returns inode number or 0. */
static uint32_t find_in_dir(const uint8_t *dirdata, uint32_t dirsize,
                            const char *name)
{
    uint32_t off = 0;
    int namelen = strlen(name);

    while (off + 8 <= dirsize) {
        uint32_t ino = be32(dirdata + off + DIR_INO_OFF);
        uint16_t reclen = be16(dirdata + off + DIR_RECLEN_OFF);
        uint16_t namlen = be16(dirdata + off + DIR_NAMLEN_OFF);

        if (reclen < 8 || reclen > dirsize - off)
            break;  /* corrupt entry */

        if (ino != 0 && namlen == (uint16_t)namelen &&
            off + DIR_NAME_OFF + namlen <= dirsize &&
            memcmp(dirdata + off + DIR_NAME_OFF, name, namelen) == 0) {
            return ino;
        }
        off += reclen;
    }
    return 0;
}

/* Print first N directory entries for debugging */
static void dump_dir(const uint8_t *dirdata, uint32_t dirsize, int max_entries)
{
    uint32_t off = 0;
    int count = 0;
    while (off + 8 <= dirsize && count < max_entries) {
        uint32_t ino = be32(dirdata + off + DIR_INO_OFF);
        uint16_t reclen = be16(dirdata + off + DIR_RECLEN_OFF);
        uint16_t namlen = be16(dirdata + off + DIR_NAMLEN_OFF);
        if (reclen < 8 || reclen > dirsize - off) break;
        if (ino != 0) {
            xil_printf("  ino=%u len=%u name=", ino, namlen);
            for (int i = 0; i < namlen && i < 32; i++)
                xil_printf("%c", dirdata[off + DIR_NAME_OFF + i]);
            xil_printf("\r\n");
            count++;
        }
        off += reclen;
    }
}

/* Read an inode from disk. Returns 0 on success, inode data in diag_buf. */
static int read_inode(uint32_t ino)
{
    /* Cylinder group containing this inode */
    uint32_t cg = ino / sb.ipg;

    /* cgstart = cgbase + cgoffset * (cg & ~cgmask) */
    uint32_t cgbase_frag = sb.fpg * cg;
    uint32_t cgstart_frag = cgbase_frag +
        (uint32_t)(sb.cgoffset * (int32_t)(cg & ~(uint32_t)sb.cgmask));

    /* cgimin = cgstart + iblkno */
    uint32_t iblock_frag = cgstart_frag + sb.iblkno;

    /* Block containing this inode */
    uint32_t ino_in_cg = ino % sb.ipg;
    uint32_t blk_in_cg = ino_in_cg / sb.inopb;
    uint32_t frag_offset = blk_in_cg << sb.fragshift;

    uint32_t target_frag = iblock_frag + frag_offset;
    uint32_t ino_in_blk = ino_in_cg % sb.inopb;

    /* Read the block containing this inode */
    if (read_ufs(target_frag, sb.bsize) != 0) {
        xil_printf("[UFS-DIAG] Failed to read inode %u block\r\n", ino);
        return -1;
    }

    /* Shift inode data to start of diag_buf for convenience */
    uint32_t offset = ino_in_blk * DINODE_SIZE;
    if (offset > 0 && offset + DINODE_SIZE <= sizeof(diag_buf))
        memmove(diag_buf, diag_buf + offset, DINODE_SIZE);

    return 0;
}

/* ------------------------------------------------------------------ */
/* Main diagnostic                                                     */
/* ------------------------------------------------------------------ */
void next_ufs_diagnose(void)
{
    xil_printf("\r\n=== UFS Filesystem Diagnostic ===\r\n");

    /* Step 1: Read NeXT disk label (sector 0) */
    if (next_scsi_read_raw(0, diag_buf, 1) != 0) {
        xil_printf("[UFS-DIAG] Failed to read sector 0\r\n");
        return;
    }

    uint32_t dl_ver = be32(diag_buf + DL_VERSION_OFF);
    if (dl_ver != DL_V1 && dl_ver != DL_V2 && dl_ver != DL_V3) {
        xil_printf("[UFS-DIAG] Bad disk label magic: $%08X\r\n", dl_ver);
        /* Dump first 64 bytes for debugging */
        xil_printf("[UFS-DIAG] Sector 0 hex:\r\n");
        for (int i = 0; i < 64; i++) {
            xil_printf("%02X ", diag_buf[i]);
            if ((i & 15) == 15) xil_printf("\r\n");
        }
        return;
    }

    char label[25];
    memcpy(label, diag_buf + DL_LABEL_OFF, 24);
    label[24] = '\0';
    xil_printf("[UFS-DIAG] Disk label: \"%s\" (version $%08X)\r\n", label, dl_ver);

    /* Read partition 'a' base sector and front porch */
    uint32_t dt_base = DL_DT_OFF;
    uint32_t part_off = dt_base + DT_PART0_OFF;

    /* Verify we're reading from the right offset by checking secsize */
    uint32_t secsize = be32(diag_buf + dt_base + DT_SECSIZE_OFF);
    uint16_t dl_front = be16(diag_buf + dt_base + DT_FRONT_OFF);
    xil_printf("[UFS-DIAG] d_secsize=%u dl_front=%u\r\n", secsize, dl_front);

    uint32_t part_a_base = be32(diag_buf + part_off);
    uint32_t part_a_size = be32(diag_buf + part_off + 4);
    uint16_t part_a_bsize = be16(diag_buf + part_off + 8);
    uint16_t part_a_fsize = be16(diag_buf + part_off + 10);

    xil_printf("[UFS-DIAG] Partition 'a': base=%u size=%u bsize=%u fsize=%u\r\n",
               part_a_base, part_a_size, part_a_bsize, part_a_fsize);

    /* Sanity check */
    if (part_a_size == 0) {
        xil_printf("[UFS-DIAG] Partition size=0, dumping label bytes %u-%u:\r\n",
                   part_off, part_off + 16);
        for (uint32_t i = part_off; i < part_off + 16 && i < 512; i++)
            xil_printf("%02X ", diag_buf[i]);
        xil_printf("\r\n");
        /* Try alternate offset (with 2 bytes padding before partitions) */
        part_off += 2;
        part_a_base = be32(diag_buf + part_off);
        part_a_size = be32(diag_buf + part_off + 4);
        xil_printf("[UFS-DIAG] Trying +2: base=%u size=%u\r\n",
                   part_a_base, part_a_size);
        if (part_a_size == 0) {
            xil_printf("[UFS-DIAG] Still bad, aborting\r\n");
            return;
        }
    }

    /* Absolute partition start = (dl_front + p_base) * d_secsize bytes
     * (kernel's sd.c line 1114: start_block = blkno + p_base + dl_front) */
    uint32_t abs_start_bytes = ((uint32_t)dl_front + part_a_base) * secsize;
    sb.part_start = abs_start_bytes / 512;  /* convert to 512-byte sectors */
    xil_printf("[UFS-DIAG] Absolute partition start: byte %u = 512-sect %u\r\n",
               abs_start_bytes, sb.part_start);

    /* Step 2: Read UFS superblock (BBSIZE=8192 bytes into the partition) */
    uint32_t sb_sect = 16;  /* BBSIZE / 512 = 8192 / 512 */
    if (next_scsi_read_raw(sb.part_start + sb_sect, diag_buf,
                           16 /* 8192/512 */) != 0) {
        xil_printf("[UFS-DIAG] Failed to read superblock\r\n");
        return;
    }

    uint32_t magic = be32(diag_buf + SB_MAGIC_OFF);
    xil_printf("[UFS-DIAG] fs_magic at offset %u = $%08X %s\r\n",
               SB_MAGIC_OFF, magic,
               magic == FS_MAGIC_VAL ? "(OK)" : "(BAD!)");

    if (magic != FS_MAGIC_VAL) {
        /* Search for magic in the superblock */
        xil_printf("[UFS-DIAG] Searching for FS_MAGIC in superblock...\r\n");
        for (uint32_t i = 0; i + 3 < 8192; i += 4) {
            if (be32(diag_buf + i) == FS_MAGIC_VAL) {
                xil_printf("[UFS-DIAG] Found FS_MAGIC at offset %u\r\n", i);
                break;
            }
        }
        /* Try without offset — maybe partition starts differently */
        xil_printf("[UFS-DIAG] Dumping superblock bytes 0-63:\r\n");
        for (int i = 0; i < 64; i++) {
            xil_printf("%02X ", diag_buf[i]);
            if ((i & 15) == 15) xil_printf("\r\n");
        }
        return;
    }

    /* Parse key superblock fields */
    sb.sblkno   = be32(diag_buf + SB_SBLKNO_OFF);
    sb.iblkno   = be32(diag_buf + SB_IBLKNO_OFF);
    sb.cgoffset = bes32(diag_buf + SB_CGOFFSET_OFF);
    sb.cgmask   = bes32(diag_buf + SB_CGMASK_OFF);
    sb.bsize    = be32(diag_buf + SB_BSIZE_OFF);
    sb.fsize    = be32(diag_buf + SB_FSIZE_OFF);
    sb.frag     = be32(diag_buf + SB_FRAG_OFF);
    sb.fragshift= be32(diag_buf + SB_FRAGSHIFT_OFF);
    sb.fsbtodb  = be32(diag_buf + SB_FSBTODB_OFF);
    sb.inopb    = be32(diag_buf + SB_INOPB_OFF);
    sb.ipg      = be32(diag_buf + SB_IPG_OFF);
    sb.fpg      = be32(diag_buf + SB_FPG_OFF);

    xil_printf("[UFS-DIAG] bsize=%u fsize=%u frag=%u inopb=%u ipg=%u fpg=%u\r\n",
               sb.bsize, sb.fsize, sb.frag, sb.inopb, sb.ipg, sb.fpg);
    xil_printf("[UFS-DIAG] sblkno=%u iblkno=%u cgoffset=%d cgmask=$%X\r\n",
               sb.sblkno, sb.iblkno, sb.cgoffset, sb.cgmask);
    xil_printf("[UFS-DIAG] fragshift=%u fsbtodb=%u\r\n",
               sb.fragshift, sb.fsbtodb);

    /* Sanity checks */
    if (sb.bsize == 0 || sb.bsize > 65536 || sb.fsize == 0 ||
        sb.inopb == 0 || sb.ipg == 0) {
        xil_printf("[UFS-DIAG] Superblock values look wrong\r\n");
        return;
    }

    /* Step 3: Read root inode (inode 2) */
    xil_printf("[UFS-DIAG] Reading root inode (inode 2)...\r\n");
    if (read_inode(2) != 0) return;

    uint16_t root_mode = be16(diag_buf + DI_MODE_OFF);
    uint32_t root_db0 = be32(diag_buf + DI_DB_OFF);
    print_mode(root_mode);
    xil_printf(" uid=%u gid=%u db[0]=%u\r\n",
               be16(diag_buf + DI_UID_OFF),
               be16(diag_buf + DI_GID_OFF), root_db0);

    if ((root_mode & 0xF000) != 0x4000) {
        xil_printf("[UFS-DIAG] Root inode is NOT a directory!\r\n");
        xil_printf("[UFS-DIAG] Raw inode hex:\r\n");
        for (int i = 0; i < 128; i++) {
            xil_printf("%02X ", diag_buf[i]);
            if ((i & 15) == 15) xil_printf("\r\n");
        }
        return;
    }

    /* Step 4: Read root directory and find "etc" */
    xil_printf("[UFS-DIAG] Reading root directory (frag %u)...\r\n", root_db0);
    if (read_ufs(root_db0, sb.bsize) != 0) {
        xil_printf("[UFS-DIAG] Failed to read root directory\r\n");
        return;
    }

    xil_printf("[UFS-DIAG] Root directory entries:\r\n");
    dump_dir(diag_buf, sb.bsize, 20);

    uint32_t etc_ino = find_in_dir(diag_buf, sb.bsize, "etc");
    if (etc_ino == 0) {
        xil_printf("[UFS-DIAG] 'etc' not found in root directory!\r\n");
        return;
    }
    xil_printf("[UFS-DIAG] etc -> inode %u\r\n", etc_ino);

    /* Step 5: Read /etc inode — may be a symlink (e.g., /etc -> private/etc) */
    if (read_inode(etc_ino) != 0) return;

    uint16_t etc_mode = be16(diag_buf + DI_MODE_OFF);
    uint32_t etc_db0 = be32(diag_buf + DI_DB_OFF);
    xil_printf("[UFS-DIAG] /etc inode: ");
    print_mode(etc_mode);
    xil_printf(" db[0]=$%08X\r\n", etc_db0);

    /* If /etc is a symlink (fast link), follow it */
    if ((etc_mode & 0xF000) == 0xA000) {
        /* Fast symlink: target stored in di_db[] area (offset 40, up to 60 bytes) */
        uint8_t link_inode[128];
        memcpy(link_inode, diag_buf, 128);
        char link_target[64];
        int link_len = be32(link_inode + DI_SIZE_OFF + 4); /* di_size low word */
        if (link_len > 60) link_len = 60;
        memcpy(link_target, link_inode + DI_DB_OFF, link_len);
        link_target[link_len] = '\0';
        xil_printf("[UFS-DIAG] /etc is symlink -> \"%s\"\r\n", link_target);

        /* Follow: parse path components from root */
        uint32_t cur_ino = 2; /* start at root */
        char *p = link_target;
        while (*p) {
            /* Skip leading slashes */
            while (*p == '/') p++;
            if (*p == '\0') break;
            /* Extract component */
            char *start = p;
            while (*p && *p != '/') p++;
            int clen = p - start;
            char component[64];
            if (clen >= 64) clen = 63;
            memcpy(component, start, clen);
            component[clen] = '\0';

            /* Read current inode's directory */
            if (read_inode(cur_ino) != 0) return;
            uint32_t dir_db0 = be32(diag_buf + DI_DB_OFF);
            if (read_ufs(dir_db0, sb.bsize) != 0) {
                xil_printf("[UFS-DIAG] Failed to read dir for '%s'\r\n", component);
                return;
            }
            cur_ino = find_in_dir(diag_buf, sb.bsize, component);
            if (cur_ino == 0) {
                xil_printf("[UFS-DIAG] '%s' not found\r\n", component);
                return;
            }
            xil_printf("[UFS-DIAG] %s -> inode %u\r\n", component, cur_ino);
        }
        /* cur_ino now points to the resolved /etc directory */
        etc_ino = cur_ino;
        if (read_inode(etc_ino) != 0) return;
        etc_mode = be16(diag_buf + DI_MODE_OFF);
        etc_db0 = be32(diag_buf + DI_DB_OFF);
        xil_printf("[UFS-DIAG] Resolved /etc inode %u: ", etc_ino);
        print_mode(etc_mode);
        xil_printf("\r\n");
    }

    if ((etc_mode & 0xF000) != 0x4000) {
        xil_printf("[UFS-DIAG] /etc is not a directory after symlink resolution!\r\n");
        return;
    }

    if (read_ufs(etc_db0, sb.bsize) != 0) {
        xil_printf("[UFS-DIAG] Failed to read /etc directory\r\n");
        return;
    }

    uint32_t mach_init_ino = find_in_dir(diag_buf, sb.bsize, "mach_init");
    uint32_t init_ino = find_in_dir(diag_buf, sb.bsize, "init");
    xil_printf("[UFS-DIAG] /etc entries:\r\n");
    dump_dir(diag_buf, sb.bsize, 20);

    /* Step 6: Resolve /etc/mach_init — follow all symlinks to the real file */
    if (mach_init_ino != 0) {
        xil_printf("\r\n[UFS-DIAG] === Resolving /etc/mach_init ===\r\n");
        uint32_t cur = mach_init_ino;
        for (int depth = 0; depth < 8; depth++) {
            if (read_inode(cur) != 0) break;
            uint16_t mode = be16(diag_buf + DI_MODE_OFF);
            xil_printf("[UFS-DIAG] inode %u: ", cur);
            print_mode(mode);
            xil_printf(" uid=%u gid=%u size=%u\r\n",
                       be16(diag_buf + DI_UID_OFF),
                       be16(diag_buf + DI_GID_OFF),
                       be32(diag_buf + DI_SIZE_OFF + 4));

            if ((mode & 0xF000) == 0xA000) {
                /* Symlink — read target from fast link data */
                uint8_t lnk[128];
                memcpy(lnk, diag_buf, 128);
                int llen = be32(lnk + DI_SIZE_OFF + 4);
                if (llen > 60) llen = 60;
                char target[64];
                memcpy(target, lnk + DI_DB_OFF, llen);
                target[llen] = '\0';
                xil_printf("[UFS-DIAG]   -> \"%s\"\r\n", target);

                /* Resolve: walk from root through target path */
                uint32_t walk = 2; /* start at root for absolute, or parent for relative */
                char *p = target;
                /* For relative paths starting with ../, we need parent context.
                 * Simplified: always resolve from root for absolute paths,
                 * skip ../ components by walking from root. */
                /* Convert relative to absolute: the symlink is in /private/etc/
                 * or /usr/etc/ — for simplicity, handle ../../ prefix -> / */
                while (*p == '.' && *(p+1) == '.' && *(p+2) == '/') p += 3;
                while (*p == '/') p++; /* skip leading slashes */

                while (*p) {
                    while (*p == '/') p++;
                    if (*p == '\0') break;
                    char *s = p;
                    while (*p && *p != '/') p++;
                    int cl = p - s;
                    char comp[64];
                    if (cl >= 64) cl = 63;
                    memcpy(comp, s, cl);
                    comp[cl] = '\0';

                    if (read_inode(walk) != 0) { walk = 0; break; }
                    uint32_t ddb = be32(diag_buf + DI_DB_OFF);
                    if (read_ufs(ddb, sb.bsize) != 0) { walk = 0; break; }
                    walk = find_in_dir(diag_buf, sb.bsize, comp);
                    if (walk == 0) {
                        xil_printf("[UFS-DIAG]   '%s' not found!\r\n", comp);
                        break;
                    }
                    xil_printf("[UFS-DIAG]   %s -> inode %u\r\n", comp, walk);
                }
                if (walk == 0) break;
                cur = walk;
                continue;
            }

            /* Not a symlink — this is the real file */
            if ((mode & 0xF000) == 0x8000) {
                xil_printf("[UFS-DIAG] *** REGULAR FILE — exec should work ***\r\n");
                /* Show Mach-O header */
                uint32_t db0 = be32(diag_buf + DI_DB_OFF);
                if (db0 != 0 && read_ufs(db0, 512) == 0) {
                    xil_printf("[UFS-DIAG] First 32 bytes:\r\n  ");
                    for (int i = 0; i < 32; i++)
                        xil_printf("%02X ", diag_buf[i]);
                    xil_printf("\r\n");
                    uint32_t mh = be32(diag_buf);
                    xil_printf("[UFS-DIAG] Mach-O: $%08X %s\r\n", mh,
                               mh == 0xFEEDFACE ? "(OK)" : "(BAD)");
                }
            } else {
                xil_printf("[UFS-DIAG] *** NOT REG FILE — this causes EACCES! ***\r\n");
            }

            /* Raw inode */
            if (read_inode(cur) == 0) {
                xil_printf("[UFS-DIAG] Raw inode:\r\n");
                for (int i = 0; i < 128; i++) {
                    xil_printf("%02X ", diag_buf[i]);
                    if ((i & 15) == 15) xil_printf("\r\n");
                }
            }
            break;
        }
    } else {
        xil_printf("[UFS-DIAG] mach_init NOT found in /etc!\r\n");
    }

    xil_printf("=== End UFS Diagnostic ===\r\n\r\n");
}
