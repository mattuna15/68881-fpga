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
} page_tlb[PAGE_TLB_SIZE];

void tlb040_flush(void)
{
	for (int i = 0; i < PAGE_TLB_SIZE; i++)
		page_tlb[i].valid = 0;
}

/* Full page table walk — called on TLB miss */
/* Full page table walk — called on TLB miss.
 * Handles indirect page descriptors (type 2) per 68040 manual.
 * NOTE: WP/S protection checks and U/M bit writeback are NOT implemented
 * yet — they cause regressions because our ATC fault SSW doesn't properly
 * distinguish protection faults from invalid-page faults, and U/M writes
 * to descriptor memory corrupt early-boot page tables. These features
 * require proper SSW encoding (write bit, TM field) before enabling. */
static uint pmmu_walk_040(uint addr_in, uint root_ptr, int page_8k)
{
	/* Level 1: Root table — bits 31-25 (7 bits, 128 entries) */
	uint l1_idx = (addr_in >> 25) & 0x7F;
	uint l1_desc = next_phys_read_32(root_ptr + l1_idx * 4);

	if ((l1_desc & 3) == 0) {
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

	/* Level 2: Pointer table — bits 24-18 (7 bits, 128 entries) */
	uint l2_base = l1_desc & 0xFFFFFE00;
	uint l2_idx = (addr_in >> 18) & 0x7F;
	uint l2_desc = next_phys_read_32(l2_base + l2_idx * 4);

	if ((l2_desc & 3) == 0) {
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

	/* Level 3: Page table */
	uint l3_base, l3_idx, l3_desc, page_addr, page_offset;

	if (page_8k) {
		l3_base = l2_desc & 0xFFFFFF80;
		l3_idx = (addr_in >> 13) & 0x1F;
		l3_desc = next_phys_read_32(l3_base + l3_idx * 4);
		page_offset = addr_in & 0x1FFF;
	} else {
		l3_base = l2_desc & 0xFFFFFF00;
		l3_idx = (addr_in >> 12) & 0x3F;
		l3_desc = next_phys_read_32(l3_base + l3_idx * 4);
		page_offset = addr_in & 0xFFF;
	}

	if ((l3_desc & 3) == 0) {
		static int l3_fault_log = 0;
		if (l3_fault_log < 10) {
			xil_printf("[MMU040] L3 FAULT: VA=$%08X l3_base=$%08X idx=%d\r\n",
			           addr_in, l3_base, l3_idx);
			l3_fault_log++;
		}
		mmu040_atc_fault = 1;
		mmu040_fault_addr = addr_in;
		return addr_in;
	}

	if (page_8k)
		page_addr = l3_desc & 0xFFFFE000;
	else
		page_addr = l3_desc & 0xFFFFF000;

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

	int supervisor = (m68ki_get_sr() & 0x2000) ? 1 : 0;
	int page_8k = (tc & 0x4000) ? 1 : 0;
	uint page_shift = page_8k ? 13 : 12;
	uint page_mask = (1u << page_shift) - 1;

	/* Check Transparent Translation registers first */
	if (tt040_match(m68ki_cpu.mmu_040_dtt0, addr_in, supervisor))
		return addr_in;
	if (tt040_match(m68ki_cpu.mmu_040_dtt1, addr_in, supervisor))
		return addr_in;
	if (tt040_match(m68ki_cpu.mmu_040_itt0, addr_in, supervisor))
		return addr_in;
	if (tt040_match(m68ki_cpu.mmu_040_itt1, addr_in, supervisor))
		return addr_in;

	/* TLB lookup — check cached translation first */
	uint vpn = addr_in >> page_shift;
	uint tag = (supervisor ? 0x80000000 : 0) | vpn;
	uint tlb_idx = vpn & (PAGE_TLB_SIZE - 1);

	if (page_tlb[tlb_idx].valid && page_tlb[tlb_idx].tag == tag) {
		/* TLB hit — only successful translations are cached */
		return page_tlb[tlb_idx].phys | (addr_in & page_mask);
	}

	/* TLB miss — full page table walk */
	uint root_ptr = supervisor ? m68ki_cpu.mmu_040_srp : m68ki_cpu.mmu_040_urp;
	mmu040_atc_fault = 0;
	uint result = pmmu_walk_040(addr_in, root_ptr, page_8k);

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
		 * Musashi stores FLAG_S(0x2000) | base_fc where base_fc is 1(data) or 2(code).
		 * Real 68040 FC: user data=1, user code=2, super data=5, super code=6. */
		uint raw_fc = m68ki_address_space;
		uint fc = (raw_fc & 3) | ((raw_fc & 0x2000) ? 4 : 0);
		uint ssw = 0x0400    /* ATC=1 (bit 10) */
		         | 0x0100    /* RW=1 (read — TODO: detect writes) */
		         | fc;       /* TM = function code (bits 2-0) */

		static int fault_fire_log = 0;
		static int fault_total = 0;
		if (fault_fire_log < 20) {
			xil_printf("[MMU040] ATC FAULT: VA=$%08X SSW=$%04X PC=$%08X\r\n",
			           addr_in, ssw, REG_PPC);
			fault_fire_log++;
		}

		/* Detect infinite fault loop (double bus fault → CPU halt).
		 * On real 68040 this halts the CPU; we stop the emulator. */
		fault_total++;
		if (fault_total > 500) {
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
	else	// the rest are 1111000xxxXXXXXX where xxx is the instruction family
	{
		switch ((m68ki_cpu.ir>>9) & 0x7)
		{
			case 0:
				modes = OPER_I_16();

				if ((modes & 0xfde0) == 0x2000)	// PLOAD
				{
					xil_printf("680x0: unhandled PLOAD\n");
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
					xil_printf("680x0: unhandled PTEST\n");
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

