# Copy public game scripts into this repo before git push.
# Private tools/templates stay in tools/roblox/ only — not synced here.

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Roblox = Join-Path $Root ".."

$Copies = @(
    @{
        From = Join-Path $Roblox "ethans_lemons.lua"
        To   = Join-Path $Root "scripts\sell-lemons\ethans_lemons.lua"
    }
)

foreach ($item in $Copies) {
    if (-not (Test-Path $item.From)) {
        Write-Warning "Skip (missing): $($item.From)"
        continue
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $item.To) | Out-Null
    Copy-Item $item.From $item.To -Force
    Write-Host "Synced: $($item.To)"
}

Write-Host ""
Write-Host "Done. Next: git add . && git commit -m 'Update scripts' && git push"
