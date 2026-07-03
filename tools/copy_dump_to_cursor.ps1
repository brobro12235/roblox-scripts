# Copies latest Potassium AI dump into this repo so Cursor AI can read it.
# Usage:
#   .\tools\roblox\copy_dump_to_cursor.ps1
#   .\tools\roblox\copy_dump_to_cursor.ps1 -PlaceId 79268393072444

param(
    [string]$PlaceId = ""
)

$potassiumRoot = Join-Path $env:LOCALAPPDATA "Potassium\workspace\ai_dumps"
$destRoot = Join-Path $PSScriptRoot "dumps"

if (-not (Test-Path $potassiumRoot)) {
    Write-Error "No ai_dumps folder yet. Run potassium_ai_dump.lua in-game first."
    Write-Host "Expected: $potassiumRoot"
    exit 1
}

$source = $null
if ($PlaceId -ne "") {
    $source = Get-ChildItem $potassiumRoot -Directory | Where-Object { $_.Name -like "${PlaceId}_*" } | Select-Object -First 1
} else {
    $source = Get-ChildItem $potassiumRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not $source) {
    Write-Error "No dump folder found in $potassiumRoot"
    exit 1
}

if (-not (Test-Path $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
}

$dest = Join-Path $destRoot $source.Name
if (Test-Path $dest) {
    Remove-Item $dest -Recurse -Force
}

Copy-Item $source.FullName $dest -Recurse -Force

Write-Host "Copied dump to:"
Write-Host "  $dest"
Write-Host ""
Write-Host "Tell Cursor: read tools/roblox/dumps/$($source.Name)/AI_README.txt"
