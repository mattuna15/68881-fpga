[CmdletBinding()]
param(
  [string]$VivadoBat = $env:VIVADO_BAT,
  [string]$Top = 'mc68881_top',
  [string]$Part = 'xc7a200tfbg676-1',
  [string]$WorkDir = '.',
  [string]$OutDir = 'logs',
  [string]$XdcFile = 'constraints/mc68881_top.xdc'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $VivadoBat -or $VivadoBat.Trim().Length -eq 0) {
  $defaultVivado = 'C:\amddesigntools\2025.2\Vivado\bin\vivado.bat'
  if (Test-Path $defaultVivado) {
    $VivadoBat = $defaultVivado
  } else {
    $VivadoBat = 'vivado'
  }
}

$repoRoot = Resolve-Path $WorkDir
$outPath = Join-Path $repoRoot $OutDir
if (-not (Test-Path $outPath)) {
  New-Item -ItemType Directory -Path $outPath | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$fullLog = Join-Path $outPath ("vivado_synth_{0}_{1}.log" -f $Top, $timestamp)
$summaryLog = Join-Path $outPath ("vivado_synth_{0}_{1}_summary.log" -f $Top, $timestamp)
$journal = Join-Path $outPath ("vivado_synth_{0}_{1}.jou" -f $Top, $timestamp)
$msgDb = Join-Path $outPath ("vivado_synth_{0}_{1}.pb" -f $Top, $timestamp)
$tclFile = Join-Path $outPath ("vivado_synth_{0}_{1}.tcl" -f $Top, $timestamp)
$xdcReadCmd = ''
$xdcPath = Join-Path $repoRoot $XdcFile
if (Test-Path $xdcPath) {
  $xdcReadCmd = "read_xdc $XdcFile"
}

$tclText = @"
read_vhdl -vhdl2008 src/mc68881_pkg.vhd
read_vhdl -vhdl2008 src/mc68881_alu.vhd
read_vhdl -vhdl2008 src/mc68881_top.vhd
$xdcReadCmd
synth_design -top $Top -part $Part
quit
"@
Set-Content -Path $tclFile -Value $tclText -Encoding ascii

Write-Host "Using Vivado: $VivadoBat"
Write-Host "Synth top: $Top"
Write-Host "Part: $Part"
Write-Host "XDC: $XdcFile"
Write-Host "Full log: $fullLog"
Write-Host "Summary log: $summaryLog"

Push-Location $repoRoot
try {
  & $VivadoBat -log $fullLog -m64 -product Vivado -mode batch -messageDb $msgDb -notrace -journal $journal -source $tclFile
  $vivadoExit = $LASTEXITCODE
} finally {
  Pop-Location
}

$logExists = Test-Path $fullLog
if (-not $logExists) {
  throw "Vivado log was not generated: $fullLog"
}

$logLines = Get-Content $fullLog
$successLine = $logLines | Select-String -Pattern 'synth_design completed successfully' | Select-Object -Last 1
$failureLine = $logLines | Select-String -Pattern 'synth_design failed|Command failed: Vivado Synthesis failed' | Select-Object -Last 1
$summaryLine = $logLines | Select-String -Pattern 'Synthesis finished with .*errors.*warnings' | Select-Object -Last 1
$finalCounts = $logLines | Select-String -Pattern 'Infos, .*Warnings, .*Errors encountered' | Select-Object -Last 1

$status = 'FAILED'
if ($successLine -and -not $failureLine -and $vivadoExit -eq 0) {
  $status = 'PASSED'
}

$summary = @()
$summary += "timestamp: $(Get-Date -Format o)"
$summary += "status: $status"
$summary += "vivado_exit_code: $vivadoExit"
$summary += "top: $Top"
$summary += "part: $Part"
$summary += "xdc: $XdcFile"
$summary += "vivado: $VivadoBat"
$summary += "full_log: $fullLog"
$summary += "journal: $journal"
$summary += "message_db: $msgDb"
if ($summaryLine) { $summary += "synth_summary: $($summaryLine.Line.Trim())" }
if ($finalCounts) { $summary += "message_counts: $($finalCounts.Line.Trim())" }
if ($failureLine) { $summary += "failure_line: $($failureLine.Line.Trim())" }
if ($successLine) { $summary += "success_line: $($successLine.Line.Trim())" }

Set-Content -Path $summaryLog -Value $summary -Encoding ascii
Write-Host "Wrote summary log: $summaryLog"

if ($status -ne 'PASSED') {
  throw "Vivado synthesis failed. See $summaryLog and $fullLog"
}

Write-Host 'Vivado synthesis passed.'
