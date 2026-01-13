local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket" -- Skynet 自带的 WebSocket 库

local handle = {}
local agents = {} -- 存储 id -> agent_handle 的映射

-- WebSocket 连接建立
function handle.connect(id)
    print("New connection:", id)
end

-- WebSocket 握手完成
function handle.handshake(id, header, url)
    print("Handshake done:", id)
    -- 为该连接创建一个 agent 服务
    local agent = skynet.newservice("agent")
    agents[id] = agent
    -- 告诉 agent 初始化
    skynet.send(agent, "lua", "start", id, skynet.self())
end

-- 收到客户端消息
function handle.message(id, msg)
    local agent = agents[id]
    if agent then
        -- 转发给对应的 agent
        skynet.send(agent, "lua", "client_msg", msg)
    end
end

-- 连接关闭
function handle.close(id, code, reason)
    print("Close:", id, code, reason)
    local agent = agents[id]
    if agent then
        skynet.send(agent, "lua", "disconnect")
        agents[id] = nil
    end
end

function handle.error(id)
    print("Error:", id)
    handle.close(id)
end

-- 启动监听
local CMD = {}
function CMD.open(port)
    local id = socket.listen("0.0.0.0", port)
    skynet.error("Gateway Listen on", port)
    socket.start(id, function(id, addr)
        -- 将 socket 升级为 websocket 协议处理
        websocket.accept(id, handle, "ws", addr)
    end)
end

-- 发送消息给客户端 (供 Agent 调用)
function CMD.send_to_client(id, msg)
    websocket.write(id, msg)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
