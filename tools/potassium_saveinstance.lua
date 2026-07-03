--[[
    Potassium — one-click full game dump (scripts decompiled + .rbxl)
    Paste into Potassium while in-game.

    Output: Potassium workspace folder (next to Potassium.exe)
      - game.rbxl  (open in Roblox Studio to browse)
      - decompiled scripts embedded in the place file

    Docs: https://docs.potassium.pro/api-reference/Miscellaneous Library/saveinstance
]]

saveinstance(game, {
    FileName = game.Name .. "_" .. game.PlaceId .. ".rbxl",
    Decompile = true,
    MaxThreads = 5,              -- lower to 2-3 if your PC lags/crashes
    DecompileTimeout = 15,
    ShowStatus = true,
    RemovePlayerCharacters = true,
    DecompileIgnore = { "Chat", "CoreGui", "CorePackages" },
})

print("[potassium] saveinstance started — check workspace folder when done")
