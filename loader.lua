local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local key = getgenv().Key

-- Không có key → kick
if type(key) ~= "string" or key == "" then
    player:Kick("Chưa nhập license key.")
    return
end

local httpFn =
    (typeof(request) == "function" and request)
    or (typeof(http_request) == "function" and http_request)
    or (syn and syn.request)
    or (http and http.request)

if not httpFn then
    player:Kick("Executor không hỗ trợ HTTP request.")
    return
end

local body = HttpService:JSONEncode({
    key = key,
    deviceId = "roblox-user-" .. tostring(player.UserId)
})

-- Retry để chịu được Render cold start
local response
for attempt = 1, 5 do
    local ok, res = pcall(function()
        return httpFn({
            Url = "https://key-system-not7.onrender.com/api/v1/license/verify",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)

    if ok and res and res.Body then
        response = res
        break
    end

    warn(("[License] Lần %d/5 không kết nối được, thử lại sau 3s..."):format(attempt))
    task.wait(3)
end

if not response then
    player:Kick("Không thể kết nối license server.")
    return
end

local result
if type(response.Body) == "table" then
    result = response.Body
else
    local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
    result = okDecode and decoded or nil
end

-- Server trả rõ ràng key sai → kick
if type(result) ~= "table" then
    player:Kick("License server trả response không hợp lệ.")
    return
end

if result.valid ~= true then
    player:Kick("Key không hợp lệ: " .. tostring(result.reason or "unknown"))
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
