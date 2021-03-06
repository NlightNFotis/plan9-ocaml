/*
 * armv6/v7 machine assist, definitions
 *
 * loader uses R11 as scratch.
 */

#define PADDR(va)   (((va) & ~KSEGM))
#define L1X(va)     (((((va))>>20) & 0x0fff)<<2)


#define CpCACHEinvi 5           /* instruction, branch table */
#define CpCACHEwait 4           /* wait (prefetch flush on cortex) */
#define CpCACHEwb   10          /* writeback to PoC */

/*
 * new instructions
 */
// simplified caching and coherence for now: No cache!
#define ISB \
    MOVW    $0, R0; \
    MCR CpSC, 0, R0, C(CpCACHE), C(CpCACHEinvi), CpCACHEwait
#define DSB \
    MOVW    $0, R0; \
    MCR CpSC, 0, R0, C(CpCACHE), C(CpCACHEwb), CpCACHEwait
#define BARRIERS    ISB; DSB

#define LDREX(fp,t)   WORD $(0xe<<28|0x01900f9f | (fp)<<16 | (t)<<12)
/* `The order of operands is from left to right in dataflow order' - asm man */
#define STREX(f,tp,r) WORD $(0xe<<28|0x01800f90 | (tp)<<16 | (r)<<12 | (f)<<0)
#define CLREX   WORD    $0xf57ff01f

#define CPSID   WORD    $0xf10c0080 /* intr disable: sets I bit */

/*
 * get cpu id, or zero if armv6
 */
#define CPUID(r) \
    MRC CpSC, 0, r, C(CpID), C(CpIDfeat), 7; \
    CMP $0, r; \
    B.EQ    2(PC); \
    MRC CpSC, 0, r, C(CpID), C(CpIDidct), CpIDmpid; \
    AND.S   $(MAXCPUS-1), r
