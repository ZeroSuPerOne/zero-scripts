-- ══════════════════════════════════════════════════════════════
--  UI Skeleton v2 — หน้าต่างสวย (เมนูซ้าย + หน้า + วิดเจ็ต) สำหรับ Roblox executor
--  วิธีเพิ่มหน้า:  local p = newPage("id", "ชื่อหัวหน้า", "ชื่อในเมนูซ้าย", "🏠")   -- ไอคอนใส่หรือไม่ใส่ก็ได้
--  วิดเจ็ตในหน้า:  p.section / p.text / p.toggle / p.slider / p.button / p.info / p.box / p.input / p.choice / p.feature
--  แจ้งเตือน:     notify("ข้อความ", "good" | "warn" | "bad" | "info")
--  ธีม:           setTheme("violet" | "ocean" | "rose" | "emerald")
--  โลโก้ลอย: แตะเปิด/ลากย้าย | ปุ่มขวาบน = ย่อ / ขยาย / ปิด | กด P = เปิด/ปิด
-- ══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local TS      = game:GetService("TweenService")
local plr     = Players.LocalPlayer
local gui     = (gethui and gethui()) or plr:WaitForChild("PlayerGui")   -- ซ่อน UI จากสคริปต์เกมที่ไล่ดู PlayerGui
local function randName() local t = {} for i = 1, 12 do t[i] = string.char(math.random(97, 122)) end return table.concat(t) end
local env     = (getgenv and getgenv()) or _G
local rgb     = Color3.fromRGB
local WHITE   = Color3.new(1, 1, 1)

-- ===== ตั้งค่าหลัก (แก้ตรงนี้) =====
local CONFIG = {
	brand     = "PRO",
	subtitle  = "Dead Rails",
	toggleKey = Enum.KeyCode.P,
	theme     = "violet",
	version   = "v1.0 Release",
	key       = "",                -- แสดงในหน้า "เกี่ยวกับ" (ว่าง = ฟรี)
	expireAt  = nil,               -- เวลาหมดอายุแบบ unix เช่น os.time() + 30*86400 (nil = ไม่หมดอายุ)
	logo      = nil,               -- "rbxassetid://..." รูปโลโก้ซ้ายบน (nil = ใช้ตัวอักษรแรกของ brand)
	contact   = "",                -- ลิงก์ติดต่อ (กดแล้วคัดลอก) เช่น Discord/Telegram
}

local START = os.clock()
local function fmtDur(sec)
	sec = math.max(0, math.floor(sec))
	local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
	if d > 0 then return ("%d วัน %d ชั่วโมง %d นาที"):format(d, h, m) end
	if h > 0 then return ("%d ชั่วโมง %d นาที"):format(h, m) end
	return ("%d นาที %d วินาที"):format(m, sec % 60)
end
local function expiryText()
	if not CONFIG.expireAt then return "ไม่มีวันหมดอายุ" end
	local left = CONFIG.expireAt - os.time()
	if left <= 0 then return "หมดอายุแล้ว" end
	return "เหลือ " .. fmtDur(left)
end

local THEMES = {
	violet  = { name = "Violet",  a = rgb(139, 92, 246), b = rgb(56, 189, 248) },
	ocean   = { name = "Ocean",   a = rgb(14, 165, 233), b = rgb(45, 212, 191) },
	rose    = { name = "Rose",    a = rgb(244, 63, 94),  b = rgb(251, 146, 60) },
	emerald = { name = "Emerald", a = rgb(16, 185, 129), b = rgb(132, 204, 22) },
}
local THEME_ORDER = { "violet", "ocean", "rose", "emerald" }

if env.__SkelKill then pcall(env.__SkelKill) end   -- รันซ้ำ = ปิดอันเก่าก่อน

local screen                         -- สร้างในส่วน UI
local notify = function(_, _) end    -- UI แทนที่ให้ (toast มุมขวาบน)
local pconns = {}                    -- set: connection ที่ต้องตัดตอนปิด UI
local function track(c) pconns[c] = true; return c end
local function untrack(c) pconns[c] = nil; pcall(function() c:Disconnect() end) end
local function killAll()
	for c in pairs(pconns) do pcall(function() c:Disconnect() end) end
	table.clear(pconns)
end
local FEATURES = {}
local function stopAllFeatures()
	for _, f in pairs(FEATURES) do
		if f.on then f.on = false; f.gen = (f.gen or 0) + 1; if f.stop then pcall(f.stop) end end
	end
end
env.__SkelKill = function() pcall(stopAllFeatures); killAll(); if screen then screen:Destroy() end end

-- registry ฟีเจอร์แบบย่อ (ใช้กับ p.feature) — ใส่ loop ของคุณใน tick
local function defFeature(def) def.on = false; FEATURES[def.key] = def; return def end
local function setFeature(key, on)
	local f = FEATURES[key]
	if not f then return end
	if (on == true) == (f.on == true) then return end
	f.on = on == true
	f.gen = (f.gen or 0) + 1
	local gen = f.gen
	if f.on then
		if f.start then pcall(f.start) end
		if f.tick then
			task.spawn(function()
				while f.on and f.gen == gen do pcall(f.tick); task.wait(f.interval or 0.5) end
			end)
		end
	else
		if f.stop then pcall(f.stop) end
	end
	if f.setUI then f.setUI(f.on) end
end

-- ══════════════════════════════════════════════════════════════
--  สี + ตัวช่วย
-- ══════════════════════════════════════════════════════════════
local C = {
	panelTop = rgb(21, 22, 31), panelBot = rgb(15, 16, 23), side = rgb(12, 13, 19),
	card = rgb(23, 25, 34), cardHi = rgb(32, 34, 46), navOn = rgb(27, 29, 40), navHover = rgb(19, 20, 28),
	stroke = rgb(38, 41, 56), strokeHi = rgb(64, 68, 92), field = rgb(13, 14, 20), off = rgb(36, 38, 51),
	text = rgb(236, 239, 248), muted = rgb(130, 137, 160), dim = rgb(82, 88, 110),
	good = rgb(52, 211, 153), warn = rgb(251, 191, 36), bad = rgb(248, 113, 113),
	accent = THEMES[CONFIG.theme].a, accent2 = THEMES[CONFIG.theme].b,
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function round(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function strokeOf(o, color, th)
	return make("UIStroke", { Color = color, Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function pad(o, l, r, t, b)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r or l),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0),
	}, o)
end
-- tween: เวลา 0 = ตั้งค่าตรงๆ (ไม่สร้าง Tween ทิ้ง) / TweenInfo ถูก cache ไว้ใช้ซ้ำ
local tiCache = {}
local function tinfo(t, style, dir)
	local a = tiCache[style]; if not a then a = {}; tiCache[style] = a end
	local b = a[dir]; if not b then b = {}; a[dir] = b end
	local ti = b[t]; if not ti then ti = TweenInfo.new(t, style, dir); b[t] = ti end
	return ti
end
local function tw(o, props, t, style, dir)
	t = t or 0.18
	if t <= 0 then
		for k, v in pairs(props) do o[k] = v end
		return nil
	end
	local tween = TS:Create(o, tinfo(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- ธีม: ทุกอย่างที่ใช้สี accent ลงทะเบียนไว้ เปลี่ยนธีมแล้วทาสีใหม่ทันที
local themeFns = {}
local function onTheme(fn) themeFns[#themeFns + 1] = fn; fn() end
local function setTheme(name)
	local t = THEMES[name]
	if not t then return end
	CONFIG.theme, C.accent, C.accent2 = name, t.a, t.b
	for _, fn in ipairs(themeFns) do pcall(fn) end
end
-- UIGradient สี accent (พื้นหลังของ parent ต้องเป็นสีขาว / ถ้าเป็น TextLabel โปร่งใส = ตัวอักษรไล่สี)
local function accentGrad(o, rot)
	local g = make("UIGradient", { Rotation = rot or 0 }, o)
	onTheme(function() g.Color = ColorSequence.new(C.accent, C.accent2) end)
	return g
end
-- เอฟเฟกต์กดยุบ
local function pressFx(btn, target)
	target = target or btn
	local sc = target:FindFirstChildOfClass("UIScale") or make("UIScale", {}, target)
	local function up() tw(sc, { Scale = 1 }, 0.25, Enum.EasingStyle.Back) end
	btn.MouseButton1Down:Connect(function() tw(sc, { Scale = 0.94 }, 0.08) end)
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
end
-- ปุ่มไล่สี (ต้องแยกพื้นกับตัวอักษร ไม่งั้น gradient ไปย้อมสีตัวหนังสือด้วย)
local function gradButton(parent, size, text, color)
	local base = make("Frame", {
		Size = size, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = color or WHITE, BorderSizePixel = 0,
	}, parent)
	round(base, 8)
	if color then
		make("UIGradient", { Color = ColorSequence.new(WHITE, rgb(196, 196, 196)), Rotation = 90 }, base)
	else
		accentGrad(base, 0)
	end
	local normal = color or WHITE
	local hot = normal:Lerp(WHITE, 0.18)
	if not color then normal = rgb(232, 232, 232); base.BackgroundColor3 = normal end
	local b = make("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = WHITE,
		Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false,
	}, base)
	b.MouseEnter:Connect(function() tw(base, { BackgroundColor3 = hot }, 0.12) end)
	b.MouseLeave:Connect(function() tw(base, { BackgroundColor3 = normal }, 0.12) end)
	pressFx(b, base)
	return b, base
end
-- ปุ่มเรียบ (พื้นเข้ม + ขอบ)
local function flatButton(parent, size, text)
	local b = make("TextButton", {
		Size = size, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = C.off,
		Text = text, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
	}, parent)
	round(b, 8)
	strokeOf(b, C.stroke, 1)
	b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = C.cardHi }, 0.12) end)
	b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = C.off }, 0.12) end)
	pressFx(b)
	return b
end

local FULLTEXT = setmetatable({}, { __mode = "k" })   -- ข้อความเต็มของแต่ละช่อง (ช่องแสดงแค่ส่วนต้นถ้ายาวมาก)
-- ข้อความยาวมากใน TextBox = จัด layout/เรนเดอร์หนัก → โชว์แค่ส่วนต้น ปุ่มคัดลอกได้ข้อความเต็ม
local BOX_PREVIEW = 6000
local function setBoxText(tb, text)
	text = tostring(text)
	FULLTEXT[tb] = text
	if #text <= BOX_PREVIEW then tb.Text = text; return end
	local n = BOX_PREVIEW
	while n > 0 do                                    -- ไม่ตัดกลางตัวอักษรไทย (UTF-8)
		local b = text:byte(n + 1)
		if not b or b < 0x80 or b >= 0xC0 then break end
		n -= 1
	end
	tb.Text = text:sub(1, n) .. ("\n\n… แสดง %d จาก %d ตัวอักษร — กดคัดลอกเพื่อเอาข้อความเต็ม"):format(n, #text)
end
local function copyText(text)
	local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if fn and pcall(fn, text) then return true end
	return false
end
local function isPointer(i)
	local t = i.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end
local function isMove(i)
	local t = i.UserInputType
	return t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch
end
-- ตามนิ้ว/เมาส์เฉพาะตอนลาก: ต่อ InputChanged ตอนเริ่ม ตัดทิ้งตอนปล่อย
-- (เดิมทุก slider + หน้าต่าง + โลโก้ ฟัง InputChanged ตลอดเวลา = โดนเรียกทุกครั้งที่ขยับเมาส์)
-- touch: ตามเฉพาะนิ้วที่กดลง นิ้วที่สองหมุนกล้องไม่ไปลาก slider
local function followPointer(input, onMove, onEnd)
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	local mv, ch
	mv = track(UIS.InputChanged:Connect(function(i)
		if isTouch then
			if i == input then onMove(i) end
		elseif i.UserInputType == Enum.UserInputType.MouseMovement then
			onMove(i)
		end
	end))
	ch = track(input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			untrack(mv); untrack(ch)
			if onEnd then onEnd() end
		end
	end))
end

-- ══════════════════════════════════════════════════════════════
--  ScreenGui + Toast
-- ══════════════════════════════════════════════════════════════
local old = gui:FindFirstChild("ProToolkit")
if old then old:Destroy() end
screen = make("ScreenGui", {
	Name = randName(), ResetOnSpawn = false, DisplayOrder = 1000, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil)
screen.Destroying:Connect(function() pcall(stopAllFeatures); pcall(killAll) end)

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
local TOP = 60                                   -- เว้นแถบปุ่ม Roblox ด้านบน (มือถือ)
local W = math.clamp(math.floor(vp.X * 0.72), 460, 800)
local H = math.clamp(vp.Y - TOP - 12, 260, 480)
local SB_W = math.clamp(math.floor(W * 0.27), 120, 184)
local HEAD_H = 52

local toastHost = make("Frame", {
	Name = "Toasts", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, TOP),
	Size = UDim2.new(0, 270, 1, -TOP), BackgroundTransparency = 1, ZIndex = 50,
}, screen)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, toastHost)

local toastN, toasts = 0, {}
notify = function(msg, kind)
	msg = tostring(msg)
	if not kind then kind = (msg:lower():find("^error") and "bad") or "info" end
	local col = ({ good = C.good, warn = C.warn, bad = C.bad })[kind] or C.accent
	toastN += 1

	local outer = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = toastN,
	}, toastHost)
	local t = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(300, 0),
		BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, outer)
	round(t, 10)
	strokeOf(t, C.stroke, 1)
	pad(t, 16, 12, 10, 10)
	local bar = make("Frame", {
		Position = UDim2.new(0, -10, 0, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0,
	}, t)
	round(bar, 2)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = msg,
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 12, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, t)

	toasts[#toasts + 1] = outer
	if #toasts > 4 then local o = table.remove(toasts, 1); o:Destroy() end
	tw(t, { Position = UDim2.fromOffset(0, 0) }, 0.4, Enum.EasingStyle.Quint)
	task.delay(4.5, function()
		if not outer.Parent then return end           -- ถูกดันออกไปแล้ว (เกิน 4 อัน)
		local out = tw(t, { Position = UDim2.fromOffset(300, 0) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		out.Completed:Connect(function()              -- ไม่ :Wait() → ไม่มี thread ค้างถ้า toast ถูกลบกลางทาง
			local idx = table.find(toasts, outer)
			if idx then table.remove(toasts, idx) end
			outer:Destroy()
		end)
	end)
end

-- ══════════════════════════════════════════════════════════════
--  หน้าต่าง: เงา + พาเนล + แถบซ้าย + หัว
-- ══════════════════════════════════════════════════════════════
local root = make("Frame", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H),
	Position = UDim2.fromOffset(math.floor(vp.X / 2), math.max(TOP + H / 2, math.floor(vp.Y / 2))), Visible = false,
}, screen)
local rootScale = make("UIScale", {}, root)

for i, tr in ipairs({ 0.86, 0.92, 0.96 }) do       -- เงานุ่มๆ 3 ชั้น
	local s = make("Frame", {
		BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = tr, BorderSizePixel = 0, ZIndex = 0,
		Size = UDim2.new(1, i * 10, 1, i * 10), Position = UDim2.fromOffset(-i * 5, -i * 5 + 6),
	}, root)
	round(s, 14 + i * 5)
end

local frame = make("Frame", {
	Name = "Panel", Active = true, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1,
}, root)
round(frame, 14)
make("UIGradient", { Color = ColorSequence.new(C.panelTop, C.panelBot), Rotation = 90 }, frame)
local frameStroke = strokeOf(frame, WHITE, 1)
frameStroke.Transparency = 0.6
accentGrad(frameStroke, 35)                        -- ขอบไล่สีจางๆ

-- แถบซ้าย
local side = make("Frame", { Name = "Side", Size = UDim2.new(0, SB_W, 1, 0), BackgroundColor3 = C.side, BorderSizePixel = 0 }, frame)
round(side, 14)
make("Frame", { Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0), BackgroundColor3 = C.side, BorderSizePixel = 0 }, side)
make("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = C.stroke, BorderSizePixel = 0 }, side)

local badge = make("Frame", {
	Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = WHITE, BorderSizePixel = 0,
}, side)
round(badge, 10)
accentGrad(badge, 45)
if CONFIG.logo then
	local img = make("ImageLabel", {
		Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1,
		Image = CONFIG.logo, ScaleType = Enum.ScaleType.Crop,
	}, badge)
	round(img, 8)
else
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = CONFIG.brand:sub(1, 1), TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack, TextSize = 18,
	}, badge)
end
local brandLbl = make("TextLabel", {
	Position = UDim2.fromOffset(56, 14), Size = UDim2.new(1, -62, 0, 20), BackgroundTransparency = 1, Text = CONFIG.brand,
	TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, side)
accentGrad(brandLbl, 0)
make("TextLabel", {
	Position = UDim2.fromOffset(56, 34), Size = UDim2.new(1, -62, 0, 14), BackgroundTransparency = 1, Text = CONFIG.subtitle,
	TextColor3 = C.muted, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, side)
make("TextLabel", {
	Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 14), BackgroundTransparency = 1, Text = "MENU",
	TextColor3 = C.dim, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, side)

local USER_H = 62 + 36                           -- การ์ดผู้เล่น + บรรทัดเวอร์ชัน/วันหมดอายุ
local nav = make("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 1, -82 - USER_H), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, side)
make("UIListLayout", {                            -- ชิดขวา → เมนูย่อย (แคบกว่า) ดูเยื้องเข้าไป
	Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, nav)

-- เวอร์ชัน + วันหมดอายุ (เหนือการ์ดผู้เล่น)
local globalLive = {}                              -- อัปเดตทุก 1 วิ ตอนหน้าต่างเปิด (ไม่ขึ้นกับหน้า)
make("TextLabel", {
	Position = UDim2.new(0, 14, 1, -62 - 34), Size = UDim2.new(1, -28, 0, 14), BackgroundTransparency = 1,
	Text = CONFIG.version, TextColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, side)
local footExp = make("TextLabel", {
	Position = UDim2.new(0, 14, 1, -62 - 18), Size = UDim2.new(1, -28, 0, 13), BackgroundTransparency = 1,
	Text = "", TextColor3 = C.dim, Font = Enum.Font.GothamMedium, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, side)
globalLive[#globalLive + 1] = function()
	local s = "⏳ " .. expiryText()
	if footExp.Text ~= s then footExp.Text = s end
end
globalLive[1]()
pad(nav, 8, 9, 2, 4)

-- การ์ดผู้เล่นล่างซ้าย
local userCard = make("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -17, 0, 46),
	BackgroundColor3 = C.card, BorderSizePixel = 0,
}, side)
round(userCard, 10)
strokeOf(userCard, C.stroke, 1)
local av = make("ImageLabel", {
	Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.off, BorderSizePixel = 0,
	Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=48&h=48",
}, userCard)
round(av, 16)
local avStroke = strokeOf(av, C.accent, 1.5)
onTheme(function() avStroke.Color = C.accent end)
local online = make("Frame", {
	Position = UDim2.fromOffset(31, 31), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = C.good, BorderSizePixel = 0, ZIndex = 2,
}, userCard)
round(online, 5)
strokeOf(online, C.card, 2)
make("TextLabel", {
	Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -52, 0, 15), BackgroundTransparency = 1, Text = plr.DisplayName,
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, userCard)
make("TextLabel", {
	Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -52, 0, 13), BackgroundTransparency = 1, Text = "@" .. plr.Name,
	TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, userCard)

-- หัวฝั่งขวา
local headTitle = make("TextLabel", {
	Position = UDim2.fromOffset(SB_W + 18, 9), Size = UDim2.new(1, -SB_W - 140, 0, 22), BackgroundTransparency = 1,
	Text = "", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, frame)
local headSub = make("TextLabel", {
	Position = UDim2.fromOffset(SB_W + 18, 30), Size = UDim2.new(1, -SB_W - 140, 0, 14), BackgroundTransparency = 1,
	Text = "", TextColor3 = C.muted, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, frame)
make("Frame", {
	Position = UDim2.fromOffset(SB_W, HEAD_H), Size = UDim2.new(1, -SB_W, 0, 1), BackgroundColor3 = C.stroke, BorderSizePixel = 0,
}, frame)
local holder = make("Frame", {
	Position = UDim2.fromOffset(SB_W, HEAD_H + 1), Size = UDim2.new(1, -SB_W, 1, -HEAD_H - 1),
	BackgroundTransparency = 1, ClipsDescendants = true,
}, frame)

-- ที่จับลากหน้าต่าง (แถบหัว + โลโก้ซ้ายบน)
local headHandle = make("Frame", {
	Position = UDim2.fromOffset(SB_W, 0), Size = UDim2.new(1, -SB_W - 116, 0, HEAD_H), BackgroundTransparency = 1, Active = true,
}, frame)
local brandHandle = make("Frame", {
	Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Active = true,
}, side)

-- ปุ่มควบคุมขวาบน
local function ctrlBtn(xFromRight, hot)
	local b = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -xFromRight - 14, 0, HEAD_H / 2),
		Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.card, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, frame)
	round(b, 8)
	strokeOf(b, C.stroke, 1)
	b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = hot }, 0.12) end)
	b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = C.card }, 0.12) end)
	pressFx(b)
	return b
end
local bClose = ctrlBtn(12, C.bad)
local bMax   = ctrlBtn(46, C.cardHi)
local bMin   = ctrlBtn(80, C.cardHi)
make("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "×", TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextSize = 18,
}, bClose)
make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 2),
	BackgroundColor3 = C.text, BorderSizePixel = 0,
}, bMin)
local sq = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
	BackgroundTransparency = 1,
}, bMax)
round(sq, 2)
strokeOf(sq, C.text, 1.5)

-- ══════════════════════════════════════════════════════════════
--  หน้า + วิดเจ็ต
-- ══════════════════════════════════════════════════════════════
local pages, curPage = {}, nil

-- tween วนไม่รู้จบ (จุดกะพริบ ฯลฯ) เล่นเฉพาะหน้าที่เปิดอยู่
local function setLoops(p, on)
	if not p then return end
	for _, t in ipairs(p.loops) do if on then t:Play() else t:Pause() end end
end

local function showPage(p)
	local changed = curPage ~= p
	if changed and curPage then
		setLoops(curPage, false)
		if curPage.onHide then pcall(curPage.onHide) end
	end
	if p.onShow then pcall(p.onShow) end            -- เช่น ตัวนับ FPS ต่อเฉพาะตอนหน้านี้เปิด
	curPage = p
	for _, q in ipairs(pages) do
		local on = q == p
		q.sf.Visible = on
		if on ~= q.active or changed then q.setActive(on) end
	end
	setLoops(p, true)
	headTitle.Text = p.title
	headSub.Text = CONFIG.brand .. "  /  " .. (p.parent and (p.parent.navText .. "  /  ") or "") .. p.navText
	if changed then
		p.sf.CanvasPosition = Vector2.zero
		p.sf.Position = UDim2.fromOffset(0, 14)
		tw(p.sf, { Position = UDim2.fromOffset(0, 0) }, 0.32)
	end
	for _, f in ipairs(p.refresh) do pcall(f) end
	for _, f in ipairs(p.live) do pcall(f) end
end

-- parent = หน้าแม่ → ปุ่มเมนูนี้เป็นเมนูย่อย (เยื้องเข้า, สร้างต่อจากหน้าแม่)
local function newPage(id, title, navText, icon, parent)
	navText = navText or title
	local sf = make("ScrollingFrame", {
		Name = id, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.strokeHi, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, holder)
	make("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pad(sf, 14, 16, 12, 14)

	local P = { id = id, title = title, navText = navText, sf = sf, lo = 0, live = {}, refresh = {}, loops = {}, active = false, parent = parent }

	-- ปุ่มเมนูซ้าย: แถบไฟ + ไอคอน + ชื่อ
	local navBtn = make("TextButton", {
		Size = parent and UDim2.new(1, -14, 0, 30) or UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.side, Text = "",
		AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = #pages + 1,
	}, nav)
	round(navBtn, 9)
	local ind = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, navBtn)
	round(ind, 2)
	accentGrad(ind, 90)
	local ic = make("Frame", {
		Position = UDim2.new(0, 10, 0.5, -12), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.off, BorderSizePixel = 0,
	}, navBtn)
	round(ic, 7)
	local icGrad = accentGrad(ic, 45)
	icGrad.Enabled = false
	local icTxt = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Text = icon or (parent and "•") or string.upper(navText:match(utf8.charpattern) or "•"),
		TextColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 12,
	}, ic)
	local navLbl = make("TextLabel", {
		Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -48, 1, 0), BackgroundTransparency = 1, Text = navText,
		TextColor3 = C.muted, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, navBtn)

	P.setActive = function(on)
		P.active = on
		tw(navBtn, { BackgroundColor3 = on and C.navOn or C.side }, 0.2)
		tw(ind, { Size = UDim2.fromOffset(3, on and 18 or 0) }, 0.25)
		icGrad.Enabled = on
		ic.BackgroundColor3 = on and WHITE or C.off
		icTxt.TextColor3 = on and WHITE or C.muted
		tw(navLbl, { TextColor3 = on and C.text or C.muted }, 0.2)
	end
	navBtn.MouseEnter:Connect(function() if not P.active then tw(navBtn, { BackgroundColor3 = C.navHover }, 0.12) end end)
	navBtn.MouseLeave:Connect(function() if not P.active then tw(navBtn, { BackgroundColor3 = C.side }, 0.12) end end)
	navBtn.MouseButton1Click:Connect(function() showPage(P) end)
	P.nav = navBtn
	pages[#pages + 1] = P

	local function nextLO() P.lo += 1; return P.lo end
	local function card()
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card,
			BorderSizePixel = 0, LayoutOrder = nextLO(),
		}, sf)
		round(row, 10)
		local st = strokeOf(row, C.stroke, 1)
		pad(row, 12, 12, 10, 10)
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		row.MouseEnter:Connect(function() tw(st, { Color = C.strokeHi }, 0.15) end)
		row.MouseLeave:Connect(function() tw(st, { Color = C.stroke }, 0.15) end)
		return row
	end
	local function titleLabel(parent, text, rightGap)
		return make("TextLabel", {
			Size = UDim2.new(1, -(rightGap or 0), 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C.text,
			Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, parent)
	end
	local function descLabel(row, text, lo)
		if not text or text == "" then return end
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Text = text, TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = lo or 5,
		}, row)
	end

	P.section = function(text)
		local f = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = nextLO() }, sf)
		local bar = make("Frame", {
			Position = UDim2.new(0, 1, 1, -14), Size = UDim2.fromOffset(3, 12), BackgroundColor3 = WHITE, BorderSizePixel = 0,
		}, f)
		round(bar, 2)
		accentGrad(bar, 90)
		make("TextLabel", {
			Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, -1), BackgroundTransparency = 1,
			Text = string.upper(text), TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
		}, f)
	end

	P.text = function(text, color)
		local row = card()
		make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
			Text = text, TextColor3 = color or C.text, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, RichText = false,
		}, row)
	end

	-- สวิตช์แบบเม็ดยา
	P.toggle = function(label, desc, get, set)
		local row = card()
		local top = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1,
		}, row)
		titleLabel(top, label, 56)
		local sw = make("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(42, 22),
			BackgroundColor3 = C.off, BorderSizePixel = 0,
		}, top)
		round(sw, 11)
		strokeOf(sw, C.stroke, 1)
		local fill = make("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
		}, sw)
		round(fill, 11)
		accentGrad(fill, 0)
		local knob = make("Frame", {
			Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = rgb(160, 166, 188),
			BorderSizePixel = 0, ZIndex = 2,
		}, sw)
		round(knob, 8)
		descLabel(row, desc)

		local on = get() == true
		local function paint(anim)
			local t = anim and 0.22 or 0
			tw(fill, { BackgroundTransparency = on and 0 or 1 }, t)
			tw(knob, {
				Position = UDim2.fromOffset(on and 23 or 3, 3),
				BackgroundColor3 = on and WHITE or rgb(160, 166, 188),
			}, t, Enum.EasingStyle.Back)
		end
		paint(false)
		top.MouseButton1Click:Connect(function()
			on = not on
			set(on)       -- ถ้าฟีเจอร์ปฏิเสธ (เกมไม่รองรับ) setter ด้านล่างจะถูกเรียกให้กลับเป็น OFF
			paint(true)
		end)
		local function setter(v) local nv = v == true; if nv ~= on then on = nv; paint(true) end end
		P.refresh[#P.refresh + 1] = function() setter(get()) end
		return setter
	end

	P.slider = function(label, desc, min, max, step, get, set, fmt)
		local row = card()
		local head = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1 }, row)
		titleLabel(head, label, 90)
		local pill = make("Frame", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.field, BorderSizePixel = 0,
		}, head)
		round(pill, 6)
		strokeOf(pill, C.stroke, 1)
		pad(pill, 8, 8, 0, 0)
		local valLbl = make("TextLabel", {
			Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = "",
			TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 12,
		}, pill)
		accentGrad(valLbl, 0)
		descLabel(row, desc, 2)

		local line = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 3 }, row)
		local function smallBtn(txt, x, anchor)
			local b = make("TextButton", {
				Size = UDim2.fromOffset(24, 24), Position = UDim2.new(x, 0, 0.5, 0), AnchorPoint = Vector2.new(anchor, 0.5),
				BackgroundColor3 = C.off, Text = txt, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 15,
				AutoButtonColor = false, BorderSizePixel = 0,
			}, line)
			round(b, 7)
			strokeOf(b, C.stroke, 1)
			b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = C.cardHi }, 0.12) end)
			b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = C.off }, 0.12) end)
			pressFx(b)
			return b
		end
		local bMinus, bPlus = smallBtn("−", 0, 0), smallBtn("+", 1, 1)
		local trk = make("Frame", {
			Size = UDim2.new(1, -68, 0, 6), Position = UDim2.new(0, 34, 0.5, -3), BackgroundColor3 = C.off, BorderSizePixel = 0,
		}, line)
		round(trk, 3)
		local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, trk)
		round(fill, 3)
		accentGrad(fill, 0)
		local knob = make("Frame", {
			Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, -8, 0.5, -8), BackgroundColor3 = WHITE,
			BorderSizePixel = 0, ZIndex = 2,
		}, trk)
		round(knob, 8)
		local kst = strokeOf(knob, C.accent, 2)
		onTheme(function() kst.Color = C.accent end)
		local kScale = make("UIScale", {}, knob)
		local hit = make("TextButton", {
			Size = UDim2.new(1, 16, 0, 26), Position = UDim2.new(0, -8, 0.5, -13), BackgroundTransparency = 1, Text = "",
			AutoButtonColor = false, ZIndex = 3,
		}, trk)

		local last                                     -- ค่าล่าสุดที่แสดง → ค่าเดิมไม่วาดซ้ำ ไม่ยิง set ซ้ำ
		local function setVal(v, fire, anim)
			v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
			v = tonumber(string.format("%.4f", v))
			if v == last then return end
			last = v
			local f = (v - min) / (max - min)
			local t = anim and 0.15 or 0
			tw(fill, { Size = UDim2.new(f, 0, 1, 0) }, t)
			tw(knob, { Position = UDim2.new(f, -8, 0.5, -8) }, t)
			valLbl.Text = fmt and fmt(v) or tostring(v)
			if fire then set(v) end
		end
		setVal(get(), false, false)
		P.refresh[#P.refresh + 1] = function() setVal(get(), false, false) end

		local function fromX(x)
			local w = math.max(trk.AbsoluteSize.X, 1)
			setVal(min + math.clamp((x - trk.AbsolutePosition.X) / w, 0, 1) * (max - min), true, false)
		end
		hit.InputBegan:Connect(function(i)
			if not isPointer(i) then return end
			sf.ScrollingEnabled = false
			tw(kScale, { Scale = 1.25 }, 0.15)
			fromX(i.Position.X)
			followPointer(i, function(m) fromX(m.Position.X) end, function()
				sf.ScrollingEnabled = true
				tw(kScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
			end)
		end)
		bMinus.MouseButton1Click:Connect(function() setVal(get() - step, true, true) end)
		bPlus.MouseButton1Click:Connect(function() setVal(get() + step, true, true) end)
	end

	P.button = function(label, desc, fn, color, btnText)
		local row = card()
		local top = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, row)
		titleLabel(top, label, 96)
		local b = gradButton(top, UDim2.fromOffset(84, 28), btnText or "กด", color)
		descLabel(row, desc, 2)
		b.MouseButton1Click:Connect(function()
			local ok, res = pcall(fn)
			if not ok then notify("error: " .. tostring(res), "bad") elseif type(res) == "string" then notify(res) end
		end)
	end

	-- แถวข้อความสด (อัปเดตทุก 1 วิ ตอนหน้านี้เปิดอยู่) — มีจุดเขียวกะพริบ
	P.info = function(textFn, mono)
		local row = card()
		local wrap = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		}, row)
		local dotF = make("Frame", {
			Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.good, BorderSizePixel = 0,
		}, wrap)
		round(dotF, 4)
		P.loops[#P.loops + 1] = TS:Create(dotF, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.75 })            -- เล่นเฉพาะตอนหน้านี้เปิด (setLoops)
		local lbl = make("TextLabel", {
			Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, Text = "", TextColor3 = C.text,
			Font = mono and Enum.Font.Code or Enum.Font.GothamMedium, TextSize = 12,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		}, wrap)
		local function upd()                           -- ข้อความเดิม = ไม่ต้องจัด layout ใหม่
			local s = textFn()
			if lbl.Text ~= s then lbl.Text = s end
		end
		upd()
		P.live[#P.live + 1] = upd
		return upd
	end

	-- ช่องข้อความหลายบรรทัด (เลือก/คัดลอกด้วยมือได้) returns TextBox
	P.box = function(initial)
		local row = card()
		local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, row)
		make("TextLabel", {
			Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, Text = "ข้อความ (แตะค้างเพื่อเลือกเองได้)",
			TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, bar)
		local cp = gradButton(bar, UDim2.fromOffset(90, 26), "คัดลอก", C.good)
		-- กล่องสูงคงที่ + เลื่อนในตัว (เดิมขยายตามข้อความ → ผลดัมป์ยาวๆ ดันทั้งหน้ายาวเป็นหมื่น px)
		local scroller = make("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 170), BackgroundColor3 = C.field, BorderSizePixel = 0, LayoutOrder = 2,
			ScrollBarThickness = 3, ScrollBarImageColor3 = C.strokeHi, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		}, row)
		round(scroller, 8)
		local tbs = strokeOf(scroller, C.stroke, 1)
		local tb = make("TextBox", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "",
			TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 11, TextWrapped = true, MultiLine = true,
			ClearTextOnFocus = false, TextEditable = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, BorderSizePixel = 0,
		}, scroller)
		pad(tb, 8, 8, 8, 8)
		setBoxText(tb, initial or "")
		tb.Focused:Connect(function() tw(tbs, { Color = C.accent }, 0.15) end)
		tb.FocusLost:Connect(function() tw(tbs, { Color = C.stroke }, 0.15) end)
		cp.MouseButton1Click:Connect(function()
			local text = FULLTEXT[tb] or tb.Text
			if text == "" then notify("ยังไม่มีข้อความให้คัดลอก", "warn"); return end
			if copyText(text) then
				notify("คัดลอกแล้ว (" .. #text .. " ตัวอักษร)", "good")
			else
				pcall(function()
					tb:CaptureFocus()
					tb.SelectionStart, tb.CursorPosition = 1, #tb.Text + 1
				end)
				notify("executor นี้ไม่มีคลิปบอร์ด — เลือกข้อความทั้งหมดไว้แล้ว กดค้างที่ข้อความแล้วเลือก คัดลอก", "warn")
			end
		end)
		return tb
	end

	-- ช่องพิมพ์บรรทัดเดียว (onChange เรียกทุกครั้งที่ข้อความเปลี่ยน) returns TextBox
	P.input = function(label, placeholder, onChange)
		local row = card()
		local lh = make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, row)
		titleLabel(lh, label)
		local tb = make("TextBox", {
			Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.field, Text = "", PlaceholderText = placeholder or "",
			PlaceholderColor3 = C.dim, TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13,
			ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, LayoutOrder = 2,
		}, row)
		round(tb, 8)
		local tbs = strokeOf(tb, C.stroke, 1)
		pad(tb, 10, 10, 0, 0)
		tb.Focused:Connect(function() tw(tbs, { Color = C.accent }, 0.15) end)
		tb.FocusLost:Connect(function() tw(tbs, { Color = C.stroke }, 0.15) end)
		tb:GetPropertyChangedSignal("Text"):Connect(function() onChange(tb.Text) end)
		return tb
	end

	-- ปุ่มสลับ + ข้อความปัจจุบัน
	P.choice = function(label, textFn, onPress, btnText)
		local row = card()
		local top = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, row)
		titleLabel(top, label, 96)
		local b = flatButton(top, UDim2.fromOffset(84, 28), btnText or "สลับ")
		local cur = make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "",
			TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
		}, row)
		accentGrad(cur, 0)
		local function upd()
			local s = "› " .. textFn()
			if cur.Text ~= s then cur.Text = s end
		end
		upd()
		P.live[#P.live + 1] = upd
		b.MouseButton1Click:Connect(function()
			local ok, res = pcall(onPress)
			if not ok then notify("error: " .. tostring(res), "bad") elseif type(res) == "string" then notify(res) end
			upd()
		end)
	end

	-- การ์ดข้อมูลหลายบรรทัด (ไอคอน + ข้อความสด) rows = { { "🔑", function() return "..." end }, ... }
	P.monitor = function(rows)
		local row = card()
		row:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 6)
		for i, r in ipairs(rows) do
			local line = make("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = i }, row)
			make("TextLabel", {
				Size = UDim2.fromOffset(20, 18), BackgroundTransparency = 1, Text = r[1], TextColor3 = C.text,
				Font = Enum.Font.GothamMedium, TextSize = 13,
			}, line)
			local lbl = make("TextLabel", {
				Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0), BackgroundTransparency = 1, Text = "",
				TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			}, line)
			local fn = r[2]
			local function upd()
				local ok, s = pcall(fn)
				s = ok and tostring(s) or "—"
				if lbl.Text ~= s then lbl.Text = s end
			end
			upd()
			P.live[#P.live + 1] = upd
		end
	end

	-- รายการสถานะ จุดเขียว/เหลือง/เทา  items = { { "ชื่อ", function() return true|"warn"|false, "ข้อความต่อท้าย" end } }
	P.status = function(items)
		local row = card()
		row:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 6)
		for i, it in ipairs(items) do
			local line = make("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = i }, row)
			local dot = make("Frame", {
				Position = UDim2.fromOffset(2, 5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.dim, BorderSizePixel = 0,
			}, line)
			round(dot, 5)
			local lbl = make("TextLabel", {
				Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), BackgroundTransparency = 1, Text = "",
				TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			}, line)
			local function upd()
				local ok, st, extra = pcall(it[2])
				local col = (not ok and C.bad) or (st == true and C.good) or (st == "warn" and C.warn) or C.dim
				if dot.BackgroundColor3 ~= col then dot.BackgroundColor3 = col end
				local s = it[1] .. (ok and extra and ("  ·  " .. tostring(extra)) or "")
				if lbl.Text ~= s then lbl.Text = s end
			end
			upd()
			P.live[#P.live + 1] = upd
		end
	end

	-- toggle ที่ผูกกับ feature registry (sync ปุ่ม/Stop All/ปฏิเสธเมื่อเกมไม่รองรับ)
	P.feature = function(key)
		local f = FEATURES[key]
		f.setUI = P.toggle(f.label, f.desc, function() return f.on end, function(on) setFeature(key, on) end)
	end
	return P
end

-- ══════════════════════════════════════════════════════════════
--  ลาก / ย่อ / ขยาย / โลโก้ลอย / ปุ่มลัด
-- ══════════════════════════════════════════════════════════════
local maximized, normSize, normPos = false, nil, nil

local function dragHandle(h)
	h.InputBegan:Connect(function(i)
		if not isPointer(i) or maximized then return end
		local dStart, dPos = i.Position, root.Position
		followPointer(i, function(m)
			local d = m.Position - dStart
			local w, hh = root.Size.X.Offset, root.Size.Y.Offset
			-- root ใช้ AnchorPoint กลาง → คำนวณจากมุมซ้ายบนแล้วแปลงกลับ
			local x = math.clamp(dPos.X.Offset - w / 2 + d.X, -w + 80, math.max(0, vp.X - 80))
			local y = math.clamp(dPos.Y.Offset - hh / 2 + d.Y, 0, math.max(0, vp.Y - 40))
			root.Position = UDim2.fromOffset(x + w / 2, y + hh / 2)
		end)
	end)
end
dragHandle(headHandle)
dragHandle(brandHandle)

-- โลโก้ลอย (วงแหวนเต้น + gradient หมุน)
local LOGO = 50
local logoWrap = make("Frame", {
	Name = "Logo", Size = UDim2.fromOffset(LOGO, LOGO), Position = UDim2.fromOffset(12, math.floor(vp.Y * 0.45)),
	BackgroundTransparency = 1, Visible = false,
}, screen)
local logoScale = make("UIScale", {}, logoWrap)
local ring = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, logoWrap)
round(ring, LOGO / 2)
local ringStroke = strokeOf(ring, C.accent, 2)
onTheme(function() ringStroke.Color = C.accent end)
local ringScale = make("UIScale", {}, ring)
-- 3 tween วนของโลโก้ เล่นเฉพาะตอนโลโก้โชว์ (เดิมหมุนตลอดแม้หน้าต่างเปิดอยู่)
local logoLoops = {
	TS:Create(ringScale, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Scale = 1.45 }),
	TS:Create(ringStroke, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 }),
}
local function setLogoLoops(on) for _, t in ipairs(logoLoops) do if on then t:Play() else t:Pause() end end end

local logoBg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, logoWrap)
round(logoBg, LOGO / 2)
local lgs = strokeOf(logoBg, WHITE, 1.5)
lgs.Transparency = 0.65
local logoGrad = accentGrad(logoBg, 0)
logoLoops[#logoLoops + 1] = TS:Create(logoGrad, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
local logo = make("TextButton", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = CONFIG.brand, TextColor3 = WHITE,
	Font = Enum.Font.GothamBlack, TextSize = 13, AutoButtonColor = false,
}, logoWrap)

local visTok = 0
local function openWindow()
	visTok += 1
	root.Visible = true
	logoWrap.Visible = false
	setLogoLoops(false)
	rootScale.Scale = 0.9
	tw(rootScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	if curPage then showPage(curPage) end
end
local function closeWindow()
	visTok += 1
	local tok = visTok
	local t = tw(rootScale, { Scale = 0.9 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	t.Completed:Connect(function()
		if tok ~= visTok then return end
		root.Visible = false
		setLoops(curPage, false)
		if curPage and curPage.onHide then pcall(curPage.onHide) end
		logoWrap.Visible = true
		setLogoLoops(true)
		logoScale.Scale = 0.4
		tw(logoScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
	end)
end
bMin.MouseButton1Click:Connect(closeWindow)
bClose.MouseButton1Click:Connect(closeWindow)

bMax.MouseButton1Click:Connect(function()
	if not maximized then
		normSize, normPos = root.Size, root.Position
		local w, h = vp.X - 16, vp.Y - TOP - 8
		tw(root, { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(8 + w / 2, TOP + h / 2) }, 0.3)
	else
		tw(root, { Size = normSize, Position = normPos }, 0.3)
	end
	maximized = not maximized
end)

logo.InputBegan:Connect(function(i)
	if not isPointer(i) then return end
	local lStart, lPos, lMoved = i.Position, logoWrap.Position, 0
	tw(logoScale, { Scale = 0.92 }, 0.08)
	followPointer(i, function(m)
		local d = m.Position - lStart
		lMoved = math.max(lMoved, math.abs(d.X) + math.abs(d.Y))
		logoWrap.Position = UDim2.fromOffset(
			math.clamp(lPos.X.Offset + d.X, 0, vp.X - LOGO), math.clamp(lPos.Y.Offset + d.Y, 0, vp.Y - LOGO))
	end, function()
		tw(logoScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
		if lMoved < 20 then openWindow() end
	end)
end)
track(UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == CONFIG.toggleKey then
		if root.Visible then closeWindow() else openWindow() end
	end
end))

local pEsp
do
-- ═══════════ ฟีเจอร์เกม (Dead Rails / Dead of Night) ═══════════
local RS         = game:GetService("RunService")
local Lighting   = game:GetService("Lighting")
local RepStorage = game:GetService("ReplicatedStorage")

-- ชื่อโฟลเดอร์ในเกม (ถ้าเกมอัปเดตแล้วหาไม่เจอ แก้ตรงนี้ที่เดียว)
local GAME = {
	enemyPrefix   = "Model_",               -- ศัตรูในเกมนี้ชื่อขึ้นต้น Model_ (Model_Runner, Model_Walker, Model_Werewolf ...) อยู่หลายโฟลเดอร์
	cowboyPatterns = { "outlaw", "sheriff", "cowboy", "bandit" },   -- ชื่อที่นับเป็นคาวบอย/โจร (แยกเมนูมองต่างหาก)
	enemyExclude  = { "Horse", "Banker" },  -- ชื่อที่ไม่นับเป็นศัตรู (ใส่ RifleSoldier/TurretSoldier เพิ่มถ้าเป็นฝ่ายเดียวกัน)
	itemFolders   = { "ObjectModels", "RuntimeItems" },     -- ที่ของตกพื้นอยู่ใน workspace (เจอจากการดัมป์: ObjectModels)
	nightPatterns = { "night", "moon", "transform", "wolf" },   -- ชื่อ Attribute/BoolValue ที่จะถูกตั้งเป็น true
	scanPatterns  = { "wolf", "were", "night", "moon", "transform", "class" },
}

-- ค่าที่ปรับได้จากหน้า UI
local S = { runSpeed = 28, runMaxStep = 1.5, espName = true, espDist = true, ncPaused = false, quickBtn = true, flySpeed = 60, aimRange = 300, aimFov = 180, aimSmooth = 1, wallCheck = true, aimOnlyTool = true }

-- ── ตัวช่วย ──
local function myRoot() local c = plr.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function myHum()  local c = plr.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function partOf(m)
	if m:IsA("BasePart") then return m end
	if m:IsA("Model") and m.PrimaryPart then return m.PrimaryPart end
	return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
end
local function folderList(names)
	local t = {}
	for _, n in ipairs(names) do
		local f = workspace:FindFirstChild(n)
		if f then t[#t + 1] = f end
	end
	return t
end
local function nameMatches(name, patterns)
	name = name:lower()
	for _, p in ipairs(patterns) do
		if name:find(p, 1, true) then return true end
	end
	return false
end

-- ── รายชื่อเป้าหมาย ──
local humSet = {}   -- Humanoid ทั้งหมดใน workspace (เก็บแบบ event ไม่ต้องสแกนซ้ำ)
local function addHum(d) if d:IsA("Humanoid") then humSet[d] = true end end
for _, d in ipairs(workspace:GetDescendants()) do addHum(d) end
track(workspace.DescendantAdded:Connect(addHum))
track(workspace.DescendantRemoving:Connect(function(d) humSet[d] = nil end))

local function getZombies()
	local out, pre = {}, GAME.enemyPrefix
	for h in pairs(humSet) do
		local m = h.Parent
		if m and h.Health > 0 and m:IsA("Model") and m ~= plr.Character and not Players:GetPlayerFromCharacter(m)
			and m.Name:sub(1, #pre) == pre and not nameMatches(m.Name, GAME.enemyExclude) then
			out[#out + 1] = m
		end
	end
	return out
end
local function isCowboy(m) return nameMatches(m.Name, GAME.cowboyPatterns) end
local function getItems()
	local out = {}
	for _, f in ipairs(folderList(GAME.itemFolders)) do
		for _, c in ipairs(f:GetChildren()) do out[#out + 1] = c end
	end
	return out
end
local function getFriends()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= plr and p.Character then out[#out + 1] = p.Character end
	end
	return out
end

-- ══════════ ESP (Highlight + ป้ายชื่อ/ระยะ มองทะลุกำแพง) ══════════
local espFolder = make("Folder", { Name = "ESP" }, screen)
local esp = { friends = {}, zombies = {}, cowboys = {}, items = {} }

local function espDrop(cat, m)
	local e = esp[cat][m]
	if e then e.hl:Destroy(); e.bb:Destroy(); esp[cat][m] = nil end
end
local function espClear(cat)
	for m in pairs(esp[cat]) do espDrop(cat, m) end
end
-- Roblox วาด Highlight พร้อมกันได้ ~31 อัน → ไฮไลท์เฉพาะตัวที่ใกล้สุด (cap) ที่เหลือโชว์แค่ป้ายชื่อ
local function espRefresh(cat, models, color, cap, nameFn)
	local store = esp[cat]
	local root = myRoot()
	local cam = workspace.CurrentCamera
	local origin = root and root.Position or (cam and cam.CFrame.Position) or Vector3.zero
	local list, alive = {}, {}
	for _, m in ipairs(models) do
		local part = partOf(m)
		if part then
			list[#list + 1] = { m = m, part = part, d = (part.Position - origin).Magnitude }
			alive[m] = true
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for m in pairs(store) do
		if not alive[m] or not m.Parent then espDrop(cat, m) end
	end
	for i, it in ipairs(list) do
		local e = store[it.m]
		if not e then
			local hl = make("Highlight", {
				FillColor = color, OutlineColor = WHITE, FillTransparency = 0.55, OutlineTransparency = 0,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = it.m,
			}, espFolder)
			local bb = make("BillboardGui", {
				AlwaysOnTop = true, Size = UDim2.fromOffset(130, 18), StudsOffset = Vector3.new(0, 2.5, 0),
				LightInfluence = 0, Adornee = it.part,
			}, espFolder)
			local lbl = make("TextLabel", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextColor3 = color, TextStrokeTransparency = 0,
				Font = Enum.Font.GothamBold, TextSize = 12,
			}, bb)
			e = { hl = hl, bb = bb, lbl = lbl }
			store[it.m] = e
		end
		e.hl.Enabled = i <= cap
		e.bb.Adornee = it.part
		local txt = {}
		if S.espName then txt[#txt + 1] = nameFn(it.m) end
		if S.espDist then txt[#txt + 1] = "[" .. math.floor(it.d) .. "m]" end
		e.lbl.Text = table.concat(txt, " ")
		e.bb.Enabled = #txt > 0
	end
end

local warnedItems = false
defFeature({ key = "espFriend", label = "มองเพื่อน", desc = "ไฮไลท์ผู้เล่นคนอื่นทะลุกำแพง + ชื่อ/ระยะ", interval = 0.25,
	tick = function()
		espRefresh("friends", getFriends(), C.good, 10, function(m)
			local p = Players:GetPlayerFromCharacter(m)
			return p and p.DisplayName or m.Name
		end)
	end,
	stop = function() espClear("friends") end })

defFeature({ key = "espZombie", label = "มองซอมบี้", desc = "ไฮไลท์ซอมบี้ทะลุกำแพง (ตัวใกล้สุด 12 ตัวเรืองแสง ที่เหลือโชว์ป้าย)", interval = 0.25,
	tick = function()
		local list = {}
		for _, m in ipairs(getZombies()) do if not isCowboy(m) then list[#list + 1] = m end end
		espRefresh("zombies", list, C.bad, 12, function(m) return m.Name end)
	end,
	stop = function() espClear("zombies") end })

defFeature({ key = "espCowboy", label = "มองคาวบอย", desc = "ไฮไลท์โจร/นายอำเภอ/คาวบอย (Outlaw, Sheriff) ทะลุกำแพง แยกสีส้ม", interval = 0.25,
	tick = function()
		local list = {}
		for _, m in ipairs(getZombies()) do if isCowboy(m) then list[#list + 1] = m end end
		espRefresh("cowboys", list, rgb(251, 146, 60), 8, function(m) return (m.Name:gsub("^Model_", "")) end)
	end,
	stop = function() espClear("cowboys") end })

defFeature({ key = "espItem", label = "มองสิ่งของทะลุ", desc = "ไฮไลท์ของที่ตกพื้น/เก็บได้ทะลุกำแพง", interval = 0.5,
	tick = function()
		if not warnedItems and #folderList(GAME.itemFolders) == 0 then
			warnedItems = true
			notify("ไม่เจอโฟลเดอร์ของ (ObjectModels) — แก้ GAME.itemFolders ให้ตรงกับเกม", "warn")
		end
		espRefresh("items", getItems(), C.warn, 8, function(m) return m.Name end)
	end,
	stop = function() espClear("items") end })

-- ══════════ เดินทะลุกำแพง ══════════
local NOCLIP_PARTS = { HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true }
local ncConn, ncOrig = nil, {}
local function ncRestore()
	for part in pairs(ncOrig) do if part.Parent then part.CanCollide = true end end
	table.clear(ncOrig)
end
defFeature({ key = "noclip", label = "เดินทะลุกำแพง", desc = "ทะลุกำแพงแต่ยังยืนบนพื้น ไม่ตกแมพ (ปิดแล้วคืนค่าเดิม) — เปิดแล้วจะมีปุ่มลัด 🚶 บนหน้าจอ",
	start = function()
		S.ncPaused = false
		ncConn = RS.Stepped:Connect(function()
			if S.ncPaused then return end
			local c = plr.Character
			if not c then return end
			for _, p in ipairs(c:GetDescendants()) do
				-- ปิดชนเฉพาะลำตัว/หัว ปล่อยขาไว้ชนพื้น → ทะลุกำแพงได้แต่ไม่ตกแมพ
				if p:IsA("BasePart") and NOCLIP_PARTS[p.Name] and p.CanCollide then ncOrig[p] = true; p.CanCollide = false end
			end
		end)
	end,
	stop = function()
		if ncConn then ncConn:Disconnect(); ncConn = nil end
		ncRestore()
	end })

-- ══════════ บิน ══════════
-- จอยสติ๊ก/WASD = เคลื่อนที่ไปทางที่กล้องมอง (เงยกล้อง = ขึ้น, ก้ม = ลง) | ปุ่มกระโดด/Space/E = ขึ้น | Q/Shift = ลง | ปล่อย = ลอยนิ่ง
local flyConn, flyBV = nil, nil
defFeature({ key = "fly", label = "บิน", desc = "ปรับความเร็วได้ด้านล่าง",
	start = function()
		flyConn = RS.RenderStepped:Connect(function()
			local root, hum, cam = myRoot(), myHum(), workspace.CurrentCamera
			if not root or not hum or not cam then return end
			if not flyBV or flyBV.Parent ~= root then
				if flyBV then flyBV:Destroy() end
				flyBV = make("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero }, root)
			end
			local cf = cam.CFrame
			local v = Vector3.zero
			local md = hum.MoveDirection
			if md.Magnitude > 0 then
				local lv = cf:VectorToObjectSpace(md)
				v = cf.LookVector * -lv.Z + cf.RightVector * lv.X
			end
			if hum.Jump or UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then v += Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then v -= Vector3.yAxis end
			flyBV.Velocity = v * S.flySpeed
		end)
	end,
	stop = function()
		if flyConn then flyConn:Disconnect(); flyConn = nil end
		if flyBV then flyBV:Destroy(); flyBV = nil end
	end })

-- ══════════ ยิงล็อคหัวซอมบี้ ══════════
local zCache, zStamp = {}, 0
local function aimTarget(cf)
	if os.clock() - zStamp > 0.1 then zCache = getZombies(); zStamp = os.clock() end
	local rp
	if S.wallCheck then
		rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { plr.Character }
	end
	local best, bestDist
	for _, m in ipairs(zCache) do
		local head = m:FindFirstChild("Head")
		local hum = m:FindFirstChildOfClass("Humanoid")
		if head and hum and hum.Health > 0 then
			local to = head.Position - cf.Position
			local dist = to.Magnitude
			if dist > 0 and dist <= S.aimRange then
				local ang = math.deg(math.acos(math.clamp(cf.LookVector:Dot(to.Unit), -1, 1)))
				if ang <= S.aimFov then
					local visible = true
					if rp then
						local hit = workspace:Raycast(cf.Position, to, rp)
						visible = (not hit) or hit.Instance:IsDescendantOf(m)
					end
					if visible and (not bestDist or dist < bestDist) then best, bestDist = head, dist end
				end
			end
		end
	end
	return best
end

defFeature({ key = "aim", label = "ยิงปืนล็อคหัวซอมบี้", desc = "หันกล้องไปที่หัวซอมบี้ที่ใกล้สุดในระยะ/มุมที่ตั้งไว้ (ตั้งค่าที่หน้า ต่อสู้)",
	start = function()
		RS:BindToRenderStep("ProAimHead", Enum.RenderPriority.Camera.Value + 1, function()
			local cam, c = workspace.CurrentCamera, plr.Character
			if not cam or not c then return end
			if S.aimOnlyTool and not c:FindFirstChildOfClass("Tool") then return end
			local head = aimTarget(cam.CFrame)
			if head then
				local goal = CFrame.lookAt(cam.CFrame.Position, head.Position)
				cam.CFrame = cam.CFrame:Lerp(goal, 1 / math.max(S.aimSmooth, 1))
			end
		end)
	end,
	stop = function() pcall(function() RS:UnbindFromRenderStep("ProAimHead") end) end })

-- ══════════ มนุษย์หมาป่าอยู่ร่างกลางคืนตลอด ══════════
-- ฝั่งไคลเอนต์ทำได้: ล็อกเวลาเป็นกลางคืน + ตั้ง Attribute/BoolValue ที่ชื่อเกี่ยวกับ night/wolf เป็น true
-- ถ้าเกมตัดสินบัฟที่เซิร์ฟเวอร์ ค่าจริงอาจไม่เปลี่ยน → ใช้ปุ่ม "สแกน" ในหน้าหมาป่าดูว่าเกมเก็บค่าไว้ตรงไหน
local wolfConn, wolfClock = nil, nil
defFeature({ key = "wolf", label = "หมาป่าร่างกลางคืนตลอด", desc = "ล็อกเวลาเป็นกลางคืน + บังคับค่า night/wolf เป็น true", interval = 0.5,
	start = function()
		wolfClock = Lighting.ClockTime
		wolfConn = RS.RenderStepped:Connect(function() Lighting.ClockTime = 0 end)
	end,
	tick = function()
		for _, holder in ipairs({ plr, plr.Character }) do
			for k, v in pairs(holder:GetAttributes()) do
				if type(v) == "boolean" and nameMatches(k, GAME.nightPatterns) then holder:SetAttribute(k, true) end
			end
			for _, d in ipairs(holder:GetDescendants()) do
				if d:IsA("BoolValue") and nameMatches(d.Name, GAME.nightPatterns) then d.Value = true end
			end
		end
	end,
	stop = function()
		if wolfConn then wolfConn:Disconnect(); wolfConn = nil end
		if wolfClock then Lighting.ClockTime = wolfClock end
	end })

-- ═══════════ ปุ่มลัดบนหน้าจอ: เปิด/ปิดเดินทะลุ (กดครั้งเดียว) ═══════════
do
	local qb = make("TextButton", {
		Name = "NoclipQuick", Size = UDim2.fromOffset(84, 34), Position = UDim2.fromOffset(12, math.floor(vp.Y * 0.30)),
		BackgroundColor3 = C.good, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 20,
	}, screen)
	round(qb, 17)
	strokeOf(qb, WHITE, 1.5).Transparency = 0.5
	local qt = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextColor3 = WHITE, Font = Enum.Font.GothamBold,
		TextSize = 13, Text = "", ZIndex = 21,
	}, qb)
	local function paintQuick()
		qb.BackgroundColor3 = S.ncPaused and C.off or C.good
		qt.Text = S.ncPaused and "🚶 ทะลุ: ปิด" or "🚶 ทะลุ: เปิด"
	end
	paintQuick()
	local qDrag, qStart, qPos, qMoved = false, nil, nil, 0
	qb.InputBegan:Connect(function(i)
		if not isPointer(i) then return end
		qDrag, qStart, qPos, qMoved = true, i.Position, qb.Position, 0
		i.Changed:Connect(function()
			if i.UserInputState == Enum.UserInputState.End then
				qDrag = false
				if qMoved < 12 then
					S.ncPaused = not S.ncPaused
					if S.ncPaused then ncRestore() end
					paintQuick()
				end
			end
		end)
	end)
	track(UIS.InputChanged:Connect(function(i)
		if not qDrag or not isMove(i) then return end
		local d = i.Position - qStart
		qMoved = math.max(qMoved, math.abs(d.X) + math.abs(d.Y))
		qb.Position = UDim2.fromOffset(math.clamp(qPos.X.Offset + d.X, 0, vp.X - 84), math.clamp(qPos.Y.Offset + d.Y, 0, vp.Y - 34))
	end))
	-- โชว์ปุ่มเมื่อเปิด "เดินทะลุกำแพง" ไว้ในเมนู (และเปิดใช้ปุ่มลัด)
	local quickDead = false
	track({ Disconnect = function() quickDead = true end })
	task.spawn(function()
		while not quickDead do
			qb.Visible = S.quickBtn and FEATURES.noclip.on == true
			if not FEATURES.noclip.on then paintQuick() end
			task.wait(0.3)
		end
	end)
end

pEsp = newPage("esp", "มองทะลุ", "มองทะลุ", "👁")
pEsp.section("สถานะ")
pEsp.info(function()
	return string.format("เพื่อน: %d   ·   ซอมบี้: %d   ·   ของ: %d", #getFriends(), #getZombies(), #getItems())
end)
pEsp.section("ไฮไลท์")
pEsp.feature("espFriend")
pEsp.feature("espZombie")
pEsp.feature("espCowboy")
pEsp.feature("espItem")
pEsp.section("มองเห็นชัด")
pEsp.feature("fullbright")
pEsp.feature("nofog")
pEsp.section("การแสดงผล")
pEsp.toggle("แสดงชื่อ", "ชื่อบนตัว/ของที่ไฮไลท์", function() return S.espName end, function(v) S.espName = v end)
pEsp.toggle("แสดงระยะ", "ระยะเป็นเมตร เช่น [25m]", function() return S.espDist end, function(v) S.espDist = v end)

local pMove = newPage("move", "การเคลื่อนที่", "เคลื่อนที่", "🕊")
pMove.section("เดิน / บิน")
pMove.feature("noclip")
pMove.toggle("ปุ่มลัดเดินทะลุบนหน้าจอ", "โชว์ปุ่ม 🚶 สลับเปิด/ปิดเดินทะลุด้วยการกดครั้งเดียว (ลากย้ายได้)", function() return S.quickBtn end, function(v) S.quickBtn = v end)
pMove.feature("fly")
pMove.feature("run")
pMove.slider("ความเร็ววิ่ง", "เริ่มที่ 28 (ปกติ ~16) ถ้าโดนดึงกลับให้ลดลง", 18, 80, 2,
	function() return S.runSpeed end, function(v) S.runSpeed = v end, function(v) return v .. " studs/s" end)
pMove.slider("ความเร็วบิน", "ยิ่งสูงยิ่งไว (แนะนำ 40–80 กันโดนเตะ)", 10, 200, 5,
	function() return S.flySpeed end, function(v) S.flySpeed = v end, function(v) return v .. " studs/s" end)
pMove.text("บิน: ดันจอยไปข้างหน้า = ไปทางที่กล้องมอง (เงยกล้อง = ขึ้น ก้มกล้อง = ลง) • กดกระโดดค้าง = ขึ้น • ปล่อยจอย = ลอยนิ่ง", C.muted)

local pCombat = newPage("combat", "ต่อสู้", "ต่อสู้", "🎯")
pCombat.section("ล็อคหัว")
pCombat.feature("aim")
pCombat.toggle("เฉพาะตอนถืออาวุธ", "ล็อคเฉพาะตอนมีของในมือ (กันกล้องดึงตอนเดินเฉยๆ)", function() return S.aimOnlyTool end, function(v) S.aimOnlyTool = v end)
pCombat.toggle("เช็คกำแพง", "ล็อคเฉพาะซอมบี้ที่ไม่มีของบัง", function() return S.wallCheck end, function(v) S.wallCheck = v end)
pCombat.slider("ระยะล็อค", "ไกลสุดที่จะล็อค", 20, 600, 10,
	function() return S.aimRange end, function(v) S.aimRange = v end, function(v) return v .. " studs" end)
pCombat.slider("มุมมอง (FOV)", "ล็อคเฉพาะเป้าที่อยู่ในมุมนี้จากจุดกลางจอ (180 = ทุกทิศ)", 10, 180, 5,
	function() return S.aimFov end, function(v) S.aimFov = v end, function(v) return v .. "°" end)
pCombat.slider("ความนุ่ม", "1 = ล็อคทันที / ยิ่งสูงยิ่งค่อยๆ หมุน ดูเนียนกว่า", 1, 10, 1,
	function() return S.aimSmooth end, function(v) S.aimSmooth = v end, function(v) return tostring(v) end)

local pWolf = newPage("wolf", "มนุษย์หมาป่า", "หมาป่า", "🐺")
pWolf.section("ร่างกลางคืน")
pWolf.feature("wolf")

end

local Lighting   = game:GetService("Lighting")
local RepStorage = game:GetService("ReplicatedStorage")

-- ═══════════ ดัมป์/สแกนเกม (ใช้ในหน้า "ดัมป์") ═══════════
local Dump = (function()
local CS = game:GetService("CollectionService")
local alive = true
local spyOld                                   -- __namecall เดิม → คืนให้ตอนปิด UI
track({ Disconnect = function()
	alive = false
	if spyOld and hookmetamethod then pcall(hookmetamethod, game, "__namecall", spyOld) end
end })

-- ══════════ ตัวช่วย ══════════
local out = {}
local function L(s) out[#out + 1] = tostring(s) end
local function fullName(i) local ok, n = pcall(function() return i:GetFullName() end); return ok and n or tostring(i) end

-- พัก 1 เฟรมทุก N อินสแตนซ์ → แมพใหญ่สแกนได้โดยเกมไม่ค้าง
local YIELD_EVERY = 4000
local budget = 0
local function step()
	budget += 1
	if budget >= YIELD_EVERY then budget = 0; task.wait() end
end

local function attrLine(inst)
	local t = {}
	for k, v in pairs(inst:GetAttributes()) do t[#t + 1] = k .. "=" .. tostring(v) end
	table.sort(t)
	return table.concat(t, ", ")
end

local PATS = { "wolf", "were", "night", "moon", "transform", "class", "vampire", "zombie", "enemy", "item", "loot", "drop", "pickup" }
-- ชื่อซ้ำกันเยอะมาก (Part, MeshPart, Handle…) → จำผลไว้ ไม่ต้อง lower+find 13 รอบทุกชิ้น
local nameMemo = {}
local function matches(name)
	local h = nameMemo[name]
	if h == nil then
		h = false
		local low = name:lower()
		for _, p in ipairs(PATS) do if low:find(p, 1, true) then h = true; break end end
		nameMemo[name] = h
	end
	return h
end
-- IsA("BasePart") แพง → จำผลตาม ClassName
local partMemo = {}
local function isPart(d)
	local cn = d.ClassName
	local r = partMemo[cn]
	if r == nil then r = d:IsA("BasePart"); partMemo[cn] = r end
	return r
end
local REMOTE = { RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true }

local function isPlayerChar(m) return m and m:IsA("Model") and Players:GetPlayerFromCharacter(m) ~= nil end
local function group()
	return setmetatable({ keys = {} }, { __index = {
		add = function(self, key, sample)
			local g = self[key]
			if not g then g = { n = 0, s = {} }; self[key] = g; self.keys[#self.keys + 1] = key end
			g.n += 1
			if #g.s < 6 and sample and not table.find(g.s, sample) then g.s[#g.s + 1] = sample end
		end,
		dump = function(self)
			table.sort(self.keys, function(a, b) return self[a].n > self[b].n end)
			for _, k in ipairs(self.keys) do
				L(("  x%d  %s"):format(self[k].n, k))
				if #self[k].s > 0 then L("        ตัวอย่าง: " .. table.concat(self[k].s, " | ")) end
			end
			if #self.keys == 0 then L("  (ไม่พบ)") end
		end,
	} })
end
local function tree(inst, depth, maxDepth, indent, b)
	if b.n <= 0 then return end
	for _, c in ipairs(inst:GetChildren()) do
		if b.n <= 0 then L(indent .. "… (ตัดเพราะยาวเกิน)"); return end
		b.n -= 1
		L(indent .. c.Name .. " [" .. c.ClassName .. "]" .. (REMOTE[c.ClassName] and "  <REMOTE>" or ""))
		if depth < maxDepth then tree(c, depth + 1, maxDepth, indent .. "  ", b) end
	end
end

-- ══════════ ดัชนี workspace: เดินแมพ "ครั้งเดียว" ต่อการดัมป์ ทุกส่วนอ่านจากนี่ ══════════
-- (เดิม workspaceTop / humanoids / prompts / nearby / keywords ต่างคนต่าง GetDescendants ทั้งแมพ = 5 รอบ)
local IX
local function buildIndex(radius)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local origin = hrp and hrp.Position
	local terrain = workspace.Terrain
	local ix = {
		top = {}, humanoids = group(), prompts = group(), clicks = group(), tools = group(),
		near = {}, nearChars = {}, hasRoot = origin ~= nil, kw = {}, kwN = 0,
	}
	local seen = {}
	for _, c in ipairs(workspace:GetChildren()) do
		local skipNear = (c == char) or (c == terrain)
		local ds = c:GetDescendants()
		ix.top[#ix.top + 1] = { inst = c, kids = #c:GetChildren(), desc = #ds }
		for i = 0, #ds do
			local d = (i == 0) and c or ds[i]
			local cn = d.ClassName
			if cn == "Humanoid" then
				local m = d.Parent
				if m and not isPlayerChar(m) then
					ix.humanoids:add(fullName(m.Parent or workspace), m.Name .. "(hp " .. math.floor(d.Health) .. ")")
				end
			elseif cn == "ProximityPrompt" then
				local m = d:FindFirstAncestorOfClass("Model") or d.Parent
				if m then ix.prompts:add(fullName(m.Parent or workspace), m.Name .. " / " .. d.ActionText .. " / " .. d.ObjectText) end
			elseif cn == "ClickDetector" then
				local m = d:FindFirstAncestorOfClass("Model") or d.Parent
				if m then ix.clicks:add(fullName(m.Parent or workspace), m.Name) end
			elseif cn == "Tool" then
				ix.tools:add(fullName(d.Parent or workspace), d.Name)
			elseif origin and not skipNear and isPart(d) then
				local dist = (d.Position - origin).Magnitude
				if dist <= radius then
					local owner = d
					local m = d:FindFirstAncestorOfClass("Model")
					while m and m.Parent and m.Parent ~= workspace and m.Parent:IsA("Model") do m = m.Parent end
					if m then owner = m end
					if not seen[owner] then
						seen[owner] = true
						if owner:IsA("Model") and owner:FindFirstChildOfClass("Humanoid") then
							ix.nearChars[#ix.nearChars + 1] = owner.Name
						else
							ix.near[#ix.near + 1] = { o = owner, d = dist }
						end
					end
				end
			end
			if matches(d.Name) and not (isPart(d) and #d.Name < 4) then
				ix.kwN += 1
				if #ix.kw < 150 then ix.kw[#ix.kw + 1] = "  [" .. cn .. "] " .. fullName(d) end
			end
			step()
		end
	end
	return ix
end
local function needIX()
	if IX then return true end
	L("  (สร้างดัชนี workspace ไม่สำเร็จ — ข้ามส่วนนี้)")
	return false
end

-- ══════════ ส่วนสแกน ══════════
local sections = {}

sections.info = function()
	L("PlaceId=" .. game.PlaceId .. "  GameId=" .. game.GameId .. "  JobId=" .. game.JobId)
	L("ClockTime=" .. Lighting.ClockTime .. "  Gravity=" .. workspace.Gravity)
	L("Executor: " .. (identifyexecutor and select(1, identifyexecutor()) or "?") ..
		"  | hookmetamethod=" .. tostring(hookmetamethod ~= nil) .. " decompile=" .. tostring(decompile ~= nil) ..
		" writefile=" .. tostring(writefile ~= nil) .. " setclipboard=" .. tostring((setclipboard or toclipboard) ~= nil))
end

sections.workspaceTop = function()
	if not needIX() then return end
	for _, t in ipairs(IX.top) do
		local c, a = t.inst, attrLine(t.inst)
		L(("%s [%s]  children=%d  descendants=%d%s"):format(c.Name, c.ClassName, t.kids, t.desc,
			a ~= "" and ("  attrs{" .. a .. "}") or ""))
	end
	L("")
	L("-- ข้างในโฟลเดอร์/โมเดลใหญ่ (นับตามชื่อ) --")
	for _, t in ipairs(IX.top) do
		local c = t.inst
		if c:IsA("Folder") and t.kids > 0 and not isPlayerChar(c) then
			local g = group()
			for _, k in ipairs(c:GetChildren()) do g:add(k.Name .. " [" .. k.ClassName .. "]") end
			L("▶ workspace." .. c.Name .. "  (" .. t.kids .. " ชิ้น)")
			table.sort(g.keys, function(a, b) return g[a].n > g[b].n end)
			for n, k in ipairs(g.keys) do
				if n > 12 then L("    …"); break end
				L(("    x%d  %s"):format(g[k].n, k))
			end
		end
	end
	L("")
	L("-- workspace attributes --")
	L(attrLine(workspace))
end

sections.humanoids = function()
	if not needIX() then return end
	L("Humanoid ที่ไม่ใช่ผู้เล่น จัดกลุ่มตาม 'โฟลเดอร์ที่อยู่' → โฟลเดอร์ซอมบี้คืออันที่มีหลายตัวและชื่อเป็นศัตรู")
	IX.humanoids:dump()
end

sections.prompts = function()
	if not needIX() then return end
	L("ProximityPrompt (ของที่กดเก็บ/โต้ตอบ) จัดกลุ่มตามโฟลเดอร์ที่อยู่:")
	IX.prompts:dump()
	L("")
	L("ClickDetector:")
	IX.clicks:dump()
	L("")
	L("Tool ที่วางใน workspace:")
	IX.tools:dump()
end

sections.tags = function()
	local tags = CS:GetAllTags()
	table.sort(tags)
	for n, tag in ipairs(tags) do
		if n > 80 then L("  … (ตัด)"); break end
		local list = CS:GetTagged(tag)
		local s = fullName(list[1] or game)
		if #s > 110 then s = s:sub(1, 110) .. "…" end
		L(("  %s  x%d  เช่น %s"):format(tag, #list, s))
	end
	if #tags == 0 then L("  (ไม่มี CollectionService tag)") end
end

sections.nearby = function(radius)
	if not needIX() then return end
	radius = radius or 50
	if not IX.hasRoot then L("  ไม่มีตัวละคร"); return end
	local list, chars = IX.near, IX.nearChars
	table.sort(list, function(a, b) return a.d < b.d end)
	L(("วัตถุภายใน %d studs จากตัวคุณ (ใกล้สุดก่อน, ไม่รวมตัวละคร) — ของที่ตกพื้นอยู่ในลิสต์นี้:"):format(radius))
	for i = 1, math.min(70, #list) do
		local o = list[i].o
		local a = attrLine(o)
		L(("  %5.1f  [%s] %s%s"):format(list[i].d, o.ClassName, fullName(o), a ~= "" and ("   {" .. a .. "}") or ""))
	end
	if #list == 0 then L("  (ไม่มีวัตถุ — ถ้าอยู่ล็อบบี้ ของจะยังไม่มี ต้องเข้ารอบจริงแล้วยืนใกล้ของ)") end
	L("ตัวละคร/NPC ที่มี Humanoid ใกล้ตัว: " .. #chars .. "  " .. table.concat(chars, ", ", 1, math.min(8, #chars)))
end

sections.items = function()
	L("ของในโฟลเดอร์ที่น่าจะเป็นของเก็บได้ (ชื่อ [คลาส] {attributes}):")
	for _, name in ipairs({ "ObjectModels", "RuntimeItems", "Ore" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			local kids = f:GetChildren()
			L("▶ workspace." .. name .. "  (" .. #kids .. " ชิ้น)")
			for i, c in ipairs(kids) do
				if i > 40 then L("    …"); break end
				local a = attrLine(c)
				L("    " .. c.Name .. " [" .. c.ClassName .. "]" .. (a ~= "" and ("  {" .. a:sub(1, 120) .. "}") or ""))
			end
		else
			L("▶ workspace." .. name .. "  — ไม่มี")
		end
	end
end

sections.replicated = function()
	tree(RepStorage, 1, 4, "  ", { n = 450 })
	L("")
	L("-- ทุก Remote ใน ReplicatedStorage --")
	local n = 0
	for _, d in ipairs(RepStorage:GetDescendants()) do
		if REMOTE[d.ClassName] then
			n += 1
			if n <= 400 then L("  [" .. d.ClassName .. "] " .. fullName(d)) end
		end
		step()
	end
	L("  รวม " .. n .. " remote")
end

sections.player = function()
	L("Player attributes: " .. attrLine(plr))
	local c = plr.Character
	if c then
		L("Character attributes: " .. attrLine(c))
		local kids = {}
		for _, k in ipairs(c:GetChildren()) do kids[#kids + 1] = k.Name .. "[" .. k.ClassName .. "]" end
		L("Character children: " .. table.concat(kids, ", "))
	end
	local bp = plr:FindFirstChildOfClass("Backpack")
	if bp then
		local t = {}
		for _, k in ipairs(bp:GetChildren()) do t[#t + 1] = k.Name end
		L("Backpack: " .. table.concat(t, ", "))
	end
	L("ValueBase ใน Player/Character:")
	for _, holder in ipairs({ plr, c }) do
		if holder then
			for _, d in ipairs(holder:GetDescendants()) do
				if d:IsA("ValueBase") then L("  " .. fullName(d) .. " = " .. tostring(d.Value)) end
			end
		end
	end
	local pg = plr:FindFirstChildOfClass("PlayerGui")
	if pg then
		local t = {}
		for _, k in ipairs(pg:GetChildren()) do t[#t + 1] = k.Name end
		L("PlayerGui: " .. table.concat(t, ", "))
	end
end

sections.environment = function()
	L("Lighting attrs: " .. attrLine(Lighting))
	L("ReplicatedStorage attrs: " .. attrLine(RepStorage))
	L("Players attrs: " .. attrLine(Players))
	local t = {}
	for _, k in ipairs(Lighting:GetChildren()) do t[#t + 1] = k.Name .. "[" .. k.ClassName .. "]" end
	L("Lighting children: " .. table.concat(t, ", "))
end

sections.keywords = function()
	L("อินสแตนซ์ที่ชื่อเกี่ยวกับ wolf/night/class/item ฯลฯ (ReplicatedStorage + workspace + Player):")
	local n, shown = 0, 0
	local function emit(s) if shown < 150 then shown += 1; L(s) end end
	local function scan(root)
		for _, d in ipairs(root:GetDescendants()) do
			if matches(d.Name) and not (isPart(d) and #d.Name < 4) then
				n += 1
				emit("  [" .. d.ClassName .. "] " .. fullName(d))
			end
			step()
		end
	end
	scan(RepStorage)
	if needIX() then                               -- workspace ได้จากดัชนีแล้ว ไม่ต้องเดินซ้ำ
		n += IX.kwN
		for _, s in ipairs(IX.kw) do emit(s) end
	end
	scan(plr)
	L("  รวม " .. n .. " รายการ")
end

sections.sources = function()
	if not (decompile and writefile) then L("  executor ไม่มี decompile/writefile — ข้าม"); return end
	pcall(function() if makefolder and not isfolder("DeadRails_Src") then makefolder("DeadRails_Src") end end)
	local saved = 0
	for _, root in ipairs({ RepStorage, plr }) do
		for _, d in ipairs(root:GetDescendants()) do
			if saved >= 20 then break end
			if (d.ClassName == "ModuleScript" or d.ClassName == "LocalScript") and matches(d.Name) then
				local ok, src = pcall(decompile, d)
				if ok and type(src) == "string" and #src > 0 then
					saved += 1
					local fname = "DeadRails_Src/" .. d.Name:gsub("[^%w_]", "_") .. "_" .. saved .. ".lua"
					pcall(writefile, fname, "-- " .. fullName(d) .. "\n" .. src:sub(1, 120000))
					L("  บันทึก " .. fname .. "  ←  " .. fullName(d))
				end
				task.wait()                            -- decompile หนัก → พักทีละไฟล์
			end
			step()
		end
	end
	if saved == 0 then L("  ไม่พบสคริปต์ที่ชื่อตรงเงื่อนไข / decompile ไม่ได้") end
end

-- ══════════ ดักจับ Remote ══════════
-- hook นี้โดนเรียกทุก namecall ในเกม → ในตัว hook ทำให้น้อยที่สุด:
-- ใช้ instance เป็นคีย์ (ไม่เรียก GetFullName), เก็บ args ดิบ, แปลงเป็นข้อความตอนกดดูเท่านั้น
local spy = {}
local function ser(v, d)
	d = d or 0
	local t = typeof(v)
	if t == "string" then return '"' .. (#v > 60 and v:sub(1, 60) .. "…" or v) .. '"'
	elseif t == "Instance" then return "<" .. v.ClassName .. ":" .. fullName(v) .. ">"
	elseif t == "table" then
		if d >= 2 then return "{…}" end
		local parts, n = {}, 0
		for k, x in pairs(v) do
			n += 1
			if n > 8 then parts[#parts + 1] = "…"; break end
			parts[#parts + 1] = tostring(k) .. "=" .. ser(x, d + 1)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end
local spyOk, spyOn, spyInstalled = false, false, false
local function installSpy()
	spyInstalled = true
	spyOk = pcall(function()
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			if spyOn and alive then
				local m = getnamecallmethod()
				if (m == "FireServer" or m == "InvokeServer") and not checkcaller() then
					local e = spy[self]
					if e then e.n += 1 else e = { n = 1, a = {} }; spy[self] = e end
					if #e.a < 3 then e.a[#e.a + 1] = table.pack(...) end
				end
			end
			return old(self, ...)
		end))
		spyOld = old
	end)
end
local function setSpy(on)
	spyOn = on
	if on and not spyInstalled then installSpy() end
end
local function spyText()
	if not spyInstalled then return "  (ปิดอยู่ — ไม่ได้ดักจับ)" end
	local keys = {}
	for inst in pairs(spy) do keys[#keys + 1] = inst end
	table.sort(keys, function(a, b) return spy[a].n > spy[b].n end)
	local lines = {}
	for _, inst in ipairs(keys) do
		local e = spy[inst]
		lines[#lines + 1] = ("  x%d  %s"):format(e.n, fullName(inst))
		for i, args in ipairs(e.a) do
			local p = {}
			for j = 1, args.n do p[j] = ser(args[j]) end
			lines[#lines + 1] = ("        #%d args: %s"):format(i, table.concat(p, ", "))
		end
	end
	if #keys == 0 then lines[1] = spyOk and "  (ยังไม่มี remote ถูกเรียก — ลองเล่นสักพักแล้วกดคัดลอกใหม่)" or "  executor ไม่รองรับ hookmetamethod" end
	return table.concat(lines, "\n")
end

local NEEDS_IX = { workspaceTop = true, humanoids = true, prompts = true, nearby = true, keywords = true }
local function run(names, radius, onStatus)
	table.clear(out)
	budget = 0
	radius = radius or 50
	local total = #names
	for _, n in ipairs(names) do
		if NEEDS_IX[n] then
			if onStatus then pcall(onStatus, "index workspace", 0, total) end
			local ok, err = pcall(function() IX = buildIndex(radius) end)
			if not ok then IX = nil; L("ERROR index: " .. tostring(err)) end
			break
		end
	end
	for i, n in ipairs(names) do
		if onStatus then pcall(onStatus, n, i, total) end
		L("\n══════════ " .. n:upper() .. " ══════════")
		local ok, err = pcall(sections[n], radius)
		if not ok then L("ERROR: " .. tostring(err)) end
		task.wait()
	end
	IX = nil                                       -- ปล่อยหน่วยความจำของดัชนี
	return table.concat(out, "\n")
end
return { run = run, spyText = spyText, setSpy = setSpy, isSpyOn = function() return spyOn end, spyInstalled = function() return spyInstalled end }
end)()

-- ═══════════ หน้า UI ═══════════
local p1 = newPage("dump", "ดัมป์ข้อมูลเกม", "ดัมป์", "🔍")
p1.section("วิธีใช้ (3 ขั้น)")
p1.text("1) ยืนใกล้ของที่ตกพื้น หรือใกล้ซอมบี้\n2) กดปุ่ม ดัมป์ ปุ่มเดียว\n3) วางข้อความที่คัดลอกส่งให้ผม (ถ้าข้อความยาว มันแบ่งเป็นส่วนๆ ให้กดคัดลอกต่อทีละส่วน)", C.muted)
p1.section("ดัมป์")
local dumpBox
local dumpBusy = false
local chunks, chunkIdx = {}, 0
local function splitChunks(text, size)
	local out, cur = {}, {}
	local len = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		if len + #line + 1 > size and #cur > 0 then out[#out + 1] = table.concat(cur, "\n"); cur, len = {}, 0 end
		cur[#cur + 1] = line; len += #line + 1
	end
	if #cur > 0 then out[#out + 1] = table.concat(cur, "\n") end
	return out
end
local function copyChunk()
	if #chunks == 0 then return "ยังไม่ได้ดัมป์" end
	chunkIdx = chunkIdx % #chunks + 1
	local ok = copyText(chunks[chunkIdx])
	return (ok and "คัดลอกส่วน " or "ไม่มีคลิปบอร์ด — ส่วน ") .. chunkIdx .. "/" .. #chunks .. (#chunks > 1 and " — วางแล้วกดอีกครั้งเพื่อส่วนถัดไป" or "")
end
p1.button("ดัมป์ข้อมูลเกม", "สแกนทุกอย่าง แล้วคัดลอกส่วนแรก + บันทึกไฟล์ให้เอง", function()
	if dumpBusy then return "กำลังสแกนอยู่" end
	dumpBusy = true
	FULLTEXT[dumpBox] = nil
	local t0 = os.clock()
	local ok, text = pcall(Dump.run, { "info", "workspaceTop", "humanoids", "prompts", "items", "tags", "nearby", "replicated", "player", "environment", "keywords", "sources" }, 60,
		function(name, i, total) dumpBox.Text = ("กำลังสแกน… %s  (%d/%d)"):format(name, i, total) end)
	dumpBusy = false
	if not ok then return "error: " .. tostring(text) end
	if Dump.spyInstalled() then text = text .. "\n\n══════════ REMOTE ที่เกมเรียก ══════════\n" .. Dump.spyText() end
	setBoxText(dumpBox, text)
	chunks, chunkIdx = splitChunks(text, 25000), 0
	if writefile then pcall(writefile, "DeadRails_Dump.txt", text) end
	return ("สแกนเสร็จใน %.1f วิ — "):format(os.clock() - t0) .. copyChunk() .. (writefile and " · บันทึกไฟล์ DeadRails_Dump.txt แล้ว" or "")
end, C.good, "ดัมป์")
p1.button("คัดลอกส่วนถัดไป", "ใช้เมื่อข้อความยาวและถูกแบ่งหลายส่วน กดทีละครั้ง วางทีละส่วน", copyChunk, nil, "คัดลอก")
dumpBox = p1.box("ผลดัมป์จะขึ้นที่นี่")
p1.section("ขั้นสูง (ปกติไม่ต้องแตะ)")
p1.toggle("ดักจับ Remote", "เปิดเฉพาะตอนหาค่า — ตัวดักจับอาจทำให้เก็บของ/ยิงไม่ได้ ถ้าเป็นแบบนั้นให้ปิดแล้วรีจอยเกม", function() return Dump.isSpyOn() end, function(v) Dump.setSpy(v) end)

-- ═══════════ หน้า "เกี่ยวกับ" (ข้อมูลระบบ + สถานะ) ═══════════
local RunService = game:GetService("RunService")
local Stats      = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

-- FPS: นับเฟรมเฉพาะตอนหน้านี้เปิด (onShow/onHide) ไม่กินเครื่องตอนอยู่หน้าอื่น
local fps, frames, fpsT, fpsConn = 0, 0, os.clock(), nil
local function fpsStart()
	if fpsConn then return end
	frames, fpsT = 0, os.clock()
	fpsConn = track(RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - fpsT >= 1 then fps = math.floor(frames / (now - fpsT) + 0.5); frames, fpsT = 0, now end
	end))
end
local function fpsStop() if fpsConn then untrack(fpsConn); fpsConn = nil end end

local function pingMs()
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if ok and v then return math.floor(v + 0.5) end
	ok, v = pcall(function() return plr:GetNetworkPing() end)
	return ok and v and math.floor(v * 1000 + 0.5) or nil
end
local function platform()
	local ok, tv = pcall(function() return GuiService:IsTenFootInterface() end)
	if ok and tv then return "คอนโซล" end
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then return "มือถือ / แท็บเล็ต" end
	return "PC"
end
local execName = "ไม่ทราบ"
pcall(function()
	if identifyexecutor then
		local n, v = identifyexecutor()
		execName = tostring(n) .. (v and (" " .. tostring(v)) or "")
	end
end)
local gameName = "กำลังโหลด…"
task.spawn(function()                              -- ดึงชื่อเกมครั้งเดียว (yield ได้ ไม่บล็อก UI)
	local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
	gameName = (ok and info and info.Name) or ("Place " .. game.PlaceId)
end)
local function yesNo(v) return v ~= nil, v ~= nil and "รองรับ" or "ไม่รองรับ" end

local pAbout = newPage("about", "เกี่ยวกับ", "เกี่ยวกับ", "ℹ️")
pAbout.onShow, pAbout.onHide = fpsStart, fpsStop
pAbout.section("ข้อมูลระบบ (SYSTEM MONITOR)")
pAbout.monitor({
	{ "🔑", function() return "KEY : " .. (CONFIG.key ~= "" and CONFIG.key or "ฟรี") end },
	{ "👤", function() return ("%s (@%s)  ·  อายุบัญชี %d วัน"):format(plr.DisplayName, plr.Name, plr.AccountAge) end },
	{ "🛠", function() return "Executor : " .. execName end },
	{ "📱", function() return "แพลตฟอร์ม : " .. platform() end },
	{ "📺", function() return ("จอ : %dx%d"):format(vp.X, vp.Y) end },
	{ "⚡", function()
		local p = pingMs()
		return ("FPS : %d   |   Ping : %s"):format(fps, p and (p .. " ms") or "—")
	end },
	{ "💾", function() return ("หน่วยความจำเกม : %d MB"):format(math.floor(Stats:GetTotalMemoryUsageMb())) end },
	{ "🎮", function() return "เกม : " .. gameName end },
	{ "🌐", function() return ("เซิร์ฟเวอร์ : %d/%d คน"):format(#Players:GetPlayers(), Players.MaxPlayers) end },
	{ "🕒", function() return "เวลา : " .. os.date("%H:%M:%S") .. "   |   เปิดมาแล้ว " .. fmtDur(os.clock() - START) end },
	{ "⏳", function() return expiryText() end },
})
pAbout.section("สถานะการทำงาน")
pAbout.status({
	{ "ดักจับ Remote", function()
		if not Dump.spyInstalled() then return false, "ปิด" end
		if Dump.isSpyOn() then return true, "กำลังดักจับ" end
		return "warn", "พักไว้"
	end },
	{ "hookmetamethod", function() return yesNo(hookmetamethod) end },
	{ "decompile", function() return yesNo(decompile) end },
	{ "writefile", function() return yesNo(writefile) end },
	{ "คลิปบอร์ด", function() return yesNo(setclipboard or toclipboard) end },
})

local pDetail = newPage("detail", "รายละเอียด", "รายละเอียด", nil, pAbout)
pDetail.section("เวอร์ชัน")
pDetail.text(CONFIG.version .. "  ·  " .. CONFIG.brand .. " " .. CONFIG.subtitle)
pDetail.section("มีอะไรใหม่")
pDetail.text("• ดัมป์เดินแมพรอบเดียว + พักทุก 4000 ชิ้น เกมไม่ค้าง\n• ตัวดักจับ Remote เบาลง และคืน hook ตอนปิด UI\n• หน้าเกี่ยวกับ: ข้อมูลระบบ + สถานะแบบสด", C.muted)
if CONFIG.contact ~= "" then
	pDetail.section("ติดต่อ")
	pDetail.button("ลิงก์ติดต่อ", CONFIG.contact, function()
		return copyText(CONFIG.contact) and "คัดลอกลิงก์แล้ว" or ("ลิงก์: " .. CONFIG.contact)
	end, nil, "คัดลอก")
end

local p2 = newPage("settings", "ตั้งค่า", "ตั้งค่า", "⚙️")
p2.section("หน้าตา")
p2.choice("ธีมสี", function() return THEMES[CONFIG.theme].name end, function()
	local idx = table.find(THEME_ORDER, CONFIG.theme) or 0
	local nextName = THEME_ORDER[idx % #THEME_ORDER + 1]
	setTheme(nextName)
	return "เปลี่ยนธีมเป็น " .. THEMES[nextName].name
end, "เปลี่ยน")
p2.section("ระบบ")
p2.info(function()
	return string.format("ปุ่มลัด: %s   ·   หน้าต่าง: %dx%d", CONFIG.toggleKey.Name, root.Size.X.Offset, root.Size.Y.Offset)
end, true)
p2.button("ปิด UI", "ลบหน้าต่างทิ้งทั้งหมด (รันสคริปต์ใหม่เพื่อเปิด)", function() env.__SkelKill() end, C.bad, "ปิด")

screen.Parent = gui
showPage(pEsp)
openWindow()
notify("โหลดเสร็จแล้ว — กด " .. CONFIG.toggleKey.Name .. " เพื่อซ่อน/แสดง", "good")

task.spawn(function()
	while screen.Parent do
		task.wait(1)
		if root.Visible then
			for _, f in ipairs(globalLive) do pcall(f) end
			if curPage then for _, f in ipairs(curPage.live) do pcall(f) end end
		end
	end
end)
