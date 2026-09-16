<#
.SYNOPSIS
    Builds a Steam Workshop-ready copy of the Simple Graphs mod.

.DESCRIPTION
    This repo holds both the shippable mod and a pile of development material
    (design notes, research write-ups, verification scripts, log dumps,
    screenshots). Only the shippable subset belongs on the Workshop.

    This script wipes the destination and re-copies that subset, so the output
    is always a clean build with no leftovers from a previous run.

    The destination defaults to the CK3 mod folder, which is where
    'mod/simple-graphs.mod' already points. That means the Paradox launcher
    picks up the result with no extra configuration: run this, then upload from
    the launcher's Mod tab.

.PARAMETER Destination
    Folder to build into. Defaults to the CK3 mod directory.

.EXAMPLE
    .\build-workshop.ps1

.EXAMPLE
    .\build-workshop.ps1 -Destination "D:\staging\simple-graphs"
#>
[CmdletBinding()]
param(
    [string]$Destination = "C:\Users\hilbe\Documents\Paradox Interactive\Crusader Kings III\mod\simple-graphs"
)

$ErrorActionPreference = 'Stop'

$SourceRoot = $PSScriptRoot

# The shippable subset. Everything else in the repo stays behind.
$Folders = @('common', 'events', 'gui', 'localization')
$Files   = @('README.md', 'LICENSE', 'descriptor.mod', 'thumbnail.png')

function Fail($msg) {
    Write-Host ""
    Write-Host "  BUILD FAILED: $msg" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "  Simple Graphs - Workshop build" -ForegroundColor Cyan
Write-Host "  source: $SourceRoot"
Write-Host "  target: $Destination"
Write-Host ""

# --- Validate the source before touching the destination -------------------
# Ordering matters: never wipe the target and only then discover a missing
# input, which would leave the mod folder empty and the game with no mod.

$missing = @()
foreach ($f in $Folders) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $f) -PathType Container)) {
        $missing += "$f\"
    }
}
foreach ($f in $Files) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $f) -PathType Leaf)) {
        $missing += $f
    }
}
if ($missing.Count -gt 0) {
    Fail "missing from source repo: $($missing -join ', ')"
}

# --- Guard the destination -------------------------------------------------
# This script deletes everything in the target, so be certain about the target.

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$srcFull = (Resolve-Path -LiteralPath $SourceRoot).ProviderPath.TrimEnd('\')
$dstFull = (Resolve-Path -LiteralPath $Destination).ProviderPath.TrimEnd('\')

if ($srcFull -eq $dstFull) {
    Fail "destination is the source repo itself - that would delete your work."
}
if ($dstFull.StartsWith($srcFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
    Fail "destination is inside the source repo."
}
if ($srcFull.StartsWith($dstFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
    Fail "source repo is inside the destination - cleaning would delete it."
}
if (Test-Path -LiteralPath (Join-Path $dstFull '.git')) {
    Fail "destination contains a .git folder, so it looks like a real repo. Refusing to wipe it."
}

# --- Clean -----------------------------------------------------------------
# Remove the contents, not the folder itself. The folder can legitimately be
# held open (Explorer, an editor, the launcher), which blocks deleting the
# directory but not the files inside it.

$existing = @(Get-ChildItem -LiteralPath $dstFull -Force -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) {
    Write-Host "  cleaning   $($existing.Count) existing item(s)"
    foreach ($item in $existing) {
        try {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
        } catch {
            Fail "could not remove '$($item.Name)': $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "  cleaning   (destination already empty)"
}

# --- Copy ------------------------------------------------------------------

foreach ($f in $Folders) {
    Copy-Item -LiteralPath (Join-Path $SourceRoot $f) -Destination $dstFull -Recurse -Force
    Write-Host "  copied     $f\"
}
foreach ($f in $Files) {
    Copy-Item -LiteralPath (Join-Path $SourceRoot $f) -Destination $dstFull -Force
    Write-Host "  copied     $f"
}

# --- Verify and summarise --------------------------------------------------

$built = @(Get-ChildItem -LiteralPath $dstFull -Recurse -Force -File)
$bytes = ($built | Measure-Object -Property Length -Sum).Sum
if ($null -eq $bytes) { $bytes = 0 }
$kb = [math]::Round($bytes / 1KB, 1)

$strays = @(Get-ChildItem -LiteralPath $dstFull -Force |
    Where-Object { $Folders -notcontains $_.Name -and $Files -notcontains $_.Name })
if ($strays.Count -gt 0) {
    Fail "unexpected items in build output: $($strays.Name -join ', ')"
}

Write-Host ""
Write-Host "  Done. $($built.Count) files, $kb KB." -ForegroundColor Green
Write-Host "  Upload from the CK3 launcher: Mods tab -> Simple Graphs -> Upload."
Write-Host ""
