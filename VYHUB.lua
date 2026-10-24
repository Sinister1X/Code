local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.VyPSXClassic) == "table" and type(genv.VyPSXClassic.Stop) == "function" then
    pcall(genv.VyPSXClassic.Stop)
    task.wait(0.3)
end

local K, V, G, UI, F = {}, {}, {}, {}, {}

K.TAG = "[VY PSXClassic] "
K.VERSION = "1.0.0"
K.LIB_FILE = "VyLib.lua"
K.LIB_URLS = {
    "https://raw.githubusercontent.com/92tg/VYHUB/main/VyLib.lua",
}
K.COIN_REACH_MAX = 300
K.EGG_REACH = 20
K.GATE_REACH = 35
K.FARM_STALL = 20
K.FARM_MODES = { "Nearest", "Highest Health", "Lowest Health" }
K.EGG_AMOUNTS = { "Auto (best owned)", "1", "3", "8" }
K.SKIP_EGGS = { ["Dominus Egg"] = true, ["Hacker Egg"] = true, ["Hacker Golden Egg"] = true }

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local state = {
    alive = true,
    status = "starting",
    orbs = 0,
    orbBatches = 0,
    joins = 0,
    coinsBroken = 0,
    hatched = 0,
    hatchRequests = 0,
    areasBought = 0,
    farmNote = nil,
    eggTarget = nil,
    eggNote = nil,
    areaTarget = nil,
    areaNote = nil,
}
local connections = {}
local logOnceSeen = {}

local function log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print(K.TAG .. (ok and msg or tostring(fmt)))
end
local function warnlog(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    warn(K.TAG .. (ok and msg or tostring(fmt)))
end
local function logOnce(key, fmt, ...)
    if logOnceSeen[key] then return end
    logOnceSeen[key] = true
    warnlog(fmt, ...)
end
local function track(conn)
    if conn then connections[#connections + 1] = conn end
    return conn
end

K.IDENTITY_GAME = 2
local canSetIdentity = type(setthreadidentity) == "function"
K.IDENTITY_EXEC = 7
if type(getthreadidentity) == "function" then
    local ok, id = pcall(getthreadidentity)
    if ok and type(id) == "number" then K.IDENTITY_EXEC = id end
end

local function gcall(fn, ...)
    if type(fn) ~= "function" then return false, "gcall: not a function" end
    if canSetIdentity then pcall(setthreadidentity, K.IDENTITY_GAME) end
    local r = table.pack(pcall(fn, ...))
    if canSetIdentity then pcall(setthreadidentity, K.IDENTITY_EXEC) end
    return table.unpack(r, 1, r.n)
end
local function gval(fn, ...)
    local ok, a, b, c = gcall(fn, ...)
    if ok then return a, b, c end
    return nil
end
local function isfn(t, k)
    return type(t) == "table" and type(t[k]) == "function"
end

local function notify(title, desc, dur)
    if genv.Library and type(genv.Library.Notification) == "function" then
        pcall(function() genv.Library:Notification(title, desc, dur or 5) end)
        return
    end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "VY HUB - " .. tostring(title), Text = tostring(desc), Duration = dur or 5 })
    end)
end

local function loadLibrary()
    local src
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, K.LIB_FILE)
        if ok and exists then
            local okR, content = pcall(readfile, K.LIB_FILE)
            if okR and type(content) == "string" and #content > 1000 then src = content end
        end
    end
    if not src and type(genv.VyHub_LibUrl) == "string" then
        local ok, content = pcall(game.HttpGet, game, genv.VyHub_LibUrl)
        if ok and type(content) == "string" and #content > 1000 then src = content end
    end
    if not src then
        for _, url in ipairs(K.LIB_URLS) do
            local ok, content = pcall(game.HttpGet, game, url)
            if ok and type(content) == "string" and #content > 1000 then src = content break end
        end
    end
    assert(src, "VyLib could not be loaded from github.com/92tg/VYHUB (no internet / HttpGet blocked?)")
    if genv.Library and type(genv.Library.Unload) == "function" then pcall(function() genv.Library:Unload() end) end
    local fn, err = loadstring(src, "=VyLib")
    assert(fn, "VyLib failed to compile: " .. tostring(err))
    local lib = fn()
    if lib == nil then lib = genv.Library end
    assert(type(lib) == "table", "VyLib did not return the Library table")
    genv.Library = lib
    return lib
end

Library = loadLibrary()

local function req(path)
    local ok, mod = gcall(function()
        local node = RS
        for seg in string.gmatch(path, "[^%.]+") do
            node = node:WaitForChild(seg, 5)
            if not node then error("missing " .. path) end
        end
        return require(node)
    end)
    if ok then return mod end
    logOnce("mod-" .. path, "module %s unavailable: %s", path, tostring(mod))
    return nil
end

G.Library = req("Framework.Library")
assert(type(G.Library) == "table", "PSX Classic Library (ReplicatedStorage.Framework.Library) is unavailable")
G.Network = G.Library.Network
G.Save = G.Library.Save
G.PetCmds = G.Library.PetCmds
G.WorldCmds = G.Library.WorldCmds
G.Gamepasses = G.Library.Gamepasses
G.Directory = G.Library.Directory
G.Shared = G.Library.Shared
G.RebornLock = G.Library.RebornLock
G.Yeet = req("Library.Types.Yeet")

local function findUpvalue(fn, name)
    if type(fn) ~= "function" or type(debug.getupvalues) ~= "function" then return nil end
    local ok, ups = pcall(debug.getupvalues, fn)
    if not ok or type(ups) ~= "table" then return nil end
    for _, u in pairs(ups) do
        if type(u) == "function" then
            local okN, n = pcall(debug.info, u, "n")
            if okN and n == name then return u end
        end
    end
    return nil
end

V.remoteFns = {}
V.remoteEvents = {}
local function resolveRemotes()
    if V.getName and V.remote then return true end
    local rfn = findUpvalue(G.Network and G.Network.Invoke, "_remoteFunction")
    local getName = findUpvalue(rfn, "_getName")
    local remote = findUpvalue(rfn, "_remote")
    if type(getName) == "function" and type(remote) == "function" then
        V.getName, V.remote = getName, remote
        return true
    end
    logOnce("remotes", "could not resolve the Network remote lookup; game calls are unavailable")
    return false
end
local function remoteFunction(name)
    local r = V.remoteFns[name]
    if r and r.Parent then return r end
    if not resolveRemotes() then return nil end
    local ok, inst = pcall(function() return V.remote(2, V.getName(2, name)) end)
    if ok and typeof(inst) == "Instance" then V.remoteFns[name] = inst return inst end
    logOnce("rf-" .. name, "RemoteFunction %s not found", name)
    return nil
end
local function remoteEvent(name)
    local r = V.remoteEvents[name]
    if r and r.Parent then return r end
    if not resolveRemotes() then return nil end
    local ok, inst = pcall(function() return V.remote(1, V.getName(1, name)) end)
    if ok and typeof(inst) == "Instance" then V.remoteEvents[name] = inst return inst end
    logOnce("re-" .. name, "RemoteEvent %s not found", name)
    return nil
end
local function netInvoke(name, ...)
    local rf = remoteFunction(name)
    if not rf then return false, "remote unavailable: " .. name end
    return gcall(rf.InvokeServer, rf, ...)
end
local function netFire(name, ...)
    local re = remoteEvent(name)
    if not re then return false, "remote unavailable: " .. name end
    return gcall(re.FireServer, re, ...)
end
local function onRemote(name, fn)
    local re = remoteEvent(name)
    if not re then return nil end
    return track(re.OnClientEvent:Connect(function(...)
        if not state.alive then return end
        local ok, err = pcall(fn, ...)
        if not ok then logOnce("evt-" .. name, "%s handler error: %s", name, tostring(err)) end
    end))
end

V.save = nil
V.saveAt = 0
local function getSave()
    if type(V.save) ~= "table" then
        local s = isfn(G.Save, "Get") and gval(G.Save.Get) or nil
        if type(s) == "table" then
            local copy = {}
            for k, v in pairs(s) do copy[k] = v end
            V.save = copy
            V.saveAt = os.clock()
        end
    end
    return V.save
end
local function installSaveTracker()
    onRemote("New Stats", function(changes, who)
        if who ~= nil and who ~= LocalPlayer then return end
        if type(changes) ~= "table" then return end
        local s = getSave()
        if not s then return end
        for k, v in pairs(changes) do s[k] = v end
        V.saveAt = os.clock()
    end)
end
local function currency(name)
    local s = getSave()
    local v = s and s[name]
    if type(v) == "number" then return v end
    return 0
end
local function isHardcore()
    return G.Shared and G.Shared.IsHardcore == true
end
local function hasArea(name)
    if type(name) ~= "string" or name == "" then return true end
    if not (G.Directory and G.Directory.Areas and G.Directory.Areas[name]) then return false end
    if not isfn(G.WorldCmds, "HasArea") then return false end
    return gval(G.WorldCmds.HasArea, name) == true
end
local function areaOpen(name)
    if not isfn(G.RebornLock, "AreaOpen") then return true end
    return gval(G.RebornLock.AreaOpen, name) ~= false
end
local function canDoAction()
    if not isfn(G.WorldCmds, "CanDoAction") then return true end
    return gval(G.WorldCmds.CanDoAction) ~= false
end
local function currentWorld()
    return isfn(G.WorldCmds, "Get") and gval(G.WorldCmds.Get) or "?"
end
local function shorten(n)
    n = tonumber(n) or 0
    local a = math.abs(n)
    if a >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if a >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if a >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if a >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

local function hrp()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end
local function playerPos()
    local r = hrp()
    return r and r.Position or nil
end
local function teleportTo(cf)
    local c = LocalPlayer.Character
    local r = hrp()
    if not (c and r) then return false end
    pcall(function()
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end)
    return pcall(function() c:PivotTo(cf) end)
end
local function dist(a, b)
    if not (a and b) then return math.huge end
    return (a - b).Magnitude
end
local function thingsFolder(name)
    local things = workspace:FindFirstChild("__THINGS")
    return things and things:FindFirstChild(name) or nil
end

F.antiAfk = true
local function installAntiAfk()
    pcall(function()
        if type(getconnections) == "function" then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
    end)
    local function nudge()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            local cam = workspace.CurrentCamera
            VirtualUser:Button2Down(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
            task.wait(0.05)
            VirtualUser:Button2Up(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
        end)
    end
    track(LocalPlayer.Idled:Connect(function()
        if not (F.antiAfk and state.alive) then return end
        nudge()
    end))
    task.spawn(function()
        while state.alive do
            task.wait(60)
            if F.antiAfk and state.alive then nudge() end
        end
    end)
    log("anti-AFK installed")
end

F.autoOrbs = false
V.orbQueue = {}
V.orbSeen = {}
local function queueOrb(id)
    if type(id) ~= "string" or V.orbSeen[id] then return end
    V.orbSeen[id] = os.clock()
    V.orbQueue[#V.orbQueue + 1] = id
end
local function installOrbListener()
    onRemote("Orb Added", function(id)
        if F.autoOrbs then queueOrb(id) end
    end)
    onRemote("Orb Removed", function(id)
        if type(id) == "string" then V.orbSeen[id] = nil end
    end)
end
local function sweepOrbs()
    local folder = thingsFolder("Orbs")
    if not folder then return end
    for _, part in ipairs(folder:GetChildren()) do queueOrb(part.Name) end
end
local function orbTick()
    if not F.autoOrbs then
        if #V.orbQueue > 0 then V.orbQueue = {} end
        return
    end
    if #V.orbQueue == 0 then return end
    local ids = V.orbQueue
    V.orbQueue = {}
    local ok, err = netFire("Claim Orbs", ids)
    if ok then
        state.orbs += #ids
        state.orbBatches += 1
    else
        logOnce("claim-orbs", "Claim Orbs failed: %s", tostring(err))
    end
    local now = os.clock()
    for id, t in pairs(V.orbSeen) do
        if now - t > 120 then V.orbSeen[id] = nil end
    end
end

F.autoFarm = false
F.farmMode = K.FARM_MODES[1]
F.farmRange = 150
V.coinHealth = {}
V.farmTarget = nil
V.farmJoinedAt = 0
V.farmLastHit = 0
V.farmPets = {}

local function coinsFolder()
    return thingsFolder("Coins")
end
V.serverCoins = nil
V.serverCoinsAt = 0
V.coinBlock = {}
local function refreshServerCoins()
    if os.clock() - V.serverCoinsAt < 5 then return V.serverCoins end
    V.serverCoinsAt = os.clock()
    local ok, res = netInvoke("Get Coins")
    if ok and type(res) == "table" then
        V.serverCoins = res
        for id, data in pairs(res) do
            if type(data) == "table" and type(data.h) == "number" and V.coinHealth[id] == nil then V.coinHealth[id] = data.h end
        end
    end
    return V.serverCoins
end
local function coinHealth(folder)
    local h = V.coinHealth[folder.Name]
    if type(h) ~= "number" then
        local s = V.serverCoins and V.serverCoins[folder.Name]
        h = (type(s) == "table" and tonumber(s.h)) or tonumber(folder:GetAttribute("Health")) or 0
    end
    return h
end
local function coinPos(folder)
    local pos = folder:FindFirstChild("POS")
    if pos and pos:IsA("BasePart") then return pos.Position end
    local ok, p = pcall(function() return folder:GetPivot().Position end)
    return ok and p or nil
end
local function coinOk(folder)
    if not (folder and folder.Parent) then return false end
    if folder:GetAttribute("ID") == nil then return false end
    if V.serverCoins and V.serverCoins[folder.Name] == nil then return false end
    if (V.coinBlock[folder.Name] or 0) > os.clock() then return false end
    local area = folder:GetAttribute("Area")
    if type(area) == "string" and area ~= "" then
        if not hasArea(area) then return false end
        if isfn(G.RebornLock, "CoinAreaOpen") and gval(G.RebornLock.CoinAreaOpen, area) == false then return false end
    end
    local model = folder:FindFirstChild("Coin")
    if model and model:GetAttribute("PreventClick") then return false end
    return coinHealth(folder) > 0
end
local function installCoinListeners()
    onRemote("Update Coin Health", function(id, h)
        if type(id) == "string" and type(h) == "number" then
            V.coinHealth[id] = h
            if V.farmTarget and V.farmTarget.Name == id then V.farmLastHit = os.clock() end
        end
    end)
    onRemote("Remove Coin", function(id)
        if type(id) ~= "string" then return end
        V.coinHealth[id] = nil
        if V.farmTarget and V.farmTarget.Name == id then
            if V.farmLastHit > 0 then state.coinsBroken += 1 end
            local pets = V.farmPets
            V.farmTarget = nil
            V.farmPets = {}
            for _, uid in ipairs(pets) do netFire("Change Pet Target", uid, "Player") end
        end
    end)
end
local function releasePets(uids, lastId)
    if lastId then netInvoke("Leave Coin", lastId, uids) end
    for _, uid in ipairs(uids) do netFire("Change Pet Target", uid, "Player") end
end
local function petUids()
    local list = {}
    if not isfn(G.PetCmds, "GetEquipped") then return list end
    local eq = gval(G.PetCmds.GetEquipped)
    if type(eq) ~= "table" then return list end
    for _, p in ipairs(eq) do
        if type(p) == "table" and type(p.uid) == "string" then list[#list + 1] = p.uid end
    end
    return list
end
local function pickCoin()
    local folder = coinsFolder()
    local p = playerPos()
    if not (folder and p) then return nil end
    refreshServerCoins()
    local best, bestScore
    for _, c in ipairs(folder:GetChildren()) do
        if coinOk(c) then
            local pos = coinPos(c)
            local d = pos and dist(pos, p) or math.huge
            if d <= F.farmRange then
                local score
                if F.farmMode == "Highest Health" then
                    score = -coinHealth(c)
                elseif F.farmMode == "Lowest Health" then
                    score = coinHealth(c)
                else
                    score = d
                end
                if not bestScore or score < bestScore then best, bestScore = c, score end
            end
        end
    end
    return best
end
local function joinCoin(folder)
    local uids = petUids()
    if #uids == 0 then
        state.farmNote = "no pets equipped"
        return false
    end
    local id = folder:GetAttribute("ID") or folder.Name
    local ok, res = netInvoke("Join Coin", id, uids)
    if not ok then
        state.farmNote = "Join Coin error: " .. tostring(res)
        return false
    end
    if type(res) ~= "table" then
        state.farmNote = "Join Coin refused (" .. tostring(res) .. ")"
        return false
    end
    local joined, msg = {}, nil
    for _, uid in ipairs(uids) do
        local r = res[uid]
        if r == true then
            joined[#joined + 1] = uid
            netFire("Change Pet Target", uid, "Coin", id)
            netFire("Farm Coin", id, uid)
        elseif type(r) == "string" then
            msg = r
        end
    end
    state.joins += 1
    if #joined == 0 then
        state.farmNote = msg or "no pet accepted the coin, releasing pets"
        V.coinBlock[id] = os.clock() + 30
        releasePets(uids, V.lastTargetId)
        return false
    end
    V.farmTarget = folder
    V.lastTargetId = id
    V.farmPets = joined
    V.farmJoinedAt = os.clock()
    V.farmLastHit = 0
    state.farmNote = msg
    return true
end
local function farmTick()
    if not F.autoFarm then
        V.farmTarget = nil
        return
    end
    if not canDoAction() then
        state.status = "waiting (world loading / busy)"
        return
    end
    local t = V.farmTarget
    if t and not (t.Parent and coinHealth(t) > 0) then
        V.farmTarget = nil
        t = nil
    end
    if t then
        if V.farmLastHit > V.farmJoinedAt then V.farmRej = 0 end
        local since = os.clock() - math.max(V.farmJoinedAt, V.farmLastHit)
        if since > K.FARM_STALL then
            local id = t:GetAttribute("ID") or t.Name
            V.farmRej = (V.farmRej or 0) + 1
            releasePets(V.farmPets, id)
            if V.farmRej > 3 then
                V.farmRej = 0
                V.farmTarget = nil
                V.coinBlock[t.Name] = os.clock() + 30
                return
            end
            V.farmJoinedAt = os.clock()
            joinCoin(t)
        end
        state.status = string.format("farming %s (%s hp)", tostring(t:GetAttribute("Name")), shorten(coinHealth(t)))
        return
    end
    V.farmRej = 0
    local pick = pickCoin()
    if not pick then
        state.status = string.format("no breakable within %d studs", F.farmRange)
        return
    end
    if joinCoin(pick) then
        state.status = string.format("farming %s (%s hp)", tostring(pick:GetAttribute("Name")), shorten(coinHealth(pick)))
    else
        state.status = "join failed: " .. tostring(state.farmNote)
        task.wait(1)
    end
end

F.autoEgg = false
F.eggPercent = 100
F.eggDelay = 1
F.eggGolden = false
F.eggAmount = K.EGG_AMOUNTS[1]
F.eggTeleport = true
F.eggReturn = true

local function masteryLevel(key)
    local s = getSave()
    local xp = s and type(s.Mastery) == "table" and s.Mastery[key] or 0
    if isfn(G.Shared, "MasteryXPToLevel") then
        local lvl = gval(G.Shared.MasteryXPToLevel, xp)
        if type(lvl) == "number" then return lvl end
    end
    return 0
end
local function masteryMult(golden)
    local dir = G.Directory and G.Directory.Mastery
    local entry = dir and dir[golden and "Golden Eggs" or "Eggs"]
    local perks = entry and entry.perks
    if type(perks) ~= "table" then return 1 end
    local lvl = masteryLevel(golden and "Golden Eggs" or "Eggs")
    local p2, p4 = perks[2], perks[4]
    if golden then
        if p4 and p4.level <= lvl then return 0.85 end
        if p2 and p2.level <= lvl then return 0.95 end
    else
        if p4 and p4.level <= lvl then return 0.8 end
        if p2 and p2.level <= lvl then return 0.9 end
    end
    return 1
end
local function yeetMult()
    local s = getSave()
    local tier = s and type(s.Upgrades) == "table" and s.Upgrades["Yeet Egg Price"] or 0
    local tbl = G.Yeet and type(G.Yeet.Upgrades) == "table" and G.Yeet.Upgrades["Yeet Egg Price"]
    if type(tier) == "number" and tier > 0 and type(tbl) == "table" and type(tbl[tier]) == "number" then return tbl[tier] end
    return 1
end
local function eggCost(dir)
    if type(dir) ~= "table" then return nil end
    local base = (isHardcore() and dir.hardcoreCost) or dir.cost
    if type(base) ~= "number" then return nil end
    local mult = dir.isYeet and yeetMult() or masteryMult(dir.isGolden == true)
    return math.round(base * mult)
end
local function eggUnlocked(id, depth)
    depth = depth or 0
    if depth > 8 then return false end
    local dir = G.Directory and G.Directory.Eggs and G.Directory.Eggs[id]
    if type(dir) ~= "table" then return false end
    if K.SKIP_EGGS[id] then return false end
    if dir.areaRequired and not hasArea(dir.area) then return false end
    local reqEgg = dir.eggRequired
    if type(reqEgg) == "string" and reqEgg ~= "" and reqEgg ~= id and not eggUnlocked(reqEgg, depth + 1) then return false end
    if type(reqEgg) == "string" and reqEgg ~= "" and (tonumber(dir.eggRequiredOpenAmount) or 0) > 0 then
        local s = getSave()
        local opened = s and (isHardcore() and type(s.Hardcore) == "table" and s.Hardcore.EggsOpened or s.EggsOpened)
        local n = type(opened) == "table" and opened[reqEgg] or 0
        if (tonumber(n) or 0) < dir.eggRequiredOpenAmount then return false end
    end
    return true
end
local function allEggs()
    if isfn(G.WorldCmds, "GetAllEggs") then
        local list = gval(G.WorldCmds.GetAllEggs)
        if type(list) == "table" then return list end
    end
    return {}
end
local function bestEgg()
    local best, bestCost
    for _, m in ipairs(allEggs()) do
        local id = m:GetAttribute("ID")
        local dir = type(id) == "string" and G.Directory.Eggs[id] or nil
        if type(dir) == "table" and not dir.disabled and dir.hatchable ~= false and not dir.isYeet and (F.eggGolden or not dir.isGolden) then
            if eggUnlocked(id) then
                local cost = eggCost(dir)
                if cost and (not bestCost or cost > bestCost) then
                    best, bestCost = { model = m, id = id, dir = dir, cost = cost, currency = dir.currency or "Coins" }, cost
                end
            end
        end
    end
    return best
end
local function eggAmountFlags()
    local s = getSave()
    local ownsOct = s and s.OwnsOctupleEggs == true
    local pass = G.Directory and G.Directory.Gamepasses and G.Directory.Gamepasses["Triple Egg Open"]
    local ownsTriple = pass and pass.ID and isfn(G.Gamepasses, "Owns") and gval(G.Gamepasses.Owns, pass.ID) == true
    local choice = F.eggAmount
    if choice == "8" then return false, ownsOct, ownsOct and 8 or 1 end
    if choice == "3" then return ownsTriple, false, ownsTriple and 3 or 1 end
    if choice == "1" then return false, false, 1 end
    if ownsOct then return false, true, 8 end
    if ownsTriple then return true, false, 3 end
    return false, false, 1
end
local function eggStandCFrame(model)
    local center = model:FindFirstChild("Center")
    local base = (center and center:IsA("BasePart")) and center.CFrame or model:GetPivot()
    return base * CFrame.new(0, 3, 8)
end
local function eggTick()
    if not F.autoEgg then
        state.eggTarget = nil
        return
    end
    local egg = bestEgg()
    state.eggTarget = egg
    if not egg then
        state.eggNote = "no unlocked egg in this world"
        return
    end
    local have = currency(egg.currency)
    local need = egg.cost * math.max(1, F.eggPercent) / 100
    if have < need then
        state.eggNote = string.format("waiting: %s / %s %s", shorten(have), shorten(need), egg.currency)
        return
    end
    if not canDoAction() then
        state.eggNote = "waiting (busy)"
        return
    end
    local p = playerPos()
    local standCf = eggStandCFrame(egg.model)
    local far = p and dist(p, standCf.Position) > K.EGG_REACH
    local origin = far and hrp() and hrp().CFrame or nil
    if far then
        if not F.eggTeleport then
            state.eggNote = "too far from the egg (teleport disabled)"
            return
        end
        teleportTo(standCf)
        task.wait(0.35)
    end
    local triple, octuple, amount = eggAmountFlags()
    state.hatchRequests += 1
    local ok, res, msg = netInvoke("Buy Egg", egg.id, triple, octuple)
    if ok and res == true then
        state.hatched += amount
        state.eggNote = string.format("bought %s x%d", egg.id, amount)
    else
        state.eggNote = "Buy Egg: " .. tostring(ok and msg or res)
    end
    if origin and F.eggReturn then
        task.wait(0.3)
        teleportTo(origin)
    end
end

F.autoArea = false
F.areaTeleport = true
F.areaReturn = true

local function allGates()
    if isfn(G.WorldCmds, "GetAllGates") then
        local list = gval(G.WorldCmds.GetAllGates)
        if type(list) == "table" then return list end
    end
    return {}
end
local function nextGate()
    local best
    for _, gate in ipairs(allGates()) do
        local name = gate.Name
        local area = G.Directory and G.Directory.Areas and G.Directory.Areas[name]
        local g = type(area) == "table" and type(area.gate) == "table" and area.gate or nil
        if g and type(g.cost) == "number" and not area.hideGatePurchase and not hasArea(name) and areaOpen(name) then
            local part = gate:FindFirstChildWhichIsA("BasePart")
            if part and (not best or g.cost < best.cost) then
                best = { gate = gate, part = part, name = name, cost = g.cost, currency = g.currency or "Coins" }
            end
        end
    end
    return best
end
local function areaTick()
    if not F.autoArea then
        state.areaTarget = nil
        return
    end
    local gate = nextGate()
    state.areaTarget = gate
    if not gate then
        state.areaNote = "every gate in this world is unlocked"
        return
    end
    local have = currency(gate.currency)
    if have < gate.cost then
        state.areaNote = string.format("saving for %s: %s / %s %s", gate.name, shorten(have), shorten(gate.cost), gate.currency)
        return
    end
    if not canDoAction() then
        state.areaNote = "waiting (busy)"
        return
    end
    local p = playerPos()
    local standCf = gate.part.CFrame * CFrame.new(0, 0, 12)
    local far = p and dist(p, gate.part.Position) > K.GATE_REACH
    local origin = far and hrp() and hrp().CFrame or nil
    if far then
        if not F.areaTeleport then
            state.areaNote = "too far from the gate (teleport disabled)"
            return
        end
        teleportTo(standCf)
        task.wait(0.35)
    end
    local ok, res, msg = netInvoke("Buy Area", gate.name)
    if ok and res == true then
        state.areasBought += 1
        state.areaNote = "bought " .. gate.name
        notify("PSX Classic", "Unlocked " .. gate.name, 5)
    else
        state.areaNote = "Buy Area: " .. tostring(ok and msg or res)
    end
    if origin and F.areaReturn then
        task.wait(0.3)
        teleportTo(origin)
    end
end

local function loop(name, interval, fn)
    task.spawn(function()
        while state.alive do
            local ok, err = pcall(fn)
            if not ok then logOnce("loop-" .. name .. tostring(err):sub(1, 40), "%s loop error: %s", name, tostring(err)) end
            local dt = type(interval) == "function" and interval() or interval
            task.wait(dt)
        end
    end)
end

loop("orbs", 0.25, orbTick)
loop("farm", 1, farmTick)
loop("egg", function() return math.max(0.3, F.eggDelay) end, eggTick)
loop("area", 2, areaTick)

if type(Library.ExecutorSettings) ~= "table" or type(Library.ExecutorSettings.MenuKeybind) ~= "string" or Library.ExecutorSettings.MenuKeybind == "" then
    pcall(function() Library:SetMenuKeybind(Enum.KeyCode.RightShift) end)
end

local isMobile = false
pcall(function() isMobile = Library:IsMobileClient() end)

UI.Window = Library:CreateWindow({
    Name = "VY HUB",
    SubName = "PSX Classic",
    Logo = "egg",
    ToggleButtonEnabled = isMobile,
    KeybindListEnabled = false,
    SettingsTabEnabled = true,
    WatermarkEnabled = true,
    WatermarkText = "VY HUB | PSX Classic",
    Theme = "Onyx",
})

local function tab(name, icon)
    return UI.Window:AddTab({ Name = name, Icon = icon })
end
local function section(t, name)
    return t:AddSection({ Name = name })
end
local function num(v, fallback)
    local n = tonumber(v)
    if n == nil or n ~= n then return fallback end
    return n
end

UI.MainTab = tab("Main", "egg")
UI.StatusSec = section(UI.MainTab, "Status")
UI.lblStatus = UI.StatusSec:AddLabel("Status: starting")
UI.lblMoney = UI.StatusSec:AddLabel("Coins: - | Diamonds: -")
UI.lblWorld = UI.StatusSec:AddLabel("World: -")
UI.lblCounters = UI.StatusSec:AddLabel("Orbs: 0 | Coins broken: 0 | Eggs: 0 | Areas: 0")

UI.FarmSec = section(UI.MainTab, "Farming")
UI.FarmSec:AddToggle({ Name = "Auto Farm Breakables (Tap Once, Pets Farm)", Default = false, Flag = "px_autoFarm", Callback = function(v) F.autoFarm = v V.farmTarget = nil end })
UI.FarmSec:AddDropdown({ Name = "Target", Items = K.FARM_MODES, Default = F.farmMode, Flag = "px_farmMode", Callback = function(v)
    if type(v) == "string" then F.farmMode = v V.farmTarget = nil end
end })
UI.FarmSec:AddSlider({ Name = "Breakable Range", Min = 30, Max = K.COIN_REACH_MAX, Default = F.farmRange, Decimals = 10, Suffix = " studs", Flag = "px_farmRange", Callback = function(v) F.farmRange = math.clamp(num(v, F.farmRange), 30, K.COIN_REACH_MAX) end })
UI.FarmSec:AddToggle({ Name = "Auto Collect Orbs (Instant)", Default = false, Flag = "px_autoOrbs", Callback = function(v) F.autoOrbs = v if v then sweepOrbs() end end })
UI.lblFarm = UI.FarmSec:AddLabel("Target: -")

UI.EggTab = tab("Eggs", "egg-fried")
UI.EggSec = section(UI.EggTab, "Auto Hatch")
UI.lblEgg = UI.EggSec:AddLabel("Best egg: -")
UI.EggSec:AddToggle({ Name = "Auto Buy Best Unlocked Egg", Default = false, Flag = "px_autoEgg", Callback = function(v) F.autoEgg = v end })
UI.EggSec:AddSlider({ Name = "Buy When Money Is Above X% Of Price", Min = 100, Max = 1000, Default = 100, Decimals = 5, Suffix = "%", Flag = "px_eggPercent", Callback = function(v) F.eggPercent = math.clamp(num(v, F.eggPercent), 100, 1000) end })
UI.EggSec:AddDropdown({ Name = "Eggs Per Buy", Items = K.EGG_AMOUNTS, Default = F.eggAmount, Flag = "px_eggAmount", Callback = function(v)
    if type(v) == "string" then F.eggAmount = v end
end })
UI.EggSec:AddSlider({ Name = "Buy Delay", Min = 0.3, Max = 5, Default = 1, Decimals = 0.1, Suffix = "s", Flag = "px_eggDelay", Callback = function(v) F.eggDelay = math.clamp(num(v, F.eggDelay), 0.3, 5) end })
UI.EggSec:AddToggle({ Name = "Prefer Golden Eggs", Default = false, Flag = "px_eggGolden", Callback = function(v) F.eggGolden = v end })
UI.EggSec:AddToggle({ Name = "Teleport To The Egg When Buying", Default = true, Flag = "px_eggTeleport", Callback = function(v) F.eggTeleport = v end })
UI.EggSec:AddToggle({ Name = "Return After Buying", Default = true, Flag = "px_eggReturn", Callback = function(v) F.eggReturn = v end })
UI.lblEggNote = UI.EggSec:AddLabel("Eggs: -")

UI.AreaTab = tab("Areas", "map")
UI.AreaSec = section(UI.AreaTab, "Auto Unlock")
UI.lblArea = UI.AreaSec:AddLabel("Next area: -")
UI.AreaSec:AddToggle({ Name = "Auto Buy Next Area", Default = false, Flag = "px_autoArea", Callback = function(v) F.autoArea = v end })
UI.AreaSec:AddToggle({ Name = "Teleport To The Gate When Buying", Default = true, Flag = "px_areaTeleport", Callback = function(v) F.areaTeleport = v end })
UI.AreaSec:AddToggle({ Name = "Return After Buying", Default = true, Flag = "px_areaReturn", Callback = function(v) F.areaReturn = v end })
UI.lblAreaNote = UI.AreaSec:AddLabel("Areas: -")

UI.MiscTab = tab("Misc", "settings-2")
UI.PatchSec = section(UI.MiscTab, "Patches")
UI.PatchSec:AddToggle({ Name = "Anti AFK", Default = true, Flag = "px_antiAfk", Callback = function(v) F.antiAfk = v end })
UI.CtrlSec = section(UI.MiscTab, "Script")
UI.CtrlSec:AddLabel("VY HUB PSX Classic v" .. K.VERSION)
UI.CtrlSec:AddLabel("Made By Vy | .gg/Fgaw3JZt6w")
UI.CtrlSec:AddButton({ Name = "Stop Script", Callback = function()
    if genv.VyPSXClassic then genv.VyPSXClassic.Stop() end
end })

pcall(function() UI.Window:CreateInfoPage({}) end)
pcall(function() UI.Window:HideLoading() end)

local function setText(lbl, text)
    if lbl and type(lbl.SetText) == "function" then pcall(lbl.SetText, lbl, text) end
end
loop("ui", 1, function()
    setText(UI.lblStatus, "Status: " .. tostring(state.status))
    setText(UI.lblMoney, string.format("Coins: %s | Diamonds: %s", shorten(currency("Coins")), shorten(currency("Diamonds"))))
    setText(UI.lblWorld, string.format("World: %s%s", tostring(currentWorld()), isHardcore() and " (hardcore)" or ""))
    setText(UI.lblCounters, string.format("Orbs: %d | Coins broken: %d | Eggs: %d | Areas: %d", state.orbs, state.coinsBroken, state.hatched, state.areasBought))
    local t = V.farmTarget
    if t and t.Parent then
        setText(UI.lblFarm, string.format("Target: %s  -  %s hp, %d pets%s", tostring(t:GetAttribute("Name")), shorten(coinHealth(t)), #V.farmPets, state.farmNote and (" | " .. tostring(state.farmNote)) or ""))
    else
        setText(UI.lblFarm, "Target: -" .. (state.farmNote and (" | " .. tostring(state.farmNote)) or ""))
    end
    local egg = F.autoEgg and state.eggTarget or bestEgg()
    if egg then
        setText(UI.lblEgg, string.format("Best egg: %s for %s %s", egg.id, shorten(egg.cost), egg.currency))
    else
        setText(UI.lblEgg, "Best egg: none unlocked here")
    end
    setText(UI.lblEggNote, string.format("Eggs: %d bought (%d requests)%s", state.hatched, state.hatchRequests, state.eggNote and (" | " .. tostring(state.eggNote)) or ""))
    local gate = F.autoArea and state.areaTarget or nextGate()
    if gate then
        setText(UI.lblArea, string.format("Next area: %s for %s %s%s", gate.name, shorten(gate.cost), gate.currency, currency(gate.currency) >= gate.cost and " (you can afford it)" or ""))
    else
        setText(UI.lblArea, "Next area: everything here is unlocked")
    end
    setText(UI.lblAreaNote, string.format("Areas: %d bought%s", state.areasBought, state.areaNote and (" | " .. tostring(state.areaNote)) or ""))
end)

resolveRemotes()
pcall(installSaveTracker)
pcall(installOrbListener)
pcall(installCoinListeners)
pcall(installAntiAfk)

genv.VyPSXClassic = {
    Stop = function()
        if not state.alive then return end
        state.alive = false
        F.autoOrbs, F.autoFarm, F.autoEgg, F.autoArea = false, false, false, false
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
        pcall(function() if genv.Library and genv.Library.Unload then genv.Library:Unload() end end)
        log("stopped")
    end,
    State = state,
    Features = F,
    Vars = V,
    Debug = { pickCoin = pickCoin, joinCoin = joinCoin, farmTick = farmTick, bestEgg = bestEgg, eggCost = eggCost, eggTick = eggTick, nextGate = nextGate, areaTick = areaTick, currency = currency, getSave = getSave, petUids = petUids, netInvoke = netInvoke, netFire = netFire, remoteFunction = remoteFunction, remoteEvent = remoteEvent, orbTick = orbTick, sweepOrbs = sweepOrbs },
}

pcall(function()
    if type(Library.OnUnload) == "function" then
        Library:OnUnload(function()
            if state.alive then
                state.alive = false
                for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
            end
        end)
    end
end)

state.status = "idle"
notify("VY HUB", "PSX Classic loaded - RightShift opens the menu", 6)
pcall(function() Library:LoadAutoloadConfig(true) end)
log("loaded v%s (identity %d, remotes %s)", K.VERSION, K.IDENTITY_EXEC, (V.getName and V.remote) and "resolved" or "unresolved")
