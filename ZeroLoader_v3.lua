-- ════════════════════════════════════════════════════════════
--  ZERO v3  —  Universal Loader
--  รัน script นี้แทน ZeroESP_v3.lua ตัวเดิม
--  แก้ปัญหา executor จำกัด script size (Arceus X, JJSploit ฯลฯ)
-- ════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
--  วิธีที่ 1: จาก GitHub Raw  (แนะนำ — ใส่ URL เรียบร้อยแล้ว)
-- ──────────────────────────────────────────────────────────
local URLS = {
    main  = "https://raw.githubusercontent.com/ZeroSuPerOne/zero-scripts/refs/heads/main/ZeroESP_v3.lua",
    patch = "https://raw.githubusercontent.com/ZeroSuPerOne/zero-scripts/refs/heads/main/ZeroESP_v3_BanDodge_Patch.lua",
}

-- ──────────────────────────────────────────────────────────
--  วิธีที่ 2: จาก File System  (ถ้า executor มี readfile)
-- ──────────────────────────────────────────────────────────
local FILES = {
    main  = "ZeroESP_v3.lua",
    patch = "ZeroESP_v3_BanDodge_Patch.lua",
}

-- ──────────────────────────────────────────────────────────
--  วิธีที่ 3: Chunk Execute  (fallback ไม่ต้องมีไฟล์)
-- ──────────────────────────────────────────────────────────
local function chunkLoad(src)
    local ok, err = pcall(loadstring(src))
    if not ok then
        warn("[ZeroLoader] loadstring failed: " .. tostring(err))
        return false
    end
    return true
end

-- ──────────────────────────────────────────────────────────
--  MAIN LOADER LOGIC
-- ──────────────────────────────────────────────────────────
local loaded = false

-- ─── ลอง GitHub URL ก่อน ───
if not loaded and URLS.main ~= "" then
    local ok, err = pcall(function()
        print("[ZeroLoader] โหลดจาก GitHub...")
        local src_main  = game:HttpGet(URLS.main,  true)
        loadstring(src_main)()
        task.wait(0.5)
        if URLS.patch ~= "" then
            local src_patch = game:HttpGet(URLS.patch, true)
            loadstring(src_patch)()
        end
    end)
    if ok then
        loaded = true
        print("[ZeroLoader] ✓ โหลดจาก GitHub สำเร็จ")
    else
        warn("[ZeroLoader] GitHub ล้มเหลว: " .. tostring(err))
    end
end

-- ─── ลอง File System ───
if not loaded and readfile and isfile then
    local ok, err = pcall(function()
        if isfile(FILES.main) then
            print("[ZeroLoader] โหลดจากไฟล์: " .. FILES.main)
            loadstring(readfile(FILES.main))()
            task.wait(0.5)
            if isfile(FILES.patch) then
                print("[ZeroLoader] โหลด patch: " .. FILES.patch)
                loadstring(readfile(FILES.patch))()
            end
        else
            error("ไม่พบ " .. FILES.main .. " ใน workspace")
        end
    end)
    if ok then
        loaded = true
        print("[ZeroLoader] ✓ โหลดจากไฟล์สำเร็จ")
    else
        warn("[ZeroLoader] File system: " .. tostring(err))
    end
end

-- ─── Fallback: แจ้งให้รันตรง ───
if not loaded then
    warn([[
[ZeroLoader] โหลดไม่ได้ — ทำตามนี้:

วิธี A (ถ้า executor มี file system):
  1. วาง ZeroESP_v3.lua และ ZeroESP_v3_BanDodge_Patch.lua ไว้ใน workspace
  2. รัน ZeroLoader_v3.lua อีกครั้ง

วิธี B (GitHub hosting):
  1. อัปโหลดทั้งสองไฟล์ขึ้น GitHub
  2. ใส่ raw URL ใน URLS.main และ URLS.patch ด้านบน
  3. รัน loader อีกครั้ง

วิธี C (executor ที่ support script ใหญ่):
  รัน ZeroESP_v3.lua โดยตรง แล้วตามด้วย ZeroESP_v3_BanDodge_Patch.lua
]])
end

-- ──────────────────────────────────────────────────────────
--  ℹ️  ทดสอบ executor support
-- ──────────────────────────────────────────────────────────
print(string.format(
    "[ZeroLoader] executor caps → readfile:%s  HttpGet:%s  hookmetamethod:%s  Drawing:%s",
    tostring(readfile ~= nil),
    tostring(type(game.HttpGet) ~= "nil"),
    tostring(hookmetamethod ~= nil),
    tostring(Drawing ~= nil and Drawing.new ~= nil)
))
