// ===========================================
// 全局变量 (Global Variables)
// ===========================================

// WebSocket 连接引用 (WebSocket connection reference)
let globalSocket;

// 调试标志 - 生产环境设为 false (Debug flag - set to false in production)
const DEBUG = true;

// ===========================================
// 登录场景类 (Login Scene Class)
// ===========================================

class LoginScene extends Phaser.Scene {
    constructor() { 
        super({ key: 'LoginScene' }); 
    }

    create() {
        // 创建登录按钮文字 (Create login button text)
        this.add.text(300, 250, 'Click to Login', { fontSize: '32px', fill: '#fff' })
            .setInteractive()
            .on('pointerdown', () => this.connectServer());
    }

    // 连接服务器 (Connect to server)
    connectServer() {
        this.add.text(300, 300, 'Connecting...', { fontSize: '24px', fill: '#fff' });
        
        // 确保端口号和 skynet config 里的 gate 端口一致 
        // Make sure port matches gate port in skynet config
        globalSocket = new WebSocket('ws://localhost:8001');

        // WebSocket 连接成功 (WebSocket connection opened)
        globalSocket.onopen = () => {
            if (DEBUG) console.log('Connected');
            this.scene.start('GameScene');
        };

        // WebSocket 连接错误 (WebSocket connection error)
        globalSocket.onerror = (error) => {
            console.error('WebSocket Error:', error);
            this.add.text(300, 350, 'Connection Error!', { fontSize: '20px', fill: '#f00' });
        };

        // WebSocket 连接关闭 (WebSocket connection closed)
        globalSocket.onclose = (event) => {
            if (DEBUG) console.log('WebSocket closed:', event);
            this.add.text(300, 350, 'Connection Closed!', { fontSize: '20px', fill: '#f00' });
        };
    }
}

// ===========================================
// 游戏场景类 (Game Scene Class)
// ===========================================

class GameScene extends Phaser.Scene {
    constructor() { 
        super({ key: 'GameScene' }); 
    }

    create() {
        if (DEBUG) console.log('GameScene created');
        
        // 实体存储：id -> {rect, text} (Entity storage: id -> {rect, text})
        this.entities = {}; 
        
        // 我的玩家 ID (My player ID)
        this.myId = 0;
        
        // 上次发送移动消息的时间，用于限制发包频率 
        // Last send time for movement, to throttle packet sending
        this.lastSendTime = 0;

        // ===========================================
        // 设置摄像机系统 (Setup Camera System)
        // ===========================================
        
        // 设置摄像机边界为整个地图 (Set camera bounds to full map)
        this.cameras.main.setBounds(0, 0, MAP_WIDTH, MAP_HEIGHT);
        
        // 绘制地图边框用于视觉参考 (Draw map border for visual reference)
        const mapBorder = this.add.graphics();
        mapBorder.lineStyle(4, 0x444444, 1);
        mapBorder.strokeRect(0, 0, MAP_WIDTH, MAP_HEIGHT);
        
        // 添加网格以便更好地判断空间位置 (Add grid for better spatial reference)
        mapBorder.lineStyle(1, 0x333333, 0.3);
        for (let x = 0; x < MAP_WIDTH; x += 100) {
            mapBorder.lineBetween(x, 0, x, MAP_HEIGHT);
        }
        for (let y = 0; y < MAP_HEIGHT; y += 100) {
            mapBorder.lineBetween(0, y, MAP_WIDTH, y);
        }

        // ===========================================
        // 设置小地图 (Setup Minimap)
        // ===========================================
        
        this.setupMinimap();

        // 添加调试文字显示场景已加载（固定在屏幕上）
        // Add debug text to show scene loaded (fixed on screen)
        if (DEBUG) {
            this.add.text(10, 10, 'Game Scene Loaded', { fontSize: '16px', fill: '#fff' })
                .setScrollFactor(0); // 固定在屏幕上，不随摄像机移动 (Fixed on screen)
        }

        // ===========================================
        // 初始化键盘输入 (Initialize Keyboard Input)
        // ===========================================
        
        // 方向键 (Arrow keys)
        this.cursors = this.input.keyboard.createCursorKeys();
        
        // WASD 键 (WASD keys)
        this.keys = this.input.keyboard.addKeys('W,A,S,D');

        // ===========================================
        // 设置网络消息监听 (Setup Network Message Listener)
        // ===========================================
        
        globalSocket.onmessage = (event) => {
            if (DEBUG) console.log('Received message:', event.data);
            const msg = JSON.parse(event.data);
            this.handleMessage(msg);
        };

        // ===========================================
        // 发送登录请求 (Send Login Request)
        // ===========================================
        
        if (DEBUG) console.log('Sending login request');
        // 发送登录指令，随机生成用户 ID (Send login command with random user ID)
        this.send({ cmd: "login", userid: Math.floor(Math.random() * 10000) }); 
    }

    // ===========================================
    // 设置小地图 (Setup Minimap Function)
    // ===========================================
    
    setupMinimap() {
        // 小地图配置 (Minimap configuration)
        const minimapWidth = 200;
        const minimapHeight = 200;
        const minimapX = this.cameras.main.width - minimapWidth - 10;  // 右上角 (Top-right)
        const minimapY = 10;
        
        // 创建小地图摄像机 (Create minimap camera)
        this.minimapCamera = this.cameras.add(minimapX, minimapY, minimapWidth, minimapHeight);
        
        // 设置缩放以显示整个地图 (Set zoom to show full map)
        this.minimapCamera.setZoom(minimapWidth / MAP_WIDTH);
        
        // 设置小地图边界 (Set minimap bounds)
        this.minimapCamera.setBounds(0, 0, MAP_WIDTH, MAP_HEIGHT);
        
        // 设置小地图背景色 (Set minimap background color)
        this.minimapCamera.setBackgroundColor(0x000000);
        
        // 创建小地图边框（固定在屏幕上）(Create minimap border - fixed on screen)
        const border = this.add.graphics();
        border.lineStyle(3, 0xffffff, 1);
        border.strokeRect(minimapX - 2, minimapY - 2, minimapWidth + 4, minimapHeight + 4);
        border.setScrollFactor(0);  // 不随摄像机移动 (Don't move with camera)
        border.setDepth(1000);      // 确保在最上层 (Ensure on top layer)
        
        // 存储小地图信息供后续使用 (Store minimap info for later use)
        this.minimapInfo = {
            camera: this.minimapCamera,
            x: minimapX,
            y: minimapY,
            width: minimapWidth,
            height: minimapHeight
        };
    }

    // ===========================================
    // 游戏主循环 (Game Main Loop)
    // ===========================================
    // 每一帧都会运行 (Runs every frame)
    
    update(time, delta) {
        // 如果玩家还未初始化，直接返回 (Return if player not initialized)
        if (!this.myId || !this.entities[this.myId]) return;

        // 计算移动速度：200 像素/秒 (Calculate movement speed: 200 pixels/second)
        const speed = 200 * (delta / 1000);
        let dx = 0;  // X 轴移动量 (X-axis movement)
        let dy = 0;  // Y 轴移动量 (Y-axis movement)

        // ===========================================
        // 检测按键输入 (Detect Key Input)
        // ===========================================
        
        // 左右移动：A/D 或 左右方向键 (Left/Right: A/D or Arrow keys)
        if (this.cursors.left.isDown || this.keys.A.isDown) dx = -speed;
        else if (this.cursors.right.isDown || this.keys.D.isDown) dx = speed;

        // 上下移动：W/S 或 上下方向键 (Up/Down: W/S or Arrow keys)
        if (this.cursors.up.isDown || this.keys.W.isDown) dy = -speed;
        else if (this.cursors.down.isDown || this.keys.S.isDown) dy = speed;

        // ===========================================
        // 处理玩家移动 (Handle Player Movement)
        // ===========================================
        
        // 如果有移动输入 (If there is movement input)
        if (dx !== 0 || dy !== 0) {
            const myEntity = this.entities[this.myId];
            
            // 计算新位置 (Calculate new position)
            let newX = myEntity.rect.x + dx;
            let newY = myEntity.rect.y + dy;
            
            // 保持玩家在地图边界内 (Keep player within map bounds)
            newX = Math.max(20, Math.min(MAP_WIDTH - 20, newX));
            newY = Math.max(20, Math.min(MAP_HEIGHT - 20, newY));
            
            // --- 客户端先行预测 (Client-Side Prediction) ---
            // 立即移动自己的方块，不用等服务器回复，这样玩家感觉流畅
            // Move player immediately without waiting for server, feels smooth
            myEntity.rect.x = newX;
            myEntity.rect.y = newY;
            
            // 更新文字标签位置 (Update text label position)
            myEntity.text.setPosition(newX - 20, newY - 40);

            // 更新摄像机跟随玩家 (Update camera to follow player)
            this.cameras.main.centerOn(newX, newY);

            // --- 发送位置更新给服务器 (Send Position Update to Server) ---
            // 限制发送频率，避免每帧都发送（例如每 50ms 发一次）
            // Throttle sending to avoid sending every frame (e.g., once per 50ms)
            const now = Date.now();
            if (now - this.lastSendTime > 50) {
                this.send({ 
                    cmd: "move", 
                    x: Math.floor(newX), 
                    y: Math.floor(newY) 
                });
                this.lastSendTime = now;
            }
        }
    }

    // ===========================================
    // 发送消息给服务器 (Send Message to Server)
    // ===========================================
    
    send(data) {
        if (globalSocket.readyState === WebSocket.OPEN) {
            globalSocket.send(JSON.stringify(data));
        }
    }

    // ===========================================
    // 处理服务器消息 (Handle Server Messages)
    // ===========================================
    
    handleMessage(msg) {
        if (DEBUG) console.log("Recv:", msg);
        
        switch (msg.cmd) {
            // 收到自己的信息 (Received self info)
            case "self_info":
                this.myId = msg.data.id;
                if (DEBUG) console.log("My ID:", this.myId, "Data:", msg.data);
                // 收到自己信息时，添加自己到场景 (Add self to scene)
                this.addEntity(msg.data); 
                break;

            // 有实体进入视野 (Entity entered view)
            case "aoi_add":
                if (DEBUG) console.log("AOI Add:", msg.entity);
                this.addEntity(msg.entity);
                break;

            // 有实体离开视野 (Entity left view)
            case "aoi_remove":
                if (DEBUG) console.log("AOI Remove:", msg.id);
                this.removeEntity(msg.id);
                break;

            // 实体位置更新 (Entity position update)
            case "entity_move":
                this.updateEntityPosition(msg.id, msg.x, msg.y);
                break;

            // 未知命令 (Unknown command)
            default:
                if (DEBUG) console.log("Unknown message command:", msg.cmd);
        }
    }

    // ===========================================
    // 添加实体到场景 (Add Entity to Scene)
    // ===========================================
    
    addEntity(data) {
        if (DEBUG) console.log("Adding entity:", data);
        
        // 如果实体已存在，不重复添加 (Don't add if entity already exists)
        if (this.entities[data.id]) {
            if (DEBUG) console.log("Entity already exists:", data.id);
            return;
        }

        // 根据实体类型设置颜色 (Set color based on entity type)
        let color = 0xffffff;  // 默认白色 (Default white)
        
        if (data.type === 'npc') {
            color = 0xff0000; // NPC 红色 (NPC red)
        }
        if (data.type === 'player') {
            color = (data.id === this.myId) ? 0x0000ff : 0x00ff00; 
            // 自己：蓝色 (Self: blue)
            // 其他玩家：绿色 (Other players: green)
        }

        if (DEBUG) console.log("Creating rectangle at:", data.x, data.y, "with color:", color);
        
        // 创建实体方块（40x40 像素）(Create entity rectangle - 40x40 pixels)
        const rect = this.add.rectangle(data.x, data.y, 40, 40, color);
        
        // 创建实体标签文字 (Create entity label text)
        const text = this.add.text(data.x - 20, data.y - 40, data.type + ":" + data.id, { fontSize: '12px' });
        
        // 存储实体引用 (Store entity reference)
        this.entities[data.id] = { rect, text };
        
        // 如果是玩家自己，将摄像机居中对准 (If this is the player, center camera on them)
        if (data.id === this.myId) {
            this.cameras.main.centerOn(data.x, data.y);
            if (DEBUG) console.log("Camera centered on player at:", data.x, data.y);
        }
        
        if (DEBUG) console.log("Entity added successfully:", data.id);
    }

    // ===========================================
    // 移除实体 (Remove Entity)
    // ===========================================
    
    removeEntity(id) {
        if (this.entities[id]) {
            // 销毁图形对象 (Destroy graphics objects)
            this.entities[id].rect.destroy();
            this.entities[id].text.destroy();
            
            // 从实体列表中删除 (Remove from entity list)
            delete this.entities[id];
        }
    }

    // ===========================================
    // 更新实体位置 (Update Entity Position)
    // ===========================================
    
    updateEntityPosition(id, x, y) {
        const ent = this.entities[id];
        if (ent) {
            // 如果是玩家自己 (If this is the player)
            if (id === this.myId) {
                // 我们已经在 update 里做过客户端预测了
                // We already did client-side prediction in update()
                
                // 简单的防抖动：只有服务器位置和本地位置差太远才强制拉回
                // Simple anti-jitter: only force correction if server position differs significantly
                if (Phaser.Math.Distance.Between(ent.rect.x, ent.rect.y, x, y) > 50) {
                     ent.rect.x = x;
                     ent.rect.y = y;
                     ent.text.setPosition(x - 20, y - 40);
                }
                return; 
            }

            // 其他玩家的位置直接更新 (Directly update other players' positions)
            ent.rect.x = x;
            ent.rect.y = y;
            ent.text.setPosition(x - 20, y - 40);
        }
    }
}

// ===========================================
// 地图常量 (Map Constants)
// ===========================================
// 必须与服务器配置匹配 (Must match server configuration)
// 注意：生产环境可考虑从服务器获取或使用共享配置
// Note: For production, consider fetching from server or using shared config

const MAP_WIDTH = 2000;   // 地图宽度（像素）(Map width in pixels)
const MAP_HEIGHT = 2000;  // 地图高度（像素）(Map height in pixels)

// ===========================================
// Phaser 游戏配置 (Phaser Game Configuration)
// ===========================================

const config = {
    type: Phaser.AUTO,           // 自动选择 WebGL 或 Canvas (Auto-select WebGL or Canvas)
    width: 800,                  // 游戏窗口宽度（像素）(Game window width in pixels)
    height: 600,                 // 游戏窗口高度（像素）(Game window height in pixels)
    backgroundColor: '#2d2d2d',  // 背景颜色 (Background color)
    scene: [LoginScene, GameScene]  // 场景列表：登录场景 -> 游戏场景 (Scene list: Login -> Game)
};

// ===========================================
// 创建并启动 Phaser 游戏 (Create and Start Phaser Game)
// ===========================================

const game = new Phaser.Game(config);
