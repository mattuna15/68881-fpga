# The team and history behind Motorola's MC68881 floating-point coprocessor

The MC68881, Motorola's landmark floating-point coprocessor, was architecturally led by **Joel F. Boney** from Motorola's Austin, Texas facility and became one of the earliest fully IEEE 754-compliant chips when introduced in 1984 — roughly three years ahead of Intel's equivalent 80387. This investigation confirms most claims in the source document while surfacing important corrections, newly identified team members from patent records, and a rich oral history archive that fills significant gaps in the public record.

---

## Joel Boney: from 6809 co-architect to IEEE 754 pioneer

**Joel F. Boney** (April 21, 1947 – October 12, 2010) is confirmed as the lead architect of the MC68881 project. Born in Marietta, Ohio, he held a BSE from the University of South Florida and worked at Motorola's facility at **3501 Ed Bluestein Blvd., Austin, TX 78721**. His career trajectory at Motorola traced a clear path toward the MC68881: software architect for the 6800 family, co-architect of the M6809 processor (with Terry Ritter, 1978), co-author of the MC6839 Floating Point ROM for the 6809 (with Greg Stevens and G. Walker, circa 1980), and then principal architect of the MC68881.

William Kahan's account on his IEEE 754 historical page confirms Boney's central role directly. At the second IEEE p754 committee meeting in November 1977, **"Motorola was represented by Joel Boney who then led their project in Austin, Texas, to build what later (1984) became the MC68881/2 coprocessors. These were beautiful jobs."** This establishes that Boney was Motorola's representative on the IEEE 754 standards committee from its earliest days, and that his participation directly informed the MC68881's design philosophy. Boney's attendance at the p754 meetings — alongside representatives from National Semiconductor, Zilog, and Intel — places him among the small group of industry engineers who shaped the standard before it was finalized in 1985.

Boney passed away on October 12, 2010, in Fort Collins, Colorado, after a decade-long battle with Alzheimer's disease. His obituary was published in the *Austin American-Statesman*, and he was survived by his wife Gloria Ackley (married 24 years) and daughters Robin and Gena Boney.

---

## The MC68881 team was larger than the public record suggests

The source document's claim that three people — Boney, Huntsman, and Cawthron — are the primary known figures is confirmed, but patent filings and conference proceedings reveal a substantially larger team.

**The 1983 IEEE Micro article** requires an important correction: it was authored by **Clayton Huntsman and Duane Cawthron only**. Joel Boney is *not* a co-author. The full citation is: Clayton Huntsman and Duane Cawthron, "The MC68881 Floating-point Coprocessor," *IEEE Micro*, Vol. 3, No. 6 (December 1983), pp. 44–54. Boney's MC68881 paper is a separate publication — his sole-authored "Goals and tradeoffs in the design of the MC68881 floating point coprocessor," presented at the **AFIPS National Computer Conference 1984** (July 9–12, Las Vegas), proceedings pp. 107–113 (DOI: 10.1145/1499310.1499325).

**US Patent 4,777,613** ("Floating point numeric data processor"), filed April 1, 1986 and published October 11, 1988, names four inventors on the MC68881's execution unit: **Van B. Shahan, Paul E. Harvey, Clayton D. Huntsman, and Ashok H. Someshway**. A later assignment (November 25, 1988) added **Stanley Groves** and **Kirk Holden**. This patent describes the micromachine architecture, PLA-based microsequencing, barrel shifter, and arithmetic pipeline that formed the heart of the MC68881.

A companion set of **coprocessor interface patents** (filed April 18, 1983) reveals the engineers who designed the MC68020–MC68881 communication protocol: **John Zolnowsky, David Mothersole, and Douglas B. MacGregor** were the primary inventors, with **Michael Cruess, Donald L. Tietjen, Van B. Shahan, and Stanley E. Groves** contributing to specific aspects of interrupt handling and address evaluation. These seven patents (originally Ser. No. 485,671 through 485,814) covered the complete F-line coprocessor instruction format and coordination mechanism.

Additionally, **R.J. Simcoe et al.** published "A Floating Point Unit for a 32-bit Microprocessor System" at the **IEEE 1984 Custom Integrated Circuits Conference** (pp. 478–481), another paper from the MC68881 hardware team.

At the management level, **Tom Gunter** (BS EE, Texas A&M) served as team lead for the entire 68000 family from 1975 into the early 1990s and had oversight of every family member, including the MC68881. **Gary Daniels** headed the design group. The **Computer History Museum** recorded a full oral history panel on July 23, 2007 in Austin, featuring Gunter, **Van Shahan**, **Jack Browne** (marketing manager), **Murray Goldman** (operations VP), and **Bill Walker** (manufacturing), which contains first-hand accounts of the MC68881 development and production challenges.

The complete identified team roster:

- **Joel F. Boney** — instruction set architect and project lead
- **Clayton D. Huntsman** — hardware designer (IEEE Micro author, patent inventor)
- **Duane Cawthron** — hardware designer (IEEE Micro co-author)
- **Van B. Shahan** — execution unit designer (patent inventor, CHM oral history participant)
- **Paul E. Harvey** — execution unit designer (patent inventor)
- **Ashok H. Someshway** — execution unit designer (patent inventor)
- **Stanley Groves** — coprocessor interface and interrupt handling (patent contributor)
- **Kirk Holden** — contributor (patent assignment)
- **R.J. Simcoe** — hardware engineer (CICC 1984 paper author)
- **John Zolnowsky, David Mothersole, Douglas B. MacGregor** — coprocessor interface architects
- **Michael Cruess, Donald L. Tietjen** — coprocessor interface contributors
- **Tom Gunter** — 68000 family program manager
- **Gary Daniels** — design group head

---

## Timeline: roughly four years from spec to silicon, confirmed

The "approximately four years" claim is plausible but cannot be pinned to exact dates from primary sources. The evidence brackets the development window as follows:

Boney attended IEEE p754 meetings starting in late 1977, and the MC6839 Floating Point ROM (a software precursor) was developed around 1980. Customer canvassing for a hardware FPU occurred in the early 1980s alongside MC68020 development — 68000 customers, especially those building Unix workstations, "all stated they would purchase a floating-point unit for every one of the machines if one was available." A project start of **circa 1980–1981** is consistent with all available evidence.

The December 1983 IEEE Micro article by Huntsman and Cawthron describes the completed design, implying **first silicon by late 1983 at the latest**. The MC68020 design was completed in summer 1983 and announced in June 1984; the MC68881 was announced around the same time. However, severe production problems at Motorola's MOS-8 factory meant yields were initially zero. The oral history records that Bill Walker was brought in to fix the factory in July 1985, and **volume deliveries began in late 1985**. By that point, workstation customers (HP, Apollo, Sun) "had already developed complete systems ready to use the 020 and the new floating point unit."

If the project began around 1980 and first silicon arrived in 1983, the "four years" claim holds. The gap between first silicon (1983) and volume production (late 1985) was approximately two additional years of manufacturing ramp-up.

---

## AN947 confirmed: peripheral mode thoroughly documented

**Motorola Application Note AN947/D** exists and is archived. Its full title is "MC68881 Floating-Point Coprocessor as a Peripheral in an M68000 System," published in 1987, spanning 37 pages. The document is available on bitsavers.org and covers exactly what the source document claims: using the MC68881 as a memory-mapped peripheral with MC68000, MC68008, and MC68010 systems that lack the MC68020's native coprocessor interface.

The application note describes two software approaches — F-line instruction trap emulation and inline code using subroutine calls or macros — along with detailed hardware connection diagrams for chip select decode, address line routing, and DSACK/DTACK signal handling. It emphasizes that object code containing MC68881 instructions written for the peripheral configuration is upward-compatible with MC68020 systems using the native coprocessor interface.

Notable products that actually used peripheral mode include the **Atari SFP004** (Atari's official MC68881 add-on board for the 68000-based Atari ST, 1988), the **ICD AdSpeed ST** accelerator, and the **CMI PAMC-500** board. Various third-party Amiga accelerator boards also employed peripheral-mode operation with the original 68000 CPU.

---

## How the MC68881 stacked up against its competitors

The MC68881 entered a competitive landscape where **no existing coprocessor fully implemented IEEE 754-1985**. The Intel **8087** (1980, ~40,000 transistors) was the *basis* for the standard but deviated from the final specification — it supported projective closure (later dropped), had limited trigonometric argument ranges, and lacked direct sine/cosine instructions. The **80287** (1982) reused the 8087's execution unit with the same limitations. Intel did not achieve full IEEE 754 compliance until the **80387 in 1987**, three years after the MC68881.

The National Semiconductor **NS32081** (~1982) for the NS32000 family offered only partial compliance — it used IEEE 754 formats but implemented only basic arithmetic in hardware, relying on software for the remainder of the standard. Interestingly, before the MC68881 existed, HP used the NS32081 as a peripheral FPU with the MC68010 in its HP 9000 systems (the HP 98635A accelerator board).

**Weitek's** approach was fundamentally different. Their WTL 1164/1165 chip pair (circa 1986) and later WTL 3167 "Abacus" (1988) were memory-mapped devices offering raw speed but sacrificing IEEE 754 features — no extended precision, no denormal support, no built-in transcendentals, and requiring special compiler support. Sun Microsystems used Weitek 1164/1165 chips in its Sun-3 Floating Point Accelerator board *alongside* an MC68881 on the CPU board, falling back to the 68881 for IEEE 754 edge cases and exceptions.

The MC68881's **155,000 transistors** delivered eight 80-bit registers (not stack-based like x87), **seven data formats** including packed BCD, a full set of transcendental functions, and all four IEEE 754 rounding modes with gradual underflow and proper NaN/infinity handling. Kahan noted that "microcoded implementations like the i8087 and MC68881/2 had nothing to lose" regarding gradual underflow — both were microcoded designs that could support the feature without hardware penalty.

---

## The MC68882: evolutionary upgrade with real-world caveats

The MC68882 appeared around **1987–1988** (the 1st edition of the combined MC68881/MC68882 User's Manual is dated 1987; the MC68882 Technical Summary is rev. 3, 1988). It was an evolutionary upgrade — **pin-compatible and software-compatible** with the MC68881, using an identical instruction set across **176,000 transistors** (versus 155,000).

Key improvements included an optimized bus interface with better pipelining, a **67-bit barrel shifter** for high-speed shifting, and special-purpose hardware for faster binary-to-real conversions. Motorola claimed performance exceeding **1.5× the MC68881** at the same clock speed, with some instructions up to 40% faster — though typical real-world gains were more modest. The MC68882 eventually reached **50 MHz** (versus 25 MHz maximum for the MC68881), delivering roughly **528 kFLOPS** at top speed.

The most significant compatibility issue was the MC68882's **larger FSAVE state frame**, which required operating system modifications for preemptive multitasking. Unix systems and other OSes that context-switched floating-point state had to allocate additional memory for the larger frame, making the 68882 not a completely transparent drop-in replacement at the OS level.

---

## Filling the gaps: where to look next

The **Computer History Museum oral history** (reference X4145.2008, recorded July 23, 2007 in Austin at Freescale Semiconductor) is the single most valuable unexploited source. The 54-page transcript includes first-hand accounts from Van Shahan and Tom Gunter, who were directly involved in the MC68881 project. The full PDF is archived at computerhistory.org.

An FPGA reimplementation of the MC68881 in VHDL-2008 exists on GitHub (github.com/mattuna15/68881-fpga), and its creator noted that "building it has shown me just what the Motorola engineers did all those years ago" — suggesting the implementation process itself revealed design insights not documented elsewhere.

Terry Ritter, Boney's 6809 co-architect, left Motorola and became a cryptography researcher. His personal website (ciphersbyritter.com) includes a complete CV with his Motorola career history, which may contain additional context about the Austin facility's culture and working relationships during the MC68881 era. No direct evidence links Ritter to the MC68881 project specifically, but his close partnership with Boney and continued presence in Austin make him a potential source of undocumented institutional knowledge.