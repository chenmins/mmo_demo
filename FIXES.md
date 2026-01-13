# Bug Fixes for Black Screen Issue

## Problem
After clicking "Click to Login" in the browser, the screen goes black with no visible blocks (players or NPCs).

## Root Cause Analysis
The `server/service/agent.lua` file had an incomplete login handler that caused the following issues:

1. **Missing player_id initialization**: The `player_id` variable was used in the login handler (line 50) but was never defined or extracted from the login request.

2. **Missing scene initialization**: The scene service was not being initialized when a player logged in via the "login" command.

3. **Incomplete login logic**: There was only a comment saying "登录逻辑保持不变" (login logic remains unchanged) but no actual implementation.

4. **player_id not available for move handler**: The move handler (line 59) referenced `player_id`, but this variable was only defined locally in the old `CMD.start` function and not accessible to the protocol dispatcher.

## Changes Made

### 1. Fixed `server/service/agent.lua`

#### Added player_id as a module-level variable:
```lua
local client_fd
local gateway
local scene 
local my_id
local player_id  -- Added this line
```

#### Implemented complete login handler with error handling:
```lua
if req.cmd == "login" then
    -- Extract player_id from request
    player_id = req.userid or math.random(10000, 99999)
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
```

#### Added proper disconnect handling:
```lua
function CMD.disconnect()
    if scene and player_id then
        skynet.call(scene, "lua", "leave", player_id)
    end
    skynet.exit()
end
```

### 2. Enhanced `client/src/game.js` for debugging

Added comprehensive logging and error handling with a DEBUG flag for production control:

#### Debug flag control:
```javascript
// Debug flag - set to false in production to reduce logging
const DEBUG = true;
```

All debug logging is now wrapped with `if (DEBUG)` checks to allow easy toggling for production use.

#### WebSocket error handling:
```javascript
globalSocket.onerror = (error) => {
    console.error('WebSocket Error:', error);
    this.add.text(300, 350, 'Connection Error!', { fontSize: '20px', fill: '#f00' });
};

globalSocket.onclose = (event) => {
    console.log('WebSocket closed:', event);
    this.add.text(300, 350, 'Connection Closed!', { fontSize: '20px', fill: '#f00' });
};
```

#### Enhanced message logging:
- Added logging for all received messages
- Added logging for entity creation
- Added logging for scene initialization
- Added debug text showing "Game Scene Loaded"
- Added default case to catch unknown message commands

#### Fixed player colors:
Changed from incorrect colors to match problem description:
- Self: Blue (0x0000ff)
- Other players: Green (0x00ff00)
- NPCs: Red (0xff0000)

## Testing Instructions

### Prerequisites
1. Windows environment (since the server is compiled for Windows)
2. Skynet framework properly installed and configured
3. Python or Node.js for running a simple HTTP server

### Start the Server
1. Open terminal and navigate to the `server` directory
2. Run the skynet executable:
   ```
   skynet.exe config
   ```
3. You should see: `Gateway Listen on 8001`

### Start the Client
1. Open terminal and navigate to the `client` directory
2. Start an HTTP server:
   ```bash
   # Using Python
   python -m http.server 8000
   
   # Or using Node.js
   npx http-server .
   ```
3. Open browser to `http://localhost:8000`
4. Open browser console (F12) to view debug logs
5. Click "Click to Login"

### Expected Behavior
1. Console should show:
   - "Connected" (when WebSocket opens)
   - "GameScene created"
   - "Sending login request"
   - "Received message: {cmd: 'self_info', ...}"
   - "My ID: [number]"
   - "Adding entity: {id: [number], type: 'player', ...}"
   - "Creating rectangle at: [x] [y] with color: [color]"
   - Multiple "AOI Add" messages for NPCs

2. Visual display should show:
   - "Game Scene Loaded" text in top-left corner
   - A blue square (your player) at a random position
   - Red squares (NPCs) if they are within view distance
   - Entity labels showing type:id

3. Gameplay:
   - Press WASD or arrow keys to move
   - Your blue square should move smoothly
   - NPCs should appear/disappear based on distance
   - When another player connects and comes close, you should see a green square

### Troubleshooting

If you still see a black screen:

1. **Check browser console** - Look for error messages
   - WebSocket connection errors mean server isn't running
   - JavaScript errors mean there's a code issue
   
2. **Check server logs** - Look for:
   - "Agent start. ID: [number]"
   - "Player login. ID: [number]"
   - "Login success, entering scene"
   - "Scene initialized. NPCs loaded."

3. **Common issues**:
   - **Port conflict**: Make sure port 8001 is not in use
   - **Firewall**: Ensure WebSocket connections are allowed
   - **CORS**: Make sure the HTTP server is running from the client directory
   - **Scene not initialized**: Check if the scene service has any errors in server logs

## What Was Fixed

The main issue was that when the client sent a `{"cmd": "login", "userid": [number]}` message, the server's agent.lua was not properly handling it. The incomplete handler was trying to use variables that didn't exist and wasn't initializing the scene or entering the player into it.

With these fixes:
1. The server now properly extracts the player ID from the login request
2. The scene is initialized if not already initialized
3. The player is entered into the scene with their ID
4. The player receives a `self_info` message with their position
5. The player receives `aoi_add` messages for nearby NPCs and other players
6. The client renders all entities as colored rectangles

The enhanced logging helps identify exactly where the process might be failing if issues persist.
