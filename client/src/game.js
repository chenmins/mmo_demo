// 全局 Socket 引用
let globalSocket;

// Debug flag - set to false in production to reduce logging
const DEBUG = true;

class LoginScene extends Phaser.Scene {
    constructor() { super({ key: 'LoginScene' }); }

    create() {
        this.add.text(300, 250, 'Click to Login', { fontSize: '32px', fill: '#fff' })
            .setInteractive()
            .on('pointerdown', () => this.connectServer());
    }

    connectServer() {
        this.add.text(300, 300, 'Connecting...', { fontSize: '24px', fill: '#fff' });
        // 确保端口号和你 skynet config 里的 gate 端口一致
        globalSocket = new WebSocket('ws://localhost:8001');

        globalSocket.onopen = () => {
            if (DEBUG) console.log('Connected');
            this.scene.start('GameScene');
        };

        globalSocket.onerror = (error) => {
            console.error('WebSocket Error:', error);
            this.add.text(300, 350, 'Connection Error!', { fontSize: '20px', fill: '#f00' });
        };

        globalSocket.onclose = (event) => {
            if (DEBUG) console.log('WebSocket closed:', event);
            this.add.text(300, 350, 'Connection Closed!', { fontSize: '20px', fill: '#f00' });
        };
    }
}

class GameScene extends Phaser.Scene {
    constructor() { super({ key: 'GameScene' }); }

    create() {
        if (DEBUG) console.log('GameScene created');
        this.entities = {}; // 存储 id -> {rect, text}
        this.myId = 0;
        this.lastSendTime = 0; // 用于限制发包频率

        // Add debug text to show the scene is running
        if (DEBUG) {
            this.add.text(10, 10, 'Game Scene Loaded', { fontSize: '16px', fill: '#fff' });
        }

        // 1. 初始化键盘输入 (WASD 和 方向键)
        this.cursors = this.input.keyboard.createCursorKeys();
        this.keys = this.input.keyboard.addKeys('W,A,S,D');

        // 监听消息
        globalSocket.onmessage = (event) => {
            if (DEBUG) console.log('Received message:', event.data);
            const msg = JSON.parse(event.data);
            this.handleMessage(msg);
        };

        // 发送进入地图指令
        // 注意：根据之前的 agent 逻辑，登录后可能需要先发 login 协议，
        // 如果你 agent 里处理了 enter_map，请保持。
        // 这里假设发送 login 包含 userid 就能进入
        // 如果你的 agent 需要特定指令，请在此处修改
        if (DEBUG) console.log('Sending login request');
        this.send({ cmd: "login", userid: Math.floor(Math.random() * 10000) }); 
    }

    // 2. 游戏主循环：每一帧都会运行
    update(time, delta) {
        if (!this.myId || !this.entities[this.myId]) return;

        const speed = 200 * (delta / 1000); // 速度：像素/秒
        let dx = 0;
        let dy = 0;

        // 检测按键
        if (this.cursors.left.isDown || this.keys.A.isDown) dx = -speed;
        else if (this.cursors.right.isDown || this.keys.D.isDown) dx = speed;

        if (this.cursors.up.isDown || this.keys.W.isDown) dy = -speed;
        else if (this.cursors.down.isDown || this.keys.S.isDown) dy = speed;

        // 如果有移动
        if (dx !== 0 || dy !== 0) {
            const myEntity = this.entities[this.myId];
            
            // --- 客户端先行预测 (Client Prediction) ---
            // 立即移动自己的方块，不用等服务器回复，这样感觉流畅
            myEntity.rect.x += dx;
            myEntity.rect.y += dy;
            // 更新文字位置
            myEntity.text.setPosition(myEntity.rect.x - 20, myEntity.rect.y - 40);

            // --- 发送请求给服务器 ---
            // 限制发送频率，避免每帧都发 (例如每 50ms 发一次)
            const now = Date.now();
            if (now - this.lastSendTime > 50) {
                this.send({ 
                    cmd: "move", 
                    x: Math.floor(myEntity.rect.x), 
                    y: Math.floor(myEntity.rect.y) 
                });
                this.lastSendTime = now;
            }
        }
    }

    send(data) {
        if (globalSocket.readyState === WebSocket.OPEN) {
            globalSocket.send(JSON.stringify(data));
        }
    }

    handleMessage(msg) {
        if (DEBUG) console.log("Recv:", msg);
        switch (msg.cmd) {
            case "self_info":
                this.myId = msg.data.id;
                if (DEBUG) console.log("My ID:", this.myId, "Data:", msg.data);
                // 收到自己信息时，确保先添加自己
                this.addEntity(msg.data); 
                break;

            case "aoi_add":
                if (DEBUG) console.log("AOI Add:", msg.entity);
                this.addEntity(msg.entity);
                break;

            case "aoi_remove":
                if (DEBUG) console.log("AOI Remove:", msg.id);
                this.removeEntity(msg.id);
                break;

            // 3. 处理移动同步消息
            case "entity_move":
                this.updateEntityPosition(msg.id, msg.x, msg.y);
                break;

            default:
                if (DEBUG) console.log("Unknown message command:", msg.cmd);
        }
    }

    addEntity(data) {
        if (DEBUG) console.log("Adding entity:", data);
        if (this.entities[data.id]) {
            if (DEBUG) console.log("Entity already exists:", data.id);
            return;
        }

        let color = 0xffffff;
        if (data.type === 'npc') color = 0xff0000; // NPC 红色
        if (data.type === 'player') {
            color = (data.id === this.myId) ? 0x0000ff : 0x00ff00; // 自己蓝色，别人绿色
        }

        if (DEBUG) console.log("Creating rectangle at:", data.x, data.y, "with color:", color);
        const rect = this.add.rectangle(data.x, data.y, 40, 40, color);
        const text = this.add.text(data.x - 20, data.y - 40, data.type + ":" + data.id, { fontSize: '12px' });
        
        this.entities[data.id] = { rect, text };
        if (DEBUG) console.log("Entity added successfully:", data.id);
    }

    removeEntity(id) {
        if (this.entities[id]) {
            this.entities[id].rect.destroy();
            this.entities[id].text.destroy();
            delete this.entities[id];
        }
    }

    // 更新位置函数
    updateEntityPosition(id, x, y) {
        const ent = this.entities[id];
        if (ent) {
            // 如果是自己，我们已经在 update 里做过客户端预测了，
            // 这里可以选择忽略服务器回包，或者用来做位置校正（防止作弊或误差）。
            // 为了演示流畅性，如果偏差不大，我们这里忽略自己的服务器回包。
            if (id === this.myId) {
                // 简单的防抖动：只有服务器位置和本地位置差太远才强制拉回
                if (Phaser.Math.Distance.Between(ent.rect.x, ent.rect.y, x, y) > 50) {
                     ent.rect.x = x;
                     ent.rect.y = y;
                     ent.text.setPosition(x - 20, y - 40);
                }
                return; 
            }

            // 别人的位置直接更新
            ent.rect.x = x;
            ent.rect.y = y;
            ent.text.setPosition(x - 20, y - 40);
        }
    }
}

const config = {
    type: Phaser.AUTO,
    width: 800,
    height: 600,
    backgroundColor: '#2d2d2d',
    scene: [LoginScene, GameScene]
};

const game = new Phaser.Game(config);
