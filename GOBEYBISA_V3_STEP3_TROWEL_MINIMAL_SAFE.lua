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
    autoPlant = false, plantSpacing = 4, plantSeed = "Best owned", plantSeeds = { ["BEST OWNED"] = true },
    autoHarvest = false, harvestAll = true, harvestFruitTargets = {}, harvestKeepMutations = {}, harvestMaxKg = 0, harvestKgMode = "OFF", harvestKgValue = 0, harvestInterval = 2, harvestDelay = 0.01,
    autoSell = false, sellInterval = 15, sellKeepMutations = {}, sellKeepKgMode = "OFF", sellKeepKgValue = 0,
    autoExpand = false, autoPot = false, autoDaily = false, dailyDelay = 60,
    autoClaimSeedEvent = false, claimUseFly = false, seedEventDelay = 3,
    autoShovelPlants = false, autoShovelFruits = false, shovelPlantTargets = {}, shovelFruitTargets = {}, shovelKeepMutations = {}, shovelMaxKg = 0, shovelKgMode = "OFF", shovelKgValue = 0, shovelNameFilter = "", shovelDelay = 2,
    autoFavoriteFruits = false, favoriteFruitTargets = {}, favoriteMutations = {}, favoriteFruitFilter = "", favoriteMinKg = 0, favoriteMaxKg = 0, favoriteKgMode = "OFF", favoriteKgValue = 0, favoriteMutationFilter = "", unfavoriteNotMatching = false, favoriteDelay = 3,
    -- boosts
    autoSprinkler = false, sprinklerInterval = 30, sprinklerTargetMode = "GARDEN CENTER", sprinklerTargets = {},
    autoWater = false, waterInterval = 8,
    autoTrowelPlants = false, trowelPlantTargets = {}, trowelPositionMode = "MAPPING", trowelDelay = 3,
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
    codeText = "", autoCodes = false, antiAfk = true, disableCutscene = false,
    -- perf / webhook
    fpsBoost = false, highGraphics = false,
    webhookEnabled = false, webhookUrl = "", webhookInterval = 300,
    webhookDisconnect = false,
    -- esp
    espGardenFruit = false, espGardenGrowing = false, espGardenValue = false,
    espBackpackFruit = false, espBackpackValue = false, espBackpackTotal = false,
    -- config / auto execute
    autoExecute = false, autoExecuteUrl = "",
    uiScale = 0,
    uiKeybindName = "LeftControl",
    killed = false,
}
local Stats = { bought = 0, seedBought = 0, gearBought = 0, sprinklerBought = 0, planted = 0, harvested = 0, sold = 0, earned = 0,
    sprinklers = 0, watered = 0, tamed = 0, opened = 0, stolen = 0, codes = 0,
    purchaseSeeds = {}, purchaseGear = {}, purchaseSprinklers = {},
    lastSeedBuy = "NONE", lastGearBuy = "NONE", lastSprinklerBuy = "NONE",
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
    end
end


-- // ============================================================ \ --
-- //                    CONFIG / AUTO EXECUTE                     \ --
-- // ============================================================ \ --
local CONFIG_DIR = "HaimiyachHub"
local CONFIG_FILE = CONFIG_DIR .. "/GAG2H_Config.json"
local CONFIG_KEYS = {
    "autoFarm", "autoBuy", "autoBuyAllSeeds", "buySeeds", "buyInterval", "buyPerTick",
    "autoPlant", "plantSpacing", "plantSeed", "plantSeeds", "autoHarvest", "harvestAll", "harvestFruitTargets", "harvestKeepMutations", "harvestMaxKg", "harvestKgMode", "harvestKgValue", "harvestInterval", "harvestDelay",
    "autoSell", "sellInterval", "sellKeepMutations", "sellKeepKgMode", "sellKeepKgValue", "autoExpand", "autoPot", "autoDaily", "dailyDelay",
    "autoClaimSeedEvent", "claimUseFly", "seedEventDelay", "autoShovelPlants", "autoShovelFruits", "shovelPlantTargets", "shovelFruitTargets", "shovelKeepMutations", "shovelMaxKg", "shovelKgMode", "shovelKgValue", "shovelNameFilter", "shovelDelay",
    "autoFavoriteFruits", "favoriteFruitTargets", "favoriteMutations", "favoriteFruitFilter", "favoriteMinKg", "favoriteMaxKg", "favoriteKgMode", "favoriteKgValue", "favoriteMutationFilter", "unfavoriteNotMatching", "favoriteDelay",
    "autoSprinkler", "sprinklerInterval", "sprinklerTargetMode", "sprinklerTargets", "autoWater", "waterInterval", "autoTrowelPlants", "trowelPlantTargets", "trowelPositionMode", "trowelDelay", "autoSkill", "skillStats",
    "autoEquipPets", "autoPetSlot", "autoBuyPets", "maxPetPrice", "petTeleport", "petBuyInterval",
    "sellPets", "autoSellPets", "autoEgg", "autoCrate", "autoPack", "openInterval",
    "autoGear", "autoBuyAllGear", "gearBuy", "gearInterval", "autoSteal", "stealTeleport", "stealReturnBase", "stealDelay",
    "autoMail", "autoAcceptGift", "autoHop", "hopInterval", "codeText", "autoCodes", "antiAfk", "disableCutscene",
    "fpsBoost", "highGraphics", "webhookEnabled", "webhookUrl", "webhookInterval", "webhookDisconnect",
    "espGardenFruit", "espGardenGrowing", "espGardenValue", "espBackpackFruit", "espBackpackValue", "espBackpackTotal", "autoExecute", "autoExecuteUrl", "uiScale", "uiKeybindName"
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
local AUTO_MAIN_FILE = CONFIG_DIR .. "/GOBEYBISA_Main.lua"
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
-- //                       GARDEN FRUIT ESP LITE                  \ --
-- // ============================================================ \ --
local GardenESP = {
    running = false,
    labels = {},
    singleHarvest = {},
    modulesReady = false,
    visualizer = nil,
    gardenSync = nil,
    valueCalc = nil,
    overtimeCalc = nil,
    mutationData = nil,
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

    if GardenESP.singleHarvest[name] == true then return true end

    -- Fallback for plants like Bamboo if SeedData has not replicated yet:
    -- single-harvest plants usually do not keep real fruit models inside their Fruits folder.
    local fruits = model:FindFirstChild("Fruits")
    if not fruits then return true end
    for _, child in ipairs(fruits:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("FruitId") ~= nil then
            return false
        end
    end
    return true
end

function GardenESP.isFruit(model)
    if not (model and model:IsA("Model")) then return false end
    if not GardenESP.name(model) then return false end

    -- Single-harvest crops like Bamboo are the plant model itself, not a child fruit model.
    if GardenESP.isSingleHarvestPlant(model) then return true end

    -- Do not show parent plant models for multi-harvest crops, because their child Fruits are shown instead.
    if model:GetAttribute("FruitId") == nil and model.Parent and model.Parent.Name == "Plants" then
        return false
    end

    if model:GetAttribute("FruitId") ~= nil then return true end
    if model:FindFirstChild("HarvestPart", true) ~= nil then return true end
    if GardenESP.hasTag(model, "Harvestable") or GardenESP.hasTag(model, "Growable") then return true end
    local age = tonumber(model:GetAttribute("Age"))
    local maxAge = tonumber(model:GetAttribute("MaxAge"))
    return age ~= nil and maxAge ~= nil and maxAge > 0
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
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "HaimiyachGardenFruitESP" then obj:Destroy() end
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
        if ok and tonumber(value) then return tonumber(value) end
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
    return value
end

function GardenESP.make(parent)
    local mobile = GardenESP.mobile()
    local gui = Instance.new("BillboardGui")
    gui.Name = "HaimiyachGardenFruitESP"
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = GardenESP.maxDistance()
    gui.StudsOffset = Vector3.new(0, 1.15, 0)
    gui.Size = UDim2.fromOffset(mobile and 96 or 118, mobile and 25 or 29)
    gui.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BackgroundTransparency = 0.45
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(255, 245, 170)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = mobile and 8 or 10
    label.TextWrapped = true
    label.TextScaled = false
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextXAlignment = Enum.TextXAlignment.Center
    pcall(function() label.TextTruncate = Enum.TextTruncate.None end)
    label.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = label

    return gui
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
                    or inst:GetAttribute("CorePartName") ~= nil
                    or inst:GetAttribute("SeedName") ~= nil
                    or inst:GetAttribute("FruitName") ~= nil
                    or inst:GetAttribute("Fruit") ~= nil
                    or (inst.Parent and inst.Parent.Name == "Fruits")
                    or inst:FindFirstChild("HarvestPart", true) ~= nil then
                    add(inst)
                end
            end
        end
    end
    return out
end

function GardenESP.update()
    GardenESP.initModules()
    if not S.espGardenFruit and not S.espGardenGrowing then return end
    local alive = {}
    local anchor = GardenESP.anchorPosition()
    local maxDistance = GardenESP.maxDistance()
    local candidates = {}

    for _, model in ipairs(GardenESP.scan()) do
        local gardensRoot = Workspace:FindFirstChild("Gardens")
        if gardensRoot and model:IsDescendantOf(gardensRoot) and GardenESP.isFruit(model) then
            local ready = GardenESP.ready(model)
            local shouldShow = (ready and S.espGardenFruit) or ((not ready) and S.espGardenGrowing)
            local hp = shouldShow and GardenESP.part(model) or nil
            if hp and hp.Parent then
                local dist = 0
                if anchor then dist = (hp.Position - anchor).Magnitude end
                if (not anchor) or dist <= maxDistance then
                    candidates[#candidates + 1] = { model = model, part = hp, distance = dist, ready = ready }
                end
            end
        end
    end

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

            local name = GardenESP.name(model) or "Fruit"
            local sm = tonumber(model:GetAttribute("SizeMulti") or model:GetAttribute("SizeMultiplier") or 1) or 1
            local status = GardenESP.status(model)
            local title = tostring(name)
            if status ~= "READY" then title = title .. " " .. status end
            local bottom = GardenESP.weightText(model, sm)
            if S.espGardenValue then
                local value = GardenESP.valueFor(model, name, sm)
                if value then bottom = bottom .. " | " .. GardenESP.money(value) .. "¢" end
            end

            local label = gui:FindFirstChild("Text")
            if label then label.Text = title .. "\n" .. bottom end
        end
    end

    for model, gui in pairs(GardenESP.labels) do
        if not alive[model] or not model.Parent or (not S.espGardenFruit and not S.espGardenGrowing) then
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
            if S.espGardenFruit or S.espGardenGrowing then
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
    elseif not S.espGardenGrowing then
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
    elseif not S.espGardenFruit then
        pcall(GardenESP.clear)
    else
        pcall(GardenESP.update)
    end
end

function GardenESP.setValue(state)
    S.espGardenValue = state and true or false
    if S.espGardenFruit or S.espGardenGrowing then pcall(GardenESP.update) end
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
        if ok and tonumber(value) then return tonumber(value) end
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
    if value < 1 then value = 1 end
    return value
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
    local label = inv:FindFirstChild("HaimiyachBackpackTotalESP")
    if label and label:IsA("TextLabel") then return label end
    label = Instance.new("TextLabel")
    label.Name = "HaimiyachBackpackTotalESP"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(255, 245, 170)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.05
    label.Font = Enum.Font.GothamBlack
    label.TextSize = BackpackESP.mobile() and 18 or 22
    label.TextScaled = false
    label.TextWrapped = false
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 90
    label.Size = UDim2.new(0, BackpackESP.mobile() and 230 or 260, 0, 34)
    label.Position = UDim2.new(0, BackpackESP.mobile() and 185 or 220, 0, 4)
    label.Parent = inv
    return label
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
        if total then total.Text = "Total Value: " .. BackpackESP.money(data.total) .. "¢" end
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
            text = BackpackESP.money(value) .. "¢"
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

-- // ============================================================ \ --
-- //                    INVENTORY FAVORITE                        \ --
-- // ============================================================ \ --
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

-- // ============================================================ \\ --
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
                local okBuy = fire("SeedShop.PurchaseSeed", s.name)
                if not okBuy then break end
                Stats.TrackPurchase("Seed", s.name, 1); bought = bought + 1
                if stock ~= nil then stock = stock - 1 end
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
-- Instant steal: for HoldDuration==0 prompts the game fires BeginSteal+CompleteSteal
-- back-to-back (no hold). Server-side steal is proximity-gated like the prompt, so
-- teleport to the fruit unless disabled.
local function hrpNow() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
loopOn(function() return S.autoSteal end, 1.5, function()
    if not isNight() then return end
    for _, f in ipairs(stealable()) do
        if not (S.autoSteal and isNight()) then break end
        -- 1) go to the fruit (proximity is server-gated) and steal it
        if S.stealTeleport and f.pos then
            local hrp = hrpNow(); if hrp then hrp.CFrame = CFrame.new(f.pos + Vector3.new(0, 4, 0)); task.wait(0.4) end
        end
        fire("Steal.BeginSteal", f.owner, f.plantId, f.fruitId)
        fire("Steal.CompleteSteal")
        Stats.stolen = Stats.stolen + 1
        -- 2) carry it home: standing in own garden zone banks it (CarryingStolenFruit clears)
        if S.stealReturnBase then
            local base = myBasePos()
            local hrp = hrpNow()
            if base and hrp then
                hrp.CFrame = CFrame.new(base + Vector3.new(0, 4, 0))
                local t0 = os.clock()
                while LocalPlayer:GetAttribute("CarryingStolenFruit") and os.clock() - t0 < 3 and S.autoSteal do task.wait(0.15) end
            end
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
            elseif os.clock() >= nextHopAt then
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
                fire("AntiAfk.RequestHop")
                nextHopAt = os.clock() + delaySec
            end
        else
            nextHopAt = nil
        end
        task.wait(0.5)
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

function HaimiyachGAG2_ReportClean(text)
    text = tostring(text or "-")
    text = text:gsub("·", "|")
    text = text:gsub("✅", "OK")
    text = text:gsub("❌", "NO")
    text = text:gsub("⚠️", "WARNING")
    text = text:gsub("🌱", "")
    text = text:gsub("💰", "")
    text = text:gsub("🪙", "")
    text = text:gsub("📊", "")
    text = text:gsub("✨", "")
    text = text:gsub("⏱️", "")
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
    if force then notify("Webhook", good and "Disconnect test sent" or ("Failed (" .. tostring(code or "request") .. ")"), 4) end
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

local guiParent = CoreGui or PlayerGui
local ScreenGui = new("ScreenGui", {
    Name = "Haimiyach_GAG2_Custom_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999995,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)

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
local baseH = 350

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
    Name = "TopTabBar",
    Size = UDim2.new(1, -24, 0, 46),
    Position = UDim2.fromOffset(12, 56),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.X,
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    CanvasSize = UDim2.fromOffset(0,0),
    ClipsDescendants = true,
}, Main)
corner(TabBar, 12); stroke(TabBar, Color3.fromRGB(80,80,80), 1, 0.72); pad(TabBar, 8, 8, 6, 6)
local TabLayout = new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, TabBar)

local Content = new("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -24, 1, -116),
    Position = UDim2.fromOffset(12, 108),
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
    Size = UDim2.fromOffset(isMobile and 148 or 168, isMobile and 32 or 34),
    Position = UDim2.new(0.5, 0, 0, isMobile and 10 or 14),
    BackgroundColor3 = Color3.fromRGB(35,35,35),
    BackgroundTransparency = 0.88,
    TextTransparency = 0.32,
    Text = "HAIMIYACH HUB",
    TextColor3 = T.Text,
    Font = Enum.Font.GothamBlack,
    TextSize = isMobile and 12 or 13,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
    Visible = false,
    ZIndex = 999,
}, ShowGui)
corner(ShowButton, 20)

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
    -- Fixed tab widths/order are used so FARM and the other top buttons match the original HAIMIYACH HUB style.
    local TabWidths = {
        ["DASHBOARD"] = 128,
        ["FARM"] = 106,
        ["AUTO"] = 104,
        ["BOOSTS"] = 108,
        ["PETS"] = 104,
        ["OPEN"] = 104,
        ["SHOP"] = 104,
        ["STEAL"] = 104,
        ["MISC"] = 104,
        ["VISUALS"] = 108,
        ["SETTINGS"] = 120,
    }
    local w = TabWidths[name] or math.clamp((#name * 8) + 58, 96, 136)
    local btn = new("TextButton", {
        Name = "Tab_" .. name,
        Size = UDim2.fromOffset(w, 34),
        BackgroundColor3 = T.Row,
        Text = cleanUiText(name),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        BorderSizePixel = 0,
        LayoutOrder = order or 99,
        AutoButtonColor = true,
    }, TabBar)
    corner(btn, 18)
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
    pad(page, 4, 10, 2, 10)
    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    trackConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() refreshCanvas(page) end))
    UI.Pages[name] = page
    trackConnection(btn.Activated:Connect(function() selectTab(name) end))
    return page
end

local function addSection(page, text)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = cleanUiText(text),
        TextColor3 = T.Muted,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
    return lbl
end

local function addLabel(page, text)
    local row = new("Frame", { Size = UDim2.new(1,0,0,54), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 14)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.fromOffset(13, 0),
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    return lbl
end

local function addButton(page, label, callback)
    local btn = new("TextButton", {
        Size = UDim2.new(1,0,0,54),
        BackgroundColor3 = T.Row,
        BorderSizePixel = 0,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 13,
        AutoButtonColor = false,
    }, page)
    corner(btn, 10)
    trackConnection(btn.Activated:Connect(function()
        tween(btn, TweenInfo.new(0.08), { BackgroundColor3 = T.Row2 })
        task.delay(0.1, function() if btn and btn.Parent then tween(btn, TweenInfo.new(0.12), { BackgroundColor3 = T.Row }) end end)
        if callback then task.spawn(function() pcall(callback) end) end
    end))
    return btn
end

local function addToggle(page, label, default, callback)
    local value = default and true or false
    local row = new("Frame", { Size = UDim2.new(1,0,0,54), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 14)
    local txt = new("TextLabel", {
        Size = UDim2.new(1, -92, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local hit = new("TextButton", {
        Size = UDim2.fromOffset(66, 30),
        Position = UDim2.new(1, -80, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(38,38,38),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(hit, 17); stroke(hit, Color3.fromRGB(80,80,80), 1, 0.35)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(24,24),
        Position = UDim2.fromOffset(3,3),
        BackgroundColor3 = Color3.fromRGB(135,135,135),
        BorderSizePixel = 0,
    }, hit)
    corner(knob, 14)
    local function draw(call)
        tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = value and UDim2.fromOffset(39,3) or UDim2.fromOffset(3,3),
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
    min = tonumber(min) or 0; max = tonumber(max) or 100; precision = precision or 0
    local value = tonumber(default) or min
    value = math.clamp(value, min, max)
    local row = new("Frame", { Size = UDim2.new(1,0,0,68), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 14)
    local txt = new("TextLabel", {
        Size = UDim2.new(0.55, -18, 0, 28),
        Position = UDim2.fromOffset(14, 4),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valLbl = new("TextLabel", {
        Size = UDim2.new(0.45, -18, 0, 28),
        Position = UDim2.new(0.55, 0, 0, 4),
        BackgroundTransparency = 1,
        Text = fmtValue(value, precision),
        TextColor3 = T.White,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local bar = new("TextButton", {
        Size = UDim2.new(1, -28, 0, 16),
        Position = UDim2.new(0, 14, 0, 40),
        BackgroundColor3 = Color3.fromRGB(26,26,26),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(bar, 10)
    local fill = new("Frame", { Size = UDim2.new(0,0,1,0), BackgroundColor3 = T.White, BorderSizePixel = 0 }, bar)
    corner(fill, 10)
    local knob = new("Frame", { Size = UDim2.fromOffset(22,22), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = T.White, BorderSizePixel = 0 }, bar)
    corner(knob, 13)
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
        valLbl.Text = fmtValue(value, precision)
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
    local row = new("Frame", { Size = UDim2.new(1,0,0,62), BackgroundColor3 = T.Row, BorderSizePixel = 0 }, page)
    corner(row, 14)
    new("TextLabel", {
        Size = UDim2.new(0.42, -18, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local box = new("TextBox", {
        Size = UDim2.new(0.58, -24, 0, 38),
        Position = UDim2.new(0.42, 10, 0.5, -19),
        BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel = 0,
        Text = default or "",
        PlaceholderText = placeholder or "",
        TextColor3 = T.Text,
        PlaceholderColor3 = Color3.fromRGB(115,115,115),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 10); pad(box, 10, 10, 0, 0)
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
    options = options or {}
    local selected = {}
    local current = default
    if multi then
        if type(default) == "table" then
            for k, v in pairs(default) do if v == true then selected[k] = true elseif type(v) == "string" then selected[v] = true end end
        end
    end
    local row = new("Frame", { Size = UDim2.new(1,0,0,62), BackgroundColor3 = T.Row, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = dropdownZ }, page)
    corner(row, 14)
    new("TextLabel", {
        Size = UDim2.new(0.42, -18, 0, 62),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = cleanUiText(label),
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBlack,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    local btn = new("TextButton", {
        Size = UDim2.new(0.58, -24, 0, 38),
        Position = UDim2.new(0.42, 10, 0, 12),
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
    corner(btn, 10)
    local btnText = new("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, btn)
    new("TextLabel", { Size = UDim2.fromOffset(26, 38), Position = UDim2.new(1, -30, 0, 0), BackgroundTransparency = 1, Text = "v", TextColor3 = T.Muted, Font = Enum.Font.GothamBold, TextSize = 14 }, btn)
    local list = new("ScrollingFrame", {
        Size = UDim2.new(0.58, -24, 0, 0),
        Position = UDim2.new(0.42, 10, 0, 56),
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
                Size = UDim2.new(1, -2, 0, 30),
                BackgroundColor3 = (multi and selected[op] or current == op) and Color3.fromRGB(230,230,230) or Color3.fromRGB(32,32,32),
                BorderSizePixel = 0,
                Text = (multi and (selected[op] and "✓ " or "") or "") .. cleanUiText(op),
                TextColor3 = (multi and selected[op] or current == op) and T.DarkText or T.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
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
            local h = math.min(150, layout.AbsoluteContentSize.Y + 12)
            list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
            if list.Visible then
                list.Size = UDim2.new(0.58, -24, 0, h)
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
            local h = math.min(150, layout.AbsoluteContentSize.Y + 12)
            list.Size = UDim2.new(0.58, -24, 0, h)
        else
            list.Size = UDim2.new(0.58, -24, 0, 0)
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
createTab("SHOP", 3)
createTab("AUTO", 4)
createTab("BOOSTS", 5)
createTab("PETS", 6)
createTab("OPEN", 7)
createTab("STEAL", 8)
createTab("MISC", 9)
createTab("VISUALS", 10)
createTab("SETTINGS", 11)

-- DASHBOARD
addSection(UI.Pages["DASHBOARD"], "STATUS")
UI.plotLabel = addLabel(UI.Pages["DASHBOARD"], "GARDEN: ?")
UI.cashLabel = addLabel(UI.Pages["DASHBOARD"], "SHECKLES: ? · TOKENS: ?")
UI.statLabel = addLabel(UI.Pages["DASHBOARD"], "BOUGHT 0 · PLANTED 0 · HARVESTED 0 · SOLD 0 (+0)")
UI.extraStatLabel = addLabel(UI.Pages["DASHBOARD"], "SPRINKLERS 0 · WATERED 0 · TAMED 0 · OPENED 0 · STOLEN 0")
UI.seedEventAvailableLabel = addLabel(UI.Pages["DASHBOARD"], "SEED EVENTS AVAILABLE: NONE")
UI.seedEventClaimedLabel = addLabel(UI.Pages["DASHBOARD"], "SEED EVENTS CLAIMED: RAINBOW 0 · GOLD 0 · TOTAL 0")
UI.seedEventLastLabel = addLabel(UI.Pages["DASHBOARD"], "LAST SEED EVENT CLAIM: NONE")
UI.uptimeLabel = addLabel(UI.Pages["DASHBOARD"], "UPTIME: 0S")
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
addSlider(UI.Pages["FARM"], "HARVEST DELAY", 0, 0.2, S.harvestDelay, 3, function(v) S.harvestDelay = v end)
addToggle(UI.Pages["FARM"], "AUTO POT PLANTS", S.autoPot, function(v) S.autoPot = v end)

-- AUTO
addSection(UI.Pages["AUTO"], "SELL WHEN FULL")
addToggle(UI.Pages["AUTO"], "AUTO SELL WHEN FULL", S.autoSell, function(v) S.autoSell = v end)
addSlider(UI.Pages["AUTO"], "SELL DELAY", 3, 120, S.sellInterval, 0, function(v) S.sellInterval = v end)
addDropdown(UI.Pages["AUTO"], "SELL KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.sellKeepMutations, true, function(sel) pickMulti(sel, S.sellKeepMutations) end)
addDropdown(UI.Pages["AUTO"], "SELL KEEP WEIGHT FILTER", KG_MODE_OPTIONS, S.sellKeepKgMode, false, function(v) S.sellKeepKgMode = v end)
addSlider(UI.Pages["AUTO"], "SELL KEEP WEIGHT VALUE", 0, 500, S.sellKeepKgValue, 1, function(v) S.sellKeepKgValue = v end)
addSection(UI.Pages["AUTO"], "SEED EVENTS")
addToggle(UI.Pages["AUTO"], "AUTO CLAIM SEED EVENT", S.autoClaimSeedEvent, function(v) S.autoClaimSeedEvent = v end)
addToggle(UI.Pages["AUTO"], "USE FLY TO SEED EVENT", S.claimUseFly, function(v) S.claimUseFly = v end)
addSlider(UI.Pages["AUTO"], "SEED EVENT DELAY", 3, 60, S.seedEventDelay, 0, function(v) S.seedEventDelay = v end)
addSection(UI.Pages["AUTO"], "DAILY DEALS")
addToggle(UI.Pages["AUTO"], "AUTO DAILY DEALS", S.autoDaily, function(v) S.autoDaily = v end)
addSlider(UI.Pages["AUTO"], "DAILY CLAIM DELAY", 10, 300, S.dailyDelay, 0, function(v) S.dailyDelay = v end)
addSection(UI.Pages["AUTO"], "SHOVEL")
addToggle(UI.Pages["AUTO"], "AUTO SHOVEL PLANTS", S.autoShovelPlants, function(v) S.autoShovelPlants = v end)
addDropdown(UI.Pages["AUTO"], "SHOVEL PLANT TARGETS", SEED_NAMES, S.shovelPlantTargets, true, function(sel) pickMulti(sel, S.shovelPlantTargets) end)
addToggle(UI.Pages["AUTO"], "AUTO SHOVEL FRUITS", S.autoShovelFruits, function(v) S.autoShovelFruits = v end)
addDropdown(UI.Pages["AUTO"], "SHOVEL FRUIT TARGETS", SEED_NAMES, S.shovelFruitTargets, true, function(sel) pickMulti(sel, S.shovelFruitTargets) end)
addDropdown(UI.Pages["AUTO"], "SHOVEL KEEP MUTATIONS", HaimiyachGAG2_MutationNames, S.shovelKeepMutations, true, function(sel) pickMulti(sel, S.shovelKeepMutations) end)
addDropdown(UI.Pages["AUTO"], "SHOVEL WEIGHT FILTER", KG_MODE_OPTIONS, S.shovelKgMode, false, function(v) S.shovelKgMode = v end)
addSlider(UI.Pages["AUTO"], "SHOVEL WEIGHT VALUE", 0, 500, S.shovelKgValue, 1, function(v) S.shovelKgValue = v end)
addSlider(UI.Pages["AUTO"], "SHOVEL DELAY", 1, 30, S.shovelDelay, 0, function(v) S.shovelDelay = v end)
addSection(UI.Pages["AUTO"], "TROWEL")
addToggle(UI.Pages["AUTO"], "AUTO TROWEL PLANTS", S.autoTrowelPlants, function(v) S.autoTrowelPlants = v end)
addDropdown(UI.Pages["AUTO"], "TROWEL PLANT TARGETS", SEED_NAMES, S.trowelPlantTargets, true, function(sel) pickMulti(sel, S.trowelPlantTargets) end)
addDropdown(UI.Pages["AUTO"], "TROWEL POSITION", { "MAPPING", "AVATAR POSITION" }, S.trowelPositionMode, false, function(v) S.trowelPositionMode = v or "MAPPING" end)
addSlider(UI.Pages["AUTO"], "TROWEL DELAY", 1, 30, S.trowelDelay, 0, function(v) S.trowelDelay = v end)
addSection(UI.Pages["AUTO"], "INVENTORY FAVORITE")
addToggle(UI.Pages["AUTO"], "AUTO FAVORITE FRUITS", S.autoFavoriteFruits, function(v) S.autoFavoriteFruits = v end)
addDropdown(UI.Pages["AUTO"], "FAVORITE FRUIT TARGETS", SEED_NAMES, S.favoriteFruitTargets, true, function(sel) pickMulti(sel, S.favoriteFruitTargets) end)
addDropdown(UI.Pages["AUTO"], "FAVORITE MUTATIONS", HaimiyachGAG2_MutationNames, S.favoriteMutations, true, function(sel) pickMulti(sel, S.favoriteMutations) end)
addDropdown(UI.Pages["AUTO"], "FAVORITE WEIGHT FILTER", KG_MODE_OPTIONS, S.favoriteKgMode, false, function(v) S.favoriteKgMode = v end)
addSlider(UI.Pages["AUTO"], "FAVORITE WEIGHT VALUE", 0, 500, S.favoriteKgValue, 1, function(v) S.favoriteKgValue = v end)
addToggle(UI.Pages["AUTO"], "UNFAVORITE NOT MATCHING", S.unfavoriteNotMatching, function(v) S.unfavoriteNotMatching = v end)
addSlider(UI.Pages["AUTO"], "FAVORITE DELAY", 1, 30, S.favoriteDelay, 0, function(v) S.favoriteDelay = v end)
addButton(UI.Pages["AUTO"], "FAVORITE INVENTORY NOW", function()
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
addSlider(UI.Pages["BOOSTS"], "SPRINKLER DELAY", 10, 120, S.sprinklerInterval, 0, function(v) S.sprinklerInterval = v end)
addToggle(UI.Pages["BOOSTS"], "AUTO WATERING CAN", S.autoWater, function(v) S.autoWater = v end)
addSlider(UI.Pages["BOOSTS"], "WATER DELAY", 2, 60, S.waterInterval, 0, function(v) S.waterInterval = v end)
addSection(UI.Pages["BOOSTS"], "SKILL POINTS")
addDropdown(UI.Pages["BOOSTS"], "STATS TO LEVEL", { "BaseSpeed", "BaseJump", "ShovelPower", "MaxBackpack" }, S.skillStats, true, function(sel) pickMulti(sel, S.skillStats) end)
addToggle(UI.Pages["BOOSTS"], "AUTO SPEND SKILL POINTS", S.autoSkill, function(v) S.autoSkill = v end)

-- PETS
addSection(UI.Pages["PETS"], "PETS")
addToggle(UI.Pages["PETS"], "AUTO EQUIP PETS", S.autoEquipPets, function(v) S.autoEquipPets = v end)
addToggle(UI.Pages["PETS"], "AUTO BUY PET SLOTS", S.autoPetSlot, function(v) S.autoPetSlot = v end)
addToggle(UI.Pages["PETS"], "AUTO BUY WORLD PETS", S.autoBuyPets, function(v) S.autoBuyPets = v end)
addSlider(UI.Pages["PETS"], "MAX PET PRICE", 1000, 1000000, S.maxPetPrice, 0, function(v) S.maxPetPrice = v end)
addToggle(UI.Pages["PETS"], "TELEPORT TO PET", S.petTeleport, function(v) S.petTeleport = v end)
addSlider(UI.Pages["PETS"], "PET BUY DELAY", 2, 60, S.petBuyInterval, 0, function(v) S.petBuyInterval = v end)
addSection(UI.Pages["PETS"], "SELL PETS")
UI.petDrop = addDropdown(UI.Pages["PETS"], "PETS TO SELL", ownedPetNames(), S.sellPets, true, function(sel) pickMulti(sel, S.sellPets) end)
addButton(UI.Pages["PETS"], "REFRESH PET LIST", function() UI.petDrop.SetOptions(ownedPetNames()) end)
addToggle(UI.Pages["PETS"], "AUTO SELL SELECTED PETS", S.autoSellPets, function(v) S.autoSellPets = v end)

-- OPEN
addSection(UI.Pages["OPEN"], "OPEN ITEMS")
addToggle(UI.Pages["OPEN"], "AUTO OPEN EGGS", S.autoEgg, function(v) S.autoEgg = v end)
addToggle(UI.Pages["OPEN"], "AUTO OPEN CRATES", S.autoCrate, function(v) S.autoCrate = v end)
addToggle(UI.Pages["OPEN"], "AUTO OPEN SEED PACKS", S.autoPack, function(v) S.autoPack = v end)
addSlider(UI.Pages["OPEN"], "OPEN DELAY", 1, 30, S.openInterval, 0, function(v) S.openInterval = v end)

-- SHOP
addSection(UI.Pages["SHOP"], "SEED SHOP")
addDropdown(UI.Pages["SHOP"], "SEEDS TO BUY", SEED_NAMES, S.buySeeds, true, function(sel) pickMulti(sel, S.buySeeds) end)
addToggle(UI.Pages["SHOP"], "AUTO BUY SEEDS", S.autoBuy, function(v) S.autoBuy = v end)
addToggle(UI.Pages["SHOP"], "AUTO BUY ALL SEEDS", S.autoBuyAllSeeds, function(v) S.autoBuyAllSeeds = v end)
addSlider(UI.Pages["SHOP"], "SEED BUY DELAY", 1, 30, S.buyInterval, 0, function(v) S.buyInterval = v end)
addSlider(UI.Pages["SHOP"], "MAX BUYS PER SEED", 1, 50, S.buyPerTick, 0, function(v) S.buyPerTick = v end)
addSection(UI.Pages["SHOP"], "GEAR SHOP")
addDropdown(UI.Pages["SHOP"], "GEAR TO BUY", GEAR_NAMES, S.gearBuy, true, function(sel) pickMulti(sel, S.gearBuy) end)
addToggle(UI.Pages["SHOP"], "AUTO BUY GEAR", S.autoGear, function(v) S.autoGear = v end)
addToggle(UI.Pages["SHOP"], "AUTO BUY ALL GEAR", S.autoBuyAllGear, function(v) S.autoBuyAllGear = v end)
addSlider(UI.Pages["SHOP"], "GEAR BUY DELAY", 2, 60, S.gearInterval, 0, function(v) S.gearInterval = v end)
-- STEAL
addSection(UI.Pages["STEAL"], "STEAL")
addToggle(UI.Pages["STEAL"], "AUTO STEAL RIPE FRUIT", S.autoSteal, function(v) S.autoSteal = v end)
addToggle(UI.Pages["STEAL"], "TELEPORT TO FRUIT", S.stealTeleport, function(v) S.stealTeleport = v end)
addToggle(UI.Pages["STEAL"], "RETURN TO BASE", S.stealReturnBase, function(v) S.stealReturnBase = v end)
addSlider(UI.Pages["STEAL"], "STEAL WAIT TIME", 0, 1, S.stealDelay, 2, function(v) S.stealDelay = v end)

-- MISC
addSection(UI.Pages["MISC"], "MAILBOX & GIFTS")
addToggle(UI.Pages["MISC"], "AUTO CLAIM MAILBOX", S.autoMail, function(v) S.autoMail = v end)
addToggle(UI.Pages["MISC"], "AUTO ACCEPT GIFTS", S.autoAcceptGift, function(v) S.autoAcceptGift = v end)
addSection(UI.Pages["MISC"], "SERVER")
addToggle(UI.Pages["MISC"], "ANTI AFK", S.antiAfk, function(v) S.antiAfk = v end)
addToggle(UI.Pages["MISC"], "AUTO SERVER HOP", S.autoHop, function(v) S.autoHop = v; saveConfig(true) end)
addSlider(UI.Pages["MISC"], "SERVER HOP DELAY (MIN)", 0, 120, S.hopInterval / 60, 0, function(v) S.hopInterval = v * 60; saveConfig(true) end)
addToggle(UI.Pages["MISC"], "AUTO EXECUTE AFTER HOP", S.autoExecute, function(v)
    S.autoExecute = v
    saveConfig(true)
    if v then
        local ok, err = writeAutoExecuteLoader()
        notify("HAIMIYACH HUB", ok and "Auto execute loader saved." or ("Auto execute loader failed: " .. tostring(err)), 4)
    end
end)
addInput(UI.Pages["MISC"], "AUTO EXECUTE URL", "raw loader/script url", S.autoExecuteUrl, function(text)
    S.autoExecuteUrl = tostring(text or "")
    saveConfig(true)
    if S.autoExecute then
        pcall(writeAutoExecuteLoader)
    end
end)
addSection(UI.Pages["MISC"], "CODES")
addInput(UI.Pages["MISC"], "REDEEM CODE", "enter code", "", function(text) S.codeText = text or "" end)
addButton(UI.Pages["MISC"], "REDEEM CODE NOW", function()
    local code = S.codeText or ""
    if code ~= "" then
        local ok, res = fire("Settings.SubmitCode", code)
        notify("Code", ok and "Redeem request sent" or tostring(res or "Failed"), 3)
    end
end)
addToggle(UI.Pages["MISC"], "AUTO REDEEM CODE LIST", S.autoCodes, function(v) S.autoCodes = v end)

-- VISUALS
addSection(UI.Pages["VISUALS"], "ESP")
addToggle(UI.Pages["VISUALS"], "ESP READY FRUIT", S.espGardenFruit, function(v) GardenESP.set(v); saveConfig(true) end)
addToggle(UI.Pages["VISUALS"], "ESP GROWING FRUIT", S.espGardenGrowing, function(v) GardenESP.setGrowing(v); saveConfig(true) end)
addToggle(UI.Pages["VISUALS"], "GARDEN VALUE SHECKLES", S.espGardenValue, function(v) GardenESP.setValue(v); saveConfig(true) end)
addToggle(UI.Pages["VISUALS"], "ESP BACKPACK FRUIT", S.espBackpackFruit, function(v) BackpackESP.set(v); saveConfig(true) end)
addToggle(UI.Pages["VISUALS"], "BACKPACK VALUE SHECKLES", S.espBackpackValue, function(v) BackpackESP.setValue(v); saveConfig(true) end)
addToggle(UI.Pages["VISUALS"], "TOTAL BACKPACK VALUE", S.espBackpackTotal, function(v) BackpackESP.setTotal(v); saveConfig(true) end)

addSection(UI.Pages["VISUALS"], "PERFORMANCE")
UI.visualPerfLabel = addLabel(UI.Pages["VISUALS"], "FPS: ?\nPING: ?")
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
if S.espGardenFruit then GardenESP.set(true) end
if S.espGardenGrowing then GardenESP.setGrowing(true) end
if S.espBackpackFruit then BackpackESP.set(true) end
if S.espBackpackTotal then BackpackESP.setTotal(true) end

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
addSlider(UI.Pages["SETTINGS"], "REPORT DELAY", 1, 60, S.webhookInterval / 60, 0, function(v) S.webhookInterval = v * 60; saveConfig(true) end)
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
    if fpsConnection then pcall(function() fpsConnection:Disconnect() end) end
    disconnectUiConnections()
    cleanContainer(PlayerGui)
    cleanContainer(CoreGui)
end)

-- AUTO CLAIM SEED EVENT loop
loopOn(function() return S.autoClaimSeedEvent end, function() return math.max(3, tonumber(S.seedEventDelay) or 3) end, function()
    claimSeedEvent()
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

-- live status
function UI.SafeSetText(lbl, txt)
    pcall(function() if lbl and lbl.Parent then lbl.Text = txt end end)
end
task.spawn(function()
    while not S.killed do
        local p = myPlot()
        UI.SafeSetText(UI.plotLabel, "GARDEN: " .. (p and p.Name or "?"))
        UI.SafeSetText(UI.cashLabel, string.format("SHECKLES: %s · TOKENS: %s", fmt(getSheckles()), fmt(getTokens())))
        UI.SafeSetText(UI.statLabel, string.format("BOUGHT %d · PLANTED %d · HARVESTED %d · SOLD %d (+%s)",
            Stats.bought, Stats.planted, Stats.harvested, Stats.sold, fmt(Stats.earned)))
        UI.SafeSetText(UI.extraStatLabel, string.format("SPRINKLERS %d · WATERED %d · TAMED %d · OPENED %d · STOLEN %d",
            Stats.sprinklers, Stats.watered, Stats.tamed, Stats.opened, Stats.stolen))
        UI.SafeSetText(UI.seedEventAvailableLabel, "SEED EVENTS AVAILABLE: " .. getSeedEventAvailableText())
        UI.SafeSetText(UI.seedEventClaimedLabel, "SEED EVENTS CLAIMED: " .. getSeedEventClaimText())
        UI.SafeSetText(UI.seedEventLastLabel, "LAST SEED EVENT CLAIM: " .. getSeedEventLastText())
        UI.SafeSetText(UI.uptimeLabel, "UPTIME: " .. hms(os.clock() - Stats.startAt))
        UI.SafeSetText(UI.visualPerfLabel, string.format("FPS: %s\nPING: %s", tostring(currentFps), getPingText()))
        task.wait(1)
    end
end)

pcall(function()
    if getgenv then getgenv().HaimiyachGAG2 = {
        S = S, Stats = Stats, Net = Net, fire = fire, action = action,
        catalog = CATALOG, gearNames = GEAR_NAMES, myPlot = myPlot, replica = replica,
        ripeHarvests = ripeHarvests, stealable = stealable, wildPets = wildPets,
        claimSeedEvent = claimSeedEvent, flyToPosition = flyToPosition, SetCutsceneDisabled = SetCutsceneDisabled,
        toolsByAttr = toolsByAttr, plantGrid = plantGrid, ownedPetNames = ownedPetNames, myBasePos = myBasePos,
        stepHarvest = stepHarvest, fireFast = fireFast, fruitCount = fruitCount, sellAllNow = sellAllNow, maxFruitCap = maxFruitCap,
        unload = function()
            S.killed = true
            UI.Unloaded = true
            pcall(function() SetCutsceneDisabled(false, true) end)
            pcall(RestoreDefaultGraphics)
            pcall(function() GardenESP.set(false) end)
            pcall(GardenESP.clear)
            pcall(function() BackpackESP.set(false) end)
            pcall(BackpackESP.clear)
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

