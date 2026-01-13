# NPC Visibility and AOI System Explanation

## Why Different Players See Different NPCs

The MMO demo uses an **Area of Interest (AOI)** system to optimize network traffic. Players only receive updates about entities (NPCs and other players) that are within their view range.

### Configuration

From `server/service/scene.lua`:
```lua
local VIEW_WIDTH = 400  -- Horizontal view distance
local VIEW_HEIGHT = 400 -- Vertical view distance
```

### NPC Positions

There are 3 NPCs with fixed positions:
1. **Guard** at (200, 200)
2. **Villager** at (400, 300)
3. **Merchant** at (600, 200)

### Player Spawn

Players spawn at random positions:
```lua
local x, y = math.random(100, 300), math.random(100, 300)
```

This means players spawn in the range:
- X: 100-300
- Y: 100-300

### Visibility Calculation

A player can see an NPC if the NPC is within 400 pixels (VIEW_WIDTH/HEIGHT) of the player's position.

**Example:**
- Player spawns at (150, 150)
- Can see entities in range: X: -250 to 550, Y: -250 to 550
- **Guard (200, 200)**: Distance ≈ 70 pixels → **VISIBLE** ✓
- **Villager (400, 300)**: Distance ≈ 320 pixels → **VISIBLE** ✓
- **Merchant (600, 200)**: Distance ≈ 450 pixels → **NOT VISIBLE** ✗

**Another Example:**
- Player spawns at (280, 250)
- Can see entities in range: X: -120 to 680, Y: -150 to 650
- **Guard (200, 200)**: Distance ≈ 90 pixels → **VISIBLE** ✓
- **Villager (400, 300)**: Distance ≈ 135 pixels → **VISIBLE** ✓
- **Merchant (600, 200)**: Distance ≈ 325 pixels → **VISIBLE** ✓

## This is Expected Behavior!

Different browsers (players) seeing different NPCs is **correct** and demonstrates that:
1. ✅ The AOI system is working properly
2. ✅ Players only receive data about nearby entities
3. ✅ Network traffic is optimized (no global broadcasts)

## How to See All NPCs

To see all 3 NPCs, a player needs to spawn close enough to all of them, or **move around**:
1. Use WASD or Arrow keys to move your character
2. As you move toward an NPC, it will appear (AOI Enter event)
3. As you move away, it will disappear (AOI Leave event)

## Testing AOI

1. **Single Player**: Move around the map to see NPCs appear and disappear
2. **Multiple Players**: 
   - Open multiple browser tabs
   - Each player will see different NPCs based on their spawn position
   - When two players are within 400 pixels of each other, they will see each other (as green squares)

## Technical Details

The AOI system uses spatial indexing to efficiently query nearby entities:
- Map is divided into 50x50 pixel tiles (40x40 grid for a 2000x2000 map)
- When an entity moves, only entities in nearby tiles are checked
- Events are generated when entities enter/leave each other's view range

This is the foundation of scalable MMO architecture - sending only relevant updates to each client.
