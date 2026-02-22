--[[ 
   WexZ Hub | Secure Loader
   หน้าที่: แอบดึงสคริปต์หลักมารันและแก้บัค Executor (เช่น Xeno)
]]

-- ลิงก์สคริปต์หลักของคุณ (Rivals.lua)
local MainScriptURL = "https://raw.githubusercontent.com/Kakuri12/WexZ/main/Rivals.lua"

local function LoadWexZ()
    local scriptData = ""
    
    -- 1. แอบดึงข้อมูลสคริปต์หลัก
    local fetchFunc = request or http_request or (http and http.request)
    if fetchFunc then
        local response = fetchFunc({Url = MainScriptURL, Method = "GET"})
        if response.StatusCode == 200 then
            scriptData = response.Body
        end
    end
    
    if scriptData == "" then
        local success, res = pcall(function() return game:HttpGet(MainScriptURL, true) end)
        if success then scriptData = res end
    end

    -- 2. รันสคริปต์แบบหลบหลีกบัคตัวรัน (Bypass Xeno/Delta/Codex)
    if scriptData ~= "" then
        if writefile and loadfile then
            local tempName = "WexZ_Sys_" .. tostring(math.random(10000, 99999)) .. ".txt"
            pcall(function() writefile(tempName, scriptData) end)
            
            local func = loadfile(tempName)
            if delfile then pcall(function() delfile(tempName) end) end
            
            if func then return func() end
        end

        -- สำรองกรณีตัวรันเขียนไฟล์ไม่ได้
        local func = loadstring(scriptData)
        if func then return func() end
    else
        game.Players.LocalPlayer:Kick("WexZ Hub: ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์หลักได้")
    end
end

-- เรียกใช้งาน
task.spawn(LoadWexZ)
