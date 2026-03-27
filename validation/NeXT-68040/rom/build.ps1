# Build NeXTMach standalone boot ROM via Cygwin m68k-elf-gcc
#
# Usage:
#   .\build.ps1          -- build the ROM
#   .\build.ps1 clean    -- remove build artifacts

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Targets
)

$CygwinBash = "C:\cygwin64\bin\bash.exe"

if (-not (Test-Path $CygwinBash)) {
    Write-Error "Cygwin bash not found at $CygwinBash"
    exit 1
}

# Convert Windows script directory to Cygwin path
$WinDir = $PSScriptRoot -replace '\\', '/'
$CygDir = $WinDir -replace '^([A-Za-z]):', '/cygdrive/$1'
$CygDir = $CygDir.Substring(0, '/cygdrive/'.Length) + $CygDir['/cygdrive/'.Length].ToString().ToLower() + $CygDir.Substring('/cygdrive/'.Length + 1)

$MakeArgs = if ($Targets) { $Targets -join ' ' } else { '' }

& $CygwinBash -l -c "export PATH=/home/mattp/.local/bin:`$PATH; cd '$CygDir' && make $MakeArgs"
exit $LASTEXITCODE
