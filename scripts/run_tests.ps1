Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$GhdlExe = $env:GHDL_EXE
if (-not $GhdlExe -or $GhdlExe.Trim().Length -eq 0) {
  $defaultPath = 'C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe'
  if (Test-Path $defaultPath) {
    $GhdlExe = $defaultPath
  } else {
    $GhdlExe = 'ghdl'
  }
}

Write-Host "Using GHDL: $GhdlExe"

function Invoke-Ghdl {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Args
  )

  & $GhdlExe @Args
  if ($LASTEXITCODE -ne 0) {
    throw "GHDL command failed (exit $LASTEXITCODE): $GhdlExe $($Args -join ' ')"
  }
}

Invoke-Ghdl @('-a', '--std=08', 'src/mc68881_pkg.vhd', 'src/mc68881_alu.vhd', 'src/mc68881_top.vhd', 'tb/tb_mc68881_alu.vhd', 'tb/tb_mc68881_top.vhd', 'tb/tb_mc68881_fpcr_fpsr.vhd', 'tb/tb_mc68881_ea_cycles.vhd', 'tb/tb_mc68881_cycle_counts.vhd', 'tb/tb_mc68881_cycle_counts_top.vhd', 'tb/tb_mc68881_fmove_fmovem.vhd', 'tb/tb_mc68881_fmovecr.vhd', 'tb/tb_mc68881_ac_timing.vhd')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_alu')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_alu', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_top')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_top', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_fpcr_fpsr')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_fpcr_fpsr', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_ea_cycles')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_ea_cycles', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_cycle_counts')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_cycle_counts', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_cycle_counts_top')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_cycle_counts_top', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_fmove_fmovem')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_fmove_fmovem', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_fmovecr')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_fmovecr', '--assert-level=error')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_ac_timing')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_ac_timing', '--assert-level=error')

Write-Host 'GHDL tests passed.'
