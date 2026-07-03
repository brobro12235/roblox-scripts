--[[
    Potassium AI Game Dump
    Decompiles client scripts + builds remotes index for script dev / Cursor AI.

    RUN:
      1. Join the game (fully loaded in)
      2. Inject Potassium
      3. Execute this script — wait until "DUMP COMPLETE"

    OUTPUT (Potassium workspace):
      %LOCALAPPDATA%\\Potassium\\workspace\\ai_dumps\\<PlaceId>_<GameName>\\
        AI_README.txt       ← start here
        remotes/all_remotes.json
        analysis/fireserver_calls.txt
        analysis/invokeserver_calls.txt
        scripts/            ← decompiled .lua by path

    THEN copy folder to Cursor (PowerShell):
      .\\tools\\roblox\\copy_dump_to_cursor.ps1

    Requires Potassium: decompile, writefile, makefolder, isfile, isfolder, getscripts
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CONFIG = {
    outputRoot = "ai_dumps",
    maxScripts = 8000,
    skipExisting = false,
    useGetScripts = true,       -- catches scripts getDescendants misses
    useNilInstances = true,     -- orphaned / hidden instances
    saveRbxlBackup = true,      -- also save .rbxl via saveinstance
    rbxlMaxThreads = 4,
    logEvery = 20,
    ignoreServices = {
        Chat = true,
        CoreGui = true,
        CorePackages = true,
    },
}

-- ============ filesystem helpers ============

local function safeSegment(name)
    return (name:gsub("[<>:\"/\\|%?%*]", "_"):gsub("%.%.", "_"))
end

local function ensureFolder(path)
    if isfolder(path) then
        return
    end
    local parts = {}
    for part in path:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    local built = ""
    for _, part in ipairs(parts) do
        built = (built == "") and part or (built .. "/" .. part)
        if not isfolder(built) then
            makefolder(built)
        end
    end
end

local function writeText(path, content)
    local dir = path:match("^(.*)/[^/]+$")
    if dir then
        ensureFolder(dir)
    end
    writefile(path, content)
end

local function instancePath(inst)
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, "/")
end

local function isIgnored(inst)
    local service = inst:FindFirstAncestorWhichIsA("ServiceProvider")
    if not service then
        return false
    end
    return CONFIG.ignoreServices[service.Name] == true
end

-- ============ collect everything ============

local function collectRemotes()
    local remotes = {}
    local roots = {
        ReplicatedStorage,
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterGui"),
        game:GetService("StarterPlayer"),
        game:GetService("Workspace"),
    }

    local lp = Players.LocalPlayer
    if lp then
        roots[#roots + 1] = lp:FindFirstChild("PlayerScripts")
        roots[#roots + 1] = lp:FindFirstChild("PlayerGui")
    end

    local seen = {}
    for _, root in ipairs(roots) do
        if root then
            for _, inst in ipairs(root:GetDescendants()) do
                if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent"))
                    and not seen[inst] then
                    seen[inst] = true
                    remotes[#remotes + 1] = {
                        name = inst.Name,
                        class = inst.ClassName,
                        path = inst:GetFullName(),
                    }
                end
            end
        end
    end

    table.sort(remotes, function(a, b)
        return a.path < b.path
    end)
    return remotes
end

local function collectScripts()
    local list = {}
    local seen = {}

    local function add(inst)
        if seen[inst] or not inst:IsA("LuaSourceContainer") then
            return
        end
        if isIgnored(inst) then
            return
        end
        if #list >= CONFIG.maxScripts then
            return
        end
        seen[inst] = true
        list[#list + 1] = inst
    end

    if CONFIG.useGetScripts and type(getscripts) == "function" then
        local ok, result = pcall(getscripts)
        if ok and type(result) == "table" then
            for _, inst in ipairs(result) do
                add(inst)
            end
        end
    end

    if CONFIG.useNilInstances and type(getnilinstances) == "function" then
        local ok, result = pcall(getnilinstances)
        if ok and type(result) == "table" then
            for _, inst in ipairs(result) do
                if inst:IsA("LuaSourceContainer") then
                    add(inst)
                end
            end
        end
    end

    local scanRoots = {
        ReplicatedStorage,
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterGui"),
        game:GetService("StarterPlayer"),
        game:GetService("Workspace"),
        game:GetService("Lighting"),
    }

    local lp = Players.LocalPlayer
    if lp then
        scanRoots[#scanRoots + 1] = lp:FindFirstChild("PlayerScripts")
        scanRoots[#scanRoots + 1] = lp:FindFirstChild("PlayerGui")
        scanRoots[#scanRoots + 1] = lp:FindFirstChild("Backpack")
    end

    for _, root in ipairs(scanRoots) do
        if root then
            for _, inst in ipairs(root:GetDescendants()) do
                if inst:IsA("LuaSourceContainer") then
                    add(inst)
                end
            end
        end
    end

    return list
end

-- ============ analysis ============

local PATTERNS = {
    fireserver = {
        ":FireServer%([^%)]*",
        ":fireServer%([^%)]*",
    },
    invokeserver = {
        ":InvokeServer%([^%)]*",
        ":invokeServer%([^%)]*",
    },
    onclient = {
        ":OnClientEvent",
        ":OnClientInvoke",
    },
    waitforchild_remote = {
        'WaitForChild%("([^"]+)"%)',
        "WaitForChild%('([^']+)'%)",
    },
}

local function extractMatches(source, patterns)
    local hits = {}
    for _, pat in ipairs(patterns) do
        local start = 1
        while true do
            local s, e, cap = source:find(pat, start)
            if not s then
                break
            end
            hits[#hits + 1] = cap or source:sub(s, math.min(e + 40, #source))
            start = e + 1
        end
    end
    return hits
end

local function analyzeSource(scriptPath, source)
    return {
        fireserver = extractMatches(source, PATTERNS.fireserver),
        invokeserver = extractMatches(source, PATTERNS.invokeserver),
        onclient = extractMatches(source, PATTERNS.onclient),
    }
end

-- ============ main dump ============

if not decompile then
    return warn("[ai_dump] decompile() missing")
end
if not writefile or not makefolder then
    return warn("[ai_dump] writefile/makefolder missing")
end

local dumpRoot = string.format(
    "%s/%s_%s",
    CONFIG.outputRoot,
    tostring(game.PlaceId),
    safeSegment(game.Name)
)

ensureFolder(dumpRoot)
ensureFolder(dumpRoot .. "/scripts")
ensureFolder(dumpRoot .. "/remotes")
ensureFolder(dumpRoot .. "/analysis")

print("[ai_dump] ========================================")
print("[ai_dump]  Potassium AI Dump")
print("[ai_dump] ========================================")
print("[ai_dump] Game: " .. game.Name)
print("[ai_dump] PlaceId: " .. game.PlaceId)
print("[ai_dump] Output: " .. dumpRoot)

local remotes = collectRemotes()
writeText(dumpRoot .. "/remotes/all_remotes.json", HttpService:JSONEncode(remotes))

local remotesTxt = { "# All remotes found on client\n" }
for _, r in ipairs(remotes) do
    remotesTxt[#remotesTxt + 1] = string.format("[%s] %s\n  path: %s\n", r.class, r.name, r.path)
end
writeText(dumpRoot .. "/remotes/remotes_list.txt", table.concat(remotesTxt))

local scripts = collectScripts()
print("[ai_dump] Scripts to decompile: " .. #scripts)
print("[ai_dump] Remotes found: " .. #remotes)

local stats = { ok = 0, fail = 0, skip = 0 }
local manifestScripts = {}
local fireLines = { "# FireServer / fireServer calls\n" }
local invokeLines = { "# InvokeServer / invokeServer calls\n" }
local onClientLines = { "# OnClientEvent / OnClientInvoke hooks\n" }

for i, inst in ipairs(scripts) do
    local rel = safeSegment(instancePath(inst))
    local outRel = "scripts/" .. inst.ClassName .. "/" .. rel .. ".lua"
    local outPath = dumpRoot .. "/" .. outRel

    if CONFIG.skipExisting and isfile(outPath) then
        stats.skip += 1
    else
        local ok, source = pcall(decompile, inst)
        if not ok or type(source) ~= "string" then
            source = "-- decompile failed: " .. tostring(source)
            stats.fail += 1
        else
            stats.ok += 1
        end

        local header = string.format(
            "-- Class: %s\n-- FullName: %s\n-- Source: %s\n\n",
            inst.ClassName,
            inst:GetFullName(),
            outRel
        )
        local full = header .. source
        writeText(outPath, full)

        local analysis = analyzeSource(outRel, source)
        for _, hit in ipairs(analysis.fireserver or {}) do
            fireLines[#fireLines + 1] = string.format("%s\n  -> %s\n", outRel, hit)
        end
        for _, hit in ipairs(analysis.invokeserver or {}) do
            invokeLines[#invokeLines + 1] = string.format("%s\n  -> %s\n", outRel, hit)
        end
        for _, hit in ipairs(analysis.onclient or {}) do
            onClientLines[#onClientLines + 1] = string.format("%s\n  -> %s\n", outRel, hit)
        end
    end

    manifestScripts[#manifestScripts + 1] = {
        class = inst.ClassName,
        fullName = inst:GetFullName(),
        file = outRel,
    }

    if i % CONFIG.logEvery == 0 then
        print(string.format("[ai_dump] %d / %d", i, #scripts))
    end
end

writeText(dumpRoot .. "/analysis/fireserver_calls.txt", table.concat(fireLines))
writeText(dumpRoot .. "/analysis/invokeserver_calls.txt", table.concat(invokeLines))
writeText(dumpRoot .. "/analysis/onclient_hooks.txt", table.concat(onClientLines))

local manifest = {
    placeId = game.PlaceId,
    placeName = game.Name,
    gameId = game.GameId,
    universeId = game.GameId,
    dumpedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    scriptCount = #scripts,
    remoteCount = #remotes,
    stats = stats,
    scripts = manifestScripts,
    remotes = remotes,
    potassiumWorkspace = "%LOCALAPPDATA%/Potassium/workspace/" .. dumpRoot,
    cursorCopyHint = "Run tools/roblox/copy_dump_to_cursor.ps1 from r6_external repo",
}

writeText(dumpRoot .. "/manifest.json", HttpService:JSONEncode(manifest))

local readme = string.format([[
# AI Game Dump — %s

PlaceId: %s
GameId:  %s
Dumped:  %s

## Stats
- Scripts decompiled: %d (ok=%d fail=%d skip=%d)
- Remotes indexed:    %d

## Files for AI / script dev (read these first)
1. remotes/remotes_list.txt     — every RemoteEvent/RemoteFunction path
2. analysis/fireserver_calls.txt — client -> server calls
3. analysis/invokeserver_calls.txt
4. analysis/onclient_hooks.txt
5. scripts/                      — full decompiled source tree

## Copy to Cursor so AI can read it
From PowerShell in r6_external repo:
  .\\tools\\roblox\\copy_dump_to_cursor.ps1 -PlaceId %s

Or manually copy:
  %%LOCALAPPDATA%%\\Potassium\\workspace\\%s
  -> C:\\Users\\ethan\\.cursor\\r6_external\\tools\\roblox\\dumps\\

## Limits (cannot bypass)
- ServerScriptService scripts are NOT on client
- Decompiled code is pseudocode, not original source
- Some games obfuscate remote args (check analysis + Simple Spy)

## Next step
Paste in Cursor chat: "read tools/roblox/dumps/%s/ and help me script X"
]], game.Name, game.PlaceId, game.GameId, manifest.dumpedAt,
    #scripts, stats.ok, stats.fail, stats.skip, #remotes,
    game.PlaceId, dumpRoot, dumpRoot, dumpRoot)

writeText(dumpRoot .. "/AI_README.txt", readme)

if CONFIG.saveRbxlBackup and type(saveinstance) == "function" then
    print("[ai_dump] Saving .rbxl backup (background)...")
    task.spawn(function()
        pcall(saveinstance, game, {
            FileName = dumpRoot .. "/game_backup.rbxl",
            Decompile = false,
            MaxThreads = CONFIG.rbxlMaxThreads,
            ShowStatus = false,
            RemovePlayerCharacters = true,
            DecompileIgnore = { "Chat", "CoreGui", "CorePackages" },
        })
        print("[ai_dump] .rbxl backup done")
    end)
end

print("[ai_dump] ========================================")
print("[ai_dump]  DUMP COMPLETE")
print("[ai_dump] ========================================")
print("[ai_dump] Folder: " .. dumpRoot)
print("[ai_dump] Open: %LOCALAPPDATA%\\Potassium\\workspace\\" .. dumpRoot)
print("[ai_dump] Copy to Cursor then ask AI to read AI_README.txt")
