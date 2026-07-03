# Roblox Scripts

Personal Roblox executor scripts and tools. Use with **Potassium** (or any executor with `HttpGet` + `loadstring`).

Replace `YOUR_USERNAME` with your GitHub username in the URLs below.

---

## Loadstring — game scripts

### Sell Lemons — Ethan's Lemons

**Game:** Sell Lemons · PlaceId `79268393072444`  
**Menu:** Right Shift

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/roblox-scripts/main/scripts/sell-lemons/ethans_lemons.lua"))()
```

Features: Auto Buy, Auto Upgrade, Auto Collect Fruits, Auto Phone Offer, themes, unload.

---

## Learning / templates

| File | Description |
|------|-------------|
| `learning/visual_ui_learn.lua` | Visual UI Library tutorial template |
| `learning/clean_ui_tutorial.lua` | Build a clean menu from scratch (no library) |

Run these directly in your executor (copy/paste or local file). Not meant for loadstring unless you host them.

---

## Tools (executor / local)

| File | Description |
|------|-------------|
| `tools/game_dumper.lua` | Dump client scripts from a game to workspace |
| `tools/potassium_saveinstance.lua` | Save game as `.rbxl` for Studio |
| `tools/potassium_ai_dump.lua` | AI-friendly game dump helper |
| `tools/copy_dump_to_cursor.ps1` | Copy dump folder into Cursor workspace (Windows) |

---

## Adding a new script

1. Put game scripts under `scripts/<game-name>/your_script.lua`
2. Add a loadstring block to this README
3. Commit and push:

```powershell
cd tools/roblox/roblox-scripts
git add .
git commit -m "Add my new script"
git push
```

**Do not commit** game dumps (`dumps/`), `.rbxl` files, or decompiled game source — those stay local.

---

## Upload to GitHub (first time)

1. Create a new repo at [github.com/new](https://github.com/new) named **`roblox-scripts`** (public, no README)
2. Push:

```powershell
cd "C:\Users\ethan\.cursor\r6_external\tools\roblox\roblox-scripts"
git remote add origin https://github.com/YOUR_USERNAME/roblox-scripts.git
git push -u origin main
```
