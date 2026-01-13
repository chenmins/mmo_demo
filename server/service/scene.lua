local skynet = require "skynet"
local yyjson = require "yyjson"
local aoi = require "aoi" -- 加载你的 C 模块

local CMD = {}
local agents = {}      -- player_id -> agent_handle
local entities = {}    -- player_id/npc_id -> data
local aoi_space        

-- 地图配置
local MAP_WIDTH = 2000
local MAP_HEIGHT = 2000
local TILE_SIZE = 50   -- 网格大小 (2000/50 = 40x40网格)
local VIEW_WIDTH = 400 -- 视野宽
local VIEW_HEIGHT = 400-- 视野高

-- AOI 常量 (根据你的文档)
local MODE_WATCHER = 1
local MODE_MARKER = 2
local MODE_BOTH = 3
local EVENT_ENTER = 1
local EVENT_LEAVE = 2

local npc_id_counter = 1

-- 辅助函数：处理 AOI 事件
local function handle_aoi_events()
    local events = {}
    -- 获取事件列表
    local count = aoi_space:update_event(events)
    
    skynet.error("AOI events count:", count or 0)
    
    if count and count > 0 then
        -- 事件格式：[watcher, marker, type, watcher, marker, type, ...]
        for i = 1, count, 3 do
            local watcher_id = events[i]
            local marker_id = events[i+1]
            local event_type = events[i+2]
            
            skynet.error("AOI event:", watcher_id, "sees", marker_id, "type:", event_type)

            -- 我们只关心把消息发给 watcher (观察者)
            local watcher_agent = agents[watcher_id]
            if watcher_agent then
                if event_type == EVENT_ENTER then
                    -- 这里的 marker 可能是 NPC 也可能是其他玩家
                    local ent = entities[marker_id]
                    if ent then
                        local msg = { cmd = "aoi_add", entity = ent }
                        local json_msg = yyjson.encode(msg)
                        skynet.error("Sending aoi_add to", watcher_id, ":", json_msg)
                        skynet.send(watcher_agent, "lua", "send", json_msg)
                    else
                        skynet.error("Entity not found for marker_id:", marker_id)
                    end
                elseif event_type == EVENT_LEAVE then
                    local msg = { cmd = "aoi_remove", id = marker_id }
                    skynet.send(watcher_agent, "lua", "send", yyjson.encode(msg))
                end
            else
                skynet.error("Watcher agent not found for watcher_id:", watcher_id)
            end
        end
    end
end

function CMD.init()
    if aoi_space then return end

    -- 1. 初始化 AOI 空间
    -- 参数: x, y, map_size, tile_size
    aoi_space = aoi.new(0, 0, MAP_WIDTH, TILE_SIZE) 
    
    -- 开启调试 (可选，如果太吵可以关掉)
    -- aoi_space:enable_debug(true)

    local npcs = {
        {x=200, y=200, name="Guard"},
        {x=400, y=300, name="Villager"},
        {x=600, y=200, name="Merchant"}
    }

    for _, info in ipairs(npcs) do
        local id = npc_id_counter
        npc_id_counter = npc_id_counter + 1
        
        entities[id] = {
            id = id,
            type = "npc",
            x = info.x,
            y = info.y,
            name = info.name
        }
        
        -- 2. 插入 NPC
        -- API: insert(handle, x, y, view_w, view_h, layer, mode)
        -- NPC 只是标记者 (MODE_MARKER)，视野宽高设为 0
        aoi_space:insert(id, info.x, info.y, 0, 0, 0, MODE_MARKER)
    end
    skynet.error("Scene initialized. NPCs loaded.")
end

function CMD.enter(agent_handle, player_id)
    agents[player_id] = agent_handle
    
    local x, y = math.random(100, 300), math.random(100, 300)
    
    entities[player_id] = {
        id = player_id,
        type = "player",
        x = x,
        y = y
    }

    -- 发送玩家自己的信息
    local self_info = {
        cmd = "self_info",
        data = entities[player_id]
    }
    local json_msg = yyjson.encode(self_info)
    skynet.error("Sending self_info to player", player_id, ":", json_msg)
    skynet.send(agent_handle, "lua", "send", json_msg)

    -- 3. 插入玩家
    -- 玩家既看别人也被别人看 (MODE_BOTH)
    -- 视野范围 VIEW_WIDTH x VIEW_HEIGHT
    skynet.error("Inserting player into AOI:", player_id, x, y)
    aoi_space:insert(player_id, x, y, VIEW_WIDTH, VIEW_HEIGHT, 0, MODE_BOTH)
    
    -- 4. 处理插入后产生的 Enter 事件
    skynet.error("Handling AOI events for player:", player_id)
    handle_aoi_events()
    
    return true
end


-- 广播位置更新给周围的玩家
local function broadcast_move(who_id, x, y)
    local nearby = {}
    -- 查询周围视野内的对象 (包括自己)
    -- 注意：query 返回的是所有 MODE_MARKER (包括玩家和NPC)
    local count = aoi_space:query(x, y, VIEW_WIDTH, VIEW_HEIGHT, nearby)
    
    local move_msg = { 
        cmd = "entity_move", 
        id = who_id, 
        x = x, 
        y = y 
    }
    local json_msg = yyjson.encode(move_msg)

    if count then
        for i = 1, count do
            local neighbor_id = nearby[i]
            -- 这里的 neighbor_id 可能是 NPC，也可能是玩家
            -- 我们只给在线的玩家 (agents 中存在的) 发送消息
            local agent = agents[neighbor_id]
            if agent then
                skynet.send(agent, "lua", "send", json_msg)
            end
        end
    end
end

-- Collision detection constants
local ENTITY_SIZE = 40  -- Size of player/NPC hitbox (matches client rectangle size)
local COLLISION_DISTANCE = ENTITY_SIZE  -- Minimum distance between entities

-- Check if a position collides with any entity
local function check_collision(moving_id, new_x, new_y)
    for id, ent in pairs(entities) do
        -- Don't check collision with self
        if id ~= moving_id then
            local dx = new_x - ent.x
            local dy = new_y - ent.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- If too close, there's a collision
            if distance < COLLISION_DISTANCE then
                return true, id  -- Collision detected
            end
        end
    end
    return false  -- No collision
end

function CMD.move(player_id, x, y)
    local p = entities[player_id]
    if not p then return end

    -- Check map boundaries
    if x < 20 or x > MAP_WIDTH - 20 or y < 20 or y > MAP_HEIGHT - 20 then
        -- Out of bounds - send correction to client
        local correction_msg = {
            cmd = "entity_move",
            id = player_id,
            x = p.x,
            y = p.y
        }
        local agent = agents[player_id]
        if agent then
            skynet.send(agent, "lua", "send", yyjson.encode(correction_msg))
        end
        return
    end

    -- Check collision with other entities
    local has_collision, collided_with = check_collision(player_id, x, y)
    if has_collision then
        -- Collision detected - send position correction back to client
        skynet.error("Collision detected for player", player_id, "with entity", collided_with)
        local correction_msg = {
            cmd = "entity_move",
            id = player_id,
            x = p.x,
            y = p.y
        }
        local agent = agents[player_id]
        if agent then
            skynet.send(agent, "lua", "send", yyjson.encode(correction_msg))
        end
        return
    end

    -- 1. 更新内存数据
    p.x = x
    p.y = y

    -- 2. 更新 AOI 位置
    -- API: update(handle, x, y, view_w, view_h, layer)
    aoi_space:update(player_id, x, y, VIEW_WIDTH, VIEW_HEIGHT, 0)

    -- 3. 处理 AOI 产生的 Enter/Leave 事件 (比如走太远看不见了)
    handle_aoi_events()

    -- 4. 【新增】广播移动消息给视野内的人 (包括自己，这样客户端位置会被服务器修正)
    broadcast_move(player_id, x, y)
end

 

function CMD.leave(player_id)
    if not entities[player_id] then return end
    
    -- 7. 移除对象
    -- API: erase(handle)
    -- 移除时会自动触发 Leave 事件给周围的人
    aoi_space:erase(player_id)
    handle_aoi_events()

    agents[player_id] = nil
    entities[player_id] = nil
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
