local skynet = require "skynet"

skynet.start(function()
    skynet.error("Server start...")
    
    -- 启动网关服务，监听 8001 端口
    local gateway = skynet.newservice("gateway")
    skynet.call(gateway, "lua", "open", 8001)
    
    skynet.exit()
end)
