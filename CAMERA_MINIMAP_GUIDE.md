# MMO Camera and Minimap System

## Overview

This implementation adds a professional camera system and minimap to the MMO demo, similar to MOBA games like League of Legends or Dota 2.

## Features Implemented

### 1. Camera System
- **Camera follows player**: The viewport automatically centers on the player character
- **Map boundaries**: Camera respects the 2000x2000 map boundaries
- **Smooth following**: Camera updates every frame to stay centered on the player
- **Viewport limitation**: Players only see 800x600 pixels of the map at a time

### 2. Minimap
- **Full map view**: Shows the entire 2000x2000 map in a 200x200 pixel minimap
- **Position**: Located in the top-right corner with a white border
- **Entity indicators**:
  - Blue square: Your player (larger, 6x6 pixels)
  - Red squares: NPCs (4x4 pixels)
  - Green squares: Other players (4x4 pixels)
- **Viewport indicator**: Yellow rectangle shows where your camera is looking on the map
- **Grid overlay**: Subtle grid for spatial reference

### 3. Collision Detection
- **Entity-to-entity collision**: Players cannot move through NPCs or other players
- **Collision distance**: 40 pixels (matching entity size)
- **Server-side validation**: All movement is validated on the server
- **Position correction**: Server sends corrected position if collision is detected
- **Map boundaries**: Players cannot move outside the map bounds (20 pixels from edge)

## Technical Implementation

### Client-Side Changes (game.js)

#### Map Constants
```javascript
const MAP_WIDTH = 2000;
const MAP_HEIGHT = 2000;
```

#### Camera Setup
```javascript
// Setup camera with map bounds
this.cameras.main.setBounds(0, 0, MAP_WIDTH, MAP_HEIGHT);

// Center camera on player position
this.cameras.main.centerOn(data.x, data.y);
```

#### Minimap Setup
```javascript
// Create secondary camera for minimap
this.minimapCamera = this.cameras.add(minimapX, minimapY, minimapWidth, minimapHeight);
this.minimapCamera.setZoom(minimapWidth / MAP_WIDTH); // Scale to show full map
this.minimapCamera.setBounds(0, 0, MAP_WIDTH, MAP_HEIGHT);
```

#### Movement with Boundary Checking
```javascript
// Keep player within map bounds
newX = Math.max(20, Math.min(MAP_WIDTH - 20, newX));
newY = Math.max(20, Math.min(MAP_HEIGHT - 20, newY));

// Update camera to follow player
this.cameras.main.centerOn(newX, newY);
```

### Server-Side Changes (scene.lua)

#### Collision Detection
```lua
-- Collision detection constants
local ENTITY_SIZE = 40
local COLLISION_DISTANCE = ENTITY_SIZE

-- Check if a position collides with any entity
local function check_collision(moving_id, new_x, new_y)
    for id, ent in pairs(entities) do
        if id ~= moving_id then
            local dx = new_x - ent.x
            local dy = new_y - ent.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < COLLISION_DISTANCE then
                return true, id  -- Collision detected
            end
        end
    end
    return false  -- No collision
end
```

#### Move Validation
```lua
function CMD.move(player_id, x, y)
    -- Check map boundaries
    if x < 20 or x > MAP_WIDTH - 20 or y < 20 or y > MAP_HEIGHT - 20 then
        -- Send correction to client
        return
    end

    -- Check collision with other entities
    local has_collision, collided_with = check_collision(player_id, x, y)
    if has_collision then
        -- Send position correction back to client
        return
    end
    
    -- Allow movement...
end
```

## Files Modified

### Client-Side
- `client/src/game.js`: Added camera system and minimap rendering

### Server-Side
- `server/service/scene.lua`: Added collision detection and boundary checking

### New Test Files
- `client/test_collision.html`: Interactive collision testing tool
- `client/demo_canvas.html`: Canvas-based demo (works without external dependencies)

## Testing

### Visual Testing
1. Start server: `cd server && ./skynet config`
2. Start client: `cd client && python3 -m http.server 8000`
3. Open browser: `http://localhost:8000/demo_canvas.html`
4. Click "Connect and Login"
5. Use WASD or Arrow keys to move

### Collision Testing
1. Open: `http://localhost:8000/test_collision.html`
2. Click "Connect and Login"
3. Click "Test Collision (move very close to Guard)"
4. Observe: Server rejects the move and returns original position

### Expected Behavior
- ✅ Camera centers on player at spawn
- ✅ Camera follows player movement smoothly
- ✅ Minimap shows full map with viewport indicator
- ✅ Entities appear/disappear based on AOI
- ✅ Collision with NPCs is blocked
- ✅ Collision with other players is blocked
- ✅ Map boundaries prevent out-of-bounds movement

## Screenshots

### Camera and Minimap System
![Camera and Minimap](https://github.com/user-attachments/assets/b8d58bce-c496-4fe2-bd14-21437acd596d)

*Shows the camera system with the player (blue) in the center, Guard NPC (red) visible, and minimap in top-right showing full map view with yellow viewport indicator*

### Player Movement
![Player Movement](https://github.com/user-attachments/assets/09fb764b-1770-4a0c-982c-07ee3782e76b)

*After moving, camera follows the player. Notice the position changed from (174, 272) to (177, 229)*

### Collision Detection Test
![Collision Detection](https://github.com/user-attachments/assets/cd98ee58-110c-4e64-9b0e-3a8db87d2484)

*Testing collision: Attempting to move to Guard's position (200, 200) is rejected by the server. The red "COLLISION DETECTED!" message confirms the system is working*

## MOBA-Like Experience

The implementation provides a MOBA-like experience:

1. **Fog of War Effect**: Players only see entities within their AOI range
2. **Minimap Navigation**: Full map visibility on minimap like League of Legends
3. **Unit Collision**: Players and NPCs cannot overlap, encouraging strategic positioning
4. **Camera Follow**: Smooth camera tracking keeps the player centered
5. **Map Awareness**: Yellow viewport rectangle on minimap shows your current view

## Performance Considerations

- **Client-side prediction**: Movement feels responsive with immediate visual feedback
- **Throttled updates**: Movement packets sent maximum every 50ms to reduce network traffic
- **AOI system**: Only entities within view distance are synchronized
- **Efficient rendering**: Both main view and minimap render in single frame loop

## Future Enhancements

Potential improvements for the future:

1. **Smart camera**: Predict player movement direction
2. **Minimap clicks**: Click minimap to see that area (spectator mode)
3. **Fog of War**: Add unexplored area rendering
4. **Minimap pings**: Communication system
5. **Collision prediction**: Prevent client from attempting invalid moves
6. **Path smoothing**: Smooth movement around obstacles
7. **Camera shake**: Impact effects for better game feel

## Configuration

All magic numbers are now configurable:

### Client (game.js)
```javascript
const MAP_WIDTH = 2000;          // Map width in pixels
const MAP_HEIGHT = 2000;         // Map height in pixels
const VIEWPORT_WIDTH = 800;      // Camera viewport width
const VIEWPORT_HEIGHT = 600;     // Camera viewport height
const MINIMAP_SIZE = 200;        // Minimap dimension
```

### Server (scene.lua)
```lua
local MAP_WIDTH = 2000           -- Map width
local MAP_HEIGHT = 2000          -- Map height
local ENTITY_SIZE = 40           -- Entity hitbox size
local COLLISION_DISTANCE = 40    -- Minimum distance between entities
local VIEW_WIDTH = 400           -- AOI view width
local VIEW_HEIGHT = 400          -- AOI view height
```

## Compatibility

- Works with existing AOI (Area of Interest) system
- Compatible with multi-player gameplay
- Backward compatible with existing movement system
- No breaking changes to existing protocols
