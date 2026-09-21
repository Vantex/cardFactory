# CardFactory 对齐 DSPONLINE 单机玩法实施计划

> **执行要求：** 后续会话使用 `executing-plans` 或 `subagent-driven-development` 技能按任务实施。每项功能先写失败测试，再做最小实现；每完成一个任务都运行本任务门和全量门，并形成可回滚提交。

**目标：** 在 Godot 4 中完整复刻 DSPONLINE 的离线单机功能、内容、数值规则和操作闭环，覆盖可靠存档、确定性生产、电力、物流、科技、多行星、戴森工程、离线结算和终局；不要求读取或转换 DSPONLINE 旧存档，不实现账号、云存档、排行榜、在线社交或服务器运维。

**设计依据：** `docs/current/SINGLE_PLAYER_GAP_ANALYSIS.md`

**架构方向：** 保留当前 `Main + GameManager + GameState + SimulationEngine` 主干，但先建立版本化状态、codec、迁移和固定步长。领域系统只接受权威 GameState，通过原子命令修改状态；UI 只发送意图和展示结果。各阶段必须交付一个从正式入口可触发的纵向闭环。

**技术栈：** Godot 4.7、GDScript、Node2D/Camera2D、Control/CanvasLayer、JSON 本地存档、PowerShell 测试门。

---

## 范围边界

### 本计划包含

- 完整单机工厂、科技、星图、物流、戴森和终局循环。
- 本地存档、备份、自动保存、离线结算和崩溃后安全恢复。
- 蓝图、统计、资料库、设置、桌面键鼠/手柄/无障碍和本地导出。
- DSPONLINE 当前单机目录中的全部物品、配方、建筑、科技、战役、成就、难度、速通、时间扭曲和本地空间站功能。
- DSPONLINE 单机 UI 中的等价操作、反馈、快捷键和桌面键鼠工作流；Godot 可以使用原生控件实现，不要求复用 React 代码或像素级复制网页布局。

### 本计划明确排除

- 账号、邮箱、云存档、云冲突、排行榜、在线活动、遥测。
- 公共空间站主页、玩家社交、在线合同和服务器同步。
- Node/SQLite 服务端、部署、备份、运营后台、PWA/Electron/Capacitor 实现。
- 读取、导入或无损转换 DSPONLINE 既有存档；CardFactory 只保证自身版本间的存档迁移。

旧 `SaveSystem` 中的云方法不得继续伪装成功；在任务 1 中将其隔离或明确返回“不支持”。

## 全程质量门

每个任务结束都运行：

```powershell
git diff --check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
& 'D:\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
git status --short --branch
```

要求：

- 命令退出码均为 0。
- 无 `SCRIPT ERROR`、`Parse Error`、测试失败标记和重复成功标记。
- 新增测试已进入 `tools/run_tests.ps1`，不能只手动运行。
- 新建 worktree 不需要人工先打开编辑器；测试门自行完成必要导入。
- 主场景退出不再新增 ObjectDB/resource 泄漏；现有退出警告在任务 1 收口。
- 文档状态只在正式入口、持久化往返和回归测试均通过后更新。

## 目标测试结构

- `scripts/test/TestStatePersistence.gd`：状态 schema、codec、迁移、槽位与自动保存。
- `scripts/test/TestSimulationCore.gd`：固定步长、电力、生产、资源守恒。
- `scripts/test/TestInventoryConstruction.gd`：行星托盘、施工库存、手工制造、升级和回收。
- `scripts/test/TestAdvancedCanvas.gd`：多选、批量编辑、线路配置和小地图。
- `scripts/test/TestBlueprints.gd`：蓝图创建、变换、预检、原子部署和导入导出。
- `scripts/test/TestProgression.gd`：教程、任务、科技、成就与解锁。
- `scripts/test/TestStatisticsCodex.gd`：统计、诊断、资料库和生产定位。
- `scripts/test/TestGalaxyLogistics.gd`：独立行星、殖民、星图和星际物流。
- `scripts/test/TestDysonEndgame.gd`：戴森工程、巨构和胜利条件。
- `scripts/test/TestOfflineSettlement.gd`：离线时间、重复结算保护和离线报告。
- `scripts/test/TestProductShell.gd`：菜单、设置、输入方式和响应式 UI。
- `scripts/test/TestPerformanceBudgets.gd`：大工厂状态一致性与性能预算。
- `scripts/test/TestDSPOnlineParity.gd`：冻结目录、规则夹具、单机操作和端到端内容对齐。

每个脚本配一个同名 `scenes/test/*.tscn` 入口，并有唯一成功标记。

---

## 阶段 0：可信基线

### 任务 1：收紧测试门并清理假能力

**文件：**

- 修改：`tools/run_tests.ps1`
- 修改：`scripts/game/SaveSystem.gd`
- 修改：`scripts/game/PerformanceSystem.gd`
- 修改：`docs/PROJECT_STATUS.md`
- 检查：`scripts/test/TestCompletedFeatures.gd`、`scripts/test/TestPhase*.gd`

- [x] **步骤 1：为全新检出编写失败门禁**

在临时 worktree 直接运行 `tools/run_tests.ps1`，记录当前因全局脚本类缓存缺失而失败的复现；增加测试门自引导断言，预期修改前失败。

- [x] **步骤 2：让 runner 自动完成 Godot 导入**

runner 在执行测试场景前运行一次 `--headless --editor --quit`，检查退出码和解析错误，再进入测试列表。Godot 路径只在 runner 中解析，不在各测试重复硬编码。

- [x] **步骤 3：修复主场景退出资源警告**

定位未释放的 `SimulationEngine`/动态脚本实例/信号连接；添加确定性 teardown。禁止用过滤日志隐藏 ObjectDB/resource 警告。

- [x] **步骤 4：删除假成功语义**

云同步、云备份、云恢复、伪压缩和伪迁移方法改为明确 `ERR_UNAVAILABLE` 风格结果，或移出单机公共接口。`PerformanceSystem` 的 Worker 占位不得报告已启用。

- [x] **步骤 5：标记历史测试为非权威**

旧 `TestPhase*` 保留为历史夹具或迁入 `tests/legacy`，但 runner 只执行具有失败退出语义的正式测试。

- [x] **步骤 6：验证并提交**

运行全程质量门，并在全新临时 worktree 再运行一次 runner。

```powershell
git add tools/run_tests.ps1 scripts/game/SaveSystem.gd scripts/game/PerformanceSystem.gd docs/PROJECT_STATUS.md
git commit -m "test: establish trustworthy clean checkout gate"
```

**停止门：** 全新检出可一条命令测试，主场景零脚本错误且资源生命周期问题已解释或修复，任何未实现服务不会返回成功。

**完成记录（2026-08-24）：** `9d060e7` 已建立自动导入与泄漏失败门，修正 `SimulationEngine` 生命周期，清除延期存档能力的假成功返回，并在无 `.godot` 的全新 worktree 中直接通过权威 runner。

### 任务 2：建立版本化 GameState 和完整性验证

**文件：**

- 创建：`scripts/game/GameStateCodec.gd`
- 创建：`scripts/game/GameStateValidator.gd`
- 创建：`scripts/game/SaveMigrationRegistry.gd`
- 创建：`scripts/test/TestStatePersistence.gd`
- 创建：`scenes/test/TestStatePersistence.tscn`
- 修改：`scripts/game/GameState.gd`
- 修改：`autoload/GameManager.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写 schema/codec 失败测试**

覆盖：版本号、稳定 ID、`Vector2` 编码、建筑/连接字典、临时运行字段排除、解码后类型恢复、悬空连接拒绝、负库存拒绝。

- [x] **步骤 2：定义规范快照**

`GameStateCodec.to_persistent_dict(state)` 只输出持久字段；位置编码为 `{x, y}`；字典键稳定排序；`from_persistent_dict` 创建新 GameState，不直接把 JSON 字典塞入运行对象。

- [x] **步骤 3：增加 schema 版本和迁移注册表**

定义单调整数版本。每个迁移只处理 `vN → vN+1`，未知未来版本拒绝加载；迁移完成后运行 validator。

- [x] **步骤 4：增加状态摘要**

提供稳定的 `state_digest_payload()`，用于固定步长、保存往返、优化前后差分测试；不包含帧时间、节点引用和 UI 选择。

- [x] **步骤 5：验证并提交**

```powershell
git add scripts/game/GameState.gd scripts/game/GameStateCodec.gd scripts/game/GameStateValidator.gd scripts/game/SaveMigrationRegistry.gd autoload/GameManager.gd scripts/test/TestStatePersistence.gd scenes/test/TestStatePersistence.tscn tools/run_tests.ps1
git commit -m "feat: add versioned authoritative game state"
```

**完成记录（2026-08-24）：** 已交付整数 schema、规范 codec、逐版本迁移、完整性验证、稳定状态摘要和 GameManager 原子替换边界；`TestStatePersistence` 已进入权威 runner。真正的磁盘存档接入继续由任务 3 负责。

### 任务 3：交付可靠本地存档和游戏会话入口

**文件：**

- 修改：`scripts/game/SaveSystem.gd`
- 修改：`autoload/GameManager.gd`
- 创建：`scenes/ui/AppShell.gd`
- 创建：`scenes/ui/StartMenu.gd`
- 创建：`scenes/ui/SaveSlotsPanel.gd`
- 修改：`scenes/main/Main.tscn`
- 修改：`scenes/main/Main.gd`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scripts/test/TestStatePersistence.gd`
- 修改：`scripts/test/TestFactoryWorkspace.gd`

- [x] **步骤 1：写槽位往返失败测试**

保存包含建筑位置、连接流状态、库存、研究进度和 elapsed time 的状态；加载后比较持久摘要。覆盖无效槽、损坏 JSON、未来版本、写入中断和备份恢复。

- [x] **步骤 2：原子写入本地档**

先写临时文件并读回校验，再替换主档；保留最近一个已验证备份。元数据包含 schema、时间、游玩时长、活动行星和摘要。

- [x] **步骤 3：实现开始菜单**

正式入口提供新游戏、继续、槽位管理、删除确认和返回。加载失败留在菜单并显示可操作原因，不创建半初始化会话。

- [x] **步骤 4：实现自动保存和退出握手**

定时保存、关键进度保存、退出前保存使用同一个协调器，禁止重叠写入。玩家暂停意图在保存前后不改变。

- [x] **步骤 5：验证真实流程**

自动测试与一次手动流程：新游戏 → 建造生产线 → 保存 → 退出 → 继续 → 位置、库存和模拟状态一致。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/SaveSystem.gd autoload/GameManager.gd scenes/ui/AppShell.gd scenes/ui/StartMenu.gd scenes/ui/SaveSlotsPanel.gd scenes/main/Main.gd scenes/main/Main.tscn scripts/input/InputHandler.gd scripts/test/TestStatePersistence.gd scripts/test/TestFactoryWorkspace.gd README.md docs/PROJECT_STATUS.md docs/current/SINGLE_PLAYER_ROADMAP.md
git commit -m "feat: add durable local save sessions"
```

**完成记录（2026-08-24）：** 已交付 10 槽原子本地存档、最近有效备份、损坏/未来版本拒绝、开始菜单、槽位管理、120 秒自动保存和退出握手；自动门禁与用户手动流程均通过。UI 不直接修改权威状态，加载失败不会替换现有会话。

---

## 阶段 1：完整行星工厂

### 任务 4：固定步长与真实电力效果

**文件：**

- 创建：`scripts/test/TestSimulationCore.gd`
- 创建：`scenes/test/TestSimulationCore.tscn`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scripts/game/PowerSystem.gd`
- 修改：`scripts/game/ProductionSystem.gd`
- 修改：`scripts/game/BeltSystem.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/game/GameStateCodec.gd`
- 修改：`scripts/game/GameStateValidator.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scripts/test/TestFactoryWorkspace.gd`
- 修改：`scripts/test/TestStatePersistence.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写帧率独立失败测试**

对同一初态分别执行 60×1/60 秒、10×0.1 秒和 1×1 秒，比较持久摘要与产量；修改前应暴露差异或边界跳跃。

- [x] **步骤 2：增加固定模拟步长**

渲染 delta 进入 accumulator，以固定 tick 推进。定义每帧最大追赶步数，超额时间保留到下一帧而不是丢弃。

- [x] **步骤 3：让供电倍率进入生产和物流**

断电停止，欠电按倍率推进，恢复后保留进度。发电机没有燃料时不得发电；基础太阳能/风能使用明确规则。

- [x] **步骤 4：测试阶段顺序**

固定 `电力 → 生产/采集 → 线路 → 研究 → 统计` 的边界，并用一 tick 和多 tick 用例证明没有同帧重复消费。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/SimulationEngine.gd scripts/game/PowerSystem.gd scripts/game/ProductionSystem.gd scripts/game/BeltSystem.gd scripts/test/TestSimulationCore.gd scenes/test/TestSimulationCore.tscn tools/run_tests.ps1
git commit -m "feat: make factory simulation deterministic"
```

**完成记录（2026-08-24）：** 已交付 60 Hz 固定 tick、每帧最多 10 步且保留超额时间的追赶预算、确定的“电力 → 生产/采集 → 线路 → 研究边界 → 统计”顺序，以及作用于生产和线路的真实供电倍率。燃料机无燃料不发电，太阳能/风能使用显式倍率；任务 5 已把基础发电机启动燃料接入守恒的行星煤炭库存，正式补充燃料交互仍属后续范围。规范存档排除可重建的电力输出和效率，并校验持久化燃料字段。`TestSimulationCore` 已进入权威 runner。

### 任务 5：行星库存、施工库存与手工制造

**文件：**

- 创建：`scripts/game/InventorySystem.gd`
- 创建：`scripts/game/ConstructionSystem.gd`
- 创建：`scripts/game/HandcraftSystem.gd`
- 创建：`scripts/test/TestInventoryConstruction.gd`
- 创建：`scenes/test/TestInventoryConstruction.tscn`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/game/GameStateCodec.gd`
- 修改：`scripts/game/GameStateValidator.gd`
- 修改：`scripts/game/SaveMigrationRegistry.gd`
- 修改：`scripts/game/SaveSystem.gd`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scenes/main/Main.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scripts/test/TestFactoryWorkspace.gd`
- 修改：`scripts/test/TestStatePersistence.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写资源守恒失败测试**

覆盖物资加入/取出、施工件消费、建筑拆除返还、手工制造、材料不足原子失败、缓存上限和非负约束。

- [x] **步骤 2：用真实库存替换建造点**

保留旧建造点只作为迁移输入或删除；正式建造从施工库存扣除对应建筑件。新游戏初始套装足以建成第一条电力—采矿—熔炼—制造链。

- [x] **步骤 3：实现手工制造**

支持可手工配方、批量数量、上游材料预览和原子扣料；长任务进入持久队列，暂停/保存/加载后继续。

- [x] **步骤 4：接入资源栏与建造坞**

资源栏显示行星托盘和光标载荷；建造坞显示已有/需要数量与缺料原因。UI 不直接改库存字典。

- [x] **步骤 5：提交**

```powershell
git add scenes/main/Main.gd scenes/ui/FactoryWorkspaceUI.gd scripts/game/GameState.gd scripts/game/GameStateCodec.gd scripts/game/GameStateValidator.gd scripts/game/SaveMigrationRegistry.gd scripts/game/SaveSystem.gd scripts/game/SimulationEngine.gd scripts/game/InventorySystem.gd scripts/game/ConstructionSystem.gd scripts/game/HandcraftSystem.gd scripts/input/InputHandler.gd scripts/test/TestFactoryWorkspace.gd scripts/test/TestStatePersistence.gd scripts/test/TestInventoryConstruction.gd scenes/test/TestInventoryConstruction.tscn tools/run_tests.ps1 README.md docs/PROJECT_STATUS.md docs/current/SINGLE_PLAYER_GAP_ANALYSIS.md docs/current/SINGLE_PLAYER_ROADMAP.md
git commit -m "feat: add conserved construction inventory"
```

**完成记录（2026-08-24）：** 已用行星托盘、施工库存和光标载荷替换运行时建造点，四类初始施工件足以搭建第一条基础链。放置与拆除会原子消费/返还施工件、建筑缓存和发电机未燃煤，容量不足时不产生半状态。基础手工配方支持 1～99 批量需求、缺料与上游配方预览，整批输入在排队时统一保留，持久队列按固定 tick 推进并支持暂停、保存和加载续作。schema v2 保存全部新领域状态，合法 v1 封装先校验原版本摘要再迁移，建造点转为界面可见的兼容施工额度。资源栏、空闲检查器和建造坞已显示托盘、光标、手工队列、已有/需要数量及缺料原因；`TestInventoryConstruction` 已进入五场景权威 runner。

### 任务 6：补齐数据驱动生产目录

**文件：**

- 修改：`autoload/DataManager.gd`
- 拆分/修改：`data/*.json`
- 修改：`scripts/game/ProductionSystem.gd`
- 修改：`scripts/game/GameStateValidator.gd`
- 修改：`scripts/test/TestSimulationCore.gd`
- 修改：`scripts/test/TestInventoryConstruction.gd`

- [x] **步骤 1：建立内容清单**

创建物品、配方、建筑、科技和解锁映射表。历史参考数量 78/78/37/67 已由任务 19 冻结目录取代（78 物品、80 配方、39 建筑、69 有效科技及 7 弃用定义），后续以冻结目录检查覆盖度，不复制其名字、素材或源码；CardFactory 可使用原创命名和视觉。

- [x] **步骤 2：先完成一条完整科学链**

实现从原矿到基础研究矩阵的全部设备、配方、电力和施工件，使第一章教程可以完整游玩。

- [x] **步骤 3：扩展设备规则**

支持多输入/输出、燃料、副产物、不同缓存、速度倍率、资源采集器和研究设备。每种新 `kind` 至少有一个领域测试。

- [x] **步骤 4：加强 DataManager 校验**

启动时拒绝重复 ID、缺失物品、非法数量/持续时间、无效建筑引用、科技循环和无法制造的强制任务物品。

- [x] **步骤 5：分批补齐目录**

按基础金属 → 石油化工 → 电子 → 星际材料 → 戴森材料分批提交。每批都保持现有存档可迁移，避免一次性导入全部内容。

- [x] **步骤 6：提交第一批完整生产目录**

```powershell
git add autoload/DataManager.gd data scripts/game/ProductionSystem.gd scripts/game/GameStateValidator.gd scripts/test/TestSimulationCore.gd scripts/test/TestInventoryConstruction.gd
git commit -m "feat: expand data driven production catalog"
```

**完成记录（2026-08-25）：** 新增 [`CONTENT_CATALOG.md`](CONTENT_CATALOG.md) 作为当前 39 个物品、30 个建筑、22 个配方和 3 项科技的权威映射。第一条科学链已从可切换铁/铜采集目标，经铁锭、铜锭、磁体、电路和磁线圈，接入可施工的矩阵研究站并产出基础研究矩阵；固定步长测试会运行完整连接图而非只检查 JSON。采集资源/速率、燃料/燃烧时间、输入输出缓存、速度、多输入、多输出和副产物均由目录字段驱动，检查器可选择副产物进入正式连接。`DataManager` 启动门禁覆盖跨文件重复 ID、引用、数量/时间/容量、科技循环和强制物品可制造性，`GameStateValidator` 拒绝存档中的配方错配、非法燃料与非法采集/输出目标。目录按基础、化工、电子、进阶和进程文件保持可分批扩展；电路配方保留旧 `assembler` 设备映射，新增字段及矩阵施工件不提升 schema v2，基线 v2 存档仍可直接加载。

---

## 阶段 2：大型工厂编辑与物流

### 任务 7：多选、批量命令和线路配置

**文件：**

- 创建：`scripts/test/TestAdvancedCanvas.gd`
- 创建：`scenes/test/TestAdvancedCanvas.tscn`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scripts/rendering/CardRenderer.gd`
- 修改：`scripts/rendering/ConnectionRenderer.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/game/BeltSystem.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写选择集合失败测试**

覆盖 Ctrl 增减选择、空白反向框选、批量移动失败回滚、批量删除确认和锁定建筑不可移动。

- [x] **步骤 2：把选择状态从单 ID 升级为集合**

选择属于工作区会话状态，不进入存档；renderer、检查器和删除操作都消费同一集合。

- [x] **步骤 3：实现传送带等级和配置**

增加 Mk.I/II/III 吞吐、并联数、货物堆叠、优先级、路线模式、监控和启停；所有调整进行施工件守恒校验。

- [x] **步骤 4：实现整网同步和升级**

模板线路必须由玩家明确选择；批量结果报告成功、跳过和失败原因，不修改在途货物与累计统计。

- [x] **步骤 5：接入高级检查器**

单选展示完整线路或建筑配置；多选只展示交集命令和汇总预览。

- [x] **步骤 6：提交**

```powershell
git add scripts/input/InputHandler.gd scripts/rendering/CardRenderer.gd scripts/rendering/ConnectionRenderer.gd scripts/game/GameState.gd scripts/game/BeltSystem.gd scenes/ui/FactoryWorkspaceUI.gd scripts/test/TestAdvancedCanvas.gd scenes/test/TestAdvancedCanvas.tscn tools/run_tests.ps1
git commit -m "feat: add advanced canvas and belt editing"
```

**完成记录（2026-08-28）：** 画布选择已升级为不进入存档的会话集合，支持 Ctrl 增减、空白反向框选、锁定建筑保护及预检后原子批量移动/确认删除。线路支持 Mk.I/II/III、并联、堆叠、优先级、路线、手动偏移、监控和启停；等级/并联及拆除统一校验施工件守恒，旧 schema v2 线路使用确定性默认。整网命令按真实连通端点执行并返回成功/跳过/失败原因，不修改运行时流量、累计统计或在途货物。单选检查器显示完整建筑/线路配置，多选只展示建筑或线路的交集命令；`TestAdvancedCanvas` 已加入统一门禁，六个权威场景全部通过。

### 任务 8：蓝图、小地图、区域与书签

**文件：**

- 创建：`scripts/game/BlueprintSystem.gd`
- 创建：`scripts/game/BlueprintCodec.gd`
- 创建：`scenes/ui/BlueprintWorkspace.gd`
- 创建：`scripts/test/TestBlueprints.gd`
- 创建：`scenes/test/TestBlueprints.tscn`
- 重写：`scenes/ui/MiniMap.gd`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写蓝图原子性失败测试**

覆盖选择捕获、内部连接、旋转、镜像、位置偏移、重叠、缺料、非法引用、重复粘贴和完整回滚。

- [x] **步骤 2：定义蓝图 v1 格式**

格式包含版本、相对位置、建筑类型/配置和内部线路，不包含运行中库存、进度、ID、选中态或节点引用。

- [x] **步骤 3：实现预览与原子部署**

先生成全部目标实体和总成本，再统一验证空间、解锁和施工库存；任何失败不创建实体、不扣物资。

- [x] **步骤 4：实现导入导出**

只接受受限 JSON；限制数量、坐标和文本长度；导入不自动执行部署。

- [x] **步骤 5：重写小地图并加入区域/书签**

小地图读取实时相机和空间索引；点击/拖动移动相机。区域与书签只影响展示和导航，不进入生产规则。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/BlueprintSystem.gd scripts/game/BlueprintCodec.gd scenes/ui/BlueprintWorkspace.gd scenes/ui/MiniMap.gd scripts/input/InputHandler.gd scripts/game/GameState.gd scripts/test/TestBlueprints.gd scenes/test/TestBlueprints.tscn tools/run_tests.ps1
git commit -m "feat: add atomic factory blueprints"
```

**完成记录（2026-08-30）：** 已交付受限蓝图 v1、选择捕获、内部线路与完整持久配置、顺逆时针/镜像预览、剪贴板导入导出和预检后原子部署。空间、科技解锁、建筑/线路兼容性及施工库存会在任何状态写入前统一验证；提交阶段故障会恢复建筑、线路、库存与下一个稳定 ID，失败不发出半完成事件。正式 Main 通过 Inspector 入口打开默认收起的蓝图工作台，普通画布不会被常驻浮层遮挡；工作台与小地图进入统一 UI 命中边界，连接/框选释放不会穿透。小地图使用实时相机与派生空间索引，动态覆盖远端/负坐标建筑，并提供只影响展示和导航的区域与书签。`TestBlueprints` 以 52 项行为断言加入统一门禁，七个权威场景全部通过。交付提交为 `dc518a6`、`52d2dec`、`0226572` 与 `e5fb7d7`。

---

## 阶段 3：教程、科技与分析

### 任务 9：正式教程、战役与成就

**文件：**

- 创建：`scripts/game/ProgressionSystem.gd`
- 创建：`scripts/game/ObjectiveSystem.gd`
- 创建：`data/progression.json`
- 创建：`scenes/ui/CampaignWorkspace.gd`
- 创建：`scenes/ui/TutorialOverlay.gd`
- 创建：`scripts/test/TestProgression.gd`
- 创建：`scenes/test/TestProgression.tscn`
- 修改：`scripts/game/GameState.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写任务状态机失败测试**

覆盖开始、进度、完成、奖励一次性发放、保存加载、已有状态回溯完成和直接定位停机建筑。

- [x] **步骤 2：把新手提示升级为持久目标**

第一章从建造电力、采矿、熔炼到第一份研究矩阵；每一步由领域事实判断，不由 UI 点击次数判断。

- [x] **步骤 3：建立章节和支线**

覆盖电力、存储、线路升级、化工、物流、稀有资源、蓝图、星际和戴森。奖励通过统一原子命令进入库存或解锁表。

- [x] **步骤 4：加入本地成就**

成就只依赖当前存档事实，不联网；加载旧档时可补发符合条件的成就，但奖励必须幂等。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/ProgressionSystem.gd scripts/game/ObjectiveSystem.gd data/progression.json scenes/ui/CampaignWorkspace.gd scenes/ui/TutorialOverlay.gd scripts/game/GameState.gd scenes/ui/FactoryWorkspaceUI.gd scripts/test/TestProgression.gd scenes/test/TestProgression.tscn tools/run_tests.ps1
git commit -m "feat: add persistent single player progression"
```

**完成记录（2026-08-30）：** 已交付基于领域事实的持久目标状态机、9 个章节/支线、13 项阶段目标和 3 项本地成就。第一章按供电、采矿、熔炼、连接和首份基础研究矩阵推进；旧 schema v2 存档迁移到 v3 后会根据当前建筑、连接、库存和缓冲区追溯完成，不依赖 UI 点击。目标与成就奖励先统一预检库存及解锁表，再原子提交稳定领取 ID，容量不足不产生半完成或重复发放。正式 Main 新增默认收起的战役工作台和不拦截画布的目标提示，支持定位并选中停工建筑，面板与现有顶栏、资源栏、检查器、建造坞、蓝图及小地图保持独立区域。`TestProgression` 已加入统一门禁，八个权威场景全部通过。

### 任务 10：重建数据驱动科技系统

**文件：**

- 重写：`scripts/game/TechnologySystem.gd`
- 重写：`scenes/ui/TechnologyPanel.gd`
- 创建：`data/technologies.json`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/test/TestProgression.gd`

- [x] **步骤 1：写研究队列失败测试**

覆盖前置、成本、排队、暂停、恢复、取消后保留投入、完成、下一项启动、效果应用和保存加载。

- [x] **步骤 2：把科技定义迁到 JSON**

科技包含稳定 ID、前置、成本、解锁、效果和可重复规则；DataManager 检查循环和无效引用。

- [x] **步骤 3：接入 SimulationEngine**

研究只在有合法科研设备、矩阵和电力时推进；完成边界与生产 tick 确定一致。

- [x] **步骤 4：实现正式科技工作区**

支持搜索、筛选、队列、前置可视化、进度和解锁说明；关闭再打开保持筛选和滚动。

- [x] **步骤 5：分阶段扩充科技目录**

先覆盖基础行星工业，再扩展星际、戴森和无限科技。每批科技必须有至少一个效果行为测试。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/TechnologySystem.gd scenes/ui/TechnologyPanel.gd data/technologies.json scripts/game/SimulationEngine.gd scripts/game/GameState.gd scripts/test/TestProgression.gd
git commit -m "feat: add data driven technology progression"
```

**完成记录（2026-08-31）：** `technologies.json` 提供 6 项基础行星、星际、戴森和无限科技，均有稳定 ID、名称、描述、层级、前置、非零矩阵成本、解锁、效果与可重复规则。`DataManager` 拒绝缺失必填字段、非法层级、空/未知/非有限/非正成本、未知/非有限/非正效果及不合法前置/解锁形状。schema v4 将当前研究、FIFO 队列、进度、已投入成本和暂停状态迁入 `GameState`；schema v5 再持久化队列等待原因和可重复层数，迁移链为 v3→v4→v5，v4 的已完成可重复科技初始化为第 1 层。研究命令在开始时原子扣除矩阵；空闲研究阶段会重试 FIFO 队首，先完成扣费、出队和当前项赋值再发布开始事件，直接开始不能绕过队列。暂停/取消保留投入和进度，生产速度效果直接影响真实生产/采集。正式科技工作区通过 Main 路由意图，支持搜索、独立层级/状态筛选、目录详情、等待原因、暂停/恢复/取消/移出队列、真实滚动保持，并与战役/蓝图工作区互斥；`TestBaseline`、`TestProgression`、`TestSimulationCore` 和持久化门覆盖完整闭环。

### 任务 11：统计、诊断与生产资料库

**文件：**

- 重写：`scripts/game/StatisticsSystem.gd`
- 创建：`scripts/game/ProductionDiagnostics.gd`
- 创建：`scripts/game/RecipeGraph.gd`
- 重写：`scenes/ui/StatisticsPanel.gd`
- 创建：`scenes/ui/CodexWorkspace.gd`
- 创建：`scripts/test/TestStatisticsCodex.gd`
- 创建：`scenes/test/TestStatisticsCodex.tscn`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写采样窗口和诊断失败测试**

覆盖生产/消耗/净值、多个时间窗口、断电、缺料、输出满、线路堵塞和无配方原因。

- [x] **步骤 2：实现有界统计历史**

统计按固定模拟时间采样，限制历史大小；统计缓存可重建，不阻塞存档。

- [x] **步骤 3：实现生产链图**

支持物品→配方→建筑正反查、两层链和完整链；检测循环，输出缺口和理论速率。

- [x] **步骤 4：实现生产定位**

从诊断结果定位到正确行星，聚焦并高亮真实生产/阻塞建筑，不修改选择之外的状态。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/StatisticsSystem.gd scripts/game/ProductionDiagnostics.gd scripts/game/RecipeGraph.gd scenes/ui/StatisticsPanel.gd scenes/ui/CodexWorkspace.gd scripts/test/TestStatisticsCodex.gd scenes/test/TestStatisticsCodex.tscn tools/run_tests.ps1 README.md docs/PROJECT_STATUS.md docs/current/SINGLE_PLAYER_ROADMAP.md
git commit -m "docs: complete statistics diagnostics task"
```

**完成记录（2026-09-01）：** 已交付固定模拟时间采样的生产、消耗、净值和线路吞吐统计；60/300/600 秒窗口使用最多 600 个历史样本，60×1/60 与 10×0.1 的权威摘要一致。统计历史是运行时可重建缓存，不写入 `GameState` 或存档 schema。`ProductionDiagnostics` 以稳定顺序只读报告无配方、无电、缺料、输出满、线路堵塞和禁用线路；定位只经 Main 改变相机与会话选择。`RecipeGraph` 深拷贝目录，支持物品—配方—建筑正反查、两层/完整上游链、循环、缺口及理论速率。正式“分析”工作区提供统计、诊断和资料库三页、搜索、固定窗口/链深度与真实滚动，并与科技、战役、蓝图互斥。`TestStatisticsCodex` 已成为第九个严格门禁场景；门禁验证成功标记恰好一次、失败标记、Godot 退出码、脚本/解析错误及 ObjectDB/资源泄漏。当前范围仍为单行星；下一步是任务 12 的独立行星工厂与星图，账号、云存档、排行榜、在线社交和服务器运维继续排除。

---

## 阶段 4：多行星与星际物流

### 任务 12：独立行星工厂与星图

**文件：**

- 重写：`scripts/game/PlanetSystem.gd`
- 重写：`scripts/game/GalaxySystem.gd`
- 创建：`data/galaxy.json`
- 重写：`scenes/ui/GalaxyMap.gd`
- 创建：`scripts/test/TestGalaxyLogistics.gd`
- 创建：`scenes/test/TestGalaxyLogistics.tscn`
- 修改：`scripts/game/GameState.gd`
- 修改：`scenes/main/Main.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写行星隔离失败测试**

在两颗行星放置相同 ID 前缀的建筑和库存，切换活动行星后证明画布、库存、连接和相机状态互不混合。

- [x] **步骤 2：定义星区与行星状态**

每局保存星区种子或固定原创目录、活动行星、已探索/殖民集合、每行星工厂和资源储量。内部 ID 不依赖显示名称。

- [x] **步骤 3：实现矿产与殖民**

矿机只能绑定合法资源点；殖民先原子验证材料、科技和载具，再创建目标行星初始状态。

- [x] **步骤 4：实现星图工作区**

提供恒星系→行星导航、资源、距离、殖民成本、工业摘要、搜索和返回恢复。

- [x] **步骤 5：迁移当前单工厂档**

旧档的建筑、连接、库存和进度完整迁入母星；迁移前后摘要除新容器结构外保持等价。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/PlanetSystem.gd scripts/game/GalaxySystem.gd data/galaxy.json scenes/ui/GalaxyMap.gd scripts/game/GameState.gd scenes/main/Main.gd scripts/test/TestGalaxyLogistics.gd scenes/test/TestGalaxyLogistics.tscn tools/run_tests.ps1
git commit -m "feat: add isolated planetary factories"
```

**完成记录（2026-09-04）：** 任务 12 已交付 schema v6：固定原创星图目录包含 3 个恒星系和 6 颗行星，活动行星是唯一权威值，每颗已殖民行星独立持有库存、建筑、线路、资源储量和相机；有限资源点会在采集时耗尽，非活动行星工厂继续由固定 tick 后台模拟。正式 `GalaxyMap` 已进入 Main，支持搜索、恒星系/行星摘要、勘探、殖民和行星切换；旧 v5 单工厂存档无损迁入母星。当前精简目录已补齐熔炉钛合金配方和基础处理器手工配方，从正式新游戏母星矿产到物流运输机、随身编队及气态巨星殖民形成守恒闭环。`TestGalaxyLogistics` 成为第十个严格 runner 场景，门禁验证每个成功标记恰好一次、失败标记、Godot 退出码、脚本/解析错误及 ObjectDB/资源泄漏。任务 13 的行星与星际物流尚未实现；账号、云存档、排行榜、在线社交和服务器运维继续排除。

### 任务 13：行星与星际物流站

**文件：**

- 重写：`scripts/game/StationSystem.gd`
- 重写：`scripts/game/LogisticsSystem.gd`
- 重写：`scenes/ui/StationPanel.gd`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/test/TestGalaxyLogistics.gd`

- [x] **步骤 1：写货物所有权失败测试**

覆盖供应/需求槽、载具占用、派遣、在途、送达、返航、断电、目标满、缺翘曲器和保存加载。任何时刻总货物保持守恒。

- [x] **步骤 2：实现行星内调度**

物流站槽位支持物品、供需模式、容量、最低装载和优先级；多供应源使用稳定公平游标。

- [x] **步骤 3：实现星际调度**

距离决定航程；跨星系需要科技、运输船和翘曲器。每条路线持久化唯一载具所有者和在途货物。

- [x] **步骤 4：实现诊断和配置 UI**

明确区分库存不足、无载具、断电、无翘曲器、容量不足和无合法 peer；批量配置复用单站校验。

- [x] **步骤 5：加入长期性能夹具**

建立 10/50/100 站状态摘要基准；任何索引优化前后摘要完全一致。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/StationSystem.gd scripts/game/LogisticsSystem.gd scenes/ui/StationPanel.gd scripts/game/SimulationEngine.gd scripts/game/GameState.gd scripts/test/TestGalaxyLogistics.gd
git commit -m "feat: add conserved interplanetary logistics"
```

**停止门：** 玩家能从母星建立跨行星材料链，完成至少一条需要星际物流的科技/任务；保存加载后在途货物和载具归属不变。

---

## 阶段 5：戴森工程、离线与终局

### 任务 14：戴森云与戴森球

**文件：**

- 重写：`scripts/game/DysonSphereSystem.gd`
- 重写：`scenes/ui/DysonUI.gd`
- 创建：`data/dyson.json`
- 创建：`scripts/test/TestDysonEndgame.gd`
- 创建：`scenes/test/TestDysonEndgame.tscn`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scripts/game/PowerSystem.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写轨道和材料守恒失败测试**

覆盖太阳帆发射、寿命衰减、轨道选择、火箭、结构点、壳面吸附、射线接收和保存加载。

- [x] **步骤 2：实现每恒星系独立戴森状态**

太阳帆、火箭、壳面和发电都归属具体恒星系；切换视图不改变模拟归属。

- [x] **步骤 3：接入生产和电力**

弹射器、发射井和接收站遵循配方、电力、科技和目标轨道；戴森功率进入所在恒星系电网。

- [x] **步骤 4：实现戴森规划工作区**

支持轨道、层、节点/壳面计划、材料缺口、功率预估和合法失败反馈。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/DysonSphereSystem.gd scenes/ui/DysonUI.gd data/dyson.json scripts/game/SimulationEngine.gd scripts/game/PowerSystem.gd scripts/test/TestDysonEndgame.gd scenes/test/TestDysonEndgame.tscn tools/run_tests.ps1
git commit -m "feat: add deterministic dyson engineering"
```

### 任务 15：终局目标和胜利状态

**文件：**

- 创建：`scripts/game/EndgameSystem.gd`
- 创建：`scenes/ui/EndgameWorkspace.gd`
- 修改：`data/progression.json`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/test/TestDysonEndgame.gd`

- [x] **步骤 1：写终局状态机失败测试**

覆盖白矩阵、戴森功率、巨构材料、启动确认、进度、完成一次性奖励、胜利后继续游玩和保存加载。

- [x] **步骤 2：定义明确单机胜利条件**

胜利必须由可验证领域事实构成，不依赖联网排名或全服进度。终局前提供清晰缺口列表和生产定位。

- [x] **步骤 3：实现终局工作区**

显示阶段、材料、功率、速率、预计时间和阻塞原因；危险销毁/时间扭曲操作使用明确确认。

- [x] **步骤 4：提交**

```powershell
git add scripts/game/EndgameSystem.gd scenes/ui/EndgameWorkspace.gd data/progression.json scripts/game/GameState.gd scripts/test/TestDysonEndgame.gd
git commit -m "feat: add single player endgame victory"
```

### 任务 16：安全离线结算与离线报告

**文件：**

- 创建：`scripts/game/OfflineSettlementSystem.gd`
- 创建：`scripts/game/OfflineSettlementJournal.gd`
- 创建：`scenes/ui/OfflineReportWorkspace.gd`
- 创建：`scripts/test/TestOfflineSettlement.gd`
- 创建：`scenes/test/TestOfflineSettlement.tscn`
- 修改：`scripts/game/SaveSystem.gd`
- 修改：`autoload/GameManager.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：写重复结算失败测试**

覆盖短离线、长离线、设备阻塞、科技完成边界、戴森衰减、在途物流、系统时间回拨、崩溃中断和同一时间段只结算一次。

- [x] **步骤 2：先实现分段精确结算**

复用固定步长模拟，按关键边界分段。第一版设置保守离线上限，不在没有等价性证明时引入近似算法。

- [x] **步骤 3：加入结算 journal**

结算前保存起点、目标时间和状态摘要；完成后原子提交新档。中断后回到已验证边界，不重复发放。

- [x] **步骤 4：实现离线报告**

显示真实离线时长、模拟时长、主要产出、科技/任务完成、阻塞和被限制原因；允许玩家放弃未提交的长结算。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/OfflineSettlementSystem.gd scripts/game/OfflineSettlementJournal.gd scenes/ui/OfflineReportWorkspace.gd scripts/game/SaveSystem.gd autoload/GameManager.gd scripts/test/TestOfflineSettlement.gd scenes/test/TestOfflineSettlement.tscn tools/run_tests.ps1
git commit -m "feat: add recoverable offline settlement"
```

**核心终局门：** 新游戏 → 多行星工业 → 戴森工程 → 单机胜利可以完整游玩；保存、退出、离线和恢复不破坏资源守恒或重复进度。

---

## 阶段 6：产品化与大型工厂

### 任务 17：设置、主题和桌面输入

**范围修订：** 用户明确取消国际化和手机适配；保留中文，操作逻辑按电脑游戏。窗口缩放和大字号使用桌面布局，不增加触摸抽屉、底部导航或手势。

**文件：**

- 创建：`scripts/game/SettingsSystem.gd`
- 创建：`scenes/ui/SettingsWorkspace.gd`、`DeviceUI.gd`、`AdaptivePanel.gd`、`DesktopLayout.gd`
- 创建：`scripts/test/TestProductShell.gd`、`scenes/test/TestProductShell.tscn`
- 修改：`project.godot`、正式 Main、AppShell、工作区与 `scripts/input/InputHandler.gd`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：设备偏好隔离**

主题、字号、UI 密度、滚轮方向和手柄光标速度仅存设备文件，不进入 GameState；切换存档不改变偏好，保存失败保留当前值。

- [x] **步骤 2：国际化已按用户要求取消**

继续使用现有中文，不添加语言设置或翻译目录。

- [x] **步骤 3：亮/暗主题与 80%～200% 字号**

共用主题覆盖动态控件；桌面侧栏和工作区可滚动，焦点有明确边框。最小桌面窗口 1000×600；按当前可用分辨率实时调整比例和布局，覆盖 1080p、1440p、4K、宽屏与窗口尺寸往返变化。

- [x] **步骤 4：键盘和手柄桌面操作**

保留鼠标与既有快捷键；F6 / 手柄 Y 切换画布焦点，光标支持选择、放置、移动、连线及缩放。菜单、工作区有返回路径，删除仍需确认。

- [x] **步骤 5：手机/触摸适配已按用户要求取消**

保留电脑端顶栏、左右侧栏与建造坞，不实现移动布局或触摸手势。

- [x] **步骤 6：提交本地 main**

```powershell
git commit -m "feat: add accessible local game settings"
```

### 任务 18：大型工厂性能与稳定性预算

**文件：**

- 重写：`scripts/game/PerformanceSystem.gd`
- 修改：`scripts/utils/SpatialIndex.gd`
- 修改：`scripts/rendering/CardRenderer.gd`
- 修改：`scripts/rendering/ConnectionRenderer.gd`
- 创建：`scripts/test/TestPerformanceBudgets.gd`
- 创建：`scenes/test/TestPerformanceBudgets.tscn`
- 创建：`tests/fixtures/README.md`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：建立合成存档夹具**

至少覆盖小型、中型和大型工厂；夹具不含玩家数据，生成规则固定，记录实体、线路和物流站规模。

- [x] **步骤 2：建立状态等价基线**

任何空间索引、批处理、LOD 或休眠优化都必须与朴素路径比较持久摘要；不等价即失败。

- [x] **步骤 3：优化画布**

引入视口裁剪、LOD、线路批绘和命中空间索引；选中、拖动、连接源/目标必须强制保持交互精度。

- [x] **步骤 4：优化模拟**

只缓存可重建索引和稳定查询；拓扑、供电、配方、库存或容量变化时使相关缓存失效。

- [x] **步骤 5：定义预算**

把引擎至测试场景就绪时间、固定 tick、画布更新、存档大小与保存/加载时间记录为本机基线。提供默认关闭的运行时监测和 JSON / Markdown 报告，采用有界采样；趋势工具拒绝不匹配环境，不伪造跨机器绝对 FPS 承诺。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/PerformanceSystem.gd scripts/utils/SpatialIndex.gd scripts/rendering/CardRenderer.gd scripts/rendering/ConnectionRenderer.gd scripts/test/TestPerformanceBudgets.gd scenes/test/TestPerformanceBudgets.tscn tests/fixtures/README.md tools/run_tests.ps1
git commit -m "perf: add deterministic large factory budgets"
```

**完成记录（2026-09-08）：** 已交付三档固定工厂、状态等价/存档往返门禁、设置页监测开关和双格式报告；优化传送带排序查询、空间命中、视口裁剪和 LOD 批绘。本机报告与限制见 [任务 18 验收](TASK18_ACCEPTANCE.md)。十四场景门禁和独立 OpenGL 基准通过；大型工厂仍有固定步超预算，未承诺 60 FPS。

---

## 阶段 7：DSPONLINE 完整单机功能与内容复刻

本阶段以任务 19 冻结的 DSPONLINE 单机基线为验收依据。要求功能、内容、数值规则和玩家可执行操作一致；Godot 内部架构、控件和存档格式可以不同。账号、云存档、排行榜、在线社交、在线合同、服务器和 DSPONLINE 旧存档导入继续排除。

### 任务 19：冻结 DSPONLINE 单机对齐基线

**文件：**

- 创建：`docs/CONTENT_PARITY.md`
- 创建：`tests/fixtures/parity/dsponline_single_player_manifest.json`
- 创建：`tools/check_dsponline_parity.ps1`
- 创建：`scripts/test/TestDSPOnlineParity.gd`
- 创建：`scenes/test/TestDSPOnlineParity.tscn`
- 修改：`tools/run_tests.ps1`

- [x] **步骤 1：从 DSPONLINE 当前代码冻结单机目录**

记录全部物品、配方、建筑、科技、战役任务、成就、难度、研究矩阵、传送带等级、单机工作区和可执行命令。冻结提交 472bf62 的实际数量为 78 个物品、80 条配方、39 类建筑、69 项有效科技（另有 7 项弃用保留定义）、32 个战役任务和 13 项成就；源版本及文件哈希记录在 fixture 中。

- [x] **步骤 2：建立逐项功能矩阵**

`docs/CONTENT_PARITY.md` 对每个条目记录 DSPONLINE 稳定 ID、名称、输入输出、数值、前置、解锁、运行规则、UI 入口、CardFactory 对应 ID、自动测试和人工验收编号。状态只能是“未实现/实现中/已验证/在线排除”，不得使用“类似实现”代替验证。

- [x] **步骤 3：建立自动差距门**

`check_dsponline_parity.ps1` 校验冻结 manifest 的条目在 CardFactory 数据目录中均有显式映射，且不存在未解释缺失；`TestDSPOnlineParity` 读取同一 manifest，拒绝无逐项规则验收规格的内容条目。登记门允许有明确承接任务的缺口；发布模式必须有实际行为验证，不允许以 pending 规格冒充已通过。在线排除项使用固定白名单并写明原因。

- [x] **步骤 4：把对齐门加入统一 runner**

在 `tools/run_tests.ps1` 中加入唯一成功标记；缺少冻结 fixture、映射、规则测试或出现未登记排除项时全量门失败。

- [x] **步骤 5：提交**

```powershell
git add docs/CONTENT_PARITY.md tests/fixtures/parity tools/check_dsponline_parity.ps1 scripts/test/TestDSPOnlineParity.gd scenes/test/TestDSPOnlineParity.tscn tools/run_tests.ps1
git commit -m "test: freeze DSPONLINE single player parity baseline"
```

**完成记录（2026-09-08）：** 已冻结源目录与桌面操作契约，生成逐项矩阵、固定排除与规则规格，接入十五场景门禁；登记门通过，完整发布模式按预期拒绝待实现项。详见 [任务 19 验收](TASK19_ACCEPTANCE.md)。本轮未开始任务 20。

### 后续任务执行约定（任务 19 复核，2026-09-09）

顺序保持 20 → 21 → 22 → 23 → 24 → 25 → 26 → 27。每项先核实候选映射，区分已有能力待验证、行为不一致和真正缺失；“未实现”登记数量不能直接当开发工作量。任务归属表示主责，跨系统行为仍需关联验证。

任务 20 先保证保存协调与恢复；后续每次新增状态同时补 codec、迁移和保存往返，保留 schema v9 旧档与待提交离线结算的兼容证据。任务 22 的科技引用先完成目录一致性检查，任务 25 再对齐完整研究效果，任务 26 复核特殊系统中的效果，避免循环依赖阻塞。

任务 20～26 每批同步补真实行为夹具、更新矩阵和运行对应门禁，不把全部行为验证推迟到任务 27。任务 27 负责全覆盖与完整旅程收口。各批保留任务 18 同场景、同设备的性能差分；新增规模单独版本化基线，不与不同输入混比，也不承诺已达到 60 FPS。文件列表是实施入口，优先扩展当前活跃系统，避免另建同义系统。

### 任务 20：对齐本地存档控制与恢复体验

**文件：**

- 修改：`scripts/game/SaveSystem.gd`
- 修改：`autoload/GameManager.gd`
- 修改：`scenes/ui/AppShell.gd`
- 创建：`scenes/ui/RecoveryWorkspace.gd`
- 复用验证：`scripts/test/TestStatePersistence.gd`
- 创建：`scripts/test/TestSaveRecovery.gd` 与对应测试场景
- 修改：`scripts/game/OfflineSettlementSystem.gd`、`scenes/main/Main.gd` 和保存相关界面
- 修改：`scripts/test/TestProductShell.gd`

- [x] **步骤 1：写手动保存和恢复失败测试**

覆盖立即保存、自动保存间隔、返回/退出保存、写入冲突、最近有效主档、备份、紧急恢复点、恢复来源提示和恢复后再次保存。任何失败不得替换当前权威状态或删除最后一份有效恢复点。

- [x] **步骤 2：实现统一保存协调器**

手动、自动、生命周期和离线结算只提交同一串行保存队列；相同状态请求合并，不同状态按权威修订号排序。完成写入、读回和摘要校验后才更新“已保存”状态。

- [x] **步骤 3：实现恢复工作区**

开始菜单显示主档、备份和紧急恢复点的时间、游玩时长、版本与校验状态，允许玩家选择恢复来源；不提供 DSPONLINE 存档导入。

- [x] **步骤 4：接入正式 UI**

顶栏和暂停菜单提供“立即保存”，显示保存中、成功、失败和只读原因；桌面键鼠和已有手柄入口均能完成同一操作。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/SaveSystem.gd autoload/GameManager.gd scenes/ui/AppShell.gd scenes/ui/RecoveryWorkspace.gd scripts/test/TestStatePersistence.gd scripts/test/TestProductShell.gd
git commit -m "feat: match local save and recovery controls"
```

**完成记录（2026-09-09）：** 保存协调、来源检查/选择、紧急恢复和手动快照管理及桌面入口已交付；十六场景门禁通过，图形验证范围见 [任务 20 验收](TASK20_ACCEPTANCE.md)。源项目特有高级策略仍按矩阵逐项核对，不将本轮交付等同于完整发布对齐。

### 任务 21：对齐多电网、优先级与储能

**文件：**

- 重写：`scripts/game/PowerSystem.gd`
- 创建：`scripts/game/PowerGridSystem.gd`
- 修改：`scripts/game/GameState.gd`
- 修改：`scripts/game/GameStateCodec.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scripts/test/TestSimulationCore.gd`

- [x] **步骤 1：写电网隔离和能量守恒失败测试**

覆盖同一行星多个电网、覆盖丢失、建筑换网、发电优先级、用电优先级、蓄电池充放电、能量枢纽、断电、满储能、空储能和保存加载。每个固定 tick 的发电、消耗、充电、放电和损耗必须守恒。

- [x] **步骤 2：实现稳定电网归属**

电网使用稳定 ID；每个建筑持久化电网、用电优先级，发电设备另存发电优先级。覆盖变化只重建可派生索引，不隐式搬运库存或重置生产进度。

- [ ] **步骤 3：实现分级供电和储能调度**

按 DSPONLINE 冻结基线的优先级、容量、充放电功率和待机规则分配能源；可再生、燃料、戴森功率和储能遵循相同数值顺序。

- [x] **步骤 4：对齐检查器与反馈**

建筑检查器可修改电网和优先级，显示需求、获得功率、覆盖、储能水平和阻塞原因；批量修改先完整预检再原子提交。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/PowerSystem.gd scripts/game/PowerGridSystem.gd scripts/game/GameState.gd scripts/game/GameStateCodec.gd scenes/ui/FactoryWorkspaceUI.gd scripts/test/TestSimulationCore.gd
git commit -m "feat: match DSPONLINE power grids and storage"
```

**本轮记录（2026-09-10）：** 电网、分级调度、储能和桌面配置核心已实现，十七场景门禁及 OpenGL 产品界面门通过；本轮提交本地 main，不推送。步骤 3 的完整源待机/动态需求及多燃料规则依赖任务 22 的目录，暂不勾为完全对齐；任务 22 必须接续，见 [验收边界](TASK21_ACCEPTANCE.md)。

### 任务 22：对齐完整生产目录、递归制造与喷涂

2026-09-13：本轮生产/制造实现与门禁完成，详见 [验收](TASK22_ACCEPTANCE.md)。目录包含后续任务的高级设备；其专用运行与源行为金标继续按任务 24～27 接续，不据此标记全部玩法完成。

**文件：**

- 修改：`data/*.json`
- 创建：`scripts/game/CraftingPlanner.gd`
- 创建：`scripts/game/ConstructionAutomationSystem.gd`
- 创建：`scripts/game/ProliferatorSystem.gd`
- 修改：`scripts/game/ProductionSystem.gd`
- 修改：`scripts/game/HandcraftSystem.gd`
- 修改：`autoload/DataManager.gd`
- 创建：`scripts/test/TestContentParity.gd`
- 创建：`scenes/test/TestContentParity.tscn`

- [x] **步骤 1：写目录和规则差距测试**

逐项断言冻结 manifest 中全部物品、配方和建筑都有对应数据、设备约束、科技前置、输入输出、时间、功率、缓存和施工成本；缺一项即失败。

- [x] **步骤 2：迁移完整单机目录**

把 DSPONLINE 冻结基线的 78 个物品、80 条配方和 39 类建筑及其数值迁入 Godot 数据文件，保留稳定映射并接入正式建造、生产和资料库入口。所有源项目后续新增内容必须通过新的基线更新进入，不静默改变本阶段目标。

- [x] **步骤 3：实现递归材料规划**

从目标数量构建完整无环依赖图，按已解锁配方优先级选择路线；输入不足、输出容量不足、副产物堵塞或配方锁定时返回确定缺口。确认后一次性保留材料，失败不产生半成品状态。

- [x] **步骤 4：实现建筑制造中心和自动补货**

持续目标库存、阶段 WIP、缺料、预计时间、暂停和保存恢复均进入权威状态；物流载具和复杂建筑可以一键递归制造。

- [x] **步骤 5：实现三级喷涂规则**

按冻结基线实现喷涂点、额外产物、加速、功耗倍率、配方资格和拆卸返还；生产、科研、统计、蓝图和保存共用同一规则源。

- [x] **步骤 6：提交**

```powershell
git add data scripts/game/CraftingPlanner.gd scripts/game/ConstructionAutomationSystem.gd scripts/game/ProliferatorSystem.gd scripts/game/ProductionSystem.gd scripts/game/HandcraftSystem.gd autoload/DataManager.gd scripts/test/TestContentParity.gd scenes/test/TestContentParity.tscn
git commit -m "feat: match DSPONLINE production content and crafting"
```

### 任务 23：对齐画布历史、自动布局与高效命令

2026-09-14：本轮实现及 19 场景/1080p 门禁通过，见 [任务 23 验收](TASK23_ACCEPTANCE.md)。

**文件：**

- 创建：`scripts/game/CommandHistory.gd`
- 创建：`scripts/game/FactoryAutoLayout.gd`
- 创建：`scenes/ui/CommandPalette.gd`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`
- 修改：`scripts/game/BeltSystem.gd`
- 修改：`scripts/test/TestAdvancedCanvas.gd`

- [x] **步骤 1：写可逆命令和批量交互失败测试**

覆盖建造、移动、删除、连接、线路配置、配方修改、自动布局的撤销/重做；覆盖连续拉线候选、确认、撤销最近候选和取消。历史操作前后资源、稳定 ID、在途货物和累计统计必须守恒。

- [x] **步骤 2：实现会话命令历史**

所有玩家画布修改封装为可验证命令，保存提交前后摘要；`Ctrl+Z`、`Ctrl+Shift+Z` 和 UI 按钮共享同一历史。加载、新游戏和明确清空历史不会修改 GameState。

- [x] **步骤 3：实现确定性自动布局**

按生产拓扑、稳定 ID 和卡片尺寸生成布局，保留锁定建筑并避免重叠；自动布局作为单一可撤销命令提交。

- [x] **步骤 4：实现命令面板和连续拉线**

命令面板提供工作区导航、建造、实体定位和批量命令；连续拉线支持候选预览、兼容性原因、确认和取消，不允许 UI 释放穿透。

- [x] **步骤 5：对齐线路规模与批量配置**

把并联上限、直接输入、增减、整网同步、批量减堆和施工库存扣除对齐冻结基线；扩大上限不能改变既有线路设置或在途货物。

- [x] **步骤 6：提交**

```powershell
git add scripts/game/CommandHistory.gd scripts/game/FactoryAutoLayout.gd scenes/ui/CommandPalette.gd scripts/input/InputHandler.gd scenes/ui/FactoryWorkspaceUI.gd scripts/game/BeltSystem.gd scripts/test/TestAdvancedCanvas.gd
git commit -m "feat: match DSPONLINE factory editing workflow"
```

### 任务 24：对齐持久蓝图库、施工队列与导航标记

**文件：**

- 修改：`scripts/game/BlueprintSystem.gd`
- 修改：`scripts/game/BlueprintCodec.gd`
- 创建：`scripts/game/ConstructionQueueSystem.gd`
- 修改：`scripts/game/GameState.gd`
- 重写：`scenes/ui/BlueprintWorkspace.gd`
- 修改：`scenes/ui/MiniMap.gd`
- 修改：`scripts/test/TestBlueprints.gd`

- [x] **步骤 1：写蓝图库持久化和施工队列失败测试**

覆盖命名、重命名、删除、旋转、镜像、配方替换、导入导出、排队部署、部分资助、全部资助、取消、重叠策略、载具目标和保存加载。

- [x] **步骤 2：把蓝图库迁入权威状态**

蓝图定义、变换和配方替换持久化；运行缓存、临时进度、选中态和来源建筑稳定 ID 不复制。导入继续使用受限格式和完整引用校验。

- [x] **步骤 3：实现待建与补足队列**

部署可选择立即原子完成或生成灰模队列；材料、建筑、线路和载具逐项资助并保持唯一所有权，取消按真实未消耗数量返还。

- [x] **步骤 4：持久化区域和书签**

区域名称、矩形、颜色和书签视口进入 GameState；支持重命名、调整、删除、跨行星导航和保存加载，数量上限与冻结基线一致。

- [x] **步骤 5：提交**

```powershell
git add scripts/game/BlueprintSystem.gd scripts/game/BlueprintCodec.gd scripts/game/ConstructionQueueSystem.gd scripts/game/GameState.gd scenes/ui/BlueprintWorkspace.gd scenes/ui/MiniMap.gd scripts/test/TestBlueprints.gd
git commit -m "feat: match DSPONLINE blueprint and navigation persistence"
```

**完成记录（2026-09-21）：** 持久蓝图库、部分预留/退款、载具补足、精确复用及区域/书签桌面入口已交付；20 场景门禁和 1080p 图形门通过，受限格式及后续配置边界见 [任务 24 验收](TASK24_ACCEPTANCE.md)。

### 任务 25：对齐科技、战役、成就和完整内容推进

**文件：**

- 修改：`data/technologies.json`
- 修改：`data/progression.json`
- 修改：`scripts/game/TechnologySystem.gd`
- 修改：`scripts/game/ProgressionSystem.gd`
- 修改：`scenes/ui/TechnologyPanel.gd`
- 修改：`scenes/ui/CampaignWorkspace.gd`
- 修改：`scripts/test/TestProgression.gd`

- [ ] **步骤 1：写完整推进目录失败测试**

断言冻结基线全部有限/无限科技、战役任务和成就均有稳定映射、真实领域条件、矩阵成本、前置、效果、导航和奖励；UI 点击本身不得完成目标。

- [ ] **步骤 2：对齐 69 项有效科技、7 项弃用定义处理和完整矩阵层级**

对齐电磁、能量、结构、信息、引力和宇宙矩阵成本，接入生产、采矿、物流、电力、储量利用、建筑和无限研究效果。队列、暂停、取消、层数、投入和保存规则继续保持原子。

- [ ] **步骤 3：迁移 32 个战役任务和 13 项成就**

覆盖基础工业、六色矩阵、行星/星际物流、稀有资源、喷涂、蓝图、戴森工程和银河终局；旧 CardFactory 存档依据已有领域事实补齐进度，不重复发放奖励。

- [ ] **步骤 4：对齐工作区操作**

科技和战役工作区提供冻结基线中的搜索、筛选、层级导航、任务选择、缺口、定位、奖励和无限研究操作；桌面键鼠和已有手柄入口等价。

- [ ] **步骤 5：提交**

```powershell
git add data/technologies.json data/progression.json scripts/game/TechnologySystem.gd scripts/game/ProgressionSystem.gd scenes/ui/TechnologyPanel.gd scenes/ui/CampaignWorkspace.gd scripts/test/TestProgression.gd
git commit -m "feat: match DSPONLINE technology and progression content"
```

### 任务 26：对齐单机模式、本地空间站与剩余特殊规则

**文件：**

- 创建：`scripts/game/GameModeSystem.gd`
- 创建：`scripts/game/LocalSpaceStationSystem.gd`
- 创建：`scenes/ui/LocalSpaceStationWorkspace.gd`
- 修改：`scripts/game/EndgameSystem.gd`
- 修改：`scripts/game/SimulationEngine.gd`
- 修改：`scenes/ui/StartMenu.gd`
- 创建：`scripts/test/TestSinglePlayerModes.gd`
- 创建：`scenes/test/TestSinglePlayerModes.tscn`

- [ ] **步骤 1：写模式隔离和特殊规则失败测试**

覆盖冻结基线中的难度、速通、时间扭曲、纯挂机/宏观推进、本地空间站、银河出口和无限科研目标。模式创建后不可通过加载或 UI 操作绕过规则，模式间存档和成就互不污染。

- [ ] **步骤 2：实现难度、速通和时间扭曲**

对齐生产、采矿、物流、功耗、计时、暂停和时间扭曲功率限制；时间扭曲只改变规定的模拟领域，不重复累计游玩时间或离线结算。

- [ ] **步骤 3：实现本地空间站和银河项目**

每档唯一空间站、建设阶段、材料守恒、本地合同、银河出口和长期目标进入权威状态；公共主页、玩家信号和服务器同步不进入代码路径。

- [ ] **步骤 4：清零冻结 manifest 的特殊规则差距**

按以下批次处理冻结清单，每批先核实已有实现，再补差和验证：

- 26A：标准、速通、时间扭曲、纯挂机及难度规则。
- 26B：本地空间站、银河工业/出口与项目，以及星图、资源储量和戴森工程的剩余差异。
- 26C：站点槽位、舰队和翘曲器配置、量子物流挂接与容量、轨道采集器及黑洞特殊规则；复用既有物流和电力系统。
- 26D：本地内容包的注册、校验、依赖和启停操作；只承接源清单中的离线能力。

每批须有具体领域测试、正式 UI 入口和必要的持久化往返；查询/展示项验证派生值，不强行新增持久状态。不得把普通线路 Mode 或电力 Snapshot 归入特殊玩法。科技效果由任务 25 实现，本任务验证模式和特殊系统中的集成。

- [ ] **步骤 5：提交**

```powershell
git add scripts/game/GameModeSystem.gd scripts/game/LocalSpaceStationSystem.gd scenes/ui/LocalSpaceStationWorkspace.gd scripts/game/EndgameSystem.gd scripts/game/SimulationEngine.gd scenes/ui/StartMenu.gd scripts/test/TestSinglePlayerModes.gd scenes/test/TestSinglePlayerModes.tscn
git commit -m "feat: match remaining DSPONLINE single player modes"
```

### 任务 27：逐项对齐验收与单机发布门

**文件：**

- 创建：`docs/testing/dsponline-parity-checklist.md`
- 创建：`docs/testing/single-player-release-checklist.md`
- 创建：`tests/fixtures/parity/behavior/`
- 修改：`docs/CONTENT_PARITY.md`
- 修改：`README.md`
- 修改：`docs/PROJECT_STATUS.md`
- 修改：本计划复选框

- [ ] **步骤 1：建立跨实现行为金标**

汇总并补齐任务 20～26 随功能建立的行为金标。从冻结 DSPONLINE 基线导出不含账号和玩家数据的确定性输入/输出夹具，CardFactory 对相同初始目录、命令序列和模拟时间验证库存、产量、研究、物流、电力、戴森、任务和终局结果。Godot 内部字段可不同，玩家可见数值和资源守恒结果必须一致。

- [ ] **步骤 2：清零内容矩阵**

`docs/CONTENT_PARITY.md` 中所有非在线条目必须为“已验证”，并链接自动测试或人工验收编号；任何“未实现/实现中”都阻止发布。

- [ ] **步骤 3：执行完整人工旅程**

分别完成标准、难度、速通、时间扭曲和纯挂机的适用旅程；以电脑键鼠操作验收，并检查窗口缩放、常见桌面分辨率和大字号：新游戏、六色矩阵、蓝图、科技、多行星、星际物流、戴森、离线、终局、空间站、保存恢复及损坏档处理。逐项核对 DSPONLINE 对应入口、反馈和数值。

- [ ] **步骤 4：验证本地导出**

Windows 单机包必须通过完整旅程；不设置 Android 或手机触摸验收。导出包不得包含账号、云、排行榜或服务器入口。

- [ ] **步骤 5：最终审查**

使用 `requesting-code-review` 检查状态守恒、CardFactory 存档兼容、输入穿透、错误反馈、性能差分、冻结基线覆盖和文档真实性。修复所有高置信度问题后重跑全程质量门与行为金标。

- [ ] **步骤 6：更新权威文档并提交**

```powershell
git add README.md docs/PROJECT_STATUS.md docs/CONTENT_PARITY.md docs/testing tests/fixtures/parity docs/current/SINGLE_PLAYER_ROADMAP.md
git commit -m "docs: verify complete DSPONLINE single player parity"
```

---

## 阶段交付检查点

| 检查点 | 可玩的新增结果 | 禁止进入下一阶段的条件 |
|---|---|---|
| 阶段 0 | 可新建、保存、退出、恢复同一工厂 | schema/Vector2 往返、损坏档处理或测试自引导失败 |
| 阶段 1 | 有真实库存、电力和完整基础科学链 | 资源不守恒、结果依赖帧率、供电不影响生产 |
| 阶段 2 | 可高效编辑大型单行星工厂并使用蓝图 | 批量/蓝图失败会部分扣料或留下半状态 |
| 阶段 3 | 教程、科技和分析形成正式推进 | 任务靠 UI 点击、科技效果未进入模拟、诊断不可信 |
| 阶段 4 | 多行星和星际物流形成跨星生产链 | 行星状态混合、货物/载具归属不唯一、迁移丢数据 |
| 阶段 5 | 戴森工程和单机终局完整，离线可恢复 | 离线重复结算、戴森状态跨星混合、胜利依赖联网 |
| 阶段 6 | 设置、平台适配和大型工厂性能证据齐全 | 大工厂优化改变状态、核心 UI 重叠或存档不可恢复 |
| 阶段 7 | DSPONLINE 单机功能、内容、数值规则和操作逐项通过对齐门 | 冻结 manifest 有任何非在线差距、行为金标不一致或完整旅程未通过 |

## 文档维护规则

- 本计划是程序级路线图；每个阶段开始前可以创建更细的阶段计划，但不得改变本文件的范围边界和停止门，除非先更新设计规格并获得用户批准。
- 每完成一步勾选对应复选框；不能按“已有类似函数”提前勾选。
- 新发现差距先加入 `docs/CONTENT_PARITY.md`；Stage 7 完成前所有非在线差距都必须落实到任务 20～26 并通过任务 27 验收。
- 在线功能需求若未来重新进入范围，必须新建设计规格和独立计划，不能悄悄加入本单机路线。
