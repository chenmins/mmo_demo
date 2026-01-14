-- ============================================
-- 游戏地图和视野配置文件
-- Game Map and View Configuration
-- ============================================

local config = {}

-- ============================================
-- 地图配置 (Map Configuration)
-- ============================================

-- 地图宽度（像素）
-- Map width in pixels
config.MAP_WIDTH = 2000

-- 地图高度（像素）
-- Map height in pixels  
config.MAP_HEIGHT = 2000

-- AOI 网格大小（像素）
-- AOI tile/grid size in pixels
-- 注意：MAP_WIDTH 必须能被 TILE_SIZE 整除
-- Note: MAP_WIDTH must be divisible by TILE_SIZE
config.TILE_SIZE = 50   -- 2000/50 = 40x40 网格 (40x40 grids)

-- ============================================
-- 玩家视野配置 (Player View Configuration)
-- ============================================

-- 客户端视口大小（像素）
-- Client viewport size in pixels
config.VIEWPORT_WIDTH = 800   -- 客户端显示的宽度 (Client display width)
config.VIEWPORT_HEIGHT = 600  -- 客户端显示的高度 (Client display height)

-- AOI 视野范围（像素）
-- AOI view range in pixels
-- 重要：这个值定义了从玩家位置为中心的矩形范围
-- Important: This defines a rectangle centered on the player position
-- 所以实际可见范围是 VIEW_WIDTH/2 向左右，VIEW_HEIGHT/2 向上下
-- So the actual visible range is VIEW_WIDTH/2 left/right, VIEW_HEIGHT/2 up/down
--
-- 为了匹配客户端视口（800x600），AOI 视野范围应该设置为：
-- To match client viewport (800x600), AOI view range should be set to:
-- VIEW_WIDTH = 800 (匹配客户端宽度 / Match client width)
-- VIEW_HEIGHT = 600 (匹配客户端高度 / Match client height)
config.VIEW_WIDTH = 800   
config.VIEW_HEIGHT = 600  

-- ============================================
-- 碰撞检测配置 (Collision Detection Configuration)
-- ============================================

-- 实体大小（像素）
-- Entity size in pixels (hitbox)
config.ENTITY_SIZE = 40

-- 碰撞检测距离（像素）
-- Collision detection distance in pixels
-- 两个实体之间的最小距离
-- Minimum distance between two entities
config.COLLISION_DISTANCE = 40

-- 地图边界缓冲区（像素）
-- Map boundary buffer in pixels
-- 玩家不能移动到离地图边缘这么近的位置
-- Players cannot move this close to map edges
config.BOUNDARY_BUFFER = 20

-- ============================================
-- 小地图配置 (Minimap Configuration)
-- ============================================

-- 小地图大小（像素）
-- Minimap size in pixels
config.MINIMAP_WIDTH = 200
config.MINIMAP_HEIGHT = 200

-- 小地图位置（右上角）
-- Minimap position (top-right corner)
config.MINIMAP_OFFSET_X = 10  -- 距离右边的像素 (pixels from right)
config.MINIMAP_OFFSET_Y = 10  -- 距离顶部的像素 (pixels from top)

-- ============================================
-- NPC 配置 (NPC Configuration)
-- ============================================

-- NPC 信息列表
-- List of NPCs with their spawn positions and names
config.NPCS = {
    {
        name = "Guard",      -- 守卫 (Guard)
        x = 200,
        y = 200,
        type = "npc"
    },
    {
        name = "Villager",   -- 村民 (Villager)
        x = 400,
        y = 300,
        type = "npc"
    },
    {
        name = "Merchant",   -- 商人 (Merchant)
        x = 600,
        y = 200,
        type = "npc"
    }
}

-- ============================================
-- 玩家生成配置 (Player Spawn Configuration)
-- ============================================

-- 玩家随机生成范围（像素）
-- Player random spawn range in pixels
config.SPAWN_MIN_X = 100
config.SPAWN_MAX_X = 300
config.SPAWN_MIN_Y = 100
config.SPAWN_MAX_Y = 300

-- ============================================
-- AOI 系统配置 (AOI System Configuration)
-- ============================================

-- AOI 模式常量
-- AOI mode constants
config.MODE_WATCHER = 1  -- 观察者：可以观察其他标记者 (Watcher: can observe markers)
config.MODE_MARKER = 2   -- 标记者：可以被观察者观察 (Marker: can be observed by watchers)
config.MODE_BOTH = 3     -- 同时是观察者和标记者 (Both watcher and marker)

-- AOI 事件类型
-- AOI event types
config.EVENT_ENTER = 1   -- 进入事件 (Enter event)
config.EVENT_LEAVE = 2   -- 离开事件 (Leave event)

-- 是否启用 AOI 调试输出
-- Enable AOI debug output
config.ENABLE_AOI_DEBUG = false

-- 是否启用离开事件
-- Enable leave events
-- 重要：必须启用才能在玩家离开时清理实体
-- Important: Must be enabled to clean up entities when players leave
config.ENABLE_LEAVE_EVENT = true

-- ============================================
-- 网络配置 (Network Configuration)
-- ============================================

-- 移动消息发送间隔（毫秒）
-- Movement message send interval in milliseconds
config.MOVE_SEND_INTERVAL = 50

-- ============================================
-- 调试配置 (Debug Configuration)
-- ============================================

-- 启用服务器调试日志
-- Enable server debug logs
config.DEBUG_SERVER = true

-- 启用客户端调试日志
-- Enable client debug logs
config.DEBUG_CLIENT = true

-- ============================================
-- 返回配置表
-- Return configuration table
-- ============================================

return config
