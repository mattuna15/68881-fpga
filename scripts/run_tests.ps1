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

& $GhdlExe -a --std=08 src/mc68881_pkg.vhd src/mc68881_alu.vhd src/mc68881_top.vhd tb/tb_mc68881_alu.vhd tb/tb_mc68881_top.vhd tb/tb_mc68881_ea_cycles.vhd tb/tb_mc68881_cycle_counts.vhd
& $GhdlExe -e --std=08 tb_mc68881_alu
& $GhdlExe -r --std=08 tb_mc68881_alu --assert-level=error
& $GhdlExe -e --std=08 tb_mc68881_top
& $GhdlExe -r --std=08 tb_mc68881_top --assert-level=error
& $GhdlExe -e --std=08 tb_mc68881_ea_cycles
& $GhdlExe -r --std=08 tb_mc68881_ea_cycles --assert-level=error
& $GhdlExe -e --std=08 tb_mc68881_cycle_counts
& $GhdlExe -r --std=08 tb_mc68881_cycle_counts --assert-level=error

Write-Host 'GHDL tests passed.'
