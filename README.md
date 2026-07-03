# Roblox Scripts

Public game scripts for loadstring. Use with **Potassium** (or any executor with `HttpGet` + `loadstring`).

Private tools, dumpers, and templates stay local in `tools/roblox/` — not in this repo.

---

## Loadstring

### Sell Lemons — Ethan's Lemons

**Game:** Sell Lemons · PlaceId `79268393072444`  
**Menu:** Right Shift

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/brobro12235/roblox-scripts/main/scripts/sell-lemons/ethans_lemons.lua"))()
```

Features: Auto Buy, Auto Upgrade, Auto Collect Fruits, Auto Phone Offer, themes, unload.

---

## Updating a script

Edit locally in `tools/roblox/`, sync, then push:

```powershell
cd "C:\Users\ethan\.cursor\r6_external\tools\roblox\roblox-scripts"
.\sync.ps1
git add .
git commit -m "Update ethans_lemons"
git push
```

---

## Adding another game script

1. Edit source in `tools/roblox/`
2. Add to `scripts/<game-name>/your_script.lua` (via sync or manually)
3. Add a loadstring block to this README
4. Commit and push
