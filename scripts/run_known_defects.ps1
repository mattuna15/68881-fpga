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

Invoke-Ghdl @('-a', '--std=08', 'src/mc68881_pkg.vhd', 'src/mc68881_trig_unit.vhd', 'src/mc68881_divrem_unit.vhd', 'src/mc68881_sgl_ops_unit.vhd', 'src/mc68881_alu.vhd', 'tb/tb_mc68881_known_defects.vhd')
Invoke-Ghdl @('-e', '--std=08', 'tb_mc68881_known_defects')
Invoke-Ghdl @('-r', '--std=08', 'tb_mc68881_known_defects', '--assert-level=error')

Write-Host 'Known-defect checks completed.'

