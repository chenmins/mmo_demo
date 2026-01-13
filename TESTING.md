# MMO Demo - Testing Guide

This guide provides detailed instructions for testing the MMO demo after the black screen fix.

## Quick Summary of Fixes

The black screen issue was caused by an incomplete login handler in `server/service/agent.lua`. The fixes include:

1. **Server-side**: Complete login handler implementation with proper scene initialization
2. **Client-side**: Enhanced error handling and debugging capabilities
3. **Code quality**: Error handling for pcall and DEBUG flag for production readiness

## Prerequisites

### For Windows Users (Recommended)
- Windows OS (server is compiled for Windows)
- Skynet framework installed and properly configured
- Python 3.x or Node.js for HTTP server

### For Linux/Mac Users
- You'll need to compile the Skynet server from source for your platform
- Or use Windows in a VM or WSL2 with Windows binaries

## Setup and Testing Steps

### Step 1: Start the Server

1. Open a terminal/command prompt
2. Navigate to the `server` directory:
   ```bash
   cd server
   ```

3. Verify the config file (`config`) has correct paths pointing to your Skynet installation

4. Run the server:
   ```bash
   skynet.exe config
   ```
   
   On Linux (if compiled):
   ```bash
   ./skynet config
   ```

5. **Expected output**:
   ```
   Server start...
   Gateway Listen on 8001
   Scene initialized. NPCs loaded.
   ```

### Step 2: Start the Client

1. Open a new terminal/command prompt
2. Navigate to the `client` directory:
   ```bash
   cd client
   ```

3. Start an HTTP server:
   
   **Using Python 3**:
   ```bash
   python -m http.server 8000
   ```
   
   **Using Node.js**:
   ```bash
   npx http-server . -p 8000
   ```

4. **Expected output**:
   ```
   Serving HTTP on 0.0.0.0 port 8000 ...
   ```

### Step 3: Test the Game

1. Open your web browser (Chrome or Firefox recommended)
2. Navigate to: `http://localhost:8000`
3. Open the browser's Developer Console (F12 or Ctrl+Shift+I)
4. Click on "Click to Login" button

### Expected Behavior

#### Visual Display
You should see:
- **Dark gray background** (#2d2d2d)
- **"Game Scene Loaded" text** in the top-left corner (if DEBUG=true)
- **A blue square (40x40 pixels)** - This is YOUR player
- **Red squares** - These are NPCs (if within view distance of 400 pixels)
- **Text labels** above each square showing "player:ID" or "npc:ID"

#### Console Output (with DEBUG=true)
```
Connected
GameScene created
Sending login request
Received message: {cmd: "self_info", data: {id: XXXX, type: "player", x: XXX, y: XXX}}
My ID: XXXX Data: {id: XXXX, type: "player", x: XXX, y: XXX}
Adding entity: {id: XXXX, type: "player", x: XXX, y: XXX}
Creating rectangle at: XXX XXX with color: 255
Entity added successfully: XXXX
Received message: {cmd: "aoi_add", entity: {id: X, type: "npc", ...}}
AOI Add: {id: X, type: "npc", x: 200, y: 200, name: "Guard"}
...
```

#### Gameplay
1. **Movement**: Press W/A/S/D or Arrow Keys
   - Your blue square should move smoothly
   - Position updates are sent to server every 50ms
   - Movement is client-predicted for responsiveness

2. **NPCs Visibility**:
   - Red NPCs appear when you're within 400 pixels
   - NPCs disappear when you move too far away
   - There are 3 NPCs at positions:
     - (200, 200) - Guard
     - (400, 300) - Villager
     - (600, 200) - Merchant

3. **Multi-player** (requires second client):
   - Open a second browser window/tab to `http://localhost:8000`
   - Click "Click to Login" in the second window
   - When the two players are within 400 pixels of each other:
     - Each player sees the other as a **green square**
   - When moving, both players see each other's movement in real-time

## Troubleshooting

### Black Screen Issues

If you still see a black screen after clicking "Click to Login":

1. **Check Console for Errors**:
   - Look for WebSocket connection errors
   - Look for JavaScript errors
   - Check if "GameScene created" message appears

2. **Check Server Logs**:
   - Ensure you see "Agent start. ID: XXXX"
   - Look for "Player login. ID: XXXX"
   - Check for "Login success, entering scene"
   - Verify "Scene initialized. NPCs loaded." appeared at startup

3. **Verify Network Connection**:
   - Open Network tab in browser DevTools
   - Check if WebSocket connection to `ws://localhost:8001` succeeds
   - If connection fails: server not running or port blocked

### Common Issues

#### "Connection Error!" message appears
- **Cause**: Cannot connect to WebSocket server at localhost:8001
- **Solution**: 
  - Verify server is running
  - Check if port 8001 is available (not used by another process)
  - Check firewall settings

#### No squares visible but console shows messages
- **Cause**: Entities might be spawning outside visible canvas area
- **Solution**: 
  - Canvas is 800x600 pixels
  - Players spawn at random positions (100-300, 100-300)
  - NPCs are at fixed positions (see above)
  - All should be visible initially

#### "Scene init error" in server logs
- **Cause**: Scene service failed to initialize
- **Solution**:
  - Check if AOI library (aoi.so/.dll) is available in luaclib directory
  - Verify yyjson library is available
  - Check server logs for specific error message

#### NPCs don't appear
- **Cause**: AOI (Area of Interest) system not working
- **Solution**:
  - Verify scene initialization succeeded
  - Check if player spawn position is within 400 pixels of NPC positions
  - Try moving around to enter NPC view range

#### Second player doesn't appear green
- **Cause**: Players too far apart or AOI issue
- **Solution**:
  - Move both players to center of map
  - Ensure both are within 400 pixels of each other
  - Check console for "AOI Add" messages

### Debug Mode

To disable verbose logging in production:

1. Open `client/src/game.js`
2. Change line 5:
   ```javascript
   const DEBUG = false;  // was: const DEBUG = true;
   ```
3. Refresh the browser

This will:
- Keep error messages (console.error still works)
- Hide debug logs for better performance
- Hide "Game Scene Loaded" debug text

## Performance Tips

1. **Client-side**:
   - Movement updates are throttled to every 50ms
   - Client prediction reduces perceived lag
   - Entity updates only occur for entities within view range

2. **Server-side**:
   - AOI system efficiently manages visibility
   - Only relevant updates are sent to clients
   - Scene uses tile-based spatial partitioning (50x50 tiles)

## System Architecture

```
Client (Browser)           Server (Skynet)
================          ==================
LoginScene                main.lua
    ↓ WebSocket               ↓
    ↓ connect             gateway.lua
    ↓                         ↓ creates
GameScene ←─ messages ─→  agent.lua
    ↓ login                   ↓ calls
    ↓ move                scene.lua (AOI)
    ↓                         ↓ manages
entities                  entities + NPCs
```

### Message Flow

1. **Login**:
   ```
   Client → {cmd: "login", userid: XXXX}
   Server → {cmd: "self_info", data: {id, type, x, y}}
   Server → {cmd: "aoi_add", entity: {npc data}} (for each visible NPC)
   ```

2. **Movement**:
   ```
   Client → {cmd: "move", x: XXX, y: XXX}
   Server → {cmd: "entity_move", id: XXXX, x: XXX, y: XXX} (broadcast to nearby)
   Server → {cmd: "aoi_add", entity: {...}} (when entity enters range)
   Server → {cmd: "aoi_remove", id: XXXX} (when entity leaves range)
   ```

## Next Steps

If everything works:
1. Try adding more NPCs in `server/service/scene.lua`
2. Experiment with different spawn positions
3. Adjust view range (VIEW_WIDTH, VIEW_HEIGHT)
4. Add more players to test scaling
5. Implement chat or other features

For more details on the fixes, see [FIXES.md](FIXES.md).

## Security Notes

- All code has been checked with CodeQL - no vulnerabilities found
- Input validation should be added before production use
- Consider rate limiting for move commands
- Add authentication for production deployment
