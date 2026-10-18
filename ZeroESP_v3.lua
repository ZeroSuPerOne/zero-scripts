-- ═══════════════════════════════════════════════════════════
--  ZERO v3.0  |  Roblox toolkit
--  Tabs: Combat / Target / Farm / Move / Warp / Map / Tools / ESP / Bypass / UI
--  แตะโลโก้ "Z" เพื่อเปิด/ปิดเมนู | ลากมุมขวาล่างเพื่อปรับขนาด
--  ทุกฟีเจอร์ปิดเป็นค่าเริ่มต้น ยกเว้นหมวด Bypass
-- ═══════════════════════════════════════════════════════════

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local CollectionSvc = game:GetService("CollectionService")
local VirtualUser   = game:GetService("VirtualUser")
local HttpService   = game:GetService("HttpService")
local TeleportSvc   = game:GetService("TeleportService")
local Lighting      = game:GetService("Lighting")
local Stats         = game:GetService("Stats")
local lp            = Players.LocalPlayer

local WHITE = Color3.fromRGB(255, 255, 255)

-- รันซ้ำ = ปิดตัวเก่าก่อน
local env = (getgenv and getgenv()) or _G
if env.__zero_unload then pcall(env.__zero_unload) end

local alive, conns, errors = true, {}, {}

local function bind(sig, fn)
    local c = sig:Connect(fn)
    conns[#conns + 1] = c
    return c
end

local function logErr(tag, err)
    errors[#errors + 1] = tag .. ": " .. tostring(err)
    warn("[Zero] " .. tag .. ": " .. tostring(err))
end

local function safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then logErr(tag, err) end
    return ok
end

-- ความสามารถของ executor
local CAP = {
    Draw   = (Drawing ~= nil and Drawing.new ~= nil),
    Hook   = (hookmetamethod ~= nil and getnamecallmethod ~= nil and checkcaller ~= nil),
    Clip   = (setclipboard ~= nil or toclipboard ~= nil),
    Files  = (writefile ~= nil and readfile ~= nil and isfile ~= nil),
    Prompt = (fireproximityprompt ~= nil),
    Touch  = (firetouchinterface ~= nil),
}

local function copy(text)
    local f = setclipboard or toclipboard
    if f then pcall(f, text); return true end
    return false
end

local notify = function(msg) print("[Zero] " .. tostring(msg)) end

-- ══════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════
local CFG = {
    Speed  = { Enabled = false, Value = 50, Default = 16, Mode = "CFrame", WasOverriding = false },
    Fly    = { Enabled = false, Speed = 40 },
    Noclip = { Enabled = false },
    InfJump = false,

    Aura   = { Enabled = false, Range = 14, CPS = 4, Players = true, Monsters = true, WallCheck = true },
    Kill   = { Enabled = false, Target = nil, Follow = false, Range = 14, CPS = 5 },
    Chop   = { Enabled = false, Range = 12, CPS = 3, Keywords = "tree,wood,log,trunk" },
    Combat = { TouchHit = true, Face = true },
    Prompt = { Enabled = false, Range = 12, Instant = false },

    ESP = {
        Players  = { Enabled = false, MaxDist = 1000,
                     Hostile = Color3.fromRGB(255, 60, 60), Friendly = Color3.fromRGB(60, 230, 100) },
        Monsters = { Enabled = false, MaxDist = 800,
                     Hostile = Color3.fromRGB(255, 120, 0), Passive = Color3.fromRGB(240, 220, 0) },
        Items    = { Enabled = false, MaxDist = 400, Color = Color3.fromRGB(0, 200, 255) },
        ShowDistance = true, ShowName = true, Thickness = 1.5,
    },

    Misc = { Fullbright = false, FOVOn = false, FOV = 70 },
    Spy  = { Enabled = false, Ignore = "ping,heartbeat,update,move,position,look,mouse,camera" },

    -- Bypass: เปิดอัตโนมัติ
    Bypass = { CFrameSpeed = true, Humanize = true, RangeJitter = true, AntiAFK = true,
               AntiReset = true, SafeTP = true, TPSpeed = 180, SpoofReads = true,
               BlockKick = true, MaxStep = 1.2 },
}

math.randomseed(math.floor(os.clock() * 100000) % 2147483647)
local function rand(a, b) return a + math.random() * (b - a) end
local function cam() return workspace.CurrentCamera end

local function getRoot(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("RootPart")
        or model:FindFirstChildWhichIsA("BasePart")
end
local function getHum(model) return model:FindFirstChildOfClass("Humanoid") end
local function myRoot()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function dist3(pos)
    local r = myRoot()
    return r and math.floor((r.Position - pos).Magnitude) or 9999
end

local Actions = {} -- ฟังก์ชันที่ต้องเรียกข้ามส่วน

-- ══════════════════════════════════════
--  DETECTION
-- ══════════════════════════════════════
local isNPCHostile, isPlayerHostile, isItemModel
do
    local HOSTILE_WORDS  = {"zombie","monster","enemy","hostile","mob","boss","alien","mutant","demon","ghoul","walker","raider","bandit"}
    local PASSIVE_WORDS  = {"villager","merchant","npc","friendly","trader","guide","citizen"}
    local HOSTILE_TAGS   = {"Enemy","Hostile","Zombie","Monster"}
    local ATTACK_SCRIPTS = {"Attack","Aggro","Chase","AggroRange","AggressiveScript","EnemyAI"}
    local ITEM_KEYWORDS  = {
        "tool","weapon","pickup","item","coin","gem","key","chest","ammo","health","armor",
        "potion","collectible","drop","loot","reward","powerup","card","badge","crate",
    }

    isNPCHostile = function(model)
        local name = model.Name:lower()
        for _, w in ipairs(HOSTILE_WORDS) do if name:find(w) then return true end end
        for _, w in ipairs(PASSIVE_WORDS) do if name:find(w) then return false end end
        for _, tag in ipairs(HOSTILE_TAGS) do
            if CollectionSvc:HasTag(model, tag) then return true end
        end
        for _, s in ipairs(ATTACK_SCRIPTS) do
            if model:FindFirstChild(s, true) then return true end
        end
        local root, mine = getRoot(model), myRoot()
        if root and mine then
            local delta = mine.Position - root.Position
            if delta.Magnitude > 0.1 and root.AssemblyLinearVelocity.Magnitude > 2 then
                if root.AssemblyLinearVelocity.Unit:Dot(delta.Unit) > 0.7 then return true end
            end
        end
        return false
    end

    isPlayerHostile = function(player)
        if lp.Team and player.Team then return player.Team ~= lp.Team end
        return true
    end

    isItemModel = function(obj)
        local name = obj.Name:lower()
        for _, kw in ipairs(ITEM_KEYWORDS) do
            if name:find(kw) then return true end
        end
        if obj:FindFirstChildOfClass("ProximityPrompt") then return true end
        return false
    end
end

-- ══════════════════════════════════════
--  CACHE (สแกนทุก 2 วิ เฉพาะตอนมีฟีเจอร์ที่ต้องใช้)
-- ══════════════════════════════════════
local Cache = { npcs = {}, items = {}, trees = {}, prompts = {} }
local treeKeys = {}

local function parseKeys(str)
    local t = {}
    for piece in tostring(str):gmatch("[^,]+") do
        local k = piece:lower():gsub("^%s+", ""):gsub("%s+$", "")
        if #k > 0 then t[#t + 1] = k end
    end
    return t
end

local function nameHasKey(name, keys)
    name = name:lower()
    for _, k in ipairs(keys) do
        if name:find(k, 1, true) then return true end
    end
    return false
end

treeKeys = parseKeys(CFG.Chop.Keywords)

local function scanNow()
    task.spawn(function()
        pcall(function()
            local npcs, items, trees, prompts = {}, {}, {}, {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") then
                    if getHum(obj) then
                        if not Players:GetPlayerFromCharacter(obj) then npcs[#npcs + 1] = obj end
                    else
                        if isItemModel(obj) then items[#items + 1] = obj end
                        if #trees < 600 and nameHasKey(obj.Name, treeKeys) then trees[#trees + 1] = obj end
                    end
                elseif obj:IsA("BasePart") then
                    if obj.Parent and not obj.Parent:IsA("Model") then
                        if isItemModel(obj) then items[#items + 1] = obj end
                        if #trees < 600 and nameHasKey(obj.Name, treeKeys) then trees[#trees + 1] = obj end
                    end
                elseif obj:IsA("ProximityPrompt") then
                    if #prompts < 800 then prompts[#prompts + 1] = obj end
                end
            end
            Cache.npcs, Cache.items, Cache.trees, Cache.prompts = npcs, items, trees, prompts
        end)
    end)
end

task.spawn(function()
    while alive do
        task.wait(2)
        if CFG.ESP.Monsters.Enabled or CFG.ESP.Items.Enabled
           or (CFG.Aura.Enabled and CFG.Aura.Monsters) or CFG.Chop.Enabled or CFG.Prompt.Enabled then
            scanNow()
        end
    end
end)

-- ══════════════════════════════════════
--  ESP
-- ══════════════════════════════════════
local updateESP, freeAllESP
do
    local pool = {}

    local function newEntry()
        local function mkSquare(thickness, color)
            local s = Drawing.new("Square")
            s.Visible = false; s.Filled = false
            s.Thickness = thickness; s.Color = color or WHITE
            return s
        end
        local t = Drawing.new("Text")
        t.Visible = false; t.Size = 13; t.Center = true; t.Outline = true
        t.Font = (Drawing.Fonts and Drawing.Fonts.Plex) or 2
        t.Color = WHITE
        return {
            outline = mkSquare(CFG.ESP.Thickness + 2, Color3.fromRGB(0, 0, 0)),
            box = mkSquare(CFG.ESP.Thickness),
            label = t,
        }
    end

    local function freeEntry(e)
        pcall(function() e.outline:Remove(); e.box:Remove(); e.label:Remove() end)
    end
    local function hideEntry(e)
        e.outline.Visible = false; e.box.Visible = false; e.label.Visible = false
    end
    local function applyEntry(e, b, color, text)
        local pad = Vector2.new(1, 1)
        e.outline.Visible = true
        e.outline.Position = b.pos - pad
        e.outline.Size = b.size + pad * 2
        e.box.Visible = true
        e.box.Position = b.pos
        e.box.Size = b.size
        e.box.Color = color
        e.label.Visible = (text ~= "")
        e.label.Text = text
        e.label.Position = Vector2.new(b.pos.X + b.size.X / 2, b.pos.Y - 16)
        e.label.Color = color
    end

    local function boxFromCF(cf, size)
        local c = cam()
        if not c then return nil end
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyOn = false
        for _, sx in ipairs({-1, 1}) do
            for _, sy in ipairs({-1, 1}) do
                for _, sz in ipairs({-1, 1}) do
                    local p = cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
                    local s, on = c:WorldToViewportPoint(p)
                    if s.Z <= 0 then return nil end
                    if on then anyOn = true end
                    minX = math.min(minX, s.X); maxX = math.max(maxX, s.X)
                    minY = math.min(minY, s.Y); maxY = math.max(maxY, s.Y)
                end
            end
        end
        if not anyOn then return nil end
        return { pos = Vector2.new(minX, minY), size = Vector2.new(maxX - minX, maxY - minY) }
    end

    local function modelBox(model)
        local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
        if not ok then return nil end
        return boxFromCF(cf, size)
    end

    local function text(prefix, name, d)
        local t = prefix
        if CFG.ESP.ShowName then t = t .. " " .. name end
        if CFG.ESP.ShowDistance then t = t .. " [" .. d .. "m]" end
        return t
    end

    updateESP = function()
        if not CAP.Draw then return end
        local used = {}

        if CFG.ESP.Players.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp and player.Character then
                    local char = player.Character
                    local root, hum = getRoot(char), getHum(char)
                    if root and hum and hum.Health > 0 then
                        local d = dist3(root.Position)
                        if d <= CFG.ESP.Players.MaxDist then
                            local box = modelBox(char)
                            if box then
                                local key = "plr_" .. player.UserId
                                pool[key] = pool[key] or newEntry()
                                local hostile = isPlayerHostile(player)
                                applyEntry(pool[key], box,
                                    hostile and CFG.ESP.Players.Hostile or CFG.ESP.Players.Friendly,
                                    text(hostile and "[!]" or "[+]", player.Name, d))
                                used[key] = true
                            end
                        end
                    end
                end
            end
        end

        if CFG.ESP.Monsters.Enabled then
            for _, model in ipairs(Cache.npcs) do
                if model.Parent then
                    local hum, root = getHum(model), getRoot(model)
                    if hum and root and hum.Health > 0 then
                        local d = dist3(root.Position)
                        if d <= CFG.ESP.Monsters.MaxDist then
                            local box = modelBox(model)
                            if box then
                                local key = "npc_" .. model:GetDebugId()
                                pool[key] = pool[key] or newEntry()
                                local hostile = isNPCHostile(model)
                                applyEntry(pool[key], box,
                                    hostile and CFG.ESP.Monsters.Hostile or CFG.ESP.Monsters.Passive,
                                    text(hostile and "[!]" or "[~]", model.Name, d))
                                used[key] = true
                            end
                        end
                    end
                end
            end
        end

        if CFG.ESP.Items.Enabled then
            local c = cam()
            for _, obj in ipairs(Cache.items) do
                if obj.Parent and c then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local d = dist3(part.Position)
                        if d <= CFG.ESP.Items.MaxDist then
                            local s, on = c:WorldToViewportPoint(part.Position)
                            if on and s.Z > 0 then
                                local key = "item_" .. obj:GetDebugId()
                                pool[key] = pool[key] or newEntry()
                                local sz = math.clamp(900 / s.Z, 18, 70)
                                applyEntry(pool[key], {
                                    pos = Vector2.new(s.X - sz / 2, s.Y - sz / 2),
                                    size = Vector2.new(sz, sz),
                                }, CFG.ESP.Items.Color, text("[*]", obj.Name, d))
                                used[key] = true
                            end
                        end
                    end
                end
            end
        end

        for key, e in pairs(pool) do
            if not used[key] then hideEntry(e) end
        end
    end

    freeAllESP = function()
        for _, e in pairs(pool) do freeEntry(e) end
        pool = {}
    end

    task.spawn(function()
        while alive do
            task.wait(5)
            for key, e in pairs(pool) do
                if not e.outline.Visible then freeEntry(e); pool[key] = nil end
            end
        end
    end)
end

-- ══════════════════════════════════════
--  SPEED / NOCLIP / FLY / INF JUMP
-- ══════════════════════════════════════
local Fly = { up = false, down = false }
local FlyBtns -- Frame ปุ่ม UP/DN (สร้างทีหลัง)

local function applySpeed()
    local char = lp.Character
    local hum = char and getHum(char)
    if not hum then return end
    local overriding = CFG.Speed.Enabled and CFG.Speed.Mode == "WalkSpeed"
    if overriding then
        hum.WalkSpeed = CFG.Speed.Value
    elseif CFG.Speed.WasOverriding then
        hum.WalkSpeed = CFG.Speed.Default
    end
    CFG.Speed.WasOverriding = overriding
end

local function hookCharacterSpeed(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    bind(hum:GetPropertyChangedSignal("WalkSpeed"), function()
        if CFG.Speed.Enabled and CFG.Speed.Mode == "WalkSpeed" and CFG.Bypass.AntiReset
           and hum.WalkSpeed ~= CFG.Speed.Value then
            hum.WalkSpeed = CFG.Speed.Value
        end
    end)
    if CFG.Speed.Enabled then applySpeed() end
end

local function cframeSpeedStep(dt)
    if not (CFG.Speed.Enabled and CFG.Speed.Mode == "CFrame") then return end
    local hrp = myRoot()
    local hum = lp.Character and getHum(lp.Character)
    if not hrp or not hum or hum.Health <= 0 or hum.Sit then return end
    local dir = hum.MoveDirection
    if dir.Magnitude < 0.1 then return end
    local extra = CFG.Speed.Value - hum.WalkSpeed
    if extra <= 0 then return end
    local step = extra * dt
    if CFG.Bypass.Humanize then step = step * rand(0.95, 1.05) end
    step = math.min(step, CFG.Bypass.MaxStep)
    hrp.CFrame = hrp.CFrame + dir.Unit * step
end

local NOCLIP_PARTS = {
    HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
}
local function applyNoclip()
    local char = lp.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and NOCLIP_PARTS[p.Name] then p.CanCollide = false end
    end
end
local function restoreCollision()
    local char = lp.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and NOCLIP_PARTS[p.Name] then p.CanCollide = true end
    end
end

local controlsMod, controlsTried = nil, false
local function getMoveVector()
    if not controlsMod and not controlsTried then
        controlsTried = true
        pcall(function()
            controlsMod = require(lp:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 3)):GetControls()
        end)
    end
    if controlsMod then
        local ok, v = pcall(function() return controlsMod:GetMoveVector() end)
        if ok and v then return v end
    end
    local hum = lp.Character and getHum(lp.Character)
    local c = cam()
    if hum and c then return c.CFrame:VectorToObjectSpace(hum.MoveDirection) end
    return Vector3.zero
end

local function flyStep(dt)
    if not CFG.Fly.Enabled then return end
    local hrp = myRoot()
    local hum = lp.Character and getHum(lp.Character)
    local c = cam()
    if not hrp or not hum or hum.Health <= 0 or not c then return end
    hum.PlatformStand = true
    local mv = getMoveVector()
    local dir = c.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))
    dir = dir + Vector3.new(0, (Fly.up and 1 or 0) - (Fly.down and 1 or 0), 0)
    local speed = CFG.Fly.Speed
    if CFG.Bypass.Humanize then speed = speed * rand(0.97, 1.03) end
    local vel = Vector3.zero
    if dir.Magnitude > 0.05 then vel = dir.Unit * speed end
    -- ชดเชยแรงโน้มถ่วงต่อเฟรม กันตัวละครค่อยๆ จม
    hrp.AssemblyLinearVelocity = vel + Vector3.new(0, workspace.Gravity * dt, 0)
end

local function setFly(on)
    CFG.Fly.Enabled = on
    if FlyBtns then FlyBtns.Visible = on end
    if not on then
        local hum = lp.Character and getHum(lp.Character)
        local hrp = myRoot()
        if hum then hum.PlatformStand = false end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
        Fly.up, Fly.down = false, false
    end
end

bind(UIS.JumpRequest, function()
    if CFG.InfJump then
        local hum = lp.Character and getHum(lp.Character)
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ══════════════════════════════════════
--  TELEPORT + WAYPOINT STORE
-- ══════════════════════════════════════
local Store = { slots = {}, named = {} }
local STORE_FILE = "ZeroESP_" .. tostring(game.PlaceId) .. ".json"

local function saveStore()
    if not CAP.Files then return end
    pcall(function() writefile(STORE_FILE, HttpService:JSONEncode(Store)) end)
end

if CAP.Files then
    pcall(function()
        if isfile(STORE_FILE) then
            local data = HttpService:JSONDecode(readfile(STORE_FILE))
            if type(data) == "table" then
                Store.slots = data.slots or {}
                Store.named = data.named or {}
            end
        end
    end)
end

local tpToken = 0
local function teleportTo(cf)
    local hrp = myRoot()
    if not hrp then notify("ยังไม่มีตัวละคร"); return end
    tpToken = tpToken + 1
    local my = tpToken
    if not CFG.Bypass.SafeTP then
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        return
    end
    task.spawn(function()
        local rot = cf - cf.Position
        local target = cf.Position
        while alive and my == tpToken do
            local r = myRoot()
            if not r then break end
            local delta = target - r.Position
            local dist = delta.Magnitude
            if dist < 3 then break end
            local dt = RunService.Heartbeat:Wait()
            local speed = CFG.Bypass.TPSpeed
            if CFG.Bypass.Humanize then speed = speed * rand(0.9, 1.1) end
            local step = math.min(dist, speed * dt)
            r.CFrame = CFrame.new(r.Position + delta.Unit * step) * (r.CFrame - r.CFrame.Position)
            r.AssemblyLinearVelocity = Vector3.zero
            applyNoclip()
        end
        if my == tpToken then
            local r = myRoot()
            if r then
                r.CFrame = CFrame.new(target) * rot
                r.AssemblyLinearVelocity = Vector3.zero
            end
            if not CFG.Noclip.Enabled then restoreCollision() end
        end
    end)
end

local function warpToPos(p) -- p = {x,y,z}
    teleportTo(CFrame.new(p[1], p[2] + 3, p[3]))
end

-- ══════════════════════════════════════
--  COMBAT (Aura / Kill Player / Chop) — คูลดาวน์ร่วมกัน
-- ══════════════════════════════════════
local combatStep
do
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local AS = { last = 0, delay = 0.25 }

    local function heldWeapon()
        local char = lp.Character
        return char and char:FindFirstChildOfClass("Tool") or nil
    end

    local function visibleTo(fromPos, model, root)
        rayParams.FilterDescendantsInstances = { lp.Character }
        local hit = workspace:Raycast(fromPos, root.Position - fromPos, rayParams)
        return (not hit) or hit.Instance:IsDescendantOf(model)
    end

    local function swingAt(tool, part)
        pcall(function() tool:Activate() end)
        local handle = tool:FindFirstChild("Handle")
        if CFG.Combat.TouchHit and handle and CAP.Touch then
            pcall(function()
                firetouchinterface(handle, part, 0)
                firetouchinterface(handle, part, 1)
            end)
        end
    end

    local function faceAt(hrp, pos)
        local goal = CFrame.new(hrp.Position, Vector3.new(pos.X, hrp.Position.Y, pos.Z))
        hrp.CFrame = CFG.Bypass.Humanize and hrp.CFrame:Lerp(goal, 0.55) or goal
    end

    local function getAuraTarget(myPos)
        local K = CFG.Aura
        local range = K.Range
        if CFG.Bypass.RangeJitter then range = range * rand(0.9, 1) end
        local bestD, bestRoot = math.huge, nil
        local function consider(model)
            local hum, root = getHum(model), getRoot(model)
            if not hum or not root or hum.Health <= 0 then return end
            local d = (root.Position - myPos).Magnitude
            if d > range or d >= bestD then return end
            if K.WallCheck and not visibleTo(myPos, model, root) then return end
            bestD, bestRoot = d, root
        end
        if K.Players then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= lp and pl.Character and isPlayerHostile(pl) then consider(pl.Character) end
            end
        end
        if K.Monsters then
            for _, m in ipairs(Cache.npcs) do
                if m.Parent and isNPCHostile(m) then consider(m) end
            end
        end
        return bestRoot
    end

    local function getKillTarget(myPos)
        local pl = CFG.Kill.Target
        local char = pl and pl.Parent and pl.Character
        if not char then return nil end
        local hum, root = getHum(char), getRoot(char)
        if not hum or not root or hum.Health <= 0 then return nil end
        local range = CFG.Kill.Range
        if CFG.Bypass.RangeJitter then range = range * rand(0.9, 1) end
        if (root.Position - myPos).Magnitude > range then return nil end
        return root
    end

    local function getChopTarget(myPos)
        local range = CFG.Chop.Range
        local bestD, bestPart = math.huge, nil
        for _, t in ipairs(Cache.trees) do
            if t.Parent then
                local part = t:IsA("BasePart") and t
                    or t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (part.Position - myPos).Magnitude
                    if d <= range and d < bestD then bestD, bestPart = d, part end
                end
            end
        end
        return bestPart
    end

    local function attackStep(cfg, getTarget)
        local hrp = myRoot()
        local hum = lp.Character and getHum(lp.Character)
        if not hrp or not hum or hum.Health <= 0 then return false end
        local tool = heldWeapon()
        if not tool then return false end
        if os.clock() - AS.last < AS.delay then return true end
        local part = getTarget(hrp.Position)
        if not part then return false end
        if CFG.Combat.Face then faceAt(hrp, part.Position) end
        swingAt(tool, part)
        AS.last = os.clock()
        local base = 1 / math.max(cfg.CPS, 1)
        AS.delay = CFG.Bypass.Humanize and base * rand(0.85, 1.3) or base
        return true
    end

    local function followStep(dt)
        local K = CFG.Kill
        if not (K.Enabled and K.Follow and K.Target) then return end
        local hrp = myRoot()
        local tchar = K.Target.Character
        local troot = tchar and getRoot(tchar)
        if not hrp or not troot then return end
        local delta = troot.Position - hrp.Position
        local dist = delta.Magnitude
        if dist <= K.Range * 0.85 or dist > 300 then return end
        local step = math.min(dt * 30, CFG.Bypass.MaxStep * 1.5, dist - K.Range * 0.8)
        if CFG.Bypass.Humanize then step = step * rand(0.92, 1.05) end
        if step <= 0 then return end
        hrp.CFrame = hrp.CFrame + delta.Unit * step
    end

    combatStep = function(dt)
        followStep(dt)
        if CFG.Kill.Enabled and attackStep(CFG.Kill, getKillTarget) then return end
        if CFG.Aura.Enabled and attackStep(CFG.Aura, getAuraTarget) then return end
        if CFG.Chop.Enabled then attackStep(CFG.Chop, getChopTarget) end
    end
end

-- ══════════════════════════════════════
--  AUTO PROMPT / INSTANT PROMPT
-- ══════════════════════════════════════
local function setInstantPrompts(on)
    CFG.Prompt.Instant = on
    if not on then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then d.HoldDuration = 0 end
    end
    if not Actions.instantConn then
        Actions.instantConn = bind(workspace.DescendantAdded, function(d)
            if CFG.Prompt.Instant and d:IsA("ProximityPrompt") then d.HoldDuration = 0 end
        end)
    end
end

task.spawn(function()
    while alive do
        task.wait(rand(0.25, 0.45))
        if CFG.Prompt.Enabled and CAP.Prompt then
            local hrp = myRoot()
            if hrp then
                local best, bestD = nil, CFG.Prompt.Range
                for _, pr in ipairs(Cache.prompts) do
                    if pr.Parent and pr.Enabled then
                        local par = pr.Parent
                        local pos
                        if par:IsA("BasePart") then pos = par.Position
                        elseif par:IsA("Attachment") then pos = par.WorldPosition end
                        if pos then
                            local d = (pos - hrp.Position).Magnitude
                            if d <= bestD then best, bestD = pr, d end
                        end
                    end
                end
                if best then pcall(fireproximityprompt, best) end
            end
        end
    end
end)

-- ══════════════════════════════════════
--  TOOLS: item inspector / remote spy / hooks
-- ══════════════════════════════════════
local Spy = { buf = {} }

local function itemPos(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, cf = pcall(function() return obj:GetPivot() end)
        return ok and cf.Position or nil
    end
    if obj:IsA("Tool") then
        local h = obj:FindFirstChild("Handle")
        return h and h.Position or nil
    end
    return nil
end

local function scanNearby(radius)
    local hrp = myRoot()
    if not hrp then return {} end
    local out, seen = {}, {}
    for _, o in ipairs(workspace:GetDescendants()) do
        local target = nil
        if o:IsA("Tool") then
            target = o
        elseif o:IsA("ProximityPrompt") or o:IsA("ClickDetector") then
            target = o.Parent
        elseif (o:IsA("Model") or o:IsA("BasePart")) and isItemModel(o) then
            target = o
        end
        if target and not seen[target] then
            seen[target] = true
            local skip = target:IsDescendantOf(lp) or Players:GetPlayerFromCharacter(target) ~= nil
            if not skip and lp.Character and target:IsDescendantOf(lp.Character) then skip = true end
            if not skip then
                local anc = target.Parent
                if anc and anc:IsA("Model") and anc:FindFirstChildOfClass("Humanoid") then skip = true end
            end
            if not skip then
                local p = itemPos(target)
                if p then
                    local d = (p - hrp.Position).Magnitude
                    if d <= radius then out[#out + 1] = { obj = target, pos = p, dist = math.floor(d) } end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    while #out > 40 do table.remove(out) end
    return out
end

local function describe(item)
    local obj = item.obj
    local L = {}
    L[#L + 1] = "Name: " .. obj.Name
    L[#L + 1] = "Class: " .. obj.ClassName
    L[#L + 1] = "Path: " .. obj:GetFullName()
    L[#L + 1] = "Distance: " .. item.dist
    L[#L + 1] = string.format("Pos: %.1f, %.1f, %.1f", item.pos.X, item.pos.Y, item.pos.Z)
    local attrs = {}
    for k, v in pairs(obj:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
    if #attrs > 0 then L[#L + 1] = "Attributes: " .. table.concat(attrs, "; ") end

    local ids, vals, prompts = {}, {}, {}
    local function inspect(x)
        if x:IsA("Tool") then
            ids[#ids + 1] = "Tool.TextureId=" .. x.TextureId
            if x.ToolTip ~= "" then ids[#ids + 1] = "ToolTip=" .. x.ToolTip end
        elseif x:IsA("MeshPart") then
            ids[#ids + 1] = "MeshId=" .. x.MeshId
            if x.TextureID ~= "" then ids[#ids + 1] = "TextureID=" .. x.TextureID end
        elseif x:IsA("SpecialMesh") then
            ids[#ids + 1] = "SpecialMesh.MeshId=" .. x.MeshId
            if x.TextureId ~= "" then ids[#ids + 1] = "SpecialMesh.TextureId=" .. x.TextureId end
        elseif x:IsA("Decal") then
            ids[#ids + 1] = "Texture=" .. x.Texture
        elseif x:IsA("ValueBase") then
            vals[#vals + 1] = x.Name .. "(" .. x.ClassName .. ")=" .. tostring(x.Value)
        elseif x:IsA("ProximityPrompt") then
            prompts[#prompts + 1] = "Prompt Action='" .. x.ActionText .. "' Object='" .. x.ObjectText
                .. "' Hold=" .. x.HoldDuration
        elseif x:IsA("ClickDetector") then
            prompts[#prompts + 1] = "ClickDetector"
        end
    end
    inspect(obj)
    local n = 0
    for _, d in ipairs(obj:GetDescendants()) do
        n = n + 1
        if n > 60 then break end
        inspect(d)
        for k, v in pairs(d:GetAttributes()) do
            if tostring(k):lower():find("id") then attrs[#attrs + 1] = d.Name .. "." .. k .. "=" .. tostring(v) end
        end
    end
    if #ids > 0 then L[#L + 1] = "IDs: " .. table.concat(ids, " | ") end
    if #vals > 0 then L[#L + 1] = "Values: " .. table.concat(vals, " | ") end
    if #prompts > 0 then L[#L + 1] = table.concat(prompts, " | ") end
    return table.concat(L, "\n")
end

-- Remote spy view
local function argStr(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return '"' .. v:sub(1, 60) .. '"' end
    if t == "Instance" then
        local ok, p = pcall(function() return v:GetFullName() end)
        return ok and p or "Instance"
    end
    if t == "table" then
        if depth > 1 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 6 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. "=" .. argStr(x, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function spyRows()
    local ignore = parseKeys(CFG.Spy.Ignore)
    local rows, idx, b = {}, {}, Spy.buf
    for i = #b, 1, -1 do
        local e = b[i]
        pcall(function()
            if not nameHasKey(e.self.Name, ignore) then
                local args = {}
                for k = 1, e.args.n do args[#args + 1] = argStr(e.args[k]) end
                local line = (e.method == "FireServer" and "FS " or "IS ")
                    .. e.self:GetFullName() .. "(" .. table.concat(args, ", ") .. ")"
                if idx[line] then
                    idx[line].count = idx[line].count + 1
                elseif #rows < 30 then
                    local r = { line = line, count = 1 }
                    rows[#rows + 1] = r
                    idx[line] = r
                end
            end
        end)
    end
    return rows
end

-- Hooks (ติดตั้งเฉพาะเมื่อ executor รองรับ)
if CAP.Hook then
    safe("hook:namecall", function()
        local old
        local fn = function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" or method == "Kick" or method == "kick" then
                if not checkcaller() then
                    if CFG.Bypass.BlockKick and self == lp and method:lower() == "kick" then
                        return
                    end
                    if CFG.Spy.Enabled and (method == "FireServer" or method == "InvokeServer") then
                        local b = Spy.buf
                        b[#b + 1] = { self = self, method = method, args = table.pack(...) }
                        if #b > 300 then table.remove(b, 1) end
                    end
                end
                if setnamecallmethod then setnamecallmethod(method) end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(fn) or fn)
    end)

    -- สปูฟการอ่าน WalkSpeed (ติดตั้งตอนใช้โหมด WalkSpeed เท่านั้น เพื่อไม่ถ่วง __index)
    Actions.ensureIndexHook = function()
        if Actions.indexHooked then return end
        Actions.indexHooked = true
        safe("hook:index", function()
            local old
            local fn = function(self, key)
                if key == "WalkSpeed" and CFG.Bypass.SpoofReads and CFG.Speed.Enabled
                   and CFG.Speed.Mode == "WalkSpeed" and not checkcaller() then
                    if typeof(self) == "Instance" and self.ClassName == "Humanoid"
                       and self.Parent == lp.Character then
                        return CFG.Speed.Default
                    end
                end
                return old(self, key)
            end
            old = hookmetamethod(game, "__index", newcclosure and newcclosure(fn) or fn)
        end)
    end
end

-- Anti-AFK
bind(lp.Idled, function()
    if CFG.Bypass.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)
task.spawn(function()
    while alive do
        task.wait(rand(200, 280))
        if CFG.Bypass.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--  GUI  (สร้างโลโก้ก่อน เพื่อให้เห็นเสมอแม้ส่วนอื่นจะ error)
-- ══════════════════════════════════════════════════════════
local function randName()
    local t = {}
    for i = 1, 12 do t[i] = string.char(math.random(97, 122)) end
    return table.concat(t)
end

local function pickParent()
    local okCG, cg = pcall(function() return game:GetService("CoreGui") end)
    if okCG and cg then
        local okT = pcall(function()
            local f = Instance.new("Folder"); f.Parent = cg; f:Destroy()
        end)
        if okT then return cg end
    end
    local okH, h = pcall(function() return gethui and gethui() end)
    if okH and h then return h end
    return lp:WaitForChild("PlayerGui")
end

local GUI = Instance.new("ScreenGui")
GUI.Name = randName()
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.IgnoreGuiInset = true
GUI.DisplayOrder = 999
pcall(function() if syn and syn.protect_gui then syn.protect_gui(GUI) end end)
do
    local target = pickParent()
    local ok = pcall(function() GUI.Parent = target end)
    if not ok or not GUI.Parent then GUI.Parent = lp:WaitForChild("PlayerGui") end
end

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
    return c
end
local function stroke(inst, color, thick, transp)
    local s = Instance.new("UIStroke")
    s.Color = color; s.Thickness = thick or 1.5; s.Transparency = transp or 0.25
    s.Parent = inst
    return s
end
local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch
end

local ACCENT = Color3.fromRGB(70, 110, 255)
local C = {
    red = Color3.fromRGB(255, 70, 90),     pink = Color3.fromRGB(255, 120, 200),
    lime = Color3.fromRGB(150, 230, 80),   blue = Color3.fromRGB(100, 170, 255),
    orange = Color3.fromRGB(255, 160, 60), yellow = Color3.fromRGB(240, 220, 0),
    cyan = Color3.fromRGB(0, 200, 255),    green = Color3.fromRGB(60, 230, 100),
    teal = Color3.fromRGB(70, 220, 200),   purple = Color3.fromRGB(180, 80, 255),
}

-- Toast
local Toast = Instance.new("TextLabel")
Toast.Size = UDim2.new(0, 300, 0, 28)
Toast.AnchorPoint = Vector2.new(0.5, 1)
Toast.Position = UDim2.new(0.5, 0, 1, -90)
Toast.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Toast.BackgroundTransparency = 0.25
Toast.TextColor3 = WHITE
Toast.TextSize = 13
Toast.Font = Enum.Font.GothamMedium
Toast.Visible = false
Toast.ZIndex = 50
Toast.Parent = GUI
corner(Toast, 8)
do
    local id = 0
    notify = function(msg)
        print("[Zero] " .. tostring(msg))
        id = id + 1
        local my = id
        Toast.Text = tostring(msg)
        Toast.Visible = true
        task.delay(2.5, function()
            if my == id and Toast then Toast.Visible = false end
        end)
    end
end

-- LOGO (สร้างก่อนทุกอย่าง)
local Main -- หน้าต่างหลัก (สร้างทีหลัง)
local Logo = Instance.new("TextButton")
Logo.Name = "Logo"
Logo.Text = "Z"
Logo.Size = UDim2.new(0, 44, 0, 44)
Logo.Position = UDim2.new(0, 14, 0.35, 0)
Logo.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Logo.TextColor3 = Color3.fromRGB(110, 150, 255)
Logo.TextSize = 24
Logo.Font = Enum.Font.GothamBlack
Logo.AutoButtonColor = false
Logo.BorderSizePixel = 0
Logo.ZIndex = 40
Logo.Parent = GUI
corner(Logo, 12)
stroke(Logo, ACCENT, 1.5, 0.15)

do
    local down, moved, startPos, startUDim = false, false, nil, nil
    Logo.InputBegan:Connect(function(i)
        if isPress(i) then
            down = true; moved = false
            startPos = i.Position; startUDim = Logo.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    if down and not moved and Main then Main.Visible = not Main.Visible end
                    down = false
                end
            end)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if down and isMove(i) then
            local d = i.Position - startPos
            if d.Magnitude > 8 then moved = true end
            if moved then
                Logo.Position = UDim2.new(startUDim.X.Scale, startUDim.X.Offset + d.X,
                                          startUDim.Y.Scale, startUDim.Y.Offset + d.Y)
            end
        end
    end)
end

-- ── Main window ──
local MIN_W, MIN_H, MAX_W, MAX_H = 260, 280, 560, 760

Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 340, 0, 420)
Main.Position = UDim2.new(0, 76, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Visible = false
Main.Parent = GUI
corner(Main, 12)
stroke(Main, ACCENT)

local TBar = Instance.new("Frame")
TBar.Size = UDim2.new(1, 0, 0, 36)
TBar.BackgroundColor3 = Color3.fromRGB(12, 12, 26)
TBar.BorderSizePixel = 0
TBar.Parent = Main
corner(TBar, 12)

do
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = WHITE
    line.BorderSizePixel = 0
    line.Parent = TBar
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(60, 100, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 60, 255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(60, 200, 255)),
    })
    g.Parent = line

    local title = Instance.new("TextLabel")
    title.Text = "ZERO  v3.0"
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(210, 220, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = TBar

    local close = Instance.new("TextButton")
    close.Text = "X"
    close.Size = UDim2.new(0, 26, 0, 22)
    close.Position = UDim2.new(1, -32, 0.5, -11)
    close.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
    close.TextColor3 = Color3.fromRGB(255, 120, 130)
    close.TextSize = 12
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    close.Parent = TBar
    corner(close, 6)
    close.MouseButton1Click:Connect(function() Main.Visible = false end)
end

local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(1, 0, 0, 32)
TabBar.Position = UDim2.new(0, 0, 0, 36)
TabBar.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = Main
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    l.Padding = UDim.new(0, 4)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = TabBar
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 8); p.PaddingRight = UDim.new(0, 8)
    p.Parent = TabBar
end

local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -68)
Body.Position = UDim2.new(0, 0, 0, 68)
Body.BackgroundTransparency = 1
Body.ClipsDescendants = true
Body.Parent = Main

local T = { tabs = {}, first = nil, n = 0 }
local orderCounter = setmetatable({}, { __mode = "k" })
local function order(page)
    orderCounter[page] = (orderCounter[page] or 0) + 1
    return orderCounter[page]
end

local function selectTab(name)
    for n, t in pairs(T.tabs) do
        local on = (n == name)
        t.btn.BackgroundColor3 = on and t.color or Color3.fromRGB(22, 22, 38)
        t.btn.TextColor3 = on and Color3.fromRGB(8, 8, 16) or Color3.fromRGB(170, 178, 210)
        t.page.Visible = on
    end
end

local function newTab(name, color)
    T.n = T.n + 1
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.Size = UDim2.new(0, 62, 0, 24)
    btn.LayoutOrder = T.n
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = TabBar
    corner(btn, 6)

    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = ACCENT
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Body
    do
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 5)
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Parent = page
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 10); p.PaddingRight = UDim.new(0, 10)
        p.PaddingTop = UDim.new(0, 8); p.PaddingBottom = UDim.new(0, 30)
        p.Parent = page
    end

    T.tabs[name] = { btn = btn, page = page, color = color }
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    if not T.first then T.first = name end
    return page
end

-- ══════════════════════════════════════
--  WIDGETS
-- ══════════════════════════════════════
local W = {}
local OFF = Color3.fromRGB(32, 32, 48)
local KNOB_ON, KNOB_OFF = UDim2.new(1, -18, 0.5, -7.5), UDim2.new(0, 3, 0.5, -7.5)

function W.section(page, text, color)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 24)
    f.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    f.BorderSizePixel = 0
    f.LayoutOrder = order(page)
    f.Parent = page
    corner(f, 6)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0.65, 0)
    bar.Position = UDim2.new(0, 0, 0.175, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.Parent = f
    corner(bar, 2)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text:upper()
    lbl.Size = UDim2.new(1, -14, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
end

function W.label(page, text, color)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Size = UDim2.new(1, 0, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(140, 148, 180)
    l.TextSize = 11
    l.Font = Enum.Font.Gotham
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order(page)
    l.Parent = page
    return l
end

function W.spacer(page)
    local s = Instance.new("Frame")
    s.Size = UDim2.new(1, 0, 0, 4)
    s.BackgroundTransparency = 1
    s.LayoutOrder = order(page)
    s.Parent = page
end

function W.row(page, h)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, h or 34)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 25)
    row.BorderSizePixel = 0
    row.LayoutOrder = order(page)
    row.Parent = page
    corner(row, 6)
    return row
end

function W.mini(parent, text, color, rightOffset, width, cb)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Size = UDim2.new(0, width, 0, 24)
    b.Position = UDim2.new(1, -(rightOffset + width), 0.5, -12)
    b.BackgroundColor3 = Color3.fromRGB(26, 26, 46)
    b.TextColor3 = color
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = parent
    corner(b, 5)
    b.MouseButton1Click:Connect(cb)
    return b
end

function W.toggle(page, text, default, color, cb)
    local on = default and true or false
    local row = W.row(page, 34)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, -62, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(185, 192, 218)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = row
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 42, 0, 21)
    bg.Position = UDim2.new(1, -50, 0.5, -10.5)
    bg.BackgroundColor3 = on and color or OFF
    bg.BorderSizePixel = 0
    bg.Parent = row
    corner(bg, 11)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 15, 0, 15)
    knob.Position = on and KNOB_ON or KNOB_OFF
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel = 0
    knob.Parent = bg
    corner(knob, 8)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        on = not on
        TweenService:Create(bg, TweenInfo.new(0.18), { BackgroundColor3 = on and color or OFF }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), { Position = on and KNOB_ON or KNOB_OFF }):Play()
        safe("toggle:" .. text, cb, on)
    end)
end

function W.slider(page, text, minV, maxV, defV, color, cb)
    local val = defV or minV
    local row = W.row(page, 52)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.65, 0, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(185, 192, 218)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local valLbl = Instance.new("TextLabel")
    valLbl.Text = tostring(val)
    valLbl.Size = UDim2.new(0.3, 0, 0, 22)
    valLbl.Position = UDim2.new(0.7, -10, 0, 5)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3 = color
    valLbl.TextSize = 12
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 6)
    track.Position = UDim2.new(0, 10, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    track.BorderSizePixel = 0
    track.Active = true
    track.Parent = row
    corner(track, 3)
    local pct = (val - minV) / (maxV - minV)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 3)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(pct, -7, 0.5, -7)
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 7)

    local drag = false
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        val = math.floor(minV + (maxV - minV) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valLbl.Text = tostring(val)
        safe("slider:" .. text, cb, val)
    end
    track.InputBegan:Connect(function(i)
        if isPress(i) then
            drag = true
            page.ScrollingEnabled = false
            update(i.Position.X)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if drag and isMove(i) then update(i.Position.X) end
    end)
    bind(UIS.InputEnded, function(i)
        if isPress(i) and drag then
            drag = false
            page.ScrollingEnabled = true
        end
    end)
end

function W.button(page, text, color, cb)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = Color3.fromRGB(22, 22, 40)
    b.TextColor3 = color
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.LayoutOrder = order(page)
    b.Parent = page
    corner(b, 6)
    stroke(b, color, 1, 0.6)
    b.MouseButton1Click:Connect(function() safe("button:" .. text, cb) end)
    return b
end

function W.textbox(page, text, default, color, cb)
    local row = W.row(page, 56)
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(185, 192, 218)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local box = Instance.new("TextBox")
    box.Text = default
    box.ClearTextOnFocus = false
    box.Size = UDim2.new(1, -20, 0, 24)
    box.Position = UDim2.new(0, 10, 0, 26)
    box.BackgroundColor3 = Color3.fromRGB(24, 24, 42)
    box.TextColor3 = color
    box.TextSize = 12
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.BorderSizePixel = 0
    box.Parent = row
    corner(box, 5)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = box
    box.FocusLost:Connect(function() safe("textbox:" .. text, cb, box.Text) end)
    return box
end

function W.listBox(page)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundTransparency = 1
    f.LayoutOrder = order(page)
    f.Parent = page
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 4)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = f
    return f
end

function W.clear(box)
    for _, c in ipairs(box:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

-- rows = { {text=, cb=, color=?, selected=?}, ... }
function W.fill(box, rows, accent)
    W.clear(box)
    if #rows == 0 then
        local l = Instance.new("TextLabel")
        l.Text = "(ไม่พบรายการ)"
        l.Size = UDim2.new(1, 0, 0, 22)
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.fromRGB(120, 128, 160)
        l.TextSize = 11
        l.Font = Enum.Font.Gotham
        l.Parent = box
        return
    end
    for i, r in ipairs(rows) do
        local b = Instance.new("TextButton")
        b.Text = r.text
        b.Size = UDim2.new(1, 0, 0, 30)
        b.LayoutOrder = i
        b.BackgroundColor3 = r.selected and accent or Color3.fromRGB(20, 20, 36)
        b.TextColor3 = r.selected and Color3.fromRGB(8, 8, 16) or Color3.fromRGB(190, 196, 224)
        b.TextSize = 11
        b.Font = Enum.Font.Gotham
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextTruncate = Enum.TextTruncate.AtEnd
        b.BorderSizePixel = 0
        b.Parent = box
        corner(b, 6)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = b
        b.MouseButton1Click:Connect(function() safe("list row", r.cb) end)
    end
end

-- ══════════════════════════════════════
--  TABS
-- ══════════════════════════════════════
local P = {}
P.combat = newTab("Combat", C.red)
P.target = newTab("Target", C.pink)
P.farm   = newTab("Farm",   C.lime)
P.move   = newTab("Move",   C.blue)
P.warp   = newTab("Warp",   C.orange)
P.map    = newTab("Map",    C.yellow)
P.tools  = newTab("Tools",  C.cyan)
P.esp    = newTab("ESP",    C.green)
P.bypass = newTab("Bypass", C.teal)
P.ui     = newTab("UI",     C.purple)

local function fmt(p) return string.format("%.0f, %.0f, %.0f", p[1], p[2], p[3]) end

-- ── COMBAT ──
safe("tab:Combat", function()
    local pg = P.combat
    W.section(pg, "Kill Aura", C.red)
    W.label(pg, "ต้องถืออาวุธ (Tool) อยู่ในมือ ถึงจะทำงาน")
    W.toggle(pg, "Kill Aura", false, C.red, function(v) CFG.Aura.Enabled = v; if v then scanNow() end end)
    W.slider(pg, "Range (studs)", 5, 30, 14, C.red, function(v) CFG.Aura.Range = v end)
    W.slider(pg, "Attacks / sec", 1, 12, 4, C.red, function(v) CFG.Aura.CPS = v end)
    W.spacer(pg)
    W.section(pg, "Targets", C.red)
    W.toggle(pg, "Players", true, C.red, function(v) CFG.Aura.Players = v end)
    W.toggle(pg, "Monsters / NPC", true, C.red, function(v) CFG.Aura.Monsters = v; if v then scanNow() end end)
    W.toggle(pg, "Wall Check", true, C.red, function(v) CFG.Aura.WallCheck = v end)
    W.spacer(pg)
    W.section(pg, "Attack method (ใช้ร่วมทุกโหมด)", C.red)
    W.toggle(pg, "Touch Hit (อาวุธระยะประชิด)", true, C.red, function(v) CFG.Combat.TouchHit = v end)
    W.toggle(pg, "Face Target", true, C.red, function(v) CFG.Combat.Face = v end)
    if not CAP.Touch then W.label(pg, "Executor นี้ไม่มี firetouchinterface — Touch Hit จะไม่ทำงาน", C.red) end
end)

-- ── TARGET ──
safe("tab:Target", function()
    local pg = P.target
    W.section(pg, "Kill Player", C.pink)
    local selLabel = W.label(pg, "Target: (none)", C.pink)
    W.toggle(pg, "Kill Selected Player", false, C.pink, function(v) CFG.Kill.Enabled = v end)
    W.toggle(pg, "Follow Target (เดินเข้าหา)", false, C.pink, function(v) CFG.Kill.Follow = v end)
    W.slider(pg, "Range (studs)", 5, 30, 14, C.pink, function(v) CFG.Kill.Range = v end)
    W.slider(pg, "Attacks / sec", 1, 12, 5, C.pink, function(v) CFG.Kill.CPS = v end)
    W.spacer(pg)
    W.section(pg, "Players in server (แตะชื่อเพื่อเลือก)", C.pink)
    local box = W.listBox(pg)

    local function setTarget(pl)
        CFG.Kill.Target = pl
        selLabel.Text = pl and ("Target: " .. pl.DisplayName .. "  (@" .. pl.Name .. ")") or "Target: (none)"
    end
    local function refresh()
        if not alive then return end
        local rows = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= lp then
                rows[#rows + 1] = {
                    text = pl.DisplayName .. "  (@" .. pl.Name .. ")",
                    selected = (CFG.Kill.Target == pl),
                    cb = function() setTarget(pl); Actions.refreshTarget() end,
                }
            end
        end
        W.fill(box, rows, C.pink)
    end
    Actions.refreshTarget = refresh
    Actions.clearTarget = function() setTarget(nil) end
    W.button(pg, "Refresh list", C.pink, refresh)
    W.button(pg, "Clear target", C.pink, function() setTarget(nil); refresh() end)
    refresh()
end)

-- ── FARM ──
safe("tab:Farm", function()
    local pg = P.farm
    W.section(pg, "Chop Aura", C.lime)
    W.label(pg, "ต้องถือขวาน/เครื่องมือตัดไม้ ต้นไม้จะถูกจับจากชื่อ (Keywords)")
    W.toggle(pg, "Chop Aura", false, C.lime, function(v) CFG.Chop.Enabled = v; if v then scanNow() end end)
    W.slider(pg, "Range (studs)", 5, 30, 12, C.lime, function(v) CFG.Chop.Range = v end)
    W.slider(pg, "Swings / sec", 1, 10, 3, C.lime, function(v) CFG.Chop.CPS = v end)
    W.textbox(pg, "Keywords (คั่นด้วย ,)", CFG.Chop.Keywords, C.lime, function(txt)
        CFG.Chop.Keywords = txt
        treeKeys = parseKeys(txt)
        scanNow()
    end)
    W.button(pg, "Rescan now", C.lime, scanNow)
    W.spacer(pg)
    W.section(pg, "Prompts (กดปุ่ม E อัตโนมัติ)", C.lime)
    W.label(pg, "ใช้กับเกมที่เก็บของ/เปิดหีบ/คราฟต์ผ่านปุ่ม ProximityPrompt")
    W.toggle(pg, "Auto Prompt", false, C.lime, function(v) CFG.Prompt.Enabled = v; if v then scanNow() end end)
    W.slider(pg, "Prompt range", 5, 30, 12, C.lime, function(v) CFG.Prompt.Range = v end)
    W.toggle(pg, "Instant Prompts (HoldDuration = 0)", false, C.lime, setInstantPrompts)
    if not CAP.Prompt then W.label(pg, "Executor นี้ไม่มี fireproximityprompt — Auto Prompt จะไม่ทำงาน", C.red) end
end)

-- ── MOVE ──
safe("tab:Move", function()
    local pg = P.move
    W.section(pg, "Speed", C.blue)
    W.toggle(pg, "Speed Hack", false, C.blue, function(v)
        CFG.Speed.Enabled = v
        if v and CFG.Speed.Mode == "WalkSpeed" and Actions.ensureIndexHook and CFG.Bypass.SpoofReads then
            Actions.ensureIndexHook()
        end
        applySpeed()
    end)
    W.slider(pg, "Walk Speed", 16, 350, 50, C.blue, function(v)
        CFG.Speed.Value = v
        if CFG.Speed.Enabled then applySpeed() end
    end)
    W.label(pg, "โหมดความเร็วเลือกได้ในแท็บ Bypass (CFrame = ไม่แตะ WalkSpeed)")
    W.spacer(pg)
    W.section(pg, "Fly (ลอย)", C.blue)
    W.label(pg, "ใช้จอยเดินตามทิศที่กล้องมอง + ปุ่ม UP / DN ที่ขึ้นข้างจอ")
    W.toggle(pg, "Fly", false, C.blue, setFly)
    W.slider(pg, "Fly speed", 10, 200, 40, C.blue, function(v) CFG.Fly.Speed = v end)
    W.spacer(pg)
    W.section(pg, "Other", C.blue)
    W.toggle(pg, "Infinite Jump", false, C.blue, function(v) CFG.InfJump = v end)
    W.toggle(pg, "Noclip (เดินทะลุกำแพง)", false, C.blue, function(v)
        CFG.Noclip.Enabled = v
        if not v then restoreCollision() end
    end)
end)

-- ── WARP (บันทึกจุด 1-10 + ชื่อเอง) ──
safe("tab:Warp", function()
    local pg = P.warp
    W.section(pg, "Current location", C.orange)
    local locLabel = W.label(pg, "X: -  Y: -  Z: -", C.orange)
    Actions.locLabel = locLabel
    W.button(pg, "Copy coordinates", C.orange, function()
        local r = myRoot()
        if r then
            local p = r.Position
            notify(copy(string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)) and "คัดลอกพิกัดแล้ว" or "executor ไม่รองรับ clipboard")
        end
    end)
    W.spacer(pg)
    W.section(pg, "Teleport mode", C.orange)
    W.toggle(pg, "Safe TP (วาร์ปแบบเลื่อนต่อเนื่อง)", true, C.orange, function(v) CFG.Bypass.SafeTP = v end)
    W.slider(pg, "Safe TP speed (studs/s)", 50, 400, 180, C.orange, function(v) CFG.Bypass.TPSpeed = v end)
    W.button(pg, "Cancel teleport", C.orange, function() tpToken = tpToken + 1 end)
    W.spacer(pg)
    W.section(pg, "Slots 1-10", C.orange)
    W.label(pg, "SAVE = บันทึกตำแหน่งปัจจุบัน | GO = วาร์ป | X = ลบ " .. (CAP.Files and "(บันทึกลงไฟล์ ใช้ได้ข้ามรอบ)" or "(executor นี้ไม่มี writefile: จะจำได้จนกว่าจะปิดเกม)"))
    local slotLabels = {}
    local function refreshSlot(i)
        local p = Store.slots[tostring(i)]
        slotLabels[i].Text = i .. ":  " .. (p and fmt(p) or "(empty)")
        slotLabels[i].TextColor3 = p and Color3.fromRGB(230, 235, 255) or Color3.fromRGB(110, 118, 150)
    end
    for i = 1, 10 do
        local row = W.row(pg, 34)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -150, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = row
        slotLabels[i] = lbl
        W.mini(row, "GO", C.green, 6, 38, function()
            local p = Store.slots[tostring(i)]
            if p then warpToPos(p) else notify("Slot " .. i .. " ยังว่าง") end
        end)
        W.mini(row, "SAVE", C.orange, 48, 44, function()
            local r = myRoot()
            if not r then return end
            local pos = r.Position
            Store.slots[tostring(i)] = { math.floor(pos.X * 10) / 10, math.floor(pos.Y * 10) / 10, math.floor(pos.Z * 10) / 10 }
            saveStore(); refreshSlot(i); notify("บันทึก Slot " .. i)
        end)
        W.mini(row, "X", C.red, 98, 26, function()
            Store.slots[tostring(i)] = nil
            saveStore(); refreshSlot(i)
        end)
        refreshSlot(i)
    end
    W.spacer(pg)
    W.section(pg, "Named locations", C.orange)
    local nameBox = W.textbox(pg, "ชื่อจุด (แล้วกด Save here)", "", C.orange, function() end)
    local namedList = W.listBox(pg)
    local function rebuildNamed()
        W.clear(namedList)
        local names = {}
        for n in pairs(Store.named) do names[#names + 1] = n end
        table.sort(names)
        for i, n in ipairs(names) do
            local p = Store.named[n]
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 32)
            row.BackgroundColor3 = Color3.fromRGB(14, 14, 25)
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            row.Parent = namedList
            corner(row, 6)
            local lbl = Instance.new("TextLabel")
            lbl.Text = n .. "   " .. fmt(p)
            lbl.Size = UDim2.new(1, -90, 1, 0)
            lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(210, 216, 240)
            lbl.TextSize = 11
            lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.Parent = row
            W.mini(row, "GO", C.green, 6, 38, function() warpToPos(p) end)
            W.mini(row, "X", C.red, 48, 26, function()
                Store.named[n] = nil; saveStore(); rebuildNamed()
            end)
        end
    end
    W.button(pg, "Save here as name", C.orange, function()
        local name = (nameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local r = myRoot()
        if #name == 0 then notify("ใส่ชื่อจุดก่อน"); return end
        if not r then return end
        local pos = r.Position
        Store.named[name] = { math.floor(pos.X * 10) / 10, math.floor(pos.Y * 10) / 10, math.floor(pos.Z * 10) / 10 }
        saveStore(); rebuildNamed(); notify("บันทึก: " .. name)
    end)
    W.button(pg, "Copy all saved (Lua)", C.orange, function()
        local L = { "-- PlaceId " .. tostring(game.PlaceId), "local Slots = {" }
        for i = 1, 10 do
            local p = Store.slots[tostring(i)]
            if p then L[#L + 1] = string.format("  [%d] = Vector3.new(%.1f, %.1f, %.1f),", i, p[1], p[2], p[3]) end
        end
        L[#L + 1] = "}"
        L[#L + 1] = "local Named = {"
        for n, p in pairs(Store.named) do
            L[#L + 1] = string.format("  [%q] = Vector3.new(%.1f, %.1f, %.1f),", n, p[1], p[2], p[3])
        end
        L[#L + 1] = "}"
        notify(copy(table.concat(L, "\n")) and "คัดลอกแล้ว" or "executor ไม่รองรับ clipboard")
    end)
    rebuildNamed()
end)

-- ── MAP (วาร์ปเลือกชื่อผู้เล่น / Spawn / Landmarks) ──
safe("tab:Map", function()
    local pg = P.map
    W.section(pg, "Players (แตะชื่อเพื่อวาร์ปไปหา)", C.yellow)
    local pbox = W.listBox(pg)
    local function refreshTP()
        if not alive then return end
        local rows = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= lp then
                rows[#rows + 1] = {
                    text = pl.DisplayName .. "  (@" .. pl.Name .. ")",
                    cb = function()
                        local ch = pl.Character
                        local root = ch and getRoot(ch)
                        if root then
                            teleportTo(root.CFrame * CFrame.new(0, 0, 4))
                            notify("วาร์ปไปหา " .. pl.DisplayName)
                        else
                            notify(pl.DisplayName .. " ยังไม่มีตัวละคร")
                        end
                    end,
                }
            end
        end
        W.fill(pbox, rows, C.yellow)
    end
    Actions.refreshTP = refreshTP
    W.button(pg, "Refresh players", C.yellow, refreshTP)
    refreshTP()

    W.spacer(pg)
    W.section(pg, "Spawn points", C.yellow)
    local sbox = W.listBox(pg)
    W.button(pg, "Scan spawn points", C.yellow, function()
        local rows = {}
        for _, o in ipairs(workspace:GetDescendants()) do
            if o:IsA("SpawnLocation") then
                local p = o.Position
                rows[#rows + 1] = {
                    text = o.Name .. "   " .. fmt({ p.X, p.Y, p.Z }),
                    cb = function() teleportTo(CFrame.new(p + Vector3.new(0, 4, 0))) end,
                }
            end
            if #rows >= 40 then break end
        end
        W.fill(sbox, rows, C.yellow)
    end)

    W.spacer(pg)
    W.section(pg, "Landmarks (สถานที่ในแมพ)", C.yellow)
    W.label(pg, "สแกนหาสิ่งปลูกสร้าง/จุดสำคัญจากชื่อ แล้วแตะเพื่อวาร์ป (เรียงตามระยะใกล้→ไกล)")
    local keyBox = W.textbox(pg, "Keywords (คั่นด้วย ,)",
        "station,shop,store,bank,saloon,tailor,spawn,lobby,house,base,castle,town,market,bridge,tower,dock,gate,church,hotel",
        C.yellow, function() end)
    local lbox = W.listBox(pg)
    W.button(pg, "Scan landmarks", C.yellow, function()
        local keys = parseKeys(keyBox.Text)
        local hrp = myRoot()
        local origin = hrp and hrp.Position or Vector3.zero
        local found, seen = {}, {}
        for _, o in ipairs(workspace:GetDescendants()) do
            if (o:IsA("Model") or o:IsA("BasePart")) and o.Parent
               and not (o:IsA("BasePart") and o.Parent:IsA("Model"))
               and not Players:GetPlayerFromCharacter(o) and nameHasKey(o.Name, keys) then
                local p = itemPos(o)
                if p then
                    local sig = o.Name .. math.floor(p.X / 8) .. "_" .. math.floor(p.Z / 8)
                    if not seen[sig] then
                        seen[sig] = true
                        found[#found + 1] = { name = o.Name, pos = p, d = (p - origin).Magnitude }
                    end
                end
            end
        end
        table.sort(found, function(a, b) return a.d < b.d end)
        local rows = {}
        for i = 1, math.min(#found, 60) do
            local f = found[i]
            rows[#rows + 1] = {
                text = f.name .. "   " .. math.floor(f.d) .. "m",
                cb = function() teleportTo(CFrame.new(f.pos + Vector3.new(0, 5, 0))) end,
            }
        end
        W.fill(lbox, rows, C.yellow)
        notify("พบ " .. #found .. " จุด")
    end)
end)

-- ── TOOLS ──
safe("tab:Tools", function()
    local pg = P.tools

    -- Nearby item inspector
    W.section(pg, "Nearby items (ชื่อ / ID / ตำแหน่ง)", C.cyan)
    local radius = 60
    W.slider(pg, "Scan radius (studs)", 10, 300, 60, C.cyan, function(v) radius = v end)
    local ibox = W.listBox(pg)
    local detail = W.label(pg, "แตะรายการเพื่อดูรายละเอียด", C.cyan)
    local selected = nil
    W.button(pg, "Scan nearby", C.cyan, function()
        local items = scanNearby(radius)
        local rows = {}
        for _, it in ipairs(items) do
            rows[#rows + 1] = {
                text = it.obj.Name .. "  [" .. it.obj.ClassName .. "]  " .. it.dist .. "m",
                cb = function()
                    selected = it
                    local ok, txt = pcall(describe, it)
                    detail.Text = ok and txt or ("describe error: " .. tostring(txt))
                end,
            }
        end
        W.fill(ibox, rows, C.cyan)
        notify("พบ " .. #items .. " รายการ")
    end)
    W.button(pg, "Copy details", C.cyan, function()
        if selected then notify(copy(detail.Text) and "คัดลอกแล้ว" or "executor ไม่รองรับ clipboard")
        else notify("เลือกรายการก่อน") end
    end)
    W.button(pg, "Warp to item", C.cyan, function()
        if selected and selected.obj.Parent then
            teleportTo(CFrame.new(selected.pos + Vector3.new(0, 4, 0)))
        else notify("เลือกรายการก่อน") end
    end)

    -- Remote spy
    W.spacer(pg)
    W.section(pg, "Remote Spy (ดูว่าเกมส่ง remote อะไรตอนตี/เก็บของ)", C.cyan)
    W.label(pg, "เปิดแล้วลองตีหรือกดปุ่มในเกม จากนั้นกด Refresh ดูชื่อ remote ที่ถูกเรียก")
    if not CAP.Hook then W.label(pg, "Executor นี้ไม่รองรับ hookmetamethod — Remote Spy ใช้ไม่ได้", C.red) end
    W.toggle(pg, "Remote Spy", false, C.cyan, function(v) CFG.Spy.Enabled = v end)
    W.textbox(pg, "Ignore names (คั่นด้วย ,)", CFG.Spy.Ignore, C.cyan, function(txt) CFG.Spy.Ignore = txt end)
    local sbox = W.listBox(pg)
    local lastLines = {}
    local function refreshSpy()
        local rows = {}
        lastLines = {}
        for _, r in ipairs(spyRows()) do
            local line = (r.count > 1 and ("x" .. r.count .. " ") or "") .. r.line
            lastLines[#lastLines + 1] = line
            rows[#rows + 1] = { text = line, cb = function() notify(copy(r.line) and "คัดลอกบรรทัดแล้ว" or "executor ไม่รองรับ clipboard") end }
        end
        W.fill(sbox, rows, C.cyan)
    end
    Actions.spyRefresh = refreshSpy
    W.button(pg, "Refresh log", C.cyan, refreshSpy)
    W.button(pg, "Copy log", C.cyan, function()
        notify(copy(table.concat(lastLines, "\n")) and "คัดลอกแล้ว" or "executor ไม่รองรับ clipboard")
    end)
    W.button(pg, "Clear log", C.cyan, function() Spy.buf = {}; refreshSpy() end)

    -- Server
    W.spacer(pg)
    W.section(pg, "Server", C.cyan)
    W.button(pg, "Rejoin", C.cyan, function() TeleportSvc:Teleport(game.PlaceId, lp) end)
    W.button(pg, "Server hop", C.cyan, function()
        local ok = pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            local data = HttpService:JSONDecode(game:HttpGet(url))
            local pick = {}
            for _, s in ipairs(data.data or {}) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then pick[#pick + 1] = s.id end
            end
            if #pick == 0 then error("no server") end
            TeleportSvc:TeleportToPlaceInstance(game.PlaceId, pick[math.random(#pick)], lp)
        end)
        if not ok then
            notify("หาเซิร์ฟเวอร์ไม่ได้ ลอง Rejoin แทน")
        end
    end)
    W.button(pg, "Copy PlaceId", C.cyan, function() notify(copy(tostring(game.PlaceId)) and "คัดลอก PlaceId" or "ไม่รองรับ clipboard") end)
    W.button(pg, "Copy JobId", C.cyan, function() notify(copy(tostring(game.JobId)) and "คัดลอก JobId" or "ไม่รองรับ clipboard") end)

    -- Visual
    W.spacer(pg)
    W.section(pg, "Visual", C.cyan)
    local fbOrig
    local function setFullbright(on)
        CFG.Misc.Fullbright = on
        if on then
            if not fbOrig then
                fbOrig = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                           FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
                           Ambient = Lighting.Ambient }
            end
            Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 1e6
            Lighting.GlobalShadows = false; Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        elseif fbOrig then
            for k, v in pairs(fbOrig) do Lighting[k] = v end
        end
    end
    Actions.setFullbright = setFullbright
    W.toggle(pg, "Fullbright", false, C.cyan, setFullbright)
    W.toggle(pg, "Custom FOV", false, C.cyan, function(v) CFG.Misc.FOVOn = v end)
    W.slider(pg, "FOV", 40, 120, 70, C.cyan, function(v)
        CFG.Misc.FOV = v
        if CFG.Misc.FOVOn and cam() then cam().FieldOfView = v end
    end)

    -- Stats
    W.spacer(pg)
    W.section(pg, "Stats", C.cyan)
    Actions.statsLabel = W.label(pg, "FPS: -   Ping: -", C.cyan)
end)

-- ── ESP ──
safe("tab:ESP", function()
    local pg = P.esp
    local orange = Color3.fromRGB(255, 120, 0)
    W.section(pg, "Players", C.green)
    W.toggle(pg, "Player ESP", false, C.green, function(v) CFG.ESP.Players.Enabled = v end)
    W.slider(pg, "Max distance", 100, 2000, 1000, C.green, function(v) CFG.ESP.Players.MaxDist = v end)
    W.spacer(pg)
    W.section(pg, "Monsters / Zombies", orange)
    W.toggle(pg, "Monster ESP", false, orange, function(v) CFG.ESP.Monsters.Enabled = v; if v then scanNow() end end)
    W.slider(pg, "Max distance", 100, 1500, 800, orange, function(v) CFG.ESP.Monsters.MaxDist = v end)
    W.spacer(pg)
    W.section(pg, "Items / Pickups", C.cyan)
    W.toggle(pg, "Item ESP", false, C.cyan, function(v) CFG.ESP.Items.Enabled = v; if v then scanNow() end end)
    W.slider(pg, "Max distance", 50, 1000, 400, C.cyan, function(v) CFG.ESP.Items.MaxDist = v end)
    W.spacer(pg)
    W.section(pg, "Display", C.green)
    W.toggle(pg, "Show Distance", true, C.green, function(v) CFG.ESP.ShowDistance = v end)
    W.toggle(pg, "Show Names", true, C.green, function(v) CFG.ESP.ShowName = v end)
    if not CAP.Draw then W.label(pg, "Executor นี้ไม่รองรับ Drawing API — ESP จะไม่แสดงผล", C.red) end
end)

-- ── BYPASS (เปิดอัตโนมัติ) ──
safe("tab:Bypass", function()
    local pg = P.bypass
    W.section(pg, "Auto-enabled", C.teal)
    W.label(pg, "ตัวเลือกเหล่านี้เปิดให้อัตโนมัติ ปิดได้ถ้าเกมมีปัญหา")
    W.toggle(pg, "CFrame Speed (ไม่แตะ WalkSpeed)", true, C.teal, function(v)
        CFG.Bypass.CFrameSpeed = v
        CFG.Speed.Mode = v and "CFrame" or "WalkSpeed"
        if CFG.Speed.Mode == "WalkSpeed" and CFG.Speed.Enabled and Actions.ensureIndexHook and CFG.Bypass.SpoofReads then
            Actions.ensureIndexHook()
        end
        applySpeed()
    end)
    W.toggle(pg, "Anti-Server Reset (โหมด WalkSpeed)", true, C.teal, function(v) CFG.Bypass.AntiReset = v end)
    W.toggle(pg, "Spoof WalkSpeed reads (โหมด WalkSpeed)", true, C.teal, function(v)
        CFG.Bypass.SpoofReads = v
        if v and CFG.Speed.Enabled and CFG.Speed.Mode == "WalkSpeed" and Actions.ensureIndexHook then
            Actions.ensureIndexHook()
        end
    end)
    W.toggle(pg, "Humanize (สุ่มจังหวะ/มุม/ความเร็ว)", true, C.teal, function(v) CFG.Bypass.Humanize = v end)
    W.toggle(pg, "Range Jitter (สุ่มระยะตี)", true, C.teal, function(v) CFG.Bypass.RangeJitter = v end)
    W.toggle(pg, "Block client Kick()", true, C.teal, function(v) CFG.Bypass.BlockKick = v end)
    W.toggle(pg, "Anti-AFK (กันหลุดเมื่อไม่ขยับ)", true, C.teal, function(v) CFG.Bypass.AntiAFK = v end)
    W.label(pg, "Safe TP ตั้งค่าได้ในแท็บ Warp (เปิดอัตโนมัติเช่นกัน)")
    W.spacer(pg)
    W.section(pg, "สถานะ", C.teal)
    W.label(pg, "Hook (spoof/anti-kick/spy): " .. (CAP.Hook and "รองรับ" or "ไม่รองรับ")
        .. "\nBlock Kick ได้เฉพาะ Kick ที่สั่งจากฝั่งเครื่อง ส่วนเซิร์ฟเวอร์เตะจะกันไม่ได้")
    W.spacer(pg)
    W.section(pg, "ข้อจำกัดที่ต้องรู้", C.teal)
    W.label(pg, "ระบบเหล่านี้ลดโอกาสโดนตรวจจับจากฝั่งเครื่อง และทำให้การเคลื่อนที่ดูสมเหตุสมผล แต่เซิร์ฟเวอร์ของแต่ละเกมตรวจต่างกัน จึงรับประกันทุกเกมไม่ได้")
end)

-- ── UI ──
safe("tab:UI", function()
    local pg = P.ui
    W.section(pg, "Window size", C.purple)
    W.label(pg, "ลากมุมขวาล่างของเมนูเพื่อปรับขนาดเอง หรือเลือกพรีเซ็ต")
    W.button(pg, "Small  (280 x 340)", C.purple, function() Main.Size = UDim2.new(0, 280, 0, 340) end)
    W.button(pg, "Medium  (340 x 420)", C.purple, function() Main.Size = UDim2.new(0, 340, 0, 420) end)
    W.button(pg, "Large  (440 x 560)", C.purple, function() Main.Size = UDim2.new(0, 440, 0, 560) end)
    W.spacer(pg)
    W.section(pg, "Position", C.purple)
    W.button(pg, "Reset menu position", C.purple, function()
        Main.Position = UDim2.new(0, 76, 0.5, -Main.AbsoluteSize.Y / 2)
    end)
    W.button(pg, "Reset logo position", C.purple, function() Logo.Position = UDim2.new(0, 14, 0.35, 0) end)
    W.spacer(pg)
    W.section(pg, "Executor support", C.purple)
    local function yn(b) return b and "yes" or "NO" end
    W.label(pg, "Drawing (ESP): " .. yn(CAP.Draw)
        .. "\nhookmetamethod: " .. yn(CAP.Hook)
        .. "\nclipboard: " .. yn(CAP.Clip)
        .. "\nwritefile (save warps): " .. yn(CAP.Files)
        .. "\nfireproximityprompt: " .. yn(CAP.Prompt)
        .. "\nfiretouchinterface: " .. yn(CAP.Touch))
    W.spacer(pg)
    W.section(pg, "Error log", C.purple)
    local logLbl = W.label(pg, #errors == 0 and "ไม่มี error" or table.concat(errors, "\n"), C.red)
    W.button(pg, "Refresh log", C.purple, function()
        logLbl.Text = #errors == 0 and "ไม่มี error" or table.concat(errors, "\n")
    end)
    W.button(pg, "Copy log", C.purple, function()
        notify(copy(table.concat(errors, "\n")) and "คัดลอกแล้ว" or "executor ไม่รองรับ clipboard")
    end)
    W.spacer(pg)
    W.section(pg, "Script", C.red)
    W.button(pg, "Unload script", C.red, function() if Actions.unload then Actions.unload() end end)
end)

if T.first then selectTab(T.first) end

-- ══════════════════════════════════════
--  FLY BUTTONS (UP / DN)
-- ══════════════════════════════════════
safe("flybtns", function()
    FlyBtns = Instance.new("Frame")
    FlyBtns.Size = UDim2.new(0, 56, 0, 120)
    FlyBtns.Position = UDim2.new(1, -150, 0.5, -60)
    FlyBtns.BackgroundTransparency = 1
    FlyBtns.Visible = false
    FlyBtns.ZIndex = 35
    FlyBtns.Parent = GUI
    local function mk(text, y, key)
        local b = Instance.new("TextButton")
        b.Text = text
        b.Size = UDim2.new(1, 0, 0, 56)
        b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        b.BackgroundTransparency = 0.25
        b.TextColor3 = Color3.fromRGB(110, 150, 255)
        b.TextSize = 16
        b.Font = Enum.Font.GothamBlack
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.ZIndex = 36
        b.Parent = FlyBtns
        corner(b, 12)
        stroke(b, ACCENT, 1.5, 0.3)
        b.InputBegan:Connect(function(i) if isPress(i) then Fly[key] = true end end)
        b.InputEnded:Connect(function(i) if isPress(i) then Fly[key] = false end end)
    end
    mk("UP", 0, "up")
    mk("DN", 64, "down")
end)

-- ══════════════════════════════════════
--  DRAG + RESIZE
-- ══════════════════════════════════════
safe("drag", function()
    local dragging, ds, sp = false, nil, nil
    TBar.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging = true; ds = i.Position; sp = Main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if dragging and isMove(i) then
            local d = i.Position - ds
            Main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)

    local Grip = Instance.new("TextButton")
    Grip.Text = ""
    Grip.Size = UDim2.new(0, 30, 0, 30)
    Grip.Position = UDim2.new(1, -30, 1, -30)
    Grip.BackgroundTransparency = 1
    Grip.ZIndex = 20
    Grip.Parent = Main
    local h = Instance.new("Frame")
    h.Size = UDim2.new(0, 14, 0, 3)
    h.Position = UDim2.new(1, -18, 1, -8)
    h.BackgroundColor3 = ACCENT
    h.BorderSizePixel = 0
    h.ZIndex = 21
    h.Parent = Grip
    local v = Instance.new("Frame")
    v.Size = UDim2.new(0, 3, 0, 14)
    v.Position = UDim2.new(1, -8, 1, -18)
    v.BackgroundColor3 = ACCENT
    v.BorderSizePixel = 0
    v.ZIndex = 21
    v.Parent = Grip

    local resizing, startPos, startSize = false, nil, nil
    Grip.InputBegan:Connect(function(i)
        if isPress(i) then
            resizing = true; startPos = i.Position; startSize = Main.AbsoluteSize
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if resizing and isMove(i) then
            local d = i.Position - startPos
            Main.Size = UDim2.new(0, math.clamp(startSize.X + d.X, MIN_W, MAX_W),
                                  0, math.clamp(startSize.Y + d.Y, MIN_H, MAX_H))
        end
    end)
end)

-- ══════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════
Actions.unload = function()
    alive = false
    setFly(false)
    CFG.Speed.Enabled = false
    pcall(applySpeed)
    CFG.Noclip.Enabled = false
    pcall(restoreCollision)
    CFG.Fly.Enabled = false
    if Actions.setFullbright then pcall(Actions.setFullbright, false) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(freeAllESP)
    pcall(function() GUI:Destroy() end)
    env.__zero_unload = nil
end
env.__zero_unload = Actions.unload

-- ══════════════════════════════════════
--  MAIN LOOPS
-- ══════════════════════════════════════
local frames = 0
bind(RunService.RenderStepped, function()
    frames = frames + 1
    if CFG.Speed.Enabled and CFG.Speed.Mode == "WalkSpeed" and CFG.Bypass.AntiReset then applySpeed() end
    if CFG.Misc.FOVOn and cam() then cam().FieldOfView = CFG.Misc.FOV end
    local ok, err = pcall(updateESP)
    if not ok and not Actions.espWarned then
        Actions.espWarned = true
        logErr("ESP", err)
    end
end)

bind(RunService.Stepped, function()
    if CFG.Noclip.Enabled then applyNoclip() end
end)

bind(RunService.Heartbeat, function(dt)
    local ok, err = pcall(combatStep, dt)
    if not ok and not Actions.combatWarned then Actions.combatWarned = true; logErr("combat", err) end
    local ok2, err2 = pcall(cframeSpeedStep, math.min(dt, 1 / 20))
    if not ok2 and not Actions.speedWarned then Actions.speedWarned = true; logErr("speed", err2) end
    local ok3, err3 = pcall(flyStep, dt)
    if not ok3 and not Actions.flyWarned then Actions.flyWarned = true; logErr("fly", err3) end
end)

bind(lp.CharacterAdded, hookCharacterSpeed)
if lp.Character then task.spawn(hookCharacterSpeed, lp.Character) end

bind(Players.PlayerAdded, function()
    task.wait(0.5)
    if Actions.refreshTarget then pcall(Actions.refreshTarget) end
    if Actions.refreshTP then pcall(Actions.refreshTP) end
end)
bind(Players.PlayerRemoving, function(pl)
    if CFG.Kill.Target == pl and Actions.clearTarget then Actions.clearTarget() end
    task.wait(0.2)
    if Actions.refreshTarget then pcall(Actions.refreshTarget) end
    if Actions.refreshTP then pcall(Actions.refreshTP) end
end)

-- อัปเดตป้ายพิกัด / สถิติ / spy (เฉพาะตอนเมนูเปิด)
task.spawn(function()
    local lastFrames, lastT = 0, os.clock()
    while alive do
        task.wait(0.4)
        if Main and Main.Visible then
            if Actions.locLabel then
                local r = myRoot()
                if r then
                    local p = r.Position
                    Actions.locLabel.Text = string.format("X: %.1f   Y: %.1f   Z: %.1f", p.X, p.Y, p.Z)
                end
            end
            if Actions.statsLabel then
                local now = os.clock()
                local fps = math.floor((frames - lastFrames) / math.max(now - lastT, 0.001) + 0.5)
                lastFrames, lastT = frames, now
                local ping = "-"
                pcall(function()
                    ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
                end)
                Actions.statsLabel.Text = "FPS: " .. fps .. "   Ping: " .. ping
            end
            if CFG.Spy.Enabled and Actions.spyRefresh and P.tools.Visible then
                pcall(Actions.spyRefresh)
                task.wait(0.8)
            end
        end
    end
end)

notify("ZERO พร้อมใช้งาน — แตะโลโก้ Z เพื่อเปิดเมนู" .. (#errors > 0 and (" (มี " .. #errors .. " error ดูที่แท็บ UI)") or ""))
