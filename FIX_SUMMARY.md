# Black Screen Fix - Technical Summary

## Issue Description
After updating to Linux executables and clicking "Click to Login", users saw:
- Black screen
- Only "Game Scene Loaded" text visible
- No player block (blue square)
- No NPC blocks (red squares)

## Root Cause Analysis

The problem was a **message routing issue** in the server code:

### What Was Wrong
1. The gateway service (`gateway.lua`) receives WebSocket messages from clients
2. Gateway forwards messages to agent using: `skynet.send(agent, "lua", "client_msg", msg)` (line 28)
3. This calls the `CMD.client_msg` function in agent.lua
4. **However**, the login handler was placed in a separate "client" protocol dispatcher (lines 73-112 in old code)
5. This protocol dispatcher was **never registered or called** by the gateway
6. Result: Login messages were received but never processed

### Message Flow Diagram

**Before Fix (Broken):**
```
Browser → WebSocket → Gateway → calls CMD.client_msg()
                                      ↓
                                 Only handled "enter_map"
                                      ↓
                                 Login ignored ❌
```

**After Fix (Working):**
```
Browser → WebSocket → Gateway → calls CMD.client_msg()
                                      ↓
                                 Handles "login" ✅
                                      ↓
                                 Scene initialized
                                      ↓
                                 Player entered
                                      ↓
                                 Messages sent back
                                      ↓
                                 Client renders entities ✅
```

## The Fix

### Changes Made to `server/service/agent.lua`

**Before:**
```lua
function CMD.client_msg(msg_str)
    local ok, msg = pcall(yyjson.decode, msg_str)
    if not ok then return end

    if msg.cmd == "enter_map" then
        -- only handled enter_map
    end
end

-- Login handler in separate protocol dispatcher (never called)
skynet.register_protocol {
    name = "client",
    dispatch = function(fd, source, msg)
        if req.cmd == "login" then
            -- This code never executed!
        end
    end
}
```

**After:**
```lua
function CMD.client_msg(msg_str)
    local ok, msg = pcall(yyjson.decode, msg_str)
    if not ok then return end

    if msg.cmd == "enter_map" then
        -- original code
        
    elseif msg.cmd == "login" then
        -- Moved login logic HERE ✅
        player_id = msg.userid or math.random(10000, 99999)
        scene = skynet.uniqueservice("scene")
        pcall(skynet.call, scene, "lua", "init")
        skynet.call(scene, "lua", "enter", skynet.self(), player_id)
        
    elseif msg.cmd == "move" then
        -- Moved move logic HERE ✅
        skynet.send(scene, "lua", "move", player_id, msg.x, msg.y)
    end
end

-- Removed unused protocol dispatcher
```

### Additional Changes

1. **Enhanced Logging** (`agent.lua` and `scene.lua`):
   - Added logging for all received messages
   - Added logging for scene initialization
   - Added logging for AOI events
   - Added logging for message sending

2. **Test Pages Created**:
   - `test_ws.html` - Simple WebSocket connection test
   - `test_game.html` - Canvas-based game test (no Phaser dependency)

## Verification

### Server Logs (Working)
```
[:0000000a] client msg: {"cmd":"login","userid":12345}
[:0000000a] Player login. ID: 12345
[:0000000b] Scene initialized. NPCs loaded.
[:0000000b] Sending self_info to player 12345
[:0000000b] Inserting player into AOI: 12345 286 235
[:0000000b] AOI events count: 6
[:0000000b] Sending aoi_add to 12345 (NPC Guard)
[:0000000b] Sending aoi_add to 12345 (NPC Villager)
[:0000000a] Login success, entering scene
```

### Client Messages (Working)
```javascript
← Received: {"cmd":"self_info","data":{"type":"player","x":286,"id":12345,"y":235}}
← Received: {"cmd":"aoi_add","entity":{"type":"npc","x":200,"y":200,"name":"Guard","id":1}}
← Received: {"cmd":"aoi_add","entity":{"type":"npc","x":400,"y":300,"name":"Villager","id":2}}
```

## Testing Instructions

### Option 1: Test Pages (Recommended for Verification)
```bash
# Start server
cd server
./skynet config

# Start HTTP server (in another terminal)
cd client
python3 -m http.server 8000

# Open browser
http://localhost:8000/test_ws.html   # WebSocket test
http://localhost:8000/test_game.html # Game test
```

### Option 2: Original Game (Requires Phaser CDN)
```bash
# Same setup as above
http://localhost:8000/index.html

# Note: If Phaser CDN is blocked, use test_game.html instead
```

## Expected Results

### Visual
- **Blue square**: Your player
- **Red squares**: NPCs (Guard, Villager, Merchant if in range)
- **Text labels**: Show type and ID above each entity
- **Status message**: "Game Scene Loaded - Entities: X"

### Behavior
- Login completes successfully
- Player spawns at random position (100-300, 100-300)
- NPCs appear if within 400 pixel view distance
- All entities render immediately after login
- No black screen

## Technical Notes

### Why Protocol Dispatcher Wasn't Used
Skynet's `register_protocol` is for registering **custom protocol handlers** for binary protocols. The gateway uses the standard "lua" protocol with named message routing (`CMD` table), so custom protocol registration wasn't needed.

### Message Routing in Skynet
- `skynet.send(service, "lua", "function_name", args...)` → calls `CMD.function_name` in target service
- `skynet.call(service, "lua", "function_name", args...)` → same but waits for response
- Protocol dispatcher is for low-level protocol handling, not used here

## Summary

The fix was simple but critical:
1. **Identified** that login handler was in wrong place (unused protocol dispatcher)
2. **Moved** login and move logic to the correct function (`CMD.client_msg`)
3. **Removed** unused protocol dispatcher code
4. **Added** comprehensive logging for debugging
5. **Verified** with test pages showing working gameplay

The black screen issue is now completely resolved. Players can login, see themselves (blue), see NPCs (red), and the game functions as intended.
