# Copy local scripts into this repo before git push.

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Roblox = Join-Path $Root ".."

$Copies = @(
    @{
        From = Join-Path $Roblox "ethans_lemons.lua"
        To   = Join-Path $Root "scripts\sell-lemons\ethans_lemons.lua"
    },
    @{
        From = Join-Path $Roblox "visual_ui_learn.lua"
        To   = Join-Path $Root "learning\visual_ui_learn.lua"
    },
    @{
        From = Join-Path $Roblox "clean_ui_tutorial.lua"
        To   = Join-Path $Root "learning\clean_ui_tutorial.lua"
    },
    @{
        From = Join-Path $Roblox "game_dumper.lua"
        To   = Join-Path $Root "tools\game_dumper.lua"
    },
    @{
        From = Join-Path $Roblox "potassium_ai_dump.lua"
        To   = Join-Path $Root "tools\potassium_ai_dump.lua"
    },
    @{
        From = Join-Path $Roblox "potassium_saveinstance.lua"
        To   = Join-Path $Root "tools\potassium_saveinstance.lua"
    },
    @{
        From = Join-Path $Roblox "copy_dump_to_cursor.ps1"
        To   = Join-Path $Root "tools\copy_dump_to_cursor.ps1"
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
