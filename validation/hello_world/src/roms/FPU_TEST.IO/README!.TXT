
MC68881 Test Utilities

(c) 1991 Quidnunc Software. All Rights Reserved.

YOU MAY USE, COPY, AND FREELY DISTRIBUTE THESE PROGRAMS.  JUST KEEP
ALL THREE FILES TOGETHER AND DON'T CHARGE ANYTHING FOR THEM.

These two programs perform a simple test to determine if a MC68881
FPU (Math Coprocessor) chip exists, and if so, if it is working.

These programs have only been tested on the MC68881 mapped into 
memory as a peripheral device (e.g. installed on the ICD AdSpeedST
board or on the Atari SFP004 Floating Point Coprocessor board).

To use the utilities:

Both programs perform floating point calculations for ten seconds
and then display a "speed factor" which is proportional to the number
of calculations performed.

First, run FPU_SOFT.PRG.  This program does NOT use the MC68881
regardless of whether it's installed or not.  Make a note of the
reported speed factor.

Now, run FPU_HARD.PRG.  This program WILL use the MC68881 if it is
installed.  Compare the resulting speed factor to that obtained for
FPU_SOFT.PRG:

*  If the two numbers are about the same, you either do not have the
   FPU installed or it is not being recognized.

*  If the "Hard" number is significantly larger than the "Soft" 
   number, the FPU is installed and recognized.

The ratio of the two numbers is an indicator of the speed "benefit."  This
ratio should NOT be used as an overall indicator of the FPU benefit, since
the actual benefit will depend on the efficiency of the software floating
point operations being replaced by the FPU hardware operations and the
actual operations themselves (FYI, these utilities use the sine trigonometric
function).

For your reference, the values we obtained for various configurations
were:

System: 1040STe 4MB with ICD ADSpeed STe.
        MC68881 FPU with 16 MHz oscillator.

                    Speed Factor
                   --------------
        CPU Speed   Soft    Hard
        ---------  ------  ------
          8 MHz      100     646
         16 MHz      186    1053

The hard and soft values obtained for a 520ST/1MB with no ADSpeedST
board installed (and no FPU) were both about 100 (as you would expect).

We'd be curious to know what the results are for a MC68881 FPU with
an 8 MHz oscillator...
