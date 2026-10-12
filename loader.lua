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

local VERIFY_URL = "https://key-system-not7.onrender.com/api/v1/license/verify"

local body = _JSONEncode({
    key = key,
    deviceId = "roblox-user-" .. tostring(player.UserId)
})

local function doVerify()
    local ok, res = pcall(function()
        return _request({
            Url = VERIFY_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)

    if not ok or not res or not res.Body then
        return nil, "no_response"
    end

    local result
    if type(res.Body) == "table" then
        result = res.Body
    else
        local okDecode, decoded = pcall(_JSONDecode, HttpService, res.Body)
        result = okDecode and decoded or nil
    end

    if type(result) ~= "table" then
        return nil, "bad_response"
    end

    return result
end

local result
for attempt = 1, 5 do
    local r, err = doVerify()
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

if result.valid ~= true then
    player:Kick("Key không hợp lệ: " .. tostring(result.reason or "unknown"))
    return
end

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

        local r, err = doVerify()

        if not r then
            failCount += 1
            warn(("[License] Heartbeat thất bại lần %d (%s)"):format(failCount, tostring(err)))

            if failCount >= 5 then
                player:Kick("Mất kết nối license server quá lâu.")
                return
            end
        else
            failCount = 0

            if r.valid ~= true then
                player:Kick("License đã bị thu hồi: " .. tostring(r.reason or "unknown"))
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
