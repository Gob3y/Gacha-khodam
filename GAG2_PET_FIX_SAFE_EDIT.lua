-- // ============================================================ \\ --
-- //          HAIMIYACH HUB | Grow a Garden 2        \\ --
-- // ============================================================ \\ --
--  Game : Grow a Garden 2   Place: 97598239454123   Framework: Standard
--  Net  : local Net = require(ReplicatedStorage.SharedModules.Networking)
--         Net.<Category>.<Action>:Fire(args...)   (single Packet RemoteEvent transport)
--         :Fire is universal - events ignore the return, requests consume it.
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
-- Also carry live settings into the next instance, so Webhook URL/ENABLE REPORTS
-- stay active even when the user executes the script again without pressing SAVE CONFIG.
pcall(function()
    local prev = getgenv and getgenv().HaimiyachGAG2
    if prev then
        if getgenv and type(prev.S) == "table" then
            local carry = {}
            for k, v in pairs(prev.S) do
                local tv = type(v)
                if tv == "table" then
                    local t2 = {}
                    for kk, vv in pairs(v) do
                        local kt, vt = type(kk), type(vv)
                        if (kt == "string" or kt == "number") and (vt == "boolean" or vt == "number" or vt == "string") then
                            t2[kk] = vv
                        end
                    end
                    carry[k] = t2
                elseif tv == "boolean" or tv == "number" or tv == "string" then
                    carry[k] = v
                end
            end
            getgenv().HaimiyachGAG2PendingConfig = carry
        end
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
    local ok, res = pcall(a.Fire, a, ...)
    if not ok then return false, res end
    return true, res
end
-- NO pacer: for the high-volume harvest/sell hot path (the 60/s pacer throttled it to ~0).
local function fireFast(path, ...)
    local a = action(path)
    if not (a and a.Fire) then return false, "no action: " .. path end
    local ok, res = pcall(a.Fire, a, ...)
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
HaimiyachGAG2_MutationNames = (function()
    local out, seen = {}, {}
    local folder = ReplicatedStorage:FindFirstChild("SharedModules")
    folder = folder and folder:FindFirstChild("MutationData")
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("ModuleScript") and not seen[m.Name] then
                seen[m.Name] = true
                out[#out + 1] = m.Name
            end
        end
    end
    if #out == 0 then
        for _, n in ipairs({ "Gold", "Rainbow", "Electric", "Frozen", "Bloodlit", "Chained", "Starstruck" }) do
            if not seen[n] then seen[n] = true; out[#out + 1] = n end
        end
    end
    table.sort(out)
    return out
end)()

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
local function HaimiyachGAG2_InventorySeedCount(seedName)
    seedName = tostring(seedName or "")
    if seedName == "" then return 0 end
    local total = 0

    local okInv, names = pcall(function() return invNames("Seeds") end)
    if okInv and type(names) == "table" then
        total = total + (tonumber(names[seedName]) or 0)
    end

    local okTools, tools = pcall(function() return toolsByAttr("SeedTool", seedName) end)
    if okTools and type(tools) == "table" then
        total = total + #tools
    end

    return total
end

local function HaimiyachGAG2_SeedPurchaseConfirmed(seedName, beforeMoney, beforeCount, beforeStock, price)
    seedName = tostring(seedName or "")
    beforeMoney = tonumber(beforeMoney) or getSheckles()
    beforeCount = tonumber(beforeCount) or HaimiyachGAG2_InventorySeedCount(seedName)
    beforeStock = tonumber(beforeStock)
    price = tonumber(price) or 0

    local deadline = os.clock() + 1.15
    repeat
        task.wait(0.08)

        local nowCount = HaimiyachGAG2_InventorySeedCount(seedName)
        if nowCount > beforeCount then
            return true, "inventory"
        end

        local nowMoney = getSheckles()
        if price > 0 and nowMoney < beforeMoney then
            return true, "sheckles"
        end

        if beforeStock ~= nil then
            local nowStock = tonumber(stockOf("SeedShop", seedName))
            if nowStock ~= nil and nowStock < beforeStock then
                return true, "stock"
            end
        end
    until os.clock() >= deadline

    return false, "not-confirmed"
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

function HaimiyachGAG2_NameKey(text)
    text = string.lower(tostring(text or ""))
    return (string.gsub(text, "[^%w]", ""))
end

function HaimiyachGAG2_ObjectName(obj)
    if not obj then return "" end
    for _, attr in ipairs({ "Fruit", "FruitName", "CorePartName", "Plant", "PlantName", "Seed", "SeedName", "Crop", "CropName", "ItemName" }) do
        local v = obj:GetAttribute(attr)
        if type(v) == "string" and v ~= "" then return v end
    end
    -- HarvestPrompt often sits inside HarvestPart. HarvestPart may only carry PlantId/FruitId,
    -- while the real fruit name is stored on the parent fruit/plant model.
    local node = obj.Parent
    local guard = 0
    while node and node ~= Workspace and guard < 8 do
        guard = guard + 1
        for _, attr in ipairs({ "Fruit", "FruitName", "CorePartName", "Plant", "PlantName", "Seed", "SeedName", "Crop", "CropName", "ItemName" }) do
            local v = node:GetAttribute(attr)
            if type(v) == "string" and v ~= "" then return v end
        end
        if node:IsA("Model") then
            local n = tostring(node.Name or "")
            if n ~= "" and n ~= "HarvestPart" then
                local first = string.match(n, "^([^_]+)_")
                return (first and first ~= "") and first or n
            end
        end
        node = node.Parent
    end
    local n = tostring(obj.Name or "")
    local first = string.match(n, "^([^_]+)_")
    if first and first ~= "" then return first end
    return n
end

function HaimiyachGAG2_ObjectNameCandidates(obj)
    local out, seen = {}, {}
    local function add(v)
        if type(v) ~= "string" or v == "" then return end
        local key = HaimiyachGAG2_NameKey(v)
        if key ~= "" and not seen[key] then
            seen[key] = true
            out[#out + 1] = v
        end
    end
    local function scan(inst)
        if not inst then return end
        for _, attr in ipairs({ "Fruit", "FruitName", "CorePartName", "Plant", "PlantName", "Seed", "SeedName", "Crop", "CropName", "ItemName" }) do
            add(inst:GetAttribute(attr))
        end
        local n = tostring(inst.Name or "")
        if n ~= "" and n ~= "HarvestPart" and n ~= "Handle" then
            local first = string.match(n, "^([^_]+)_")
            add((first and first ~= "") and first or n)
        end
    end
    scan(obj)
    local node = obj and obj.Parent or nil
    local guard = 0
    while node and node ~= Workspace and guard < 10 do
        guard = guard + 1
        scan(node)
        node = node.Parent
    end
    if #out == 0 then add(HaimiyachGAG2_ObjectName(obj)) end
    return out
end

function HaimiyachGAG2_ObjectKg(obj)
    if not obj then return nil end
    for _, attr in ipairs({ "Weight", "WeightKg", "KG", "Kg", "Kilogram", "Kilograms", "Mass", "Size" }) do
        local v = obj:GetAttribute(attr)
        if type(v) == "number" then return v end
        if type(v) == "string" then
            local n = string.match(v, "([%d%.]+)")
            if n then return tonumber(n) end
        end
    end
    local n = string.match(tostring(obj.Name or ""), "([%d%.]+)%s*[Kk][Gg]")
    if n then return tonumber(n) end
    return nil
end

local KG_MODE_OPTIONS = { "OFF", "BELOW KG", "ABOVE KG" }

function HaimiyachGAG2_KgModeActive(mode, value)
    mode = string.upper(tostring(mode or "OFF"))
    return mode ~= "OFF" and (tonumber(value) or 0) > 0
end

function HaimiyachGAG2_KgValueOk(kg, mode, value)
    mode = string.upper(tostring(mode or "OFF"))
    local limit = tonumber(value) or 0
    if mode == "OFF" or limit <= 0 then return true end
    kg = tonumber(kg)
    if not kg then return false end
    if string.find(mode, "BELOW", 1, true) then
        return kg < limit
    elseif string.find(mode, "ABOVE", 1, true) then
        return kg > limit
    end
    return true
end

function HaimiyachGAG2_ObjectKgOk(obj, mode, value)
    return HaimiyachGAG2_KgValueOk(HaimiyachGAG2_ObjectKg(obj), mode, value)
end

function HaimiyachGAG2_ObjectMutation(obj)
    if not obj then return nil end
    local v = obj:GetAttribute("Mutation")
    if type(v) == "string" and v ~= "" and v ~= "None" then return v end
    for _, d in ipairs(obj:GetDescendants()) do
        local mv = d:GetAttribute("Mutation")
        if type(mv) == "string" and mv ~= "" and mv ~= "None" then return mv end
    end
    return nil
end

function HaimiyachGAG2_HasSelection(selected)
    if type(selected) ~= "table" then return false end
    for _, enabled in pairs(selected) do
        if enabled == true then return true end
    end
    return false
end

function HaimiyachGAG2_SelectedNameOk(obj, selected)
    if not HaimiyachGAG2_HasSelection(selected) then return false end
    local candidates = HaimiyachGAG2_ObjectNameCandidates and HaimiyachGAG2_ObjectNameCandidates(obj) or { HaimiyachGAG2_ObjectName(obj) }
    for name, enabled in pairs(selected) do
        if enabled == true then
            local want = HaimiyachGAG2_NameKey(name)
            if want ~= "" then
                for _, candidate in ipairs(candidates) do
                    local got = HaimiyachGAG2_NameKey(candidate)
                    if got == want then return true end
                end
            end
        end
    end
    return false
end

function HaimiyachGAG2_SelectedMutationOk(obj, selected)
    if not HaimiyachGAG2_HasSelection(selected) then return false end
    local mutation = HaimiyachGAG2_ObjectMutation(obj)
    if not mutation then return false end
    local key = HaimiyachGAG2_NameKey(mutation)
    for name, enabled in pairs(selected) do
        if enabled == true and HaimiyachGAG2_NameKey(name) == key then return true end
    end
    return false
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
                    out[#out + 1] = { plantId = tostring(pid), fruitId = tostring(m:GetAttribute("FruitId") or ""), obj = m }
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
-- SpawnPetController creates the visible pet in Map.WildPetSpawns and puts BuyPrompt on the model primary part.
local function HaimiyachGAG2_ModelPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    local ok, cf = pcall(function() return obj:GetPivot() end)
    if ok and cf then return cf.Position end
    local bp = obj:FindFirstChildWhichIsA("BasePart", true)
    return bp and bp.Position or nil
end

local function HaimiyachGAG2_FindPrompt(root, promptName)
    if not root then return nil end
    if root:IsA("ProximityPrompt") then
        if not promptName or root.Name == promptName then return root end
    end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ProximityPrompt") and (not promptName or d.Name == promptName) then
            return d
        end
    end
    return nil
end

local function HaimiyachGAG2_FindWildPetVisual(refPart)
    if not refPart then return nil, nil, nil end
    local map = Workspace:FindFirstChild("Map")
    local spawns = map and map:FindFirstChild("WildPetSpawns")
    if not spawns then return nil, nil, nil end

    local refName = tostring(refPart.Name or "")
    local petName = tostring(refPart:GetAttribute("PetName") or refPart:GetAttribute("Name") or "")
    local refPos = refPart.Position
    local best, bestScore = nil, -1

    for _, model in ipairs(spawns:GetChildren()) do
        if model:IsA("Model") then
            local score = 0
            local mn = tostring(model.Name or "")
            local mp = HaimiyachGAG2_ModelPos(model)
            local attrName = tostring(model:GetAttribute("PetName") or "")

            if petName ~= "" and attrName == petName then score = score + 5 end
            if refName ~= "" and string.find(mn, refName, 1, true) then score = score + 5 end
            if mp and (mp - refPos).Magnitude <= 18 then score = score + 3 end

            if score > bestScore then
                bestScore = score
                best = model
            end
        end
    end

    if best and bestScore > 0 then
        local prompt = HaimiyachGAG2_FindPrompt(best, "BuyPrompt") or HaimiyachGAG2_FindPrompt(best)
        local promptPart = prompt and prompt.Parent or best:FindFirstChildWhichIsA("BasePart", true)
        return best, prompt, promptPart
    end

    return nil, nil, nil
end

local function wildPets()
    local out = {}
    local map = Workspace:FindFirstChild("Map")
    local ref = map and (map:FindFirstChild("WildPetRef") or map:FindFirstChild("WildPets"))
    if ref then
        for _, p in ipairs(ref:GetChildren()) do
            if p:IsA("BasePart") then
                local spawnedAt = tonumber(p:GetAttribute("SpawnedAt")) or tonumber(p:GetAttribute("SpawnTime")) or 0
                local lifetime = tonumber(p:GetAttribute("Lifetime")) or tonumber(p:GetAttribute("LeaveTime")) or tonumber(p:GetAttribute("DespawnTime")) or 0
                local visual, prompt, promptPart = HaimiyachGAG2_FindWildPetVisual(p)
                local pos = HaimiyachGAG2_ModelPos(promptPart) or HaimiyachGAG2_ModelPos(visual) or p.Position
                out[#out + 1] = {
                    part = p,
                    visual = visual,
                    prompt = prompt,
                    promptPart = promptPart,
                    name = p:GetAttribute("PetName") or p:GetAttribute("Name") or (visual and visual:GetAttribute("PetName")) or p.Name,
                    rarity = p:GetAttribute("Rarity"),
                    price = tonumber(p:GetAttribute("Price")) or 0,
                    owner = tonumber(p:GetAttribute("OwnerUserId")) or 0,
                    spawnedAt = spawnedAt,
                    lifetime = lifetime,
                    state = p:GetAttribute("State") or p:GetAttribute("PetState"),
                    pos = pos,
                }
            end
        end
    end
    return out
end

function HaimiyachGAG2_WorldPetNames()
    -- Target preset list for AFK: not only currently spawned pets.
    -- New pets should appear automatically if the game adds them to SharedModules.PetModules / SharedData.PetData.
    local seen, names = {}, {}
    local function addName(n)
        n = tostring(n or "")
        if n ~= "" and not seen[n] then
            seen[n] = true
            names[#names + 1] = n
        end
    end

    -- Main game data source: all world pet species, even if not spawned in this server yet.
    pcall(function()
        local mods = ReplicatedStorage:FindFirstChild("SharedModules")
        local petModules = mods and mods:FindFirstChild("PetModules")
        if petModules then
            local data = require(petModules)
            if type(data) == "table" then
                for petName, info in pairs(data) do
                    if type(petName) == "string" and type(info) == "table" then
                        addName(petName)
                    end
                end
            end
        end
    end)

    -- Extra data source/fallback if the game stores pet definitions here.
    pcall(function()
        local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
        local petDataModule = sharedData and sharedData:FindFirstChild("PetData")
        if petDataModule then
            local data = require(petDataModule)
            if type(data) == "table" then
                for petName, info in pairs(data) do
                    if type(petName) == "string" and type(info) == "table" then
                        addName(petName)
                    end
                end
            end
        end
    end)

    -- Live spawned pets are still included, useful if the game adds a temporary/event pet.
    local ok, pets = pcall(wildPets)
    if ok and type(pets) == "table" then
        for _, w in ipairs(pets) do
            addName(w and w.name)
        end
    end

    -- Safe fallback so the dropdown is still useful if require() fails on some executor.
    local fallback = {
        "Raccoon", "Monkey", "Robin", "Frog", "Bunny", "Deer",
        "Bear", "Owl", "Bee", "Unicorn", "BlackDragon",
        "IceSerpent", "GoldenDragonfly"
    }
    for _, n in ipairs(fallback) do addName(n) end

    table.sort(names)
    return names
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
    restockPredictionMode = "HISTORY + LIVE STOCK", restockRarityFilter = "MYTHIC", restockWatchedSeeds = {}, restockNotifyWatched = false, restockAutoBuyWatched = false, restockAutoHopTarget = false,
    autoPlant = false, plantSpacing = 4, plantSeed = "Best owned", plantSeeds = { ["BEST OWNED"] = true },
    autoHarvest = false, harvestAll = true, harvestFruitTargets = {}, harvestKeepMutations = {}, harvestMaxKg = 0, harvestKgMode = "OFF", harvestKgValue = 0, harvestInterval = 2, harvestDelay = 0.01,
    autoSell = false, sellInterval = 15, sellKeepMutations = {}, sellKeepKgMode = "OFF", sellKeepKgValue = 0,
    autoExpand = false, autoPot = false, autoDaily = false, dailyDelay = 60,
    autoClaimSeedEvent = false, claimUseFly = false, seedEventDelay = 3,
    autoCollectSeed = false, autoCollectFruit = false, autoCollectPet = false, collectSeedDelay = 1, collectSeedTeleport = true, collectSeedReturn = true,
    autoShovelPlants = false, autoShovelFruits = false, shovelPlantTargets = {}, shovelFruitTargets = {}, shovelKeepMutations = {}, shovelMaxKg = 0, shovelKgMode = "OFF", shovelKgValue = 0, shovelNameFilter = "", shovelDelay = 2,
    autoFavoriteFruits = false, favoriteFruitTargets = {}, favoriteMutations = {}, favoriteFruitFilter = "", favoriteMinKg = 0, favoriteMaxKg = 0, favoriteKgMode = "OFF", favoriteKgValue = 0, favoriteMutationFilter = "", unfavoriteNotMatching = false, favoriteDelay = 3,
    -- boosts
    autoSprinkler = false, sprinklerInterval = 30, sprinklerTargetMode = "GARDEN CENTER", sprinklerTargets = {},
    autoWater = false, waterInterval = 8,
    autoTrowelPlants = false, trowelPlantTargets = {}, trowelPositionMode = "MAPPING", trowelDelay = 3,
    autoSkill = false, skillStats = {},          -- {"BaseSpeed"=true,...}
    -- pets
    autoEquipPets = false, autoPetSlot = false, bestPetMode = "FARM",
    autoBuyPets = false, buyWorldPets = {}, wildPetRarities = {}, wildPetOnlyUnowned = true, petTeleport = true, petBuyInterval = 5,
    sellPets = {}, autoSellPets = false,
    -- eggs / crates / packs
    autoEgg = false, autoCrate = false, autoPack = false, autoBuyCrates = false, buyCrates = {}, crateBuyDelay = 5, openInterval = 4,
    -- shop
    autoGear = false, autoBuyAllGear = false, gearBuy = {}, gearInterval = 10,
    -- steal
    autoSteal = false, stealTeleport = true, stealReturnBase = true, stealDelay = 0.05,
    -- misc
    autoMail = false, autoAcceptGift = false, autoSendMail = false, mailTargetUsername = "", mailNote = "Here is a gift!", mailSeedTargets = {}, mailFruitTargets = {}, mailGearTargets = {}, mailPetTargets = {}, mailCrateTargets = {}, mailSeedPackTargets = {}, mailSprinklerTargets = {}, mailWateringCanTargets = {}, mailMushroomTargets = {}, mailGnomeTargets = {}, mailRaccoonTargets = {}, mailTrowelTargets = {}, mailPropTargets = {}, mailEmptyPotTargets = {}, mailOtherCategories = {}, mailSendCount = 1, mailSendDelay = 30, autoHop = false, hopInterval = 0, hopConditions = {}, autoReconnect = false, reconnectDelay = 5,
    -- protect
    protectNoClip = false, protectAntiFling = false, protectAntiRagdoll = false, protectAntiKnockback = false, protectAntiSit = false, protectAntiVoid = false, protectVelocityLimit = 85, protectVoidY = -25,
    codeText = "", autoCodes = false, antiAfk = true, disableCutscene = false,
    -- perf / webhook
    fpsBoost = false, fpsBoostMode = "BALANCED", highGraphics = false, blankScreen = false,
    webhookEnabled = false, webhookUrl = "", webhookInterval = 300,
    webhookDisconnect = false,
    -- esp
    espGardenFruit = false, espGardenGrowing = false, espGardenPlant = false, espGardenValue = false,
    espBackpackFruit = false, espBackpackValue = false, espBackpackTotal = false,
    espWildPet = false, espWildPetDetails = { RARITY = true, PRICE = true, TIMER = true },
    -- config / auto execute
    notifyRareWeather = false, rareWeatherTargets = { Rainbow = true, Snowfall = true, Starfall = true, Aurora = true },
    autoExecute = false, autoExecuteUrl = "",
    uiScale = 0,
    uiKeybindName = "LeftControl",
    killed = false,
}
local Stats = { bought = 0, seedBought = 0, gearBought = 0, crateBought = 0, sprinklerBought = 0, planted = 0, harvested = 0, sold = 0, earned = 0,
    sprinklers = 0, watered = 0, tamed = 0, opened = 0, stolen = 0, codes = 0,
    purchaseSeeds = {}, purchaseGear = {}, purchaseCrates = {}, purchaseSprinklers = {},
    lastSeedBuy = "NONE", lastGearBuy = "NONE", lastCrateBuy = "NONE", lastSprinklerBuy = "NONE",
    seedEvents = 0, seedRainbow = 0, seedGold = 0, lastSeedEvent = "NONE", lastSeedClaimAt = 0,
    collectedSeeds = 0, lastCollectedSeed = "NONE", lastCollectSeedAt = 0,
    collectedFruits = 0, lastCollectedFruit = "NONE", lastCollectFruitAt = 0,
    collectedPets = 0, lastCollectedPet = "NONE", lastCollectPetAt = 0,
    lastSellValue = 0, lastSellAt = 0,
    lastAction = "NONE", lastActionAt = 0,
    lastWarning = "OK", lastWarningAt = 0,
    lastDisconnectReason = "NONE", lastDisconnectAt = 0,
    lastWebhookStatus = "OFF", lastWebhookAt = 0,
    lastReturnGardenStatus = "WAITING", lastReturnGardenAt = 0,
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

function Stats.SetLastAction(kind, detail)
    kind = tostring(kind or "ACTION")
    detail = tostring(detail or "")
    detail = detail:gsub("%c", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if detail == "" then detail = "-" end
    if #detail > 70 then detail = string.sub(detail, 1, 67) .. "..." end
    Stats.lastAction = kind .. ": " .. detail
    Stats.lastActionAt = os.clock()
end

function Stats.SetWarning(kind, detail)
    kind = tostring(kind or "WARNING")
    detail = tostring(detail or "")
    detail = detail:gsub("%c", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if detail == "" then detail = "-" end
    if #detail > 70 then detail = string.sub(detail, 1, 67) .. "..." end
    Stats.lastWarning = kind .. ": " .. detail
    Stats.lastWarningAt = os.clock()
end


-- // Mailbox / Gift by username (NO top-level local variables; safer for executor compile)
HaimiyachGAG2_MailGearCategories = {
    "Sprinklers",
    "WateringCans",
    "Trowels",
    "Mushrooms",
    "Gnomes",
    "Raccoons",
    "EmptyPots"
}

function HaimiyachGAG2_TrimText(v)
    v = tostring(v or "")
    v = v:gsub("%c", " ")
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    return v
end

function HaimiyachGAG2_NormalMailName(v)
    v = string.lower(HaimiyachGAG2_TrimText(v))
    v = v:gsub("%s+", " ")
    if string.sub(v, -5) == " seed" then
        v = string.sub(v, 1, #v - 5)
    end
    return v
end

function HaimiyachGAG2_SelectedTextMatch(selected, name)
    if type(selected) ~= "table" then return false end
    name = HaimiyachGAG2_NormalMailName(name)
    if name == "" then return false end
    for sel, enabled in pairs(selected) do
        if enabled == true and HaimiyachGAG2_NormalMailName(sel) == name then
            return true
        end
    end
    return false
end

function HaimiyachGAG2_MailEntryName(category, key, value)
    if type(value) == "table" then
        return value.FruitName or value.PetName or value.Name or value.ItemName or value.Type or value.SeedName or tostring(key)
    end
    return tostring(key)
end

function HaimiyachGAG2_MailStackCount(value)
    if type(value) == "number" then return math.floor(value) end
    if type(value) == "table" then
        return math.floor(tonumber(value.Count) or tonumber(value.Amount) or tonumber(value.Quantity) or 1)
    end
    return 1
end

function HaimiyachGAG2_ResolveMailUserId(username)
    username = HaimiyachGAG2_TrimText(username)
    if username == "" then return nil, "Enter target username" end
    for _, plr in ipairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == string.lower(username) or string.lower(plr.DisplayName) == string.lower(username) then
            return plr.UserId
        end
    end
    local ok, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    if ok and type(userId) == "number" and userId > 0 then
        return userId
    end
    return nil, "Username not found"
end

function HaimiyachGAG2_AddMailItem(items, category, key, count, maxEach)
    if type(items) ~= "table" then return 0 end
    if #items >= 20 then return 0 end
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return 0 end
    maxEach = math.floor(tonumber(maxEach) or 1)
    if maxEach < 1 then maxEach = 1 end
    if maxEach > 20 then maxEach = 20 end
    if count > maxEach then count = maxEach end
    table.insert(items, {
        Category = tostring(category),
        ItemKey = tostring(key),
        Count = count
    })
    return count
end

function HaimiyachGAG2_AddMailFromInventory(items, category, selected, maxEach, uniqueOnly)
    if type(selected) ~= "table" or not HaimiyachGAG2_HasSelection(selected) then return end
    for key, value in pairs(inv(category)) do
        if #items >= 20 then break end
        if HaimiyachGAG2_SelectedTextMatch(selected, HaimiyachGAG2_MailEntryName(category, key, value)) then
            HaimiyachGAG2_AddMailItem(items, category, key, uniqueOnly and 1 or HaimiyachGAG2_MailStackCount(value), uniqueOnly and 1 or maxEach)
        end
    end
end

function HaimiyachGAG2_AddMailGearFromInventory(items, maxEach)
    if type(S.mailGearTargets) ~= "table" or not HaimiyachGAG2_HasSelection(S.mailGearTargets) then return end
    for _, category in ipairs(HaimiyachGAG2_MailGearCategories) do
        if #items >= 20 then break end
        HaimiyachGAG2_AddMailFromInventory(items, category, S.mailGearTargets, maxEach, false)
    end
end

function HaimiyachGAG2_AddMailOldOtherCategories(items, maxEach)
    if type(S.mailOtherCategories) ~= "table" or not HaimiyachGAG2_HasSelection(S.mailOtherCategories) then return end
    for category, enabled in pairs(S.mailOtherCategories) do
        if #items >= 20 then break end
        if enabled == true then
            HaimiyachGAG2_AddMailFromInventory(items, category, { [category] = true }, maxEach, category == "Pets" or category == "HarvestedFruits")
        end
    end
end

function HaimiyachGAG2_BuildMailItems()
    local items = {}
    local maxEach = math.floor(tonumber(S.mailSendCount) or 1)
    if maxEach < 1 then maxEach = 1 end
    if maxEach > 20 then maxEach = 20 end

    HaimiyachGAG2_AddMailFromInventory(items, "Seeds", S.mailSeedTargets, maxEach, false)
    HaimiyachGAG2_AddMailFromInventory(items, "HarvestedFruits", S.mailFruitTargets, 1, true)
    HaimiyachGAG2_AddMailGearFromInventory(items, maxEach)
    HaimiyachGAG2_AddMailFromInventory(items, "Pets", S.mailPetTargets, 1, true)
    HaimiyachGAG2_AddMailFromInventory(items, "Crates", S.mailCrateTargets, maxEach, false)
    HaimiyachGAG2_AddMailFromInventory(items, "SeedPacks", S.mailSeedPackTargets, maxEach, false)
    HaimiyachGAG2_AddMailFromInventory(items, "Props", S.mailPropTargets, maxEach, false)

    return items
end

function HaimiyachGAG2_SendSelectedMailNow(showNotify)
    local targetName = HaimiyachGAG2_TrimText(S.mailTargetUsername)
    local userId, userErr = HaimiyachGAG2_ResolveMailUserId(targetName)
    if not userId then
        if showNotify ~= false then notify("Mailbox", tostring(userErr or "Invalid username"), 3) end
        return false
    end

    local items = HaimiyachGAG2_BuildMailItems()
    if #items == 0 then
        if showNotify ~= false then notify("Mailbox", "No selected gift item found.", 3) end
        return false
    end

    local send = action("Mailbox.SendBatch")
    if not (send and send.Fire) then
        if showNotify ~= false then notify("Mailbox", "SendBatch remote not found.", 4) end
        return false
    end

    local note = tostring(S.mailNote or "")
    if #note > 100 then note = string.sub(note, 1, 100) end
    local ok, success, message = pcall(function()
        return send:Fire(userId, items, note)
    end)
    if ok and success then
        if showNotify ~= false then
            local mailText = "Mail sent to @" .. tostring(targetName) .. " (" .. tostring(#items) .. " item)"
            notify("Mailbox", mailText, 4)
            pcall(function()
                local nc = require(LocalPlayer.PlayerScripts.Controllers.NotificationController)
                if nc and nc.CreateNotification then nc:CreateNotification(mailText) end
            end)
        end
        return true
    end
    if showNotify ~= false then notify("Mailbox", tostring(message or success or "Could not send gift"), 4) end
    return false
end

function HaimiyachGAG2_AddUniqueName(list, seen, name)
    name = HaimiyachGAG2_TrimText(name)
    if name ~= "" and HaimiyachGAG2_IsValidMailCatalogName(name) and not seen[name] then
        seen[name] = true
        list[#list + 1] = name
    end
end

function HaimiyachGAG2_IsValidMailCatalogName(name)
    name = HaimiyachGAG2_TrimText(name)
    if name == "" then return false end
    local n = string.lower(name):gsub("%s+", "")
    if n == "data" or n == "getdata" or n == "getrandomseed" or n == "getrandomitem" or n == "getallcrates" or n == "getallseedpacks" or n == "getallpacks" or n == "resolve" or n == "isgiftable" or n == "categories" then
        return false
    end
    if string.sub(n, 1, 3) == "get" and #n <= 18 then
        return false
    end
    return true
end

function HaimiyachGAG2_InventoryOptionNames(category, fallback)
    local list, seen = {}, {}
    for nm in pairs(invNames(category)) do
        HaimiyachGAG2_AddUniqueName(list, seen, nm)
    end
    if type(fallback) == "table" then
        for _, nm in ipairs(fallback) do
            HaimiyachGAG2_AddUniqueName(list, seen, nm)
        end
    end
    table.sort(list)
    return list
end

function HaimiyachGAG2_ReadDataList(moduleName, nameFields, dataKeys)
    local list, seen = {}, {}
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("SharedModules")
        local m = shared and shared:FindFirstChild(moduleName)
        if not m then return end
        local data = require(m)
        local function addEntry(e, fallbackKey)
            if type(e) == "table" then
                for _, field in ipairs(nameFields) do
                    local v = e[field]
                    if type(v) == "string" then
                        HaimiyachGAG2_AddUniqueName(list, seen, v)
                        return
                    end
                end
            end
            if type(fallbackKey) == "string" then
                HaimiyachGAG2_AddUniqueName(list, seen, fallbackKey)
            end
        end
        local function scanTable(t)
            if type(t) ~= "table" then return end
            for k, e in pairs(t) do
                if type(k) == "string" and HaimiyachGAG2_IsValidMailCatalogName(k) and type(e) == "table" then
                    addEntry(e, k)
                elseif type(k) == "number" then
                    addEntry(e, nil)
                end
            end
        end
        for _, fnName in ipairs({ "GetAll", "GetAllCrates", "GetAllSeedPacks", "GetAllPacks" }) do
            if type(data) == "table" and type(data[fnName]) == "function" then
                local ok, arr = pcall(data[fnName])
                if ok then scanTable(arr) end
            end
        end
        if type(data) == "table" then
            if type(dataKeys) == "table" then
                for _, dk in ipairs(dataKeys) do
                    scanTable(data[dk])
                end
            end
            scanTable(data)
        end
    end)
    table.sort(list)
    return list
end

function HaimiyachGAG2_MailGearOptionNames()
    local list, seen = {}, {}
    for _, category in ipairs(HaimiyachGAG2_MailGearCategories) do
        for nm in pairs(invNames(category)) do
            HaimiyachGAG2_AddUniqueName(list, seen, nm)
        end
    end
    if type(GEAR_NAMES) == "table" then
        for _, nm in ipairs(GEAR_NAMES) do
            HaimiyachGAG2_AddUniqueName(list, seen, nm)
        end
    end
    table.sort(list)
    return list
end

function HaimiyachGAG2_CrateNames()
    local list, seen = {}, {}
    local crates = HaimiyachGAG2_ReadDataList("CrateData", { "Name", "CrateName", "ItemName" }, { "Data" })
    for _, nm in ipairs(crates) do HaimiyachGAG2_AddUniqueName(list, seen, nm) end
    for nm in pairs(invNames("Crates")) do HaimiyachGAG2_AddUniqueName(list, seen, nm) end
    if #list == 0 then HaimiyachGAG2_AddUniqueName(list, seen, "Arch Crate") end
    table.sort(list)
    return list
end

function HaimiyachGAG2_SeedPackNames()
    local list, seen = {}, {}
    local packs = HaimiyachGAG2_ReadDataList("SeedPackData", { "PackName", "Name", "SeedPackName", "ItemName" }, { "Data", "Packs" })
    for _, nm in ipairs(packs) do HaimiyachGAG2_AddUniqueName(list, seen, nm) end
    for nm in pairs(invNames("SeedPacks")) do HaimiyachGAG2_AddUniqueName(list, seen, nm) end
    table.sort(list)
    return list
end

function HaimiyachGAG2_PropNames()
    local list, seen = {}, {}
    local props = HaimiyachGAG2_ReadDataList("PropData", { "PropName", "Name", "ItemName" }, { "Data", "Props" })
    for _, nm in ipairs(props) do HaimiyachGAG2_AddUniqueName(list, seen, nm) end
    for nm in pairs(invNames("Props")) do HaimiyachGAG2_AddUniqueName(list, seen, nm) end
    table.sort(list)
    return list
end



function Stats.CleanPurchaseName(name)
    name = tostring(name or "UNKNOWN")
    name = name:gsub("%c", " ")
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "UNKNOWN" end
    if #name > 48 then name = string.sub(name, 1, 45) .. "..." end
    return name
end

function Stats.IsSprinklerGearName(name)
    name = string.lower(tostring(name or ""))
    return string.find(name, "sprinkler", 1, true) ~= nil
end

function Stats.AddPurchaseCounter(counter, name, amount)
    if type(counter) ~= "table" then return end
    name = Stats.CleanPurchaseName(name)
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then amount = 1 end
    counter[name] = (tonumber(counter[name]) or 0) + amount
end

function Stats.TrackPurchase(kind, name, amount)
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then amount = 1 end
    name = Stats.CleanPurchaseName(name)
    Stats.bought = (tonumber(Stats.bought) or 0) + amount

    if kind == "Seed" then
        Stats.seedBought = (tonumber(Stats.seedBought) or 0) + amount
        Stats.lastSeedBuy = name
        Stats.AddPurchaseCounter(Stats.purchaseSeeds, name, amount)
    elseif kind == "Gear" then
        Stats.gearBought = (tonumber(Stats.gearBought) or 0) + amount
        Stats.lastGearBuy = name
        Stats.AddPurchaseCounter(Stats.purchaseGear, name, amount)
        if Stats.IsSprinklerGearName(name) then
            Stats.sprinklerBought = (tonumber(Stats.sprinklerBought) or 0) + amount
            Stats.lastSprinklerBuy = name
            Stats.AddPurchaseCounter(Stats.purchaseSprinklers, name, amount)
        end
    elseif kind == "Crate" then
        Stats.crateBought = (tonumber(Stats.crateBought) or 0) + amount
        Stats.lastCrateBuy = name
        Stats.AddPurchaseCounter(Stats.purchaseCrates, name, amount)
    end
    if Stats.SetLastAction then
        Stats.SetLastAction("BUY", tostring(kind or "Item") .. " " .. tostring(name) .. " x" .. tostring(amount))
    end
end


-- // ============================================================ \ --
-- //                    CONFIG / AUTO EXECUTE                     \ --
-- // ============================================================ \ --
local CONFIG_DIR = "HaimiyachHub"
local CONFIG_FILE = CONFIG_DIR .. "/GAG2H_Config.json"
local CONFIG_KEYS = {
    "autoFarm", "autoBuy", "autoBuyAllSeeds", "buySeeds", "buyInterval", "buyPerTick", "restockPredictionMode", "restockRarityFilter", "restockWatchedSeeds", "restockNotifyWatched", "restockAutoBuyWatched", "restockAutoHopTarget",
    "autoPlant", "plantSpacing", "plantSeed", "plantSeeds", "autoHarvest", "harvestAll", "harvestFruitTargets", "harvestKeepMutations", "harvestMaxKg", "harvestKgMode", "harvestKgValue", "harvestInterval", "harvestDelay",
    "autoSell", "sellInterval", "sellKeepMutations", "sellKeepKgMode", "sellKeepKgValue", "autoExpand", "autoPot", "autoDaily", "dailyDelay",
    "autoClaimSeedEvent", "claimUseFly", "seedEventDelay", "autoCollectSeed", "autoCollectFruit", "autoCollectPet", "collectSeedDelay", "collectSeedTeleport", "collectSeedReturn", "autoShovelPlants", "autoShovelFruits", "shovelPlantTargets", "shovelFruitTargets", "shovelKeepMutations", "shovelMaxKg", "shovelKgMode", "shovelKgValue", "shovelNameFilter", "shovelDelay",
    "autoFavoriteFruits", "favoriteFruitTargets", "favoriteMutations", "favoriteFruitFilter", "favoriteMinKg", "favoriteMaxKg", "favoriteKgMode", "favoriteKgValue", "favoriteMutationFilter", "unfavoriteNotMatching", "favoriteDelay",
    "autoSprinkler", "sprinklerInterval", "sprinklerTargetMode", "sprinklerTargets", "autoWater", "waterInterval", "autoTrowelPlants", "trowelPlantTargets", "trowelPositionMode", "trowelDelay", "autoSkill", "skillStats",
    "autoEquipPets", "autoPetSlot", "bestPetMode", "autoBuyPets", "buyWorldPets", "wildPetRarities", "wildPetOnlyUnowned", "petTeleport", "petBuyInterval",
    "sellPets", "autoSellPets", "autoEgg", "autoCrate", "autoPack", "autoBuyCrates", "buyCrates", "crateBuyDelay", "openInterval",
    "autoGear", "autoBuyAllGear", "gearBuy", "gearInterval", "autoSteal", "stealTeleport", "stealReturnBase", "stealDelay",
    "autoMail", "autoAcceptGift", "autoSendMail", "mailTargetUsername", "mailNote", "mailSeedTargets", "mailFruitTargets", "mailGearTargets", "mailPetTargets", "mailCrateTargets", "mailSeedPackTargets", "mailSprinklerTargets", "mailWateringCanTargets", "mailMushroomTargets", "mailGnomeTargets", "mailRaccoonTargets", "mailTrowelTargets", "mailPropTargets", "mailEmptyPotTargets", "mailOtherCategories", "mailSendCount", "mailSendDelay", "autoHop", "hopInterval", "hopConditions", "autoReconnect", "reconnectDelay", "protectNoClip", "protectAntiFling", "protectAntiRagdoll", "protectAntiKnockback", "protectAntiSit", "protectAntiVoid", "protectVelocityLimit", "protectVoidY", "codeText", "autoCodes", "antiAfk", "disableCutscene",
    "fpsBoost", "fpsBoostMode", "highGraphics", "blankScreen", "webhookEnabled", "webhookUrl", "webhookInterval", "webhookDisconnect",
    "espGardenFruit", "espGardenGrowing", "espGardenPlant", "espGardenValue", "espBackpackFruit", "espBackpackValue", "espBackpackTotal", "espWildPet", "espWildPetDetails", "notifyRareWeather", "rareWeatherTargets", "autoExecute", "autoExecuteUrl", "uiScale", "uiKeybindName"
}
local CONFIG_KEYSET = {}
for _, k in ipairs(CONFIG_KEYS) do CONFIG_KEYSET[k] = true end

-- Auto-register every top-level setting from S into config.
-- This prevents new features from being forgotten in CONFIG_KEYS.
for k, _ in pairs(S) do
    if k ~= "killed" and not CONFIG_KEYSET[k] then
        CONFIG_KEYS[#CONFIG_KEYS + 1] = k
        CONFIG_KEYSET[k] = true
    end
end

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
local AUTO_MAIN_FILE = CONFIG_DIR .. "/HAIMIYACH_Main.lua"
local AUTO_EXEC_DEFAULT_URL = "" -- optional: isi raw loader/script url di sini kalau mau default permanen

local function luaStringLiteral(v)
    local text = tostring(v or "")
    local ok, encoded = pcall(function() return HttpService:JSONEncode(text) end)
    if ok and type(encoded) == "string" then return encoded end
    return string.format("%q", text)
end

local function getAutoExecuteUrl()
    local url = tostring(S.autoExecuteUrl or "")
    if url == "" and getgenv and type(getgenv().HaimiyachGAG2AutoExecUrl) == "string" then
        url = tostring(getgenv().HaimiyachGAG2AutoExecUrl or "")
    end
    if url == "" then url = AUTO_EXEC_DEFAULT_URL end
    return url
end

local function buildAutoExecuteLoader()
    local url = getAutoExecuteUrl()
    return ([=[
repeat task.wait() until game:IsLoaded()
task.wait(3)

getgenv().HaimiyachGAG2AutoExec = true

local url = %s
local mainFile = %s

local function runSource(src)
    if type(src) ~= "string" or #src < 50 then
        warn("HAIMIYACH HUB auto execute: empty source")
        return
    end
    local fn, err = loadstring(src)
    if not fn then
        warn("HAIMIYACH HUB auto execute compile failed: " .. tostring(err))
        return
    end
    return fn()
end

local ok, err = pcall(function()
    if url ~= "" then
        return runSource(game:HttpGet(url, true))
    end

    if isfile and readfile and isfile(mainFile) then
        return runSource(readfile(mainFile))
    end

    warn("HAIMIYACH HUB auto execute: set AUTO EXECUTE URL or save main file to " .. tostring(mainFile))
end)

if not ok then
    warn("HAIMIYACH HUB auto execute failed: " .. tostring(err))
end
]=]):format(luaStringLiteral(url), luaStringLiteral(AUTO_MAIN_FILE))
end

local function writeAutoExecuteLoader()
    if not fsSupported() then return false, "file system unsupported" end
    ensureConfigDir()
    local loader = buildAutoExecuteLoader()
    local ok, err = pcall(function() writefile(AUTO_EXEC_FILE, loader) end)
    if not ok then return false, tostring(err) end
    return true
end

local function queueAutoExecute(force)
    -- Auto execute after hop now queues a small loader only.
    -- GAG2H_AutoExecute.lua will NOT contain the full source code.
    if not force and not S.autoExecute then return false, "disabled" end

    local q = teleportQueueFunction()
    if not q then return false, "queue unsupported" end

    saveConfig(true)

    -- Save tiny loader for executor fallback/manual autoexec folder.
    -- If filesystem fails but URL is filled, queue_on_teleport can still run direct loader code.
    local url = getAutoExecuteUrl()
    local wrote, werr = false, nil
    if fsSupported() then
        wrote, werr = writeAutoExecuteLoader()
    end

    if url == "" and not wrote then
        return false, tostring(werr or "AUTO EXECUTE URL empty and loader file cannot be written")
    end

    local code = buildAutoExecuteLoader()
    local ok, err = pcall(function() q(code) end)
    if not ok then return false, tostring(err) end
    return true
end

-- Auto-load saved config before loops and UI are created.
loadConfig(true)
-- Apply live settings carried from a previous execute, then persist them.
pcall(function()
    if getgenv and type(getgenv().HaimiyachGAG2PendingConfig) == "table" then
        applyConfigTable(getgenv().HaimiyachGAG2PendingConfig)
        getgenv().HaimiyachGAG2PendingConfig = nil
        saveConfig(true)
    end
end)
-- Backward compatibility: some older configs stored server-hop delay as raw minutes.
-- Internally this script uses seconds, so 2 must become 120 seconds / 2 minutes.
if type(S.hopInterval) == "number" and S.hopInterval > 0 and S.hopInterval < 60 then
    S.hopInterval = S.hopInterval * 60
end
if S.fpsBoostMode ~= "LIGHT" and S.fpsBoostMode ~= "BALANCED" and S.fpsBoostMode ~= "ULTRA" then S.fpsBoostMode = "BALANCED" end
if S.fpsBoost and S.highGraphics then S.highGraphics = false end
-- Migrate old single-seed setting into multi-select without adding extra heavy locals.
if type(S.plantSeeds) ~= "table" then S.plantSeeds = {} end
do
    local any = false
    for _ in pairs(S.plantSeeds) do any = true break end
    if not any then
        if type(S.plantSeed) == "string" and S.plantSeed ~= "" and S.plantSeed ~= "Best owned" and S.plantSeed ~= "BEST OWNED" and S.plantSeed ~= "Selected" then
            S.plantSeeds[S.plantSeed] = true
        else
            S.plantSeeds["BEST OWNED"] = true
        end
    end
    if S.plantSeeds["Best owned"] then S.plantSeeds["Best owned"] = nil; S.plantSeeds["BEST OWNED"] = true end
end
if type(S.buyWorldPets) ~= "table" then S.buyWorldPets = {} end

if S.sprinklerTargetMode ~= "AVATAR POSITION" and S.sprinklerTargetMode ~= "MAPPING" then
    S.sprinklerTargetMode = "GARDEN CENTER"
end
if type(S.sprinklerTargets) ~= "table" then S.sprinklerTargets = {} end
if type(S.trowelPlantTargets) ~= "table" then S.trowelPlantTargets = {} end
if S.trowelPositionMode ~= "AVATAR POSITION" then S.trowelPositionMode = "MAPPING" end
if type(S.trowelDelay) ~= "number" then S.trowelDelay = 3 end

-- Safe sprinkler helpers. These are defined after config/state load and before loops run.
-- They follow the game's controller: placement must hit a PlantArea inside the player's plot,
-- then Place.PlaceSprinkler(pos, sprinklerName, tool, plotId) is fired.
HaimiyachGAG2_SprinklerMapCursor = tonumber(HaimiyachGAG2_SprinklerMapCursor) or 0
function HaimiyachGAG2_LoadSprinklerNameSet()
    local set = {}
    local ok, data = pcall(function()
        return require(ReplicatedStorage.SharedModules.SprinklerData)
    end)
    if ok and type(data) == "table" then
        for _, info in pairs(data) do
            if type(info) == "table" then
                local n = info.SprinklerName or info.Name
                if type(n) == "string" and n ~= "" then set[n] = true end
            end
        end
    end
    return set
end
HaimiyachGAG2_SprinklerNames = HaimiyachGAG2_SprinklerNames or HaimiyachGAG2_LoadSprinklerNameSet()

function HaimiyachGAG2_SprinklerOptions()
    local seen, out = {}, {}
    local names = HaimiyachGAG2_SprinklerNames
    if type(names) == "table" then
        for n in pairs(names) do
            if not seen[n] then seen[n] = true; out[#out + 1] = n end
        end
    end
    for _, tool in ipairs(toolsByAttr("Sprinkler")) do
        local n = tool:GetAttribute("Sprinkler") or tool.Name
        if type(n) == "string" and n ~= "" and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    table.sort(out)
    return out
end

function HaimiyachGAG2_SelectedSprinklerTools()
    local out = {}
    if type(S.sprinklerTargets) == "table" and HaimiyachGAG2_HasSelection(S.sprinklerTargets) then
        for name, enabled in pairs(S.sprinklerTargets) do
            if enabled == true then
                for _, tool in ipairs(toolsByAttr("Sprinkler", name)) do
                    out[#out + 1] = tool
                end
            end
        end
    else
        out = toolsByAttr("Sprinkler")
    end
    table.sort(out, function(a, b)
        return tostring(a:GetAttribute("Sprinkler") or a.Name) < tostring(b:GetAttribute("Sprinkler") or b.Name)
    end)
    return out
end

function HaimiyachGAG2_ExistingSprinklerPositions()
    local out, plot = {}, myPlot()
    if not plot then return out end
    local names = HaimiyachGAG2_SprinklerNames or {}
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("Model") then
            local isSprinkler = names[obj.Name] == true or string.find(string.lower(obj.Name), "sprinkler", 1, true) ~= nil
            if isSprinkler then
                local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if pp then out[#out + 1] = pp.Position end
            end
        elseif obj:IsA("BasePart") and string.find(string.lower(obj.Name), "sprinkler", 1, true) ~= nil then
            out[#out + 1] = obj.Position
        end
    end
    return out
end

function HaimiyachGAG2_PointTooClose(pos, placed, dist)
    dist = tonumber(dist) or 1
    for _, p in ipairs(placed or {}) do
        if (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < dist then
            return true
        end
    end
    return false
end

function HaimiyachGAG2_PlantAreaCenter()
    local areas = myPlantAreas()
    if #areas == 0 then return nil end
    local sum = Vector3.new(0, 0, 0)
    for _, area in ipairs(areas) do
        local top = (area.CFrame * CFrame.new(0, area.Size.Y / 2, 0)).Position
        sum = sum + top
    end
    return sum / #areas
end

function HaimiyachGAG2_AvatarPos()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

function HaimiyachGAG2_NearestSprinklerPoint(target, placed, minDist)
    if not target then return nil end
    local pts = plantGrid(4)
    local best, bestDist
    for _, pos in ipairs(pts) do
        if not HaimiyachGAG2_PointTooClose(pos, placed, minDist or 1.2) then
            local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
            if not bestDist or d < bestDist then
                best, bestDist = pos, d
            end
        end
    end
    return best
end

function HaimiyachGAG2_MappingSprinklerPoint(placed)
    local pts = plantGrid(8)
    if #pts == 0 then pts = plantGrid(4) end
    if #pts == 0 then return nil end

    local candidates = {}
    for _, pos in ipairs(pts) do
        if not HaimiyachGAG2_PointTooClose(pos, placed, 8) then
            candidates[#candidates + 1] = pos
        end
    end
    if #candidates == 0 then
        for _, pos in ipairs(pts) do
            if not HaimiyachGAG2_PointTooClose(pos, placed, 1.2) then
                candidates[#candidates + 1] = pos
            end
        end
    end
    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b)
        if math.abs(a.X - b.X) < 0.01 then return a.Z < b.Z end
        return a.X < b.X
    end)
    HaimiyachGAG2_SprinklerMapCursor = (HaimiyachGAG2_SprinklerMapCursor % #candidates) + 1
    return candidates[HaimiyachGAG2_SprinklerMapCursor]
end

function HaimiyachGAG2_ChooseSprinklerPosition(placed)
    local mode = tostring(S.sprinklerTargetMode or "GARDEN CENTER")
    if mode == "AVATAR POSITION" then
        return HaimiyachGAG2_NearestSprinklerPoint(HaimiyachGAG2_AvatarPos(), placed, 1.2)
            or HaimiyachGAG2_NearestSprinklerPoint(HaimiyachGAG2_PlantAreaCenter(), placed, 1.2)
    elseif mode == "MAPPING" then
        return HaimiyachGAG2_MappingSprinklerPoint(placed)
    else
        return HaimiyachGAG2_NearestSprinklerPoint(HaimiyachGAG2_PlantAreaCenter(), placed, 1.2)
    end
end

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


-- // ============================================================ \ --
-- //                      PROTECT AVATAR                         \ --
-- Client-side avatar protection only. It does not damage or delete other players.
HaimiyachGAG2_NoClipCache = HaimiyachGAG2_NoClipCache or {}
HaimiyachGAG2_NoClipActive = false
HaimiyachGAG2_ProtectSafeCFrame = nil
HaimiyachGAG2_ProtectRagdollLocked = false
HaimiyachGAG2_ProtectSitLocked = false

function HaimiyachGAG2_ProtectCharacter()
    return LocalPlayer and LocalPlayer.Character or nil
end

function HaimiyachGAG2_ProtectHumanoid()
    local c = HaimiyachGAG2_ProtectCharacter()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

function HaimiyachGAG2_ProtectRoot()
    local c = HaimiyachGAG2_ProtectCharacter()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")) or nil
end

function HaimiyachGAG2_SetStateSafe(hum, stateName, enabled)
    if not hum then return end
    local ok, state = pcall(function() return Enum.HumanoidStateType[stateName] end)
    if ok and state then
        pcall(function() hum:SetStateEnabled(state, enabled == true) end)
    end
end

function HaimiyachGAG2_SetRagdollProtection(hum, enabled)
    if not hum then return end
    HaimiyachGAG2_SetStateSafe(hum, "Ragdoll", not enabled)
    HaimiyachGAG2_SetStateSafe(hum, "FallingDown", not enabled)
    HaimiyachGAG2_SetStateSafe(hum, "Physics", not enabled)
    HaimiyachGAG2_SetStateSafe(hum, "PlatformStanding", not enabled)
end

function HaimiyachGAG2_SetSitProtection(hum, enabled)
    if not hum then return end
    HaimiyachGAG2_SetStateSafe(hum, "Seated", not enabled)
end

function HaimiyachGAG2_RestoreNoClip()
    for part, old in pairs(HaimiyachGAG2_NoClipCache) do
        if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
            pcall(function()
                if type(old) == "table" then
                    part.CanCollide = old.collide == true
                    part.CanTouch = old.touch == true
                else
                    part.CanCollide = old == true
                end
            end)
        end
    end
    table.clear(HaimiyachGAG2_NoClipCache)
    HaimiyachGAG2_NoClipActive = false
end

function HaimiyachGAG2_ApplyNoClip()
    local c = HaimiyachGAG2_ProtectCharacter()
    if not c then return end
    HaimiyachGAG2_NoClipActive = true
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            if HaimiyachGAG2_NoClipCache[part] == nil then
                HaimiyachGAG2_NoClipCache[part] = { collide = part.CanCollide, touch = part.CanTouch }
            end
            pcall(function()
                part.CanCollide = false
                part.CanTouch = false
            end)
        end
    end
end

function HaimiyachGAG2_ResetOwnVelocity(limitOnly)
    local c = HaimiyachGAG2_ProtectCharacter()
    if not c then return 0 end
    local limit = tonumber(S.protectVelocityLimit) or 85
    if limit < 25 then limit = 25 end
    local changed = 0
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            local lv = part.AssemblyLinearVelocity
            local av = part.AssemblyAngularVelocity
            local hit = (not limitOnly) or (lv.Magnitude > limit) or (av.Magnitude > limit)
            if hit then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    part.RotVelocity = Vector3.new(0, 0, 0)
                end)
                changed = changed + 1
            end
        end
    end
    return changed
end

task.spawn(function()
    while not S.killed do
        local anyProtect = S.protectNoClip or S.protectAntiFling or S.protectAntiRagdoll or S.protectAntiKnockback or S.protectAntiSit or S.protectAntiVoid
        if anyProtect then
            local c = HaimiyachGAG2_ProtectCharacter()
            local hum = HaimiyachGAG2_ProtectHumanoid()
            local root = HaimiyachGAG2_ProtectRoot()

            if S.protectNoClip then
                HaimiyachGAG2_ApplyNoClip()
            elseif HaimiyachGAG2_NoClipActive then
                HaimiyachGAG2_RestoreNoClip()
            end

            if hum then
                if S.protectAntiRagdoll or S.protectAntiFling or S.protectAntiKnockback then
                    if not HaimiyachGAG2_ProtectRagdollLocked then
                        HaimiyachGAG2_ProtectRagdollLocked = true
                    end
                    HaimiyachGAG2_SetRagdollProtection(hum, true)
                    if hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
                    local stateOk, state = pcall(function() return hum:GetState() end)
                    if stateOk and (state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.PlatformStanding) then
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                    end
                elseif HaimiyachGAG2_ProtectRagdollLocked then
                    HaimiyachGAG2_ProtectRagdollLocked = false
                    HaimiyachGAG2_SetRagdollProtection(hum, false)
                end

                if S.protectAntiSit then
                    if not HaimiyachGAG2_ProtectSitLocked then
                        HaimiyachGAG2_ProtectSitLocked = true
                    end
                    HaimiyachGAG2_SetSitProtection(hum, true)
                    if hum.Sit then pcall(function() hum.Sit = false end) end
                elseif HaimiyachGAG2_ProtectSitLocked then
                    HaimiyachGAG2_ProtectSitLocked = false
                    HaimiyachGAG2_SetSitProtection(hum, false)
                end
            end

            if root and hum and hum.Health > 0 then
                local voidY = tonumber(S.protectVoidY) or -25
                if root.Position.Y > voidY + 8 and root.AssemblyLinearVelocity.Magnitude < 120 then
                    HaimiyachGAG2_ProtectSafeCFrame = root.CFrame
                end

                if S.protectAntiFling or S.protectAntiKnockback then
                    HaimiyachGAG2_ResetOwnVelocity(true)
                end

                if S.protectAntiVoid and root.Position.Y < voidY then
                    local cf = HaimiyachGAG2_ProtectSafeCFrame
                    if cf then
                        pcall(function()
                            root.CFrame = cf + Vector3.new(0, 5, 0)
                            HaimiyachGAG2_ResetOwnVelocity(false)
                        end)
                    else
                        pcall(function()
                            root.CFrame = CFrame.new(0, 15, 0)
                            HaimiyachGAG2_ResetOwnVelocity(false)
                        end)
                    end
                end
            end
            task.wait(0.08)
        else
            if HaimiyachGAG2_NoClipActive then HaimiyachGAG2_RestoreNoClip() end
            local hum = HaimiyachGAG2_ProtectHumanoid()
            if hum then
                if HaimiyachGAG2_ProtectRagdollLocked then
                    HaimiyachGAG2_ProtectRagdollLocked = false
                    HaimiyachGAG2_SetRagdollProtection(hum, false)
                end
                if HaimiyachGAG2_ProtectSitLocked then
                    HaimiyachGAG2_ProtectSitLocked = false
                    HaimiyachGAG2_SetSitProtection(hum, false)
                end
            end
            task.wait(0.4)
        end
    end
end)

-- // ============================================================ \ --
-- //                       GARDEN FRUIT ESP LITE                  \ --
-- // ============================================================ \ --
local GardenESP = {
    running = false,
    labels = {},
    totalValueGui = nil,
    singleHarvest = {},
    singleHarvestKnown = {
        ["Bamboo"] = true,
        ["Tulip"] = true,
        ["Carrot"] = true,
        ["Mushroom"] = true,
    },
    modulesReady = false,
    visualizer = nil,
    gardenSync = nil,
    valueCalc = nil,
    overtimeCalc = nil,
    mutationData = nil,
    sellValueData = nil,
    sellFlags = nil,
    stockMultipliers = {},
    stockConn = nil,
    stockLastRequest = 0,
    stockNextRefreshUnix = 0,
    stockServerOffset = 0,
    stockCycleSeconds = 600,
    fruitBaseWeight = {},
    plantBaseWeight = {},
    base = {
        ["Carrot"] = 5, ["Strawberry"] = 3, ["Tomato"] = 9, ["Blueberry"] = 5, ["Apple"] = 12,
        ["Pinetree"] = 100, ["Bamboo"] = 800, ["Pumpkin"] = 350, ["Cactus"] = 40, ["Pineapple"] = 30,
        ["Green Bean"] = 10, ["Banana"] = 35, ["Grape"] = 45, ["Mushroom"] = 13000, ["Coconut"] = 60,
        ["Mango"] = 90, ["Thorn Rose"] = 140, ["Dragon Fruit"] = 150, ["Acorn"] = 200, ["Cherry"] = 350,
        ["Sunflower"] = 1750, ["Venus Fly Trap"] = 3000, ["Lotus"] = 6500, ["Pomegranate"] = 900,
        ["Beanstalk"] = 2000, ["Poison Apple"] = 900, ["Moon Bloom"] = 9000, ["Dragon's Breath"] = 3400,
        ["Poison Ivy"] = 1700, ["Glow Mushroom"] = 700, ["Ghost Pepper"] = 2500, ["Horned Melon"] = 200,
        ["Corn"] = 34, ["Baby Cactus"] = 70, ["Tulip"] = 60, ["Romanesco"] = 1500, ["Venom Spitter"] = 4000,
        ["Hypnobloom"] = 2000,
    },
}

function GardenESP.applyFruitStockSnapshot(snapshot)
    if typeof(snapshot) ~= "table" then return false end

    local entries = snapshot.entries
    if typeof(entries) ~= "table" then return false end

    local parsed = {}
    for fruitName, data in pairs(entries) do
        if typeof(fruitName) == "string" and typeof(data) == "table" then
            local multiplier = tonumber(data.multiplier) or 1
            local tier = typeof(data.tier) == "string" and data.tier or "normal"

            if multiplier > 0 then
                parsed[fruitName] = {
                    multiplier = multiplier,
                    tier = tier,
                }
            end
        end
    end

    GardenESP.stockMultipliers = parsed

    if typeof(snapshot.nextRefreshUnix) == "number" then
        GardenESP.stockNextRefreshUnix = snapshot.nextRefreshUnix
    end

    if typeof(snapshot.cycleSeconds) == "number" and snapshot.cycleSeconds > 0 then
        GardenESP.stockCycleSeconds = snapshot.cycleSeconds
    end

    if typeof(snapshot.server_now_unix) == "number" then
        GardenESP.stockServerOffset = snapshot.server_now_unix - os.time()
    end

    return true
end

function GardenESP.requestFruitStockSnapshot(force)
    local now = os.clock()
    if not force and GardenESP.stockLastRequest and now - GardenESP.stockLastRequest < 15 then
        return false
    end

    GardenESP.stockLastRequest = now

    local ok, snapshot = pcall(function()
        local fs = Net and Net.FruitStock
        local req = fs and fs.Request
        if req and req.Fire then
            return req:Fire()
        end
        return nil
    end)

    if ok then
        return GardenESP.applyFruitStockSnapshot(snapshot)
    end

    return false
end

function GardenESP.ensureFruitStock()
    local hasStock = next(GardenESP.stockMultipliers) ~= nil
    local serverNow = os.time() + (tonumber(GardenESP.stockServerOffset) or 0)
    local nextRefresh = tonumber(GardenESP.stockNextRefreshUnix) or 0

    if (not hasStock) or (nextRefresh > 0 and serverNow >= nextRefresh + 1) then
        GardenESP.requestFruitStockSnapshot(false)
    end
end

function GardenESP.stockMultiplier(name)
    GardenESP.ensureFruitStock()

    local data = GardenESP.stockMultipliers[tostring(name or "")]
    if type(data) == "table" then
        local multiplier = tonumber(data.multiplier) or 1
        local tier = tostring(data.tier or "normal")
        if multiplier > 0 then
            return multiplier, tier
        end
    end

    return 1, "normal"
end

function GardenESP.applySellFlags(name, value)
    value = tonumber(value)
    if not value then return nil end

    local flags = GardenESP.sellFlags
    if flags and type(flags.Apply) == "function" then
        local ok, applied = pcall(flags.Apply, name, value)
        if ok and tonumber(applied) then
            value = tonumber(applied)
        end
    end

    if value < 1 then value = 1 end
    return value
end

function GardenESP.applyStockMultiplier(name, value)
    value = tonumber(value)
    if not value then return nil end

    local multiplier = GardenESP.stockMultiplier(name)
    multiplier = tonumber(multiplier) or 1

    if multiplier > 0 and multiplier ~= 1 then
        value = math.floor(value * multiplier)
    end

    if value < 1 then value = 1 end
    return value
end

function GardenESP.applyFinalSellValue(name, value)
    value = GardenESP.applySellFlags(name, value)
    if not value then return nil end
    return GardenESP.applyStockMultiplier(name, value)
end

function GardenESP.mobile()
    local cam = Workspace.CurrentCamera
    local size = cam and cam.ViewportSize
    return size and size.X <= 900
end

function GardenESP.money(n)
    n = math.floor(tonumber(n) or 0)
    local a = math.abs(n)
    if a >= 1000000000 then return string.format("%.1fB", n / 1000000000) end
    if a >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if a >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(n)
end

function GardenESP.hasTag(inst, tag)
    local ok, res = pcall(function()
        return CollectionService:HasTag(inst, tag)
    end)
    return ok and res == true
end

function GardenESP.initModules()
    -- Do not lock this forever. Some executors run before PlayerScripts/Controllers finish loading,
    -- so this function is allowed to retry until the required modules are found.
    pcall(function()
        local sm = ReplicatedStorage:FindFirstChild("SharedModules")
        local seedData = sm and sm:FindFirstChild("SeedData")
        if seedData and next(GardenESP.singleHarvest) == nil then
            local ok, data = pcall(require, seedData)
            if ok and type(data) == "table" then
                for _, info in pairs(data) do
                    if type(info) == "table" and type(info.SeedName) == "string" then
                        GardenESP.singleHarvest[info.SeedName] = info.IsSingleHarvest == true
                    end
                end
            end
        end

        if not GardenESP.sellValueData then
            local svd = sm and sm:FindFirstChild("SellValueData")
            if svd then
                local ok, data = pcall(require, svd)
                if ok and type(data) == "table" then
                    GardenESP.sellValueData = data
                    GardenESP.base = data
                end
            end
        end

        if not GardenESP.sellFlags then
            local flagsFolder = sm and sm:FindFirstChild("Flags")
            local sf = flagsFolder and flagsFolder:FindFirstChild("SellFlags")
            if sf then
                local ok, mod = pcall(require, sf)
                if ok and type(mod) == "table" then
                    GardenESP.sellFlags = mod
                end
            end
        end

        if not GardenESP.stockConn then
            local fs = Net and Net.FruitStock
            local snapshotEvent = fs and fs.Snapshot
            if snapshotEvent and snapshotEvent.OnClientEvent then
                GardenESP.stockConn = snapshotEvent.OnClientEvent:Connect(function(snapshot)
                    pcall(GardenESP.applyFruitStockSnapshot, snapshot)
                end)
            end
        end

        GardenESP.ensureFruitStock()

        if not GardenESP.valueCalc then
            local fvc = sm and sm:FindFirstChild("FruitValueCalc")
            if fvc then
                local ok, calc = pcall(require, fvc)
                if ok and type(calc) == "function" then GardenESP.valueCalc = calc end
            end
        end

        if not GardenESP.mutationData then
            local md = sm and sm:FindFirstChild("MutationData")
            if md then
                local ok, mod = pcall(require, md)
                if ok and type(mod) == "table" then GardenESP.mutationData = mod end
            end
        end

        if not GardenESP.overtimeCalc then
            local ot = sm and sm:FindFirstChild("CalculateOvertimeGrowth")
            if ot then
                local ok, calc = pcall(require, ot)
                if ok and type(calc) == "function" then GardenESP.overtimeCalc = calc end
            end
        end
    end)

    pcall(function()
        local pgm = ReplicatedStorage:FindFirstChild("PlantGenerationModules")
        local fruits = pgm and pgm:FindFirstChild("Fruits")
        local plants = pgm and pgm:FindFirstChild("Plants")

        if fruits then
            for _, modScript in ipairs(fruits:GetChildren()) do
                if modScript:IsA("ModuleScript") and GardenESP.fruitBaseWeight[modScript.Name] == nil then
                    local ok, mod = pcall(require, modScript)
                    local grow = ok and type(mod) == "table" and mod.GrowData
                    local bw = type(grow) == "table" and tonumber(grow.BaseWeight) or nil
                    if bw and bw > 0 then GardenESP.fruitBaseWeight[modScript.Name] = bw end
                end
            end
        end

        if plants then
            for _, modScript in ipairs(plants:GetChildren()) do
                if modScript:IsA("ModuleScript") and GardenESP.plantBaseWeight[modScript.Name] == nil then
                    local ok, mod = pcall(require, modScript)
                    local grow = ok and type(mod) == "table" and mod.GrowData
                    local bw = type(grow) == "table" and tonumber(grow.BaseWeight) or nil
                    if bw and bw > 0 then GardenESP.plantBaseWeight[modScript.Name] = bw end
                end
            end
        end
    end)

    pcall(function()
        local ps = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
        local controllers = ps and ps:FindFirstChild("Controllers")

        if not GardenESP.visualizer then
            local visualizer = controllers and controllers:FindFirstChild("PlantVisualizerController")
            if visualizer then
                local ok, mod = pcall(require, visualizer)
                if ok and type(mod) == "table" then
                    GardenESP.visualizer = mod
                    -- Safe: Init only loads generation modules into the controller table/upvalues.
                    -- Do not call Start because the game already manages connections.
                    pcall(function()
                        if type(mod.Init) == "function" then mod:Init() end
                    end)
                end
            end
        end

        if not GardenESP.gardenSync then
            local sync = controllers and controllers:FindFirstChild("GardenSyncController")
            if sync then
                local ok, mod = pcall(require, sync)
                if ok and type(mod) == "table" then GardenESP.gardenSync = mod end
            end
        end
    end)

    GardenESP.modulesReady = (GardenESP.valueCalc ~= nil) or (GardenESP.visualizer ~= nil) or next(GardenESP.fruitBaseWeight) ~= nil or next(GardenESP.plantBaseWeight) ~= nil
end

function GardenESP.name(model)
    if not model then return nil end
    local attrs = { "CorePartName", "SeedName", "FruitName", "Fruit", "PlantName", "CropName" }
    for _, attr in ipairs(attrs) do
        local v = model:GetAttribute(attr)
        if type(v) == "string" and v ~= "" then return v end
    end
    return nil
end

function GardenESP.sizeName(sizeMulti)
    sizeMulti = tonumber(sizeMulti) or 1
    if sizeMulti >= 4 then return "GIANT" end
    if sizeMulti >= 2.5 then return "BIG" end
    return "NORMAL"
end

function GardenESP.value(name, sizeMulti)
    local base = GardenESP.base[tostring(name or "")]
    if not base then return nil end
    sizeMulti = tonumber(sizeMulti) or 1
    local exponent = 2.65
    if name == "Mushroom" then exponent = 1.9 end
    if name == "Bamboo" then exponent = 1.75 end
    local value = math.floor(base * (sizeMulti ^ exponent))
    if value < 1 then value = base end
    return value
end

function GardenESP.part(model)
    if not model then return nil end
    local hp = model:FindFirstChild("HarvestPart", true)
    if hp and hp:IsA("BasePart") then return hp end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

function GardenESP.isSingleHarvestPlant(model)
    if not (model and model:IsA("Model")) then return false end
    if model:GetAttribute("FruitId") ~= nil then return false end
    if model:GetAttribute("PlantId") == nil then return false end
    if not (model.Parent and model.Parent.Name == "Plants") then return false end

    local name = GardenESP.name(model)
    if not name then return false end
    GardenESP.initModules()

    local known = GardenESP.singleHarvest[name]
    if known == true then return true end
    if known == false then return false end

    -- Safe fallback only for known one-time harvest plants.
    -- Do not guess by empty Fruits folder, because multi-harvest plants can be empty
    -- before fruits spawn and that caused unwanted plant ESP.
    return GardenESP.singleHarvestKnown[name] == true
end

function GardenESP.isFruit(model)
    if not (model and model:IsA("Model")) then return false end
    if not GardenESP.name(model) then return false end

    if model:GetAttribute("FruitId") ~= nil then return true end
    if model.Parent and model.Parent.Name == "Fruits" then return true end
    if model:GetAttribute("FruitName") ~= nil then return true end
    if model:GetAttribute("Fruit") ~= nil then return true end

    return false
end

function GardenESP.isGardenTarget(model)
    if not (model and model:IsA("Model")) then return false end
    if GardenESP.isFruit(model) then return true end
    if GardenESP.isSingleHarvestPlant(model) then return true end
    return false
end

function GardenESP.ready(model)
    if not model then return false end
    local age = tonumber(model:GetAttribute("Age"))
    local maxAge = tonumber(model:GetAttribute("MaxAge"))
    if age and maxAge and maxAge > 0 then
        return age >= maxAge
    end
    if GardenESP.hasTag(model, "Harvestable") then return true end
    if model:FindFirstChild("HarvestPart", true) ~= nil then return true end
    return false
end

function GardenESP.status(model)
    local age = tonumber(model and model:GetAttribute("Age"))
    local maxAge = tonumber(model and model:GetAttribute("MaxAge"))
    if GardenESP.ready(model) then return "READY" end
    if age and maxAge and maxAge > 0 then
        local pct = math.floor(math.clamp((age / maxAge) * 100, 0, 99))
        return tostring(pct) .. "%"
    end
    return "GROWING"
end

function GardenESP.clear()
    for model, gui in pairs(GardenESP.labels) do
        pcall(function()
            if gui then gui:Destroy() end
        end)
        GardenESP.labels[model] = nil
    end
    pcall(function()
        if GardenESP.totalValueGui then
            GardenESP.totalValueGui:Destroy()
            GardenESP.totalValueGui = nil
        end
    end)
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "HaimiyachGardenFruitESP" or obj.Name == "HaimiyachGardenTotalValueESP" then obj:Destroy() end
        end
    end)
end

function GardenESP.maxDistance()
    return GardenESP.mobile() and 170 or 230
end

function GardenESP.maxLabels()
    return GardenESP.mobile() and 45 or 70
end

function GardenESP.anchorPosition()
    local cam = Workspace.CurrentCamera
    if cam then return cam.CFrame.Position end
    local char = LocalPlayer and LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then return root.Position end
    return nil
end

function GardenESP.getSyncedPlant(model)
    if not model then return nil end
    GardenESP.initModules()
    local sync = GardenESP.gardenSync
    if not (sync and sync.GetPlant) then return nil end

    local userId = tonumber(model:GetAttribute("UserId"))
    local plantId = model:GetAttribute("PlantId")
    if not (userId and type(plantId) == "string") then return nil end

    local ok, plant = pcall(function()
        return sync:GetPlant(userId, plantId)
    end)
    if ok and type(plant) == "table" then return plant end
    return nil
end


function GardenESP.getSyncedFruit(model)
    if not model then return nil, GardenESP.getSyncedPlant(model) end
    local plant = GardenESP.getSyncedPlant(model)
    if not plant then return nil, nil end
    local fruitId = model:GetAttribute("FruitId")
    if type(fruitId) == "string" and type(plant.Fruits) == "table" and type(plant.Fruits[fruitId]) == "table" then
        return plant.Fruits[fruitId], plant
    end
    return nil, plant
end

function GardenESP.getMutation(model)
    if not model then return nil end
    local m = model:GetAttribute("Mutation")
    if type(m) == "string" and m ~= "" then return m end
    local fruitData, plantData = GardenESP.getSyncedFruit(model)
    if type(fruitData) == "table" and type(fruitData.Mutation) == "string" and fruitData.Mutation ~= "" then return fruitData.Mutation end
    if GardenESP.isSingleHarvestPlant(model) and type(plantData) == "table" then
        local pm = plantData.Mutation
        if type(pm) == "string" and pm ~= "" then return pm end
    end
    return nil
end

function GardenESP.getDecay(model)
    if not model then return nil end
    local d = tonumber(model:GetAttribute("DecayAlpha"))
    if d then return d end
    local fruitData, plantData = GardenESP.getSyncedFruit(model)
    if type(fruitData) == "table" then
        d = tonumber(fruitData.DecayAlpha)
        if d then return d end
    end
    if GardenESP.isSingleHarvestPlant(model) and type(plantData) == "table" then
        d = tonumber(plantData.DecayAlpha)
        if d then return d end
    end
    return nil
end

function GardenESP.moduleBaseWeight(model, name)
    GardenESP.initModules()
    name = tostring(name or GardenESP.name(model) or "")
    if name == "" then return nil end
    if GardenESP.isSingleHarvestPlant(model) then
        return GardenESP.plantBaseWeight[name] or GardenESP.fruitBaseWeight[name]
    end
    return GardenESP.fruitBaseWeight[name] or GardenESP.plantBaseWeight[name]
end

function GardenESP.finalSize(model, sizeMulti)
    sizeMulti = tonumber(sizeMulti) or 1
    local plant = GardenESP.getSyncedPlant(model)
    if not plant then return sizeMulti end

    local fruitId = model and model:GetAttribute("FruitId")
    if type(fruitId) == "string" and type(plant.Fruits) == "table" then
        local fruitData = plant.Fruits[fruitId]
        local overtime = type(fruitData) == "table" and tonumber(fruitData.OvertimeGrowth) or nil
        if overtime and overtime > 0 then
            return sizeMulti * math.max(overtime, 1)
        end
        return sizeMulti
    end

    if GardenESP.isSingleHarvestPlant(model) then
        local plantSize = tonumber(plant.SizeMultiplier) or sizeMulti
        local overtime = tonumber(plant.OvertimeGrowth)
        if (not overtime or overtime <= 0) and type(plant.FinishedGrowingAt) == "number" and GardenESP.overtimeCalc then
            local ok, calculated = pcall(GardenESP.overtimeCalc, os.time() - plant.FinishedGrowingAt)
            if ok and type(calculated) == "number" then overtime = calculated end
        end
        return plantSize * math.max(tonumber(overtime) or 1, 1)
    end

    return sizeMulti
end

function GardenESP.calculateWeight(model, sizeMulti)
    if not model then return nil end
    GardenESP.initModules()

    local visualizer = GardenESP.visualizer
    if visualizer then
        if GardenESP.isSingleHarvestPlant(model) and type(visualizer.CalculatePlantWeight) == "function" then
            local ok, weight = pcall(function()
                return visualizer:CalculatePlantWeight(model)
            end)
            if ok and tonumber(weight) and tonumber(weight) > 0 then return tonumber(weight) end
        elseif type(visualizer.CalculateFruitWeight) == "function" then
            local ok, weight = pcall(function()
                return visualizer:CalculateFruitWeight(model)
            end)
            if ok and tonumber(weight) and tonumber(weight) > 0 then return tonumber(weight) end
        end
    end

    local w = model:GetAttribute("Weight") or model:GetAttribute("KG") or model:GetAttribute("Kg") or model:GetAttribute("Mass")
    w = tonumber(w)
    if w and w > 0 then return w end

    -- Fallback matching the game's controller formula:
    -- Weight = GrowData.BaseWeight * SizeMultiplier * OvertimeGrowth
    local name = GardenESP.name(model)
    local baseWeight = GardenESP.moduleBaseWeight(model, name)
    if baseWeight and baseWeight > 0 then
        local finalSize = GardenESP.finalSize(model, sizeMulti)
        if finalSize and finalSize > 0 then
            return baseWeight * finalSize
        end
    end
    return nil
end

function GardenESP.weightText(model, sizeMulti)
    local w = GardenESP.calculateWeight(model, sizeMulti)
    if w and w > 0 then
        return string.format("%.2fkg", w)
    end
    sizeMulti = GardenESP.finalSize(model, sizeMulti)
    return "x" .. string.format("%.2f", sizeMulti)
end

function GardenESP.valueFor(model, name, sizeMulti)
    GardenESP.initModules()
    local finalSize = GardenESP.finalSize(model, sizeMulti)
    local mutation = GardenESP.getMutation(model)
    local decay = GardenESP.getDecay(model)

    if GardenESP.valueCalc then
        local ok, value = pcall(GardenESP.valueCalc, name, finalSize, mutation, LocalPlayer, decay)
        if ok and tonumber(value) then
            return GardenESP.applyFinalSellValue(name, tonumber(value))
        end
    end

    local value = GardenESP.value(name, finalSize)
    if value and mutation and GardenESP.mutationData and type(GardenESP.mutationData.ReturnPriceMultiplier) == "function" then
        local ok, mult = pcall(GardenESP.mutationData.ReturnPriceMultiplier, mutation)
        if ok and tonumber(mult) and tonumber(mult) > 1 then
            if GardenESP.singleHarvest[name] == true then
                mult = 1 + (tonumber(mult) - 1) * 0.15
            end
            value = math.floor(value * tonumber(mult))
        end
    end
    if value and decay and decay > 0 then
        value = math.floor(value * (1 - math.clamp(decay, 0, 1) * 0.8))
    end

    return GardenESP.applyFinalSellValue(name, value)
end

function GardenESP.make(parent)
    local mobile = GardenESP.mobile()
    local gui = Instance.new("BillboardGui")
    gui.Name = "HaimiyachGardenFruitESP"
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = GardenESP.maxDistance()
    gui.StudsOffset = Vector3.new(0, 1.05, 0)
    gui.Size = UDim2.fromOffset(mobile and 150 or 175, mobile and 18 or 20)
    gui.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Text = ""
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(255, 225, 70)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.38
    label.Font = Enum.Font.GothamBold
    label.TextSize = mobile and 8 or 9
    label.TextWrapped = false
    label.TextScaled = false
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextXAlignment = Enum.TextXAlignment.Center
    pcall(function() label.TextTruncate = Enum.TextTruncate.AtEnd end)
    label.Parent = gui

    return gui
end

function GardenESP.makeTotalValueGui(parent)
    local mobile = GardenESP.mobile()
    local gui = Instance.new("BillboardGui")
    gui.Name = "HaimiyachGardenTotalValueESP"
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = GardenESP.maxDistance() + 80
    gui.StudsOffset = Vector3.new(0, mobile and 2.8 or 3.3, 0)
    gui.Size = UDim2.fromOffset(mobile and 235 or 280, mobile and 24 or 28)
    gui.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Text = "Total Value Fruits Garden: 0 S"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(90, 255, 120)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBlack
    label.TextSize = mobile and 10 or 12
    label.TextWrapped = false
    label.TextScaled = false
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextXAlignment = Enum.TextXAlignment.Center
    pcall(function() label.TextTruncate = Enum.TextTruncate.AtEnd end)
    label.Parent = gui

    return gui
end

function GardenESP.updateTotalValueGui(totalValue, totalCount, anchorPart)
    if not S.espGardenValue then
        if GardenESP.totalValueGui then
            pcall(function() GardenESP.totalValueGui:Destroy() end)
            GardenESP.totalValueGui = nil
        end
        return
    end

    totalValue = tonumber(totalValue) or 0
    totalCount = tonumber(totalCount) or 0

    if totalCount <= 0 or not (anchorPart and anchorPart.Parent) then
        if GardenESP.totalValueGui then
            pcall(function() GardenESP.totalValueGui:Destroy() end)
            GardenESP.totalValueGui = nil
        end
        return
    end

    local gui = GardenESP.totalValueGui
    if not (gui and gui.Parent) then
        gui = GardenESP.makeTotalValueGui(anchorPart)
        GardenESP.totalValueGui = gui
    elseif gui.Parent ~= anchorPart then
        gui.Parent = anchorPart
    end

    gui.MaxDistance = GardenESP.maxDistance() + 80

    local label = gui:FindFirstChild("Text")
    if label then
        label.Text = "Total Value Fruits Garden: " .. GardenESP.money(totalValue) .. " S"
    end
end

function GardenESP.scan()
    local out = {}
    local seen = {}
    local function add(inst)
        if inst and inst:IsA("Model") and not seen[inst] then
            seen[inst] = true
            out[#out + 1] = inst
        end
    end

    local gardens = Workspace:FindFirstChild("Gardens")

    -- Important: only show real garden fruits.
    -- Some harvested/held fruits can keep Growable/Harvestable tags in Character,
    -- which makes the ESP value/size different from Backpack ESP.
    pcall(function()
        for _, inst in ipairs(CollectionService:GetTagged("Harvestable")) do
            if gardens and inst:IsDescendantOf(gardens) then add(inst) end
        end
        for _, inst in ipairs(CollectionService:GetTagged("Growable")) do
            if gardens and inst:IsDescendantOf(gardens) then add(inst) end
        end
    end)

    if gardens then
        for _, inst in ipairs(gardens:GetDescendants()) do
            if inst:IsA("Model") then
                if inst:GetAttribute("FruitId") ~= nil
                    or inst:GetAttribute("FruitName") ~= nil
                    or inst:GetAttribute("Fruit") ~= nil
                    or inst:GetAttribute("PlantId") ~= nil
                    or (inst.Parent and (inst.Parent.Name == "Fruits" or inst.Parent.Name == "Plants")) then
                    add(inst)
                end
            end
        end
    end
    return out
end

function GardenESP.update()
    GardenESP.initModules()
    if not S.espGardenFruit and not S.espGardenGrowing and not S.espGardenPlant and not S.espGardenValue then return end
    local alive = {}
    local anchor = GardenESP.anchorPosition()
    local maxDistance = GardenESP.maxDistance()
    local candidates = {}
    local totalValue = 0
    local totalCount = 0
    local totalAnchorPart = nil
    local gardensRoot = Workspace:FindFirstChild("Gardens")

    for _, model in ipairs(GardenESP.scan()) do
        if gardensRoot and model:IsDescendantOf(gardensRoot) then
            local isOneTimePlant = GardenESP.isSingleHarvestPlant(model)
            local isFruitTarget = (not isOneTimePlant) and GardenESP.isFruit(model)
            if isFruitTarget or isOneTimePlant then
                local hpAny = GardenESP.part(model)
                if S.espGardenValue and hpAny and hpAny.Parent then
                    local nameForValue = GardenESP.name(model) or (isOneTimePlant and "Plant" or "Fruit")
                    local smForValue = tonumber(model:GetAttribute("SizeMulti") or model:GetAttribute("SizeMultiplier") or 1) or 1
                    local value = GardenESP.valueFor(model, nameForValue, smForValue)
                    if value then
                        totalValue = totalValue + value
                        totalCount = totalCount + 1
                        if not totalAnchorPart then totalAnchorPart = hpAny end
                    end
                end

                local ready = GardenESP.ready(model)
                local shouldShow = false
                if isOneTimePlant then
                    shouldShow = S.espGardenPlant
                elseif isFruitTarget then
                    shouldShow = (ready and S.espGardenFruit) or ((not ready) and S.espGardenGrowing)
                end
                local hp = shouldShow and hpAny or nil
                if hp and hp.Parent then
                local dist = 0
                if anchor then dist = (hp.Position - anchor).Magnitude end
                if (not anchor) or dist <= maxDistance then
                    candidates[#candidates + 1] = { model = model, part = hp, distance = dist, ready = ready, isPlant = isOneTimePlant }
                end
            end
        end
        end
    end

    GardenESP.updateTotalValueGui(totalValue, totalCount, totalAnchorPart)

    table.sort(candidates, function(a, b)
        return (a.distance or 0) < (b.distance or 0)
    end)

    local shown = 0
    local limit = GardenESP.maxLabels()
    for _, item in ipairs(candidates) do
        if shown >= limit then break end
        local model = item.model
        local hp = item.part
        if model and model.Parent and hp and hp.Parent then
            shown = shown + 1
            alive[model] = true

            local gui = GardenESP.labels[model]
            if not (gui and gui.Parent) then
                gui = GardenESP.make(hp)
                GardenESP.labels[model] = gui
            elseif gui.Parent ~= hp then
                gui.Parent = hp
            end
            gui.MaxDistance = maxDistance

            local isPlantLabel = item.isPlant == true
            local name = GardenESP.name(model) or (isPlantLabel and "Plant" or "Fruit")
            local sm = tonumber(model:GetAttribute("SizeMulti") or model:GetAttribute("SizeMultiplier") or 1) or 1
            local status = GardenESP.status(model)
            local title = tostring(name)
            if status ~= "READY" then title = title .. " " .. status end
            local bottom = GardenESP.weightText(model, sm)
            if S.espGardenValue then
                local value = GardenESP.valueFor(model, name, sm)
                if value then bottom = bottom .. " | " .. GardenESP.money(value) .. " S" end
            end

            local label = gui:FindFirstChild("Text")
            if label then
                local parts = { tostring(name) }
                if status ~= "READY" then parts[#parts + 1] = tostring(status) end
                parts[#parts + 1] = tostring(bottom)
                label.Text = table.concat(parts, " | ")
            end
        end
    end

    for model, gui in pairs(GardenESP.labels) do
        if not alive[model] or not model.Parent or (not S.espGardenFruit and not S.espGardenGrowing and not S.espGardenPlant) then
            pcall(function()
                if gui then gui:Destroy() end
            end)
            GardenESP.labels[model] = nil
        end
    end
end

function GardenESP.start()
    if GardenESP.running then return end
    GardenESP.running = true
    task.spawn(function()
        while GardenESP.running and not S.killed do
            if S.espGardenFruit or S.espGardenGrowing or S.espGardenPlant or S.espGardenValue then
                pcall(GardenESP.update)
                task.wait(1.2)
            else
                pcall(GardenESP.clear)
                task.wait(0.5)
            end
        end
        pcall(GardenESP.clear)
    end)
end

function GardenESP.set(state)
    S.espGardenFruit = state and true or false
    if S.espGardenFruit then
        GardenESP.start()
        pcall(GardenESP.update)
    elseif not S.espGardenGrowing and not S.espGardenPlant then
        pcall(GardenESP.clear)
    else
        pcall(GardenESP.update)
    end
end

function GardenESP.setGrowing(state)
    S.espGardenGrowing = state and true or false
    if S.espGardenGrowing then
        GardenESP.start()
        pcall(GardenESP.update)
    elseif not S.espGardenFruit and not S.espGardenPlant then
        pcall(GardenESP.clear)
    else
        pcall(GardenESP.update)
    end
end

function GardenESP.setPlant(state)
    S.espGardenPlant = state and true or false
    if S.espGardenPlant then
        GardenESP.start()
        pcall(GardenESP.update)
    elseif S.espGardenFruit or S.espGardenGrowing then
        pcall(GardenESP.update)
    else
        pcall(GardenESP.clear)
    end
end

function GardenESP.setValue(state)
    S.espGardenValue = state and true or false
    if S.espGardenValue then
        GardenESP.start()
        pcall(GardenESP.update)
    elseif S.espGardenFruit or S.espGardenGrowing or S.espGardenPlant then
        pcall(GardenESP.update)
    else
        pcall(GardenESP.clear)
    end
end

pcall(GardenESP.clear)

-- // ============================================================ \ --
-- //                     BACKPACK FRUIT ESP LITE                 \ --
-- // ============================================================ \ --
local BackpackESP = {
    running = false,
}

function BackpackESP.mobile()
    local cam = Workspace.CurrentCamera
    local size = cam and cam.ViewportSize
    return size and size.X <= 900
end

function BackpackESP.cleanName(name)
    name = tostring(name or "")
    name = name:gsub("%s*%b[]", "")
    name = name:gsub("[\r\n]+", " ")
    name = name:gsub("[%d%.,]+%s*[kK][gG]", "")
    name = name:gsub("[%d%.,]+%s*[gG]", "")
    name = name:gsub("^x%d+%s*", "")
    name = name:gsub("%s+x%d+$", "")
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

function BackpackESP.parseKg(text)
    text = tostring(text or ""):lower():gsub(",", ".")
    local kg = text:match("([%d%.]+)%s*kg")
    if kg then return tonumber(kg) end
    local g = text:match("([%d%.]+)%s*g")
    if g then return (tonumber(g) or 0) / 1000 end
    return nil
end

function BackpackESP.kgKey(kg)
    kg = tonumber(kg)
    if not kg then return "?" end
    return string.format("%.2f", kg)
end

function BackpackESP.money(n)
    return GardenESP.money(n)
end

function BackpackESP.value(name, sizeMulti, mutation, decayAlpha)
    GardenESP.initModules()
    sizeMulti = tonumber(sizeMulti) or 1

    if GardenESP.valueCalc then
        local ok, value = pcall(GardenESP.valueCalc, name, sizeMulti, mutation, LocalPlayer, decayAlpha)
        if ok and tonumber(value) then
            return GardenESP.applyFinalSellValue(name, tonumber(value))
        end
    end

    local value = GardenESP.value(name, sizeMulti)
    if not value then return nil end
    if mutation and GardenESP.mutationData and type(GardenESP.mutationData.ReturnPriceMultiplier) == "function" then
        local ok, mult = pcall(GardenESP.mutationData.ReturnPriceMultiplier, mutation)
        if ok and tonumber(mult) and tonumber(mult) > 1 then
            if GardenESP.singleHarvest[name] == true then
                mult = 1 + (tonumber(mult) - 1) * 0.15
            end
            value = math.floor(value * tonumber(mult))
        end
    end
    decayAlpha = tonumber(decayAlpha)
    if decayAlpha and decayAlpha > 0 then
        local mult = 1 - math.clamp(decayAlpha, 0, 1) * 0.8
        value = math.floor(value * mult)
    end

    return GardenESP.applyFinalSellValue(name, value)
end

function BackpackESP.isFruitItem(item)
    if not item then return false end
    if item:GetAttribute("Fruit") ~= nil then return true end
    if item:GetAttribute("FruitName") ~= nil then return true end
    if item:GetAttribute("FruitProxy") ~= nil then return true end
    if item:GetAttribute("HarvestedFruit") ~= nil then return true end
    return false
end

function BackpackESP.itemName(item)
    if not item then return nil end
    local attrs = { "FruitName", "Fruit", "CorePartName" }
    for _, attr in ipairs(attrs) do
        local v = item:GetAttribute(attr)
        if type(v) == "string" and v ~= "" then return v end
    end
    local parsed = tostring(item.Name or ""):match("^([^%[]+)")
    parsed = BackpackESP.cleanName(parsed)
    if parsed ~= "" then return parsed end
    return nil
end

function BackpackESP.itemKg(item)
    if not item then return nil end
    local kg = tonumber(item:GetAttribute("Weight") or item:GetAttribute("KG") or item:GetAttribute("Kg") or item:GetAttribute("Mass"))
    if kg and kg > 0 then return kg end
    return BackpackESP.parseKg(item.Name)
end

function BackpackESP.itemSize(item)
    if not item then return 1 end
    return tonumber(item:GetAttribute("SizeMultiplier") or item:GetAttribute("SizeMulti") or item:GetAttribute("Scale")) or 1
end

function BackpackESP.collectItems()
    local data = { list = {}, map = {}, total = 0 }
    local function addContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if BackpackESP.isFruitItem(item) then
                local name = BackpackESP.itemName(item)
                if name and name ~= "" then
                    local kg = BackpackESP.itemKg(item)
                    local sm = BackpackESP.itemSize(item)
                    local mutation = item:GetAttribute("Mutation")
                    local decay = item:GetAttribute("DecayAlpha")
                    local value = BackpackESP.value(name, sm, mutation, decay)
                    local rec = { name = name, kg = kg, size = sm, mutation = mutation, decay = decay, value = value, item = item }
                    data.list[#data.list + 1] = rec
                    if value then data.total = data.total + value end
                    local key = tostring(name) .. "|" .. BackpackESP.kgKey(kg)
                    if not data.map[key] then data.map[key] = {} end
                    data.map[key][#data.map[key] + 1] = rec
                end
            end
        end
    end
    if LocalPlayer then
        addContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
        addContainer(LocalPlayer.Character)
    end
    return data
end

function BackpackESP.guiRoot()
    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local bg = pg and pg:FindFirstChild("BackpackGui")
    local bp = bg and bg:FindFirstChild("Backpack")
    return bp, bp and bp:FindFirstChild("Inventory"), bp and bp:FindFirstChild("Hotbar")
end

function BackpackESP.slotInfo(slot)
    if not slot or not slot:IsA("GuiObject") then return nil end
    local nameLabel = slot:FindFirstChild("ToolName")
    local weightLabel = slot:FindFirstChild("ToolCount")
    if not (nameLabel and nameLabel:IsA("TextLabel")) then return nil end
    local rawName = tostring(nameLabel.Text or "")
    local name = BackpackESP.cleanName(rawName)
    GardenESP.initModules()
    if name == "" or GardenESP.base[name] == nil then return nil end
    local kg = nil
    if weightLabel and weightLabel:IsA("TextLabel") then
        kg = BackpackESP.parseKg(weightLabel.Text)
    end
    if not kg then kg = BackpackESP.parseKg(rawName) end
    return { name = name, kg = kg }
end

function BackpackESP.slots()
    local out = {}
    local _, inv, hotbar = BackpackESP.guiRoot()
    local function addFrom(container)
        if not container then return end
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("GuiObject") and obj:FindFirstChild("ToolName") and obj:FindFirstChild("ToolCount") then
                local info = BackpackESP.slotInfo(obj)
                if info then out[#out + 1] = { slot = obj, info = info } end
            end
        end
    end
    addFrom(inv)
    addFrom(hotbar)
    return out
end

function BackpackESP.makeSlotLabel(slot)
    local label = slot:FindFirstChild("HaimiyachBackpackESP")
    if label and label:IsA("TextLabel") then return label end
    label = Instance.new("TextLabel")
    label.Name = "HaimiyachBackpackESP"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(255, 245, 170)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.05
    label.Font = Enum.Font.GothamBlack
    label.TextSize = BackpackESP.mobile() and 11 or 13
    label.TextScaled = false
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 80
    label.Size = UDim2.new(1, 0, 0, BackpackESP.mobile() and 16 or 18)
    label.Position = UDim2.new(0, 0, 0, -2)
    label.Parent = slot
    return label
end

function BackpackESP.makeTotalLabel(inv)
    if not inv then return nil end

    -- Keep the total value neat and centered on the Backpack header/search area.
    local parent = inv
    local oldInInv = inv:FindFirstChild("HaimiyachBackpackTotalESP")
    if oldInInv and oldInInv:IsA("TextLabel") then
        oldInInv.Parent = parent
        return oldInInv
    end

    local label = parent:FindFirstChild("HaimiyachBackpackTotalESP")
    if label and label:IsA("TextLabel") then return label end

    label = Instance.new("TextLabel")
    label.Name = "HaimiyachBackpackTotalESP"
    label.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    label.BackgroundTransparency = 0.28
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(255, 245, 170)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.05
    label.Font = Enum.Font.GothamBlack
    label.TextSize = BackpackESP.mobile() and 16 or 20
    label.TextScaled = false
    label.TextWrapped = false
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 120
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Size = UDim2.new(0.58, 0, 0, BackpackESP.mobile() and 28 or 32)
    label.Position = UDim2.new(0.5, 0, 0, BackpackESP.mobile() and 4 or 6)
    label.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = label

    return label
end

function BackpackESP.repositionTotalLabel()
    local _, inv = BackpackESP.guiRoot()
    if not inv then return end
    local label = inv:FindFirstChild("HaimiyachBackpackTotalESP")
    if not (label and label:IsA("TextLabel")) then return end
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Size = UDim2.new(0.58, 0, 0, BackpackESP.mobile() and 28 or 32)
    label.Position = UDim2.new(0.5, 0, 0, BackpackESP.mobile() and 4 or 6)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextSize = BackpackESP.mobile() and 16 or 20
    label.ZIndex = 120
end

function BackpackESP.clearSlotLabels()
    local bp = BackpackESP.guiRoot()
    local root = bp
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == "HaimiyachBackpackESP" then
            pcall(function() obj:Destroy() end)
        end
    end
end

function BackpackESP.clearTotalLabel()
    local _, inv = BackpackESP.guiRoot()
    if not inv then return end
    local label = inv:FindFirstChild("HaimiyachBackpackTotalESP")
    if label then pcall(function() label:Destroy() end) end
end

function BackpackESP.clear()
    pcall(BackpackESP.clearSlotLabels)
    pcall(BackpackESP.clearTotalLabel)
end

function BackpackESP.update()
    if not S.espBackpackFruit and not S.espBackpackTotal then return end
    local data = BackpackESP.collectItems()
    local _, inv = BackpackESP.guiRoot()

    if S.espBackpackTotal and inv then
        local total = BackpackESP.makeTotalLabel(inv)
        if total then
            total.Text = "Total Value: " .. BackpackESP.money(data.total) .. " S"
            pcall(BackpackESP.repositionTotalLabel)
        end
    else
        BackpackESP.clearTotalLabel()
    end

    if not S.espBackpackFruit then
        BackpackESP.clearSlotLabels()
        return
    end

    local alive = {}
    local used = {}
    local usedRec = {}
    for _, pack in ipairs(BackpackESP.slots()) do
        local slot = pack.slot
        local info = pack.info
        local key = tostring(info.name) .. "|" .. BackpackESP.kgKey(info.kg)
        local idx = (used[key] or 0) + 1
        used[key] = idx
        local rec = data.map[key] and data.map[key][idx] or nil

        if rec then usedRec[rec] = true end
        if not rec then
            local best, bestDiff = nil, math.huge
            for _, item in ipairs(data.list) do
                if item.name == info.name and not usedRec[item] then
                    local diff = 0
                    if info.kg and item.kg then diff = math.abs(item.kg - info.kg) end
                    if (not info.kg) or (not item.kg) or diff <= 0.08 then
                        if diff < bestDiff then
                            best = item
                            bestDiff = diff
                        end
                    end
                end
            end
            rec = best
            if rec then usedRec[rec] = true end
        end

        local value = rec and rec.value or BackpackESP.value(info.name, 1, nil, nil)
        local displayKg = (rec and rec.kg) or info.kg
        local kgText = displayKg and (string.format("%.2fkg", displayKg)) or "Fruit"
        local text = kgText
        if S.espBackpackValue and value then
            text = BackpackESP.money(value) .. " S"
        end
        local label = BackpackESP.makeSlotLabel(slot)
        label.TextSize = BackpackESP.mobile() and 11 or 13
        label.BackgroundTransparency = 1
        label.Text = text
        alive[label] = true
    end

    local bp = BackpackESP.guiRoot()
    if bp then
        for _, obj in ipairs(bp:GetDescendants()) do
            if obj.Name == "HaimiyachBackpackESP" and not alive[obj] then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

function BackpackESP.start()
    if BackpackESP.running then return end
    BackpackESP.running = true
    task.spawn(function()
        while BackpackESP.running and not S.killed do
            if S.espBackpackFruit or S.espBackpackTotal then
                pcall(BackpackESP.update)
                task.wait(0.8)
            else
                pcall(BackpackESP.clear)
                task.wait(0.5)
            end
        end
        pcall(BackpackESP.clear)
    end)
end

function BackpackESP.set(state)
    S.espBackpackFruit = state and true or false
    if S.espBackpackFruit then
        BackpackESP.start()
        pcall(BackpackESP.update)
    else
        pcall(BackpackESP.clearSlotLabels)
    end
end

function BackpackESP.setValue(state)
    S.espBackpackValue = state and true or false
    if S.espBackpackFruit then pcall(BackpackESP.update) end
end

function BackpackESP.setTotal(state)
    S.espBackpackTotal = state and true or false
    if S.espBackpackTotal then
        BackpackESP.start()
        pcall(BackpackESP.update)
    else
        pcall(BackpackESP.clearTotalLabel)
    end
end

pcall(BackpackESP.clear)

-- // ============================================================ \ --
-- //                     CUTSCENE DISABLER                       \ --
-- // ============================================================ \ --
local CutsceneBlocker = {
    names = {},
    blockedConnections = {},
    workspaceConn = nil,
    lastRemoteCheck = 0,
}

local function RefreshCutsceneNames()
    local names = {}
    pcall(function()
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local folder = assets and assets:FindFirstChild("Cutscenes")
        if folder then
            for _, cutscene in ipairs(folder:GetChildren()) do
                names[cutscene.Name] = true
            end
        end
    end)
    CutsceneBlocker.names = names
    return names
end

local function IsCutsceneClone(obj)
    if not obj then return false end
    local names = CutsceneBlocker.names
    if names and names[obj.Name] then return true end
    local hasRigs = false
    local hasCamera = false
    local hasCutsceneModules = false
    pcall(function()
        hasRigs = obj:FindFirstChild("Rigs") ~= nil
        hasCamera = obj:FindFirstChild("DefaultCamera") ~= nil
        hasCutsceneModules = obj:FindFirstChild("Animations") ~= nil or obj:FindFirstChild("Markers") ~= nil or obj:FindFirstChild("FoV") ~= nil
    end)
    return hasRigs and hasCamera and hasCutsceneModules
end

local function RestoreAfterCutsceneBlock()
    pcall(function() RunService:UnbindFromRenderStep("Cutscene_Track") end)
    pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
    pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
    pcall(function() game:GetService("StarterGui"):SetCore("ResetButtonCallback", true) end)
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
        local cam = Workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            cam.FieldOfView = 70
            if hum then cam.CameraSubject = hum end
        end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") or gui:IsA("BillboardGui") then
                    gui.Enabled = true
                end
            end
        end
    end)
end

local function DestroyActiveCutscenes()
    local removed = false
    RefreshCutsceneNames()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if IsCutsceneClone(obj) then
            removed = true
            pcall(function() obj:Destroy() end)
        end
    end
    return removed
end

local function GetCutsceneRemote()
    local remote = nil
    pcall(function()
        if Net and Net.PlayCutscene and Net.PlayCutscene.OnClientEvent then
            remote = Net.PlayCutscene
        end
    end)
    return remote
end

local function SetSignalConnectionEnabled(conn, enabled)
    local ok = pcall(function()
        if enabled then
            if type(conn.Enable) == "function" then
                conn:Enable()
            elseif type(conn.enable) == "function" then
                conn:enable()
            elseif conn.Enabled ~= nil then
                conn.Enabled = true
            end
        else
            if type(conn.Disable) == "function" then
                conn:Disable()
            elseif type(conn.disable) == "function" then
                conn:disable()
            elseif conn.Enabled ~= nil then
                conn.Enabled = false
            end
        end
    end)
    return ok
end

local function DisableCutsceneRemoteConnections(force)
    if type(getconnections) ~= "function" then return false end
    local now = os.clock()
    if not force and now - (CutsceneBlocker.lastRemoteCheck or 0) < 0.75 then return false end
    CutsceneBlocker.lastRemoteCheck = now
    local remote = GetCutsceneRemote()
    if not remote then return false end
    local disabledAny = false
    pcall(function()
        for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
            if not CutsceneBlocker.blockedConnections[conn] then
                CutsceneBlocker.blockedConnections[conn] = true
                if SetSignalConnectionEnabled(conn, false) then
                    disabledAny = true
                end
            else
                SetSignalConnectionEnabled(conn, false)
            end
        end
    end)
    return disabledAny
end

local function RestoreCutsceneRemoteConnections()
    for conn in pairs(CutsceneBlocker.blockedConnections) do
        SetSignalConnectionEnabled(conn, true)
        CutsceneBlocker.blockedConnections[conn] = nil
    end
end

local function StartCutsceneWatcher()
    if CutsceneBlocker.workspaceConn then return end
    CutsceneBlocker.workspaceConn = Workspace.ChildAdded:Connect(function(obj)
        if not S.disableCutscene then return end
        task.defer(function()
            RefreshCutsceneNames()
            if IsCutsceneClone(obj) then
                pcall(function() obj:Destroy() end)
                RestoreAfterCutsceneBlock()
            end
        end)
    end)
end

local function StopCutsceneWatcher()
    if CutsceneBlocker.workspaceConn then
        pcall(function() CutsceneBlocker.workspaceConn:Disconnect() end)
        CutsceneBlocker.workspaceConn = nil
    end
end

local function SetCutsceneDisabled(enabled, silent)
    S.disableCutscene = enabled and true or false
    if S.disableCutscene then
        RefreshCutsceneNames()
        StartCutsceneWatcher()
        DisableCutsceneRemoteConnections(true)
        if DestroyActiveCutscenes() then
            RestoreAfterCutsceneBlock()
        end
        if not silent then notify("Cutscene", "Cutscene disabled.", 3) end
    else
        StopCutsceneWatcher()
        RestoreCutsceneRemoteConnections()
        if not silent then notify("Cutscene", "Cutscene enabled.", 3) end
    end
end

loopOn(function() return S.disableCutscene end, 0.4, function()
    DisableCutsceneRemoteConnections(false)
    if DestroyActiveCutscenes() then
        RestoreAfterCutsceneBlock()
    end
end)

if S.disableCutscene then
    SetCutsceneDisabled(true, true)
end

local function picked(t) for _ in pairs(t) do return true end return false end
local function pickMulti(sel, into)
    for k in pairs(into) do into[k] = nil end
    if type(sel) == "table" then for k, v in pairs(sel) do
        if v == true then into[k] = true elseif type(v) == "string" then into[v] = true end
    end end
end

-- // ============================================================ \\ --
-- //               PROGRESS / WEATHER / WILD PET HELPERS          \\ --
-- // ============================================================ \\ --
HaimiyachGAG2_RarityScore = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Super = 7, Secret = 8 }
HaimiyachGAG2_RarityOptions = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Super", "Secret" }
HaimiyachGAG2_HopConditionOptions = { "NO WEATHER", "NO WILD PET RARE", "SHOP EMPTY", "AFTER SELL", "AFTER EVENT CLAIM" }
HaimiyachGAG2_WildPetDetailOptions = { "RARITY", "PRICE", "TIMER" }
HaimiyachGAG2_RestockModeOptions = { "OFF", "LOCAL HISTORY", "NEXT CANDIDATES", "HISTORY + LIVE STOCK" }
HaimiyachGAG2_RestockRarityOptions = { "ALL", "MYTHIC", "SUPER", "RARE ONLY", "SELECTED ONLY" }

function HaimiyachGAG2_SelectedCount(t)
    local n = 0
    if type(t) == "table" then for _, v in pairs(t) do if v == true then n = n + 1 end end end
    return n
end

function HaimiyachGAG2_FormatClock(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    if sec >= 3600 then return string.format("%dh %02dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60)) end
    if sec >= 60 then return string.format("%dm %02ds", math.floor(sec / 60), sec % 60) end
    return tostring(sec) .. "s"
end

function HaimiyachGAG2_WeatherNames()
    local names, seen = {}, {}
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("SharedModules")
        mod = mod and mod:FindFirstChild("WeatherData")
        local data = mod and require(mod)
        if type(data) == "table" and type(data.Data) == "table" then
            for _, row in ipairs(data.Data) do
                local n = row and row.Name
                if type(n) == "string" and n ~= "" and not seen[n] then
                    seen[n] = true
                    names[#names + 1] = n
                end
            end
        end
    end)
    for _, n in ipairs({ "Rain", "Lightning", "Rainbow", "Snowfall", "Starfall", "Aurora" }) do
        if not seen[n] then seen[n] = true; names[#names + 1] = n end
    end
    table.sort(names)
    return names
end

function HaimiyachGAG2_ActiveWeatherRows()
    local rows = {}
    local values = ReplicatedStorage:FindFirstChild("WeatherValues")
    if not values then return rows end
    local now = os.time()
    for _, name in ipairs(HaimiyachGAG2_WeatherNames()) do
        if values:GetAttribute(name .. "_Playing") == true then
            local endTime = tonumber(values:GetAttribute(name .. "_EndTime")) or 0
            rows[#rows + 1] = { name = name, left = math.max(0, endTime - now), endTime = endTime }
        end
    end
    return rows
end

function HaimiyachGAG2_ActiveWeatherText(short)
    local rows = HaimiyachGAG2_ActiveWeatherRows()
    if #rows == 0 then return "NONE" end
    local out = {}
    for _, row in ipairs(rows) do
        if short then
            out[#out + 1] = row.name
        else
            out[#out + 1] = row.name .. " " .. HaimiyachGAG2_FormatClock(row.left)
        end
    end
    return table.concat(out, " | ")
end

function HaimiyachGAG2_WeatherTimeText()
    local rows = HaimiyachGAG2_ActiveWeatherRows()
    if #rows == 0 then return "NONE" end
    local best = rows[1]
    for _, row in ipairs(rows) do if row.left > best.left then best = row end end
    return best.name .. " " .. HaimiyachGAG2_FormatClock(best.left)
end

function HaimiyachGAG2_WeatherMachineInfo()
    local info = { progress = "?", cooldown = "?", active = "?" }
    local serverValues = ReplicatedStorage:FindFirstChild("ServerValues")
    local data = serverValues and serverValues:FindFirstChild("WeatherMachineData")
    if not data then return info end

    local cd = tonumber(data:GetAttribute("CooldownUntil")) or 0
    local cdLeft = cd - os.time()
    info.cooldown = cdLeft > 0 and HaimiyachGAG2_FormatClock(cdLeft) or "READY"

    local bestProgress, activePlayers = nil, 0
    for _, child in ipairs(data:GetChildren()) do
        local fill = child:FindFirstChild("Fill_Value")
        if fill and tonumber(fill.Value) then
            bestProgress = math.max(bestProgress or 0, tonumber(fill.Value) or 0)
        end
        local active = child:FindFirstChild("Active_Players")
        if active then activePlayers = activePlayers + #active:GetChildren() end
    end
    info.progress = bestProgress and (string.format("%.1f", bestProgress) .. "%") or "?"
    info.active = tostring(activePlayers)
    return info
end

function HaimiyachGAG2_GetPetMeta(petName)
    local meta = nil
    pcall(function()
        local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
        local mod = sharedData and sharedData:FindFirstChild("PetData")
        local data = mod and require(mod)
        if type(data) == "table" then meta = data[petName] end
    end)
    if type(meta) ~= "table" then
        pcall(function()
            local mods = ReplicatedStorage:FindFirstChild("SharedModules")
            local petModules = mods and mods:FindFirstChild("PetModules")
            local data = petModules and require(petModules)
            if type(data) == "table" then meta = data[petName] end
        end)
    end
    return type(meta) == "table" and meta or {}
end

function HaimiyachGAG2_GetPetRarity(petName, fallback)
    local meta = HaimiyachGAG2_GetPetMeta(petName)
    return tostring(meta.Rarity or fallback or "Common")
end

function HaimiyachGAG2_GetWildPetRarity(w)
    if not w then return "Common" end
    return tostring(w.rarity or HaimiyachGAG2_GetPetRarity(w.name, "Common"))
end

function HaimiyachGAG2_WildPetTimerText(w)
    if not w then return "?" end
    local spawnedAt = tonumber(w.spawnedAt) or 0
    local lifetime = tonumber(w.lifetime) or 0
    if spawnedAt > 0 and lifetime > 0 then
        local left = spawnedAt + lifetime - workspace:GetServerTimeNow()
        return HaimiyachGAG2_FormatClock(left)
    end
    return "?"
end

function HaimiyachGAG2_BestWildPetText()
    local pets = wildPets()
    if #pets == 0 then return "NONE" end
    table.sort(pets, function(a, b)
        local ra = HaimiyachGAG2_RarityScore[HaimiyachGAG2_GetWildPetRarity(a)] or 0
        local rb = HaimiyachGAG2_RarityScore[HaimiyachGAG2_GetWildPetRarity(b)] or 0
        if ra == rb then return (tonumber(a.price) or 0) > (tonumber(b.price) or 0) end
        return ra > rb
    end)
    local w = pets[1]
    return tostring(w.name or "?") .. " | " .. HaimiyachGAG2_GetWildPetRarity(w) .. " | " .. fmt(w.price or 0)
end

function HaimiyachGAG2_ShopStockStatusText()
    local function countShop(shopName)
        local data = { inStock = 0, total = 0 }
        local ok, items = pcall(function() return ReplicatedStorage.StockValues[shopName].Items end)
        if ok and items then
            for _, item in ipairs(items:GetChildren()) do
                data.total = data.total + 1
                if (tonumber(item.Value) or 0) > 0 then data.inStock = data.inStock + 1 end
            end
        end
        return data
    end
    local seed = countShop("SeedShop")
    local gear = countShop("GearShop")
    if seed.total + gear.total <= 0 then return "?" end
    return string.format("SEED %d/%d | GEAR %d/%d", seed.inStock, seed.total, gear.inStock, gear.total)
end

function HaimiyachGAG2_IsShopEmpty()
    local t = HaimiyachGAG2_ShopStockStatusText()
    local a, b, c, d = string.match(t, "SEED (%d+)/(%d+) | GEAR (%d+)/(%d+)")
    if not a then return false end
    return (tonumber(a) or 0) <= 0 and (tonumber(c) or 0) <= 0
end

function HaimiyachGAG2_WildPetMatchesAuto(w)
    if not w or not w.part then return false end
    local petName = tostring(w.name or "")
    if petName == "" then return false end
    if S.wildPetOnlyUnowned ~= false and (tonumber(w.owner) or 0) ~= 0 then return false end
    if (tonumber(w.price) or 0) > 0 and getSheckles() < (tonumber(w.price) or 0) then return false end

    local hasName = type(S.buyWorldPets) == "table" and HaimiyachGAG2_SelectedCount(S.buyWorldPets) > 0
    local hasRarity = type(S.wildPetRarities) == "table" and HaimiyachGAG2_SelectedCount(S.wildPetRarities) > 0
    if hasName and S.buyWorldPets[petName] then return true end
    if hasRarity and S.wildPetRarities[HaimiyachGAG2_GetWildPetRarity(w)] then return true end
    return false
end

function HaimiyachGAG2_HasSelectedRareWildPet()
    local hasRarity = type(S.wildPetRarities) == "table" and HaimiyachGAG2_SelectedCount(S.wildPetRarities) > 0
    for _, w in ipairs(wildPets()) do
        if (S.wildPetOnlyUnowned == false or (tonumber(w.owner) or 0) == 0) then
            local rarity = HaimiyachGAG2_GetWildPetRarity(w)
            if hasRarity then
                if S.wildPetRarities[rarity] then return true end
            elseif rarity == "Super" or rarity == "Mythic" or rarity == "Legendary" or rarity == "Secret" then
                return true
            end
        end
    end
    return false
end


-- // ============================================================ \ --
-- //                    RESTOCK PREDICTION HELPERS                \ --
-- Local tracker: reads live SeedShop stock, stores last appeared time,
-- and ranks watched/rare seeds. This is a prediction helper, not a guarantee.
HaimiyachGAG2_RestockHistory = HaimiyachGAG2_RestockHistory or {}
HaimiyachGAG2_RestockLastStock = HaimiyachGAG2_RestockLastStock or {}
HaimiyachGAG2_RestockNotified = HaimiyachGAG2_RestockNotified or {}

function HaimiyachGAG2_SeedMeta(seedName)
    seedName = tostring(seedName or "")
    for _, data in ipairs(CATALOG or {}) do
        if tostring(data.name or "") == seedName then
            return data
        end
    end
    return { name = seedName, price = 0, rarity = "" }
end

function HaimiyachGAG2_SeedRarity(seedName)
    local data = HaimiyachGAG2_SeedMeta(seedName)
    local rarity = tostring(data.rarity or "")
    if rarity == "" then return "Unknown" end
    return rarity
end

function HaimiyachGAG2_SeedRarityScore(seedName)
    return HaimiyachGAG2_RarityScore[HaimiyachGAG2_SeedRarity(seedName)] or 0
end

function HaimiyachGAG2_RestockSelectedSeedCount()
    return HaimiyachGAG2_SelectedCount(S.restockWatchedSeeds)
end

function HaimiyachGAG2_RestockSeedPassFilter(seedName)
    local selectedCount = HaimiyachGAG2_RestockSelectedSeedCount()
    if selectedCount > 0 and S.restockWatchedSeeds[seedName] then return true end

    local filter = tostring(S.restockRarityFilter or "ALL")
    if filter == "SELECTED ONLY" then return false end
    if filter == "ALL" then return true end

    local rarity = HaimiyachGAG2_SeedRarity(seedName)
    local score = HaimiyachGAG2_RarityScore[rarity] or 0
    if filter == "MYTHIC" then return rarity == "Mythic" end
    if filter == "SUPER" then return rarity == "Super" or rarity == "Secret" end
    if filter == "RARE ONLY" then return score >= (HaimiyachGAG2_RarityScore.Rare or 3) end
    return true
end

function HaimiyachGAG2_RestockSeedIsTarget(seedName)
    local selectedCount = HaimiyachGAG2_RestockSelectedSeedCount()
    if selectedCount > 0 then
        return S.restockWatchedSeeds[seedName] == true
    end
    return HaimiyachGAG2_RestockSeedPassFilter(seedName)
end

function HaimiyachGAG2_RestockScan()
    local now = os.time()
    for _, data in ipairs(CATALOG or {}) do
        local name = tostring(data.name or "")
        if name ~= "" then
            local stock = stockOf("SeedShop", name)
            local current = tonumber(stock) or 0
            local previous = HaimiyachGAG2_RestockLastStock[name]
            if current > 0 and (previous == nil or previous <= 0) then
                local h = HaimiyachGAG2_RestockHistory[name] or {}
                h.name = name
                h.rarity = HaimiyachGAG2_SeedRarity(name)
                h.price = tonumber(data.price) or 0
                h.lastSeen = now
                h.count = (tonumber(h.count) or 0) + 1
                h.lastStock = current
                HaimiyachGAG2_RestockHistory[name] = h
                HaimiyachGAG2_RestockNotified[name] = nil
            end
            if current <= 0 then
                HaimiyachGAG2_RestockNotified[name] = nil
            end
            HaimiyachGAG2_RestockLastStock[name] = current
        end
    end
end

function HaimiyachGAG2_SeedRestockSecondsLeft()
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    local seedShop = stockValues and stockValues:FindFirstChild("SeedShop")
    if seedShop then
        for _, attr in ipairs({ "NextRestockTime", "NextRestock", "NextRefreshTime", "RefreshAt", "RestockAt", "EndTime" }) do
            local v = tonumber(seedShop:GetAttribute(attr))
            if v then
                if v > 100000 then return math.max(0, v - os.time()) end
                if v >= 0 and v <= 86400 then return v end
            end
        end
        for _, childName in ipairs({ "NextRestock", "NextRestockTime", "NextRefresh", "Timer" }) do
            local child = seedShop:FindFirstChild(childName)
            local v = child and tonumber(child.Value)
            if v then
                if v > 100000 then return math.max(0, v - os.time()) end
                if v >= 0 and v <= 86400 then return v end
            end
        end
    end
    return 300 - (os.time() % 300)
end

function HaimiyachGAG2_SeedRestockText()
    return HaimiyachGAG2_FormatClock(HaimiyachGAG2_SeedRestockSecondsLeft())
end

function HaimiyachGAG2_RestockAgoText(unix)
    unix = tonumber(unix) or 0
    if unix <= 0 then return "NEVER" end
    local diff = math.max(0, os.time() - unix)
    if diff >= 86400 then return tostring(math.floor(diff / 86400)) .. "d ago" end
    if diff >= 3600 then return tostring(math.floor(diff / 3600)) .. "h " .. tostring(math.floor((diff % 3600) / 60)) .. "m ago" end
    if diff >= 60 then return tostring(math.floor(diff / 60)) .. "m ago" end
    return tostring(diff) .. "s ago"
end

function HaimiyachGAG2_RestockPredictionMode()
    local mode = tostring(S.restockPredictionMode or "HISTORY + LIVE STOCK")
    if mode == "LIVE STOCK ONLY" then mode = "NEXT CANDIDATES" end
    return mode
end

function HaimiyachGAG2_RestockPredictionChance(row)
    local since = tonumber(row.since) or 0
    local rarityScore = tonumber(row.rarityScore) or 0
    if tonumber(row.lastSeen) == nil or tonumber(row.lastSeen) <= 0 then
        if rarityScore >= 6 then return "UNKNOWN HIGH" end
        return "WAITING DATA"
    end
    if since >= 43200 then return "VERY HIGH" end
    if since >= 21600 then return "HIGH" end
    if since >= 7200 then return "MEDIUM" end
    return "LOW"
end

function HaimiyachGAG2_RestockPredictionRows(limit)
    local mode = HaimiyachGAG2_RestockPredictionMode()
    if mode == "OFF" then return {} end
    HaimiyachGAG2_RestockScan()

    local rows, now = {}, os.time()

    for _, data in ipairs(CATALOG or {}) do
        local name = tostring(data.name or "")
        if name ~= "" and HaimiyachGAG2_RestockSeedPassFilter(name) then
            local stock = tonumber(stockOf("SeedShop", name)) or 0

            -- Prediction = next possible seeds, not seeds currently in stock.
            -- Current stock stays in TARGET STATUS / auto buy logic.
            if stock <= 0 then
                local hist = HaimiyachGAG2_RestockHistory[name] or {}
                local lastSeen = tonumber(hist.lastSeen) or 0

                if not (mode == "LOCAL HISTORY" and lastSeen <= 0) then
                    local since = lastSeen > 0 and (now - lastSeen) or 999999
                    local rarity = HaimiyachGAG2_SeedRarity(name)
                    local rarityScore = HaimiyachGAG2_RarityScore[rarity] or 0
                    local price = tonumber(data.price) or 0
                    local selectedBonus = (type(S.restockWatchedSeeds) == "table" and S.restockWatchedSeeds[name]) and 2500000 or 0

                    local score = selectedBonus + rarityScore * 1000000 + math.min(since, 86400) + (price / 100)

                    rows[#rows + 1] = {
                        name = name,
                        rarity = rarity,
                        rarityScore = rarityScore,
                        price = price,
                        stock = stock,
                        lastSeen = lastSeen,
                        since = since,
                        score = score,
                    }
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.score == b.score then return tostring(a.name) < tostring(b.name) end
        return a.score > b.score
    end)

    local maxRows = tonumber(limit) or 5
    while #rows > maxRows do table.remove(rows) end
    return rows
end

function HaimiyachGAG2_RestockPredictionText()
    local rows = HaimiyachGAG2_RestockPredictionRows(4)
    if #rows == 0 then return "NO NEXT CANDIDATES" end

    local out = {}
    for _, row in ipairs(rows) do
        local ago = HaimiyachGAG2_RestockAgoText(row.lastSeen)
        local chance = HaimiyachGAG2_RestockPredictionChance(row)
        out[#out + 1] = tostring(row.name) .. " | " .. tostring(row.rarity) .. " | " .. chance .. " | last " .. ago
    end
    return table.concat(out, "\n")
end

function HaimiyachGAG2_RestockTargetText()
    HaimiyachGAG2_RestockScan()

    local watched = HaimiyachGAG2_RestockSelectedSeedCount()
    local inStock, total = 0, 0

    if watched > 0 then
        for seedName, enabled in pairs(S.restockWatchedSeeds or {}) do
            if enabled == true then
                total = total + 1
                if (tonumber(stockOf("SeedShop", seedName)) or 0) > 0 then
                    inStock = inStock + 1
                end
            end
        end
        return tostring(inStock) .. "/" .. tostring(total) .. " watched currently in stock"
    end

    for _, data in ipairs(CATALOG or {}) do
        local name = tostring(data.name or "")
        if name ~= "" and HaimiyachGAG2_RestockSeedPassFilter(name) then
            total = total + 1
            if (tonumber(stockOf("SeedShop", name)) or 0) > 0 then
                inStock = inStock + 1
            end
        end
    end

    return tostring(inStock) .. "/" .. tostring(total) .. " filtered currently in stock"
end

function HaimiyachGAG2_RestockRecentText()
    HaimiyachGAG2_RestockScan()
    local rows = {}
    for name, hist in pairs(HaimiyachGAG2_RestockHistory) do
        if HaimiyachGAG2_RestockSeedPassFilter(name) then
            rows[#rows + 1] = { name = name, lastSeen = tonumber(hist.lastSeen) or 0, rarity = hist.rarity or HaimiyachGAG2_SeedRarity(name) }
        end
    end
    table.sort(rows, function(a, b) return a.lastSeen > b.lastSeen end)
    if #rows == 0 then return "NONE" end
    local out = {}
    for i = 1, math.min(3, #rows) do
        local r = rows[i]
        out[#out + 1] = tostring(r.name) .. " | " .. tostring(r.rarity) .. " | " .. HaimiyachGAG2_RestockAgoText(r.lastSeen)
    end
    return table.concat(out, "\n")
end

function HaimiyachGAG2_RestockAnyTargetInStock()
    HaimiyachGAG2_RestockScan()
    if HaimiyachGAG2_RestockSelectedSeedCount() <= 0 then return false end
    for seedName, enabled in pairs(S.restockWatchedSeeds or {}) do
        if enabled == true and (tonumber(stockOf("SeedShop", seedName)) or 0) > 0 then
            return true
        end
    end
    return false
end

function HaimiyachGAG2_RestockNotifyStep()
    if not S.restockNotifyWatched then return end
    HaimiyachGAG2_RestockScan()

    for _, data in ipairs(CATALOG or {}) do
        local name = tostring(data.name or "")
        if name ~= "" and HaimiyachGAG2_RestockSeedIsTarget(name) then
            local stock = tonumber(stockOf("SeedShop", name)) or 0
            if stock > 0 and not HaimiyachGAG2_RestockNotified[name] then
                HaimiyachGAG2_RestockNotified[name] = true
                notify("Seed Restock", tostring(name) .. " is in stock x" .. tostring(stock), 5)
            end
        end
    end
end

function HaimiyachGAG2_RestockAutoBuyStep()
    if not S.restockAutoBuyWatched then return end
    if HaimiyachGAG2_RestockSelectedSeedCount() <= 0 then return end
    HaimiyachGAG2_RestockScan()
    for seedName, enabled in pairs(S.restockWatchedSeeds or {}) do
        if enabled == true then
            local meta = HaimiyachGAG2_SeedMeta(seedName)
            local stock = tonumber(stockOf("SeedShop", seedName)) or 0
            local bought = 0
            while stock > 0 and bought < math.max(1, tonumber(S.buyPerTick) or 1) do
                if (tonumber(meta.price) or 0) > 0 and getSheckles() < (tonumber(meta.price) or 0) then break end
                local beforeMoney = getSheckles()
                local beforeCount = HaimiyachGAG2_InventorySeedCount(seedName)
                local beforeStock = tonumber(stockOf("SeedShop", seedName))
                local okBuy = fire("SeedShop.PurchaseSeed", seedName)
                if not okBuy then break end

                local confirmed = HaimiyachGAG2_SeedPurchaseConfirmed(seedName, beforeMoney, beforeCount, beforeStock, tonumber(meta.price) or 0)
                if confirmed then
                    Stats.TrackPurchase("Seed", seedName, 1)
                    bought = bought + 1
                    stock = math.max(0, stock - 1)
                else
                    if Stats.SetWarning then Stats.SetWarning("BUY SEED", "Not confirmed: " .. tostring(seedName)) end
                    break
                end
                task.wait(jitter(0.1, 0.22))
            end
        end
    end
end

function HaimiyachGAG2_ShouldHopNow()
    if type(S.hopConditions) ~= "table" or HaimiyachGAG2_SelectedCount(S.hopConditions) <= 0 then
        return true, "TIMER"
    end
    if S.hopConditions["NO WEATHER"] and #HaimiyachGAG2_ActiveWeatherRows() == 0 then
        return true, "NO WEATHER"
    end
    if S.hopConditions["NO WILD PET RARE"] and not HaimiyachGAG2_HasSelectedRareWildPet() then
        return true, "NO WILD PET RARE"
    end
    if S.hopConditions["SHOP EMPTY"] and HaimiyachGAG2_IsShopEmpty() then
        return true, "SHOP EMPTY"
    end
    if S.hopConditions["AFTER SELL"] and (tonumber(Stats.lastSellAt) or 0) > (tonumber(HaimiyachGAG2_LastHopAfterSellAt) or 0) then
        return true, "AFTER SELL"
    end
    if S.hopConditions["AFTER EVENT CLAIM"] and (tonumber(Stats.lastSeedClaimAt) or 0) > (tonumber(HaimiyachGAG2_LastHopAfterEventAt) or 0) then
        return true, "AFTER EVENT CLAIM"
    end
    if S.restockAutoHopTarget and HaimiyachGAG2_RestockSelectedSeedCount() > 0 and not HaimiyachGAG2_RestockAnyTargetInStock() then
        return true, "NO RESTOCK TARGET"
    end
    return false, "WAITING CONDITION"
end

function HaimiyachGAG2_MarkHopReason(reason)
    HaimiyachGAG2_LastHopReason = tostring(reason or "TIMER")
    if Stats.SetLastAction then Stats.SetLastAction("SERVER HOP", HaimiyachGAG2_LastHopReason) end
    if reason == "AFTER SELL" then HaimiyachGAG2_LastHopAfterSellAt = tonumber(Stats.lastSellAt) or os.clock() end
    if reason == "AFTER EVENT CLAIM" then HaimiyachGAG2_LastHopAfterEventAt = tonumber(Stats.lastSeedClaimAt) or os.clock() end
end

function HaimiyachGAG2_NextHopText()
    if not S.autoHop then return "OFF" end
    local at = tonumber(HaimiyachGAG2_NextHopAt) or 0
    if at <= 0 then return "READY" end
    local left = at - os.clock()
    return HaimiyachGAG2_FormatClock(left)
end

function HaimiyachGAG2_SessionRatesText()
    local elapsed = math.max(1, os.clock() - (Stats.startAt or os.clock()))
    local shecklesPerMin = ((tonumber(Stats.earned) or 0) / elapsed) * 60
    local harvestPerMin = ((tonumber(Stats.harvested) or 0) / elapsed) * 60
    return "SHECKLES/MIN: " .. fmt(shecklesPerMin) .. " | HARVEST/MIN: " .. fmt(harvestPerMin)
end

function HaimiyachGAG2_NotifyRareWeatherStep()
    if not S.notifyRareWeather then return end
    HaimiyachGAG2_NotifiedWeather = HaimiyachGAG2_NotifiedWeather or {}
    for _, row in ipairs(HaimiyachGAG2_ActiveWeatherRows()) do
        if type(S.rareWeatherTargets) == "table" and S.rareWeatherTargets[row.name] and not HaimiyachGAG2_NotifiedWeather[row.name] then
            HaimiyachGAG2_NotifiedWeather[row.name] = true
            notify("Rare Weather", row.name .. " active for " .. HaimiyachGAG2_FormatClock(row.left), 5)
        end
    end
    for name in pairs(HaimiyachGAG2_NotifiedWeather) do
        local still = false
        for _, row in ipairs(HaimiyachGAG2_ActiveWeatherRows()) do if row.name == name then still = true break end end
        if not still then HaimiyachGAG2_NotifiedWeather[name] = nil end
    end
end

HaimiyachGAG2_WildPetEspObjects = HaimiyachGAG2_WildPetEspObjects or {}
function HaimiyachGAG2_ClearWildPetESP()
    for part, gui in pairs(HaimiyachGAG2_WildPetEspObjects) do
        pcall(function() if gui then gui:Destroy() end end)
        HaimiyachGAG2_WildPetEspObjects[part] = nil
    end
end

function HaimiyachGAG2_UpdateWildPetESP()
    if not S.espWildPet then
        HaimiyachGAG2_ClearWildPetESP()
        return
    end
    local alive = {}
    for _, w in ipairs(wildPets()) do
        local part = w.part
        if part and part.Parent then
            alive[part] = true
            local gui = HaimiyachGAG2_WildPetEspObjects[part]
            if not gui or not gui.Parent then
                gui = Instance.new("BillboardGui")
                gui.Name = "Haimiyach_WildPetESP"
                gui.AlwaysOnTop = true
                gui.Size = UDim2.fromOffset(190, 58)
                gui.StudsOffset = Vector3.new(0, 4, 0)
                gui.Adornee = part
                gui.Parent = part
                local label = Instance.new("TextLabel")
                label.Name = "Text"
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.fromRGB(255,255,255)
                label.TextStrokeTransparency = 0.35
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.TextWrapped = true
                label.Parent = gui
                HaimiyachGAG2_WildPetEspObjects[part] = gui
            end
            local lines = { tostring(w.name or "?") }
            if type(S.espWildPetDetails) ~= "table" or S.espWildPetDetails.RARITY then lines[#lines + 1] = HaimiyachGAG2_GetWildPetRarity(w) end
            if type(S.espWildPetDetails) ~= "table" or S.espWildPetDetails.PRICE then lines[#lines + 1] = fmt(w.price or 0) .. " S" end
            if type(S.espWildPetDetails) ~= "table" or S.espWildPetDetails.TIMER then lines[#lines + 1] = HaimiyachGAG2_WildPetTimerText(w) end
            local label = gui:FindFirstChild("Text")
            if label then label.Text = table.concat(lines, " | ") end
        end
    end
    for part, gui in pairs(HaimiyachGAG2_WildPetEspObjects) do
        if not alive[part] then
            pcall(function() if gui then gui:Destroy() end end)
            HaimiyachGAG2_WildPetEspObjects[part] = nil
        end
    end
end

-- // ============================================================ \\ --
-- //                    INVENTORY FAVORITE                        \\ --
-- // ============================================================ \\ --
function HaimiyachGAG2_GetInventoryFruitTools()
    local out = {}
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("Fruit") and tool:GetAttribute("Id") then
                out[#out + 1] = tool
            end
        end
    end
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("Fruit") and tool:GetAttribute("Id") then
                out[#out + 1] = tool
            end
        end
    end
    return out
end

function HaimiyachGAG2_GetFruitToolKg(tool)
    if not tool then return nil end
    local attrs = { "Weight", "WeightKg", "KG", "Kg", "Kilogram", "Kilograms", "Mass" }
    for _, attr in ipairs(attrs) do
        local v = tool:GetAttribute(attr)
        if type(v) == "number" then return v end
        if type(v) == "string" then
            local n = string.match(v, "([%d%.]+)")
            if n then return tonumber(n) end
        end
    end
    local n = string.match(tostring(tool.Name or ""), "([%d%.]+)%s*[Kk][Gg]")
    if n then return tonumber(n) end
    return nil
end

function HaimiyachGAG2_TextListMatch(text, filter)
    filter = string.lower(tostring(filter or ""))
    if filter == "" or filter == "all" then return true end
    text = string.lower(tostring(text or ""))
    for item in string.gmatch(filter, "[^,]+") do
        item = string.gsub(item, "^%s+", "")
        item = string.gsub(item, "%s+$", "")
        if item ~= "" and string.find(text, item, 1, true) then
            return true
        end
    end
    return false
end

function HaimiyachGAG2_NameKey(text)
    return (string.gsub(string.lower(tostring(text or "")), "[^%w]", ""))
end

function HaimiyachGAG2_SelectedNameMatch(text, selected)
    if type(selected) ~= "table" or not picked(selected) then return true end
    local key = HaimiyachGAG2_NameKey(text)
    if key == "" then return false end
    for name, enabled in pairs(selected) do
        if enabled == true and HaimiyachGAG2_NameKey(name) == key then
            return true
        end
    end
    return false
end

function HaimiyachGAG2_ShouldFavoriteFruit(tool)
    local fruit = tool and tool:GetAttribute("Fruit")
    local fruitId = tool and tool:GetAttribute("Id")
    if not fruit or not fruitId then return false end

    if picked(S.favoriteFruitTargets) then
        if not HaimiyachGAG2_SelectedNameMatch(fruit, S.favoriteFruitTargets) then return false end
    elseif not HaimiyachGAG2_TextListMatch(fruit, S.favoriteFruitFilter) then
        return false
    end

    local mutation = tostring(tool:GetAttribute("Mutation") or "")
    if picked(S.favoriteMutations) then
        if not HaimiyachGAG2_SelectedNameMatch(mutation, S.favoriteMutations) then return false end
    else
        local mutFilter = tostring(S.favoriteMutationFilter or "")
        if mutFilter ~= "" and mutFilter ~= "all" then
            if not HaimiyachGAG2_TextListMatch(mutation, mutFilter) then return false end
        end
    end

    local kg = HaimiyachGAG2_GetFruitToolKg(tool)
    if HaimiyachGAG2_KgModeActive(S.favoriteKgMode, S.favoriteKgValue) then
        if not HaimiyachGAG2_KgValueOk(kg, S.favoriteKgMode, S.favoriteKgValue) then return false end
    else
        local minKg = tonumber(S.favoriteMinKg) or 0
        local maxKg = tonumber(S.favoriteMaxKg) or 0
        if minKg > 0 and (not kg or kg < minKg) then return false end
        if maxKg > 0 and (not kg or kg > maxKg) then return false end
    end
    return true
end

function HaimiyachGAG2_SetFruitFavorite(tool, enabled)
    if not tool then return false end
    local fruitId = tool:GetAttribute("Id")
    if not fruitId then return false end
    tool:SetAttribute("IsFavorite", enabled and true or nil)
    local ok = fire("Backpack.SetFruitFavorite", fruitId, enabled and true or false)
    return ok and true or false
end

function HaimiyachGAG2_AutoFavoriteStep()
    local changed = 0
    for _, tool in ipairs(HaimiyachGAG2_GetInventoryFruitTools()) do
        local shouldFav = HaimiyachGAG2_ShouldFavoriteFruit(tool)
        if shouldFav and tool:GetAttribute("IsFavorite") ~= true then
            if HaimiyachGAG2_SetFruitFavorite(tool, true) then changed = changed + 1 end
            task.wait(0.15)
        elseif (not shouldFav) and S.unfavoriteNotMatching and tool:GetAttribute("IsFavorite") == true then
            if HaimiyachGAG2_SetFruitFavorite(tool, false) then changed = changed + 1 end
            task.wait(0.15)
        end
    end
    return changed
end

function HaimiyachGAG2_ProtectSellMutations()
    local hasMutationKeep = picked(S.sellKeepMutations)
    local hasKgKeep = HaimiyachGAG2_KgModeActive(S.sellKeepKgMode, S.sellKeepKgValue)
    if not hasMutationKeep and not hasKgKeep then return 0 end
    local protected = 0
    for _, tool in ipairs(HaimiyachGAG2_GetInventoryFruitTools()) do
        local keep = false
        local mutation = tool:GetAttribute("Mutation")
        if hasMutationKeep and mutation and HaimiyachGAG2_SelectedNameMatch(mutation, S.sellKeepMutations) then
            keep = true
        end
        if hasKgKeep and HaimiyachGAG2_KgValueOk(HaimiyachGAG2_GetFruitToolKg(tool), S.sellKeepKgMode, S.sellKeepKgValue) then
            keep = true
        end
        if keep and tool:GetAttribute("IsFavorite") ~= true then
            if HaimiyachGAG2_SetFruitFavorite(tool, true) then protected = protected + 1 end
            task.wait(0.12)
        end
    end
    return protected
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
    return string.format("RAINBOW %d | GOLD %d | TOTAL %d", rainbow, gold, total)
end

local function getSeedEventClaimText()
    return string.format("RAINBOW %d | GOLD %d | TOTAL %d",
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
    return tostring(Stats.lastSeedEvent) .. " | " .. getSeedEventAgeText(age) .. " ago"
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
                if Stats.SetLastAction then Stats.SetLastAction("SEED EVENT", "Claimed " .. tostring(data.seedType) .. " Seed") end
                notify("Seed Event", "Claimed " .. data.seedType .. " Seed", 3)
                task.wait(0.5)
            end
        end
    end

    return claimed
end

-- // ============================================================ \ --
-- // ============================================================ \ --
-- //          AUTO COLLECT DROPPED ITEMS (SEED / FRUIT / PET)     \ --
-- // ============================================================ \ --
local function HaimiyachGAG2_DroppedItemFolder()
    return Workspace:FindFirstChild("DroppedItems")
end

local function HaimiyachGAG2_DropItemText(obj)
    if not obj then return "" end
    local vals = {
        obj:GetAttribute("DisplayName"),
        obj:GetAttribute("ItemName"),
        obj:GetAttribute("Name"),
        obj.Name
    }
    for _, v in ipairs(vals) do
        if type(v) == "string" and v ~= "" then
            return v
        end
    end
    return tostring(obj.Name or "")
end

local function HaimiyachGAG2_DropCategory(obj)
    if not obj then return "" end
    return string.lower(tostring(obj:GetAttribute("ItemCategory") or ""))
end

local function HaimiyachGAG2_IsDroppedSeed(obj)
    if not (obj and obj:IsA("Model")) then return false end

    local c = HaimiyachGAG2_DropCategory(obj)
    if c == "seeds" or c == "seedtool" then
        return true
    end
    if string.find(c, "seed", 1, true) and not string.find(c, "seedpack", 1, true) then
        return true
    end

    local n = string.lower(HaimiyachGAG2_DropItemText(obj))
    if string.find(n, "seed", 1, true) and not string.find(n, "seed pack", 1, true) and not string.find(n, "seedpack", 1, true) then
        return true
    end

    return false
end

local function HaimiyachGAG2_IsDroppedFruit(obj)
    if not (obj and obj:IsA("Model")) then return false end

    local c = HaimiyachGAG2_DropCategory(obj)
    if c == "harvestedfruits" or c == "fruits" or c == "fruit" then
        return true
    end
    if string.find(c, "fruit", 1, true) and not string.find(c, "magnet", 1, true) then
        return true
    end

    if obj:GetAttribute("HarvestedFruit") == true then
        return true
    end

    return false
end

local function HaimiyachGAG2_IsDroppedPet(obj)
    if not (obj and obj:IsA("Model")) then return false end

    local c = HaimiyachGAG2_DropCategory(obj)
    if c == "pets" or c == "pet" then
        return true
    end
    if string.find(c, "pet", 1, true) and not string.find(c, "teleporter", 1, true) then
        return true
    end

    local petId = obj:GetAttribute("PetId")
    if type(petId) == "string" and petId ~= "" then
        return true
    end

    return false
end

local function HaimiyachGAG2_CanCollectDroppedItem(obj)
    if not obj then return false end
    if obj:GetAttribute("OwnerRestricted") == true then
        local droppedBy = tonumber(obj:GetAttribute("DroppedBy"))
        if droppedBy and droppedBy ~= LocalPlayer.UserId then
            return false
        end
    end
    return true
end

local function HaimiyachGAG2_InstancePos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
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

local function HaimiyachGAG2_FindEnabledPrompt(obj)
    if not obj then return nil end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            return d
        end
    end
    return nil
end

local function HaimiyachGAG2_TriggerPrompt(prompt)
    if not (prompt and prompt.Enabled) then return false end
    local ok = false
    if type(fireproximityprompt) == "function" then
        ok = pcall(function() fireproximityprompt(prompt) end)
    end
    if not ok then
        ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.max(0.12, tonumber(prompt.HoldDuration) or 0.12))
            prompt:InputHoldEnd()
        end)
    end
    return ok == true
end

local function HaimiyachGAG2_WaitDroppedItemCollected(obj, folder)
    if not obj then return false end
    local deadline = os.clock() + 1.25
    while os.clock() < deadline do
        if not obj.Parent then
            return true
        end
        if folder and not obj:IsDescendantOf(folder) then
            return true
        end
        task.wait(0.05)
    end
    return false
end

local function HaimiyachGAG2_CollectDroppedItemStep(kind, force)
    kind = string.lower(tostring(kind or ""))
    local folder = HaimiyachGAG2_DroppedItemFolder()
    if not folder then return 0 end

    local root = HaimiyachGAG2_ProtectRoot and HaimiyachGAG2_ProtectRoot()
    if not root then
        local char = LocalPlayer.Character
        root = char and char:FindFirstChild("HumanoidRootPart")
    end

    local collected = 0
    local returnPos = myBasePos and myBasePos() or nil
    local fallbackCf = root and root.CFrame or nil

    for _, item in ipairs(folder:GetChildren()) do
        if S.killed then break end
        if kind == "seed" and not (force or S.autoCollectSeed) then break end
        if kind == "fruit" and not (force or S.autoCollectFruit) then break end
        if kind == "pet" and not (force or S.autoCollectPet) then break end

        local isTarget = false
        if kind == "seed" then
            isTarget = HaimiyachGAG2_IsDroppedSeed(item)
        elseif kind == "fruit" then
            isTarget = HaimiyachGAG2_IsDroppedFruit(item)
        elseif kind == "pet" then
            isTarget = HaimiyachGAG2_IsDroppedPet(item)
        end

        if item and item.Parent and isTarget and HaimiyachGAG2_CanCollectDroppedItem(item) then
            local prompt = HaimiyachGAG2_FindEnabledPrompt(item)
            local pos = HaimiyachGAG2_InstancePos(item)
            if prompt and pos then
                if root and S.collectSeedTeleport then
                    pcall(function() root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
                    task.wait(0.12)
                end

                local itemName = HaimiyachGAG2_DropItemText(item)
                local didCollect = false

                if not item.Parent or not item:IsDescendantOf(folder) then
                    didCollect = true
                else
                    local ok = HaimiyachGAG2_TriggerPrompt(prompt)
                    if ok then
                        didCollect = HaimiyachGAG2_WaitDroppedItemCollected(item, folder)
                    end
                end

                if didCollect then
                    collected = collected + 1
                    if kind == "seed" then
                        Stats.collectedSeeds = (Stats.collectedSeeds or 0) + 1
                        Stats.lastCollectedSeed = itemName
                        Stats.lastCollectSeedAt = os.clock()
                        if Stats.SetLastAction then Stats.SetLastAction("COLLECT", "Seed " .. tostring(itemName)) end
                    elseif kind == "fruit" then
                        Stats.collectedFruits = (Stats.collectedFruits or 0) + 1
                        Stats.lastCollectedFruit = itemName
                        Stats.lastCollectFruitAt = os.clock()
                        if Stats.SetLastAction then Stats.SetLastAction("COLLECT", "Fruit " .. tostring(itemName)) end
                    elseif kind == "pet" then
                        Stats.collectedPets = (Stats.collectedPets or 0) + 1
                        Stats.lastCollectedPet = itemName
                        Stats.lastCollectPetAt = os.clock()
                        if Stats.SetLastAction then Stats.SetLastAction("COLLECT", "Pet " .. tostring(itemName)) end
                    end
                end
                task.wait(0.08)
            end
        end
    end

    -- Return only after the dropped item is confirmed removed from DroppedItems.
    -- This prevents RETURN TO GARDEN from spamming when prompt fire succeeds but no seed/fruit/pet is actually collected.
    if collected > 0 and root and root.Parent and S.collectSeedTeleport and S.collectSeedReturn then
        local charNow = LocalPlayer.Character
        local rootNow = charNow and charNow:FindFirstChild("HumanoidRootPart")
        if rootNow then
            root = rootNow
        end
        local basePos = returnPos or (myBasePos and myBasePos() or nil)
        if basePos then
            pcall(function() root.CFrame = CFrame.new(basePos + Vector3.new(0, 4, 0)) end)
            Stats.lastReturnGardenStatus = "OK"
            Stats.lastReturnGardenAt = os.clock()
        elseif fallbackCf then
            pcall(function() root.CFrame = fallbackCf end)
            Stats.lastReturnGardenStatus = "FALLBACK"
            Stats.lastReturnGardenAt = os.clock()
        else
            Stats.lastReturnGardenStatus = "NO BASE"
            Stats.lastReturnGardenAt = os.clock()
            if Stats.SetWarning then Stats.SetWarning("RETURN", "Garden position not found") end
        end
        task.wait(0.15)
    end

    return collected
end

function HaimiyachGAG2_CollectDroppedSeedsStep(force)
    return HaimiyachGAG2_CollectDroppedItemStep("seed", force)
end

function HaimiyachGAG2_CollectDroppedFruitsStep(force)
    return HaimiyachGAG2_CollectDroppedItemStep("fruit", force)
end

function HaimiyachGAG2_CollectDroppedPetsStep(force)
    return HaimiyachGAG2_CollectDroppedItemStep("pet", force)
end

function HaimiyachGAG2_CollectDroppedEnabledStep()
    local total = 0
    if S.autoCollectSeed then
        total = total + HaimiyachGAG2_CollectDroppedSeedsStep(false)
    end
    if S.autoCollectFruit then
        total = total + HaimiyachGAG2_CollectDroppedFruitsStep(false)
    end
    if S.autoCollectPet then
        total = total + HaimiyachGAG2_CollectDroppedPetsStep(false)
    end
    return total
end

-- //                     CORE FARM (master loop)                 \\ --
-- // ============================================================ \\ --
local function stepBuy()
    if not due("buy", S.buyInterval) then return end
    if not (S.autoBuyAllSeeds or picked(S.buySeeds)) then return end
    for _, s in ipairs(CATALOG) do
        if not (S.autoFarm or S.autoBuy or S.autoBuyAllSeeds) then break end
        if S.autoBuyAllSeeds or S.buySeeds[s.name] then
            local stock, bought = stockOf("SeedShop", s.name), 0
            while bought < S.buyPerTick do
                if stock ~= nil and stock <= 0 then break end
                if s.price > 0 and getSheckles() < s.price then break end
                local beforeMoney = getSheckles()
                local beforeCount = HaimiyachGAG2_InventorySeedCount(s.name)
                local beforeStock = tonumber(stockOf("SeedShop", s.name))
                local okBuy = fire("SeedShop.PurchaseSeed", s.name)
                if not okBuy then break end

                local confirmed = HaimiyachGAG2_SeedPurchaseConfirmed(s.name, beforeMoney, beforeCount, beforeStock, tonumber(s.price) or 0)
                if confirmed then
                    Stats.TrackPurchase("Seed", s.name, 1)
                    bought = bought + 1
                    if stock ~= nil then stock = math.max(0, stock - 1) end
                else
                    if Stats.SetWarning then Stats.SetWarning("BUY SEED", "Not confirmed: " .. tostring(s.name)) end
                    break
                end
                task.wait(jitter(0.1, 0.22))
            end
        end
    end
end

HaimiyachGAG2_PlantSeedCursor = HaimiyachGAG2_PlantSeedCursor or 0
function HaimiyachGAG2_SeedCatalogPrice(seedName)
    for _, data in ipairs(CATALOG) do
        if data.name == seedName then return tonumber(data.price) or 0 end
    end
    return 0
end
function HaimiyachGAG2_HasSpecificPlantSeedSelected()
    if type(S.plantSeeds) ~= "table" then return false end
    for name, enabled in pairs(S.plantSeeds) do
        if enabled == true and name ~= "BEST OWNED" and name ~= "Best owned" then return true end
    end
    return type(S.plantSeed) == "string" and S.plantSeed ~= "" and S.plantSeed ~= "Best owned" and S.plantSeed ~= "BEST OWNED" and S.plantSeed ~= "Selected"
end
function HaimiyachGAG2_BuildPlantToolList()
    local out = {}
    if HaimiyachGAG2_HasSpecificPlantSeedSelected() then
        if type(S.plantSeeds) == "table" then
            for seedName, enabled in pairs(S.plantSeeds) do
                if enabled == true and seedName ~= "BEST OWNED" and seedName ~= "Best owned" then
                    for _, tool in ipairs(toolsByAttr("SeedTool", seedName)) do out[#out + 1] = tool end
                end
            end
        end
        if #out == 0 and type(S.plantSeed) == "string" and S.plantSeed ~= "" and S.plantSeed ~= "Best owned" and S.plantSeed ~= "BEST OWNED" and S.plantSeed ~= "Selected" then
            for _, tool in ipairs(toolsByAttr("SeedTool", S.plantSeed)) do out[#out + 1] = tool end
        end
    else
        local best, bestPrice
        for _, tool in ipairs(toolsByAttr("SeedTool")) do
            local nm = tool:GetAttribute("SeedTool")
            local price = HaimiyachGAG2_SeedCatalogPrice(nm)
            if not bestPrice or price > bestPrice then best, bestPrice = tool, price end
        end
        if best then out[#out + 1] = best end
    end
    table.sort(out, function(a, b)
        local an, bn = tostring(a:GetAttribute("SeedTool") or a.Name), tostring(b:GetAttribute("SeedTool") or b.Name)
        local ap, bp = HaimiyachGAG2_SeedCatalogPrice(an), HaimiyachGAG2_SeedCatalogPrice(bn)
        if ap == bp then return an < bn end
        return ap > bp
    end)
    return out
end

local function pickPlantTool()
    local list = HaimiyachGAG2_BuildPlantToolList()
    if #list == 0 then return nil end
    HaimiyachGAG2_PlantSeedCursor = (HaimiyachGAG2_PlantSeedCursor % #list) + 1
    return list[HaimiyachGAG2_PlantSeedCursor]
end

local function stepPlant()
    local grid = plantGrid(S.plantSpacing)
    if #grid == 0 then return end
    local hum = humanoid(); if not hum then return end
    local occupied = existingPlantPositions()
    for _, pos in ipairs(grid) do
        if not (S.autoFarm or S.autoPlant) then break end
        local clear = true
        for _, op in ipairs(occupied) do
            if (Vector2.new(pos.X, pos.Z) - Vector2.new(op.X, op.Z)).Magnitude < 1 then clear = false; break end
        end
        if clear then
            local tool = pickPlantTool(); if not tool then return end
            if heldToolByAttr("SeedTool") ~= tool then hum:EquipTool(tool); task.wait(0.22) end
            tool = heldToolByAttr("SeedTool"); if not tool then return end
            local seedAttr = tool:GetAttribute("SeedTool")
            if seedAttr then
                local ok = fire("Plant.PlantSeed", pos, seedAttr, tool)
                if ok then Stats.planted = Stats.planted + 1; occupied[#occupied + 1] = pos end
                task.wait(jitter(0.08, 0.16))
            end
        end
    end
end

local function maxFruitCap() return tonumber(LocalPlayer:GetAttribute("MaxFruitCapacity")) or 100 end
local function fruitCount()  return tonumber(LocalPlayer:GetAttribute("FruitCount")) or 0 end

function HaimiyachGAG2_HarvestAllowed(obj)
    if HaimiyachGAG2_SelectedMutationOk(obj, S.harvestKeepMutations) then return false end
    if HaimiyachGAG2_KgModeActive(S.harvestKgMode, S.harvestKgValue) then
        if not HaimiyachGAG2_ObjectKgOk(obj, S.harvestKgMode, S.harvestKgValue) then return false end
    else
        local maxKg = tonumber(S.harvestMaxKg) or 0
        if maxKg > 0 then
            local kg = HaimiyachGAG2_ObjectKg(obj)
            if not kg then return false end
            if kg >= maxKg then return false end
        end
    end
    -- Selected target must work by itself. If targets are selected, use them first
    -- even when AUTO HARVEST ALL is still ON from default/config.
    if HaimiyachGAG2_HasSelection(S.harvestFruitTargets) then
        return HaimiyachGAG2_SelectedNameOk(obj, S.harvestFruitTargets)
    end
    if S.harvestAll then return true end
    return false
end
local function sellAllNow()
    HaimiyachGAG2_ProtectSellMutations()
    local ok, res = fireFast("NPCS.SellAll")
    if ok and type(res) == "table" and res.Success then
        local n = tonumber(res.SoldCount) or 0
        local sellValue = tonumber(res.SellPrice) or 0
        Stats.sold = Stats.sold + n; Stats.earned = Stats.earned + sellValue
        if n > 0 or sellValue > 0 then
            Stats.lastSellValue = sellValue
            Stats.lastSellAt = os.clock()
            if Stats.SetLastAction then Stats.SetLastAction("SELL", tostring(n) .. " fruits for " .. fmt(sellValue)) end
        end
        return n
    end
    return 0
end

-- THROUGHPUT FIX: inventory caps at MaxFruitCapacity (100) and the server only accepts
-- ~20-25 collects/sec. So harvest in a tight cycle and SELL THE MOMENT the pack is full -
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
        if HaimiyachGAG2_HarvestAllowed(h.obj) then
            fireFast("Garden.CollectFruit", h.plantId, h.fruitId)
            Stats.harvested = Stats.harvested + 1
            if d > 0 then task.wait(d) end
        end
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
    if not due("daily", math.max(10, tonumber(S.dailyDelay) or 60)) then return end
    fire("NPCS.CheckDailyDeal"); task.wait(0.3); fire("NPCS.UseDailyDealAll")
end

task.spawn(function()
    while not S.killed do
        if S.autoFarm or S.autoBuy or S.autoBuyAllSeeds then pcall(stepBuy) end
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


-- // ============================================================ \ --
-- //                        AUTO SHOVEL                          \ --
-- Selected target + KG filter. Default target list is empty, so the
-- feature will not shovel everything unless user selects targets first.
S.shovelNameKey = function(text)
    text = string.lower(tostring(text or ""))
    return (string.gsub(text, "[^%w]", ""))
end

S.shovelObjectName = function(obj)
    if not obj then return "" end
    local attrs = { "Fruit", "Plant", "PlantName", "Seed", "SeedName", "Crop", "CropName", "ItemName" }
    for _, attr in ipairs(attrs) do
        local v = obj:GetAttribute(attr)
        if type(v) == "string" and v ~= "" then return v end
    end
    local n = tostring(obj.Name or "")
    local first = string.match(n, "^([^_]+)_")
    if first and first ~= "" then return first end
    return n
end

S.shovelSelectedOk = function(obj, selected)
    if type(selected) ~= "table" or not picked(selected) then return false end
    local key = S.shovelNameKey(S.shovelObjectName(obj))
    if key == "" then return false end
    for name, enabled in pairs(selected) do
        if enabled == true and S.shovelNameKey(name) == key then
            return true
        end
    end
    return false
end

S.shovelKgOf = function(obj)
    if not obj then return nil end
    local attrs = { "Weight", "WeightKg", "KG", "Kg", "Kilogram", "Kilograms", "Mass", "Size" }
    for _, attr in ipairs(attrs) do
        local v = obj:GetAttribute(attr)
        if type(v) == "number" then return v end
        if type(v) == "string" then
            local n = string.match(v, "([%d%.]+)")
            if n then return tonumber(n) end
        end
    end
    local n = string.match(tostring(obj.Name or ""), "([%d%.]+)%s*[Kk][Gg]")
    if n then return tonumber(n) end
    return nil
end

S.shovelKgOk = function(obj)
    if HaimiyachGAG2_KgModeActive(S.shovelKgMode, S.shovelKgValue) then
        return HaimiyachGAG2_KgValueOk(S.shovelKgOf(obj), S.shovelKgMode, S.shovelKgValue)
    end
    local maxKg = tonumber(S.shovelMaxKg) or 0
    if maxKg <= 0 then return true end
    local kg = S.shovelKgOf(obj)
    if not kg then return false end
    return kg < maxKg
end

S.shovelMutationOk = function(obj)
    return not HaimiyachGAG2_SelectedMutationOk(obj, S.shovelKeepMutations)
end

S.getShovelTool = function()
    local t = heldToolByAttr("Shovel")
    if t then return t end
    return equipByAttr("Shovel")
end

S.useShovel = function(plantId, fruitId)
    local tool = S.getShovelTool()
    if not tool then return false end
    local shovelName = tool:GetAttribute("Shovel")
    if not shovelName then return false end
    local ok = fire("Shovel.UseShovel", tostring(plantId or ""), tostring(fruitId or ""), shovelName, tool)
    return ok == true
end

S.getShovelFruitTargets = function()
    local out = {}
    if not picked(S.shovelFruitTargets) then return out end
    for _, pr in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(Workspace) then
            local m = promptCarrier(pr)
            local pid = m and m:GetAttribute("PlantId")
            if pid and S.shovelSelectedOk(m, S.shovelFruitTargets) and S.shovelKgOk(m) and S.shovelMutationOk(m) then
                local uid = tonumber(m:GetAttribute("UserId"))
                if uid == nil or uid == LocalPlayer.UserId then
                    out[#out + 1] = { plantId = tostring(pid), fruitId = tostring(m:GetAttribute("FruitId") or ""), obj = m }
                end
            end
        end
    end
    return out
end

S.getShovelPlantTargets = function()
    local out = {}
    if not picked(S.shovelPlantTargets) then return out end
    local plot = myPlot()
    local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return out end
    for _, m in ipairs(plants:GetChildren()) do
        if S.shovelSelectedOk(m, S.shovelPlantTargets) and S.shovelKgOk(m) and S.shovelMutationOk(m) then
            local pid = m:GetAttribute("PlantId") or m.Name
            if pid then out[#out + 1] = { plantId = tostring(pid), fruitId = "" } end
        end
    end
    return out
end

loopOn(function() return S.autoShovelFruits or S.autoShovelPlants end, function()
    return math.max(1, tonumber(S.shovelDelay) or 2)
end, function()
    if S.autoShovelFruits then
        for _, t in ipairs(S.getShovelFruitTargets()) do
            if not S.autoShovelFruits then break end
            S.useShovel(t.plantId, t.fruitId)
            task.wait(math.max(0.5, tonumber(S.shovelDelay) or 2))
        end
    end
    if S.autoShovelPlants then
        for _, t in ipairs(S.getShovelPlantTargets()) do
            if not S.autoShovelPlants then break end
            S.useShovel(t.plantId, "")
            task.wait(math.max(0.5, tonumber(S.shovelDelay) or 2))
        end
    end
end)

-- // ============================================================ \ --
-- //                         AUTO TROWEL                         \ --
-- Minimal patch from the execute-safe base. The game controller sends:
-- Trowel.MovePlant(plantModelName, targetPosition, rotationDegrees).
HaimiyachGAG2_TrowelMapCursor = tonumber(HaimiyachGAG2_TrowelMapCursor) or 0

function HaimiyachGAG2_TrowelPivot(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local ok, cf = pcall(function() return inst:GetPivot() end)
    if ok and cf then return cf.Position end
    local pp = inst:FindFirstChildWhichIsA("BasePart", true)
    return pp and pp.Position or nil
end

function HaimiyachGAG2_TrowelTooClose(pos, list, dist)
    if not pos then return true end
    dist = tonumber(dist) or 3
    for _, p in ipairs(list or {}) do
        if p and (Vector2.new(pos.X, pos.Z) - Vector2.new(p.X, p.Z)).Magnitude < dist then
            return true
        end
    end
    return false
end

function HaimiyachGAG2_TrowelSelectedPlant(plant)
    if type(S.trowelPlantTargets) ~= "table" or not picked(S.trowelPlantTargets) then return false end
    return HaimiyachGAG2_SelectedNameOk(plant, S.trowelPlantTargets)
end

function HaimiyachGAG2_TrowelTargets()
    local out = {}
    local plot = myPlot()
    local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return out end
    for _, plant in ipairs(plants:GetChildren()) do
        if plant:IsA("Model") and HaimiyachGAG2_TrowelSelectedPlant(plant) then
            local key = tostring(plant.Name or "")
            local pos = HaimiyachGAG2_TrowelPivot(plant)
            if key ~= "" and pos then
                out[#out + 1] = { model = plant, key = key, pos = pos }
            end
        end
    end
    return out
end

function HaimiyachGAG2_TrowelOccupied(targets)
    local occupied = {}
    for _, p in ipairs(existingPlantPositions()) do
        local isTarget = false
        for _, t in ipairs(targets or {}) do
            if t.pos and (Vector2.new(p.X, p.Z) - Vector2.new(t.pos.X, t.pos.Z)).Magnitude <= 2 then
                isTarget = true
                break
            end
        end
        if not isTarget then occupied[#occupied + 1] = p end
    end
    return occupied
end

function HaimiyachGAG2_TrowelCenter()
    local pts = plantGrid(math.max(6, tonumber(S.plantSpacing) or 4))
    if #pts == 0 then return nil end
    local sx, sy, sz = 0, 0, 0
    for _, p in ipairs(pts) do sx = sx + p.X; sy = sy + p.Y; sz = sz + p.Z end
    return Vector3.new(sx / #pts, sy / #pts, sz / #pts)
end

function HaimiyachGAG2_TrowelNearestPoint(target, occupied, minDist)
    local grid = plantGrid(math.max(4, tonumber(S.plantSpacing) or 4))
    if #grid == 0 then return nil end
    target = target or HaimiyachGAG2_TrowelCenter() or grid[1]
    table.sort(grid, function(a, b)
        return (Vector2.new(a.X, a.Z) - Vector2.new(target.X, target.Z)).Magnitude < (Vector2.new(b.X, b.Z) - Vector2.new(target.X, target.Z)).Magnitude
    end)
    for _, pos in ipairs(grid) do
        if not HaimiyachGAG2_TrowelTooClose(pos, occupied, minDist or 3) then
            return pos
        end
    end
    return grid[1]
end

function HaimiyachGAG2_TrowelPositions(targets)
    local positions = {}
    local occupied = HaimiyachGAG2_TrowelOccupied(targets)
    local spacing = math.max(3, tonumber(S.plantSpacing) or 4)
    if S.trowelPositionMode == "AVATAR POSITION" then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local base = hrp and hrp.Position or HaimiyachGAG2_TrowelCenter()
        local offsets = {
            Vector3.new(0,0,0), Vector3.new(spacing,0,0), Vector3.new(-spacing,0,0), Vector3.new(0,0,spacing), Vector3.new(0,0,-spacing),
            Vector3.new(spacing,0,spacing), Vector3.new(-spacing,0,spacing), Vector3.new(spacing,0,-spacing), Vector3.new(-spacing,0,-spacing),
            Vector3.new(spacing*2,0,0), Vector3.new(-spacing*2,0,0), Vector3.new(0,0,spacing*2), Vector3.new(0,0,-spacing*2)
        }
        for i = 1, #targets do
            local pos = HaimiyachGAG2_TrowelNearestPoint(base + offsets[((i - 1) % #offsets) + 1], occupied, math.max(2, spacing * 0.75))
            positions[i] = pos
            if pos then occupied[#occupied + 1] = pos end
        end
    else
        local grid = plantGrid(spacing)
        local center = HaimiyachGAG2_TrowelCenter()
        table.sort(grid, function(a, b)
            if not center then return a.X < b.X end
            return (Vector2.new(a.X, a.Z) - Vector2.new(center.X, center.Z)).Magnitude < (Vector2.new(b.X, b.Z) - Vector2.new(center.X, center.Z)).Magnitude
        end)
        for _, pos in ipairs(grid) do
            if not HaimiyachGAG2_TrowelTooClose(pos, occupied, math.max(2, spacing * 0.75)) then
                positions[#positions + 1] = pos
                occupied[#occupied + 1] = pos
                if #positions >= #targets then break end
            end
        end
    end
    return positions
end

function HaimiyachGAG2_AutoTrowelStep()
    if type(S.trowelPlantTargets) ~= "table" or not picked(S.trowelPlantTargets) then return 0 end
    local targets = HaimiyachGAG2_TrowelTargets()
    if #targets == 0 then return 0 end
    local tool = equipByAttr("Trowel")
    if not tool then return 0 end
    local positions = HaimiyachGAG2_TrowelPositions(targets)
    local moved = 0
    for i, data in ipairs(targets) do
        if not S.autoTrowelPlants then break end
        local pos = positions[i]
        if pos and (Vector2.new(pos.X, pos.Z) - Vector2.new(data.pos.X, data.pos.Z)).Magnitude > 1.5 then
            local ok = fire("Trowel.MovePlant", data.key, pos, 0)
            if ok then moved = moved + 1 end
            task.wait(math.max(0.6, tonumber(S.trowelDelay) or 3))
        end
    end
    pcall(function() local h = humanoid(); if h then h:UnequipTools() end end)
    return moved
end

loopOn(function() return S.autoTrowelPlants end, function()
    return math.max(1, tonumber(S.trowelDelay) or 3)
end, function()
    HaimiyachGAG2_AutoTrowelStep()
end)

loopOn(function() return S.autoFavoriteFruits end, function()
    return math.max(1, tonumber(S.favoriteDelay) or 3)
end, function()
    HaimiyachGAG2_AutoFavoriteStep()
end)

-- // ============================================================ \\ --
-- //                       BOOSTS (passive)                      \\ --
-- // ============================================================ \\ --
-- AUTO SPRINKLER: place owned sprinkler tools at the selected target.
loopOn(function() return S.autoSprinkler end, function() return S.sprinklerInterval end, function()
    local pid = myPlotId(); if not pid then return end
    local hum = humanoid(); if not hum then return end
    local placed = HaimiyachGAG2_ExistingSprinklerPositions()
    for _, tool in ipairs(HaimiyachGAG2_SelectedSprinklerTools()) do
        if not S.autoSprinkler then break end
        local pos = HaimiyachGAG2_ChooseSprinklerPosition(placed)
        if not pos then break end
        hum:EquipTool(tool); task.wait(0.25)
        local cur = heldToolByAttr("Sprinkler"); if not cur then break end
        local ok = fire("Place.PlaceSprinkler", pos, cur:GetAttribute("Sprinkler"), cur, pid)
        if ok then Stats.sprinklers = Stats.sprinklers + 1; placed[#placed + 1] = pos end
        task.wait(0.35)
    end
    pcall(function() local h = humanoid(); if h then h:UnequipTools() end end)
end)

-- AUTO WATER: water only plants that expose dry/need-water state; fallback uses safe growing-plant cooldown.
loopOn(function() return S.autoWater end, function() return S.waterInterval end, function()
    local targets = HaimiyachGAG2_PlantsNeedingWater()
    if #targets == 0 then return end
    local tool = equipByAttr("WateringCan"); if not tool then return end
    local name = tool:GetAttribute("WateringCan")
    for _, data in ipairs(targets) do
        if not S.autoWater then break end
        local ok = fire("WateringCan.UseWateringCan", data.pos - Vector3.new(0, 0.3, 0), name, tool)
        if ok then HaimiyachGAG2_MarkWatered(data.plant); Stats.watered = Stats.watered + 1 end
        task.wait(jitter(0.15, 0.3))
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

function HaimiyachGAG2_PetDescriptionText(petName)
    local meta = HaimiyachGAG2_GetPetMeta(petName)
    local desc = meta.Description
    if type(desc) == "function" then
        local ok, result = pcall(desc, "Huge", nil)
        if ok then desc = result end
    end
    return string.lower(tostring(desc or ""))
end

function HaimiyachGAG2_PetModeScore(petName, mode)
    local meta = HaimiyachGAG2_GetPetMeta(petName)
    local rarity = tostring(meta.Rarity or "Common")
    local score = (HaimiyachGAG2_RarityScore[rarity] or 1) * 100000
    score = score + math.min(50000, (tonumber(meta.BasePrice) or 0) / 100)
    local chance = tonumber(meta.SpawnChance)
    if chance and chance > 0 then score = score + math.min(25000, 25000 / chance) end

    mode = string.upper(tostring(mode or "VALUE"))
    local nameLow = string.lower(tostring(petName or ""))
    local desc = HaimiyachGAG2_PetDescriptionText(petName)

    if mode == "FARM" then
        if string.find(desc, "grow", 1, true) or string.find(desc, "fruit", 1, true) or string.find(desc, "seed", 1, true) or string.find(desc, "harvest", 1, true) or string.find(desc, "pick", 1, true) then
            score = score + 80000
        end
        if nameLow == "monkey" or nameLow == "robin" or nameLow == "deer" or nameLow == "unicorn" then score = score + 60000 end
    elseif mode == "STEAL" then
        if string.find(desc, "steal", 1, true) or string.find(desc, "limit", 1, true) then score = score + 100000 end
        if nameLow == "raccoon" then score = score + 150000 end
    elseif mode == "PROTECT" then
        if string.find(desc, "intruder", 1, true) or string.find(desc, "attack", 1, true) or string.find(desc, "burn", 1, true) or string.find(desc, "freeze", 1, true) or string.find(desc, "defen", 1, true) then
            score = score + 100000
        end
        if string.find(nameLow, "dragon", 1, true) or string.find(nameLow, "serpent", 1, true) or nameLow == "bear" or nameLow == "bee" then score = score + 65000 end
    end
    return score
end

function HaimiyachGAG2_BestOwnedPetNames(mode)
    local list = ownedPetNames()
    table.sort(list, function(a, b)
        local sa = HaimiyachGAG2_PetModeScore(a, mode)
        local sb = HaimiyachGAG2_PetModeScore(b, mode)
        if sa == sb then return tostring(a) < tostring(b) end
        return sa > sb
    end)
    return list
end

function HaimiyachGAG2_EquippedPetNames()
    local out = {}
    local ok, list = fire("Pets.GetEquippedPets")
    if ok and type(list) == "table" then
        for _, data in pairs(list) do
            if type(data) == "table" then
                local name = data.Name or data.PetName or data.DisplayName
                if name then out[#out + 1] = tostring(name) end
            elseif type(data) == "string" then
                out[#out + 1] = data
            end
        end
    end
    table.sort(out, function(a, b) return HaimiyachGAG2_PetModeScore(a, S.bestPetMode) > HaimiyachGAG2_PetModeScore(b, S.bestPetMode) end)
    return out
end

function HaimiyachGAG2_BestPetEquippedText()
    local list = HaimiyachGAG2_EquippedPetNames()
    if #list > 0 then return list[1] end
    local owned = HaimiyachGAG2_BestOwnedPetNames(S.bestPetMode)
    return owned[1] and ("READY: " .. tostring(owned[1])) or "NONE"
end

loopOn(function() return S.autoEquipPets end, 12, function()
    local cap = tonumber(LocalPlayer:GetAttribute("MaxEquippedPets")) or 3
    local have = equippedPetCount()
    if have >= cap then return end
    for _, nm in ipairs(HaimiyachGAG2_BestOwnedPetNames(S.bestPetMode)) do
        if not S.autoEquipPets or have >= cap then break end
        fire("Pets.RequestEquipByName", nm); have = have + 1; task.wait(0.3)
    end
end)
loopOn(function() return S.autoPetSlot end, 20, function()
    fire("Pets.RequestPurchasePetSlot")
end)
local function HaimiyachGAG2_InventoryPetCount(petName)
    petName = tostring(petName or "")
    if petName == "" then return 0 end
    local total = 0

    local okInv, names = pcall(function() return invNames("Pets") end)
    if okInv and type(names) == "table" then
        total = total + (tonumber(names[petName]) or 0)
    end

    local okTools, tools = pcall(function()
        local list = {}
        local function scan(container)
            if not container then return end
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") then
                    local nm = t:GetAttribute("PetName") or t:GetAttribute("Name") or t.Name
                    if tostring(nm or "") == petName then
                        list[#list + 1] = t
                    end
                end
            end
        end
        scan(LocalPlayer:FindFirstChild("Backpack"))
        scan(LocalPlayer.Character)
        return list
    end)
    if okTools and type(tools) == "table" then
        total = total + #tools
    end

    return total
end

local function HaimiyachGAG2_FirePrompt(prompt)
    if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then return false end
    if type(fireproximityprompt) == "function" then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then return true end
    end
    local ok2 = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(0.12, tonumber(prompt.HoldDuration) or 0.12))
        prompt:InputHoldEnd()
    end)
    return ok2 and true or false
end

local function HaimiyachGAG2_TriggerWildPetPrompt(w)
    if not w then return false end
    local prompt = nil
    if type(w) == "table" then
        prompt = w.prompt
        if not (prompt and prompt.Parent) then
            prompt = HaimiyachGAG2_FindPrompt(w.visual, "BuyPrompt") or HaimiyachGAG2_FindPrompt(w.promptPart, "BuyPrompt") or HaimiyachGAG2_FindPrompt(w.part, "BuyPrompt")
        end
    else
        prompt = HaimiyachGAG2_FindPrompt(w, "BuyPrompt") or HaimiyachGAG2_FindPrompt(w)
    end
    return HaimiyachGAG2_FirePrompt(prompt)
end

local function HaimiyachGAG2_WaitWildPetConfirmed(w, beforeCount)
    if not w then return false end
    local part = w.part
    local visual = w.visual
    local prompt = w.prompt
    local petName = tostring(w.name or "")
    local deadline = os.clock() + 4.75

    while os.clock() < deadline do
        if part and not part.Parent then return true end
        if part and not part:IsDescendantOf(Workspace) then return true end
        if visual and not visual.Parent then return true end
        if visual and not visual:IsDescendantOf(Workspace) then return true end

        if part then
            local owner = tonumber(part:GetAttribute("OwnerUserId")) or tonumber(part:GetAttribute("Owner")) or 0
            if owner == LocalPlayer.UserId then return true end
            if owner ~= 0 and owner ~= tonumber(w.owner or 0) then return true end

            local state = string.lower(tostring(part:GetAttribute("State") or part:GetAttribute("PetState") or ""))
            if string.find(state, "tame", 1, true) or string.find(state, "own", 1, true) or string.find(state, "sold", 1, true) then
                return true
            end
        end

        if prompt and prompt.Parent and prompt.Enabled == false then
            local owner2 = part and (tonumber(part:GetAttribute("OwnerUserId")) or 0) or 0
            if owner2 == LocalPlayer.UserId then return true end
        end

        if petName ~= "" and HaimiyachGAG2_InventoryPetCount(petName) > (tonumber(beforeCount) or 0) then
            return true
        end

        task.wait(0.1)
    end

    return false
end

local function HaimiyachGAG2_TameWildPet(w)
    if not (w and w.part and w.part.Parent) then return false end

    if not (w.visual and w.visual.Parent) then
        local visual, prompt, promptPart = HaimiyachGAG2_FindWildPetVisual(w.part)
        w.visual = visual or w.visual
        w.prompt = prompt or w.prompt
        w.promptPart = promptPart or w.promptPart
        w.pos = HaimiyachGAG2_ModelPos(w.promptPart) or HaimiyachGAG2_ModelPos(w.visual) or w.pos
    end

    local petName = tostring(w.name or "?")
    local beforeCount = HaimiyachGAG2_InventoryPetCount(petName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local savedCf = hrp and hrp.CFrame or nil
    local gardenPos = myBasePos and myBasePos() or nil
    local moved = false
    local targetPos = HaimiyachGAG2_ModelPos(w.promptPart) or HaimiyachGAG2_ModelPos(w.visual) or w.pos

    if S.petTeleport and targetPos and hrp then
        pcall(function() hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0)) end)
        moved = true
        task.wait(0.55)
    end

    local fired = false
    for attempt = 1, 3 do
        if not S.autoBuyPets then break end
        if not (w.part and w.part.Parent) then break end

        local promptOk = HaimiyachGAG2_TriggerWildPetPrompt(w)
        task.wait(0.15)
        local ok = fire("Pets.WildPetTame", w.part)
        fired = fired or ok or promptOk

        if HaimiyachGAG2_WaitWildPetConfirmed(w, beforeCount) then
            if moved and S.petTeleport then
                local rootNow = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if rootNow then
                    if gardenPos then
                        pcall(function() rootNow.CFrame = CFrame.new(gardenPos + Vector3.new(0, 4, 0)) end)
                        Stats.lastReturnGardenStatus = "PET OK"
                    elseif savedCf then
                        pcall(function() rootNow.CFrame = savedCf end)
                        Stats.lastReturnGardenStatus = "PET FALLBACK"
                    else
                        Stats.lastReturnGardenStatus = "PET NO BASE"
                    end
                    Stats.lastReturnGardenAt = os.clock()
                end
            end
            return true
        end
        task.wait(0.55)
    end

    if not fired and Stats.SetWarning then
        Stats.SetWarning("PET", "Tame remote failed: " .. petName)
    elseif Stats.SetWarning then
        Stats.SetWarning("PET", "Tame not confirmed: " .. petName)
    end
    return false
end

-- AUTO BUY selected world pets: teleport to pet, tame/buy, then return only after confirmed.
-- Buying == Pets.WildPetTame:Fire(refPart); server charges Price and REQUIRES proximity.
loopOn(function() return S.autoBuyPets end, function() return S.petBuyInterval end, function()
    if (type(S.buyWorldPets) ~= "table" or not picked(S.buyWorldPets)) and (type(S.wildPetRarities) ~= "table" or not picked(S.wildPetRarities)) then return end
    for _, w in ipairs(wildPets()) do
        if not S.autoBuyPets then break end
        if HaimiyachGAG2_WildPetMatchesAuto(w) then
            local ok = HaimiyachGAG2_TameWildPet(w)
            if ok then
                Stats.tamed = Stats.tamed + 1
                if Stats.SetLastAction then Stats.SetLastAction("PET", "Tamed " .. tostring(w.name or "?")) end
            end
            task.wait(jitter(0.35, 0.7))
        end
    end
end)
loopOn(function() return S.espWildPet end, 1, function()
    HaimiyachGAG2_UpdateWildPetESP()
end)

loopOn(function() return S.notifyRareWeather end, 2, function()
    HaimiyachGAG2_NotifyRareWeatherStep()
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
-- //                    AUTO BUY CRATES (Charlotte)               \\ --
-- // ============================================================ \\ --
-- Uses CrateShop stock values + the real GUI controller BuyButton.
-- No max price filter: only skips when stock is 0 or Sheckles are not enough.

HaimiyachGAG2_CrateBoughtThisRestock = HaimiyachGAG2_CrateBoughtThisRestock or {}
HaimiyachGAG2_CrateBoughtRestockKey = HaimiyachGAG2_CrateBoughtRestockKey or ""
HaimiyachGAG2_CrateBuyLock = false

function HaimiyachGAG2_CrateNames()
    local seen, out = {}, {}

    local function add(n)
        n = tostring(n or "")
        if n ~= "" and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end

    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("SharedModules")
        mod = mod and mod:FindFirstChild("CrateData")
        local data = mod and require(mod)
        if type(data) == "table" and type(data.GetAllCrates) == "function" then
            for _, row in ipairs(data.GetAllCrates()) do
                if type(row) == "table" then add(row.Name or row.CrateName or row.ItemName) end
            end
        end
    end)

    local root = HaimiyachGAG2_FindCrateStockRoot and HaimiyachGAG2_FindCrateStockRoot()
    local items = root and root:FindFirstChild("Items")
    if items then
        for _, item in ipairs(items:GetChildren()) do add(item.Name) end
    end

    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pg and pg:FindFirstChild("CrateShop")
    local scroll = shop and shop:FindFirstChild("ScrollingFrame", true)
    if scroll then
        for _, item in ipairs(scroll:GetChildren()) do
            if item:IsA("GuiObject") and item.Name ~= "ItemTemplate" and item.Name ~= "Sheckles_Shelf" and item.Name ~= "Robux_Shelf" then
                add(item.Name)
            end
        end
    end

    if #out == 0 then
        for _, n in ipairs({
            "Ladder Crate", "Bench Crate", "Light Crate", "Sign Crate", "Arch Crate",
            "Picture Frame Crate", "Bridge Crate", "Conveyor Crate", "Seesaw Crate",
            "Fence Crate", "Owner Door Crate", "Teleporter Pad Crate", "Spring Crate",
            "Roleplay Crate", "Bear Trap Crate", "Common Guild Crate", "Uncommon Guild Crate",
            "Rare Guild Crate", "Epic Guild Crate", "Legendary Guild Crate", "Mythic Guild Crate",
            "Super Guild Crate"
        }) do add(n) end
    end

    table.sort(out)
    return out
end

function HaimiyachGAG2_FindCrateStockRoot()
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    local candidates = {
        stockValues and stockValues:FindFirstChild("CrateShop"),
        ReplicatedStorage:FindFirstChild("CrateShop"),
        Workspace:FindFirstChild("CrateShop"),
    }

    for _, root in ipairs(candidates) do
        if root and root:FindFirstChild("Items") then return root end
    end

    for _, root in ipairs({ ReplicatedStorage, Workspace }) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj.Name == "CrateShop" and obj:FindFirstChild("Items") then
                    return obj
                end
            end
        end
    end

    return nil
end

function HaimiyachGAG2_CrateRestockKey()
    local root = HaimiyachGAG2_FindCrateStockRoot()
    if not root then return "NO_CRATE_STOCK" end
    local last = root:FindFirstChild("UnixLastRestock")
    local nextv = root:FindFirstChild("UnixNextRestock")
    return tostring(last and last.Value or "?") .. ":" .. tostring(nextv and nextv.Value or "?")
end

function HaimiyachGAG2_ResetCrateBoughtIfRestocked()
    local key = HaimiyachGAG2_CrateRestockKey()
    if key ~= HaimiyachGAG2_CrateBoughtRestockKey then
        HaimiyachGAG2_CrateBoughtRestockKey = key
        HaimiyachGAG2_CrateBoughtThisRestock = {}
    end
end

function HaimiyachGAG2_ParseCrateCost(text)
    text = tostring(text or "")
    if text == "" or string.find(string.lower(text), "no stock", 1, true) then return nil end
    local mult = 1
    if string.find(string.lower(text), "k", 1, true) then mult = 1000 end
    if string.find(string.lower(text), "m", 1, true) then mult = 1000000 end
    local raw = string.gsub(text, "[^%d%.]", "")
    local n = tonumber(raw)
    return n and n * mult or nil
end

function HaimiyachGAG2_CrateStock(name)
    name = tostring(name or "")
    local root = HaimiyachGAG2_FindCrateStockRoot()
    local items = root and root:FindFirstChild("Items")
    local item = items and items:FindFirstChild(name)
    if item and item:IsA("NumberValue") then
        return tonumber(item.Value) or 0
    end

    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pg and pg:FindFirstChild("CrateShop")
    local frame = shop and shop:FindFirstChild(name, true)
    local stockLabel = frame and frame:FindFirstChild("Stock_Text", true)
    local stockText = stockLabel and tostring(stockLabel.Text or "") or ""
    local n = string.match(stockText, "x%s*(%d+)")
    return n and tonumber(n) or nil
end

function HaimiyachGAG2_CrateCostFromGui(name)
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pg and pg:FindFirstChild("CrateShop")
    local frame = shop and shop:FindFirstChild(tostring(name or ""), true)
    local costLabel = frame and frame:FindFirstChild("Cost_Text", true)
    return costLabel and HaimiyachGAG2_ParseCrateCost(costLabel.Text) or nil
end

function HaimiyachGAG2_ClickGuiButton(btn)
    if not (btn and btn:IsA("GuiButton")) then return false end

    local ok = pcall(function()
        btn:Activate()
    end)
    if ok then return true end

    if type(firesignal) == "function" then
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Up) end)
        return true
    end

    return false
end

function HaimiyachGAG2_FindCrateItemButton(frame)
    if not frame then return nil end
    if frame:IsA("GuiButton") then return frame end
    for _, obj in ipairs(frame:GetDescendants()) do
        if obj:IsA("GuiButton") then
            local n = string.lower(tostring(obj.Name or ""))
            if n ~= "buybutton" and n ~= "giftbutton" and n ~= "togglerobux" and n ~= "togglesheckles" then
                return obj
            end
        end
    end
    return nil
end

function HaimiyachGAG2_HideCrateShopGui()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pg and pg:FindFirstChild("CrateShop")
    if shop then
        pcall(function() shop.Enabled = false end)
        local frame = shop:FindFirstChild("Frame")
        if frame and frame:IsA("GuiObject") then
            pcall(function() frame.Visible = false end)
        end
    end
end

function HaimiyachGAG2_BuyCrateViaGui(crateName)
    crateName = tostring(crateName or "")
    if crateName == "" then return false, "empty crate" end
    if HaimiyachGAG2_CrateBuyLock then return false, "buy locked" end

    HaimiyachGAG2_CrateBuyLock = true

    local okFinal, result = pcall(function()
        local stock = HaimiyachGAG2_CrateStock(crateName)
        if stock ~= nil and stock <= 0 then return false, "no stock" end

        -- No max-price filter. Only enough-money check if GUI cost is readable.
        local cost = HaimiyachGAG2_CrateCostFromGui(crateName)
        if cost and cost > 0 and getSheckles() < cost then
            return false, "not enough sheckles"
        end

        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local shop = pg and pg:FindFirstChild("CrateShop")
        if not shop then return false, "CrateShop GUI not found. Open Charlotte first." end

        pcall(function() shop.Enabled = true end)
        local mainFrame = shop:FindFirstChild("Frame")
        if mainFrame and mainFrame:IsA("GuiObject") then
            pcall(function() mainFrame.Visible = true end)
        end

        local scroll = shop:FindFirstChild("ScrollingFrame", true)
        local frame = scroll and scroll:FindFirstChild(crateName) or shop:FindFirstChild(crateName, true)
        if not frame then
            HaimiyachGAG2_HideCrateShopGui()
            return false, "crate frame not found"
        end

        local selectBtn = HaimiyachGAG2_FindCrateItemButton(frame)
        if selectBtn then
            HaimiyachGAG2_ClickGuiButton(selectBtn)
            task.wait(0.18)
        end

        local shelf = shop:FindFirstChild("Sheckles_Shelf", true)
        local buyButton = shelf and shelf:FindFirstChild("BuyButton", true) or shop:FindFirstChild("BuyButton", true)
        if not buyButton or not buyButton:IsA("GuiButton") then
            HaimiyachGAG2_HideCrateShopGui()
            return false, "BuyButton not found"
        end

        local before = HaimiyachGAG2_CrateStock(crateName)
        HaimiyachGAG2_ClickGuiButton(buyButton)
        task.wait(0.45)
        HaimiyachGAG2_HideCrateShopGui()
        task.wait(0.25)

        local after = HaimiyachGAG2_CrateStock(crateName)
        if before ~= nil and after ~= nil and after >= before then
            -- Some stock values update with slight delay, so return success after real click but do not spam.
            task.wait(0.55)
            after = HaimiyachGAG2_CrateStock(crateName)
        end

        Stats.TrackPurchase("Crate", crateName, 1)
        return true, "clicked buy"
    end)

    HaimiyachGAG2_CrateBuyLock = false

    if not okFinal then return false, result end
    if type(result) == "table" then return unpack(result) end
    return result == true, tostring(result)
end

function HaimiyachGAG2_BuySelectedCratesOnce()
    if type(S.buyCrates) ~= "table" or not picked(S.buyCrates) then
        return false, "no selected crates"
    end

    HaimiyachGAG2_ResetCrateBoughtIfRestocked()

    local boughtAny = false
    for crateName, enabled in pairs(S.buyCrates) do
        if not S.autoBuyCrates and not HaimiyachGAG2_ManualCrateBuyNow then break end
        if enabled == true and not HaimiyachGAG2_CrateBoughtThisRestock[crateName] then
            local stock = HaimiyachGAG2_CrateStock(crateName)
            if stock and stock > 0 then
                local okBuy, reason = HaimiyachGAG2_BuyCrateViaGui(crateName)
                HaimiyachGAG2_CrateBoughtThisRestock[crateName] = true
                if okBuy then
                    boughtAny = true
                    notify("HAIMIYACH HUB", "Bought crate: " .. tostring(crateName), 3)
                else
                    -- Mark it for this restock to prevent spam. Manual reset/restock will try again.
                    warn("[HAIMIYACH HUB] Crate buy skipped:", crateName, reason)
                end
                task.wait(jitter(0.45, 0.85))
            end
        end
    end

    return boughtAny
end

loopOn(function() return S.autoBuyCrates end, function() return S.crateBuyDelay end, function()
    HaimiyachGAG2_ManualCrateBuyNow = false
    HaimiyachGAG2_BuySelectedCratesOnce()
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
loopOn(function() return S.autoGear or S.autoBuyAllGear end, function() return S.gearInterval end, function()
    if not (S.autoBuyAllGear or picked(S.gearBuy)) then return end
    if S.autoBuyAllGear then
        for _, name in ipairs(GEAR_NAMES) do
            if not (S.autoGear or S.autoBuyAllGear) then break end
            local stock = stockOf("GearShop", name)
            if stock == nil or stock > 0 then
                local okBuy, res = fire("GearShop.PurchaseGear", name)
                if okBuy and not (type(res) == "table" and res.Success == false) then
                    Stats.TrackPurchase("Gear", name, 1)
                end
                task.wait(jitter(0.2, 0.4))
            end
        end
    else
        for name in pairs(S.gearBuy) do
            if not S.autoGear then break end
            local stock = stockOf("GearShop", name)
            if stock == nil or stock > 0 then
                local okBuy, res = fire("GearShop.PurchaseGear", name)
                if okBuy and not (type(res) == "table" and res.Success == false) then
                    Stats.TrackPurchase("Gear", name, 1)
                end
                task.wait(jitter(0.2, 0.4))
            end
        end
    end
end)

-- // ============================================================ \\ --
-- //                     STEAL (PvP, night)                      \\ --
-- // ============================================================ \\ --
-- Instant steal: proximity is server-gated like the prompt, so teleport to the fruit unless disabled.
-- Smart mode: choose the highest-value fruit from the highest-value garden, and return only after steal is confirmed.
local function hrpNow() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local HaimiyachGAG2_StealFailUntil = HaimiyachGAG2_StealFailUntil or {}

local function HaimiyachGAG2_StealKey(f)
    return tostring(f.owner or 0) .. ":" .. tostring(f.plantId or "") .. ":" .. tostring(f.fruitId or "")
end

local function HaimiyachGAG2_PromptObjectPos(prompt, model)
    local parent = prompt and prompt.Parent
    if parent and parent:IsA("BasePart") then return parent.Position end
    if model then
        local ok, cf = pcall(function() return model:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    return nil
end

local function HaimiyachGAG2_IsOwnerNear(ownerId, pos, range)
    if not (ownerId and ownerId > 0 and pos) then return false end
    local plr = Players:GetPlayerByUserId(ownerId)
    local char = plr and plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return (root.Position - pos).Magnitude <= (tonumber(range) or 45)
end

local function HaimiyachGAG2_StealFruitValue(model)
    if not model then return 1 end
    local name = HaimiyachGAG2_ObjectName(model)
    if name == "" then name = tostring(model:GetAttribute("PlantName") or model.Name or "Fruit") end
    local size = tonumber(model:GetAttribute("SizeMultiplier")) or tonumber(model:GetAttribute("FruitSize")) or 1
    local ok, value = pcall(function()
        if GardenESP and GardenESP.valueFor then
            return GardenESP.valueFor(model, name, size)
        end
        return nil
    end)
    value = ok and tonumber(value) or nil
    if not value or value < 1 then value = math.max(1, math.floor(size * 1000)) end
    return value
end

local function HaimiyachGAG2_BuildStealTargets()
    local targets = {}
    local gardenTotals = {}
    local now = os.clock()

    for _, pr in ipairs(CollectionService:GetTagged("StealPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(Workspace) then
            local m = promptCarrier(pr)
            local pid = m and m:GetAttribute("PlantId")
            if pid then
                local owner = tonumber(m:GetAttribute("UserId")) or tonumber(m:GetAttribute("OwnerUserId")) or 0
                if owner ~= LocalPlayer.UserId then
                    local fruitId = tostring(m:GetAttribute("FruitId") or "")
                    local key = tostring(owner) .. ":" .. tostring(pid) .. ":" .. fruitId
                    local blockedUntil = tonumber(HaimiyachGAG2_StealFailUntil[key]) or 0
                    local pos = HaimiyachGAG2_PromptObjectPos(pr, m)
                    if blockedUntil <= now and pos and not HaimiyachGAG2_IsOwnerNear(owner, pos, 45) then
                        local value = HaimiyachGAG2_StealFruitValue(m)
                        local gardenKey = tostring(owner)
                        gardenTotals[gardenKey] = (gardenTotals[gardenKey] or 0) + value
                        targets[#targets + 1] = {
                            owner = owner,
                            plantId = tostring(pid),
                            fruitId = fruitId,
                            pos = pos,
                            prompt = pr,
                            obj = m,
                            value = value,
                            gardenKey = gardenKey,
                            key = key,
                        }
                    end
                end
            end
        end
    end

    table.sort(targets, function(a, b)
        local ga = gardenTotals[a.gardenKey] or 0
        local gb = gardenTotals[b.gardenKey] or 0
        if ga ~= gb then return ga > gb end
        return (a.value or 0) > (b.value or 0)
    end)

    return targets
end

local function HaimiyachGAG2_HasStealCarry()
    local a = LocalPlayer:GetAttribute("CarryingStolenFruit")
    local b = LocalPlayer:GetAttribute("CarryingFruit")
    if a == true then return true end
    if type(a) == "string" and a ~= "" then return true end
    if type(b) == "string" and b ~= "" then return true end
    return false
end

local function HaimiyachGAG2_WaitStealConfirmed(f)
    local deadline = os.clock() + 2.75
    while os.clock() < deadline do
        if HaimiyachGAG2_HasStealCarry() then return true end
        if f.obj and not f.obj:IsDescendantOf(Workspace) then return true end
        if f.prompt and f.prompt.Parent and f.prompt.Enabled == false then
            if HaimiyachGAG2_HasStealCarry() then return true end
        end
        task.wait(0.1)
    end
    return false
end

local function HaimiyachGAG2_TriggerStealPrompt(prompt)
    if not (prompt and prompt.Parent and prompt.Enabled) then return false end
    if type(fireproximityprompt) == "function" then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then return true end
    end
    local ok2 = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(0.08, tonumber(prompt.HoldDuration) or 0.08))
        prompt:InputHoldEnd()
    end)
    return ok2 and true or false
end

local function HaimiyachGAG2_ReturnHomeAfterSteal()
    if not S.stealReturnBase then return true end
    local base = myBasePos()
    local hrp = hrpNow()
    if not (base and hrp) then return false end
    pcall(function() hrp.CFrame = CFrame.new(base + Vector3.new(0, 4, 0)) end)
    local t0 = os.clock()
    while HaimiyachGAG2_HasStealCarry() and os.clock() - t0 < 4 and S.autoSteal do
        task.wait(0.15)
    end
    return true
end

loopOn(function() return S.autoSteal end, 1.5, function()
    if not isNight() then return end
    if HaimiyachGAG2_HasStealCarry() then
        HaimiyachGAG2_ReturnHomeAfterSteal()
        return
    end

    local targets = HaimiyachGAG2_BuildStealTargets()
    for _, f in ipairs(targets) do
        if not (S.autoSteal and isNight()) then break end
        if HaimiyachGAG2_HasStealCarry() then break end

        if S.stealTeleport and f.pos then
            local hrp = hrpNow()
            if hrp then
                pcall(function() hrp.CFrame = CFrame.new(f.pos + Vector3.new(0, 4, 0)) end)
                task.wait(0.45)
            end
        end

        local okBegin = fire("Steal.BeginSteal", f.owner, f.plantId, f.fruitId)
        HaimiyachGAG2_TriggerStealPrompt(f.prompt)
        task.wait(0.12)
        fire("Steal.CompleteSteal")

        if okBegin and HaimiyachGAG2_WaitStealConfirmed(f) then
            Stats.stolen = Stats.stolen + 1
            if Stats.SetLastAction then Stats.SetLastAction("STEAL", "Stole fruit value " .. tostring(math.floor(tonumber(f.value) or 0))) end
            HaimiyachGAG2_ReturnHomeAfterSteal()
            break
        else
            HaimiyachGAG2_StealFailUntil[f.key or HaimiyachGAG2_StealKey(f)] = os.clock() + 20
            if Stats.SetWarning then Stats.SetWarning("STEAL", "Skip failed fruit") end
        end

        if (S.stealDelay or 0) > 0 then task.wait(S.stealDelay) end
    end
end)

-- Forward declaration used by Auto Server Hop before the webhook block is parsed.
local sendWebhook

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
loopOn(function() return S.autoSendMail end, function()
    local delayValue = tonumber(S.mailSendDelay) or 30
    if delayValue < 5 then delayValue = 5 end
    return delayValue
end, function()
    HaimiyachGAG2_SendSelectedMailNow(true)
end)
-- RESTOCK prediction / notify / watched-seed buyer loop
loopOn(function()
    return tostring(S.restockPredictionMode or "OFF") ~= "OFF" or S.restockNotifyWatched or S.restockAutoBuyWatched
end, 5, function()
    HaimiyachGAG2_RestockScan()
    HaimiyachGAG2_RestockNotifyStep()
    HaimiyachGAG2_RestockAutoBuyStep()
end)

-- server hop when enabled (RequestHop asks the server to migrate the player)
-- Important: this loop waits the full delay BEFORE the first hop.
-- The older loop executed once immediately, so setting 2 minutes could still hop right away
-- after enabling Auto Server Hop or after Auto Execute loaded in the next server.
task.spawn(function()
    local nextHopAt = nil
    while not S.killed do
        if S.autoHop and (tonumber(S.hopInterval) or 0) > 0 then
            local delaySec = math.max(60, tonumber(S.hopInterval) or 0)
            if not nextHopAt then
                nextHopAt = os.clock() + delaySec
                HaimiyachGAG2_NextHopAt = nextHopAt
            elseif os.clock() >= nextHopAt then
                local shouldHop, hopReason = HaimiyachGAG2_ShouldHopNow()
                if shouldHop then
                    HaimiyachGAG2_MarkHopReason(hopReason)
                    saveConfig(true)
                    local needsQueue = S.autoExecute or S.webhookEnabled or S.webhookDisconnect
                    local queued, qerr = queueAutoExecute(needsQueue)
                    if needsQueue and not queued then
                        notify("HAIMIYACH HUB", "Auto execute queue failed: " .. tostring(qerr), 4)
                    end
                    if S.webhookEnabled and string.match(S.webhookUrl or "", "^https?://") then
                        -- Give the HTTP request time to finish before the server hop starts.
                        pcall(function() sendWebhook(false) end)
                        task.wait(1.5)
                    end
                    notify("Server Hop", "Reason: " .. tostring(hopReason or "TIMER"), 3)
                    fire("AntiAfk.RequestHop")
                    nextHopAt = os.clock() + delaySec
                else
                    nextHopAt = os.clock() + 5
                end
                HaimiyachGAG2_NextHopAt = nextHopAt
            end
        else
            nextHopAt = nil
            HaimiyachGAG2_NextHopAt = nil
        end
        task.wait(0.5)
    end
end)
-- Anti-AFK: one toggle, idle-aware logic
-- Layer 1: VirtualUser fake tap, but only after the player has been idle long enough.
-- Layer 2: avatar jump every 3-5 minutes while idle.
-- This avoids spamming input/jump when the player is still active or when Anti AFK is OFF.
local AntiAfkUIS = nil
pcall(function() AntiAfkUIS = game:GetService("UserInputService") end)

local antiAfkIdleLimit = 300      -- 5 minutes before the script considers the player idle
local antiAfkTapDelay = 60        -- while idle, fake tap at most once every 60 seconds
local antiAfkLoopDelay = 2

local lastAntiAfkInputTick = tick()
local lastAntiAfkTapTick = tick()
local lastAntiAfkPulse = 0
local lastAntiAfkJump = 0
local nextAntiAfkJumpAt = tick() + math.random(180, 300)
local lastAntiAfkMode = "READY"

local function antiAfkNow()
    return tick()
end

local function antiAfkTouchInput()
    lastAntiAfkInputTick = antiAfkNow()
end

local function antiAfkAgo(t)
    if not t or t <= 0 then return "NEVER" end
    local d = math.max(0, math.floor(antiAfkNow() - t))
    if d < 60 then return tostring(d) .. "S" end
    return tostring(math.floor(d / 60)) .. "M"
end

local function antiAfkShortTime(seconds)
    local d = math.max(0, math.floor(tonumber(seconds) or 0))
    if d < 60 then return tostring(d) .. "S" end
    return tostring(math.floor(d / 60)) .. "M"
end

local function antiAfkIdleSeconds()
    return math.max(0, antiAfkNow() - lastAntiAfkInputTick)
end

local function antiAfkTapAgoSeconds()
    return math.max(0, antiAfkNow() - lastAntiAfkTapTick)
end

local function antiAfkNextJumpText()
    if not S.antiAfk then return "OFF" end
    local idle = antiAfkIdleSeconds()
    if idle < antiAfkIdleLimit then
        return "WAIT " .. antiAfkShortTime(antiAfkIdleLimit - idle)
    end
    return antiAfkShortTime((nextAntiAfkJumpAt or antiAfkNow()) - antiAfkNow())
end

local function antiAfkDashboardText()
    if not S.antiAfk then return "ANTI AFK: OFF" end
    local idle = antiAfkShortTime(antiAfkIdleSeconds())
    local tapAgo = antiAfkAgo(lastAntiAfkTapTick)
    return "ANTI AFK: ON | IDLE " .. idle .. " | TAP " .. tapAgo .. " | JUMP " .. antiAfkAgo(lastAntiAfkJump) .. " | NEXT " .. antiAfkNextJumpText()
end

local function antiAfkDisableOldIdledConnections()
    pcall(function()
        if getconnections and LocalPlayer and LocalPlayer.Idled then
            for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
                pcall(function()
                    if conn.Disable then conn:Disable() end
                end)
            end
        end
    end)
end

local function doAntiAfkPulse()
    if S.killed or not S.antiAfk or not VirtualUser then return false end
    local cam = workspace.CurrentCamera
    if not cam then return false end

    lastAntiAfkTapTick = antiAfkNow()
    lastAntiAfkPulse = lastAntiAfkTapTick
    lastAntiAfkMode = "VIRTUAL USER"

    pcall(function() VirtualUser:CaptureController() end)
    pcall(function() VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame) end)
    task.wait(0.1)
    pcall(function() VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame) end)
    pcall(function() VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
    return true
end

local function doAntiAfkJump()
    if S.killed or not S.antiAfk then return false end
    local hum = humanoid()
    if not (hum and hum.Parent and hum.Health > 0) then return false end
    if hum.Sit then pcall(function() hum.Sit = false end) end
    pcall(function() hum.Jump = true end)
    lastAntiAfkJump = antiAfkNow()
    lastAntiAfkMode = "JUMP"
    return true
end

antiAfkDisableOldIdledConnections()

if AntiAfkUIS then
    AntiAfkUIS.InputBegan:Connect(function()
        antiAfkTouchInput()
    end)
    AntiAfkUIS.InputChanged:Connect(function(inputObj)
        local t = inputObj.UserInputType
        if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Gamepad1 or t == Enum.UserInputType.Touch then
            antiAfkTouchInput()
        end
    end)
end

if VirtualUser then
    LocalPlayer.Idled:Connect(function()
        if S.killed or not S.antiAfk then return end
        doAntiAfkPulse()
    end)
end

task.spawn(function()
    while not S.killed do
        if S.antiAfk then
            local idle = antiAfkIdleSeconds()
            local sinceTap = antiAfkTapAgoSeconds()

            -- Do not spam while the player is active. Start fake taps only after real idle time reaches 5 minutes.
            if idle >= antiAfkIdleLimit and sinceTap >= antiAfkTapDelay then
                doAntiAfkPulse()
            elseif idle < antiAfkIdleLimit and sinceTap >= antiAfkIdleLimit then
                -- Safety fallback, similar to the reference logic: keep one delayed tap even if real inputs are still happening rarely.
                doAntiAfkPulse()
            end

            if idle >= antiAfkIdleLimit and antiAfkNow() >= nextAntiAfkJumpAt then
                if doAntiAfkJump() then
                    nextAntiAfkJumpAt = antiAfkNow() + math.random(180, 300)
                else
                    nextAntiAfkJumpAt = antiAfkNow() + 30
                end
            elseif idle < antiAfkIdleLimit then
                nextAntiAfkJumpAt = antiAfkNow() + math.random(180, 300)
            end
        else
            lastAntiAfkInputTick = antiAfkNow()
            lastAntiAfkTapTick = antiAfkNow()
            nextAntiAfkJumpAt = antiAfkNow() + math.random(180, 300)
        end
        task.wait(antiAfkLoopDelay)
    end
end)
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
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
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
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
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

local function NormalizeFPSBoostMode(mode)
    mode = string.upper(tostring(mode or "BALANCED"))
    if mode ~= "LIGHT" and mode ~= "BALANCED" and mode ~= "ULTRA" then
        mode = "BALANCED"
    end
    return mode
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
    local fpsMode = NormalizeFPSBoostMode(S.fpsBoostMode)

    S.fpsBoost = true
    S.highGraphics = false
    FPSBoostActive = true
    HighGraphicsActive = false

    -- Mobile safe FPS modes:
    -- LIGHT    = disable particles/lights/post effects only.
    -- BALANCED = LIGHT + terrain/water off + part shadows off + lighter decals.
    -- ULTRA    = BALANCED + potato mode: smooth plastic + hidden decals + hide gardens/plants/decor client-side.
    SafeSetProperty(Lighting, "GlobalShadows", false)
    SafeSetProperty(Lighting, "ExposureCompensation", 0)
    SafeSetProperty(Lighting, "ShadowSoftness", 0)
    if fpsMode == "LIGHT" then
        pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel3 end)
    else
        SafeSetProperty(Lighting, "Brightness", 1)
        SafeSetProperty(Lighting, "FogStart", 0)
        SafeSetProperty(Lighting, "FogEnd", 100000)
        SafeSetProperty(Lighting, "EnvironmentDiffuseScale", 0)
        SafeSetProperty(Lighting, "EnvironmentSpecularScale", 0)
        pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
        pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
    end

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") then
            SafeSetProperty(obj, "Enabled", false)
        elseif obj:IsA("Atmosphere") and fpsMode ~= "LIGHT" then
            SafeSetProperty(obj, "Density", 0)
            SafeSetProperty(obj, "Haze", 0)
            SafeSetProperty(obj, "Glare", 0)
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain and fpsMode ~= "LIGHT" then
        SafeSetProperty(terrain, "Decoration", false)
        SafeSetProperty(terrain, "WaterReflectance", 0)
        SafeSetProperty(terrain, "WaterTransparency", 1)
        SafeSetProperty(terrain, "WaterWaveSize", 0)
        SafeSetProperty(terrain, "WaterWaveSpeed", 0)
    end

    -- ULTRA detector dibuat sengaja simpel dan aman untuk executor.
    -- Penyebab file GOBEYGG sebelumnya masih kelihatan plants:
    -- logic lama cuma hide decor/leaf/effect dan other plot jika PlotId kebaca.
    -- Kalau PlotId telat / path plants bukan nama leaf, object tetap kelihatan.
    local gardensFolder = Workspace:FindFirstChild("Gardens")
    local temporaryFolder = Workspace:FindFirstChild("Temporary")
    local pottedPlantVisuals = Workspace:FindFirstChild("PottedPlantVisuals")

    local function hasText(text, needle)
        return string.find(text, needle, 1, true) ~= nil
    end

    local function isCharacterOrTool(obj)
        local cur = obj
        while cur and cur ~= Workspace do
            if cur:IsA("Tool") then
                return true
            end
            if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function shouldHideUltraVisual(obj)
        if not obj or isCharacterOrTool(obj) then
            return false
        end

        local cur = obj
        while cur and cur ~= Workspace do
            local curName = string.lower(tostring(cur.Name or ""))

            -- Direct visual folders used by Grow a Garden 2.
            if gardensFolder and cur.Parent == gardensFolder then
                -- Potato mode: hide own plot + other plots client-side.
                return true
            end
            if temporaryFolder and cur == temporaryFolder then
                return true
            end
            if pottedPlantVisuals and cur == pottedPlantVisuals then
                return true
            end

            -- Plants/fruits/decor can be inside custom model/folder names.
            if curName == "plants" or curName == "plant" or curName == "fruits" or curName == "fruit" or curName == "crops" or curName == "crop" then
                return true
            end

            if hasText(curName, "plant") or hasText(curName, "fruit") or hasText(curName, "crop") or hasText(curName, "leaf") or hasText(curName, "leaves") or hasText(curName, "stem") or hasText(curName, "tree") then
                return true
            end

            if hasText(curName, "decor") or hasText(curName, "cosmetic") or hasText(curName, "fakeplot") or hasText(curName, "visual") or hasText(curName, "preview") or hasText(curName, "effect") or hasText(curName, "vfx") or hasText(curName, "radius") then
                return true
            end

            cur = cur.Parent
        end

        return false
    end

    local function applyFPSObject(obj, mode)
        if not obj then return end

        DisableClientVisualEffect(obj)

        if mode == "LIGHT" then
            return
        end

        pcall(function()
            if obj:IsA("BasePart") then
                obj.CastShadow = false

                if mode == "ULTRA" then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0

                    if shouldHideUltraVisual(obj) then
                        obj.LocalTransparencyModifier = 1
                        obj.Transparency = 1
                    end
                end

            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                if mode == "ULTRA" then
                    obj.Transparency = 1
                else
                    local currentTransparency = tonumber(obj.Transparency) or 0
                    if currentTransparency < 0.6 then
                        obj.Transparency = 0.6
                    end
                end

            elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                if mode == "ULTRA" and shouldHideUltraVisual(obj) then
                    obj.Enabled = false
                end
            end
        end)
    end

    -- Batch scan supaya mobile tidak freeze saat descendants banyak.
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

            applyFPSObject(obj, fpsMode)

            processed = processed + 1
            if processed % 40 == 0 then
                task.wait()
            end
        end
    end)

    FPSBoostDescendantConnection = Workspace.DescendantAdded:Connect(function(obj)
        if FPSBoostActive and S.fpsBoost then
            task.delay(0.1, function()
                if FPSBoostActive and S.fpsBoost then
                    applyFPSObject(obj, NormalizeFPSBoostMode(S.fpsBoostMode))
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
local function getHttpRequest()
    return (syn and syn.request) or http_request or request or (http and http.request) or (fluxus and fluxus.request)
end
local httpRequest = getHttpRequest()
local function refreshHttpRequest(timeout)
    local deadline = os.clock() + (tonumber(timeout) or 0)
    repeat
        httpRequest = getHttpRequest()
        if httpRequest then return httpRequest end
        task.wait(0.25)
    until os.clock() >= deadline
    return nil
end
local function hms(sec)
    sec = math.floor(sec); local h = math.floor(sec / 3600); local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, sec%60) end
    return sec .. "s"
end

local function HaimiyachGAG2_OnOff(v)
    return v and "ON" or "OFF"
end

local function HaimiyachGAG2_AgeSuffix(t)
    t = tonumber(t) or 0
    if t <= 0 then return "-" end
    return hms(os.clock() - t) .. " ago"
end

local function HaimiyachGAG2_DashboardSystemText()
    local uptime = hms(os.clock() - (Stats.startAt or os.clock()))
    local serverAge = uptime
    pcall(function()
        if Workspace and Workspace.DistributedGameTime then
            serverAge = hms(Workspace.DistributedGameTime)
        end
    end)
    return "FPS: " .. tostring(currentFps) .. " | PING: " .. getPingText() .. "\nUPTIME: " .. uptime .. " | SERVER AGE: " .. serverAge
end

local function HaimiyachGAG2_DashboardFeatureFarmText()
    return "FARM " .. HaimiyachGAG2_OnOff(S.autoFarm) .. " | HARVEST " .. HaimiyachGAG2_OnOff(S.autoHarvest) .. " | PLANT " .. HaimiyachGAG2_OnOff(S.autoPlant) .. "\nSELL " .. HaimiyachGAG2_OnOff(S.autoSell) .. " | SHOVEL " .. HaimiyachGAG2_OnOff(S.autoShovelPlants or S.autoShovelFruits) .. " | WATER " .. HaimiyachGAG2_OnOff(S.autoWater)
end

local function HaimiyachGAG2_DashboardFeatureCollectText()
    return "COLLECT SEED " .. HaimiyachGAG2_OnOff(S.autoCollectSeed) .. " | FRUIT " .. HaimiyachGAG2_OnOff(S.autoCollectFruit) .. " | PET " .. HaimiyachGAG2_OnOff(S.autoCollectPet) .. "\nRETURN " .. HaimiyachGAG2_OnOff(S.collectSeedReturn) .. " | TELEPORT " .. HaimiyachGAG2_OnOff(S.collectSeedTeleport)
end

local function HaimiyachGAG2_DashboardFeatureShopText()
    return "BUY SEED " .. HaimiyachGAG2_OnOff(S.autoBuy or S.autoBuyAllSeeds) .. " | GEAR " .. HaimiyachGAG2_OnOff(S.autoGear or S.autoBuyAllGear) .. "\nCRATE " .. HaimiyachGAG2_OnOff(S.autoBuyCrates or S.autoCrate) .. " | PET " .. HaimiyachGAG2_OnOff(S.autoBuyPets) .. " | PACK " .. HaimiyachGAG2_OnOff(S.autoPack)
end

local function HaimiyachGAG2_DashboardFeatureUtilityText()
    return "AFK " .. HaimiyachGAG2_OnOff(S.antiAfk) .. " | RECONNECT " .. HaimiyachGAG2_OnOff(S.autoReconnect) .. " | HOP " .. HaimiyachGAG2_OnOff(S.autoHop) .. "\nWEBHOOK " .. HaimiyachGAG2_OnOff(S.webhookEnabled or S.webhookDisconnect) .. " | ESP " .. HaimiyachGAG2_OnOff(S.espGardenFruit or S.espGardenPlant or S.espBackpackFruit or S.espWildPet)
end

local function HaimiyachGAG2_DashboardReportBuyText()
    return string.format("BUY SEED OK: %d | GEAR: %d | CRATE: %d\nSPRINKLER: %d | OPENED: %d", tonumber(Stats.seedBought) or 0, tonumber(Stats.gearBought) or 0, tonumber(Stats.crateBought) or 0, tonumber(Stats.sprinklerBought) or 0, tonumber(Stats.opened) or 0)
end

local function HaimiyachGAG2_DashboardReportCollectText()
    return string.format("COLLECT SEED: %d | FRUIT: %d | PET: %d\nSELL: %d | EARNED: %s", tonumber(Stats.collectedSeeds) or 0, tonumber(Stats.collectedFruits) or 0, tonumber(Stats.collectedPets) or 0, tonumber(Stats.sold) or 0, fmt(Stats.earned or 0))
end

local function HaimiyachGAG2_DashboardLastActionText()
    local action = tostring(Stats.lastAction or "NONE")
    if action == "" then action = "NONE" end
    local ago = HaimiyachGAG2_AgeSuffix(Stats.lastActionAt)
    return "LAST ACTION: " .. action .. "\nTIME: " .. ago
end

local function HaimiyachGAG2_DashboardWarningText()
    local webhook = tostring(Stats.lastWebhookStatus or "OFF")
    local ret = tostring(Stats.lastReturnGardenStatus or "WAITING")
    local disconnect = tostring(Stats.lastDisconnectReason or "NONE")
    return "WEBHOOK: " .. webhook .. " | RECONNECT: " .. HaimiyachGAG2_OnOff(S.autoReconnect) .. "\nDISCONNECT: " .. disconnect .. " | RETURN: " .. ret
end

local function HaimiyachGAG2_DashboardWarningDetailText()
    local warn = tostring(Stats.lastWarning or "OK")
    local ago = HaimiyachGAG2_AgeSuffix(Stats.lastWarningAt)
    return "WARNING: " .. warn .. "\nLAST WARNING: " .. ago
end

function HaimiyachGAG2_ReportClean(text)
    text = tostring(text or "-")
    text = text:gsub("|", "|")
    text = text:gsub("OK", "OK")
    text = text:gsub("NO", "NO")
    text = text:gsub("WARNING", "WARNING")
    text = text:gsub("", "")
    text = text:gsub("", "")
    text = text:gsub("", "")
    text = text:gsub("", "")
    text = text:gsub("", "")
    text = text:gsub("", "")
    text = text:gsub("\r\n", "\n")
    text = text:gsub("\r", "\n")
    text = text:gsub("\t", " ")
    text = text:gsub("%s+\n", "\n"):gsub("\n%s+", "\n")
    return text
end

function Stats.WebhookFieldValue(text, maxLen)
    text = HaimiyachGAG2_ReportClean(text)
    if text == "" or text == "-" then text = "NONE" end
    maxLen = tonumber(maxLen) or 1000
    if #text > maxLen then
        text = string.sub(text, 1, math.max(1, maxLen - 3)) .. "..."
    end
    return text
end

function Stats.PurchaseCounterSummary(counter, limit)
    local rows = {}
    if type(counter) == "table" then
        for name, count in pairs(counter) do
            count = tonumber(count) or 0
            if count > 0 then
                rows[#rows + 1] = { name = Stats.CleanPurchaseName(name), count = count }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.count == b.count then return a.name < b.name end
        return a.count > b.count
    end)
    if #rows == 0 then return "NONE" end

    limit = tonumber(limit) or 10
    local out = {}
    local maxRows = math.min(#rows, limit)
    for i = 1, maxRows do
        out[#out + 1] = rows[i].name .. " x" .. tostring(rows[i].count)
    end
    if #rows > maxRows then
        out[#out + 1] = "+" .. tostring(#rows - maxRows) .. " more"
    end
    return table.concat(out, "\n")
end

function Stats.PurchaseSummary(total, counter, last)
    total = tonumber(total) or 0
    last = Stats.CleanPurchaseName(last or "NONE")
    return Stats.WebhookFieldValue("Total: " .. tostring(total) .. "\nLast: " .. last .. "\nItems:\n" .. Stats.PurchaseCounterSummary(counter, 10), 1000)
end

function Stats.WebhookStatusCode(res)
    if type(res) ~= "table" then return nil end
    return tonumber(res.StatusCode or res.Status or res.status_code or res.status)
end

function Stats.WebhookRequestGood(ok, res)
    if not ok then return false, "request" end
    local code = Stats.WebhookStatusCode(res)
    if code == nil then
        if type(res) == "table" and res.Success == false then return false, "request" end
        return true, nil
    end
    return code >= 200 and code < 300, code
end

sendWebhook = function(isTest)
    local req = refreshHttpRequest(isTest and 5 or 8)
    if not req then notify("Webhook", "Executor exposes no HTTP request fn", 4); return false end
    if not string.match(S.webhookUrl or "", "^https?://") then notify("Webhook", "Set a valid webhook URL", 4); return false end
    local gardenName = tostring((myPlot() and myPlot().Name) or "Unknown")
    local payload = {
        username = "HAIMIYACH HUB",
        embeds = { {
            title = "HAIMIYACH HUB REPORT",
            description = "Grow a Garden 2 session report",
            color = 5763719,
            fields = {
                { name = "Account", value = Stats.WebhookFieldValue("Player: " .. tostring(LocalPlayer.Name) .. "\nGarden: " .. gardenName), inline = false },
                { name = "Balance", value = Stats.WebhookFieldValue("Sheckles: " .. fmt(getSheckles()) .. "\nTokens: " .. fmt(getTokens())), inline = false },
                { name = "Farm Stats", value = Stats.WebhookFieldValue(string.format("Bought: %d\nSeeds Bought: %d\nGear Bought: %d\nSprinklers Bought: %d\nPlanted: %d\nHarvested: %d\nSold: %d\nEarned: %s", tonumber(Stats.bought) or 0, tonumber(Stats.seedBought) or 0, tonumber(Stats.gearBought) or 0, tonumber(Stats.sprinklerBought) or 0, tonumber(Stats.planted) or 0, tonumber(Stats.harvested) or 0, tonumber(Stats.sold) or 0, fmt(Stats.earned))), inline = false },
                { name = "Seed Purchases", value = Stats.PurchaseSummary(Stats.seedBought, Stats.purchaseSeeds, Stats.lastSeedBuy), inline = false },
                { name = "Gear Purchases", value = Stats.PurchaseSummary(Stats.gearBought, Stats.purchaseGear, Stats.lastGearBuy), inline = false },
                { name = "Sprinkler Purchases", value = Stats.PurchaseSummary(Stats.sprinklerBought, Stats.purchaseSprinklers, Stats.lastSprinklerBuy), inline = false },
                { name = "Activity", value = Stats.WebhookFieldValue(string.format("Sprinklers Placed: %d\nWatered: %d\nTamed: %d\nOpened: %d\nStolen: %d", tonumber(Stats.sprinklers) or 0, tonumber(Stats.watered) or 0, tonumber(Stats.tamed) or 0, tonumber(Stats.opened) or 0, tonumber(Stats.stolen) or 0)), inline = false },
                { name = "Seed Event", value = Stats.WebhookFieldValue("Available: " .. HaimiyachGAG2_ReportClean(getSeedEventAvailableText()) .. "\nClaimed: " .. HaimiyachGAG2_ReportClean(getSeedEventClaimText()) .. "\nLast: " .. HaimiyachGAG2_ReportClean(getSeedEventLastText())), inline = false },
                { name = "Runtime", value = Stats.WebhookFieldValue("Uptime: " .. hms(os.clock() - Stats.startAt) .. "\nFPS: " .. tostring(currentFps) .. "\nPing: " .. getPingText()), inline = false },
            },
            footer = { text = "HAIMIYACH HUB | Grow a Garden 2" },
        } }
    }
    local ok, res = pcall(function()
        return req({
            Url = S.webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    local good, code = Stats.WebhookRequestGood(ok, res)
    Stats.lastWebhookStatus = good and "READY" or ("ERROR " .. tostring(code or "request"))
    Stats.lastWebhookAt = os.clock()
    if not good and Stats.SetWarning then Stats.SetWarning("WEBHOOK", tostring(code or "request")) end
    if isTest then notify("Webhook", good and "Test sent" or ("Failed (" .. tostring(code or "request") .. ")"), 4) end
    return good
end
loopOn(function() return S.webhookEnabled end, function() return S.webhookInterval end, function() sendWebhook(false) end)
-- On auto-execute/re-execute/server-hop, send one delayed report after the new server is fully loaded.
task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    task.wait(5)
    if not S.killed and S.webhookEnabled and string.match(S.webhookUrl or "", "^https?://") then
        sendWebhook(false)
    end
end)

local DisconnectWebhookSent = false
local function sendDisconnectWebhook(reason, detail, force)
    if not force and not S.webhookDisconnect then return false end
    if DisconnectWebhookSent and not force then return false end
    local req = refreshHttpRequest(force and 5 or 8)
    if not req then
        if force then notify("Webhook", "Executor exposes no HTTP request fn", 4) end
        return false
    end
    if not string.match(S.webhookUrl or "", "^https?://") then
        if force then notify("Webhook", "Set a valid webhook URL", 4) end
        return false
    end

    DisconnectWebhookSent = true
    local payload = {
        username = "HAIMIYACH HUB",
        embeds = { {
            title = "HAIMIYACH HUB DISCONNECT REPORT",
            description = "Grow a Garden 2 connection status report",
            color = 16753920,
            fields = {
                { name = "Account", value = Stats.WebhookFieldValue("Player: " .. tostring(LocalPlayer.Name) .. "\nGarden: " .. tostring((myPlot() and myPlot().Name) or "Unknown")), inline = false },
                { name = "Reason", value = Stats.WebhookFieldValue(tostring(reason or "Disconnect detected")), inline = false },
                { name = "Detail", value = Stats.WebhookFieldValue(tostring(detail or "No extra detail")), inline = false },
                { name = "Server", value = Stats.WebhookFieldValue("PlaceId: " .. tostring(game.PlaceId) .. "\nJobId: " .. tostring(game.JobId ~= "" and game.JobId or "Unknown")), inline = false },
                { name = "Balance", value = Stats.WebhookFieldValue("Sheckles: " .. fmt(getSheckles()) .. "\nTokens: " .. fmt(getTokens())), inline = false },
                { name = "Seed Purchases", value = Stats.PurchaseSummary(Stats.seedBought, Stats.purchaseSeeds, Stats.lastSeedBuy), inline = false },
                { name = "Gear Purchases", value = Stats.PurchaseSummary(Stats.gearBought, Stats.purchaseGear, Stats.lastGearBuy), inline = false },
                { name = "Sprinkler Purchases", value = Stats.PurchaseSummary(Stats.sprinklerBought, Stats.purchaseSprinklers, Stats.lastSprinklerBuy), inline = false },
                { name = "Seed Event", value = Stats.WebhookFieldValue("Available: " .. HaimiyachGAG2_ReportClean(getSeedEventAvailableText()) .. "\nClaimed: " .. HaimiyachGAG2_ReportClean(getSeedEventClaimText()) .. "\nLast: " .. HaimiyachGAG2_ReportClean(getSeedEventLastText())), inline = false },
                { name = "Runtime", value = Stats.WebhookFieldValue("Uptime: " .. hms(os.clock() - Stats.startAt) .. "\nFPS: " .. tostring(currentFps) .. "\nPing: " .. getPingText()), inline = false },
            },
            footer = { text = "HAIMIYACH HUB | Disconnect" },
        } }
    }

    local ok, res = pcall(function()
        return req({
            Url = S.webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    local good, code = Stats.WebhookRequestGood(ok, res)
    Stats.lastWebhookStatus = good and "DISCONNECT SENT" or ("ERROR " .. tostring(code or "request"))
    Stats.lastWebhookAt = os.clock()
    if not good and Stats.SetWarning then Stats.SetWarning("WEBHOOK", tostring(code or "request")) end
    if force then notify("Webhook", good and "Disconnect test sent" or ("Failed (" .. tostring(code or "request") .. ")"), 4) end
    return good
end


-- Auto Reconnect: no top-level local helpers, supaya executor mobile tidak gagal compile.
_G.HaimiyachGAG2ReconnectState = _G.HaimiyachGAG2ReconnectState or { Busy = false, Last = 0, LastReason = "" }
function HaimiyachGAG2_TriggerAutoReconnect(reason, detail)
    if S.killed or not S.autoReconnect then return false end
    if _G.HaimiyachGAG2ReconnectState.Busy then return false end

    local now = os.clock()
    local reasonText = tostring(reason or "Disconnect detected")
    if _G.HaimiyachGAG2ReconnectState.LastReason == reasonText and (now - (_G.HaimiyachGAG2ReconnectState.Last or 0)) < 10 then
        return false
    end

    _G.HaimiyachGAG2ReconnectState.Busy = true
    _G.HaimiyachGAG2ReconnectState.Last = now
    _G.HaimiyachGAG2ReconnectState.LastReason = reasonText
    Stats.lastDisconnectReason = reasonText
    Stats.lastDisconnectAt = os.clock()
    if Stats.SetWarning then Stats.SetWarning("DISCONNECT", reasonText) end

    task.spawn(function()
        local delaySec = tonumber(S.reconnectDelay) or 5
        if delaySec < 3 then delaySec = 3 end
        if delaySec > 60 then delaySec = 60 end

        pcall(function() saveConfig(true) end)
        pcall(function()
            if S.autoExecute then queueAutoExecute(true) end
        end)
        pcall(function()
            notify("Auto Reconnect", "Disconnect detected. Rejoining in " .. tostring(math.floor(delaySec)) .. "s", 5)
        end)
        if S.webhookDisconnect then
            pcall(function() sendDisconnectWebhook(reasonText, tostring(detail or ""), false) end)
            task.wait(1)
        end

        task.wait(delaySec)
        if S.killed or not S.autoReconnect then
            _G.HaimiyachGAG2ReconnectState.Busy = false
            return
        end

        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
        task.wait(2)
        pcall(function()
            TeleportService:Teleport(game.PlaceId)
        end)
        task.wait(8)
        _G.HaimiyachGAG2ReconnectState.Busy = false
    end)
    return true
end

local function watchDisconnectPrompts()
    -- Roblox disconnect/kick prompt through GuiService.
    pcall(function()
        if GuiService and GuiService.ErrorMessageChanged then
            GuiService.ErrorMessageChanged:Connect(function(message)
                if S.killed or (not S.webhookDisconnect and not S.autoReconnect) then return end
                local text = tostring(message or "")
                if text ~= "" then
                    if S.webhookDisconnect then sendDisconnectWebhook("ROBLOX ERROR MESSAGE", text, false) end
                    HaimiyachGAG2_TriggerAutoReconnect("ROBLOX ERROR MESSAGE", text)
                end
            end)
        end
    end)

    -- Teleport/server-hop failures.
    pcall(function()
        if TeleportService and TeleportService.TeleportInitFailed then
            TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
                if S.killed or (not S.webhookDisconnect and not S.autoReconnect) then return end
                if player == LocalPlayer then
                    local detail = tostring(result) .. " | " .. tostring(errorMessage or "")
                    if S.webhookDisconnect then sendDisconnectWebhook("TELEPORT FAILED", detail, false) end
                    HaimiyachGAG2_TriggerAutoReconnect("TELEPORT FAILED", detail)
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
            if S.killed or (not S.webhookDisconnect and not S.autoReconnect) then return end
            local text = readText(inst)
            if text ~= "" and looksLikeDisconnect(text) then
                if S.webhookDisconnect then sendDisconnectWebhook("ROBLOX ERROR PROMPT", text, false) end
                HaimiyachGAG2_TriggerAutoReconnect("ROBLOX ERROR PROMPT", text)
            end
        end
        pcall(function()
            Core.DescendantAdded:Connect(function(inst)
                if S.killed or (not S.webhookDisconnect and not S.autoReconnect) then return end
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

local function HaimiyachGAG2_StartUI()
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
        pcall(function()
            obj[k] = v
        end)
    end

    if parent then
        pcall(function()
            obj.Parent = parent
        end)
    end

    return obj
end
local function corner(obj, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, obj)
end
local function stroke(obj, color, thickness, transparency)
    return new("UIStroke", { Color = color or T.Stroke, Thickness = thickness or 1, Transparency = transparency or 0.35 }, obj)
end
local function pad(obj, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, obj)
end
local function tween(obj, ti, props)
    pcall(function() TweenService:Create(obj, ti or TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end)
end
local function fmtValue(v, precision)
    precision = precision or 0
    if precision <= 0 then return tostring(math.floor((tonumber(v) or 0) + 0.5)) end
    local s = string.format("%." .. tostring(precision) .. "f", tonumber(v) or 0)
    s = string.gsub(s, "(%..-)0+$", "%1")
    s = string.gsub(s, "%.$", "")
    return s
end

local function cleanUiText(value)
    local s = tostring(value or "")
    s = s:gsub("[_%-]+", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return string.upper(s)
end

-- COPY YOUTUBE LINK ON EXECUTE
do
    local YOUTUBE_LINK = "https://youtube.com/@HAIMIYACH"

    local function CopyToClipboard(text)
        local copied = false

        if type(setclipboard) == "function" then
            pcall(function()
                setclipboard(text)
                copied = true
            end)
        elseif type(toclipboard) == "function" then
            pcall(function()
                toclipboard(text)
                copied = true
            end)
        elseif type(set_clipboard) == "function" then
            pcall(function()
                set_clipboard(text)
                copied = true
            end)
        end

        return copied
    end

    if not getgenv().HaimiyachYoutubeCopied then
        getgenv().HaimiyachYoutubeCopied = true

        if CopyToClipboard(YOUTUBE_LINK) then
            pcall(function()
                notify("HAIMIYACH HUB", "YouTube link copied.", 3)
            end)
        end
    end
end

local guiParent = PlayerGui or CoreGui
local ScreenGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Custom_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999995,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)

local BlankGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Blank_Screen",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999994,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Enabled = false,
}, guiParent)

local BlankFrame = new("Frame", {
    Name = "BlankFrame",
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Active = false,
    Selectable = false,
    ZIndex = 1,
}, BlankGui)

local function SetBlankScreenEnabled(state)
    S.blankScreen = state and true or false
    pcall(function()
        BlankGui.Enabled = S.blankScreen
        BlankFrame.Visible = S.blankScreen
    end)
end

local ScreenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
-- Match the original HAIMIYACH HUB custom UI proportions.
-- The uploaded HAIMIYACH-HUB.lua contains an older legacy GUI too; this size follows the custom top-tab UI style.
UI.Scale = (tonumber(S.uiScale) and tonumber(S.uiScale) > 0) and tonumber(S.uiScale) or (isMobile and 0.88 or 1)
S.uiScale = UI.Scale
do
    local savedKey = tostring(S.uiKeybindName or "LeftControl")
    if Enum.KeyCode[savedKey] then UI.Keybind = Enum.KeyCode[savedKey] end
end
local baseW = 600
local baseH = isMobile and 370 or 390

local Main = new("Frame", {
    Name = "MainWindow",
    Size = UDim2.fromOffset(baseW, baseH),
    Position = UDim2.new(0.5, -baseW/2, 0.5, -baseH/2),
    BackgroundColor3 = T.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
}, ScreenGui)
corner(Main, 14); stroke(Main, Color3.fromRGB(80,80,80), 1, 0.15)

local UIScaleObj = new("UIScale", { Scale = UI.Scale }, Main)

local TopBar = new("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = T.Top,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, Main)
corner(TopBar, 14)
-- TopBar needs its own UICorner. Parent UICorner does not reliably mask child frames in many Roblox executors,
-- so without this the upper left/right corners look sharp.
local TopCover = new("Frame", { Name = "TopCover", Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,1,-14), BackgroundColor3 = T.Top, BorderSizePixel = 0, ZIndex = 1 }, TopBar)
new("Frame", { Name = "TopLine", Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1), BackgroundColor3 = Color3.fromRGB(45,45,45), BorderSizePixel = 0, ZIndex = 2 }, TopBar)

local Title = new("TextLabel", {
    Size = UDim2.new(1, -120, 1, 0),
    Position = UDim2.fromOffset(18, 0),
    BackgroundTransparency = 1,
    Text = "HAIMIYACH HUB",
    TextColor3 = T.Text,
    Font = Enum.Font.GothamBlack,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local MinBtn = new("TextButton", {
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -74, 0, 9),
    BackgroundTransparency = 1,
    Text = "-",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false,
}, TopBar)
local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -40, 0, 9),
    BackgroundTransparency = 1,
    Text = "X",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false,
}, TopBar)

-- Separate minimized bar. Do not resize the main window into a bar because child frames can cover
-- the parent UICorner in some mobile executors and make the minimized UI look sharp/lancip.
-- MiniBar itself is transparent; MiniBg is the only visible rounded surface, so no square/lancip corner can show.
local MiniBar = new("Frame", {
    Name = "MinimizedWindow",
    Size = UDim2.fromOffset(math.floor((390 * UI.Scale) + 0.5), math.floor((44 * UI.Scale) + 0.5)),
    Position = Main.Position,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    Active = true,
    Visible = false,
}, ScreenGui)

local MiniBg = new("Frame", {
    Name = "RoundedMinimizedBackground",
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = T.Top,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    ZIndex = 1,
}, MiniBar)
corner(MiniBg, 16); stroke(MiniBg, Color3.fromRGB(80,80,80), 1, 0.15)

local MiniTitle = new("TextLabel", {
    Size = UDim2.new(1, -92, 1, 0),
    Position = UDim2.fromOffset(16, 0),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "HAIMIYACH HUB",
    TextColor3 = T.Text,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, MiniBar)

local MiniPlusBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -58, 0.5, -12),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "+",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    AutoButtonColor = false,
}, MiniBar)

local MiniCloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -30, 0.5, -12),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "X",
    TextColor3 = T.Muted,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    AutoButtonColor = false,
}, MiniBar)

local TabBar = new("ScrollingFrame", {
    Name = "LeftTabBar",
    Size = UDim2.new(0, 120, 1, -68),
    Position = UDim2.fromOffset(10, 56),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = isMobile and 3 or 4,
    ScrollBarImageColor3 = Color3.fromRGB(85,85,85),
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0,0),
    ClipsDescendants = true,
}, Main)
corner(TabBar, 12); stroke(TabBar, Color3.fromRGB(80,80,80), 1, 0.72); pad(TabBar, 8, 8, 8, 8)
local TabLayout = new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, TabBar)

local Content = new("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -144, 1, -68),
    Position = UDim2.fromOffset(134, 56),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, Main)
corner(Content, 12); stroke(Content, Color3.fromRGB(80,80,80), 1, 0.72)

local ShowGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Show_Button",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)
local ShowButton = new("TextButton", {
    Name = "LockedTopShowButton",
    AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.fromOffset(isMobile and 248 or 285, isMobile and 30 or 32),
    Position = UDim2.new(0.5, 0, 0, isMobile and 8 or 12),
    BackgroundColor3 = T.Top,
    BackgroundTransparency = 0,
    Text = "",
    TextTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
    Visible = false,
    ZIndex = 999,
}, ShowGui)

corner(ShowButton, 20)

local showBorder = Instance.new("UIStroke")
showBorder.Name = "BackgroundBorder"
showBorder.Color = Color3.fromRGB(80, 80, 80)
showBorder.Thickness = 1
showBorder.Transparency = 0.15
pcall(function()
    showBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end)
showBorder.Parent = ShowButton

local ShowButtonLabel = new("TextLabel", {
    Name = "StatusText",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -12, 1, 0),
    Position = UDim2.fromOffset(6, 0),
    Text = "HAIMIYACH HUB. |  -- FPS   |   -- ms",
    TextColor3 = T.Text,
    TextTransparency = 0,
    TextStrokeTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = isMobile and 12 or 13,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 1000,
}, ShowButton)

do
    local fpsValue = 0
    local pingValue = 0
    local fpsFrames = 0
    local fpsClock = os.clock()

    trackConnection(RunService.RenderStepped:Connect(function()
        fpsFrames = fpsFrames + 1
        local nowClock = os.clock()
        if nowClock - fpsClock >= 1 then
            fpsValue = math.floor(fpsFrames / (nowClock - fpsClock) + 0.5)
            fpsFrames = 0
            fpsClock = nowClock
        end
    end))

    task.spawn(function()
        while not S.killed do
            pcall(function()
                local stats = game:GetService("Stats")
                local net = stats:FindFirstChild("Network")
                local serverStats = net and net:FindFirstChild("ServerStatsItem")
                local pingItem = serverStats and serverStats:FindFirstChild("Data Ping")
                if pingItem and pingItem.GetValue then
                    pingValue = math.floor(tonumber(pingItem:GetValue()) or 0)
                end
            end)

            local fpsText = tostring(fpsValue > 0 and fpsValue or "--")
            local pingText = tostring(pingValue > 0 and pingValue or "--")
            ShowButtonLabel.Text = "HAIMIYACH HUB | " .. fpsText .. " FPS | " .. pingText .. " ms"

            task.wait(1)
        end
    end)
end

-- Drag main window from top bar only.
do
    local dragging = false
    local dragStart, startPos
    trackConnection(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and not UI.Unloaded and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

-- Drag minimized bar separately so the rounded bar keeps its own clean shape.
do
    local dragging = false
    local dragStart, startPos
    local function beginMiniDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MiniBar.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end
    trackConnection(MiniBar.InputBegan:Connect(beginMiniDrag))
    trackConnection(MiniBg.InputBegan:Connect(beginMiniDrag))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and not UI.Unloaded and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MiniBar.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

local function setVisible(v)
    UI.Visible = v and true or false
    if UI.Visible then
        ShowButton.Visible = false
        Main.Visible = not UI.Minimized
        MiniBar.Visible = UI.Minimized
    else
        Main.Visible = false
        MiniBar.Visible = false
        ShowButton.Visible = true
    end
end

local function setMinimized(v)
    UI.Minimized = v and true or false
    if UI.Minimized then
        MiniBar.Size = UDim2.fromOffset(math.floor((390 * UI.Scale) + 0.5), math.floor((44 * UI.Scale) + 0.5))
        MiniBar.Position = Main.Position
        Main.Visible = false
        MiniBar.Visible = UI.Visible
        MinBtn.Text = "-"
    else
        Main.Position = MiniBar.Position
        Main.Size = UDim2.fromOffset(baseW, baseH)
        TopBar.Position = UDim2.new(0, 0, 0, 0)
        TopBar.Size = UDim2.new(1, 0, 0, 48)
        if TopCover then TopCover.Visible = true end
        TabBar.Visible = true
        Content.Visible = true
        Main.Visible = UI.Visible
        MiniBar.Visible = false
        MinBtn.Text = "-"
    end
end

trackConnection(ShowButton.Activated:Connect(function()
    setMinimized(false)
    setVisible(true)
end))
trackConnection(MiniPlusBtn.Activated:Connect(function() setMinimized(false) end))
trackConnection(MiniCloseBtn.Activated:Connect(function() setVisible(false) end))
trackConnection(MinBtn.Activated:Connect(function() setMinimized(true) end))
trackConnection(CloseBtn.Activated:Connect(function() setVisible(false) end))
trackConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if UI.Unloaded then return end
    if input.KeyCode == UI.Keybind then
        setVisible(not UI.Visible)
    end
end))

local function refreshCanvas(page)
    task.defer(function()
        local layout = page:FindFirstChildOfClass("UIListLayout")
        if layout then page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18) end
    end)
end

local function selectTab(name)
    UI.CurrentTab = name
    for n, p in pairs(UI.Pages) do p.Visible = (n == name) end
    for n, b in pairs(UI.TabButtons) do
        local active = n == name
        tween(b, TweenInfo.new(0.12), {
            BackgroundColor3 = active and T.White or T.Row,
            TextColor3 = active and T.DarkText or T.Text,
        })
    end
end

local function createTab(name, order)
    -- Left sidebar tabs keep each page shorter and are easier to scroll on mobile.
    local displayNames = {
        ["PETS_CRATES"] = "PETS / CRATES",
    }
    local display = displayNames[name] or name
    local btn = new("TextButton", {
        Name = "Tab_" .. name,
        Size = UDim2.new(1, -2, 0, 42),
        BackgroundColor3 = T.Row,
        Text = cleanUiText(display),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = (#display > 12) and 10 or 11,
        BorderSizePixel = 0,
        LayoutOrder = order or 99,
        AutoButtonColor = true,
    }, TabBar)
    corner(btn, 12)
    stroke(btn, Color3.fromRGB(60,60,60), 1, 0.82)
    UI.TabButtons[name] = btn

    local page = new("ScrollingFrame", {
        Name = "Page_" .. name,
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = isMobile and 5 or 6,
        ScrollBarImageColor3 = Color3.fromRGB(80,80,80),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0,0),
        Visible = false,
    }, Content)
    pad(page, 3, 8, 2, 8)
    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    trackConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() refreshCanvas(page) end))
    UI.Pages[name] = page
    trackConnection(btn.Activated:Connect(function() selectTab(name) end))
    return page
end

local function safePage(page)
    return page or UI.Pages["DASHBOARD"]
end

local function addSection(page, text)
    page = safePage(page)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = cleanUiText(text),
        TextColor3 = T.Muted,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
    return lbl
end

local function addLabel(page, text)
    page = safePage(page)
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        Position = UDim2.fromOffset(11, 0),
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    return lbl
end

local function addMiniNote(page, text)
    page = safePage(page)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = T.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
    return lbl
end

local function addButton(page, label, callback)
    page = safePage(page)
    local btn = new("TextButton", {
        Size = UDim2.new(1,0,0,42),
        BackgroundColor3 = T.Row,
        BorderSizePixel = 0,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        AutoButtonColor = false,
    }, page)
    corner(btn, 12)
    trackConnection(btn.Activated:Connect(function()
        tween(btn, TweenInfo.new(0.08), { BackgroundColor3 = T.Row2 })
        task.delay(0.1, function() if btn and btn.Parent then tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = T.Row }) end end)
        if callback then task.spawn(function() pcall(callback) end) end
    end))
    return btn
end

local function addToggle(page, label, default, callback)
    page = safePage(page)
    local value = default and true or false
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    local txt = new("TextLabel", {
        Size = UDim2.new(1, -78, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local hit = new("TextButton", {
        Size = UDim2.fromOffset(52, 24),
        Position = UDim2.new(1, -64, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(38,38,38),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(hit, 13); stroke(hit, Color3.fromRGB(80,80,80), 1, 0.35)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(18,18),
        Position = UDim2.fromOffset(3,3),
        BackgroundColor3 = Color3.fromRGB(135,135,135),
        BorderSizePixel = 0,
    }, hit)
    corner(knob, 10)
    local function draw(call)
        tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = value and UDim2.fromOffset(31,3) or UDim2.fromOffset(3,3),
            BackgroundColor3 = value and T.White or Color3.fromRGB(135,135,135),
        })
        tween(hit, TweenInfo.new(0.15), { BackgroundColor3 = value and Color3.fromRGB(55,55,55) or Color3.fromRGB(38,38,38) })
        if call and callback then task.spawn(function() pcall(callback, value) end) end
    end
    trackConnection(hit.Activated:Connect(function() value = not value; draw(true) end))
    trackConnection(row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            local hp, hs = hit.AbsolutePosition, hit.AbsoluteSize
            local onSwitch = pos.X >= hp.X and pos.X <= hp.X + hs.X and pos.Y >= hp.Y and pos.Y <= hp.Y + hs.Y
            if not onSwitch then
                value = not value; draw(true)
            end
        end
    end))
    draw(false)
    return {
        Set = function(v, call) value = v and true or false; draw(call ~= false) end,
        Get = function() return value end,
    }
end

local function addSlider(page, label, min, max, default, precision, callback)
    page = safePage(page)
    min = tonumber(min) or 0; max = tonumber(max) or 100; precision = precision or 0

    -- Slider unit display:
    -- Label stays clean, value shows suffix.
    -- Example: "SPRINKLER DELAY (SEC)" -> label "SPRINKLER DELAY", value "60 sec"
    local displayLabel = tostring(label or "")
    local valueSuffix = ""
    local upperLabel = string.upper(displayLabel)

    if string.find(upperLabel, "%(SEC%)") then
        valueSuffix = " sec"
        displayLabel = displayLabel:gsub("%s*%([Ss][Ee][Cc]%)", "")
    elseif string.find(upperLabel, "%(MIN%)") then
        valueSuffix = " min"
        displayLabel = displayLabel:gsub("%s*%([Mm][Ii][Nn]%)", "")
    end

    local function fmtSliderValue(v)
        return fmtValue(v, precision) .. valueSuffix
    end

    local value = tonumber(default) or min
    value = math.clamp(value, min, max)
    local row = new("Frame", { Size = UDim2.new(1,0,0,50), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    local txt = new("TextLabel", {
        Size = UDim2.new(0.56, -16, 0, 22),
        Position = UDim2.fromOffset(12, 3),
        BackgroundTransparency = 1,
        Text = cleanUiText(displayLabel),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valLbl = new("TextLabel", {
        Size = UDim2.new(0.44, -16, 0, 22),
        Position = UDim2.new(0.56, 0, 0, 3),
        BackgroundTransparency = 1,
        Text = fmtSliderValue(value),
        TextColor3 = T.White,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local bar = new("TextButton", {
        Size = UDim2.new(1, -24, 0, 10),
        Position = UDim2.new(0, 12, 0, 34),
        BackgroundColor3 = Color3.fromRGB(26,26,26),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(bar, 10)
    local fill = new("Frame", { Size = UDim2.new(0,0,1,0), BackgroundColor3 = T.White, BorderSizePixel = 0 }, bar)
    corner(fill, 10)
    local knob = new("Frame", { Size = UDim2.fromOffset(18,18), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = T.White, BorderSizePixel = 0 }, bar)
    corner(knob, 10)
    stroke(knob, Color3.fromRGB(15,15,15), 1, 0.65)
    local dragging = false
    local function rounded(v)
        local mul = 10 ^ precision
        return math.floor(v * mul + 0.5) / mul
    end
    local function draw(call)
        local pct = 0
        if max ~= min then pct = (value - min) / (max - min) end
        pct = math.clamp(pct, 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = fmtSliderValue(value)
        if call and callback then task.spawn(function() pcall(callback, value) end) end
    end
    local function setFromX(x, call)
        local absPos = bar.AbsolutePosition.X
        local absSize = math.max(1, bar.AbsoluteSize.X)
        local pct = math.clamp((x - absPos) / absSize, 0, 1)
        value = rounded(min + (max - min) * pct)
        draw(call)
    end
    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X, true)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end
    trackConnection(bar.InputBegan:Connect(beginDrag))
    trackConnection(knob.InputBegan:Connect(beginDrag))
    trackConnection(fill.InputBegan:Connect(beginDrag))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and not UI.Unloaded and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X, true)
        end
    end))
    draw(false)
    return {
        Set = function(v, call) value = math.clamp(tonumber(v) or min, min, max); value = rounded(value); draw(call ~= false) end,
        Get = function() return value end,
    }
end

local function addInput(page, label, placeholder, default, callback)
    page = safePage(page)
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 12)
    new("TextLabel", {
        Size = UDim2.new(0.40, -16, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local box = new("TextBox", {
        Size = UDim2.new(0.60, -18, 0, 30),
        Position = UDim2.new(0.40, 8, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel = 0,
        Text = default or "",
        PlaceholderText = placeholder or "",
        TextColor3 = T.Text,
        PlaceholderColor3 = Color3.fromRGB(115,115,115),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 9); pad(box, 10, 10, 0, 0)
    trackConnection(box.FocusLost:Connect(function()
        if callback then task.spawn(function() pcall(callback, box.Text) end) end
    end))
    return box
end

local function tableFind(list, value)
    if table.find then return table.find(list, value) end
    for i, v in ipairs(list or {}) do
        if v == value then return i end
    end
    return nil
end

local dropdownZ = 10
local function addDropdown(page, label, options, default, multi, callback)
    page = safePage(page)
    options = options or {}
    local selected = {}
    local current = default
    if multi then
        if type(default) == "table" then
            for k, v in pairs(default) do if v == true then selected[k] = true elseif type(v) == "string" then selected[v] = true end end
        end
    end
    local row = new("Frame", { Size = UDim2.new(1,0,0,42), BackgroundColor3 = T.Row, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = dropdownZ }, page)
    corner(row, 12)
    new("TextLabel", {
        Size = UDim2.new(0.40, -16, 0, 42),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    local btn = new("TextButton", {
        Size = UDim2.new(0.60, -18, 0, 30),
        Position = UDim2.new(0.40, 8, 0, 6),
        BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = false,
        ClipsDescendants = true,
        ZIndex = dropdownZ + 1,
    }, row)
    corner(btn, 12)
    local btnText = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, btn)
    new("TextLabel", { Size = UDim2.fromOffset(24, 30), Position = UDim2.new(1, -28, 0, 0), BackgroundTransparency = 1, Text = "v", TextColor3 = T.Muted, Font = Enum.Font.GothamBold, TextSize = 12 }, btn)
    local list = new("ScrollingFrame", {
        Size = UDim2.new(0.60, -18, 0, 0),
        Position = UDim2.new(0.40, 8, 0, 40),
        BackgroundColor3 = Color3.fromRGB(21,21,21),
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(80,80,80),
        CanvasSize = UDim2.fromOffset(0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = dropdownZ + 2,
        ClipsDescendants = true,
    }, row)
    corner(list, 10); stroke(list, Color3.fromRGB(70,70,70), 1, 0.3)
    local layout = new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    pad(list, 6, 6, 6, 6)
    local function selectedText()
        if multi then
            local arr = {}
            for _, op in ipairs(options) do if selected[op] then arr[#arr + 1] = op end end
            if #arr == 0 then return "NONE" end
            for i, name in ipairs(arr) do arr[i] = cleanUiText(name) end
            if #arr <= 2 then return table.concat(arr, ", ") end
            return tostring(#arr) .. " SELECTED"
        else
            return cleanUiText((current == "Best owned" and "BEST OWNED") or current or options[1] or "SELECT")
        end
    end
    local function emit()
        btnText.Text = selectedText()
        if callback then
            if multi then
                local copy = {}
                for k, v in pairs(selected) do copy[k] = v end
                task.spawn(function() pcall(callback, copy) end)
            else
                task.spawn(function() pcall(callback, current) end)
            end
        end
    end
    local function rebuild()
        for _, ch in ipairs(list:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        for i, op in ipairs(options) do
            local item = new("TextButton", {
                Size = UDim2.new(1, -2, 0, 26),
                BackgroundColor3 = (multi and selected[op] or current == op) and Color3.fromRGB(230,230,230) or Color3.fromRGB(32,32,32),
                BorderSizePixel = 0,
                Text = (multi and (selected[op] and "x " or "") or "") .. cleanUiText(op),
                TextColor3 = (multi and selected[op] or current == op) and T.DarkText or T.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                LayoutOrder = i,
                AutoButtonColor = false,
                ZIndex = dropdownZ + 1,
            }, list)
            corner(item, 9)
            trackConnection(item.Activated:Connect(function()
                if multi then
                    selected[op] = not selected[op] or nil
                else
                    current = op
                    list.Visible = false
                end
                rebuild()
                emit()
                refreshCanvas(page)
            end))
        end
        task.defer(function()
            local h = math.min(132, layout.AbsoluteContentSize.Y + 10)
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
            if list.Visible then
                list.Size = UDim2.new(0.60, -20, 0, h)
            end
        end)
        btnText.Text = selectedText()
    end
    trackConnection(btn.Activated:Connect(function()
        list.Visible = not list.Visible
        dropdownZ = dropdownZ + 5
        row.ZIndex = dropdownZ
        btn.ZIndex = dropdownZ + 1
        list.ZIndex = dropdownZ + 2
        if list.Visible then
            local h = math.min(132, layout.AbsoluteContentSize.Y + 10)
            list.Size = UDim2.new(0.60, -20, 0, h)
        else
            list.Size = UDim2.new(0.60, -20, 0, 0)
        end
    end))
    rebuild()
    if not multi and not current then current = options[1] end
    btnText.Text = selectedText()
    return {
        SetOptions = function(newOptions)
            options = newOptions or {}
            if not multi and current and not tableFind(options, current) then current = options[1] end
            rebuild(); emit()
        end,
        Get = function() return multi and selected or current end,
        Set = function(v, call)
            if multi then
                selected = {}
                if type(v) == "table" then for k, val in pairs(v) do if val == true then selected[k] = true elseif type(val) == "string" then selected[val] = true end end end
            else current = v end
            rebuild(); if call ~= false then emit() end
        end,
    }
end

-- Tabs
createTab("DASHBOARD", 1)
createTab("FARM", 2)
createTab("BOOSTS", 3)
createTab("SHOP", 4)
createTab("PETS_CRATES", 6)
createTab("ESP", 7)
createTab("EVENTS", 8)
createTab("MAILBOX", 9)
createTab("STEAL", 10)
createTab("VISUALS", 11)
createTab("PROTECT", 12)
createTab("SETTINGS", 13)

-- DASHBOARD
addSection(UI.Pages["DASHBOARD"], "SYSTEM STATUS")
UI.systemStatusLabel = addLabel(UI.Pages["DASHBOARD"], "FPS: ? | PING: ?\nUPTIME: ? | SERVER AGE: ?")
UI.plotLabel = addLabel(UI.Pages["DASHBOARD"], "GARDEN: ?\nSHECKLES: ? | TOKENS: ?")
UI.afkStatusLabel = addLabel(UI.Pages["DASHBOARD"], "ANTI AFK: READY")

addSection(UI.Pages["DASHBOARD"], "FEATURE STATUS")
UI.featureFarmLabel = addLabel(UI.Pages["DASHBOARD"], "FARM OFF | HARVEST OFF | PLANT OFF\nSELL OFF | SHOVEL OFF | WATER OFF")
UI.featureCollectLabel = addLabel(UI.Pages["DASHBOARD"], "COLLECT SEED OFF | FRUIT OFF | PET OFF\nRETURN ON | TELEPORT ON")
UI.featureShopLabel = addLabel(UI.Pages["DASHBOARD"], "BUY SEED OFF | GEAR OFF\nCRATE OFF | PET OFF | PACK OFF")
UI.featureUtilityLabel = addLabel(UI.Pages["DASHBOARD"], "AFK ON | RECONNECT OFF | HOP OFF\nWEBHOOK OFF | ESP OFF")

addSection(UI.Pages["DASHBOARD"], "AUTO REPORT")
UI.reportBuyLabel = addLabel(UI.Pages["DASHBOARD"], "BUY SEED OK: 0 | GEAR: 0 | CRATE: 0\nSPRINKLER: 0 | OPENED: 0")
UI.reportCollectLabel = addLabel(UI.Pages["DASHBOARD"], "COLLECT SEED: 0 | FRUIT: 0 | PET: 0\nSELL: 0 | EARNED: 0")
UI.reportExtraLabel = addLabel(UI.Pages["DASHBOARD"], "PLANTED: 0 | HARVESTED: 0 | WATERED: 0\nTAMED: 0 | STOLEN: 0 | CODES: 0")

addSection(UI.Pages["DASHBOARD"], "LAST ACTION")
UI.lastActionLabel = addLabel(UI.Pages["DASHBOARD"], "LAST ACTION: NONE\nTIME: -")
UI.lastEventLabel = addLabel(UI.Pages["DASHBOARD"], "EVENT READY: NONE\nLAST EVENT CLAIM: NONE")

addSection(UI.Pages["DASHBOARD"], "WARNING STATUS")
UI.warningStatusLabel = addLabel(UI.Pages["DASHBOARD"], "WEBHOOK: OFF | RECONNECT: OFF\nDISCONNECT: NONE | RETURN: WAITING")
UI.warningDetailLabel = addLabel(UI.Pages["DASHBOARD"], "WARNING: OK\nLAST WARNING: -")
UI.nextHopLabel = addLabel(UI.Pages["DASHBOARD"], "NEXT SERVER HOP: OFF")
-- FARM
addSection(UI.Pages["FARM"], "MASTER")
addToggle(UI.Pages["FARM"], "AUTO FARM", S.autoFarm, function(v) S.autoFarm = v end)
addToggle(UI.Pages["FARM"], "AUTO EXPAND", S.autoExpand, function(v) S.autoExpand = v end)
addSection(UI.Pages["FARM"], "PLANT & HARVEST")
local plantOptions = { "BEST OWNED" }; for _, n in ipairs(SEED_NAMES) do plantOptions[#plantOptions + 1] = n end
addDropdown(UI.Pages["FARM"], "SEEDS TO PLANT", plantOptions, S.plantSeeds, true, function(sel)
    if type(S.plantSeeds) ~= "table" then S.plantSeeds = {} end
    pickMulti(sel, S.plantSeeds)
    local hasSpecific = false
    for name, enabled in pairs(S.plantSeeds) do
        if enabled == true and name ~= "BEST OWNED" and name ~= "Best owned" then hasSpecific = true; break end
    end
    S.plantSeed = hasSpecific and "Selected" or "Best owned"
end)
addToggle(UI.Pages["FARM"], "AUTO PLANT", S.autoPlant, function(v) S.autoPlant = v end)
addSlider(UI.Pages["FARM"], "PLANT DISTANCE", 2, 10, S.plantSpacing, 0, function(v) S.plantSpacing = v end)
addToggle(UI.Pages["FARM"], "AUTO HARVEST", S.autoHarvest, function(v) S.autoHarvest = v end)
addToggle(UI.Pages["FARM"], "AUTO HARVEST ALL", S.harvestAll, function(v) S.harvestAll = v end)
addDropdown(UI.Pages["FARM"], "HARVEST FRUIT TARGETS", SEED_NAMES, S.harvestFruitTargets, true, function(sel)
    pickMulti(sel, S.harvestFruitTargets)
    if HaimiyachGAG2_HasSelection(S.harvestFruitTargets) then S.harvestAll = false end
end)
addDropdown(UI.Pages["FARM"], "HARVEST KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.harvestKeepMutations, true, function(sel) pickMulti(sel, S.harvestKeepMutations) end)
addDropdown(UI.Pages["FARM"], "HARVEST WEIGHT FILTER", KG_MODE_OPTIONS, S.harvestKgMode, false, function(v) S.harvestKgMode = v end)
addSlider(UI.Pages["FARM"], "HARVEST WEIGHT VALUE", 0, 500, S.harvestKgValue, 1, function(v) S.harvestKgValue = v end)
addSlider(UI.Pages["FARM"], "HARVEST DELAY (SEC)", 0, 0.2, S.harvestDelay, 3, function(v) S.harvestDelay = v end)
addToggle(UI.Pages["FARM"], "AUTO POT PLANTS", S.autoPot, function(v) S.autoPot = v end)

-- AUTO
addSection(UI.Pages["FARM"], "SELL WHEN FULL")
addToggle(UI.Pages["FARM"], "AUTO SELL WHEN FULL", S.autoSell, function(v) S.autoSell = v end)
addSlider(UI.Pages["FARM"], "SELL DELAY (SEC)", 3, 120, S.sellInterval, 0, function(v) S.sellInterval = v end)
addDropdown(UI.Pages["FARM"], "SELL KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.sellKeepMutations, true, function(sel) pickMulti(sel, S.sellKeepMutations) end)
addDropdown(UI.Pages["FARM"], "SELL KEEP WEIGHT FILTER", KG_MODE_OPTIONS, S.sellKeepKgMode, false, function(v) S.sellKeepKgMode = v end)
addSlider(UI.Pages["FARM"], "SELL KEEP WEIGHT VALUE", 0, 500, S.sellKeepKgValue, 1, function(v) S.sellKeepKgValue = v end)
addSection(UI.Pages["EVENTS"], "WEATHER")
UI.activeWeatherLabel = addLabel(UI.Pages["EVENTS"], "ACTIVE WEATHER: NONE")
UI.weatherTimeLabel = addLabel(UI.Pages["EVENTS"], "WEATHER TIME LEFT: NONE")
UI.weatherMachineLabel = addLabel(UI.Pages["EVENTS"], "WEATHER MACHINE: ?")
addDropdown(UI.Pages["EVENTS"], "RARE WEATHER NOTIFY", HaimiyachGAG2_WeatherNames(), S.rareWeatherTargets, true, function(sel)
    if type(S.rareWeatherTargets) ~= "table" then S.rareWeatherTargets = {} end
    pickMulti(sel, S.rareWeatherTargets)
    saveConfig(true)
end)
addToggle(UI.Pages["EVENTS"], "NOTIFY RARE WEATHER", S.notifyRareWeather, function(v) S.notifyRareWeather = v; saveConfig(true) end)

addSection(UI.Pages["EVENTS"], "SEED EVENTS")
addToggle(UI.Pages["EVENTS"], "AUTO CLAIM EVENT SEEDS", S.autoClaimSeedEvent, function(v) S.autoClaimSeedEvent = v end)
addToggle(UI.Pages["EVENTS"], "USE FLY TO EVENT", S.claimUseFly, function(v) S.claimUseFly = v end)
addSlider(UI.Pages["EVENTS"], "EVENT CLAIM DELAY (SEC)", 3, 60, S.seedEventDelay, 0, function(v) S.seedEventDelay = v end)
addSection(UI.Pages["EVENTS"], "DAILY DEALS")
addToggle(UI.Pages["EVENTS"], "AUTO DAILY CLAIM", S.autoDaily, function(v) S.autoDaily = v end)
addSlider(UI.Pages["EVENTS"], "DAILY CLAIM DELAY (SEC)", 10, 300, S.dailyDelay, 0, function(v) S.dailyDelay = v end)
addSection(UI.Pages["FARM"], "DROPPED ITEMS")
addMiniNote(UI.Pages["FARM"], "Auto collect dropped seeds and fruits. Pet collection is in PETS / CRATES.")
addToggle(UI.Pages["FARM"], "AUTO COLLECT SEED", S.autoCollectSeed, function(v) S.autoCollectSeed = v; saveConfig(true) end)
addToggle(UI.Pages["FARM"], "AUTO COLLECT FRUITS", S.autoCollectFruit, function(v) S.autoCollectFruit = v; saveConfig(true) end)
addToggle(UI.Pages["FARM"], "TELEPORT TO ITEM", S.collectSeedTeleport, function(v) S.collectSeedTeleport = v; saveConfig(true) end)
addToggle(UI.Pages["FARM"], "RETURN TO GARDEN", S.collectSeedReturn, function(v) S.collectSeedReturn = v; saveConfig(true) end)
addSlider(UI.Pages["FARM"], "COLLECT ITEM DELAY (SEC)", 1, 30, S.collectSeedDelay, 0, function(v) S.collectSeedDelay = v; saveConfig(true) end)
addButton(UI.Pages["FARM"], "COLLECT SEEDS NOW", function()
    local n = HaimiyachGAG2_CollectDroppedSeedsStep(true)
    notify("Auto Collect Seed", tostring(n) .. " dropped seed collected", 3)
end)
addButton(UI.Pages["FARM"], "COLLECT FRUITS NOW", function()
    local n = HaimiyachGAG2_CollectDroppedFruitsStep(true)
    notify("Auto Collect Fruits", tostring(n) .. " dropped fruit collected", 3)
end)
addSection(UI.Pages["FARM"], "SHOVEL")
addToggle(UI.Pages["FARM"], "AUTO SHOVEL PLANTS", S.autoShovelPlants, function(v) S.autoShovelPlants = v end)
addDropdown(UI.Pages["FARM"], "SHOVEL PLANT TARGETS", SEED_NAMES, S.shovelPlantTargets, true, function(sel) pickMulti(sel, S.shovelPlantTargets) end)
addToggle(UI.Pages["FARM"], "AUTO SHOVEL FRUITS", S.autoShovelFruits, function(v) S.autoShovelFruits = v end)
addDropdown(UI.Pages["FARM"], "SHOVEL FRUIT TARGETS", SEED_NAMES, S.shovelFruitTargets, true, function(sel) pickMulti(sel, S.shovelFruitTargets) end)
addDropdown(UI.Pages["FARM"], "SHOVEL KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.shovelKeepMutations, true, function(sel) pickMulti(sel, S.shovelKeepMutations) end)
addDropdown(UI.Pages["FARM"], "SHOVEL WEIGHT FILTER", KG_MODE_OPTIONS, S.shovelKgMode, false, function(v) S.shovelKgMode = v end)
addSlider(UI.Pages["FARM"], "SHOVEL WEIGHT VALUE", 0, 500, S.shovelKgValue, 1, function(v) S.shovelKgValue = v end)
addSlider(UI.Pages["FARM"], "SHOVEL DELAY (SEC)", 1, 30, S.shovelDelay, 0, function(v) S.shovelDelay = v end)
addSection(UI.Pages["FARM"], "TROWEL")
addToggle(UI.Pages["FARM"], "AUTO TROWEL PLANTS", S.autoTrowelPlants, function(v) S.autoTrowelPlants = v end)
addDropdown(UI.Pages["FARM"], "TROWEL PLANT TARGETS", SEED_NAMES, S.trowelPlantTargets, true, function(sel) pickMulti(sel, S.trowelPlantTargets) end)
addDropdown(UI.Pages["FARM"], "TROWEL POSITION", { "MAPPING", "AVATAR POSITION" }, S.trowelPositionMode, false, function(v) S.trowelPositionMode = v or "MAPPING" end)
addSlider(UI.Pages["FARM"], "TROWEL DELAY (SEC)", 1, 30, S.trowelDelay, 0, function(v) S.trowelDelay = v end)
addSection(UI.Pages["FARM"], "INVENTORY FAVORITE")
addToggle(UI.Pages["FARM"], "AUTO FAVORITE FRUITS", S.autoFavoriteFruits, function(v) S.autoFavoriteFruits = v end)
addDropdown(UI.Pages["FARM"], "FAVORITE FRUIT TARGETS", SEED_NAMES, S.favoriteFruitTargets, true, function(sel) pickMulti(sel, S.favoriteFruitTargets) end)
addDropdown(UI.Pages["FARM"], "FAVORITE MUTATIONS", HaimiyachGAG2_MutationNames, S.favoriteMutations, true, function(sel) pickMulti(sel, S.favoriteMutations) end)
addDropdown(UI.Pages["FARM"], "FAVORITE WEIGHT FILTER", KG_MODE_OPTIONS, S.favoriteKgMode, false, function(v) S.favoriteKgMode = v end)
addSlider(UI.Pages["FARM"], "FAVORITE WEIGHT VALUE", 0, 500, S.favoriteKgValue, 1, function(v) S.favoriteKgValue = v end)
addToggle(UI.Pages["FARM"], "UNFAVORITE NOT MATCHING", S.unfavoriteNotMatching, function(v) S.unfavoriteNotMatching = v end)
addSlider(UI.Pages["FARM"], "FAVORITE DELAY (SEC)", 1, 30, S.favoriteDelay, 0, function(v) S.favoriteDelay = v end)
addButton(UI.Pages["FARM"], "FAVORITE INVENTORY NOW", function()
    local n = HaimiyachGAG2_AutoFavoriteStep()
    notify("Inventory Favorite", tostring(n) .. " item updated", 3)
end)

-- BOOSTS
addSection(UI.Pages["BOOSTS"], "SPRINKLER & WATER")
addToggle(UI.Pages["BOOSTS"], "AUTO PLACE SPRINKLERS", S.autoSprinkler, function(v) S.autoSprinkler = v end)
addDropdown(UI.Pages["BOOSTS"], "SELECTED SPRINKLERS", HaimiyachGAG2_SprinklerOptions(), S.sprinklerTargets, true, function(sel)
    pickMulti(sel, S.sprinklerTargets)
end)
addDropdown(UI.Pages["BOOSTS"], "SPRINKLER TARGET", { "GARDEN CENTER", "AVATAR POSITION", "MAPPING" }, S.sprinklerTargetMode, false, function(v) S.sprinklerTargetMode = v or "GARDEN CENTER" end)
addSlider(UI.Pages["BOOSTS"], "SPRINKLER DELAY (SEC)", 10, 900, S.sprinklerInterval, 0, function(v) S.sprinklerInterval = v end)
addToggle(UI.Pages["BOOSTS"], "AUTO WATERING CAN", S.autoWater, function(v) S.autoWater = v end)
addSlider(UI.Pages["BOOSTS"], "WATER DELAY (SEC)", 2, 60, S.waterInterval, 0, function(v) S.waterInterval = v end)
addSection(UI.Pages["BOOSTS"], "SKILL POINTS")
addDropdown(UI.Pages["BOOSTS"], "STATS TO LEVEL", { "BaseSpeed", "BaseJump", "ShovelPower", "MaxBackpack" }, S.skillStats, true, function(sel) pickMulti(sel, S.skillStats) end)
addToggle(UI.Pages["BOOSTS"], "AUTO SPEND SKILL POINTS", S.autoSkill, function(v) S.autoSkill = v end)


-- PETS
addSection(UI.Pages["PETS_CRATES"], "PETS")
addDropdown(UI.Pages["PETS_CRATES"], "BEST PET MODE", { "FARM", "STEAL", "PROTECT", "VALUE" }, S.bestPetMode or "FARM", false, function(v)
    S.bestPetMode = tostring(v or "FARM")
    saveConfig(true)
end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO EQUIP PETS", S.autoEquipPets, function(v) S.autoEquipPets = v end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO BUY PET SLOTS", S.autoPetSlot, function(v) S.autoPetSlot = v end)

addSection(UI.Pages["PETS_CRATES"], "DROPPED PETS")
addMiniNote(UI.Pages["PETS_CRATES"], "Auto collect dropped pets, then return to your own garden when enabled.")
addToggle(UI.Pages["PETS_CRATES"], "AUTO COLLECT PETS", S.autoCollectPet, function(v) S.autoCollectPet = v; saveConfig(true) end)
addToggle(UI.Pages["PETS_CRATES"], "TELEPORT TO PET", S.collectSeedTeleport, function(v) S.collectSeedTeleport = v; saveConfig(true) end)
addToggle(UI.Pages["PETS_CRATES"], "RETURN TO GARDEN", S.collectSeedReturn, function(v) S.collectSeedReturn = v; saveConfig(true) end)
addSlider(UI.Pages["PETS_CRATES"], "PET COLLECT DELAY (SEC)", 1, 30, S.collectSeedDelay, 0, function(v) S.collectSeedDelay = v; saveConfig(true) end)
addButton(UI.Pages["PETS_CRATES"], "COLLECT PETS NOW", function()
    local n = HaimiyachGAG2_CollectDroppedPetsStep(true)
    notify("Auto Collect Pets", tostring(n) .. " dropped pet collected", 3)
end)

addSection(UI.Pages["PETS_CRATES"], "WILD PETS")
UI.worldPetDrop = addDropdown(UI.Pages["PETS_CRATES"], "WILD PET NAME FILTER", HaimiyachGAG2_WorldPetNames(), S.buyWorldPets, true, function(sel)
    if type(S.buyWorldPets) ~= "table" then S.buyWorldPets = {} end
    pickMulti(sel, S.buyWorldPets)
    saveConfig(true)
end)
addDropdown(UI.Pages["PETS_CRATES"], "WILD PET RARITY FILTER", HaimiyachGAG2_RarityOptions, S.wildPetRarities, true, function(sel)
    if type(S.wildPetRarities) ~= "table" then S.wildPetRarities = {} end
    pickMulti(sel, S.wildPetRarities)
    saveConfig(true)
end)
addToggle(UI.Pages["PETS_CRATES"], "ONLY UNOWNED WILD PET", S.wildPetOnlyUnowned, function(v) S.wildPetOnlyUnowned = v; saveConfig(true) end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO TAME WILD PET", S.autoBuyPets, function(v) S.autoBuyPets = v; saveConfig(true) end)
addToggle(UI.Pages["PETS_CRATES"], "TELEPORT TO PET", S.petTeleport, function(v) S.petTeleport = v end)
addSlider(UI.Pages["PETS_CRATES"], "PET BUY DELAY (SEC)", 2, 60, S.petBuyInterval, 0, function(v) S.petBuyInterval = v end)
addSection(UI.Pages["PETS_CRATES"], "SELL PETS")
UI.petDrop = addDropdown(UI.Pages["PETS_CRATES"], "PETS TO SELL", ownedPetNames(), S.sellPets, true, function(sel) pickMulti(sel, S.sellPets) end)
addButton(UI.Pages["PETS_CRATES"], "REFRESH PET LIST", function() UI.petDrop.SetOptions(ownedPetNames()) end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO SELL SELECTED PETS", S.autoSellPets, function(v) S.autoSellPets = v end)

-- OPEN
addSection(UI.Pages["PETS_CRATES"], "OPEN ITEMS")
addToggle(UI.Pages["PETS_CRATES"], "AUTO OPEN EGGS", S.autoEgg, function(v) S.autoEgg = v end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO OPEN CRATES", S.autoCrate, function(v) S.autoCrate = v end)
addToggle(UI.Pages["PETS_CRATES"], "AUTO OPEN SEED PACKS", S.autoPack, function(v) S.autoPack = v end)
addSlider(UI.Pages["PETS_CRATES"], "OPEN DELAY (SEC)", 1, 30, S.openInterval, 0, function(v) S.openInterval = v end)

-- SHOP
addSection(UI.Pages["SHOP"], "SEED SHOP")
addDropdown(UI.Pages["SHOP"], "SEEDS TO BUY", SEED_NAMES, S.buySeeds, true, function(sel) pickMulti(sel, S.buySeeds) end)
addToggle(UI.Pages["SHOP"], "AUTO BUY SEEDS", S.autoBuy, function(v) S.autoBuy = v end)
addToggle(UI.Pages["SHOP"], "AUTO BUY ALL SEEDS", S.autoBuyAllSeeds, function(v) S.autoBuyAllSeeds = v end)
addSlider(UI.Pages["SHOP"], "SEED BUY DELAY (SEC)", 1, 30, S.buyInterval, 0, function(v) S.buyInterval = v end)
addSlider(UI.Pages["SHOP"], "MAX BUYS PER SEED", 1, 50, S.buyPerTick, 0, function(v) S.buyPerTick = v end)
addSection(UI.Pages["SHOP"], "GEAR SHOP")
addDropdown(UI.Pages["SHOP"], "GEAR TO BUY", GEAR_NAMES, S.gearBuy, true, function(sel) pickMulti(sel, S.gearBuy) end)
addToggle(UI.Pages["SHOP"], "AUTO BUY GEAR", S.autoGear, function(v) S.autoGear = v end)
addToggle(UI.Pages["SHOP"], "AUTO BUY ALL GEAR", S.autoBuyAllGear, function(v) S.autoBuyAllGear = v end)
addSlider(UI.Pages["SHOP"], "GEAR BUY DELAY (SEC)", 2, 60, S.gearInterval, 0, function(v) S.gearInterval = v end)

-- CRATE SHOP
addSection(UI.Pages["SHOP"], "CRATE SHOP")
UI.crateBuyDrop = addDropdown(UI.Pages["SHOP"], "CRATES TO BUY", HaimiyachGAG2_CrateNames(), S.buyCrates, true, function(sel)
    if type(S.buyCrates) ~= "table" then S.buyCrates = {} end
    pickMulti(sel, S.buyCrates)
    saveConfig(true)
end)
addButton(UI.Pages["SHOP"], "REFRESH CRATE LIST", function()
    if UI.crateBuyDrop and UI.crateBuyDrop.SetOptions then UI.crateBuyDrop.SetOptions(HaimiyachGAG2_CrateNames()) end
end)
addToggle(UI.Pages["SHOP"], "AUTO BUY SELECTED CRATES", S.autoBuyCrates, function(v)
    S.autoBuyCrates = v
    if not v then HaimiyachGAG2_HideCrateShopGui() end
    saveConfig(true)
end)
addButton(UI.Pages["SHOP"], "BUY SELECTED CRATES NOW", function()
    HaimiyachGAG2_ManualCrateBuyNow = true
    HaimiyachGAG2_BuySelectedCratesOnce()
    HaimiyachGAG2_ManualCrateBuyNow = false
end)
addSlider(UI.Pages["SHOP"], "CRATE BUY DELAY (SEC)", 2, 60, S.crateBuyDelay or 5, 0, function(v)
    S.crateBuyDelay = v
    saveConfig(true)
end)

-- STEAL
addSection(UI.Pages["STEAL"], "STEAL")
addToggle(UI.Pages["STEAL"], "AUTO STEAL RIPE FRUIT", S.autoSteal, function(v) S.autoSteal = v end)
addToggle(UI.Pages["STEAL"], "TELEPORT TO FRUIT", S.stealTeleport, function(v) S.stealTeleport = v end)
addToggle(UI.Pages["STEAL"], "RETURN TO BASE", S.stealReturnBase, function(v) S.stealReturnBase = v end)
addSlider(UI.Pages["STEAL"], "STEAL WAIT TIME (SEC)", 0, 1, S.stealDelay, 2, function(v) S.stealDelay = v end)

-- MISC
addSection(UI.Pages["SETTINGS"], "SERVER")
addToggle(UI.Pages["SETTINGS"], "ANTI AFK", S.antiAfk, function(v) S.antiAfk = v; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "AUTO SERVER HOP", S.autoHop, function(v) S.autoHop = v; saveConfig(true) end)
addDropdown(UI.Pages["SETTINGS"], "SMART HOP CONDITIONS", HaimiyachGAG2_HopConditionOptions, S.hopConditions, true, function(sel)
    if type(S.hopConditions) ~= "table" then S.hopConditions = {} end
    pickMulti(sel, S.hopConditions)
    saveConfig(true)
end)
addSlider(UI.Pages["SETTINGS"], "SERVER HOP DELAY (MIN)", 0, 120, S.hopInterval / 60, 0, function(v) S.hopInterval = v * 60; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "AUTO RECONNECT", S.autoReconnect, function(v) S.autoReconnect = v; saveConfig(true) end)
addSlider(UI.Pages["SETTINGS"], "RECONNECT DELAY (SEC)", 3, 60, S.reconnectDelay, 0, function(v) S.reconnectDelay = v; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "AUTO EXECUTE AFTER HOP", S.autoExecute, function(v)
    S.autoExecute = v
    saveConfig(true)
    if v then
        local ok, err = writeAutoExecuteLoader()
        notify("HAIMIYACH HUB", ok and "Auto execute loader saved." or ("Auto execute loader failed: " .. tostring(err)), 4)
    end
end)
addInput(UI.Pages["SETTINGS"], "LOADER URL", "raw loader url", S.autoExecuteUrl, function(text)
    S.autoExecuteUrl = tostring(text or "")
    saveConfig(true)
    if S.autoExecute then
        pcall(writeAutoExecuteLoader)
    end
end)
addSection(UI.Pages["SETTINGS"], "CODES")
addInput(UI.Pages["SETTINGS"], "REDEEM CODE", "enter code", "", function(text) S.codeText = text or "" end)
addButton(UI.Pages["SETTINGS"], "REDEEM CODE NOW", function()
    local code = S.codeText or ""
    if code ~= "" then
        local ok, res = fire("Settings.SubmitCode", code)
        notify("Code", ok and "Redeem request sent" or tostring(res or "Failed"), 3)
    end
end)
addToggle(UI.Pages["SETTINGS"], "AUTO REDEEM CODE LIST", S.autoCodes, function(v) S.autoCodes = v end)

-- ESP
addSection(UI.Pages["ESP"], "GARDEN ESP")
addMiniNote(UI.Pages["ESP"], "Turn off FPS BOOST before using ESP.")
addToggle(UI.Pages["ESP"], "ESP FRUITS", S.espGardenFruit, function(v) GardenESP.set(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "ESP GROWING FRUITS", S.espGardenGrowing, function(v) GardenESP.setGrowing(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "ESP PLANTS", S.espGardenPlant, function(v) GardenESP.setPlant(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "GARDEN VALUE", S.espGardenValue, function(v) GardenESP.setValue(v); saveConfig(true) end)

addSection(UI.Pages["ESP"], "BACKPACK ESP")
addToggle(UI.Pages["ESP"], "ESP BACKPACK FRUIT", S.espBackpackFruit, function(v) BackpackESP.set(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "BACKPACK VALUE", S.espBackpackValue, function(v) BackpackESP.setValue(v); saveConfig(true) end)
addToggle(UI.Pages["ESP"], "TOTAL VALUE", S.espBackpackTotal, function(v) BackpackESP.setTotal(v); saveConfig(true) end)

addSection(UI.Pages["ESP"], "WILD PET ESP")
addDropdown(UI.Pages["ESP"], "WILD PET DETAILS", HaimiyachGAG2_WildPetDetailOptions, S.espWildPetDetails, true, function(sel)
    if type(S.espWildPetDetails) ~= "table" then S.espWildPetDetails = {} end
    pickMulti(sel, S.espWildPetDetails)
    saveConfig(true)
end)
addToggle(UI.Pages["ESP"], "WILD PET ESP", S.espWildPet, function(v)
    S.espWildPet = v
    if not v then HaimiyachGAG2_ClearWildPetESP() end
    saveConfig(true)
end)

-- PROTECT
addSection(UI.Pages["PROTECT"], "AVATAR PROTECTION")
addToggle(UI.Pages["PROTECT"], "NO CLIP", S.protectNoClip, function(v) S.protectNoClip = v end)
addToggle(UI.Pages["PROTECT"], "ANTI FLING", S.protectAntiFling, function(v) S.protectAntiFling = v end)
addToggle(UI.Pages["PROTECT"], "ANTI RAGDOLL", S.protectAntiRagdoll, function(v) S.protectAntiRagdoll = v end)
addToggle(UI.Pages["PROTECT"], "ANTI KNOCKBACK", S.protectAntiKnockback, function(v) S.protectAntiKnockback = v end)
addToggle(UI.Pages["PROTECT"], "ANTI SIT", S.protectAntiSit, function(v) S.protectAntiSit = v end)
addToggle(UI.Pages["PROTECT"], "ANTI VOID", S.protectAntiVoid, function(v) S.protectAntiVoid = v end)
addSlider(UI.Pages["PROTECT"], "VELOCITY LIMIT", 25, 250, S.protectVelocityLimit, 0, function(v) S.protectVelocityLimit = v end)
addSlider(UI.Pages["PROTECT"], "VOID HEIGHT", -150, 0, S.protectVoidY, 0, function(v) S.protectVoidY = v end)
addButton(UI.Pages["PROTECT"], "RESET CHARACTER VELOCITY NOW", function()
    local n = HaimiyachGAG2_ResetOwnVelocity(false)
    notify("Protect", "Velocity reset on " .. tostring(n) .. " parts.", 3)
end)


-- MAILBOX
addSection(UI.Pages["MAILBOX"], "AUTO CLAIM MAIL / GIFT")
addToggle(UI.Pages["MAILBOX"], "AUTO CLAIM MAILBOX", S.autoMail, function(v) S.autoMail = v; saveConfig(true) end)
addToggle(UI.Pages["MAILBOX"], "AUTO ACCEPT GIFTS", S.autoAcceptGift, function(v) S.autoAcceptGift = v; saveConfig(true) end)
addSection(UI.Pages["MAILBOX"], "SEND MAIL BY USERNAME")
addInput(UI.Pages["MAILBOX"], "MAIL TARGET USERNAME", "username", S.mailTargetUsername or "", function(v)
    S.mailTargetUsername = tostring(v or "")
    saveConfig(true)
end)
addInput(UI.Pages["MAILBOX"], "MAIL NOTE", "optional note", S.mailNote or "", function(v)
    S.mailNote = tostring(v or "")
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "SEEDS TO SEND", SEED_NAMES, S.mailSeedTargets, true, function(sel)
    if type(S.mailSeedTargets) ~= "table" then S.mailSeedTargets = {} end
    pickMulti(sel, S.mailSeedTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "FRUITS TO SEND", SEED_NAMES, S.mailFruitTargets, true, function(sel)
    if type(S.mailFruitTargets) ~= "table" then S.mailFruitTargets = {} end
    pickMulti(sel, S.mailFruitTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "GEAR TO SEND", HaimiyachGAG2_MailGearOptionNames(), S.mailGearTargets, true, function(sel)
    if type(S.mailGearTargets) ~= "table" then S.mailGearTargets = {} end
    pickMulti(sel, S.mailGearTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "PETS TO SEND", HaimiyachGAG2_WorldPetNames(), S.mailPetTargets, true, function(sel)
    if type(S.mailPetTargets) ~= "table" then S.mailPetTargets = {} end
    pickMulti(sel, S.mailPetTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "CRATES TO SEND", HaimiyachGAG2_CrateNames(), S.mailCrateTargets, true, function(sel)
    if type(S.mailCrateTargets) ~= "table" then S.mailCrateTargets = {} end
    pickMulti(sel, S.mailCrateTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "SEED PACKS TO SEND", HaimiyachGAG2_SeedPackNames(), S.mailSeedPackTargets, true, function(sel)
    if type(S.mailSeedPackTargets) ~= "table" then S.mailSeedPackTargets = {} end
    pickMulti(sel, S.mailSeedPackTargets)
    saveConfig(true)
end)
addDropdown(UI.Pages["MAILBOX"], "PROPS TO SEND", HaimiyachGAG2_PropNames(), S.mailPropTargets, true, function(sel)
    if type(S.mailPropTargets) ~= "table" then S.mailPropTargets = {} end
    pickMulti(sel, S.mailPropTargets)
    saveConfig(true)
end)
addSlider(UI.Pages["MAILBOX"], "MAIL COUNT PER ITEM", 1, 20, S.mailSendCount, 0, function(v)
    S.mailSendCount = v
    saveConfig(true)
end)
addSlider(UI.Pages["MAILBOX"], "MAIL SEND DELAY (SEC)", 5, 300, S.mailSendDelay, 0, function(v)
    S.mailSendDelay = v
    saveConfig(true)
end)
addButton(UI.Pages["MAILBOX"], "SEND SELECTED MAIL NOW", function()
    HaimiyachGAG2_SendSelectedMailNow(true)
end)
addToggle(UI.Pages["MAILBOX"], "AUTO SEND SELECTED MAIL", S.autoSendMail, function(v)
    S.autoSendMail = v
    saveConfig(true)
end)

-- VISUALS
addSection(UI.Pages["VISUALS"], "PERFORMANCE")
UI.visualPerfLabel = addLabel(UI.Pages["VISUALS"], "FPS: ?\nPING: ?")
addToggle(UI.Pages["VISUALS"], "BLACK SCREEN", S.blankScreen, function(v)
    SetBlankScreenEnabled(v)
    saveConfig(true)
end)
addDropdown(UI.Pages["VISUALS"], "FPS BOOST MODE", { "LIGHT", "BALANCED", "ULTRA" }, S.fpsBoostMode or "BALANCED", false, function(v)
    S.fpsBoostMode = NormalizeFPSBoostMode(v)
    if S.fpsBoost then SetFPSBoostEnabled(true) end
    saveConfig(true)
end)
UI.fpsBoostToggle = nil
UI.highGraphicsToggle = nil
UI.fpsBoostToggle = addToggle(UI.Pages["VISUALS"], "FPS BOOST", S.fpsBoost, function(v)
    S.fpsBoost = v
    SetFPSBoostEnabled(v)
    if v and UI.highGraphicsToggle then
        UI.highGraphicsToggle.Set(false, false)
    end
end)
UI.highGraphicsToggle = addToggle(UI.Pages["VISUALS"], "HIGH GRAPHICS", S.highGraphics, function(v)
    S.highGraphics = v
    SetHighGraphicsEnabled(v)
    if v and UI.fpsBoostToggle then
        UI.fpsBoostToggle.Set(false, false)
    end
end)

addSection(UI.Pages["VISUALS"], "CUTSCENE")
addToggle(UI.Pages["VISUALS"], "DISABLE CUTSCENE", S.disableCutscene, function(v) SetCutsceneDisabled(v); saveConfig(true) end)

if S.fpsBoost then SetFPSBoostEnabled(true) end
if S.highGraphics then SetHighGraphicsEnabled(true) end
if S.blankScreen then SetBlankScreenEnabled(true) end
if S.espGardenFruit then GardenESP.set(true) end
if S.espGardenGrowing then GardenESP.setGrowing(true) end
if S.espGardenPlant then GardenESP.setPlant(true) end
if S.espBackpackFruit then BackpackESP.set(true) end
if S.espBackpackTotal then BackpackESP.setTotal(true) end
if S.espWildPet then HaimiyachGAG2_UpdateWildPetESP() end

-- SETTINGS
addSection(UI.Pages["SETTINGS"], "UI")
addSlider(UI.Pages["SETTINGS"], "UI SCALE", 0.6, 1.4, UI.Scale, 2, function(v)
    UI.Scale = v
    S.uiScale = v
    UIScaleObj.Scale = v
    if UI.Minimized then
        MiniBar.Size = UDim2.fromOffset(math.floor((390 * UI.Scale) + 0.5), math.floor((44 * UI.Scale) + 0.5))
    end
end)
addSection(UI.Pages["SETTINGS"], "WINDOW")
addDropdown(UI.Pages["SETTINGS"], "UI KEYBIND", { "LeftControl", "RightControl", "LeftAlt", "RightAlt", "RightShift", "K", "F" }, S.uiKeybindName or "LeftControl", false, function(v)
    S.uiKeybindName = tostring(v or "LeftControl")
    local kc = Enum.KeyCode[S.uiKeybindName]
    if kc then UI.Keybind = kc end
end)
addButton(UI.Pages["SETTINGS"], "MINIMIZE UI", function() setMinimized(true) end)
addButton(UI.Pages["SETTINGS"], "HIDE UI", function() setVisible(false) end)
addButton(UI.Pages["SETTINGS"], "RESET UI SETTINGS", function()
    UI.Scale = isMobile and 0.88 or 1
    S.uiScale = UI.Scale
    S.uiKeybindName = "LeftControl"
    UI.Keybind = Enum.KeyCode.LeftControl
    UIScaleObj.Scale = UI.Scale
    setMinimized(false)
    Main.Position = UDim2.new(0.5, -baseW/2, 0.5, -baseH/2)
end)
addSection(UI.Pages["SETTINGS"], "CONFIG")
addButton(UI.Pages["SETTINGS"], "SAVE CONFIG", function() saveConfig(false) end)
addButton(UI.Pages["SETTINGS"], "LOAD CONFIG", function() loadConfig(false) end)
addSection(UI.Pages["SETTINGS"], "WEBHOOK")
addInput(UI.Pages["SETTINGS"], "WEBHOOK URL", "https://discord.com/api/webhooks/...", S.webhookUrl, function(text) S.webhookUrl = text or ""; saveConfig(true) end)
addToggle(UI.Pages["SETTINGS"], "ENABLE REPORTS", S.webhookEnabled, function(v)
    S.webhookEnabled = v
    saveConfig(true)
    if v then task.spawn(function() task.wait(0.5); sendWebhook(false) end) end
end)
addToggle(UI.Pages["SETTINGS"], "DISCONNECT WEBHOOK", S.webhookDisconnect, function(v) S.webhookDisconnect = v; saveConfig(true) end)
addSlider(UI.Pages["SETTINGS"], "REPORT DELAY (MIN)", 1, 60, S.webhookInterval / 60, 0, function(v) S.webhookInterval = v * 60; saveConfig(true) end)
addButton(UI.Pages["SETTINGS"], "SEND TEST REPORT", function() task.spawn(function() sendWebhook(true) end) end)
addButton(UI.Pages["SETTINGS"], "SEND DISCONNECT TEST", function()
    task.spawn(function()
        DisconnectWebhookSent = false
        sendDisconnectWebhook("TEST DISCONNECT", "Manual test from HAIMIYACH HUB settings.", true)
    end)
end)
addButton(UI.Pages["SETTINGS"], "UNLOAD HUB", function()
    S.killed = true
    UI.Unloaded = true
    pcall(function() SetCutsceneDisabled(false, true) end)
    pcall(RestoreDefaultGraphics)
    pcall(HaimiyachGAG2_ClearWildPetESP)
    if fpsConnection then pcall(function() fpsConnection:Disconnect() end) end
    disconnectUiConnections()
    cleanContainer(PlayerGui)
    cleanContainer(CoreGui)
end)

-- AUTO CLAIM SEED EVENT loop
loopOn(function() return S.autoClaimSeedEvent end, function() return math.max(3, tonumber(S.seedEventDelay) or 3) end, function()
    claimSeedEvent()
end)

-- AUTO COLLECT DROPPED ITEM loop (normal dropped seeds/fruits/pets, not Seed Event)
loopOn(function() return S.autoCollectSeed or S.autoCollectFruit or S.autoCollectPet end, function() return math.max(1, tonumber(S.collectSeedDelay) or 1) end, function()
    HaimiyachGAG2_CollectDroppedEnabledStep()
end)

-- AUTO POT loop (own grown plants flagged via prompt tag is rare; pot all listed plants)
loopOn(function() return S.autoPot end, 10, function()
    local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return end
    for _, m in ipairs(plants:GetChildren()) do
        if not S.autoPot then break end
        local pid = m:GetAttribute("PlantId") or m.Name
        if pid then fire("Garden.PotPlant", tostring(pid)); task.wait(0.3) end
    end
end)

local function getPriceRefreshText()
    local ok, txt = pcall(function()
        if GardenESP and type(GardenESP.ensureFruitStock) == "function" then
            GardenESP.ensureFruitStock()
        end
        local nextRefresh = GardenESP and tonumber(GardenESP.stockNextRefreshUnix) or 0
        if not nextRefresh or nextRefresh <= 0 then return "?" end
        local serverNow = os.time() + (tonumber(GardenESP.stockServerOffset) or 0)
        local remain = math.max(0, math.floor(nextRefresh - serverNow))
        return string.format("%dm %02ds", math.floor(remain / 60), remain % 60)
    end)
    return ok and tostring(txt or "?") or "?"
end

local function getBackpackTotalText()
    local ok, data = pcall(function()
        return BackpackESP and BackpackESP.collectItems and BackpackESP.collectItems()
    end)
    if ok and data and tonumber(data.total) then
        return BackpackESP.money(data.total) .. " S"
    end
    return "?"
end

-- live status
function UI.SafeSetText(lbl, txt)
    pcall(function() if lbl and lbl.Parent then lbl.Text = txt end end)
end
task.spawn(function()
    while not S.killed do
        local p = myPlot()
        UI.SafeSetText(UI.systemStatusLabel, HaimiyachGAG2_DashboardSystemText())
        UI.SafeSetText(UI.plotLabel, string.format("GARDEN: %s | VALUE: %s\nSHECKLES: %s | TOKENS: %s", tostring(p and p.Name or "?"), getBackpackTotalText(), fmt(getSheckles()), fmt(getTokens())))
        UI.SafeSetText(UI.afkStatusLabel, antiAfkDashboardText())
        UI.SafeSetText(UI.featureFarmLabel, HaimiyachGAG2_DashboardFeatureFarmText())
        UI.SafeSetText(UI.featureCollectLabel, HaimiyachGAG2_DashboardFeatureCollectText())
        UI.SafeSetText(UI.featureShopLabel, HaimiyachGAG2_DashboardFeatureShopText())
        UI.SafeSetText(UI.featureUtilityLabel, HaimiyachGAG2_DashboardFeatureUtilityText())
        UI.SafeSetText(UI.reportBuyLabel, HaimiyachGAG2_DashboardReportBuyText())
        UI.SafeSetText(UI.reportCollectLabel, HaimiyachGAG2_DashboardReportCollectText())
        UI.SafeSetText(UI.reportExtraLabel, string.format("PLANTED: %d | HARVESTED: %d | WATERED: %d\nTAMED: %d | STOLEN: %d | CODES: %d", tonumber(Stats.planted) or 0, tonumber(Stats.harvested) or 0, tonumber(Stats.watered) or 0, tonumber(Stats.tamed) or 0, tonumber(Stats.stolen) or 0, tonumber(Stats.codes) or 0))
        UI.SafeSetText(UI.lastActionLabel, HaimiyachGAG2_DashboardLastActionText())
        UI.SafeSetText(UI.lastEventLabel, "EVENT READY: " .. getSeedEventAvailableText() .. "\nCLAIMED: " .. getSeedEventClaimText() .. " | LAST: " .. getSeedEventLastText())
        UI.SafeSetText(UI.warningStatusLabel, HaimiyachGAG2_DashboardWarningText())
        UI.SafeSetText(UI.warningDetailLabel, HaimiyachGAG2_DashboardWarningDetailText())
        if UI.restockNextLabel then UI.SafeSetText(UI.restockNextLabel, "NEXT RESTOCK: " .. HaimiyachGAG2_SeedRestockText()) end
        if UI.restockPredictionLabel then UI.SafeSetText(UI.restockPredictionLabel, "NEXT SEED PREDICTION:\n" .. HaimiyachGAG2_RestockPredictionText()) end
        if UI.restockTargetLabel then UI.SafeSetText(UI.restockTargetLabel, "TARGET STATUS: " .. HaimiyachGAG2_RestockTargetText()) end
        if UI.restockRecentLabel then UI.SafeSetText(UI.restockRecentLabel, "RECENT RARE SEEDS:\n" .. HaimiyachGAG2_RestockRecentText()) end
        UI.SafeSetText(UI.wildPetDashLabel, "WILD PET FOUND: " .. HaimiyachGAG2_BestWildPetText())
        UI.SafeSetText(UI.nextHopLabel, "NEXT SERVER HOP: " .. HaimiyachGAG2_NextHopText())
        if UI.activeWeatherLabel then UI.SafeSetText(UI.activeWeatherLabel, "ACTIVE WEATHER: " .. HaimiyachGAG2_ActiveWeatherText(false)) end
        if UI.weatherTimeLabel then UI.SafeSetText(UI.weatherTimeLabel, "WEATHER TIME LEFT: " .. HaimiyachGAG2_WeatherTimeText()) end
        if UI.weatherMachineLabel then
            local wm = HaimiyachGAG2_WeatherMachineInfo()
            UI.SafeSetText(UI.weatherMachineLabel, "WEATHER MACHINE: " .. tostring(wm.progress) .. " | COOLDOWN " .. tostring(wm.cooldown) .. " | PLAYERS " .. tostring(wm.active))
        end
        UI.SafeSetText(UI.visualPerfLabel, string.format("FPS: %s\nPING: %s", tostring(currentFps), getPingText()))
        task.wait(1)
    end
end)

pcall(function()
    if getgenv then getgenv().HaimiyachGAG2 = {
        S = S, Stats = Stats, Net = Net, fire = fire, action = action,
        catalog = CATALOG, gearNames = GEAR_NAMES, myPlot = myPlot, replica = replica,
        ripeHarvests = ripeHarvests, stealable = stealable, wildPets = wildPets,
        claimSeedEvent = claimSeedEvent, collectDroppedSeeds = HaimiyachGAG2_CollectDroppedSeedsStep, collectDroppedFruits = HaimiyachGAG2_CollectDroppedFruitsStep, collectDroppedPets = HaimiyachGAG2_CollectDroppedPetsStep, collectDroppedItems = HaimiyachGAG2_CollectDroppedEnabledStep, flyToPosition = flyToPosition, SetCutsceneDisabled = SetCutsceneDisabled,
        toolsByAttr = toolsByAttr, plantGrid = plantGrid, ownedPetNames = ownedPetNames, myBasePos = myBasePos,
        stepHarvest = stepHarvest, fireFast = fireFast, fruitCount = fruitCount, sellAllNow = sellAllNow, maxFruitCap = maxFruitCap,
        activeWeather = HaimiyachGAG2_ActiveWeatherRows, wildPetEsp = HaimiyachGAG2_UpdateWildPetESP,
        restockPrediction = HaimiyachGAG2_RestockPredictionRows, restockHistory = HaimiyachGAG2_RestockHistory,
        bestPets = HaimiyachGAG2_BestOwnedPetNames, shouldHop = HaimiyachGAG2_ShouldHopNow,
        unload = function()
            S.killed = true
            UI.Unloaded = true
            pcall(function() SetCutsceneDisabled(false, true) end)
            pcall(RestoreDefaultGraphics)
            pcall(function() GardenESP.set(false) end)
            pcall(GardenESP.clear)
            pcall(function() BackpackESP.set(false) end)
            pcall(BackpackESP.clear)
            pcall(HaimiyachGAG2_ClearWildPetESP)
            if fpsConnection then pcall(function() fpsConnection:Disconnect() end) end
            disconnectUiConnections()
            cleanContainer(PlayerGui)
            cleanContainer(CoreGui)
        end,
    } end
end)

selectTab("DASHBOARD")
setVisible(true)
notify("HAIMIYACH HUB", "has loaded successfully.", 3)
print("[HAIMIYACH HUB] Grow a Garden 2 custom GUI loaded.")
end

HaimiyachGAG2_StartUI()
