--[[
    Roblox Game Dumper (client-side scripts only)
    Tested with: Potassium (decompile, writefile, makefolder, isfile, isfolder)

    Usage (Potassium):
      1. Join the game
      2. Inject Potassium
      3. Execute this script
      4. Files saved to Potassium workspace: workspace/dumps/<PlaceId>_<GameName>/

    Faster alternative for Potassium:
      Use potassium_saveinstance.lua — one .rbxl you open in Studio

    Notes:
      - ServerScriptService / server-only scripts are NOT on the client
      - Decompiled output is approximate — expect messy names and control flow
      - Large games can take several minutes
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- ============ CONFIG ============
local CONFIG = {
    outputRoot = "dumps",
    includeCoreGui = false,       -- StarterGui/CoreGui etc. — usually skip
    includeStarterPlayer = true,
    includeReplicatedStorage = true,
    includeReplicatedFirst = true,
    includeWorkspace = true,
    includePlayerGui = true,
    maxScripts = 5000,            -- safety cap
    skipAlreadyDumped = true,     -- skip if .lua file already exists
    logEvery = 25,
}
-- ================================

local function hasApi(name)
    return type(getfenv()[name]) == "function" or type(_G[name]) == "function"
end

local decompile = decompile
    or (syn and syn.decompile)
    or (getrenv and getrenv().decompile)

if not decompile then
    return warn("[dumper] No decompile() API — your executor must support decompiling")
end

if not writefile or not makefolder then
    return warn("[dumper] No writefile/makefolder — cannot save to disk")
end

local function safeName(path)
    return path:gsub("[<>:\"/\\|%?%*]", "_"):gsub("%.%.", "_")
end

local function getPlaceFolder()
    local placeId = tostring(game.PlaceId)
    local root = CONFIG.outputRoot .. "/" .. placeId .. "_" .. safeName(game.Name)
    if not isfolder(CONFIG.outputRoot) then
        makefolder(CONFIG.outputRoot)
    end
    if not isfolder(root) then
        makefolder(root)
    end
    return root
end

local function shouldScan(root)
    if root:IsDescendantOf(game:GetService("CoreGui")) and not CONFIG.includeCoreGui then
        return false
    end
    return true
end

local function collectScripts()
    local scripts = {}
    local seen = {}

    local function add(inst)
        if seen[inst] then return end
        if not inst:IsA("LuaSourceContainer") then return end
        if #scripts >= CONFIG.maxScripts then return end
        seen[inst] = true
        scripts[#scripts + 1] = inst
    end

    local scanRoots = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterGui"),
        game:GetService("StarterPlayer"),
        game:GetService("Workspace"),
        game:GetService("Lighting"),
        game:GetService("SoundService"),
    }

    if CONFIG.includePlayerGui then
        local lp = Players.LocalPlayer
        if lp then
            scanRoots[#scanRoots + 1] = lp:WaitForChild("PlayerGui", 5)
            scanRoots[#scanRoots + 1] = lp:WaitForChild("PlayerScripts", 5)
            scanRoots[#scanRoots + 1] = lp:WaitForChild("Backpack", 5)
        end
    end

    for _, root in ipairs(scanRoots) do
        if root and shouldScan(root) then
            for _, inst in ipairs(root:GetDescendants()) do
                if inst:IsA("LuaSourceContainer") then
                    add(inst)
                end
            end
            if root:IsA("LuaSourceContainer") then
                add(root)
            end
        end
    end

    return scripts
end

local function scriptPath(inst)
    local parts = {}
    local current = inst
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, "/")
end

local function dumpScript(rootFolder, inst)
    local rel = safeName(scriptPath(inst))
    local class = inst.ClassName
    local outPath = rootFolder .. "/" .. class .. "/" .. rel .. ".lua"

    local dir = outPath:match("^(.*)/[^/]+$")
    if dir and not isfolder(dir) then
        local built = rootFolder
        for segment in dir:gsub("^" .. rootFolder:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1") .. "/", ""):gmatch("[^/]+") do
            built = built .. "/" .. segment
            if not isfolder(built) then
                makefolder(built)
            end
        end
    end

    if CONFIG.skipAlreadyDumped and isfile(outPath) then
        return "skipped"
    end

    local ok, source = pcall(decompile, inst)
    if not ok or type(source) ~= "string" or source == "" then
        source = "-- decompile failed: " .. tostring(source) .. "\n-- " .. class .. " @ " .. inst:GetFullName()
    end

    local header = string.format(
        "-- Class: %s\n-- Path: %s\n-- Dumped: %s\n\n",
        class,
        inst:GetFullName(),
        os.date("!%Y-%m-%dT%H:%M:%SZ")
    )

    writefile(outPath, header .. source)
    return "ok"
end

-- ============ RUN ============
local rootFolder = getPlaceFolder()
local scripts = collectScripts()

print(string.format("[dumper] Place: %s (%s)", game.Name, game.PlaceId))
print(string.format("[dumper] Found %d client scripts", #scripts))
print("[dumper] Output: " .. rootFolder)

local stats = { ok = 0, skipped = 0, failed = 0 }

for i, inst in ipairs(scripts) do
    local result = dumpScript(rootFolder, inst)
    stats[result == "ok" and "ok" or result == "skipped" and "skipped" or "failed"] =
        stats[result == "ok" and "ok" or result == "skipped" and "skipped" or "failed"] + 1

    if i % CONFIG.logEvery == 0 then
        print(string.format("[dumper] %d / %d ...", i, #scripts))
    end
end

-- manifest
local manifest = {
    placeId = game.PlaceId,
    placeName = game.Name,
    gameId = game.GameId,
    dumpedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    total = #scripts,
    stats = stats,
    scripts = {},
}

for _, inst in ipairs(scripts) do
    manifest.scripts[#manifest.scripts + 1] = {
        class = inst.ClassName,
        path = inst:GetFullName(),
    }
end

writefile(rootFolder .. "/manifest.json", HttpService:JSONEncode(manifest))

print(string.format(
    "[dumper] Done — saved: %d, skipped: %d, failed: %d",
    stats.ok, stats.skipped, stats.failed
))
