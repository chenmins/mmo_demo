# lua-aoi API 文档

## 概述

lua-aoi 是一个高性能的区域兴趣 (Area of Interest, AOI) 管理系统，用于游戏服务器中的视野管理。它基于网格（tile）划分实现，能够高效地处理大量对象的视野进出事件。

### 主要特性

- **基于网格的空间划分**：将地图划分为固定大小的网格，提高查询效率
- **观察者-标记者模式**：支持对象作为观察者（watcher）和/或标记者（marker）
- **事件系统**：自动生成进入（enter）和离开（leave）事件
- **高效查询**：快速查询指定区域内的对象
- **灵活更新**：支持动态更新对象位置和视野范围

### 应用场景

- 游戏视野管理（查看周围玩家、怪物）
- 地理位置服务（查找附近的人/商店）
- 实时聊天范围控制
- 任何需要基于位置的交互系统

## 坐标系统

- 使用二维整数坐标系统
- 原点位于地图左下角
- X 轴向右递增，Y 轴向上递增
- 坐标范围由创建 AOI 实例时的参数决定

## 常量定义

### 模式常量 (mode)

对象可以同时具有多种模式（使用位或运算组合）：

```lua
local MODE_WATCHER = 1      -- 观察者：可以观察其他标记者
local MODE_MARKER = 2       -- 标记者：可以被观察者观察
local MODE_BOTH = 3         -- 同时是观察者和标记者 (1 | 2)
```

### 事件类型 (event_type)

```lua
local EVENT_ENTER = 1       -- 进入事件：标记者进入观察者视野
local EVENT_LEAVE = 2       -- 离开事件：标记者离开观察者视野
```

## API 参考

### aoi.new(x, y, map_size, tile_size)

创建一个新的 AOI 实例。

**参数：**
- `x` (integer): 地图左下角的 X 坐标
- `y` (integer): 地图左下角的 Y 坐标
- `map_size` (integer): 地图大小（宽度和高度，必须是正方形）
- `tile_size` (integer): 网格大小（map_size 必须能被 tile_size 整除）

**返回值：**
- AOI 实例对象

**示例：**
```lua
local aoi = require "aoi"
-- 创建一个从 (0,0) 开始，大小为 1000x1000，网格大小为 100 的 AOI
local aoiMgr = aoi.new(0, 0, 1000, 100)
```

**注意：**
- `map_size % tile_size` 必须等于 0，否则会报错
- 网格越小，查询越精确但内存占用越大；网格越大，查询速度越快但精度降低

---

### aoiMgr:insert(handle, x, y, view_width, view_height, layer, mode)

在 AOI 中插入一个对象。

**参数：**
- `handle` (integer): 对象的唯一标识符
- `x` (integer): 对象的 X 坐标
- `y` (integer): 对象的 Y 坐标
- `view_width` (integer): 视野宽度（对于观察者）或检测范围宽度（对于标记者）
- `view_height` (integer): 视野高度（对于观察者）或检测范围高度（对于标记者）
- `layer` (integer): 对象所在的层级（可用于过滤不同层级的对象）
- `mode` (integer): 对象模式（1=观察者，2=标记者，3=两者都是）

**返回值：**
- `boolean`: 成功返回 true，失败返回 false

**示例：**
```lua
-- 插入一个观察者，位置 (100, 100)，视野范围 200x200
local success = aoiMgr:insert(1001, 100, 100, 200, 200, 0, 1)

-- 插入一个标记者，位置 (150, 150)
local success = aoiMgr:insert(2001, 150, 150, 0, 0, 0, 2)

-- 插入一个既是观察者又是标记者的对象
local success = aoiMgr:insert(3001, 200, 200, 300, 300, 0, 3)
```

**注意：**
- 插入观察者时会立即生成与其视野内标记者的进入事件
- 对于观察者，view_width 和 view_height 定义了其可观察的矩形区域
- 对于纯标记者，view_width 和 view_height 通常设为 0
- 坐标必须在地图范围内，否则插入失败

---

### aoiMgr:update(handle, x, y, view_width, view_height, layer)

更新对象的位置、视野范围或层级。

**参数：**
- `handle` (integer): 要更新的对象的唯一标识符
- `x` (integer): 新的 X 坐标
- `y` (integer): 新的 Y 坐标
- `view_width` (integer): 新的视野宽度
- `view_height` (integer): 新的视野高度
- `layer` (integer): 新的层级

**返回值：**
- `boolean`: 成功返回 true，失败返回 false

**示例：**
```lua
-- 更新对象位置
local success = aoiMgr:update(1001, 150, 150, 200, 200, 0)

-- 更新对象位置和视野范围
local success = aoiMgr:update(1001, 200, 200, 300, 300, 0)
```

**注意：**
- 更新会自动生成相应的进入和离开事件
- 如果对象是观察者，视野变化会产生新的进入/离开事件
- 如果对象是标记者，位置变化可能使其进入或离开其他观察者的视野
- 新坐标必须在地图范围内

---

### aoiMgr:query(x, y, width, height, result_table)

查询指定矩形区域内的所有标记者。

**参数：**
- `x` (integer): 查询区域中心的 X 坐标
- `y` (integer): 查询区域中心的 Y 坐标
- `width` (integer): 查询区域的宽度
- `height` (integer): 查询区域的高度
- `result_table` (table): 用于存储查询结果的表（会被清空）

**返回值：**
- `integer`: 查询到的对象数量（如果没有查询到对象则返回 nil）

**示例：**
```lua
local result = {}
local count = aoiMgr:query(500, 500, 200, 200, result)
if count then
    for i = 1, count do
        print("Found object:", result[i])
    end
end
```

**注意：**
- 查询区域是以 (x, y) 为中心的矩形
- 只返回标记者（mode 包含 MODE_MARKER 的对象）
- result_table 会被修改，从索引 1 开始填充结果

---

### aoiMgr:erase(handle)

从 AOI 中移除一个对象。

**参数：**
- `handle` (integer): 要移除的对象的唯一标识符

**返回值：**
- 无返回值

**示例：**
```lua
aoiMgr:erase(1001)
```

**注意：**
- 移除观察者时会生成其视野内所有标记者的离开事件（如果启用了离开事件）
- 移除标记者时会为所有观察到它的观察者生成离开事件

---

### aoiMgr:has(handle)

检查 AOI 中是否存在指定的对象。

**参数：**
- `handle` (integer): 要检查的对象的唯一标识符

**返回值：**
- `boolean`: 存在返回 true，不存在返回 false

**示例：**
```lua
if aoiMgr:has(1001) then
    print("Object 1001 exists")
end
```

---

### aoiMgr:fire_event(handle, event_type)

为指定的标记者手动触发事件。

**参数：**
- `handle` (integer): 标记者的唯一标识符
- `event_type` (integer): 事件类型（1=进入，2=离开）

**返回值：**
- 无返回值

**示例：**
```lua
-- 手动触发进入事件（将该标记者通知给所有能看到它的观察者）
aoiMgr:fire_event(2001, 1)
```

**注意：**
- 此函数用于手动触发事件，例如对象状态改变时需要通知观察者
- 只对标记者有效
- 会向所有视野内包含该标记者的观察者生成事件

---

### aoiMgr:update_event(event_table)

获取自上次调用以来累积的所有事件。

**参数：**
- `event_table` (table): 用于存储事件的表

**返回值：**
- `integer`: 返回事件数据的总数量（事件数 × 3）

**事件格式：**
事件以三元组形式存储在 event_table 中：
- `event_table[i]`: 观察者的 handle
- `event_table[i+1]`: 标记者的 handle
- `event_table[i+2]`: 事件类型（1=进入，2=离开）

**示例：**
```lua
local events = {}
local count = aoiMgr:update_event(events)
if count then
    -- 每个事件占 3 个元素
    for i = 1, count, 3 do
        local watcher = events[i]      -- 观察者
        local marker = events[i + 1]   -- 标记者
        local event_type = events[i + 2]  -- 事件类型
        
        if event_type == 1 then
            print(string.format("Object %d sees %d (ENTER)", watcher, marker))
        else
            print(string.format("Object %d lost sight of %d (LEAVE)", watcher, marker))
        end
    end
end
```

**注意：**
- 调用此函数后，事件队列会被自动清空
- 应该在每次 insert、update、erase 操作后调用以处理生成的事件
- 事件数量 = count / 3

---

### aoiMgr:enable_debug(enabled)

启用或禁用调试输出。

**参数：**
- `enabled` (boolean): true 启用，false 禁用

**返回值：**
- 无返回值

**示例：**
```lua
aoiMgr:enable_debug(true)
```

**注意：**
- 启用后会在标准输出打印详细的内部操作信息
- 仅用于调试目的，生产环境应禁用

---

### aoiMgr:enable_leave_event(enabled)

启用或禁用离开事件。

**参数：**
- `enabled` (boolean): true 启用，false 禁用

**返回值：**
- 无返回值

**示例：**
```lua
aoiMgr:enable_leave_event(true)
```

**注意：**
- 默认情况下，离开事件是禁用的
- 启用后会在对象移动、更新或删除时生成离开事件
- 如果应用只关心进入事件，可以保持禁用以提高性能

## 工作原理

### 网格系统

AOI 将整个地图划分为 `(map_size / tile_size)²` 个网格。每个网格维护：
- 该网格内的标记者列表
- 观察该网格的观察者集合

### 观察者模式

- **观察者 (Watcher)**：具有视野范围，可以观察进入其视野的标记者
  - 视野是以对象位置为中心的矩形区域
  - 视野覆盖的所有网格都会记录该观察者
  
- **标记者 (Marker)**：可以被观察者观察的对象
  - 存储在其所在网格的标记者列表中
  - 当位置改变时，自动在网格间移动

### 事件生成时机

1. **插入观察者**：生成其视野内所有标记者的进入事件
2. **插入标记者**：如果有观察者的视野包含该位置，生成进入事件
3. **更新对象位置**：
   - 如果是观察者：视野变化产生新的进入/离开事件
   - 如果是标记者：进入或离开观察者视野时产生事件
4. **删除对象**：如果启用了离开事件，生成相应的离开事件
5. **手动触发**：调用 fire_event 手动生成事件

## 性能考虑

1. **网格大小选择**：
   - 网格太小：内存占用大，网格管理开销大
   - 网格太大：查询精度降低，可能返回更多不相关对象
   - 建议：网格大小约为平均视野范围的 1/2 到 1/4

2. **事件处理**：
   - 及时调用 update_event 处理事件，避免事件队列过大
   - 如果不需要离开事件，保持禁用以提高性能

3. **对象数量**：
   - 每个网格中的对象数量影响查询性能
   - 合理设计地图大小和网格大小，避免对象过度集中

## 限制

- 地图必须是正方形（宽度 = 高度）
- map_size 必须能被 tile_size 整除
- 坐标必须在地图范围内
- handle 必须是唯一的整数（通常使用玩家 ID、对象 ID 等）
- 层级（layer）参数目前仅作为对象属性存储，查询时不会自动过滤

## 常见问题

### Q: 为什么没有收到进入事件？
A: 检查以下几点：
1. 确保一个对象是观察者（mode 包含 1），另一个是标记者（mode 包含 2）
2. 确保标记者在观察者的视野范围内
3. 确保调用了 update_event 来获取事件

### Q: 如何实现双向可见？
A: 让两个对象都设置 mode = 3（既是观察者又是标记者）

### Q: query 和观察者视野有什么区别？
A: 
- query 是主动查询指定区域内的对象，不产生事件
- 观察者视野是自动监控，当标记者进入/离开时自动产生事件

### Q: 如何处理不同层级的对象？
A: layer 参数存储在对象中，但需要在应用层处理。可以在处理事件时检查 layer 值，决定是否处理该事件。

### Q: 可以创建多个 AOI 实例吗？
A: 可以，每个实例独立管理一个地图区域，适用于多地图场景。