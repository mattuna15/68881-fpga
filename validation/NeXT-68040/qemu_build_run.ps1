#!/usr/bin/env pwsh
#
# qemu_build_run.ps1 - Launch NeXT-68040 under QEMU.
#
# Usage:
#   .\qemu_build_run.ps1              # run using Vitis-built ELF
#   .\qemu_build_run.ps1 -Build       # build with QEMU_MODE then run
#   .\qemu_build_run.ps1 -Clean       # clean + build + run
#
# For -Build mode, the script patches UserConfig.cmake to add QEMU_MODE,
# invokes the Vitis CMake/Ninja build, then restores the original file.
#

param(
    [switch]$Build,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$ProjectDir  = $PSScriptRoot
$SrcDir      = Join-Path $ProjectDir "src"
$BuildDir    = Join-Path $ProjectDir "build"
$ELF         = Join-Path $BuildDir "NeXT-68040.elf"
$UserConfig  = Join-Path $SrcDir "UserConfig.cmake"
$QEMU        = "C:/amddesigntools/2025.2/data/emulation/qemu/comp/qemu_win/qemu-system-aarch64.exe"

if (!(Test-Path $QEMU)) {
    Write-Error "QEMU not found: $QEMU"
    exit 1
}

if ($Build -or $Clean) {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Building NeXT-68040 (QEMU_MODE)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # Patch UserConfig.cmake to add QEMU_MODE
    $origContent = Get-Content $UserConfig -Raw
    $patched = $origContent -replace 'set\(USER_COMPILE_DEFINITIONS\s*\r?\n"SDT"\s*\r?\n\)', "set(USER_COMPILE_DEFINITIONS`n`"SDT`" `"QEMU_MODE`"`n)"
    Set-Content $UserConfig -Value $patched -NoNewline

    try {
        if ($Clean -and (Test-Path $BuildDir)) {
            Write-Host "[BUILD] Cleaning build directory"
            Remove-Item -Recurse -Force $BuildDir
        }

        # Use Vitis cmake/ninja from the existing build cache or configure fresh
        $Ninja = "C:/amddesigntools/2025.2/Vitis/bin/ninja.exe"
        $CMake = "C:/amddesigntools/2025.2/Vitis/tps/win64/cmake-3.24.2/bin/cmake.exe"
        $Toolchain = "C:/code/68881-fpga/validation/platform-68-linux/export/platform-68-linux/sw/standalone_psu_cortexa53_0/cortexa53_toolchain.cmake"

        if (!(Test-Path $BuildDir)) {
            New-Item -ItemType Directory -Path $BuildDir | Out-Null
        }

        if (!(Test-Path (Join-Path $BuildDir "build.ninja"))) {
            Write-Host "[BUILD] CMake configure..."
            & $CMake -G Ninja `
                -S $SrcDir `
                -B $BuildDir `
                -DCMAKE_TOOLCHAIN_FILE="$Toolchain" `
                -DCMAKE_MAKE_PROGRAM="$Ninja"
            if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }
        }

        Write-Host "[BUILD] Ninja build..."
        & $Ninja -C $BuildDir
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }

        Write-Host "[BUILD] OK: $ELF" -ForegroundColor Green
    }
    finally {
        # Restore original UserConfig.cmake
        Set-Content $UserConfig -Value $origContent -NoNewline
        Write-Host "[BUILD] UserConfig.cmake restored"
    }
}

if (!(Test-Path $ELF)) {
    Write-Error "ELF not found: $ELF - build in Vitis first, or use -Build flag"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  NeXT 68040LC under QEMU (ZynqMP ZCU102)" -ForegroundColor Cyan
Write-Host "  ELF: $ELF" -ForegroundColor Cyan
Write-Host "  Exit: Ctrl-A then X" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$elfLoader = 'loader,file=' + $ELF + ',cpu-num=0'
$addrLoader = 'loader,addr=0xFD1A0104,data=0x8000000e,data-len=4'
& $QEMU -M xlnx-zcu102 -nographic -device $elfLoader -device $addrLoader
