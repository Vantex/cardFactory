# Data Model

## Key entities

| Entity | Owner | Relevant fields | Phase 2 role |
|---|---|---|---|
| GameState | GameManager | buildings, connections, elapsed_time, paused, speed, construction_points | 工作区唯一活动状态 |
| Building | GameState.buildings | id, type, position, status, progress, recipe_id, input_buffer, output_buffer | 画布卡片与检查器对象 |
| Connection | GameState.connections | id, source_id, target_id, item_id, flow_rate, active | 物流边与连接反馈 |
| BuildingDefinition | DataManager.all_buildings | id, name, symbol, kind, power_demand/generation, slots | 建造坞和检查器元数据 |
| RecipeDefinition | DataManager.all_recipes | id, name, building_id, inputs, outputs, duration | 配方选择与连接兼容性 |
| ItemDefinition | DataManager.all_items | id, name, symbol, color | 端口、库存和物流标签 |

## Relationships

- GameState 1→N Building。
- GameState 1→N Connection。
- Connection N→1 source Building，N→1 target Building。
- Building N→0..1 RecipeDefinition；RecipeDefinition 指定兼容 building_id。
- RecipeDefinition N↔N ItemDefinition，通过 inputs/outputs 数组连接。
- BuildingDefinition 与 Building.type 以字符串 ID 关联。

## Invariants for Phase 2

- Connection 两端必须存在，且不能相同。
- 同一 source、target、item 组合最多一条连接。
- connection.item_id 必须来自源建筑输出，并被目标当前或自动选择的配方接受。
- 放置成功才扣建造点；任何验证失败不得部分修改状态。
- 删除建筑同步删除所有关联连接。
- UI 选择 ID 不属于持久化游戏状态；实体消失后必须清空选择。
