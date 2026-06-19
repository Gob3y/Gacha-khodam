-- // ============================================================ \\ --
-- //          HAIMIYACH HUB | Grow a Garden 2        \\ --
-- // ============================================================ \\ --
--  Game : Grow a Garden 2   Place: 97598239454123   Framework: Standard
--  Net  : local Net = require(ReplicatedStorage.SharedModules.Networking)
--         Net.<Category>.<Action>:Fire(args...)   (single Packet RemoteEvent transport)
--         :Fire is universal — events ignore the return, requests consume it.
--  State: require(ReplicatedStorage.ClientModules.PlayerStateClient):WaitForLocalReplica(30).Data
--           .Sheckles .Tokens .Inventory.{Seeds,Pets,Eggs,Crates,SeedPacks,Sprinklers,...}
--           .PurchasedThisRestock.Seeds  .OwnedExpansions
--         Stock : ReplicatedStorage.StockValues.{SeedShop,GearShop}.Items.<Name>.Value
--         Plot  : workspace.Gardens.Plot<LocalPlayer:GetAttribute("PlotId")>  (PlantArea-tagged parts)
--  All signatures verified from the v5 decompile (14-agent extraction). LIVE-TEST PENDING.
--  Full API map: ./API_REFERENCE.md
--
--  VERIFIED CORE CALLS
--    SeedShop.PurchaseSeed:Fire(seedName)                        buy 1 seed (string name)
--    Plant.PlantSeed:Fire(worldPos, seedAttr, seedTool)         worldPos on PlantArea in own plot; tool has attr "SeedTool"
--    Garden.CollectFruit:Fire(plantId, fruitId)                 string attrs off ripe fruit (tag "HarvestPrompt")
--    NPCS.SellAll:Fire() -> {Success,SoldCount,SellPrice}       sell all fruit
--    Actions.ExpandGarden:Fire()                                expand own garden (affordability-gated)
--    Garden.PotPlant:Fire(plantId)
--    Place.PlaceSprinkler:Fire(pos, name, tool, plotId)         tool attr "Sprinkler"
--    WateringCan.UseWateringCan:Fire(pos-(0,.3,0), name, tool)  tool attr "WateringCan"
--    SkillPoints.SpendSkillPoint:Fire("BaseSpeed"|"BaseJump"|"ShovelPower"|"MaxBackpack")
--    Pets.GetEquippedPets:Fire() / RequestEquipByName(name) / RequestUnequipByName(name) / RequestPurchasePetSlot()
--    Pets.WildPetTame:Fire(refPart)                             parts in workspace.WildPetRef
--    Egg.OpenEgg:Fire(name)->{Success} (ConfirmEgg auto via ReplicateOpenEgg) | Crate.OpenCrate:Fire(name) | SeedPack.OpenSeedPack:Fire(name)
--    GearShop.PurchaseGear:Fire(name) / EquipGear:Fire(name)
--    Steal.BeginSteal:Fire(ownerUserId, plantId, fruitId) then Steal.CompleteSteal:Fire()   (tag "StealPrompt", night)
--    Mailbox.OpenInbox:Fire()->inbox / Mailbox.Claim:Fire(giftId)
--    NPCS.SellPet:Fire(petId) | NPCS.UseDailyDealAll:Fire() | Settings.SubmitCode:Fire(code) | AntiAfk.RequestHop:Fire()
-- // ============================================================ \\ --

-- External MacLib UI removed. HAIMIYACH HUB custom UI is used below.

-- re-exec guard: if loaded again this session, stop the previous instance (no duplicate engines)
pcall(function()
    local prev = getgenv and getgenv().HaimiyachGAG2
    if prev then
        if prev.S then prev.S.killed = true end
        if prev.unload then pcall(prev.unload) end
    end
end)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")
local HttpService        = game:GetService("HttpService")
local CollectionService  = game:GetService("CollectionService")
local Lighting           = game:GetService("Lighting")
local RunService         = game:GetService("RunService")
local TeleportService    = game:GetService("TeleportService")
local GuiService         = game:GetService("GuiService")
local VirtualUser        = pcall(function() return game:GetService("VirtualUser") end) and game:GetService("VirtualUser") or nil
local LocalPlayer        = Players.LocalPlayer

pcall(function()
    if setthreadidentity then setthreadidentity(8) end
    if syn and syn.set_thread_identity then syn.set_thread_identity(8) end
end)

-- block ALL Robux purchase prompts so no farm action can pop a real-money dialog
pcall(function()
    local nc = newcclosure or function(f) return f end
    local oldNc
    local function blocker(self, ...)
        local m = getnamecallmethod and getnamecallmethod()
        if type(m) == "string" and string.sub(m, 1, 6) == "Prompt" and string.find(m, "Purchase") then return end
        return oldNc(self, ...)
    end
    if hookmetamethod then
        oldNc = hookmetamethod(game, "__namecall", nc(blocker))
    elseif getrawmetatable and setreadonly then
        local mt = getrawmetatable(game); oldNc = mt.__namecall
        setreadonly(mt, false); mt.__namecall = nc(blocker); setreadonly(mt, true)
    end
end)

-- // ============================================================ \\ --
-- //                       NETWORK / DATA                         \\ --
-- // ============================================================ \\ --
local Net
do
    local sm = ReplicatedStorage:WaitForChild("SharedModules", 15)
    local mod = sm and sm:FindFirstChild("Networking")
    if mod then local ok, m = pcall(require, mod); if ok then Net = m end end
end
if not Net then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "HAIMIYACH HUB",
            Text = "Networking module not found. Wrong game?",
            Duration = 8
        })
    end)
    return
end

-- light global pacer + jitter (precautionary; GAG2 has no proven AC vector yet)
local _rl = { w = 0, c = 0, cap = 60 }
local function pace()
    local now = os.clock()
    if now - _rl.w >= 1 then _rl.w = now; _rl.c = 0 end
    if _rl.c >= _rl.cap then task.wait(0.05); return pace() end
    _rl.c = _rl.c + 1
end
local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end

local function action(path)
    local cur = Net
    for part in string.gmatch(path, "[^.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end
local function fire(path, ...)            -- fire-and-forget OR returns value (both via :Fire)
    local a = action(path)
    if not (a and a.Fire) then return false, "no action: " .. path end
    pace()
    local args = table.pack(...)
    local ok, res = pcall(function() return a:Fire(table.unpack(args, 1, args.n)) end)
    if not ok then return false, res end
    return true, res
end
-- NO pacer: for the high-volume harvest/sell hot path (the 60/s pacer throttled it to ~0).
local function fireFast(path, ...)
    local a = action(path)
    if not (a and a.Fire) then return false, "no action: " .. path end
    local args = table.pack(...)
    local ok, res = pcall(function() return a:Fire(table.unpack(args, 1, args.n)) end)
    if not ok then return false, res end
    return true, res
end

-- local-player replica (Sheckles / Tokens / Inventory / PurchasedThisRestock / OwnedExpansions)
local _replica
local function replica()
    if _replica then return _replica end
    local ok, psc = pcall(function() return require(ReplicatedStorage.ClientModules.PlayerStateClient) end)
    if ok and psc and psc.WaitForLocalReplica then
        local ok2, r = pcall(function() return psc:WaitForLocalReplica(30) end)
        if ok2 and r then _replica = r end
    end
    return _replica
end
local function pdata() local r = replica(); return (r and r.Data) or {} end
local function getSheckles() return tonumber(pdata().Sheckles) or 0 end
local function getTokens()   return tonumber(pdata().Tokens) or 0 end
local function inv(category) local i = pdata().Inventory; return (i and i[category]) or {} end
local function fmt(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n/1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.2fK", n/1e3)
    else return tostring(math.floor(n)) end
end
-- extract a usable item "name" + count from an inventory entry (shape varies: count-by-name or uuid->record)
local function invNames(category)
    local out = {}                       -- { name = totalCount }
    for k, v in pairs(inv(category)) do
        local name, count
        if type(v) == "table" then
            name = v.Name or v.ItemName or v.Type or (type(k) == "string" and not v.Name and k) or tostring(k)
            count = tonumber(v.Count) or tonumber(v.Amount) or 1
        elseif type(v) == "number" then
            name, count = tostring(k), v
        else
            name, count = tostring(k), 1
        end
        if name then out[name] = (out[name] or 0) + (count or 1) end
    end
    return out
end

-- // ============================================================ \\ --
-- //                         CATALOGS                             \\ --
-- // ============================================================ \\ --
local function seedCatalog()
    local out = {}
    local ok, data = pcall(function() return require(ReplicatedStorage.SharedModules.SeedData) end)
    if ok and type(data) == "table" then
        for _, e in pairs(data) do
            if type(e) == "table" and e.SeedName and e.RestockShop ~= false and e.PurchasePrice then
                out[#out + 1] = { name = e.SeedName, price = tonumber(e.PurchasePrice) or 0, rarity = e.Rarity or "" }
            end
        end
    end
    table.sort(out, function(a, b) return a.price < b.price end)
    if #out == 0 then
        for _, n in ipairs({ "Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Bamboo","Corn",
            "Cactus","Pineapple","Mushroom","Green Bean","Banana","Grape","Coconut","Mango","Dragon Fruit",
            "Acorn","Cherry","Sunflower","Venus Fly Trap","Pomegranate","Poison Apple","Moon Bloom",
            "Dragon's Breath","Ghost Pepper","Poison Ivy" }) do out[#out + 1] = { name = n, price = 0, rarity = "" } end
    end
    return out
end
local function gearCatalog()
    local out, seen = {}, {}
    local ok, data = pcall(function() return require(ReplicatedStorage.SharedModules.GearShopData) end)
    if ok and data and type(data.Data) == "table" then
        for _, e in pairs(data.Data) do
            if type(e) == "table" and e.ItemName and not e.RobuxOnly then
                if not seen[e.ItemName] then seen[e.ItemName] = true; out[#out + 1] = e.ItemName end
            end
        end
    end
    if #out == 0 then  -- fall back to live stock items
        local ok2, items = pcall(function() return ReplicatedStorage.StockValues.GearShop.Items end)
        if ok2 and items then for _, c in ipairs(items:GetChildren()) do out[#out + 1] = c.Name end end
    end
    table.sort(out)
    return out
end
local CATALOG = seedCatalog()
local SEED_NAMES = {} ; for _, s in ipairs(CATALOG) do SEED_NAMES[#SEED_NAMES + 1] = s.name end
local GEAR_NAMES = gearCatalog()

local function stockOf(shop, name)
    local ok, items = pcall(function() return ReplicatedStorage.StockValues[shop].Items end)
    if not ok or not items then return nil end
    local v = items:FindFirstChild(name)
    return v and tonumber(v.Value) or 0
end

-- // ============================================================ \\ --
-- //                  PLOT / TOOLS / WORLD STATE                  \\ --
-- // ============================================================ \\ --
local function myPlot()
    local id = LocalPlayer:GetAttribute("PlotId")
    local gardens = Workspace:FindFirstChild("Gardens")
    if not (id and gardens) then return nil end
    return gardens:FindFirstChild("Plot" .. tostring(id))
end
local function myPlotId() return LocalPlayer:GetAttribute("PlotId") end
local function humanoid() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end

-- tools in Backpack+Character carrying attribute `attr` (optionally matching a name)
local function toolsByAttr(attr, wantName)
    local out = {}
    local function scan(c)
        if not c then return end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute(attr) ~= nil then
                if (not wantName) or t:GetAttribute(attr) == wantName or t.Name == wantName then out[#out + 1] = t end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack")); scan(LocalPlayer.Character)
    return out
end
local function heldToolByAttr(attr)
    local c = LocalPlayer.Character
    local t = c and c:FindFirstChildWhichIsA("Tool")
    if t and t:GetAttribute(attr) ~= nil then return t end
    return nil
end
local function equipByAttr(attr, wantName)
    local t = heldToolByAttr(attr)
    if t and ((not wantName) or t:GetAttribute(attr) == wantName) then return t end
    t = toolsByAttr(attr, wantName)[1]
    if not t then return nil end
    local hum = humanoid(); if not hum then return nil end
    hum:EquipTool(t); task.wait(0.22)
    return heldToolByAttr(attr)
end

-- PlantArea parts inside MY plot
local function myPlantAreas()
    local out, plot = {}, myPlot()
    if not plot then return out end
    for _, p in ipairs(CollectionService:GetTagged("PlantArea")) do
        if p:IsA("BasePart") and p:IsDescendantOf(plot) then out[#out + 1] = p end
    end
    return out
end
-- a grid of world positions over my PlantArea, raycast-confirmed onto the surface
local function plantGrid(spacing)
    local pts, areas = {}, myPlantAreas()
    spacing = math.max(2, spacing or 4)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = areas
    for _, area in ipairs(areas) do
        local cf, size = area.CFrame, area.Size
        local topY = (cf * CFrame.new(0, size.Y/2, 0)).Position.Y
        for dx = -size.X/2 + spacing/2, size.X/2 - spacing/2, spacing do
            for dz = -size.Z/2 + spacing/2, size.Z/2 - spacing/2, spacing do
                local w = (cf * CFrame.new(dx, 0, dz)).Position
                local hit = Workspace:Raycast(Vector3.new(w.X, topY + 10, w.Z), Vector3.new(0, -40, 0), params)
                if hit then pts[#pts + 1] = hit.Position end
            end
        end
    end
    return pts
end
local function existingPlantPositions()
    local out, plot = {}, myPlot()
    local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return out end
    for _, m in ipairs(plants:GetChildren()) do
        local ok, pivot = pcall(function() return m:GetPivot().Position end)
        if ok then out[#out + 1] = pivot end
    end
    return out
end

-- carrier model that holds PlantId/FruitId/UserId for a given prompt
local function promptCarrier(prompt)
    local node = prompt.Parent
    while node and node ~= Workspace and node:GetAttribute("PlantId") == nil do node = node.Parent end
    if node and node:GetAttribute("PlantId") ~= nil then return node end
    return prompt:FindFirstAncestorWhichIsA("Model")
end
local function ripeHarvests()       -- own ripe fruit (tag "HarvestPrompt")
    local out = {}
    for _, pr in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(Workspace) then
            local m = promptCarrier(pr)
            local pid = m and m:GetAttribute("PlantId")
            if pid then
                local uid = tonumber(m:GetAttribute("UserId"))
                if uid == nil or uid == LocalPlayer.UserId then
                    out[#out + 1] = { plantId = tostring(pid), fruitId = tostring(m:GetAttribute("FruitId") or "") }
                end
            end
        end
    end
    return out
end
local function stealable()          -- other players' ripe fruit (tag "StealPrompt")
    local out = {}
    for _, pr in ipairs(CollectionService:GetTagged("StealPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(Workspace) then
            local m = promptCarrier(pr)
            local pid = m and m:GetAttribute("PlantId")
            if pid then
                local pos
                local pp = pr.Parent
                if pp and pp:IsA("BasePart") then pos = pp.Position
                elseif m then local ok, pv = pcall(function() return m:GetPivot().Position end); if ok then pos = pv end end
                out[#out + 1] = {
                    owner = tonumber(m:GetAttribute("UserId")) or 0,
                    plantId = tostring(pid),
                    fruitId = tostring(m:GetAttribute("FruitId") or ""),
                    pos = pos,
                }
            end
        end
    end
    return out
end
local function isNight()
    local n = ReplicatedStorage:FindFirstChild("Night")
    return n and n.Value == true
end
-- world wild pets you walk up to and buy/tame: Map.WildPetRef parts carry PetName/Price/OwnerUserId
local function wildPets()
    local out = {}
    local map = Workspace:FindFirstChild("Map")
    local ref = map and map:FindFirstChild("WildPetRef")
    if ref then for _, p in ipairs(ref:GetChildren()) do
        if p:IsA("BasePart") then
            out[#out + 1] = {
                part = p, name = p:GetAttribute("PetName"),
                price = tonumber(p:GetAttribute("Price")) or 0,
                owner = tonumber(p:GetAttribute("OwnerUserId")) or 0,
                pos = p.Position,
            }
        end
    end end
    return out
end
-- teleport char to a world position, run fn, restore original CFrame
local function atPosition(pos, fn)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local saved = hrp.CFrame
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    task.wait(0.45)
    local ok = pcall(fn)
    task.wait(0.15)
    if hrp and hrp.Parent then hrp.CFrame = saved end
    return ok
end
-- own-garden anchor: standing inside it sets IsInOwnGarden -> the server banks carried stolen fruit
local function myBasePos()
    local plot = myPlot(); if not plot then return nil end
    for _, tag in ipairs({ "GardenTotalArea", "GardenZone" }) do
        for _, p in ipairs(CollectionService:GetTagged(tag)) do
            if p:IsA("BasePart") and p:IsDescendantOf(plot) then
                return Vector3.new(p.Position.X, p.Position.Y - p.Size.Y / 2 + 5, p.Position.Z)
            end
        end
    end
    local sp = plot:FindFirstChild("SpawnPoint")
    if sp and sp:IsA("BasePart") then return sp.Position end
    local ok, piv = pcall(function() return plot:GetPivot().Position end)
    return ok and piv or nil
end

-- // ============================================================ \\ --
-- //                          STATE                              \\ --
-- // ============================================================ \\ --
local S = {
    -- master
    autoFarm = false,
    -- buy / plant / harvest / sell
    autoBuy = false, autoBuyAllSeeds = false, buySeeds = {}, buyInterval = 5, buyPerTick = 8,
    autoPlant = false, plantSpacing = 4, plantSeed = "Best owned",
    autoHarvest = false, harvestInterval = 2, harvestDelay = 0.01,
    autoSell = false, sellInterval = 15,
    autoExpand = false, autoPot = false, autoDaily = false,
    autoClaimSeedEvent = false, claimUseFly = false,
    autoShovelPlants = false, autoShovelFruits = false, shovelNameFilter = "", shovelDelay = 2,
    -- boosts
    autoSprinkler = false, sprinklerInterval = 30,
    autoWater = false, waterInterval = 8,
    autoSkill = false, skillStats = {},          -- {"BaseSpeed"=true,...}
    -- pets
    autoEquipPets = false, autoPetSlot = false,
    autoBuyPets = false, maxPetPrice = 25000, petTeleport = true, petBuyInterval = 5,
    sellPets = {}, autoSellPets = false,
    -- eggs / crates / packs
    autoEgg = false, autoCrate = false, autoPack = false, openInterval = 4,
    -- shop
    autoGear = false, autoBuyAllGear = false, gearBuy = {}, gearInterval = 10,
    -- steal
    autoSteal = false, stealTeleport = true, stealReturnBase = true, stealDelay = 0.05,
    -- misc
    autoMail = false, autoAcceptGift = false, autoHop = false, hopInterval = 0,
    codeText = "", autoCodes = false, antiAfk = true,
    -- perf / webhook
    fpsBoost = false, highGraphics = false,
    webhookEnabled = false, webhookUrl = "", webhookInterval = 300,
    webhookDisconnect = false,
    -- config / auto execute
    autoExecute = false,
    uiScale = 0,
    uiKeybindName = "LeftControl",
    killed = false,
}
local Stats = { bought = 0, planted = 0, harvested = 0, sold = 0, earned = 0,
    sprinklers = 0, watered = 0, tamed = 0, opened = 0, stolen = 0, codes = 0,
    seedEvents = 0, seedRainbow = 0, seedGold = 0, lastSeedEvent = "NONE", lastSeedClaimAt = 0,
    startAt = os.clock() }
local function notify(t, d, l)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(t or "HAIMIYACH HUB"),
            Text = tostring(d or ""),
            Duration = tonumber(l) or 3
        })
    end)
end


-- // ============================================================ \ --
-- //                    CONFIG / AUTO EXECUTE                     \ --
-- // ============================================================ \ --
local CONFIG_DIR = "HaimiyachHub"
local CONFIG_FILE = CONFIG_DIR .. "/GAG2H_Config.json"
local CONFIG_KEYS = {
    "autoFarm", "autoBuy", "autoBuyAllSeeds", "buySeeds", "buyInterval", "buyPerTick",
    "autoPlant", "plantSpacing", "plantSeed", "autoHarvest", "harvestInterval", "harvestDelay",
    "autoSell", "sellInterval", "autoExpand", "autoPot", "autoDaily",
    "autoClaimSeedEvent", "claimUseFly",
    "autoShovelPlants", "autoShovelFruits", "shovelNameFilter", "shovelDelay",
    "autoSprinkler", "sprinklerInterval", "autoWater", "waterInterval", "autoSkill", "skillStats",
    "autoEquipPets", "autoPetSlot", "autoBuyPets", "maxPetPrice", "petTeleport", "petBuyInterval",
    "sellPets", "autoSellPets", "autoEgg", "autoCrate", "autoPack", "openInterval",
    "autoGear", "autoBuyAllGear", "gearBuy", "gearInterval", "autoSteal", "stealTeleport", "stealReturnBase", "stealDelay",
    "autoMail", "autoAcceptGift", "autoHop", "hopInterval", "codeText", "autoCodes", "antiAfk",
    "fpsBoost", "highGraphics", "webhookEnabled", "webhookUrl", "webhookInterval", "webhookDisconnect",
    "autoExecute", "uiScale", "uiKeybindName"
}
local CONFIG_KEYSET = {}
for _, k in ipairs(CONFIG_KEYS) do CONFIG_KEYSET[k] = true end

local function fsSupported()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
local function ensureConfigDir()
    if type(makefolder) ~= "function" then return end
    pcall(function()
        if type(isfolder) == "function" then
            if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        else
            makefolder(CONFIG_DIR)
        end
    end)
end
local function cloneSimpleTable(t)
    local out = {}
    if type(t) ~= "table" then return out end
    for k, v in pairs(t) do
        if type(k) == "string" or type(k) == "number" then
            if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                out[k] = v
            end
        end
    end
    return out
end
local function applyConfigTable(data)
    if type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if CONFIG_KEYSET[k] and k ~= "killed" then
            local current = S[k]
            local tv = type(v)
            if type(current) == "table" then
                S[k] = cloneSimpleTable(v)
            elseif type(current) == "number" then
                local n = tonumber(v)
                if n ~= nil then S[k] = n end
            elseif type(current) == "boolean" then
                S[k] = (v == true)
            elseif type(current) == "string" then
                S[k] = tostring(v or "")
            elseif current == nil then
                if tv == "boolean" or tv == "number" or tv == "string" then S[k] = v end
            end
        end
    end
    return true
end
local function getConfigTable()
    local out = {}
    for _, k in ipairs(CONFIG_KEYS) do
        local v = S[k]
        local tv = type(v)
        if tv == "table" then
            out[k] = cloneSimpleTable(v)
        elseif tv == "boolean" or tv == "number" or tv == "string" then
            out[k] = v
        end
    end
    return out
end
local function saveConfig(silent)
    if not fsSupported() then
        if not silent then notify("HAIMIYACH HUB", "Config save is not supported by this executor.", 4) end
        return false
    end
    ensureConfigDir()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(getConfigTable()) end)
    if not ok then
        if not silent then notify("HAIMIYACH HUB", "Failed to encode config.", 4) end
        return false
    end
    local ok2, err = pcall(function() writefile(CONFIG_FILE, encoded) end)
    if not ok2 then
        if not silent then notify("HAIMIYACH HUB", "Failed to save config: " .. tostring(err), 4) end
        return false
    end
    if not silent then notify("HAIMIYACH HUB", "Config saved successfully.", 3) end
    return true
end
local function loadConfig(silent)
    if not fsSupported() then
        if not silent then notify("HAIMIYACH HUB", "Config load is not supported by this executor.", 4) end
        return false
    end
    local exists = false
    pcall(function() exists = isfile(CONFIG_FILE) end)
    if not exists then
        if not silent then notify("HAIMIYACH HUB", "No saved config found.", 3) end
        return false
    end
    local ok, raw = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or type(raw) ~= "string" or raw == "" then
        if not silent then notify("HAIMIYACH HUB", "Failed to read config.", 4) end
        return false
    end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then
        if not silent then notify("HAIMIYACH HUB", "Invalid config file.", 4) end
        return false
    end
    applyConfigTable(data)
    if not silent then notify("HAIMIYACH HUB", "Config loaded. Re-open or re-execute to refresh UI controls.", 4) end
    return true
end
local function teleportQueueFunction()
    if type(queue_on_teleport) == "function" then return queue_on_teleport end
    if syn and type(syn.queue_on_teleport) == "function" then return syn.queue_on_teleport end
    if fluxus and type(fluxus.queue_on_teleport) == "function" then return fluxus.queue_on_teleport end
    if KRNL_LOADED and type(queue_on_teleport) == "function" then return queue_on_teleport end
    return nil
end
local AUTO_EXEC_FILE = CONFIG_DIR .. "/GAG2H_AutoExecute.lua"

local function queueAutoExecute()
    if not S.autoExecute then return false, "disabled" end
    local q = teleportQueueFunction()
    if not q then return false, "queue unsupported" end
    if not fsSupported() then return false, "file system unsupported" end

    saveConfig(true)

    local code = [[
task.wait(2)
getgenv().HaimiyachGAG2AutoExec = true
local file = "HaimiyachHub/GAG2H_AutoExecute.lua"
if isfile and readfile and isfile(file) then
    loadstring(readfile(file))()
else
    warn("HAIMIYACH HUB auto execute file missing")
end
]]

    local ok, err = pcall(function() q(code) end)
    if not ok then return false, tostring(err) end
    return true
end

-- Auto-load saved config before loops and UI are created.
loadConfig(true)
if S.fpsBoost and S.highGraphics then S.highGraphics = false end

local _due = {}
local function due(key, period)
    local now = os.clock()
    if not _due[key] or now - _due[key] >= period then _due[key] = now; return true end
    return false
end
-- passive background loop bound to a getter
local function loopOn(getOn, period, body)
    task.spawn(function()
        while not S.killed do
            if getOn() then
                pcall(body)
                local p = (type(period) == "function") and period() or period
                local e = 0; while e < p and getOn() and not S.killed do task.wait(0.4); e = e + 0.4 end
            else task.wait(0.4) end
        end
    end)
end
local function picked(t) for _ in pairs(t) do return true end return false end
local function pickMulti(sel, into)
    for k in pairs(into) do into[k] = nil end
    if type(sel) == "table" then for k, v in pairs(sel) do
        if v == true then into[k] = true elseif type(v) == "string" then into[v] = true end
    end end
end

-- // ============================================================ \\ --
-- //                  SEED EVENT CLAIM (Rainbow/Gold)             \\ --
-- // ============================================================ \\ --
local function getSeedEventPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj.Position
    end
    if obj:IsA("Model") then
        local pp = obj.PrimaryPart
        if pp and pp:IsA("BasePart") then return pp.Position end
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.Position end
    return nil
end

local function flyToPosition(targetPos, speed)
    speed = tonumber(speed) or 30
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hrp and targetPos) then return false end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "HaimiyachSeedEventFly"
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = hrp

    local oldPlatformStand = false
    if humanoid then
        oldPlatformStand = humanoid.PlatformStand
        humanoid.PlatformStand = true
    end

    local ok = pcall(function()
        local elapsed = 0
        while elapsed < 10 and not S.killed and S.autoClaimSeedEvent do
            if not (hrp and hrp.Parent) then break end
            local delta = targetPos - hrp.Position
            local dist = delta.Magnitude
            if dist <= 2 then break end
            if dist > 0 then
                bodyVelocity.Velocity = delta.Unit * speed
            end
            task.wait(0.05)
            elapsed = elapsed + 0.05
        end
    end)

    pcall(function() bodyVelocity:Destroy() end)
    if humanoid then
        pcall(function() humanoid.PlatformStand = oldPlatformStand end)
    end
    return ok
end

local function getSeedSpawnFolders()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil, nil end
    return map:FindFirstChild("SeedPackSpawnServerLocations"), map:FindFirstChild("SeedPackSpawnClient")
end

local function findSeedEventObjects()
    local results = {}
    local spawnServer = getSeedSpawnFolders()
    if not spawnServer then return results end

    for _, obj in ipairs(spawnServer:GetChildren()) do
        local isRainbow = obj:GetAttribute("RainbowSeed") == true
        local isGold = obj:GetAttribute("GoldSeed") == true
        if isRainbow or isGold then
            local pos = getSeedEventPosition(obj)
            if pos then
                results[#results + 1] = {
                    object = obj,
                    position = pos,
                    seedType = isRainbow and "RAINBOW" or "GOLD"
                }
            end
        end
    end

    return results
end

local function getSeedEventCounts(events)
    local rainbow = 0
    local gold = 0
    events = events or findSeedEventObjects()
    for _, data in ipairs(events) do
        if data.seedType == "RAINBOW" then
            rainbow = rainbow + 1
        elseif data.seedType == "GOLD" then
            gold = gold + 1
        end
    end
    return rainbow, gold, rainbow + gold
end

local function getSeedEventAvailableText()
    local events = findSeedEventObjects()
    local rainbow, gold, total = getSeedEventCounts(events)
    if total <= 0 then
        return "NONE"
    end
    return string.format("RAINBOW %d · GOLD %d · TOTAL %d", rainbow, gold, total)
end

local function getSeedEventClaimText()
    return string.format("RAINBOW %d · GOLD %d · TOTAL %d",
        Stats.seedRainbow or 0, Stats.seedGold or 0, Stats.seedEvents or 0)
end

local function getSeedEventAgeText(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, sec % 60) end
    return tostring(sec) .. "s"
end

local function getSeedEventLastText()
    if not Stats.lastSeedEvent or Stats.lastSeedEvent == "NONE" then
        return "NONE"
    end
    local age = os.clock() - (Stats.lastSeedClaimAt or os.clock())
    return tostring(Stats.lastSeedEvent) .. " · " .. getSeedEventAgeText(age) .. " ago"
end

local function findPromptNearPosition(pos)
    if not pos then return nil end
    local _, spawnClient = getSeedSpawnFolders()
    if not spawnClient then return nil end

    local bestPrompt = nil
    local bestDist = math.huge
    for _, prompt in ipairs(spawnClient:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local parent = prompt.Parent
            local ppos = getSeedEventPosition(parent)
            if ppos then
                local dist = (ppos - pos).Magnitude
                if dist < bestDist and dist <= 35 then
                    bestDist = dist
                    bestPrompt = prompt
                end
            end
        end
    end
    return bestPrompt
end

local function triggerSeedEventPrompt(obj, pos)
    local prompt = obj and obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not (prompt and prompt.Enabled) then
        prompt = findPromptNearPosition(pos)
    end
    if not (prompt and prompt.Enabled) then return false end

    local ok = false
    if type(fireproximityprompt) == "function" then
        ok = pcall(function() fireproximityprompt(prompt) end)
    end
    if not ok then
        ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.max(0.15, tonumber(prompt.HoldDuration) or 0.15))
            prompt:InputHoldEnd()
        end)
    end
    return ok == true
end

local function moveToSeedEvent(pos)
    if not pos then return false end
    local targetPos = pos + Vector3.new(0, 3, 0)
    if S.claimUseFly then
        return flyToPosition(targetPos, 30)
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(targetPos)
    return true
end

local function claimSeedEvent()
    local claimed = 0
    local events = findSeedEventObjects()
    if #events == 0 then return 0 end

    for _, data in ipairs(events) do
        if not S.autoClaimSeedEvent or S.killed then break end

        local obj = data.object
        local pos = data.position
        if obj and obj.Parent and pos then
            moveToSeedEvent(pos)
            task.wait(0.3)

            local okClaim = triggerSeedEventPrompt(obj, pos)
            if not okClaim then
                local ok = fire("SeedPack.Claim", obj)
                okClaim = ok == true
            end

            if okClaim then
                claimed = claimed + 1
                Stats.seedEvents = (Stats.seedEvents or 0) + 1
                Stats.lastSeedEvent = tostring(data.seedType or "UNKNOWN")
                Stats.lastSeedClaimAt = os.clock()
                if data.seedType == "RAINBOW" then
                    Stats.seedRainbow = (Stats.seedRainbow or 0) + 1
                elseif data.seedType == "GOLD" then
                    Stats.seedGold = (Stats.seedGold or 0) + 1
                end
                notify("Seed Event", "Claimed " .. data.seedType .. " Seed", 3)
                task.wait(0.5)
            end
        end
    end

    return claimed
end

-- // ============================================================ \ --
-- //                       AUTO SHOVEL                           \ --
-- // ============================================================ \ --
local ShovelAuto = {}

function ShovelAuto.objectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
        local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.Position end
    end
    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function ShovelAuto.matchesFilter(obj)
    local f = string.lower(tostring(S.shovelNameFilter or ""))
    if f == "" then return true end
    if not obj then return false end
    local checks = {
        tostring(obj.Name or ""),
        tostring(obj:GetAttribute("PlantName") or ""),
        tostring(obj:GetAttribute("FruitName") or ""),
        tostring(obj:GetAttribute("Seed") or ""),
        tostring(obj:GetAttribute("SeedTool") or ""),
    }
    for _, s in ipairs(checks) do
        if string.find(string.lower(s), f, 1, true) then return true end
    end
    return false
end

function ShovelAuto.equipTool()
    local tool = equipByAttr("Shovel")
    if tool then return tool end
    local hum = humanoid()
    local function scan(parent)
        if not parent then return nil end
        for _, t in ipairs(parent:GetChildren()) do
            if t:IsA("Tool") and string.find(string.lower(t.Name), "shovel", 1, true) then
                return t
            end
        end
        return nil
    end
    tool = scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
    if tool and hum and tool.Parent ~= LocalPlayer.Character then
        hum:EquipTool(tool)
        task.wait(0.22)
        tool = heldToolByAttr("Shovel") or tool
    end
    return tool
end

function ShovelAuto.moveTo(obj)
    local pos = ShovelAuto.objectPosition(obj)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if pos and hrp then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        task.wait(0.22)
        return true
    end
    return false
end

function ShovelAuto.ownPlants()
    local out = {}
    local plot = myPlot()
    local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return out end
    for _, plant in ipairs(plants:GetChildren()) do
        if ShovelAuto.matchesFilter(plant) then
            local pid = plant:GetAttribute("PlantId") or plant:GetAttribute("Id") or plant.Name
            if pid then
                out[#out + 1] = { object = plant, plantId = tostring(pid), fruitId = "" }
            end
        end
    end
    return out
end

function ShovelAuto.ownFruits()
    local out = {}
    for _, pr in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(Workspace) then
            local m = promptCarrier(pr)
            local pid = m and m:GetAttribute("PlantId")
            local fid = m and m:GetAttribute("FruitId")
            local uid = m and tonumber(m:GetAttribute("UserId"))
            if pid and (uid == nil or uid == LocalPlayer.UserId) and ShovelAuto.matchesFilter(m) then
                out[#out + 1] = { object = m, plantId = tostring(pid), fruitId = tostring(fid or "") }
            end
        end
    end
    return out
end

function ShovelAuto.target(data)
    if not data or not data.plantId then return false end
    local tool = ShovelAuto.equipTool()
    if not tool then
        if due("shovelNoTool", 6) then notify("Shovel", "Shovel tool not found.", 3) end
        return false
    end
    ShovelAuto.moveTo(data.object)
    local shovelName = tool:GetAttribute("Shovel") or tool.Name
    local ok = fire("Shovel.UseShovel", tostring(data.plantId), tostring(data.fruitId or ""), shovelName, tool)
    if ok then
        task.wait(0.35)
        return true
    end
    pcall(function() tool:Activate() end)
    task.wait(0.35)
    return false
end

loopOn(function()
    return S.autoShovelPlants or S.autoShovelFruits
end, function()
    return math.max(1, tonumber(S.shovelDelay) or 2)
end, function()
    local delayTime = math.max(0.5, tonumber(S.shovelDelay) or 2)
    if S.autoShovelFruits then
        for _, data in ipairs(ShovelAuto.ownFruits()) do
            if not S.autoShovelFruits or S.killed then break end
            ShovelAuto.target(data)
            task.wait(delayTime)
        end
    end
    if S.autoShovelPlants then
        for _, data in ipairs(ShovelAuto.ownPlants()) do
            if not S.autoShovelPlants or S.killed then break end
            ShovelAuto.target(data)
            task.wait(delayTime)
        end
    end
end)

-- // ============================================================ \\ --
-- //                     CORE FARM (master loop)                 \\ --
-- // ============================================================ \\ --
local function stepBuy()
    if not due("buy", S.buyInterval) then return end
    if not picked(S.buySeeds) then return end
    for _, s in ipairs(CATALOG) do
        if not (S.autoFarm or S.autoBuy) then break end
        if S.buySeeds[s.name] then
            local stock, bought = stockOf("SeedShop", s.name), 0
            while bought < S.buyPerTick do
                if stock ~= nil and stock <= 0 then break end
                if s.price > 0 and getSheckles() < s.price then break end
                if not fire("SeedShop.PurchaseSeed", s.name) then break end
                Stats.bought = Stats.bought + 1; bought = bought + 1
                if stock ~= nil then stock = stock - 1 end
                task.wait(jitter(0.1, 0.22))
            end
        end
    end
end


local function buyAllSeedsNow(silent)
    local total = 0
    for _, s in ipairs(CATALOG) do
        local stock = stockOf("SeedShop", s.name)
        local limit = 1
        if stock ~= nil then
            limit = math.max(0, math.floor(tonumber(stock) or 0))
        else
            limit = math.max(1, math.floor(tonumber(S.buyPerTick) or 1))
        end
        local bought = 0
        while bought < limit do
            if s.price and s.price > 0 and getSheckles() < s.price then break end
            local ok = fire("SeedShop.PurchaseSeed", s.name)
            if not ok then break end
            Stats.bought = Stats.bought + 1
            total = total + 1
            bought = bought + 1
            task.wait(jitter(0.08, 0.18))
        end
        task.wait(0.03)
    end
    if not silent then
        notify("Shop", "Bought " .. tostring(total) .. " seeds", 3)
    end
end

local function buyAllGearNow(silent)
    local total = 0
    for _, name in ipairs(GEAR_NAMES) do
        local stock = stockOf("GearShop", name)
        local limit = 1
        if stock ~= nil then
            limit = math.max(0, math.floor(tonumber(stock) or 0))
        end
        local bought = 0
        while bought < limit do
            local ok = fire("GearShop.PurchaseGear", name)
            if not ok then break end
            total = total + 1
            bought = bought + 1
            task.wait(jitter(0.12, 0.25))
        end
        task.wait(0.03)
    end
    if not silent then
        notify("Shop", "Bought " .. tostring(total) .. " gear", 3)
    end
end

loopOn(function() return S.autoBuyAllSeeds end, function() return math.max(1, tonumber(S.buyInterval) or 5) end, function()
    buyAllSeedsNow(true)
end)

loopOn(function() return S.autoBuyAllGear end, function() return math.max(2, tonumber(S.gearInterval) or 10) end, function()
    buyAllGearNow(true)
end)

local function pickPlantTool()
    if S.plantSeed ~= "Best owned" and S.plantSeed ~= "" then
        local t = toolsByAttr("SeedTool", S.plantSeed)[1]
        if t then return t end
    end
    -- best owned = rarest/most expensive seed we hold
    local best, bestPrice
    for _, t in ipairs(toolsByAttr("SeedTool")) do
        local nm = t:GetAttribute("SeedTool")
        local price = 0
        for _, s in ipairs(CATALOG) do if s.name == nm then price = s.price; break end end
        if not bestPrice or price > bestPrice then best, bestPrice = t, price end
    end
    return best or toolsByAttr("SeedTool")[1]
end

local function stepPlant()
    local grid = plantGrid(S.plantSpacing)
    if #grid == 0 then return end
    local tool = pickPlantTool(); if not tool then return end
    local hum = humanoid(); if not hum then return end
    if heldToolByAttr("SeedTool") ~= tool then hum:EquipTool(tool); task.wait(0.22) end
    tool = heldToolByAttr("SeedTool"); if not tool then return end
    local seedAttr = tool:GetAttribute("SeedTool")
    local occupied = existingPlantPositions()
    for _, pos in ipairs(grid) do
        if not (S.autoFarm or S.autoPlant) then break end
        local clear = true
        for _, op in ipairs(occupied) do
            if (Vector2.new(pos.X, pos.Z) - Vector2.new(op.X, op.Z)).Magnitude < 1 then clear = false; break end
        end
        if clear then
            if not heldToolByAttr("SeedTool") then
                local nx = pickPlantTool(); if not nx then return end
                hum:EquipTool(nx); task.wait(0.2)
                tool = heldToolByAttr("SeedTool"); if not tool then return end
                seedAttr = tool:GetAttribute("SeedTool")
            end
            fire("Plant.PlantSeed", pos, seedAttr, tool)
            Stats.planted = Stats.planted + 1; occupied[#occupied + 1] = pos
            task.wait(jitter(0.08, 0.16))   -- > the game's 0.05s client gate
        end
    end
end

local function maxFruitCap() return tonumber(LocalPlayer:GetAttribute("MaxFruitCapacity")) or 100 end
local function fruitCount()  return tonumber(LocalPlayer:GetAttribute("FruitCount")) or 0 end
local function sellAllNow()
    local ok, res = fireFast("NPCS.SellAll")
    if ok and type(res) == "table" and res.Success then
        local n = tonumber(res.SoldCount) or 0
        Stats.sold = Stats.sold + n; Stats.earned = Stats.earned + (tonumber(res.SellPrice) or 0)
        return n
    end
    return 0
end

-- THROUGHPUT FIX: inventory caps at MaxFruitCapacity (100) and the server only accepts
-- ~20-25 collects/sec. So harvest in a tight cycle and SELL THE MOMENT the pack is full —
-- never idle holding a full inventory. Firing faster than the server's rate just gets
-- dropped (delay=0 collected LESS), so harvestDelay paces each collect.
local function stepHarvest()
    local sell = (S.autoFarm or S.autoSell)
    local list = ripeHarvests()
    if #list == 0 then
        if sell and fruitCount() > 0 then sellAllNow() end
        return
    end
    local cap = maxFruitCap()
    local d = S.harvestDelay or 0
    -- fire a fresh batch of collects (the firing time lets the async collects materialize
    -- into the pack), stop if the pack is genuinely full, then sell the whole batch at once.
    for _, h in ipairs(list) do
        if not (S.autoFarm or S.autoHarvest) then break end
        if fruitCount() >= cap - 1 then break end
        fireFast("Garden.CollectFruit", h.plantId, h.fruitId)
        Stats.harvested = Stats.harvested + 1
        if d > 0 then task.wait(d) end
    end
    if sell then sellAllNow() end
end

local function stepSell()       -- sell-only mode (when AUTO HARVEST is off)
    if not due("sell", S.sellInterval) then return end
    local n = sellAllNow()
    if n > 0 then notify("Sold", n .. " items", 3) end
end

local function stepExpand()
    if not due("expand", 12) then return end
    fire("Actions.ExpandGarden")        -- server/client-gates affordability itself
end
local function stepDaily()
    if not due("daily", 60) then return end
    fire("NPCS.CheckDailyDeal"); task.wait(0.3); fire("NPCS.UseDailyDealAll")
end

task.spawn(function()
    while not S.killed do
        if S.autoFarm or S.autoBuy     then pcall(stepBuy) end
        if S.autoFarm or S.autoPlant   then pcall(stepPlant) end
        if S.autoFarm or S.autoExpand  then pcall(stepExpand) end
        if S.autoFarm or S.autoDaily   then pcall(stepDaily) end
        task.wait(0.55)
    end
end)

-- dedicated harvest+sell loop: tight cycle so a big backlog drains at the server's max
-- collect rate (never blocked behind buy/plant/expand on the slow master loop).
task.spawn(function()
    while not S.killed do
        if S.autoFarm or S.autoHarvest then
            pcall(stepHarvest)
            task.wait(0.05)
        elseif S.autoSell then
            pcall(stepSell)
            task.wait(0.3)
        else
            task.wait(0.4)
        end
    end
end)

-- // ============================================================ \\ --
-- //                       BOOSTS (passive)                      \\ --
-- // ============================================================ \\ --
-- AUTO SPRINKLER: place every owned sprinkler tool, spread across the plot
loopOn(function() return S.autoSprinkler end, function() return S.sprinklerInterval end, function()
    local pid = myPlotId(); if not pid then return end
    local placed = existingPlantPositions()  -- avoid clustering
    for _, t in ipairs(toolsByAttr("Sprinkler")) do
        if not S.autoSprinkler then break end
        local hum = humanoid(); if not hum then break end
        hum:EquipTool(t); task.wait(0.22)
        t = heldToolByAttr("Sprinkler"); if not t then break end
        local grid = plantGrid(8)
        for _, pos in ipairs(grid) do
            local far = true
            for _, op in ipairs(placed) do if (pos - op).Magnitude < 12 then far = false; break end end
            if far then
                fire("Place.PlaceSprinkler", pos, t:GetAttribute("Sprinkler"), t, pid)
                Stats.sprinklers = Stats.sprinklers + 1; placed[#placed + 1] = pos; task.wait(0.3)
                break
            end
        end
    end
    pcall(function() humanoid():UnequipTools() end)
end)

-- AUTO WATER: use watering can over planted crops
loopOn(function() return S.autoWater end, function() return S.waterInterval end, function()
    local t = equipByAttr("WateringCan"); if not t then return end
    local name = t:GetAttribute("WateringCan")
    for _, pos in ipairs(existingPlantPositions()) do
        if not S.autoWater then break end
        fire("WateringCan.UseWateringCan", pos - Vector3.new(0, 0.3, 0), name, t)
        Stats.watered = Stats.watered + 1; task.wait(jitter(0.15, 0.3))
    end
end)

-- AUTO SKILL: keep spending skill points into the selected stats
loopOn(function() return S.autoSkill end, 6, function()
    if not picked(S.skillStats) then return end
    for stat in pairs(S.skillStats) do
        if not S.autoSkill then break end
        fire("SkillPoints.SpendSkillPoint", stat); task.wait(0.25)
    end
end)

-- // ============================================================ \\ --
-- //                          PETS                               \\ --
-- // ============================================================ \\ --
local function ownedPetNames()
    local names, seen = {}, {}
    for nm in pairs(invNames("Pets")) do if not seen[nm] then seen[nm] = true; names[#names + 1] = nm end end
    for _, t in ipairs(toolsByAttr("PetId")) do
        local nm = t:GetAttribute("PetName") or t.Name
        if nm and not seen[nm] then seen[nm] = true; names[#names + 1] = nm end
    end
    table.sort(names); return names
end
local function equippedPetCount()
    local ok, list = fire("Pets.GetEquippedPets")
    if ok and type(list) == "table" then
        local n = 0; for _ in pairs(list) do n = n + 1 end; return n
    end
    return 0
end
loopOn(function() return S.autoEquipPets end, 12, function()
    local cap = tonumber(LocalPlayer:GetAttribute("MaxEquippedPets")) or 3
    local have = equippedPetCount()
    if have >= cap then return end
    for _, nm in ipairs(ownedPetNames()) do
        if not S.autoEquipPets or have >= cap then break end
        fire("Pets.RequestEquipByName", nm); have = have + 1; task.wait(0.3)
    end
end)
loopOn(function() return S.autoPetSlot end, 20, function()
    fire("Pets.RequestPurchasePetSlot")
end)
-- AUTO BUY world pets: walk up (teleport) to each affordable unowned wild pet and buy it.
-- Buying == Pets.WildPetTame:Fire(refPart); server charges Price and REQUIRES proximity.
loopOn(function() return S.autoBuyPets end, function() return S.petBuyInterval end, function()
    for _, w in ipairs(wildPets()) do
        if not S.autoBuyPets then break end
        if w.owner == 0 and w.price > 0 and w.price <= S.maxPetPrice and getSheckles() >= w.price then
            if S.petTeleport and w.pos then
                atPosition(w.pos, function() fire("Pets.WildPetTame", w.part) end)
            else
                fire("Pets.WildPetTame", w.part)
            end
            Stats.tamed = Stats.tamed + 1
            task.wait(jitter(0.3, 0.6))
        end
    end
end)
loopOn(function() return S.autoSellPets end, 4, function()
    if not picked(S.sellPets) then return end
    for _, t in ipairs(toolsByAttr("PetId")) do
        if not S.autoSellPets then break end
        local nm = t:GetAttribute("PetName") or t.Name
        if S.sellPets[nm] then
            local hum = humanoid()
            if hum then hum:EquipTool(t); task.wait(0.25) end
            fire("NPCS.SellPet", t:GetAttribute("PetId")); task.wait(0.3)
        end
    end
end)

-- // ============================================================ \\ --
-- //                  EGGS / CRATES / SEED PACKS                 \\ --
-- // ============================================================ \\ --
local function openAll(category, path)
    for nm, count in pairs(invNames(category)) do
        if S.killed then break end
        for _ = 1, math.min(count, 25) do
            local ok, res = fire(path, nm)
            if not ok then break end
            if type(res) == "table" and res.Success == false then break end
            Stats.opened = Stats.opened + 1; task.wait(jitter(0.25, 0.5))
        end
    end
end
loopOn(function() return S.autoEgg  end, function() return S.openInterval end, function() openAll("Eggs", "Egg.OpenEgg") end)
loopOn(function() return S.autoCrate end, function() return S.openInterval end, function() openAll("Crates", "Crate.OpenCrate") end)
loopOn(function() return S.autoPack  end, function() return S.openInterval end, function() openAll("SeedPacks", "SeedPack.OpenSeedPack") end)

-- // ============================================================ \\ --
-- //                      SHOP (gear)                            \\ --
-- // ============================================================ \\ --
loopOn(function() return S.autoGear end, function() return S.gearInterval end, function()
    if not picked(S.gearBuy) then return end
    for name in pairs(S.gearBuy) do
        if not S.autoGear then break end
        local stock = stockOf("GearShop", name)
        if stock == nil or stock > 0 then
            fire("GearShop.PurchaseGear", name); task.wait(jitter(0.2, 0.4))
        end
    end
end)

-- // ============================================================ \\ --
-- //                     STEAL (PvP, night)                      \\ --
-- // ============================================================ \\ --
-- Safe steal flow: move close to StealPrompt, fire BeginSteal + CompleteSteal,
-- wait until CarryingStolenFruit is true, then return to Plot SpawnPoint.
local function hrpNow() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
loopOn(function() return S.autoSteal end, 1.5, function()
    if not isNight() then return end
    for _, f in ipairs(stealable()) do
        if not (S.autoSteal and isNight()) then break end

        -- bank current carried fruit first, if any
        if LocalPlayer:GetAttribute("CarryingStolenFruit") == true and S.stealReturnBase then
            local plot = myPlot()
            local sp = plot and plot:FindFirstChild("SpawnPoint")
            local base = (sp and sp:IsA("BasePart")) and sp.Position or myBasePos()
            local hrp = hrpNow()
            if base and hrp then
                hrp.CFrame = CFrame.new(base + Vector3.new(0, 4, 0))
                local t0 = os.clock()
                while LocalPlayer:GetAttribute("CarryingStolenFruit") == true and os.clock() - t0 < 3 and S.autoSteal do
                    task.wait(0.15)
                end
            end
        end

        -- go to fruit because the server checks proximity
        if S.stealTeleport and f.pos then
            local hrp = hrpNow()
            if hrp then
                hrp.CFrame = CFrame.new(f.pos + Vector3.new(0, 4, 0))
                task.wait(0.45)
            end
        end

        local beforeCarry = LocalPlayer:GetAttribute("CarryingStolenFruit") == true
        local beforeValue = tonumber(LocalPlayer:GetAttribute("StolenCarryValue")) or 0

        fire("Steal.BeginSteal", f.owner, f.plantId, f.fruitId)
        task.wait(0.08)
        fire("Steal.CompleteSteal")

        local gotFruit = false
        local t1 = os.clock()
        while os.clock() - t1 < 1.5 and S.autoSteal do
            if LocalPlayer:GetAttribute("CarryingStolenFruit") == true then
                gotFruit = true
                break
            end
            task.wait(0.1)
        end

        local afterValue = tonumber(LocalPlayer:GetAttribute("StolenCarryValue")) or 0
        if gotFruit or (not beforeCarry and afterValue > beforeValue) then
            Stats.stolen = Stats.stolen + 1
            if S.stealReturnBase then
                local plot = myPlot()
                local sp = plot and plot:FindFirstChild("SpawnPoint")
                local base = (sp and sp:IsA("BasePart")) and sp.Position or myBasePos()
                local hrp = hrpNow()
                if base and hrp then
                    hrp.CFrame = CFrame.new(base + Vector3.new(0, 4, 0))
                    local t2 = os.clock()
                    while LocalPlayer:GetAttribute("CarryingStolenFruit") == true and os.clock() - t2 < 3 and S.autoSteal do
                        task.wait(0.15)
                    end
                end
            end
        end

        if (S.stealDelay or 0) > 0 then
            task.wait(S.stealDelay)
        end
    end
end)

-- // ============================================================ \\ --
-- //                  MISC (mail / gifts / hop / codes)          \\ --
-- // ============================================================ \\ --
loopOn(function() return S.autoMail end, 30, function()
    local ok, box = fire("Mailbox.OpenInbox")
    if ok and type(box) == "table" then
        local mb = box.Mailbox or box.Inbox or box
        for id, entry in pairs(mb) do
            if not S.autoMail then break end
            if type(entry) == "table" and (entry.Claimed == true or entry.IsClaimed == true) then
                -- skip already claimed
            else
                fire("Mailbox.Claim", id); task.wait(0.3)
            end
        end
    end
end)
-- accept incoming gifts automatically
pcall(function()
    local g = action("Gifting.Prompted")
    if g and g.OnClientEvent then
        g.OnClientEvent:Connect(function(fromPlayer)
            if S.autoAcceptGift and fromPlayer then pcall(function() fire("Gifting.Response", fromPlayer, true) end) end
        end)
    end
end)
-- server hop when enabled (RequestHop asks the server to migrate the player)
-- Waits the selected interval BEFORE the first hop, so enabling AUTO SERVER HOP
-- does not instantly hop as soon as the toggle/config turns on.
task.spawn(function()
    local waited = 0
    local wasOn = false

    while not S.killed do
        if S.autoHop and tonumber(S.hopInterval) and S.hopInterval > 0 then
            local interval = math.max(60, tonumber(S.hopInterval) or 0)

            if not wasOn then
                wasOn = true
                waited = 0
            end

            task.wait(0.4)
            waited = waited + 0.4

            if waited >= interval and S.autoHop and not S.killed then
                waited = 0
                local queued, qerr = queueAutoExecute()
                if S.autoExecute and not queued then
                    notify("HAIMIYACH HUB", "Auto execute queue failed: " .. tostring(qerr), 4)
                end
                fire("AntiAfk.RequestHop")
            end
        else
            wasOn = false
            waited = 0
            task.wait(0.4)
        end
    end
end)
-- Anti-AFK: defeat the idle kick via VirtualUser input on Idled (default on)
if VirtualUser then
    LocalPlayer.Idled:Connect(function()
        if S.killed or not S.antiAfk then return end
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
    end)
end
-- codes
local CODE_LIST = {}                  -- add known GAG2 codes here
local triedCodes = {}
local function redeemCodes(list)
    local n = 0
    for _, code in ipairs(list) do
        if code ~= "" and not triedCodes[code] then
            local ok, res = fire("Settings.SubmitCode", code)
            triedCodes[code] = true
            if ok and res == true then n = n + 1; Stats.codes = Stats.codes + 1 end
            task.wait(0.4)
        end
    end
    return n
end
loopOn(function() return S.autoCodes end, 120, function() redeemCodes(CODE_LIST) end)

-- // ============================================================ \ --
-- //                       PERFORMANCE                           \ --
-- // ============================================================ \ --
-- Stable graphics controller:
-- FPS BOOST and HIGH GRAPHICS are mutually exclusive and fully restorable.
-- FPS BOOST does NOT hide decals/textures, parts, hitboxes, characters, or GUI.
local function SafeSetProperty(obj, prop, value)
    pcall(function()
        if obj then obj[prop] = value end
    end)
end

local GraphicsBackup = {
    Captured = false,
    Lighting = {},
    Effects = {},
    Atmosphere = {},
    WorkspaceEffects = {},
    WorkspaceEffectRates = {},
    Terrain = {},
    QualityLevel = nil,
}

local FPSBoostActive = false
local HighGraphicsActive = false
local FPSBoostDescendantConnection = nil
local FPSBoostScanToken = 0

local function CaptureGraphicsBackup()
    if GraphicsBackup.Captured then return end
    GraphicsBackup.Captured = true

    local lightingProps = {
        "GlobalShadows",
        "Brightness",
        "ClockTime",
        "FogStart",
        "FogEnd",
        "ExposureCompensation",
        "EnvironmentDiffuseScale",
        "EnvironmentSpecularScale",
        "ShadowSoftness",
        "Ambient",
        "OutdoorAmbient",
        "Technology",
    }

    for _, prop in ipairs(lightingProps) do
        pcall(function()
            GraphicsBackup.Lighting[prop] = Lighting[prop]
        end)
    end

    pcall(function()
        GraphicsBackup.QualityLevel = UserSettings():GetService("UserGameSettings").SavedQualityLevel
    end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            pcall(function()
                GraphicsBackup.Effects[obj] = obj.Enabled
            end)
        elseif obj:IsA("Atmosphere") then
            pcall(function()
                GraphicsBackup.Atmosphere[obj] = {
                    Density = obj.Density,
                    Offset = obj.Offset,
                    Color = obj.Color,
                    Decay = obj.Decay,
                    Glare = obj.Glare,
                    Haze = obj.Haze,
                }
            end)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, prop in ipairs({"Decoration", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed"}) do
            pcall(function()
                GraphicsBackup.Terrain[prop] = terrain[prop]
            end)
        end
    end
end

local function CaptureWorkspaceEffectBackup(obj)
    if not obj then return end
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        if GraphicsBackup.WorkspaceEffects[obj] == nil then
            pcall(function()
                GraphicsBackup.WorkspaceEffects[obj] = obj.Enabled
            end)
        end
        if obj:IsA("ParticleEmitter") and GraphicsBackup.WorkspaceEffectRates[obj] == nil then
            pcall(function()
                GraphicsBackup.WorkspaceEffectRates[obj] = obj.Rate
            end)
        end
    end
end

local function DisableClientVisualEffect(obj)
    if not obj then return end
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        CaptureWorkspaceEffectBackup(obj)
        SafeSetProperty(obj, "Enabled", false)
        if obj:IsA("ParticleEmitter") then
            SafeSetProperty(obj, "Rate", 0)
        end
    end
end

local function RemoveHaimiyachGraphicsEffects()
    for _, name in ipairs({
        "Haimiyach_HD_Bloom",
        "Haimiyach_HD_ColorCorrection",
        "Haimiyach_HD_SunRays",
        "Haimiyach_HD_DepthOfField",
        "Haimiyach_HD_Atmosphere",
        "Haimiyach_High_Bloom",
        "Haimiyach_High_Color",
        "Haimiyach_High_SunRays",
        "Haimiyach_High_Atmosphere",
    }) do
        local obj = Lighting:FindFirstChild(name)
        if obj then pcall(function() obj:Destroy() end) end
    end
end

local function RestoreWorkspaceEffects()
    for obj, enabled in pairs(GraphicsBackup.WorkspaceEffects) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Enabled", enabled)
        end
    end
    for obj, rate in pairs(GraphicsBackup.WorkspaceEffectRates) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Rate", rate)
        end
    end
end

local function RestoreDefaultGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachGraphicsEffects()

    if FPSBoostDescendantConnection then
        pcall(function() FPSBoostDescendantConnection:Disconnect() end)
        FPSBoostDescendantConnection = nil
    end

    for prop, value in pairs(GraphicsBackup.Lighting) do
        SafeSetProperty(Lighting, prop, value)
    end

    for obj, enabled in pairs(GraphicsBackup.Effects) do
        if obj and obj.Parent then
            SafeSetProperty(obj, "Enabled", enabled)
        end
    end

    for obj, values in pairs(GraphicsBackup.Atmosphere) do
        if obj and obj.Parent then
            for prop, value in pairs(values) do
                SafeSetProperty(obj, prop, value)
            end
        end
    end

    RestoreWorkspaceEffects()

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for prop, value in pairs(GraphicsBackup.Terrain) do
            SafeSetProperty(terrain, prop, value)
        end
    end

    pcall(function()
        if GraphicsBackup.QualityLevel ~= nil then
            UserSettings():GetService("UserGameSettings").SavedQualityLevel = GraphicsBackup.QualityLevel
        end
    end)

    S.fpsBoost = false
    S.highGraphics = false
    FPSBoostActive = false
    HighGraphicsActive = false
    FPSBoostScanToken = FPSBoostScanToken + 1
end

local function ApplyFPSBoostGraphics()
    CaptureGraphicsBackup()
    RemoveHaimiyachGraphicsEffects()
    RestoreWorkspaceEffects()

    if FPSBoostDescendantConnection then
        pcall(function() FPSBoostDescendantConnection:Disconnect() end)
        FPSBoostDescendantConnection = nil
    end

    FPSBoostScanToken = FPSBoostScanToken + 1
    local scanToken = FPSBoostScanToken

    S.fpsBoost = true
    S.highGraphics = false
    FPSBoostActive = true
    HighGraphicsActive = false

    -- Mobile-safe low graphics: avoid changing map textures/parts.
    -- This keeps the map readable but removes expensive lighting, shadows, water and effects.
    SafeSetProperty(Lighting, "GlobalShadows", false)
    SafeSetProperty(Lighting, "Brightness", 1)
    SafeSetProperty(Lighting, "FogStart", 0)
    SafeSetProperty(Lighting, "FogEnd", 100000)
    SafeSetProperty(Lighting, "ExposureCompensation", 0)
    SafeSetProperty(Lighting, "EnvironmentDiffuseScale", 0)
    SafeSetProperty(Lighting, "EnvironmentSpecularScale", 0)
    SafeSetProperty(Lighting, "ShadowSoftness", 0)
    pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
    pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            SafeSetProperty(obj, "Enabled", false)
        elseif obj:IsA("Atmosphere") then
            SafeSetProperty(obj, "Density", 0)
            SafeSetProperty(obj, "Haze", 0)
            SafeSetProperty(obj, "Glare", 0)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        SafeSetProperty(terrain, "Decoration", false)
        SafeSetProperty(terrain, "WaterReflectance", 0)
        SafeSetProperty(terrain, "WaterTransparency", 1)
        SafeSetProperty(terrain, "WaterWaveSize", 0)
        SafeSetProperty(terrain, "WaterWaveSpeed", 0)
    end

    -- Batch scan so mobile does not freeze when Grow a Garden 2 has many descendants.
    -- Only particle/effect objects are touched; BasePart, Texture, Decal, GUI and characters are left alone.
    task.spawn(function()
        local descendants = {}
        pcall(function()
            descendants = Workspace:GetDescendants()
        end)

        local processed = 0
        for _, obj in ipairs(descendants) do
            if scanToken ~= FPSBoostScanToken or not FPSBoostActive or not S.fpsBoost then
                break
            end

            DisableClientVisualEffect(obj)
            processed = processed + 1

            if processed % 75 == 0 then
                task.wait()
            end
        end
    end)

    FPSBoostDescendantConnection = Workspace.DescendantAdded:Connect(function(obj)
        if FPSBoostActive and S.fpsBoost then
            task.delay(0.15, function()
                if FPSBoostActive and S.fpsBoost then
                    DisableClientVisualEffect(obj)
                end
            end)
        end
    end)
end
local function ApplyHighGraphics()
    if FPSBoostActive or S.fpsBoost then
        RestoreDefaultGraphics()
    else
        CaptureGraphicsBackup()
        RemoveHaimiyachGraphicsEffects()
    end

    S.fpsBoost = false
    S.highGraphics = true
    FPSBoostActive = false
    HighGraphicsActive = true

    if FPSBoostDescendantConnection then
        pcall(function() FPSBoostDescendantConnection:Disconnect() end)
        FPSBoostDescendantConnection = nil
    end

    RestoreWorkspaceEffects()

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        SafeSetProperty(terrain, "Decoration", true)
        SafeSetProperty(terrain, "WaterReflectance", 0.35)
        SafeSetProperty(terrain, "WaterTransparency", 0.25)
        SafeSetProperty(terrain, "WaterWaveSize", 0.12)
        SafeSetProperty(terrain, "WaterWaveSpeed", 8)
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    SafeSetProperty(part, "CastShadow", true)
                end
            end
        end
    end

    SafeSetProperty(Lighting, "GlobalShadows", true)
    SafeSetProperty(Lighting, "Brightness", 3)
    SafeSetProperty(Lighting, "ClockTime", 14.25)
    SafeSetProperty(Lighting, "FogStart", 0)
    SafeSetProperty(Lighting, "FogEnd", 100000)
    SafeSetProperty(Lighting, "ExposureCompensation", 0.16)
    SafeSetProperty(Lighting, "EnvironmentDiffuseScale", 1)
    SafeSetProperty(Lighting, "EnvironmentSpecularScale", 1)
    SafeSetProperty(Lighting, "ShadowSoftness", 0.18)
    SafeSetProperty(Lighting, "Ambient", Color3.fromRGB(105, 105, 105))
    SafeSetProperty(Lighting, "OutdoorAmbient", Color3.fromRGB(150, 150, 150))
    pcall(function() Lighting.Technology = Enum.Technology.ShadowMap end)
    pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel10 end)

    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "Haimiyach_HD_Atmosphere"
    atmosphere.Density = 0.24
    atmosphere.Offset = 0.05
    atmosphere.Color = Color3.fromRGB(220, 230, 255)
    atmosphere.Decay = Color3.fromRGB(90, 110, 140)
    atmosphere.Glare = 0.24
    atmosphere.Haze = 0.65
    atmosphere.Parent = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name = "Haimiyach_HD_Bloom"
    bloom.Intensity = 0.48
    bloom.Size = 34
    bloom.Threshold = 0.95
    bloom.Parent = Lighting

    local color = Instance.new("ColorCorrectionEffect")
    color.Name = "Haimiyach_HD_ColorCorrection"
    color.Brightness = 0.04
    color.Contrast = 0.18
    color.Saturation = 0.16
    color.TintColor = Color3.fromRGB(255, 252, 244)
    color.Parent = Lighting

    local rays = Instance.new("SunRaysEffect")
    rays.Name = "Haimiyach_HD_SunRays"
    rays.Intensity = 0.095
    rays.Spread = 0.78
    rays.Parent = Lighting

    local depth = Instance.new("DepthOfFieldEffect")
    depth.Name = "Haimiyach_HD_DepthOfField"
    depth.FarIntensity = 0.08
    depth.FocusDistance = 80
    depth.InFocusRadius = 70
    depth.NearIntensity = 0.02
    depth.Parent = Lighting
end

local function SetFPSBoostEnabled(state)
    if state then
        ApplyFPSBoostGraphics()
    else
        if FPSBoostActive or S.fpsBoost then
            RestoreDefaultGraphics()
        else
            S.fpsBoost = false
        end
    end
end

local function SetHighGraphicsEnabled(state)
    if state then
        ApplyHighGraphics()
    else
        if HighGraphicsActive or S.highGraphics then
            RestoreDefaultGraphics()
        else
            S.highGraphics = false
        end
    end
end

local fpsCounter, currentFps = 0, 0
local fpsConnection
fpsConnection = RunService.RenderStepped:Connect(function()
    fpsCounter = fpsCounter + 1
end)
task.spawn(function()
    while not S.killed do
        currentFps = fpsCounter
        fpsCounter = 0
        task.wait(1)
    end
end)
local function getPingText()
    local ok, v = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
    end)
    return ok and tostring(v) or "? ms"
end

-- // ============================================================ \\ --
-- //                    WEBHOOK REPORTING                        \\ --
-- // ============================================================ \\ --
local httpRequest = (syn and syn.request) or http_request or request or (http and http.request)
local function hms(sec)
    sec = math.floor(sec); local h = math.floor(sec / 3600); local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, sec%60) end
    return sec .. "s"
end
local function sendWebhook(isTest)
    if not httpRequest then notify("Webhook", "Executor exposes no HTTP request fn"); return false end
    if not string.match(S.webhookUrl or "", "^https?://") then notify("Webhook", "Set a valid webhook URL"); return false end
    local payload = { username = "Grow a Garden 2", embeds = { {
        title = "🌱 Farm Report — " .. LocalPlayer.Name, color = 5763719,
        fields = {
            { name = "💰 Sheckles", value = fmt(getSheckles()), inline = true },
            { name = "🪙 Tokens",   value = fmt(getTokens()),   inline = true },
            { name = "🌾 Plot",     value = tostring((myPlot() and myPlot().Name) or "?"), inline = true },
            { name = "📊 Session",  value = string.format("bought %d · planted %d · harvested %d · sold %d (+%s)",
                Stats.bought, Stats.planted, Stats.harvested, Stats.sold, fmt(Stats.earned)), inline = false },
            { name = "✨ Extras",   value = string.format("sprinklers %d · watered %d · tamed %d · opened %d · stolen %d",
                Stats.sprinklers, Stats.watered, Stats.tamed, Stats.opened, Stats.stolen), inline = false },
            { name = "🌱 Seed Events", value = "available: " .. getSeedEventAvailableText() .. "\nclaimed: " .. getSeedEventClaimText() .. "\nlast: " .. getSeedEventLastText(), inline = false },
            { name = "⏱️ Uptime",   value = hms(os.clock() - Stats.startAt), inline = true },
        }, footer = { text = "HAIMIYACH HUB · GAG2" },
    } } }
    local ok, res = pcall(function()
        return httpRequest({ Url = S.webhookUrl, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
    end)
    local code = ok and res and (res.StatusCode or res.Status or res.status_code)
    local good = ok and (code == nil or code == 200 or code == 204)
    if isTest then notify("Webhook", good and "Test sent ✅" or ("Failed (" .. tostring(code) .. ")")) end
    return good
end
loopOn(function() return S.webhookEnabled end, function() return S.webhookInterval end, function() sendWebhook(false) end)

local DisconnectWebhookSent = false
local function sendDisconnectWebhook(reason, detail, force)
    if not force and not S.webhookDisconnect then return false end
    if DisconnectWebhookSent and not force then return false end
    if not httpRequest then
        if force then notify("Webhook", "Executor exposes no HTTP request fn", 4) end
        return false
    end
    if not string.match(S.webhookUrl or "", "^https?://") then
        if force then notify("Webhook", "Set a valid webhook URL", 4) end
        return false
    end

    DisconnectWebhookSent = true
    local payload = { username = "Grow a Garden 2", embeds = { {
        title = "⚠️ Disconnect Alert — " .. LocalPlayer.Name,
        color = 16753920,
        fields = {
            { name = "Reason", value = tostring(reason or "Disconnect detected"), inline = false },
            { name = "Detail", value = tostring(detail or "No extra detail"), inline = false },
            { name = "PlaceId", value = tostring(game.PlaceId), inline = true },
            { name = "JobId", value = tostring(game.JobId ~= "" and game.JobId or "Unknown"), inline = true },
            { name = "Sheckles", value = fmt(getSheckles()), inline = true },
            { name = "Tokens", value = fmt(getTokens()), inline = true },
            { name = "Seed Events", value = "available: " .. getSeedEventAvailableText() .. "\nclaimed: " .. getSeedEventClaimText() .. "\nlast: " .. getSeedEventLastText(), inline = false },
            { name = "Uptime", value = hms(os.clock() - Stats.startAt), inline = true },
        },
        footer = { text = "HAIMIYACH HUB · DISCONNECT WEBHOOK" },
    } } }

    local ok, res = pcall(function()
        return httpRequest({
            Url = S.webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    local code = ok and res and (res.StatusCode or res.Status or res.status_code)
    local good = ok and (code == nil or code == 200 or code == 204)
    if force then notify("Webhook", good and "Disconnect test sent ✅" or ("Failed (" .. tostring(code) .. ")"), 4) end
    return good
end

local function watchDisconnectPrompts()
    -- Roblox disconnect/kick prompt through GuiService.
    pcall(function()
        if GuiService and GuiService.ErrorMessageChanged then
            GuiService.ErrorMessageChanged:Connect(function(message)
                if S.killed or not S.webhookDisconnect then return end
                local text = tostring(message or "")
                if text ~= "" then
                    sendDisconnectWebhook("ROBLOX ERROR MESSAGE", text, false)
                end
            end)
        end
    end)

    -- Teleport/server-hop failures.
    pcall(function()
        if TeleportService and TeleportService.TeleportInitFailed then
            TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
                if S.killed or not S.webhookDisconnect then return end
                if player == LocalPlayer then
                    sendDisconnectWebhook("TELEPORT FAILED", tostring(result) .. " | " .. tostring(errorMessage or ""), false)
                end
            end)
        end
    end)

    -- Fallback detector for CoreGui ErrorPrompt text.
    task.spawn(function()
        local Core = nil
        pcall(function() Core = game:GetService("CoreGui") end)
        if not Core then return end
        local function readText(root)
            local parts = {}
            pcall(function()
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                        local tx = tostring(d.Text or "")
                        if tx ~= "" then parts[#parts + 1] = tx end
                    end
                end
            end)
            return table.concat(parts, " | ")
        end
        local function looksLikeDisconnect(text)
            local t = string.lower(tostring(text or ""))
            return string.find(t, "disconnect") or string.find(t, "kicked") or string.find(t, "lost connection") or
                   string.find(t, "reconnect") or string.find(t, "error code") or string.find(t, "teleport failed")
        end
        local function inspect(inst)
            if S.killed or not S.webhookDisconnect then return end
            local text = readText(inst)
            if text ~= "" and looksLikeDisconnect(text) then
                sendDisconnectWebhook("ROBLOX ERROR PROMPT", text, false)
            end
        end
        pcall(function()
            Core.DescendantAdded:Connect(function(inst)
                if S.killed or not S.webhookDisconnect then return end
                task.wait(0.25)
                if inst.Name == "ErrorPrompt" or inst.Name == "ErrorFrame" or inst.Name == "promptOverlay" then
                    inspect(inst)
                else
                    local p = inst.Parent
                    while p and p ~= Core do
                        if p.Name == "ErrorPrompt" or p.Name == "ErrorFrame" or p.Name == "promptOverlay" then
                            inspect(p)
                            break
                        end
                        p = p.Parent
                    end
                end
            end)
        end)
    end)
end
watchDisconnectPrompts()

-- // ============================================================ \\ --

-- // ============================================================ \ --
-- //                 HAIMIYACH HUB CUSTOM GUI                    \ --
-- // ============================================================ \ --

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = nil
pcall(function() CoreGui = game:GetService("CoreGui") end)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- clean old GUI first
local GUI_NAMES = {
    "Haimiyach_GAG2_Custom_UI",
    "Haimiyach_GAG2_Show_Button",
    "Haimiyach_Hub_Custom_UI",
    "Haimiyach_Hub_Show_Button",
    "Haimiyach_Premium_GUI",
    "Haimiyach_FOV_Circle",
    "Haimiyach_FPS_Boost_Dashboard",
    "SkrilyaHub",
    "MacLib"
}
local function cleanContainer(container)
    if not container then return end
    for _, name in ipairs(GUI_NAMES) do
        pcall(function()
            local old = container:FindFirstChild(name)
            if old then old:Destroy() end
        end)
    end
    for _, child in ipairs(container:GetChildren()) do
        pcall(function()
            local n = string.lower(child.Name or "")
            if child:IsA("ScreenGui") and (string.find(n, "skrilya") or string.find(n, "maclib") or string.find(n, "haimiyach_gag2") or string.find(n, "haimiyach_hub") or string.find(n, "haimiyach_premium") or string.find(n, "haimiyach_fov") or string.find(n, "haimiyach_fps")) then
                child:Destroy()
            end
        end)
    end
end
cleanContainer(PlayerGui)
cleanContainer(CoreGui)

local UI = {
    Scale = 1,
    Keybind = Enum.KeyCode.LeftControl,
    Visible = true,
    Minimized = false,
    Unloaded = false,
    CurrentTab = nil,
    Pages = {},
    TabButtons = {},
    LiveLabels = {},
    Connections = {},
}

local function trackConnection(conn)
    if conn then UI.Connections[#UI.Connections + 1] = conn end
    return conn
end

local function disconnectUiConnections()
    for _, conn in ipairs(UI.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if table.clear then
        table.clear(UI.Connections)
    else
        for i = #UI.Connections, 1, -1 do
            UI.Connections[i] = nil
        end
    end
end

local T = {
    Bg = Color3.fromRGB(22,22,22),
    Top = Color3.fromRGB(29,29,29),
    Panel = Color3.fromRGB(16,16,16),
    Panel2 = Color3.fromRGB(24,24,24),
    Row = Color3.fromRGB(32,32,32),
    Row2 = Color3.fromRGB(40,40,40),
    Text = Color3.fromRGB(242,242,242),
    Muted = Color3.fromRGB(170,170,170),
    White = Color3.fromRGB(232,232,232),
    DarkText = Color3.fromRGB(20,20,20),
    Stroke = Color3.fromRGB(60,60,60),
    Good = Color3.fromRGB(230,230,230),
}

local function new(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end
local function corn