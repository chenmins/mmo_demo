local skynet = require "skynet"
local yyjson = require "yyjson" -- 1. 引入 yyjson

local client_fd
local gateway
local scene 
local my_id
local player_id

local CMD = {}

function CMD.start(fd, gate, id)
    client_fd = fd
    gateway = gate
    my_id = id or math.random(10000, 99999)
    skynet.error("Agent start. ID:", my_id)
end

function CMD.disconnect()
    if scene and player_id then
        skynet.call(scene, "lua", "leave", player_id)
    end
    skynet.exit()
end

function CMD.client_msg(msg_str)
    skynet.error("client msg:", msg_str)
    
    -- 2. 使用 yyjson.decode
    local ok, err_or_msg = pcall(yyjson.decode, msg_str)
    if not ok then
        skynet.error("JSON decode failed:", err_or_msg)
        return
    end
    
    local msg = err_or_msg

    if msg.cmd == "enter_map" then
        scene = skynet.uniqueservice("scene")
        pcall(skynet.call, scene, "lua", "init") 
        skynet.call(scene, "lua", "enter", skynet.self(), my_id)
        
    elseif msg.cmd == "login" then
        -- Extract player_id from request
        player_id = msg.userid or math.random(10000, 99999)
        skynet.error("Player login. ID:", player_id)
        
        -- Initialize scene service
        scene = skynet.uniqueservice("scene")
        local ok, err = pcall(skynet.call, scene, "lua", "init")
        if not ok then
            skynet.error("Scene init error:", err)
        end
        
        -- Enter player into scene
        local ret = skynet.call(scene, "lua", "enter", skynet.self(), player_id)
        if ret then
            skynet.error("Login success, entering scene")
        end
        
    elseif msg.cmd == "move" then
        -- 直接通知 scene 移动，不需要等待返回 (send)
        -- 实际项目中这里应该做防作弊检查（速度校验等）
        if scene and player_id then
            skynet.send(scene, "lua", "move", player_id, msg.x, msg.y)
        end
    end
end

function CMD.send(json_str)
    skynet.error("Sending to client:", json_str)
    skynet.call(gateway, "lua", "send_to_client", client_fd, json_str)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            f(...)
        end
    end)
end)
