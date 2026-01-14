local skynet = require "skynet"
local yyjson = require "yyjson"
local aoi = require "aoi" -- 加载你的 C 模块
local map_config = require "map_config" -- 加载地图配置 (Load map configuration)

local CMD = {}
local agents = {}      -- player_id -> agent_handle
local entities = {}    -- player_id/npc_id -> data
local aoi_space        

-- 从配置文件加载参数 (Load parameters from config file)
local MAP_WIDTH = map_config.MAP_WIDTH
local MAP_HEIGHT = map_config.MAP_HEIGHT
local TILE_SIZE = map_config.TILE_SIZE
local VIEW_WIDTH = map_config.VIEW_WIDTH
local VIEW_HEIGHT = map_config.VIEW_HEIGHT

-- AOI 常量 (AOI constants)
local MODE_WATCHER = map_config.MODE_WATCHER
local MODE_MARKER = map_config.MODE_MARKER
local MODE_BOTH = map_config.MODE_BOTH
local EVENT_ENTER = map_config.EVENT_ENTER
local EVENT_LEAVE = map_config.EVENT_LEAVE

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

    -- 1. 初始化 AOI 空间 (Initialize AOI space)
    -- 参数: x, y, map_size, tile_size
    aoi_space = aoi.new(0, 0, MAP_WIDTH, TILE_SIZE) 
    
    -- 启用离开事件 (Enable leave events) - 重要！必须启用才能清理离线玩家
    -- Important! Must be enabled to clean up disconnected players
    aoi_space:enable_leave_event(map_config.ENABLE_LEAVE_EVENT)
    
    -- 开启调试 (Enable debug) - 可选
    if map_config.ENABLE_AOI_DEBUG then
        aoi_space:enable_debug(true)
    end

    -- 从配置文件加载 NPC (Load NPCs from config file)
    for _, info in ipairs(map_config.NPCS) do
        local id = npc_id_counter
        npc_id_counter = npc_id_counter + 1
        
        entities[id] = {
            id = id,
            type = info.type,
            x = info.x,
            y = info.y,
            name = info.name
        }
        
        -- 2. 插入 NPC (Insert NPC)
        -- API: insert(handle, x, y, view_w, view_h, layer, mode)
        -- NPC 只是标记者 (MODE_MARKER)，视野宽高设为 0
        -- NPCs are only markers (MODE_MARKER), view width/height set to 0
        aoi_space:insert(id, info.x, info.y, 0, 0, 0, MODE_MARKER)
    end
    skynet.error("Scene initialized. NPCs loaded.")
end

function CMD.enter(agent_handle, player_id)
    agents[player_id] = agent_handle
    
    -- 使用配置文件中的生成范围 (Use spawn range from config file)
    local x = math.random(map_config.SPAWN_MIN_X, map_config.SPAWN_MAX_X)
    local y = math.random(map_config.SPAWN_MIN_Y, map_config.SPAWN_MAX_Y)
    
    entities[player_id] = {
        id = player_id,
        type = "player",
        x = x,
        y = y
    }

    -- 发送玩家自己的信息 (Send player's own info)
    local self_info = {
        cmd = "self_info",
        data = entities[player_id]
    }
    local json_msg = yyjson.encode(self_info)
    skynet.error("Sending self_info to player", player_id, ":", json_msg)
    skynet.send(agent_handle, "lua", "send", json_msg)

    -- 3. 插入玩家 (Insert player)
    -- 玩家既看别人也被别人看 (MODE_BOTH)
    -- Players can both watch and be watched (MODE_BOTH)
    -- 视野范围 VIEW_WIDTH x VIEW_HEIGHT
    -- View range VIEW_WIDTH x VIEW_HEIGHT
    skynet.error("Inserting player into AOI:", player_id, x, y, "view:", VIEW_WIDTH, "x", VIEW_HEIGHT)
    aoi_space:insert(player_id, x, y, VIEW_WIDTH, VIEW_HEIGHT, 0, MODE_BOTH)
    
    -- 4. 处理插入后产生的 Enter 事件 (Handle Enter events after insertion)
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

-- 碰撞检测常量 (Collision detection constants)
local ENTITY_SIZE = map_config.ENTITY_SIZE
local COLLISION_DISTANCE = map_config.COLLISION_DISTANCE
local BOUNDARY_BUFFER = map_config.BOUNDARY_BUFFER

-- Check if a position collides with any entity
-- Note: For production with many entities, consider using spatial partitioning
-- or the AOI query system for better performance. This linear search is
-- acceptable for small-scale demos with few entities.
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

    -- 检查地图边界 (Check map boundaries)
    if x < BOUNDARY_BUFFER or x > MAP_WIDTH - BOUNDARY_BUFFER or 
       y < BOUNDARY_BUFFER or y > MAP_HEIGHT - BOUNDARY_BUFFER then
        -- 超出边界 - 发送位置校正给客户端 (Out of bounds - send correction to client)
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

    -- 检查与其他实体的碰撞 (Check collision with other entities)
    local has_collision, collided_with = check_collision(player_id, x, y)
    if has_collision then
        -- 检测到碰撞 - 发送位置校正给客户端 (Collision detected - send correction to client)
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

    -- 1. 更新内存数据 (Update memory data)
    p.x = x
    p.y = y

    -- 2. 更新 AOI 位置 (Update AOI position)
    -- API: update(handle, x, y, view_w, view_h, layer)
    aoi_space:update(player_id, x, y, VIEW_WIDTH, VIEW_HEIGHT, 0)

    -- 3. 处理 AOI 产生的 Enter/Leave 事件 (Handle AOI Enter/Leave events)
    handle_aoi_events()

    -- 4. 广播移动消息给视野内的人 (Broadcast move message to nearby players)
    broadcast_move(player_id, x, y)
end

 

function CMD.leave(player_id)
    if not entities[player_id] then return end
    
    -- 7. 移除对象 (Remove object)
    -- API: erase(handle)
    -- 移除时会自动触发 Leave 事件给周围的人 (Automatically triggers Leave events)
    skynet.error("Player leaving:", player_id)
    aoi_space:erase(player_id)
    handle_aoi_events()

    agents[player_id] = nil
    entities[player_id] = nil
    skynet.error("Player removed:", player_id)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
