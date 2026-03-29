#!/usr/bin/env pwsh
#
# qemu_build_run.ps1 - Build NeXT-68040 with QEMU_MODE and run under QEMU.
#
# Usage:
#   .\qemu_build_run.ps1              # run using existing QEMU build
#   .\qemu_build_run.ps1 -Build       # build then run
#   .\qemu_build_run.ps1 -Clean       # clean build then run
#   .\qemu_build_run.ps1 -RunOnly     # just launch QEMU (skip build check)
#

param(
    [switch]$Build,
    [switch]$Clean,
    [switch]$RunOnly
)

$ErrorActionPreference = "Stop"

# Paths
$ProjectDir = $PSScriptRoot
$BuildDir   = Join-Path $ProjectDir "build-qemu"
$ELF        = Join-Path $BuildDir "NeXT-68040.elf"
$QemuBin    = "C:/amddesigntools/2025.2/data/emulation/qemu/comp/qemu_win"
$QemuA53    = Join-Path $QemuBin "qemu-system-aarch64.exe"
$QemuPMU    = Join-Path $QemuBin "qemu-system-microblazeel.exe"
$PlatformSW = "C:/code/68881-fpga/validation/platform-68-linux/export/platform-68-linux/sw/standalone_psu_cortexa53_0"
$PMUfw      = Join-Path $PlatformSW "qemu/pmufw.elf"
$Toolchain  = Join-Path $PlatformSW "cortexa53_toolchain.cmake"

# Validate critical files
foreach ($f in @($QemuA53, $QemuPMU, $PMUfw)) {
    if (!(Test-Path $f)) { Write-Error "Not found: $f"; exit 1 }
}

# ── Build ──────────────────────────────────────────────────────────
if ($Build -or $Clean) {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Building NeXT-68040 (QEMU_MODE)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    if ($Clean -and (Test-Path $BuildDir)) {
        Write-Host "[BUILD] Cleaning build directory"
        Remove-Item -Recurse -Force $BuildDir
    }

    $Ninja = "C:/amddesigntools/2025.2/Vitis/bin/ninja.exe"
    $CMake = "C:/amddesigntools/2025.2/Vitis/tps/win64/cmake-3.24.2/bin/cmake.exe"
    $toolBin = "C:/amddesigntools/2025.2/Vitis/gnu/aarch64/nt/aarch64-none/bin"
    $env:PATH = "$toolBin;$env:PATH"
    $env:ESW_REPO = "C:/amddesigntools/2025.2/Vitis/data/embeddedsw"

    if (!(Test-Path $BuildDir)) {
        New-Item -ItemType Directory -Path $BuildDir | Out-Null
    }

    if (!(Test-Path (Join-Path $BuildDir "build.ninja"))) {
        Write-Host "[BUILD] CMake configure..."
        & $CMake -G Ninja `
            -S $ProjectDir `
            -B $BuildDir `
            -DCMAKE_TOOLCHAIN_FILE="$Toolchain" `
            -DCMAKE_MAKE_PROGRAM="$Ninja"
        if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }
    }

    Write-Host "[BUILD] Ninja build..."
    & $Ninja -C $BuildDir
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }

    $ELF = Join-Path $BuildDir "NeXT-68040.elf"
    Write-Host "[BUILD] OK: $ELF" -ForegroundColor Green
}

# ── Run ────────────────────────────────────────────────────────────
if (!(Test-Path $ELF)) {
    Write-Error "ELF not found: $ELF - use -Build flag"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  NeXT 68040LC under QEMU (ZynqMP)" -ForegroundColor Cyan
Write-Host "  ELF: $ELF" -ForegroundColor Cyan
Write-Host "  Exit: Ctrl-A then X" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Two-process QEMU: PMU (MicroBlaze) + A53 (AArch64) with shared machine-path.
$dtbDir  = "C:/amddesigntools/2025.2/data/emulation/dtbs/zynqmp/dtb_qemu_win"
$pmuDtb  = Join-Path $dtbDir "zynqmp-pmu.dtb"
$armDtb  = Join-Path $dtbDir "zynqmp-arm.dtb"
$machDir = Join-Path $env:TEMP "next68040_qemu"

# Clean machine-path (stale sockets cause hangs)
if (Test-Path $machDir) { Remove-Item -Recurse -Force $machDir }
New-Item -ItemType Directory -Path $machDir | Out-Null

try {
    # A53 creates server sockets, PMU connects as client.
    # A53 must be foreground (owns stdio for serial console).
    # PMU launches via a helper .bat after a delay.

    # Write a small launcher that waits then starts PMU
    $pmuBat = Join-Path $machDir "start_pmu.bat"
    @"
@echo off
timeout /t 3 /nobreak >nul
"$QemuPMU" -M microblaze-fdt -hw-dtb "$pmuDtb" -machine-path "$machDir" -device "loader,file=$PMUfw" -display none
"@ | Set-Content $pmuBat

    Write-Host "[QEMU] Launching PMU (delayed 3s)..." -ForegroundColor DarkGray
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $pmuBat `
        -WindowStyle Hidden

    # A53 in foreground with serial on stdio
    $logFile = Join-Path $ProjectDir "qemu_trace.log"
    Write-Host "[QEMU] Starting A53 (foreground)..." -ForegroundColor DarkGray
    Write-Host "[QEMU] Trace log: $logFile" -ForegroundColor DarkGray
    & $QemuA53 `
        -M arm-generic-fdt `
        -hw-dtb $armDtb `
        -machine-path $machDir `
        -serial mon:stdio `
        -nographic `
        -global "xlnx,zynqmp-boot.cpu-num=0" `
        -global "xlnx,zynqmp-boot.use-pmufw=false" `
        -m 4G `
        -device "loader,file=$ELF,cpu-num=0" `
        -device "loader,addr=0xFD1A0104,data=0x8000000e,data-len=4" `
        -D $logFile `
        -d unimp,guest_errors
}
finally {
    Get-Process -Name "qemu-system-microblazeel" -ErrorAction SilentlyContinue |
        Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-5) } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
