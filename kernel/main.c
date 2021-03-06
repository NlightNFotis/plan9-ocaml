#include <u.h>
#include "port/lib.h"
#include "port/error.h"
#include "mem.h"
#include "dat.h"
#include "fns.h"

// for mainmem and imagmem used in confinit
#include <pool.h>

// spl.s
void arm_arch_coherence(void);
// devcons.c
int devcons_print(char *fmt, ...);
int devcons_iprint(char *fmt, ...);
void devcons_panic(char *fmt, ...);
// clock.c
uvlong clock_arch_fastticks(uvlong *hz);

extern void test(void); // test.c

//*****************************************************************************
// Cpu init
//*****************************************************************************
void
arch__cpuinit(void)
{
    Cpu *cpu0;

    cpu->ticks = 1;
    cpu->perf.period = 1;

    cpu0 = CPUS(0);
    if (cpu->cpuno != 0) {
        /* synchronise with cpu 0 */
        cpu->ticks = cpu0->ticks;
        cpu->fastclock = cpu0->fastclock;
    }
}

void
arch__cpu0init(void)
{
    conf.ncpu = 0; // set in machon() instead (machon() is called after cpuinit)

    cpu->cpuno = 0;
    cpus[cpu->cpuno] = cpu;

    arch__cpuinit();
    //active.exiting = 0;

    up = nil; //todo: still need? done in ocaml context
}

//*****************************************************************************
// Conf init
//*****************************************************************************

// used also in mmu.c
ulong   memsize = 128*1024*1024;

void
arch__confinit(void)
{
    int i;
    phys_addr pa;
    ulong kpages;
    ulong kmem;

    // simpler than for x86 :)
    getramsize(&conf.mem[0]);

    if(conf.mem[0].limit == 0){
        conf.mem[0].base = 0;
        conf.mem[0].limit = memsize;
    }

    conf.npage = 0;
    pa = PADDR(PGROUND(PTR2UINT(end)));

    /*
     *  we assume that the kernel is at the beginning of one of the
     *  contiguous chunks of memory and fits therein.
     */
    for(i=0; i<nelem(conf.mem); i++){
        /* take kernel out of allocatable space */
        if(pa > conf.mem[i].base && pa < conf.mem[i].limit)
            conf.mem[i].base = pa;

        conf.mem[i].npage = (conf.mem[i].limit - conf.mem[i].base)/BY2PG;
        conf.npage += conf.mem[i].npage;
    }

    conf.upages = (conf.npage*80)/100;
    kpages = conf.npage - conf.upages;

    /* set up other configuration parameters */
    conf.ialloc = (kpages/2)*BY2PG; // max bytes for iallocb

    conf.nproc = 100 + ((conf.npage*BY2PG)/MB)*5;
    if(conf.nproc > 2000)
        conf.nproc = 2000;

    conf.nswap = conf.npage*3;
    conf.nswppo = 4096;
    conf.nimage = 200;

    conf.copymode = 1;      /* copy on reference, not copy on write */

    /*
     * Guess how much is taken by the large permanent
     * datastructures. Mntcache and Mntrpc are not accounted for
     * (probably ~300KB).
     */
    kmem = kpages * BY2PG;
    kmem -= 
          conf.upages*sizeof(Page)
        + conf.nproc*sizeof(Proc)
        + conf.nimage*sizeof(KImage)
        + conf.nswap
        + conf.nswppo*sizeof(Page*); // pad's second bugfix :)

    // memory pool
    mainmem->maxsize = kmem;

    /*
     * give terminals lots of image memory, too; the dynamic
     * allocation will balance the load properly, hopefully.
     * be careful with 32-bit overflow.
     */
    imagmem->maxsize = kmem;
}

//*****************************************************************************
// Main entry point!
//*****************************************************************************

extern void caml_startup(char **argv);

char* empty_argv[] = { 0 };

void
main(void)
{
    // backward deps
    arch_coherence = arm_arch_coherence;
    print = devcons_print;
    iprint = devcons_iprint;
    panic = devcons_panic;
    arch_fastticks = clock_arch_fastticks;

    memset(edata, 0, end - edata);  /* clear bss */

    // Let's go!

    cpu = (Cpu*)CPUADDR;
    arch__cpu0init(); // cpu0 initialization (calls arch__cpuinit())
    mmuinit1((void*)L1); // finish mmu initialization started in mmuinit0
    //less: machon(0);

    // less: optionsinit, ataginit
    arch__confinit();     /* figures out amount of memory */
    xinit(); // less: can we get rid of xalloc? just have malloc?
 
    // less: uartconsinit

    arch__screeninit(); // screenputs = swconsole_screenputs
    
    quotefmtinstall(); // libc printf initialization
    print("\nPlan 9 from Bell Labs\n"); // yeah!

    // less: firmware printing 
    // less: setclkrate
    
    arch__trapinit();
    clockinit();
    timersinit();

    // where this is done in the original code? 
    // when go to userspace of init process?
    arch_spllo(); 
    
    // byterun/scheduler.c uses floats so we need to enable the VFP coprocessor
    fpinit();

    //test();

    // Jump to OCaml!
    caml_startup(empty_argv); // no arguments for now

    print("Done!"); // yeah!

    for(;;) ;

    assert(0);          /* shouldn't have returned */
}

