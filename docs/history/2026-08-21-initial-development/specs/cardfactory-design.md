# CardFactory - 卡牌化工厂模拟游戏 设计文档

> **历史归档（2026-08-21 初始开发）：** 本设计保留当时设想，不证明当前完成状态；请以[项目状态](../../../PROJECT_STATUS.md)和[当前设计](../../../current/SINGLE_PLAYER_GAP_ANALYSIS.md)为准。

**文档版本**: 1.0.0  
**创建日期**: 2026-08-21  
**状态**: 设计完成，待审查

---

## 1. 项目概述

### 1.1 项目愿景
CardFactory是一款创新的工厂模拟游戏，将复杂的工厂生产线以**卡牌化/流程图**的形式呈现，摒弃传统的3D/2D美术渲染，用最简洁的信息流风格实现高信息密度的生产链可视化。

### 1.2 核心理念
- **卡牌化建筑**：每个建筑是一张卡牌，显示名称、输入、输出、状态
- **流程图连线**：卡牌之间用连线表示物流关系
- **数据驱动**：生产线通过JSON配置文件定义，易于扩展
- **渐进式开发**：三阶段开发，从最小可行产品到完整游戏

### 1.3 目标用户
- 喜欢工厂模拟游戏的玩家（如异星工厂、DSPONLINE）
- 喜欢策略/管理类游戏的玩家
- 喜欢简洁UI/高信息密度游戏的玩家

---

## 2. 技术架构

### 2.1 技术栈
- **游戏引擎**: Godot 4.7.2
- **脚本语言**: GDScript
- **渲染方案**: Canvas 2D（前期）→ Canvas 2D + Shader（后期）
- **数据格式**: JSON
- **版本控制**: Git

### 2.2 项目结构
`
card-factory/
├── project.godot                    # Godot项目配置
├── autoload/                        # 全局单例
│   ├── EventBus.gd                 # 事件总线
│   ├── GameManager.gd              # 游戏管理器
│   └── DataManager.gd              # 数据管理器（数据驱动核心）
├── scenes/
│   ├── main/
│   │   └── Main.tscn              # 主场景
│   ├── canvas/
│   │   ├── GameCanvas.tscn        # 游戏画布（Canvas 2D渲染）
│   │   └── GameCanvas.gd
│   ├── cards/
│   │   ├── CardRenderer.gd        # 卡牌渲染器（统一绘制）
│   │   └── ConnectionRenderer.gd  # 连线渲染器
│   └── ui/
│       ├── HUD.tscn               # 游戏界面
│       ├── CardPanel.tscn         # 卡牌选择面板
│       └── InfoPanel.tscn         # 信息面板
├── scripts/
│   ├── game/
│   │   ├── GameState.gd           # 游戏状态
│   │   ├── SimulationEngine.gd    # 模拟引擎
│   │   └── InputHandler.gd        # 输入处理（解决操作痛点）
│   ├── data/
│   │   ├── ProductionLine.gd      # 生产线数据结构
│   │   └── CardDefinition.gd      # 卡牌定义
│   └── utils/
│       ├── CanvasUtils.gd         # Canvas工具函数
│       └── MathUtils.gd           # 数学工具
├── data/
│   ├── base_metals.json           # 基础金属生产线（前期只做这个）
│   ├── chemicals.json             # 化工生产线（后期扩展）
│   └── electronics.json           # 电子生产线（后期扩展）
└── assets/
    ├── fonts/                     # 字体
    └── icons/                     # 图标（可选，前期可用文字代替）
`

### 2.3 核心系统关系图

`
┌─────────────────────────────────────────────────────────────┐
│                      Main Scene                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    GameCanvas                          │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │CardRenderer │  │Connection   │  │ InputHandler │   │  │
│  │  │(绘制卡牌)    │  │Renderer     │  │ (解决操作痛点)│   │  │
│  │  └─────────────┘  │(绘制连线)    │  └─────────────┘   │  │
│  │                   └─────────────┘                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 SimulationEngine                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │Production   │  │Logistics    │  │Power         │   │  │
│  │  │System       │  │System       │  │System        │   │  │
│  │  │(生产系统)    │  │(物流系统)    │  │(电力系统)    │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   DataManager                          │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │base_metals  │  │chemicals    │  │electronics   │   │  │
│  │  │.json        │  │.json        │  │.json         │   │  │
│  │  │(前期只用这个)│  │(后期扩展)    │  │(后期扩展)    │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
`

---

## 3. 卡牌系统设计

### 3.1 卡牌视觉结构

#### 前期简洁版
`
┌─────────────────────────────────────────────────────────────┐
│                        卡牌结构图                            │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │  ⛏️ 矿机                                            │   │
│   │  ─────────────────────────────────────────────────  │   │
│   │                                                     │   │
│   │  ┌─────────────────────────────────────────────┐   │   │
│   │  │  状态: 运行中 ████████░░ 80%                │   │   │
│   │  └─────────────────────────────────────────────┘   │   │
│   │                                                     │   │
│   │  ┌─────────────┐         ┌─────────────┐          │   │
│   │  │    输入      │         │    输出      │          │   │
│   │  │  (无)       │         │  铁矿石     │          │   │
│   │  │             │         │  10/分钟    │          │   │
│   │  └─────────────┘         └─────────────┘          │   │
│   │                                                     │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
`

#### 后期科幻版
`
┌─────────────────────────────────────────────────────────────┐
│                    后期（科幻质感）                           │
│                                                             │
│   ╔═════════════╗         ╔═════════════╗                  │
│   ║   ⛏️ 矿机    ║ ═════▶ ║   🔥 熔炉    ║                  │
│   ║  ┄┄┄┄┄┄┄┄┄  ║        ║  ┄┄┄┄┄┄┄┄┄  ║                  │
│   ║  出: 铁矿石  ║        ║ 入: 铁矿石   ║                  │
│   ║  ▮▮▮▮▯ 80%  ║        ║ 出: 铁锭     ║                  │
│   ╚═════════════╝        ║  ▮▮▮▮▯ 60%  ║                  │
│                          ╚═════════════╝                  │
│                                                             │
│   • 发光边框 + 半透明                                        │
│   • 流动粒子连线                                             │
│   • 进度条动画                                               │
│   • 科幻字体                                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
`

### 3.2 卡牌数据结构

`gdscript
# scripts/data/CardDefinition.gd
class_name CardDefinition
extends RefCounted

# 基础信息
var id: String
var name: String
var symbol: String        # 图标符号（emoji或文字）
var kind: String          # 类型：extractor(采矿), processor(加工), logistics(物流)
var color: Color          # 主题色

# 尺寸和布局
var size: Vector2 = Vector2(200, 150)  # 默认卡牌尺寸
var input_slots: int = 2               # 输入槽位数量
var output_slots: int = 1              # 输出槽位数量

# 状态相关
var status: String = "idle"            # idle, running, blocked, error
var progress: float = 0.0              # 生产进度 0.0 - 1.0
var efficiency: float = 1.0            # 效率倍率

# 输入输出数据
var inputs: Array[Dictionary] = []     # [{"item_id": "iron_ore", "amount": 10, "max": 60}]
var outputs: Array[Dictionary] = []    # [{"item_id": "iron_ingot", "amount": 5, "max": 60}]

# 游戏逻辑
var recipe_id: String = ""             # 当前使用的配方
var power_demand: float = 0.0          # 电力需求
var speed: float = 1.0                 # 生产速度
`

### 3.3 卡牌状态系统

| 状态 | 边框颜色 | 进度条颜色 | 说明 |
|------|----------|-----------|------|
| idle (空闲) | 灰色 #666 | 灰色 #444 | 等待输入 |
| running (运行) | 青色 #00f0ff | 绿色 #00ff88 | 正常生产 |
| blocked (阻塞) | 红色 #ff4444 | 红色 #ff4444 | 输出满/无输入 |
| error (错误) | 橙色 #ff8800 | 橙色 #ff8800 | 缺电/故障 |
| completed (完成) | 金色 #ffd700 | 金色 #ffd700 | 生产完成 |

### 3.4 连线系统

`
连线数据结构：
{
  "id": "connection_1",
  "source_id": "miner_1",        // 源卡牌ID
  "source_slot": 0,              // 源输出槽位
  "target_id": "smelter_1",      // 目标卡牌ID
  "target_slot": 0,              // 目标输入槽位
  "item_id": "iron_ore",         // 运输的物品
  "flow_rate": 10,               // 流量（每分钟）
  "throughput": 1.0              // 吞吐效率
}
`

---

## 4. 交互系统设计

### 4.1 画布导航系统

#### 平移方式
- 鼠标中键拖拽（最常用）
- WASD / 方向键（游戏玩家习惯）
- 触摸板双指滑动（笔记本用户）
- 空格+左键拖拽（备选方案）

#### 缩放系统
- **缩放范围**: 0.5% - 1000%
- **默认缩放**: 100%
- **缩放步长**: 滚轮每格10%

#### 缩放级别参考
| 级别 | 缩放比例 | 用途 |
|------|----------|------|
| 1 | 0.5% | 极度缩小，看整个大型工厂 |
| 2 | 1% | 非常缩小，查看整体布局 |
| 3 | 5% | 缩小，查看区域结构 |
| 4 | 10% | 略小，查看生产线 |
| 5 | 25% | 小型视图 |
| 6 | 50% | 中型视图 |
| 7 | 100% | 标准视图（默认） |
| 8 | 200% | 放大 |
| 9 | 500% | 高度放大 |
| 0 | 1000% | 极度放大，查看细节 |

#### 智能缩放功能
- Home：缩放到显示所有内容
- End：缩放到选中内容
- 双击空白：缩放到100%
- 双击卡牌：缩放到该卡牌并居中

#### 小地图系统
- 显示整个工厂缩略图
- 点击小地图快速跳转
- 拖拽矩形框移动视图
- 实时更新内容分布
- Tab键切换显示/隐藏

### 4.2 卡牌放置系统

#### 放置流程
1. 从卡牌面板选择建筑类型
2. 画布上显示半透明预览
3. 实时跟随鼠标位置
4. 显示占用空间（绿色=可放置，红色=不可放置）
5. 自动吸附到网格对齐
6. 点击放置，播放确认效果
7. 记录到撤销栈

### 4.3 连线操作系统

#### 普通连线（一对一）
1. 鼠标悬停在输出端口（显示高亮）
2. 按住左键拖拽
3. 拖向目标输入端口
4. 松开完成连接

#### 批量连线（一对多）
- Shift+拖拽自动连接所有同类端口

#### 智能连线提示
- 悬停端口时显示：可连接的物品类型
- 拖拽时显示：匹配的输入端口高亮
- 连接成功：播放确认音效
- 连接失败：显示原因（类型不匹配、端口已占用等）

### 4.4 撤销/重做系统

#### 支持撤销的操作
- 放置卡牌
- 删除卡牌
- 移动卡牌
- 创建连接
- 删除连接
- 修改配方
- 批量操作

#### 快捷键
- Ctrl+Z：撤销
- Ctrl+Y：重做
- Ctrl+Shift+Z：重做（备选）

#### 撤销栈设计
- 最大记录100步操作
- 内存优化：只记录变化部分
- 支持操作分组（批量操作视为一步）

### 4.5 信息查看系统

#### 悬浮提示（轻量级）
鼠标悬停在卡牌上时显示：
- 建筑名称
- 状态
- 效率
- 输入/输出

#### 详情面板（重量级）
点击卡牌时在右侧显示：
- 完整的建筑信息
- 生产进度条
- 电力信息
- 连接列表
- 操作按钮（删除、断开连接、修改配方）

### 4.6 快捷键系统

#### 画布导航
- WASD / 方向键：平移画布
- 鼠标中键拖拽：平移画布
- 鼠标滚轮：缩放画布
- Home：重置视图
- End：缩放以显示所有
- 1-9：预设缩放级别

#### 编辑操作
- Ctrl+Z：撤销
- Ctrl+Y：重做
- Ctrl+A：全选
- Delete：删除选中
- Ctrl+D：复制选中
- Ctrl+G：编组

#### 视图控制
- Tab：切换信息显示
- F1：显示/隐藏网格
- F2：显示/隐藏连接
- F3：显示/隐藏状态
- Space：暂停/继续游戏

#### 快速操作
- Q：快速选择矿机
- W：快速选择熔炉
- E：快速选择组装机
- R：快速选择传送带
- Esc：取消当前操作

---

## 5. 模拟引擎设计

### 5.1 模拟引擎架构

参照DSPONLINE的simulateStep结构，采用统一的模拟循环：

`gdscript
# scripts/game/SimulationEngine.gd
class_name SimulationEngine
extends Node

# 引用
var game_state: GameState
var production_system: ProductionSystem
var logistics_system: LogisticsSystem
var power_system: PowerSystem  # 后期扩展

# 模拟配置
var paused: bool = false
var speed: float = 1.0

func _ready():
    game_state = GameState.new()
    production_system = ProductionSystem.new(game_state)
    logistics_system = LogisticsSystem.new(game_state)

func _process(delta: float):
    if paused:
        return
    
    var game_delta = delta * speed
    
    # 按顺序更新各系统（参照DSPONLINE）
    logistics_system.update(game_delta)  # 先物流
    production_system.update(game_delta) # 再生产
    # power_system.update(game_delta)    # 后电力（后期启用）
    
    # 触发视觉更新信号
    emit_signal("simulation_updated")
`

### 5.2 生产系统

#### 生产流程
`
输入缓冲区        生产进度        输出缓冲区
┌─────────┐      ┌─────────┐      ┌─────────┐
│ 铁矿石   │      │ ██████  │      │ 铁锭    │
│ 10/60   │ ───→ │ 60%     │ ───→ │ 6/60    │
│         │      │         │      │         │
└─────────┘      └─────────┘      └─────────┘
`

#### 状态判断逻辑
- 输入充足 + 输出有空间 → running（运行中）
- 输入不足 → blocked（等待输入）
- 输出已满 → blocked（等待输出）
- 缺电 → error（电力不足）

### 5.3 物流系统

#### 前期简化：直接连接
- 卡牌A输出 → 卡牌B输入（无传送带）
- 物品直接传输，无延迟
- 限制传输速率

#### 后期扩展：传送带连接
- 卡牌A → 传送带 → 卡牌B
- 有容量限制
- 有传输延迟
- 可视化流动效果

### 5.4 电力系统（后期扩展）

#### 前期方案
- 所有建筑默认有充足电力
- 降低前期开发复杂度

#### 后期方案
- 发电机 → 电网 → 建筑
- 电力平衡检查
- 电力网络可视化

---

## 6. 数据驱动系统

### 6.1 数据文件结构

#### 前期只实现 base_metals.json
`json
{
  "line_id": "base_metals",
  "name": "基础金属生产线",
  "items": {
    "iron_ore": { "id": "iron_ore", "name": "铁矿石", "symbol": "Fe", "color": "#9aa6a8" },
    "iron_ingot": { "id": "iron_ingot", "name": "铁锭", "symbol": "Fe↑", "color": "#c0c0c0" }
  },
  "buildings": {
    "miner": { "id": "miner", "name": "矿机", "kind": "extractor", "outputs": ["iron_ore"] },
    "smelter": { "id": "smelter", "name": "熔炉", "kind": "processor", "speed": 1.0 }
  },
  "recipes": {
    "iron_ingot_recipe": {
      "building": "smelter",
      "inputs": [{"item": "iron_ore", "amount": 1}],
      "outputs": [{"item": "iron_ingot", "amount": 1}],
      "duration": 1.0
    }
  }
}
`

### 6.2 扩展新生产线

#### 扩展流程
1. 创建新JSON文件（如 dvanced_circuits.json）
2. 定义新物品、配方、建筑
3. 保存文件，引擎自动加载
4. 测试验证，新内容立即生效

#### 零代码变更
- 新增物品：添加JSON条目
- 新增配方：添加JSON条目
- 新增建筑：添加JSON条目
- 新增生产线：创建新JSON文件

### 6.3 DataManager实现

`gdscript
# scripts/data/DataManager.gd
class_name DataManager
extends Node

var all_items: Dictionary = {}
var all_buildings: Dictionary = {}
var all_recipes: Dictionary = {}

func _ready():
    _load_all_data_lines()

func _load_all_data_lines():
    var dir = DirAccess.open("res://data")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                _load_data_line("res://data/" + file_name)
            file_name = dir.get_next()

func _load_data_line(path: String):
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var json = JSON.new()
        json.parse(file.get_as_text())
        var data = json.data
        
        for item_id in data.get("items", {}):
            all_items[item_id] = data.items[item_id]
        
        for building_id in data.get("buildings", {}):
            all_buildings[building_id] = data.buildings[building_id]
        
        for recipe_id in data.get("recipes", {}):
            all_recipes[recipe_id] = data.recipes[recipe_id]
`

---

## 7. 视觉升级路径

### 7.1 渐进式视觉升级

`
┌─────────────────────────────────────────────────────────────┐
│                    前期（快速验证）                           │
│                                                             │
│   ┌─────────────┐         ┌─────────────┐                  │
│   │   ⛏️ 矿机    │ ─────→ │   🔥 熔炉    │                  │
│   │             │         │             │                  │
│   │  出: 铁矿石  │         │ 入: 铁矿石   │                  │
│   │  10/分钟    │         │ 出: 铁锭     │                  │
│   └─────────────┘         │  10/分钟    │                  │
│                           └─────────────┘                  │
│                                                             │
│   • 简洁矩形 + 文字                                          │
│   • 单色连线 + 箭头                                          │
│   • 功能优先                                                 │
│                                                             │
│   ─────────────────────────────────────────────────────────  │
│                                                             │
│                    后期（科幻质感）                           │
│                                                             │
│   ╔═════════════╗         ╔═════════════╗                  │
│   ║   ⛏️ 矿机    ║ ═════▶ ║   🔥 熔炉    ║                  │
│   ║  ┄┄┄┄┄┄┄┄┄  ║        ║  ┄┄┄┄┄┄┄┄┄  ║                  │
│   ║  出: 铁矿石  ║        ║ 入: 铁矿石   ║                  │
│   ║  ▮▮▮▮▯ 80%  ║        ║ 出: 铁锭     ║                  │
│   ╚═════════════╝        ║  ▮▮▮▮▯ 60%  ║                  │
│                          ╚═════════════╝                  │
│                                                             │
│   • 发光边框 + 半透明                                        │
│   • 流动粒子连线                                             │
│   • 进度条动画                                               │
│   • 科幻字体                                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
`

### 7.2 Shader特效清单

| 特效 | 实现方式 | 性能影响 | 视觉效果 |
|------|----------|----------|----------|
| 发光边框 | Canvas Shadow + 渐变 | 极低 | ⭐⭐⭐⭐ |
| 流动粒子 | 自定义Shader / Canvas动画 | 低-中 | ⭐⭐⭐⭐⭐ |
| 玻璃态模糊 | 高斯模糊Shader | 中等 | ⭐⭐⭐⭐ |
| 能量流动 | 顶点动画Shader | 低 | ⭐⭐⭐⭐⭐ |

---

## 8. 开发路线图

### 8.1 第一阶段：最小可行产品（2-3周）

#### 目标
- 验证核心玩法
- 跑通铁矿→铁锭生产线
- 建立基础架构

#### 功能清单
- [ ] 基础Canvas 2D渲染
- [ ] 卡牌系统（矿机、熔炉）
- [ ] 简化的生产系统
- [ ] 简化的物流系统（直接连接）
- [ ] 基础交互（放置、连线、删除）
- [ ] 数据驱动架构（base_metals.json）

#### 技术任务
- [ ] 创建Godot项目结构
- [ ] 实现DataManager
- [ ] 实现GameState
- [ ] 实现SimulationEngine（简化版）
- [ ] 实现CardRenderer
- [ ] 实现ConnectionRenderer
- [ ] 实现InputHandler（基础版）

### 8.2 第二阶段：功能完善（4-6周）

#### 目标
- 添加多条生产线
- 完善交互系统
- 添加电力系统

#### 功能清单
- [ ] 多条生产线（数据驱动扩展）
- [ ] 电力系统
- [ ] 传送带系统
- [ ] 完善的交互系统（撤销、快捷键等）
- [ ] 小地图
- [ ] 完善UI界面
- [ ] 详情面板

#### 技术任务
- [ ] 实现PowerSystem
- [ ] 实现BeltSystem
- [ ] 实现UndoRedo系统
- [ ] 实现MiniMap
- [ ] 完善InputHandler
- [ ] 添加更多数据文件

### 8.3 第三阶段：性能优化+视觉升级（3-4周）

#### 目标
- 优化性能
- 升级视觉效果
- 准备发布

#### 功能清单
- [ ] 索引系统优化
- [ ] Shader科幻特效
- [ ] 存档系统
- [ ] 统计系统
- [ ] 测试和平衡调整
- [ ] 正式发布

#### 技术任务
- [ ] 实现SpatialIndex
- [ ] 实现Shader特效
- [ ] 实现SaveSystem
- [ ] 实现StatisticsSystem
- [ ] 性能测试和优化
- [ ] Bug修复

---

## 9. 非目标（Non-Goals）

以下功能在当前设计中**不包含**，以保持项目范围可控：

1. **多人游戏/联机** - 纯单机体验
2. **3D渲染** - 保持2D Canvas方案
3. **移动端适配** - 优先PC体验
4. **复杂物理模拟** - 简化物流系统
5. **无限行星系统** - 前期只做单一平面
6. **复杂AI/自动化** - 保持玩家手动操作

---

## 10. 成功标准

### 10.1 第一阶段成功标准
- 能够放置矿机和熔炉
- 能够建立连接
- 铁矿石能够流动到熔炉
- 铁锭能够生产出来
- 基础UI能够显示状态

### 10.2 第二阶段成功标准
- 支持至少3条生产线
- 电力系统正常工作
- 传送带系统正常工作
- 撤销/重做功能正常
- 小地图能够导航

### 10.3 第三阶段成功标准
- 支持100+建筑无卡顿
- 存档/读档功能正常
- Shader特效正常显示
- 无严重Bug
- 可以正式发布

---

## 附录A：参考资源

### DSPONLINE源码位置
- 项目位置：../DSPONLINE
- 核心引擎：src/game/engine.ts (675KB)
- 生产管理：src/game/productionManagement.ts
- 物流系统：src/game/beltFlow.ts

### Godot MCP工具
- Godot版本：4.7.2
- MCP工具可用：launch_editor, run_project, get_version等

---

**文档结束**
