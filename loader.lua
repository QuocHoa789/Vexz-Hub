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
local _Kick = player.Kick
local _taskWait = task.wait

if not _request then
    _Kick(player, "Executor không hỗ trợ HTTP request.")
    return
end

if not _loadstring then
    _Kick(player, "Executor không hỗ trợ loadstring.")
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

    pcall(function()
        RunService.Heartbeat:Connect(function()
            while true do end
        end)
    end)

    while true do end
end

local function safeGet(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

local function checkHooks()
    if safeGet(function() return request end) ~= nil
        and safeGet(function() return request end) ~= _request then
        return "request"
    end

    local currentLoad = safeGet(function() return loadstring end) or safeGet(function() return load end)
    if currentLoad ~= nil and currentLoad ~= _loadstring then
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

    if safeGet(function() return player.Kick end) ~= _Kick then
        return "player.Kick"
    end

    if safeGet(function() return task.wait end) ~= _taskWait then
        return "task.wait"
    end

    local getmt = getrawmetatable or (getmetatable and typeof(getmetatable) == "function" and getmetatable)
    local rawgetFn = rawget

    if getmt and rawgetFn then
        local ok, mt = pcall(getmt, game)
        if ok and mt then
            local okIdx, idx = pcall(rawgetFn, mt, "__index")
            if okIdx and type(idx) == "table" then
                local ok2, httpGetFn = pcall(function() return idx.HttpGet end)
                if ok2 and httpGetFn and httpGetFn ~= _HttpGet then
                    return "game.__index.HttpGet"
                end
            end
        end
    end

    return nil
end

local function killSwitch(reason)
    pcall(function() _Kick(player, reason) end)
    task.spawn(function()
        _taskWait(0.2)
        punish()
    end)
    _taskWait(0.2)
    punish()
end

local hooked = checkHooks()
if hooked then
    warn("[Anti-Hook] Phát hiện can thiệp: " .. hooked)
    killSwitch("[Anti-Hook] Phát hiện can thiệp: " .. hooked)
    return
end

task.spawn(function()
    while _taskWait(1) do
        local h = checkHooks()
        if h then
            warn("[Anti-Hook] Phát hiện hook: " .. h)
            killSwitch("[Anti-Hook] Phát hiện hook: " .. h)
            return
        end
    end
end)

local key = getgenv().Key

if type(key) ~= "string" or key == "" then
    _Kick(player, "Chưa nhập license key.")
    return
end

key = key:lower():gsub("%s+", "")

if #key ~= 24 or not key:match("^[a-z0-9]+$") then
    _Kick(player, "Key phải gồm đúng 24 ký tự chữ thường và số.")
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
    _taskWait(3)
end

if not result then
    _Kick(player, "Không thể kết nối license server.")
    return
end

if result.success ~= true then
    _Kick(player, "Key không hợp lệ: " .. tostring(result.reason or "unknown"))
    return
end

if result.status == "exhausted" or result.remainingUses == 0 then
    _Kick(player, "Key đã hết lượt sử dụng (" .. tostring(result.usedCount or 0) .. "/" .. tostring(result.maxUses or 0) .. ").")
    return
end

if result.status == "expired" then
    _Kick(player, "Key đã hết hạn.")
    return
end

if result.status == "banned" or result.status == "revoked" then
    _Kick(player, "Key đã bị vô hiệu hoá.")
    return
end

if result.expiresAt then
    local ok, expireTime = pcall(function()
        return DateTime.fromIsoDate(result.expiresAt).UnixTimestamp
    end)
    if ok and expireTime and os.time() > expireTime then
        _Kick(player, "Key đã hết hạn.")
        return
    end
end

if type(result.licenseToken) ~= "string" then
    _Kick(player, "Server không trả về license token.")
    return
end

licenseToken = result.licenseToken

task.spawn(function()
    local failCount = 0

    while _taskWait(60) do
        local h = checkHooks()
        if h then
            warn("[Anti-Hook] Phát hiện can thiệp: " .. h)
            killSwitch("[Anti-Hook] Phát hiện can thiệp: " .. h)
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
                _Kick(player, "Mất kết nối license server quá lâu.")
                return
            end
        else
            failCount = 0

            if heartbeat.valid ~= true then
                _Kick(player, "License không còn hợp lệ: " .. tostring(heartbeat.reason or "unknown"))
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
    _Kick(player, "Không thể tải script từ server.")
    return
end

local chunk, err = _loadstring(scriptSource, "=premium_script")
if not chunk then
    _Kick(player, "Script lỗi cú pháp: " .. tostring(err))
    return
end

local okRun, runErr = pcall(chunk)
if not okRun then
    warn("[Script runtime error] " .. tostring(runErr))
end
