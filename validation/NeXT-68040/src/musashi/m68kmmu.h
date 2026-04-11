/*
    m68kmmu.h - PMMU implementation for 68851/68030/68040

    By R. Belmont

    Copyright Nicola Salmoria and the MAME Team.
    Visit http://mamedev.org for licensing and usage restrictions.
*/

#include "xil_printf.h"
#include "next_memory.h"

/*
	pmmu_translate_addr: perform 68851/68030-style PMMU address translation
*/
uint pmmu_translate_addr_030(uint addr_in)
{
	uint32 addr_out, tbl_entry = 0, tbl_entry2, tamode = 0, tbmode = 0, tcmode = 0;
	uint root_aptr, root_limit, tofs, is, abits, bbits, cbits;
	uint resolved, tptr, shift;

	resolved = 0;
	addr_out = addr_in;

	// if SRP is enabled and we're in supervisor mode, use it
	if ((m68ki_cpu.mmu_tc & 0x02000000) && (m68ki_get_sr() & 0x2000))
	{
		root_aptr = m68ki_cpu.mmu_srp_aptr;
		root_limit = m68ki_cpu.mmu_srp_limit;
	}
	else	// else use the CRP
	{
		root_aptr = m68ki_cpu.mmu_crp_aptr;
		root_limit = m68ki_cpu.mmu_crp_limit;
	}

	// get initial shift (# of top bits to ignore)
	is = (m68ki_cpu.mmu_tc>>16) & 0xf;
	abits = (m68ki_cpu.mmu_tc>>12)&0xf;
	bbits = (m68ki_cpu.mmu_tc>>8)&0xf;
	cbits = (m68ki_cpu.mmu_tc>>4)&0xf;

//	xil_printf("PMMU: tcr %08x limit %08x aptr %08x is %x abits %d bbits %d cbits %d\n", m68ki_cpu.mmu_tc, root_limit, root_aptr, is, abits, bbits, cbits);

	// get table A offset
	tofs = (addr_in<<is)>>(32-abits);

	// find out what format table A is
	switch (root_limit & 3)
	{
		case 0:	// invalid, should cause MMU exception
		case 1:	// page descriptor, should cause direct mapping
			fatalerror("680x0 PMMU: Unhandled root mode\n");
			break;

		case 2:	// valid 4 byte descriptors
			tofs *= 4;
//			xil_printf("PMMU: reading table A entry at %08x\n", tofs + (root_aptr & 0xfffffffc));
			tbl_entry = m68k_read_memory_32( tofs + (root_aptr & 0xfffffffc));
			tamode = tbl_entry & 3;
//			xil_printf("PMMU: addr %08x entry %08x mode %x tofs %x\n", addr_in, tbl_entry, tamode, tofs);
			break;

		case 3: // valid 8 byte descriptors
			tofs *= 8;
//			xil_printf("PMMU: reading table A entries at %08x\n", tofs + (root_aptr & 0xfffffffc));
			tbl_entry2 = m68k_read_memory_32( tofs + (root_aptr & 0xfffffffc));
			tbl_entry = m68k_read_memory_32( tofs + (root_aptr & 0xfffffffc)+4);
			tamode = tbl_entry2 & 3;
//			xil_printf("PMMU: addr %08x entry %08x entry2 %08x mode %x tofs %x\n", addr_in, tbl_entry, tbl_entry2, tamode, tofs);
			break;
	}

	// get table B offset and pointer
	tofs = (addr_in<<(is+abits))>>(32-bbits);
	tptr = tbl_entry & 0xfffffff0;

	// find out what format table B is, if any
	switch (tamode)
	{
		case 0: // invalid, should cause MMU exception
			fatalerror("680x0 PMMU: Unhandled Table A mode %d (addr_in %08x)\n", tamode, addr_in);
			break;

		case 2: // 4-byte table B descriptor
			tofs *= 4;
//			xil_printf("PMMU: reading table B entry at %08x\n", tofs + tptr);
			tbl_entry = m68k_read_memory_32( tofs + tptr);
			tbmode = tbl_entry & 3;
//			xil_printf("PMMU: addr %08x entry %08x mode %x tofs %x\n", addr_in, tbl_entry, tbmode, tofs);
			break;

		case 3: // 8-byte table B descriptor
			tofs *= 8;
//			xil_printf("PMMU: reading table B entries at %08x\n", tofs + tptr);
			tbl_entry2 = m68k_read_memory_32( tofs + tptr);
			tbl_entry = m68k_read_memory_32( tofs + tptr + 4);
			tbmode = tbl_entry2 & 3;
//			xil_printf("PMMU: addr %08x entry %08x entry2 %08x mode %x tofs %x\n", addr_in, tbl_entry, tbl_entry2, tbmode, tofs);
			break;

		case 1:	// early termination descriptor
			tbl_entry &= 0xffffff00;

			shift = is+abits;
			addr_out = ((addr_in<<shift)>>shift) + tbl_entry;
			resolved = 1;
			break;
	}

	// if table A wasn't early-out, continue to process table B
	if (!resolved)
	{
		// get table C offset and pointer
		tofs = (addr_in<<(is+abits+bbits))>>(32-cbits);
		tptr = tbl_entry & 0xfffffff0;

		switch (tbmode)
		{
			case 0:	// invalid, should cause MMU exception
				fatalerror("680x0 PMMU: Unhandled Table B mode %d (addr_in %08x PC %x)\n", tbmode, addr_in, REG_PC);
				break;

			case 2: // 4-byte table C descriptor
				tofs *= 4;
//				xil_printf("PMMU: reading table C entry at %08x\n", tofs + tptr);
				tbl_entry = m68k_read_memory_32(tofs + tptr);
				tcmode = tbl_entry & 3;
//				xil_printf("PMMU: addr %08x entry %08x mode %x tofs %x\n", addr_in, tbl_entry, tbmode, tofs);
				break;

			case 3: // 8-byte table C descriptor
				tofs *= 8;
//				xil_printf("PMMU: reading table C entries at %08x\n", tofs + tptr);
				tbl_entry2 = m68k_read_memory_32(tofs + tptr);
				tbl_entry = m68k_read_memory_32(tofs + tptr + 4);
				tcmode = tbl_entry2 & 3;
//				xil_printf("PMMU: addr %08x entry %08x entry2 %08x mode %x tofs %x\n", addr_in, tbl_entry, tbl_entry2, tbmode, tofs);
				break;

			case 1: // termination descriptor
				tbl_entry &= 0xffffff00;

				shift = is+abits+bbits;
				addr_out = ((addr_in<<shift)>>shift) + tbl_entry;
				resolved = 1;
				break;
		}
	}

	if (!resolved)
	{
		switch (tcmode)
		{
			case 0:	// invalid, should cause MMU exception
			case 2: // 4-byte ??? descriptor
			case 3: // 8-byte ??? descriptor
				fatalerror("680x0 PMMU: Unhandled Table B mode %d (addr_in %08x PC %x)\n", tbmode, addr_in, REG_PC);
				break;

			case 1: // termination descriptor
				tbl_entry &= 0xffffff00;

				shift = is+abits+bbits+cbits;
				addr_out = ((addr_in<<shift)>>shift) + tbl_entry;
				resolved = 1;
				break;
		}
	}


//	xil_printf("PMMU: [%08x] => [%08x]\n", addr_in, addr_out);

	return addr_out;
}

/*
	pmmu_translate_addr_040: 68040 MMU address translation

	68040 MMU uses:
	- TC register: bit 15 = enable, bit 14 = 8K page size (else 4K)
	- SRP (supervisor root pointer, 32-bit)
	- URP (user root pointer, 32-bit)
	- ITT0/ITT1 (instruction transparent translation)
	- DTT0/DTT1 (data transparent translation)

	Page table: 3-level
	  Root table: 128 entries × 4 bytes (VA bits 31-25)
	  Pointer table: 128 entries × 4 bytes (VA bits 24-18)
	  Page table: 32 entries × 4 bytes for 8K pages (VA bits 17-13)
	              64 entries × 4 bytes for 4K pages (VA bits 17-12)

	Descriptor types (bits 1-0):
	  00 = invalid
	  01 = page descriptor (resident)
	  10 = indirect (pointer to another descriptor)
	  11 = page descriptor (resident, used+modified)
*/

/* Check if a 68040 TT register matches the address.
 * S-field (bits 14-13) per Previous emulator / UAE interpretation:
 *   bit 14 = 1: S-field filtering DISABLED → match both super and user
 *   bit 14 = 0, bit 13 = 1: match supervisor only
 *   bit 14 = 0, bit 13 = 0: match user only */
static int tt040_match(uint tt, uint addr, int supervisor)
{
	if (!(tt & 0x8000))		/* bit 15: E (enable) */
		return 0;

	/* S-field check (matches Previous/UAE cpummu.c logic) */
	if (!(tt & (1 << 14))) {		/* bit 14 = 0: filtering active */
		int s_super = (tt >> 13) & 1;	/* bit 13: 1=super, 0=user */
		if (s_super != (supervisor ? 1 : 0))
			return 0;		/* mode mismatch */
	}
	/* bit 14 = 1: filtering disabled, match both modes */

	/* Address match: upper 8 bits of address must match base, masked */
	uint lbase = (tt >> 24) & 0xFF;
	uint lmask = (tt >> 16) & 0xFF;
	uint abase = (addr >> 24) & 0xFF;

	if ((abase & ~lmask) != (lbase & ~lmask))
		return 0;

	return 1;	/* match — use physical = logical (transparent) */
}

static int mmu040_log_count = 0;

/* ATC fault signalling — set by pmmu_walk_040 on invalid page table entry.
 * The caller generates a 68040 access fault exception (format 7). */
static int mmu040_atc_fault = 0;
static uint32_t mmu040_fault_addr = 0;

/* Walk result info — set by pmmu_walk_040 for TLB fill */
static uint mmu040_walk_wp = 0;        /* accumulated write-protect */
static uint mmu040_walk_modified = 0;  /* M bit was set (write allowed) */

/* Global ATC fault counter — queryable from debug key handler.
 * mmu040_fault_reset_at records the count at last BUSRST so we can
 * report "faults since kernel init" separately from boot faults.
 * Defined in m68kcpu.c, used by m68kmmu.h (included from m68kcpu.c)
 * and extern'd from main.c / next_esp.c. */
extern int mmu040_fault_total;
extern int mmu040_fault_reset_at;

/* ------------------------------------------------------------------ */
/* TLB — caches page translations to avoid page table walks            */
/* ------------------------------------------------------------------ */

/* Full-page TLB: caches final VA→PA translation.
 * Direct-mapped, indexed by virtual page number bits.
 * Entries include supervisor bit in tag to separate S/U spaces. */
#define PAGE_TLB_BITS  8
#define PAGE_TLB_SIZE  (1 << PAGE_TLB_BITS)  /* 256 entries */

static struct {
	uint32_t tag;    /* (supervisor << 31) | virtual_page_number */
	uint32_t phys;   /* physical page base address */
	uint8_t  valid;
	uint8_t  wp;     /* write-protect (accumulated from all levels) */
	uint8_t  modified; /* M bit set in descriptor (write allowed) */
} page_tlb[PAGE_TLB_SIZE];

void tlb040_flush(void)
{
	for (int i = 0; i < PAGE_TLB_SIZE; i++)
		page_tlb[i].valid = 0;
}

/* 68040 page descriptor bits (MC68040 manual Section 9) */
#define DES_USED     0x08   /* bit 3: Used — set on any access */
#define DES_MODIFIED 0x10   /* bit 4: Modified — set on write */
#define DES_WP       0x04   /* bit 2: Write Protect */
#define DES_SUPER    0x80   /* bit 7: Supervisor only */

/* Full page table walk — called on TLB miss.
 * Handles indirect page descriptors (type 2), U/M bit writeback,
 * and write-protect/supervisor protection per MC68040 manual.
 * Modelled on Previous emulator's cpummu.c mmu_fill_atc_040(). */
static uint pmmu_walk_040(uint addr_in, uint root_ptr, int page_8k, int write)
{
	uint wp = 0;   /* accumulated write-protect from all levels */

	/* Level 1: Root table — bits 31-25 (7 bits, 128 entries) */
	uint l1_idx = (addr_in >> 25) & 0x7F;
	uint l1_addr = root_ptr + l1_idx * 4;
	uint l1_desc = next_phys_read_32(l1_addr);

	if ((l1_desc & 2) == 0) {  /* bit 1 must be set for valid UDT */
		static int l1_fault_log = 0;
		if (l1_fault_log < 10) {
			xil_printf("[MMU040] L1 FAULT: VA=$%08X root=$%08X idx=%d desc=$%08X\r\n",
			           addr_in, root_ptr, l1_idx, l1_desc);
			l1_fault_log++;
		}
		mmu040_atc_fault = 1;
		mmu040_fault_addr = addr_in;
		return addr_in;
	}
	wp |= l1_desc;
	if ((l1_desc & DES_USED) == 0)
		next_phys_write_32(l1_addr, l1_desc | DES_USED);

	/* Level 2: Pointer table — bits 24-18 (7 bits, 128 entries) */
	uint l2_base = l1_desc & 0xFFFFFE00;
	uint l2_idx = (addr_in >> 18) & 0x7F;
	uint l2_addr = l2_base + l2_idx * 4;
	uint l2_desc = next_phys_read_32(l2_addr);

	if ((l2_desc & 2) == 0) {
		static int l2_fault_log = 0;
		if (l2_fault_log < 10) {
			xil_printf("[MMU040] L2 FAULT: VA=$%08X l2_base=$%08X idx=%d\r\n",
			           addr_in, l2_base, l2_idx);
			l2_fault_log++;
		}
		mmu040_atc_fault = 1;
		mmu040_fault_addr = addr_in;
		return addr_in;
	}
	wp |= l2_desc;
	if ((l2_desc & DES_USED) == 0)
		next_phys_write_32(l2_addr, l2_desc | DES_USED);

	/* Level 3: Page table */
	uint l3_base, l3_idx, l3_addr, l3_desc, page_addr, page_offset;

	if (page_8k) {
		l3_base = l2_desc & 0xFFFFFF80;
		l3_idx = (addr_in >> 13) & 0x1F;
		page_offset = addr_in & 0x1FFF;
	} else {
		l3_base = l2_desc & 0xFFFFFF00;
		l3_idx = (addr_in >> 12) & 0x3F;
		page_offset = addr_in & 0xFFF;
	}
	l3_addr = l3_base + l3_idx * 4;
	l3_desc = next_phys_read_32(l3_addr);

	/* Handle indirect descriptor (type 2: bits 1-0 = 10) */
	if ((l3_desc & 3) == 2) {
		l3_addr = l3_desc & 0xFFFFFFFC;  /* follow indirect pointer */
		l3_desc = next_phys_read_32(l3_addr);
	}

	/* Check for valid page descriptor (bit 0 = 1 → resident) */
	if ((l3_desc & 1) == 0) {
		static int l3_fault_log = 0;
		if (l3_fault_log < 10) {
			xil_printf("[MMU040] L3 FAULT: VA=$%08X l3_base=$%08X idx=%d desc=$%08X\r\n",
			           addr_in, l3_base, l3_idx, l3_desc);
			l3_fault_log++;
		}
		mmu040_atc_fault = 1;
		mmu040_fault_addr = addr_in;
		return addr_in;
	}

	/* U/M bit writeback on page descriptor (matches Previous cpummu.c:534-550).
	 * Set U on all accesses. Set M on writes if not write-protected. */
	wp |= l3_desc;
	if (write) {
		if (wp & DES_WP) {
			/* Write-protected: set U, then signal ATC fault.
			 * The kernel's trap handler sees ATC+RW=0 and knows
			 * it's a write-protect violation. */
			if ((l3_desc & DES_USED) == 0) {
				l3_desc |= DES_USED;
				next_phys_write_32(l3_addr, l3_desc);
			}
			mmu040_atc_fault = 1;
			mmu040_fault_addr = addr_in;
			return addr_in;
		} else {
			/* Write allowed: set both U and M */
			if ((l3_desc & (DES_USED | DES_MODIFIED)) != (DES_USED | DES_MODIFIED)) {
				l3_desc |= DES_USED | DES_MODIFIED;
				next_phys_write_32(l3_addr, l3_desc);
			}
		}
	} else {
		/* Read: set U only */
		if ((l3_desc & DES_USED) == 0) {
			l3_desc |= DES_USED;
			next_phys_write_32(l3_addr, l3_desc);
		}
	}

	if (page_8k)
		page_addr = l3_desc & 0xFFFFE000;
	else
		page_addr = l3_desc & 0xFFFFF000;

	/* Store walk results for TLB fill */
	mmu040_walk_wp = (wp & DES_WP) ? 1 : 0;
	mmu040_walk_modified = (l3_desc & DES_MODIFIED) ? 1 : 0;

	return page_addr | page_offset;
}

uint pmmu_translate_addr_040(uint addr_in)
{
	uint tc = m68ki_cpu.mmu_040_tc;

	/* If MMU disabled, return address unchanged */
	if (!(tc & 0x8000))
		return addr_in;

	if (mmu040_log_count < 20) {
		xil_printf("[MMU040] translate $%08X TC=$%04X SRP=$%08X\n",
		           addr_in, tc, m68ki_cpu.mmu_040_srp);
		mmu040_log_count++;
		if (mmu040_log_count == 20)
			xil_printf("[MMU040] Further translation logging suppressed\n");
	}

	/* Use function code (m68ki_address_space) to determine supervisor/user,
	 * NOT the SR.  MOVES instruction accesses user space while in supervisor
	 * mode — the FC is set to user (via DFC/SFC) but SR.S remains set.
	 * On real 68040 hardware, FC pins select SRP vs URP during table walk.
	 * m68ki_address_space = FLAG_S | base_fc, where FLAG_S = SFLAG_SET = 4.
	 * Supervisor FCs (5,6) have bit 2 set; user FCs (1,2) do not. */
	int supervisor = (m68ki_address_space & SFLAG_SET) ? 1 : 0;
	int page_8k = (tc & 0x4000) ? 1 : 0;
	uint page_shift = page_8k ? 13 : 12;
	uint page_mask = (1u << page_shift) - 1;

	/* Check Transparent Translation registers first.
	 * On real 68040, ITT matches instruction fetches (FC bit 0 = 0: FC=2,6)
	 * and DTT matches data accesses (FC bit 0 = 1: FC=1,5). */
	int fc = m68ki_address_space & 7;
	int is_data = fc & 1;  /* FC=1(user data) or FC=5(super data) */
	int tt_hit = 0;
	if (is_data) {
		if (tt040_match(m68ki_cpu.mmu_040_dtt0, addr_in, supervisor))
			tt_hit = 1;
		else if (tt040_match(m68ki_cpu.mmu_040_dtt1, addr_in, supervisor))
			tt_hit = 2;
	} else {
		if (tt040_match(m68ki_cpu.mmu_040_itt0, addr_in, supervisor))
			tt_hit = 3;
		else if (tt040_match(m68ki_cpu.mmu_040_itt1, addr_in, supervisor))
			tt_hit = 4;
	}
	if (tt_hit) {
		/* Warn if TT maps to physical address outside RAM */
		if (addr_in >= 0x05000000 && addr_in < 0x08000000) {
			static int tt_oob_count = 0;
			if (tt_oob_count < 20) {
				xil_printf("[TT-OOB] %s%d VA=$%08X → PA=$%08X (outside 16MB RAM!) FC=%d PC=$%08X\r\n",
					is_data ? "DTT" : "ITT", (tt_hit <= 2) ? (tt_hit-1) : (tt_hit-3),
					addr_in, addr_in, fc, REG_PPC);
				tt_oob_count++;
			}
		}
		return addr_in;
	}

	/* TLB lookup — check cached translation first */
	uint vpn = addr_in >> page_shift;
	uint tag = (supervisor ? 0x80000000 : 0) | vpn;
	uint tlb_idx = vpn & (PAGE_TLB_SIZE - 1);

	if (page_tlb[tlb_idx].valid && page_tlb[tlb_idx].tag == tag) {
		/* TLB hit — check protection before returning.
		 * If write to WP page, or first write to unmodified page,
		 * invalidate and re-walk to update M bit / generate fault. */
		if (mmu040_write_pending && (page_tlb[tlb_idx].wp || !page_tlb[tlb_idx].modified)) {
			page_tlb[tlb_idx].valid = 0;  /* force re-walk */
		} else {
			return page_tlb[tlb_idx].phys | (addr_in & page_mask);
		}
	}

	/* TLB miss — full page table walk */
	uint root_ptr = supervisor ? m68ki_cpu.mmu_040_srp : m68ki_cpu.mmu_040_urp;
	mmu040_atc_fault = 0;
	uint result = pmmu_walk_040(addr_in, root_ptr, page_8k, mmu040_write_pending);

	/* ATC fault: page table entry was invalid.
	 * Generate a 68040 access fault exception (format 7 stack frame)
	 * so the kernel's page fault handler can populate the pmap. */
	if (mmu040_atc_fault) {
		mmu040_atc_fault = 0;

		/* Build 68040 SSW per MC68040 User Manual Table 8-4 and
		 * kernel's struct special_status_040 (reg.h):
		 *   bit 10: ATC  — ATC fault (page table entry invalid)
		 *   bit 8:  RW   — 1=read, 0=write
		 *   bits 6-5: SIZE — 00=long
		 *   bits 4-3: TT   — 00=normal transfer
		 *   bits 2-0: TM   — function code (1=user data, 5=super data, etc.)
		 * The kernel checks ATC_BIT (bit 10) to distinguish MMU faults
		 * from bus errors, and TM for the function code. */
		/* Reconstruct 68040 function code from Musashi's m68ki_address_space.
		 * Musashi stores FLAG_S(=SFLAG_SET=4) | base_fc where base_fc is 1(data) or 2(code).
		 * Real 68040 FC: user data=1, user code=2, super data=5, super code=6.
		 * Since SFLAG_SET==4 and supervisor FC bit==4, the value is already correct. */
		uint fc = m68ki_address_space & 7;
		uint ssw = 0x0400                              /* ATC=1 (bit 10) */
		         | (mmu040_write_pending ? 0 : 0x0100) /* RW: 1=read, 0=write */
		         | ((mmu040_access_size & 3) << 5)     /* SIZE bits 6-5 */
		         | fc;                                  /* TM = function code */

		static int fault_fire_log = 0;
		mmu040_fault_total++;
		int since_reset = mmu040_fault_total - mmu040_fault_reset_at;
		if (fault_fire_log < 200 || (since_reset > 0 && since_reset <= 10)) {
			xil_printf("[MMU040] ATC FAULT #%d (+%d): VA=$%08X SSW=$%04X PC=$%08X FC=%d\r\n",
			           mmu040_fault_total, since_reset, addr_in, ssw, REG_PPC, fc);
			fault_fire_log++;
		}

		/* Detect infinite fault loop (double bus fault → CPU halt).
		 * On real 68040 this halts the CPU; we stop the emulator. */
		if (mmu040_fault_total - mmu040_fault_reset_at > 500) {
			xil_printf("[MMU040] HALT: >500 ATC faults — likely double bus fault\r\n");
			m68k_end_timeslice();
			m68k_pulse_halt();
			return addr_in;
		}

		/* Restore registers to pre-instruction state */
		for (int i = 15; i >= 0; i--)
			REG_DA[i] = REG_DA_SAVE[i];

		/* Fire 68040 bus error with format 7 stack frame */
		CPU_RUN_MODE = RUN_MODE_BERR_AERR_RESET_WSF;
		uint sr = m68ki_init_exception();
		m68ki_stack_frame_0111(REG_PPC, sr, addr_in, ssw);
		m68ki_jump_vector(EXCEPTION_BUS_ERROR);
		CPU_RUN_MODE = RUN_MODE_BERR_AERR_RESET;
		USE_CYCLES(50);

		/* Abort current instruction */
		longjmp(m68ki_bus_error_jmp_buf, 1);
	}

	/* Fill TLB — only cache successful translations */
	if (result != addr_in) {
		page_tlb[tlb_idx].tag = tag;
		page_tlb[tlb_idx].phys = result & ~page_mask;
		page_tlb[tlb_idx].wp = mmu040_walk_wp;
		page_tlb[tlb_idx].modified = mmu040_walk_modified;
		page_tlb[tlb_idx].valid = 1;
	}

	return result;
}

/* Dispatch to correct MMU translation based on CPU type.
 * For 68040: use 3-level page table with TT registers.
 * NOTE: temporarily return identity for debugging boot issues. */
uint pmmu_translate_addr(uint addr_in)
{
	if (CPU_TYPE_IS_040_PLUS(CPU_TYPE))
		return pmmu_translate_addr_040(addr_in);
	return pmmu_translate_addr_030(addr_in);
}

/*

	m68881_mmu_ops: COP 0 MMU opcode handling

*/

void m68881_mmu_ops(void)
{
	uint16 modes;
	uint32 ea = m68ki_cpu.ir & 0x3f;
	uint64 temp64;

	// catch the 2 "weird" encodings up front (PBcc)
	if ((m68ki_cpu.ir & 0xffc0) == 0xf0c0)
	{
		xil_printf("680x0: unhandled PBcc\n");
		return;
	}
	else if ((m68ki_cpu.ir & 0xffc0) == 0xf080)
	{
		xil_printf("680x0: unhandled PBcc\n");
		return;
	}
	else if ((m68ki_cpu.ir & 0xFFF8) == 0xF548)
	{
		/* 68040 PTESTW (An) — direct opcode $F548-$F54F, no extension word.
		 * Bit 5 = 0 → write test. Bits 2-0 = register number. */
		int pt_regno = m68ki_cpu.ir & 7;
		uint pt_addr = REG_A[pt_regno];
		int pt_super = (REG_DFC & 4) != 0;
		int pt_page8k = (m68ki_cpu.mmu_040_tc & 0x4000) ? 1 : 0;
		uint pt_root = pt_super ? m68ki_cpu.mmu_040_srp : m68ki_cpu.mmu_040_urp;

		if (tt040_match(m68ki_cpu.mmu_040_dtt0, pt_addr, pt_super) ||
		    tt040_match(m68ki_cpu.mmu_040_dtt1, pt_addr, pt_super)) {
			m68ki_cpu.mmu_040_mmusr = (1 << 1) | (1 << 0); /* T | R */
		} else {
			mmu040_atc_fault = 0;
			uint pt_result = pmmu_walk_040(pt_addr, pt_root, pt_page8k, 1);
			if (mmu040_atc_fault) {
				mmu040_atc_fault = 0;
				m68ki_cpu.mmu_040_mmusr = 0;
			} else {
				uint mmusr = (pt_result & 0xFFFFF000) | (1 << 0); /* phys + R */
				if (mmu040_walk_wp) mmusr |= (1 << 2);
				if (mmu040_walk_modified) mmusr |= (1 << 4);
				m68ki_cpu.mmu_040_mmusr = mmusr;
			}
		}
		return;
	}
	else if ((m68ki_cpu.ir & 0xFFF8) == 0xF568)
	{
		/* 68040 PTESTR (An) — direct opcode $F568-$F56F.
		 * Bit 5 = 1 → read test. Bits 2-0 = register number. */
		int pt_regno = m68ki_cpu.ir & 7;
		uint pt_addr = REG_A[pt_regno];
		int pt_super = (REG_DFC & 4) != 0;
		int pt_page8k = (m68ki_cpu.mmu_040_tc & 0x4000) ? 1 : 0;
		uint pt_root = pt_super ? m68ki_cpu.mmu_040_srp : m68ki_cpu.mmu_040_urp;

		if (tt040_match(m68ki_cpu.mmu_040_dtt0, pt_addr, pt_super) ||
		    tt040_match(m68ki_cpu.mmu_040_dtt1, pt_addr, pt_super)) {
			m68ki_cpu.mmu_040_mmusr = (1 << 1) | (1 << 0); /* T | R */
		} else {
			mmu040_atc_fault = 0;
			uint pt_result = pmmu_walk_040(pt_addr, pt_root, pt_page8k, 0);
			if (mmu040_atc_fault) {
				mmu040_atc_fault = 0;
				m68ki_cpu.mmu_040_mmusr = 0;
			} else {
				uint mmusr = (pt_result & 0xFFFFF000) | (1 << 0);
				if (mmu040_walk_wp) mmusr |= (1 << 2);
				if (mmu040_walk_modified) mmusr |= (1 << 4);
				m68ki_cpu.mmu_040_mmusr = mmusr;
			}
		}
		return;
	}
	else	// the rest are 1111000xxxXXXXXX where xxx is the instruction family
	{
		switch ((m68ki_cpu.ir>>9) & 0x7)
		{
			case 0:
				modes = OPER_I_16();

				if ((modes & 0xfde0) == 0x2000)	// PLOAD
				{
					/* PLOAD: walk page table for effective address and
					 * preload result into TLB. Used by kernel after
					 * vm_fault/pmap_enter to avoid re-faulting on rerun.
					 * modes bit 5: 1=read, 0=write */
					int pl_write = (modes & 0x0200) ? 0 : 1;
					int pl_super = (REG_DFC & 4) != 0;
					uint tc = m68ki_cpu.mmu_040_tc;
					if (tc & 0x8000) {  /* only if MMU enabled */
						int page_8k = (tc & 0x4000) ? 1 : 0;
						uint page_shift = page_8k ? 13 : 12;
						uint page_mask = (1u << page_shift) - 1;
						uint root = pl_super ? m68ki_cpu.mmu_040_srp : m68ki_cpu.mmu_040_urp;
						uint pl_addr = MAKE_INT_32(m68ki_cpu.ir); /* EA from next word? */
						/* Actually, PLOAD uses the EA from the instruction.
						 * The EA was already computed by OPER_I_16 as modes.
						 * For 68040, PLOAD (An) uses register indirect.
						 * Re-decode: modes bits 15-13 tell us the format.
						 * Actually on 68040, PLOAD is rarely used — the kernel
						 * uses pload_read/pload_write macros that expand to
						 * PLOAD (An) with DFC set. The EA is in the original
						 * instruction word, not the extension.
						 * ir = F000, ea bits = ir & 0x3F.
						 * For register indirect (An): ea mode = 010, reg = n */
						uint ea_mode = (m68ki_cpu.ir >> 3) & 7;
						uint ea_reg = m68ki_cpu.ir & 7;
						if (ea_mode == 2) {  /* (An) */
							pl_addr = REG_A[ea_reg];
						} else {
							pl_addr = 0; /* unsupported EA mode */
						}

						mmu040_atc_fault = 0;
						uint result = pmmu_walk_040(pl_addr, root, page_8k, pl_write);
						if (!mmu040_atc_fault && result != pl_addr) {
							/* Fill TLB with the walk result */
							uint vpn = pl_addr >> page_shift;
							uint tag = (pl_super ? 0x80000000 : 0) | vpn;
							uint tlb_idx = vpn & (PAGE_TLB_SIZE - 1);
							page_tlb[tlb_idx].tag = tag;
							page_tlb[tlb_idx].phys = result & ~page_mask;
							page_tlb[tlb_idx].wp = mmu040_walk_wp;
							page_tlb[tlb_idx].modified = mmu040_walk_modified;
							page_tlb[tlb_idx].valid = 1;
						}
						mmu040_atc_fault = 0; /* don't propagate fault from PLOAD */
					}
					return;
				}
				else if ((modes & 0xe200) == 0x2000)	// PFLUSH
				{
					tlb040_flush();
					return;
				}
				else if (modes == 0xa000)	// PFLUSHR
				{
					tlb040_flush();
					return;
				}
				else if (modes == 0x2800)	// PVALID (FORMAT 1)
				{
					xil_printf("680x0: unhandled PVALID1\n");
					return;
				}
				else if ((modes & 0xfff8) == 0x2c00)	// PVALID (FORMAT 2)
				{
					xil_printf("680x0: unhandled PVALID2\n");
					return;
				}
				else if ((modes & 0xe000) == 0x8000)	// PTEST
				{
					/* PTEST: walk page table, store result in MMUSR.
					 * modes bit 5: 0=write, 1=read
					 * modes bits 2-0: register number (An) */
					int pt_write = (modes & 32) == 0;
					int pt_regno = modes & 7;
					uint pt_addr = REG_A[pt_regno];
					int pt_super = (REG_DFC & 4) != 0;
					int pt_page8k = (m68ki_cpu.mmu_040_tc & 0x4000) ? 1 : 0;
					uint pt_root = pt_super ? m68ki_cpu.mmu_040_srp : m68ki_cpu.mmu_040_urp;

					/* Check TT registers first */
					if (tt040_match(m68ki_cpu.mmu_040_dtt0, pt_addr, pt_super) ||
					    tt040_match(m68ki_cpu.mmu_040_dtt1, pt_addr, pt_super)) {
						m68ki_cpu.mmu_040_mmusr = (1 << 1) | (1 << 0); /* T | R */
					} else {
						mmu040_atc_fault = 0;
						uint pt_result = pmmu_walk_040(pt_addr, pt_root, pt_page8k, pt_write);
						if (mmu040_atc_fault) {
							mmu040_atc_fault = 0;
							m68ki_cpu.mmu_040_mmusr = 0; /* not resident */
						} else {
							uint mmusr = (pt_result & 0xFFFFF000) | (1 << 0); /* phys + R */
							if (mmu040_walk_wp) mmusr |= (1 << 2);  /* W */
							if (mmu040_walk_modified) mmusr |= (1 << 4); /* M */
							m68ki_cpu.mmu_040_mmusr = mmusr;
						}
					}
					return;
				}
				else
				{
					switch ((modes>>13) & 0x7)
					{
						case 0:	// MC68030/040 form with FD bit
						case 2:	// MC68881 form, FD never set
							if (modes & 0x200)
							{
							 	switch ((modes>>10) & 7)
								{
									case 0:	// translation control register
										WRITE_EA_32(ea, m68ki_cpu.mmu_tc);
										break;

									case 2: // supervisor root pointer
										WRITE_EA_64(ea, (uint64)m68ki_cpu.mmu_srp_limit<<32 | (uint64)m68ki_cpu.mmu_srp_aptr);
										break;

									case 3: // CPU root pointer
										WRITE_EA_64(ea, (uint64)m68ki_cpu.mmu_crp_limit<<32 | (uint64)m68ki_cpu.mmu_crp_aptr);
										break;

									default:
										xil_printf("680x0: PMOVE from unknown MMU register %x, PC %x\n", (modes>>10) & 7, REG_PC);
										break;
								}
							}
							else
							{
							 	switch ((modes>>10) & 7)
								{
									case 0:	// translation control register
										m68ki_cpu.mmu_tc = READ_EA_32(ea);

										if (m68ki_cpu.mmu_tc & 0x80000000)
										{
											m68ki_cpu.pmmu_enabled = 1;
										}
										else
										{
											m68ki_cpu.pmmu_enabled = 0;
										}
										break;

									case 2:	// supervisor root pointer
										temp64 = READ_EA_64(ea);
										m68ki_cpu.mmu_srp_limit = (temp64>>32) & 0xffffffff;
										m68ki_cpu.mmu_srp_aptr = temp64 & 0xffffffff;
										break;

									case 3:	// CPU root pointer
										temp64 = READ_EA_64(ea);
										m68ki_cpu.mmu_crp_limit = (temp64>>32) & 0xffffffff;
										m68ki_cpu.mmu_crp_aptr = temp64 & 0xffffffff;
										break;

									default:
										xil_printf("680x0: PMOVE to unknown MMU register %x, PC %x\n", (modes>>10) & 7, REG_PC);
										break;
								}
							}
							break;

						case 3:	// MC68030 to/from status reg
							if (modes & 0x200)
							{
								WRITE_EA_32(ea, m68ki_cpu.mmu_sr);
							}
							else
							{
								m68ki_cpu.mmu_sr = READ_EA_32(ea);
							}
							break;

						default:
							xil_printf("680x0: unknown PMOVE mode %x (modes %04x) (PC %x)\n", (modes>>13) & 0x7, modes, REG_PC);
							break;
					}
				}
				break;

			default:
				xil_printf("680x0: unknown PMMU instruction group %d\n", (m68ki_cpu.ir>>9) & 0x7);
				break;
		}
	}
}

void mmu040_dump_regs(void)
{
	xil_printf("[DUMP] SRP=$%08X URP=$%08X TC=$%04X\r\n",
		m68ki_cpu.mmu_040_srp, m68ki_cpu.mmu_040_urp,
		m68ki_cpu.mmu_040_tc);
	xil_printf("[DUMP] ITT0=$%08X ITT1=$%08X DTT0=$%08X DTT1=$%08X\r\n",
		m68ki_cpu.mmu_040_itt0, m68ki_cpu.mmu_040_itt1,
		m68ki_cpu.mmu_040_dtt0, m68ki_cpu.mmu_040_dtt1);
}

/* Translate a user-mode virtual address through URP page tables.
 * This does a manual 3-level walk, independent of current CPU state. */
uint mmu040_translate_user(uint va)
{
	uint tc = m68ki_cpu.mmu_040_tc;
	if (!(tc & 0x8000)) return va;  /* MMU disabled */

	uint urp = m68ki_cpu.mmu_040_urp;
	int page_8k = (tc & 0x4000) ? 1 : 0;
	uint page_shift = page_8k ? 13 : 12;
	uint page_mask = (1u << page_shift) - 1;

	/* 3-level walk: 7-bit L1, 7-bit L2, 5/6-bit L3 */
	int l1_shift = page_8k ? 25 : 25;  /* bits 31-25 */
	int l2_shift = page_8k ? 18 : 18;  /* bits 24-18 */
	int l3_shift = page_shift;          /* bits 17-12 or 17-13 */

	uint l1_idx = (va >> l1_shift) & 0x7F;
	uint l1_desc = next_phys_read_32(urp + l1_idx * 4);
	if (!(l1_desc & 0x2)) return va;  /* invalid */

	uint l2_base = l1_desc & 0xFFFFFE00;
	uint l2_idx = (va >> l2_shift) & 0x7F;
	uint l2_desc = next_phys_read_32(l2_base + l2_idx * 4);
	if (!(l2_desc & 0x2)) return va;  /* invalid */

	uint l3_base = l2_desc & 0xFFFFFE00;
	uint l3_bits = page_8k ? 5 : 6;
	uint l3_idx = (va >> l3_shift) & ((1 << l3_bits) - 1);
	uint l3_desc = next_phys_read_32(l3_base + l3_idx * 4);
	if (!(l3_desc & 0x1)) return va;  /* invalid (page descriptor uses bit 0) */

	uint phys_base = l3_desc & ~page_mask;
	return phys_base | (va & page_mask);
}

