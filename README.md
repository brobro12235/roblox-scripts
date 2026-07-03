# Roblox Scripts

Public Roblox executor scripts. Use with **Potassium** (or any executor with `HttpGet` + `loadstring`).

Replace `brobro12235` with your GitHub username.

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

## Upload to GitHub (first time)

1. [github.com/new](https://github.com/new) → name **`roblox-scripts`** → **Public**
2. Don't add README / .gitignore (this folder already has them)
3. Push:

```powershell
cd "C:\Users\ethan\.cursor\r6_external\tools\roblox\roblox-scripts"
git remote add origin https://github.com/brobro12235/roblox-scripts.git
git push -u origin main
```

---

## Updating a script

Edit in `tools/roblox/`, sync to this repo, then push:

```powershell
cd "C:\Users\ethan\.cursor\r6_external\tools\roblox\roblox-scripts"
.\sync.ps1
git add .
git commit -m "Update ethans_lemons"
git push
```

---

## Learning / templates

| File | Description |
|------|-------------|
| `learning/visual_ui_learn.lua` | Visual UI Library tutorial |
| `learning/clean_ui_tutorial.lua` | Clean menu from scratch |

---

## Tools

| File | Description |
|------|-------------|
| `tools/game_dumper.lua` | Dump client scripts from a game |
| `tools/potassium_saveinstance.lua` | Save `.rbxl` for Studio |
| `tools/potassium_ai_dump.lua` | AI-friendly dump helper |
| `tools/copy_dump_to_cursor.ps1` | Copy dump into Cursor workspace |

**Do not commit** game dumps (`dumps/`), `.rbxl` files, or decompiled game source.

---

## Adding another game script

1. Add `scripts/<game-name>/your_script.lua`
2. Add a loadstring block to this README
3. `git add` → `commit` → `push`
