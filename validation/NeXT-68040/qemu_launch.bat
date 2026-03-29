@echo off
REM Launch the NeXT 68040LC emulator under QEMU (ZynqMP ZCU102 model)
REM
REM PREREQUISITES:
REM   1. In Vitis, edit src/UserConfig.cmake and change:
REM        set(USER_COMPILE_DEFINITIONS "SDT")
REM      to:
REM        set(USER_COMPILE_DEFINITIONS "SDT" "QEMU_MODE")
REM   2. Rebuild the project (this skips DP and FPU hardware init)
REM   3. Run this script from the NeXT-68040 directory
REM
REM The bare-metal ELF runs on QEMU's emulated Cortex-A53.
REM Musashi emulates the 68LC040 internally.
REM UART0 output appears on the console (SCC TX → xil_printf → QEMU UART).
REM
REM Note: FPGA PL (MC68882 FPU core) is not present under QEMU.
REM FPU F-line instructions will fail. Use this for testing:
REM   - NeXT device stubs (SCR1, SCC, timer, interrupts)
REM   - Memory map and kernel loading
REM   - Serial console output path
REM
REM Press Ctrl-A then X to exit QEMU.

set QEMU=C:\amddesigntools\2025.2\data\emulation\qemu\comp\qemu_win\qemu-system-aarch64.exe
set ELF=build\NeXT-68040.elf

if not exist "%ELF%" (
    echo ERROR: %ELF% not found. Build the project in Vitis first.
    exit /b 1
)

echo ============================================================
echo  NeXT 68040LC Emulator under QEMU (ZynqMP ZCU102)
echo  ELF: %ELF%
echo  Exit: Ctrl-A then X
echo ============================================================
echo.

"%QEMU%" ^
  -M xlnx-zcu102 ^
  -nographic ^
  -device loader,file=%ELF%,cpu-num=0 ^
  -device loader,addr=0xFD1A0104,data=0x8000000e,data-len=4
