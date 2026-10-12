local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local key = getgenv().Key

if type(key) ~= "string" or key == "" then
    player:Kick("Chưa nhập license key.")
    return
end

local deviceId = "roblox-user-" .. tostring(player.UserId)

local body = HttpService:JSONEncode({
    key = key,
    deviceId = deviceId
})

local httpFn = (typeof(request) == "function" and request) or http_request

local success, response = pcall(function()
    return httpFn({
        Url = "https://key-system-not7.onrender.com/api/v1/license/verify",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = body
    })
end)

if not success or not response or not response.Success then
    player:Kick("Không thể kết nối license server.")
    return
end

local ok, result = pcall(function()
    return HttpService:JSONDecode(response.Body)
end)

if not ok or not result or result.valid ~= true then
    player:Kick("Key không hợp lệ: " .. tostring(result and result.reason or "unknown"))
    return
end

print("License hợp lệ, cho phép chạy script.")

local SCRIPT_URL = "https://raw.githubusercontent.com/QuocHoa789/premium/main/premium%281%29.lua.txt"

local okLoad, scriptSource = pcall(function()
    return game:HttpGet(SCRIPT_URL)
end)

if not okLoad or type(scriptSource) ~= "string" or scriptSource == "" then
    player:Kick("Không thể tải script từ server.")
    return
end

local compiler = (typeof(loadstring) == "function" and loadstring) or load

local chunk, err = compiler(scriptSource, "=premium_script")
if not chunk then
    player:Kick("Script lỗi cú pháp: " .. tostring(err))
    return
end

local okRun, runErr = pcall(chunk)
if not okRun then
    warn("[Script runtime error] " .. tostring(runErr))
end
