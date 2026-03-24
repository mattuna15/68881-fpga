# Build EmuTOS 256KB ROM using Cygwin m68k-elf-gcc
#
# Prerequisites:
#   - Cygwin with GNU Make at C:\cygwin64
#   - m68k-elf-gcc 14.2.0 at Cygwin /home/mattp/.local/bin/
#
# Output: toolchain/emutos-src-1.4/etos256us.img (262144 bytes)

$ErrorActionPreference = "Stop"
$CygwinBash = "C:\cygwin64\bin\bash.exe"
$EmuTOSDir = "/cygdrive/c/code/68881-fpga/toolchain/emutos-src-1.4"

Write-Host "Building EmuTOS 256KB ROM..."
Write-Host "  Source: $EmuTOSDir"
Write-Host "  Toolchain: m68k-elf-gcc (ELF=1)"

# Clean any previous build artifacts
& $CygwinBash -l -c "cd $EmuTOSDir && PATH=/home/mattp/.local/bin:`$PATH make ELF=1 clean"

# Build 256KB target
& $CygwinBash -l -c "cd $EmuTOSDir && PATH=/home/mattp/.local/bin:`$PATH make ELF=1 256"

if ($LASTEXITCODE -ne 0) {
    Write-Error "EmuTOS build failed with exit code $LASTEXITCODE"
    exit 1
}

$imgPath = "C:\code\68881-fpga\toolchain\emutos-src-1.4\etos256us.img"
if (Test-Path $imgPath) {
    $size = (Get-Item $imgPath).Length
    Write-Host "Build successful: etos256us.img ($size bytes)"
} else {
    Write-Error "Build completed but etos256us.img not found"
    exit 1
}
