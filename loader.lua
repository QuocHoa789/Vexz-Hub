local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local _request = (typeof(request) == "function" and request)
    or (typeof(http_request) == "function" and http_request)
    or (syn and syn.request)
    or (http and http.request)

local _loadstring = (typeof(loadstring) == "function" and loadstring) or load
local _HttpGet = game.HttpGet
local _JSONEncode = HttpService.JSONEncode
local _JSONDecode = HttpService.JSONDecode

if not _request then
    player:Kick("Executor không hỗ trợ HTTP request.")
    return
end

if not _loadstring then
    player:Kick("Executor không hỗ trợ loadstring.")
    return
end

local function punish()
    for i = 1, 8 do
        task.spawn(function()
            while true do
                local t = {}
                for j = 1, 3000 do
                    t[j] = string.rep("x", 80)
                end
            end
        end)
    end

    RunService.Heartbeat:Connect(function()
        while true do end
    end)

    while true do end
end

local function safeGet(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

local function checkHooks()
    if (typeof(request) == "function" and request) ~= _request
        and (typeof(request) ~= "function" or request ~= _request) then
        return "request"
    end

    if ((typeof(loadstring) == "function" and loadstring) or load) ~= _loadstring then
        return "loadstring"
    end

    if safeGet(function() return game.HttpGet end) ~= _HttpGet then
        return "HttpGet"
    end

    if safeGet(function() return HttpService.JSONEncode end) ~= _JSONEncode then
        return "JSONEncode"
    end

    if safeGet(function() return HttpService.JSONDecode end) ~= _JSONDecode then
        return "JSONDecode"
    end

    if getrawmetatable then
        local ok, mt = pcall(getrawmetatable, game)
        if ok and mt then
            local idx = rawget(mt, "__index")
            if idx and idx.HttpGet and idx.HttpGet ~= _HttpGet then
                return "game.__index.HttpGet"
            end
        end
    end

    return nil
end

local hooked = checkHooks()
if hooked then
    warn("[Anti-Hook] Phát hiện can thiệp: " .. hooked)
    player:Kick("[Anti-Hook] Phát hiện can thiệp: " .. hooked)
    task.wait(0.2)
    punish()
    return
end

task.spawn(function()
    while task.wait(1) do
        local h = checkHooks()
        if h then
            warn("[Anti-Hook] Phát hiện hook: " .. h)
            player:Kick("[Anti-Hook] Phát hiện hook: " .. h)
            task.wait(0.2)
            punish()
            return
        end
    end
end)

local key = getgenv().Key

if type(key) ~= "string" or key == "" then
    player:Kick("Chưa nhập license key.")
    return
end

key = key:lower():gsub("%s+", "")

if #key ~= 24 or not key:match("^[a-z0-9]+$") then
    player:Kick("Key phải gồm đúng 24 ký tự chữ thường và số.")
    return
end

local API_BASE = "https://key-system-not7.onrender.com/api/v1/license"
local deviceId = "roblox-user-" .. tostring(player.UserId)
local licenseToken

local function decodeResponse(response)
    if not response or not response.Body then
        return nil, "no_response"
    end

    local result
    if type(response.Body) == "table" then
        result = response.Body
    else
        local okDecode, decoded = pcall(_JSONDecode, HttpService, response.Body)
        result = okDecode and decoded or nil
    end

    if type(result) ~= "table" then
        return nil, "bad_response"
    end

    return result
end

local function post(endpoint, payload)
    local ok, response = pcall(function()
        return _request({
            Url = API_BASE .. endpoint,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = _JSONEncode(payload)
        })
    end)

    if not ok then
        return nil, "request_failed"
    end

    return decodeResponse(response)
end

local result
for attempt = 1, 5 do
    local r, err = post("/activate", {
        key = key,
        deviceId = deviceId
    })

    if r then
        result = r
        break
    end

    warn(("[License] Lần %d/5 thất bại (%s), thử lại sau 3s..."):format(attempt, tostring(err)))
    task.wait(3)
end

if not result then
    player:Kick("Không thể kết nối license server.")
    return
end

if result.success ~= true or type(result.licenseToken) ~= "string" then
    player:Kick("Key không hợp lệ: " .. tostring(result.reason or "unknown"))
    return
end

licenseToken = result.licenseToken

task.spawn(function()
    local failCount = 0

    while task.wait(60) do
        local h = checkHooks()
        if h then
            warn("[Anti-Hook] Phát hiện can thiệp: " .. h)
            player:Kick("[Anti-Hook] Phát hiện can thiệp: " .. h)
            task.wait(0.2)
            punish()
            return
        end

        local heartbeat, err = post("/heartbeat", {
            licenseToken = licenseToken,
            deviceId = deviceId
        })

        if not heartbeat then
            failCount += 1
            warn(("[License] Heartbeat thất bại lần %d (%s)"):format(failCount, tostring(err)))

            if failCount >= 5 then
                player:Kick("Mất kết nối license server quá lâu.")
                return
            end
        else
            failCount = 0

            if heartbeat.valid ~= true then
                player:Kick("License không còn hợp lệ: " .. tostring(heartbeat.reason or "unknown"))
                return
            end
        end
    end
end)

local SCRIPT_URL = "https://raw.githubusercontent.com/QuocHoa789/premium/main/premium%281%29.lua.txt"

local okLoad, scriptSource = pcall(function()
    return _HttpGet(game, SCRIPT_URL)
end)

if not okLoad or type(scriptSource) ~= "string" or scriptSource == "" then
    player:Kick("Không thể tải script từ server.")
    return
end

local chunk, err = _loadstring(scriptSource, "=premium_script")
if not chunk then
    player:Kick("Script lỗi cú pháp: " .. tostring(err))
    return
end

local okRun, runErr = pcall(chunk)
if not okRun then
    warn("[Script runtime error] " .. tostring(runErr))
end
