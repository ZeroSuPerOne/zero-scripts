-- ════════════════════════════════════════════════════════════
--  ZERO v3  —  BanDodge Patch  v1.0
--  รันอันนี้หลังจาก ZeroESP_v3.lua โหลดแล้ว
--  ถ้าใช้ ZeroLoader_v3.lua ไม่ต้องรันแยก (โหลดให้อัตโนมัติ)
-- ════════════════════════════════════════════════════════════

local Players    = game:GetService("Players")
local TpSvc      = game:GetService("TeleportService")
local HttpSvc    = game:GetService("HttpService")
local lp         = Players.LocalPlayer

-- กัน double-load
if _G.__zero_bd_loaded then print("[ZeroBD] already loaded"); return end
_G.__zero_bd_loaded = true

local function safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[ZeroBD] " .. tag .. ": " .. tostring(err)) end
end

-- ──────────────────────────────────────────────────────────
--  BD CONFIG  (แก้ค่าตรงนี้)
-- ──────────────────────────────────────────────────────────
local BD = {
    AdminKill   = true,   -- ซ่อน/บล็อก ban, kick, mute buttons ใน admin GUI
    SpoofId     = true,   -- สลับ UserId/Name ที่ report system อ่าน
    AutoHop     = true,   -- server hop อัตโนมัติเมื่อถูก kick
    FloodReport = false,  -- เปิดเพื่อ DOS ระบบ report ของเกม (ใช้ zeroFloodReport())
    LogSpoof    = true,   -- แทน UserId จริงใน HTTP POST body ด้วยค่าสุ่ม
}

-- ค่า spoof สุ่มใหม่ทุกครั้งที่ load (ไม่ตรงกับ ID จริง)
local fakeId   = math.random(100000000, 999999999)
local fakeName = "User_" .. math.random(10000, 99999)
local fakeDisp = "Player" .. math.random(1000, 9999)

local function notify(msg)
    print("[ZeroBD] " .. tostring(msg))
    -- inject เข้า toast ของ Zero ถ้ามี
    pcall(function()
        for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") then
                local t = gui:FindFirstChildOfClass("TextLabel")
                if t and t.Visible ~= nil then
                    t.Text = "[BD] " .. tostring(msg)
                    t.Visible = true
                    task.delay(2.5, function() pcall(function() t.Visible = false end) end)
                    return
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════
--  1  ADMIN GUI DESTROYER
--     ซ่อน + บล็อก button/label ทุกตัวที่มีข้อความ ban/kick/mute
-- ══════════════════════════════════════════════════════════
local BAN_EXACT = {
    ban=1, kick=1, mute=1, unmute=1, warn=1, punish=1,
    suspend=1, freeze=1, jail=1, unjail=1, silence=1,
    ["ban user"]=1,  ["kick user"]=1,
    ["ban player"]=1,["kick player"]=1,
    ["ban selected"]=1, ["kick selected"]=1,
    ["force kick"]=1, ["force ban"]=1,
}
local BAN_PREFIX = {
    "^ban%(", "^kick%(", "^banplayer", "^kickplayer",
    "^banuser","^kickuser","^ban %d","^kick %d",
}
-- ชื่อ GUI container ที่เกี่ยวกับ admin panel
local PANEL_KEYS = {
    "admin","adm","panel","cmd","command",
    "staff","mod","console","manager","infraction",
    "hdadmin","kohl","nameless","cmdr","adonis",
}

local processed = setmetatable({}, { __mode = "k" })

local function matchesBan(raw)
    local t = raw:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    if BAN_EXACT[t] then return true end
    for _, p in ipairs(BAN_PREFIX) do
        if t:find(p) then return true end
    end
    return false
end

local function isAdminName(name)
    local n = name:lower()
    for _, k in ipairs(PANEL_KEYS) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function killButton(obj)
    if processed[obj] then return end
    if not obj or not obj.Parent then return end
    if not (obj:IsA("TextButton") or obj:IsA("GuiButton") or obj:IsA("TextLabel")) then return end
    local txt = ""
    pcall(function() txt = obj.Text end)
    if not matchesBan(txt) then return end
    processed[obj] = true

    pcall(function()
        if obj:IsA("TextButton") or obj:IsA("GuiButton") then
            obj.Visible = false
            -- วาง invisible blocker กัน interaction ที่ parent ส่งผ่านมา
            local b = Instance.new("TextButton")
            b.Name        = "__bd_block"
            b.Size        = UDim2.new(1, 0, 1, 0)
            b.BackgroundTransparency = 1
            b.Text        = ""
            b.ZIndex      = (obj.ZIndex or 1) + 10
            b.Active      = true
            b.Parent      = obj.Parent
        else
            -- TextLabel หัวหมวด "Ban" → ล่องหน
            obj.TextTransparency = 1
        end
    end)
    warn("[ZeroBD] AdminKill: '" .. txt .. "'  @ " ..
        (pcall(function() return obj:GetFullName() end) and obj:GetFullName() or "?"))
end

local function deepScan(root)
    pcall(function()
        for _, obj in ipairs(root:GetDescendants()) do killButton(obj) end
    end)
end

local function hookNew(root)
    pcall(function()
        root.DescendantAdded:Connect(function(obj)
            task.wait(0.2)   -- รอให้ Text set ก่อน
            pcall(killButton, obj)
        end)
    end)
end

-- scan ครั้งแรก
safe("bd:init_scan", function()
    for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if isAdminName(gui.Name) then deepScan(gui) end
        hookNew(gui)
    end
    for _, gui in ipairs(lp.PlayerGui:GetChildren()) do
        if isAdminName(gui.Name) then deepScan(gui) end
        hookNew(gui)
    end
end)

-- watch GUI ใหม่
game:GetService("CoreGui").ChildAdded:Connect(function(gui)
    task.wait(0.6); deepScan(gui); hookNew(gui)
end)
lp.PlayerGui.ChildAdded:Connect(function(gui)
    task.wait(0.6); deepScan(gui); hookNew(gui)
end)

-- rescan ทุก 10 วิ (admin GUI บางตัว rebuild หลัง action)
task.spawn(function()
    while _G.__zero_bd_loaded do
        task.wait(10)
        if BD.AdminKill then
            safe("bd:rescan", function()
                for _, gui in ipairs(lp.PlayerGui:GetChildren()) do
                    if isAdminName(gui.Name) then deepScan(gui) end
                end
            end)
        end
    end
end)

-- ══════════════════════════════════════════════════════════
--  2  ID / NAME SPOOF
--     report system จะเห็น UserId/Name ปลอม
-- ══════════════════════════════════════════════════════════
if hookmetamethod and checkcaller and newcclosure then
    safe("bd:id_spoof", function()
        local orig
        orig = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if BD.SpoofId and not checkcaller() then
                if typeof(self) == "Instance" and self == lp then
                    if key == "UserId"      then return fakeId   end
                    if key == "Name"        then return fakeName  end
                    if key == "DisplayName" then return fakeDisp  end
                end
            end
            return orig(self, key)
        end))
    end)
    notify(string.format("SpoofId on — fakeId=%d  fakeName=%s", fakeId, fakeName))
else
    warn("[ZeroBD] hookmetamethod/checkcaller/newcclosure ไม่รองรับ — ID spoof ข้าม")
end

-- ══════════════════════════════════════════════════════════
--  3  BLOCK CLIENT KICK  +  SERVER HOP
--     ① block :Kick() ที่เรียกจาก LocalScript ของเกม
--     ② catch Kicked event (server-side) → server hop
-- ══════════════════════════════════════════════════════════
local function doHop()
    local ok = pcall(function()
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"
            .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpSvc:JSONDecode(raw)
        local pool = {}
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                pool[#pool + 1] = s.id
            end
        end
        if #pool > 0 then
            TpSvc:TeleportToPlaceInstance(game.PlaceId, pool[math.random(#pool)], lp)
        else
            error("no open server")
        end
    end)
    if not ok then
        pcall(function() TpSvc:Teleport(game.PlaceId, lp) end)
    end
end

-- block :Kick() client-side
if hookmetamethod and checkcaller and newcclosure then
    safe("bd:kick_block", function()
        local orig_nc
        orig_nc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if (m == "Kick" or m == "kick") and self == lp and not checkcaller() then
                warn("[ZeroBD] blocked client-side :Kick()")
                if BD.AutoHop then task.spawn(doHop) end
                return   -- ไม่ execute kick
            end
            return orig_nc(self, ...)
        end))
    end)
end

-- server-side kick → hop
lp.Kicked:Connect(function(msg)
    if not BD.AutoHop then return end
    warn("[ZeroBD] server kick: " .. tostring(msg) .. " → hopping...")
    task.spawn(doHop)
end)

-- ══════════════════════════════════════════════════════════
--  4  REPORT FLOOD
--     เรียก zeroFloodReport(player, จำนวน) จาก execute
--     หรือเปิด BD.FloodReport = true แล้วใช้ auto mode
-- ══════════════════════════════════════════════════════════
local function floodReport(target, amount)
    if not target then
        warn("[ZeroBD] floodReport: ต้องส่ง Player object เข้ามา")
        return
    end
    amount = math.clamp(amount or 15, 1, 50)
    task.spawn(function()
        for i = 1, amount do
            pcall(function()
                Players:ReportAbuse(target, "Exploiting", "report #" .. i)
            end)
            task.wait(0.07)
        end
        notify("flood report x" .. amount .. " → " .. target.Name)
    end)
end
-- expose ให้เรียกจาก execute ข้างนอกได้
_G.zeroFloodReport = floodReport

-- ══════════════════════════════════════════════════════════
--  5  HTTP BAN-LOG SPOOF
--     แทน UserId จริงใน POST/RequestAsync body ด้วย fakeId
--     กัน admin log ที่ส่งผ่าน HTTP ไม่ให้ตรง UserId จริง
-- ══════════════════════════════════════════════════════════
if hookmetamethod and checkcaller and newcclosure and BD.LogSpoof then
    safe("bd:http_spoof", function()
        local orig_http
        local realId = tostring(lp.UserId)
        orig_http = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if not checkcaller() and
               (m == "PostAsync" or m == "RequestAsync" or m == "GetAsync") then
                local args = { ... }
                -- table-style request (RequestAsync)
                if type(args[1]) == "table" then
                    local body = args[1].Body
                    if type(body) == "string" and body:find(realId, 1, true) then
                        args[1].Body = body:gsub(realId, tostring(fakeId))
                    end
                end
                -- string-style body (PostAsync)
                if type(args[2]) == "string" and args[2]:find(realId, 1, true) then
                    args[2] = args[2]:gsub(realId, tostring(fakeId))
                end
                return orig_http(self, table.unpack(args))
            end
            return orig_http(self, ...)
        end))
    end)
end

-- ══════════════════════════════════════════════════════════
--  DONE
-- ══════════════════════════════════════════════════════════
notify(string.format(
    "BanDodge v1.0 — AdminKill:%s SpoofId:%s AutoHop:%s LogSpoof:%s",
    tostring(BD.AdminKill), tostring(BD.SpoofId),
    tostring(BD.AutoHop),   tostring(BD.LogSpoof)
))
