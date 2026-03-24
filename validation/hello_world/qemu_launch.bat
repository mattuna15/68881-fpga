@echo off
REM Launch the Merlin 2 emulator under QEMU (ZynqMP ZCU102 model)
REM
REM PREREQUISITES:
REM   1. In Vitis, edit src/UserConfig.cmake and set:
REM        set(USER_COMPILE_DEFINITIONS "QEMU_MODE")
REM   2. Rebuild the project (this skips DP and FPU init)
REM   3. Run this script from the hello_world directory
REM
REM The bare-metal ELF runs on QEMU's emulated Cortex-A53.
REM UART0 output appears on the console.
REM Note: FPGA PL (FPU core) is not present - FPU operations will fail.
REM Use this for testing BIOS boot, RTC, Timer C, and serial I/O.
REM
REM Press Ctrl-A then X to exit QEMU.

set QEMU=C:\amddesigntools\2025.2\data\emulation\qemu\comp\qemu_win\qemu-system-aarch64.exe
set ELF=build\hello_world.elf

if not exist "%ELF%" (
    echo ERROR: %ELF% not found. Build the project in Vitis first.
    exit /b 1
)

echo ============================================================
echo  Merlin 2 Emulator under QEMU (ZynqMP ZCU102)
echo  ELF: %ELF%
echo  Exit: Ctrl-A then X
echo ============================================================
echo.

"%QEMU%" ^
  -M xlnx-zcu102 ^
  -nographic ^
  -device loader,file=%ELF%,cpu-num=0 ^
  -device loader,addr=0xFD1A0104,data=0x8000000e,data-len=4
