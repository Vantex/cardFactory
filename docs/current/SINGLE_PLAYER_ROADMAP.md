# CardFactory 对齐 DSPONLINE 单机玩法实施计划

> **执行要求：** 后续会话使用 `executing-plans` 或 `subagent-driven-development` 技能按任务实施。每项功能先写失败测试，再做最小实现；每完成一个任务都运行本任务门和全量门，并形成可回滚提交。

**目标：** 在 Godot 4 中把 CardFactory 建设为完整的离线单机工厂游戏，覆盖可靠存档、确定性生产、电力、物流、科技、多行星、戴森工程、离线结算和终局；不实现账号、云存档、排行榜、在线社交或服务器运维。

**设计依据：** `docs/current/SINGLE_PLAYER_GAP_ANALYSIS.md`

**架构方向：** 保留当前 `Main + GameManager + GameState + SimulationEngine` 主干，但先建立版本化状态、codec、迁移和固定步长。领域系统只接受权威 GameState，通过原子命令修改状态；UI 只发送意图和展示结果。各阶段必须交付一个从正式入口可触发的纵向闭环。

**技术栈：** Godot 4.7、GDScript、Node2D/Camera2D、Control/CanvasLayer、JSON 本地存档、PowerShell 测试门。

---

## 范围边界

### 本计划包含

- 完整单机工厂、科技、星图、物流、戴森和终局循环。
- 本地存档、备份、自动保存、离线结算和崩溃后安全恢复。
- 蓝图、统计、资料库、设置、移动/手柄/无障碍和本地导出。
- 纯本地空间站扩展作为核心终局后的可选阶段。

### 本计划明确排除

- 账号、邮箱、云存档、云冲突、排行榜、在线活动、遥测。
- 公共空间站主页、玩家社交、在线合同和服务器同步。
- Node/SQLite 服务端、部署、备份、运营后台、PWA/Electron/Capacitor 实现。

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

创建物品、配方、建筑、科技和解锁映射表。DSPONLINE 的 78/78/37/67 用于覆盖度检查，不复制其名字、素材或源码；CardFactory 可使用原创命名和视觉。

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

- [ ] **步骤 1：写终局状态机失败测试**

覆盖白矩阵、戴森功率、巨构材料、启动确认、进度、完成一次性奖励、胜利后继续游玩和保存加载。

- [ ] **步骤 2：定义明确单机胜利条件**

胜利必须由可验证领域事实构成，不依赖联网排名或全服进度。终局前提供清晰缺口列表和生产定位。

- [ ] **步骤 3：实现终局工作区**

显示阶段、材料、功率、速率、预计时间和阻塞原因；危险销毁/时间扭曲操作使用明确确认。

- [ ] **步骤 4：提交**

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

- [ ] **步骤 1：写重复结算失败测试**

覆盖短离线、长离线、设备阻塞、科技完成边界、戴森衰减、在途物流、系统时间回拨、崩溃中断和同一时间段只结算一次。

- [ ] **步骤 2：先实现分段精确结算**

复用固定步长模拟，按关键边界分段。第一版设置保守离线上限，不在没有等价性证明时引入近似算法。

- [ ] **步骤 3：加入结算 journal**

结算前保存起点、目标时间和状态摘要；完成后原子提交新档。中断后回到已验证边界，不重复发放。

- [ ] **步骤 4：实现离线报告**

显示真实离线时长、模拟时长、主要产出、科技/任务完成、阻塞和被限制原因；允许玩家放弃未提交的长结算。

- [ ] **步骤 5：提交**

```powershell
git add scripts/game/OfflineSettlementSystem.gd scripts/game/OfflineSettlementJournal.gd scenes/ui/OfflineReportWorkspace.gd scripts/game/SaveSystem.gd autoload/GameManager.gd scripts/test/TestOfflineSettlement.gd scenes/test/TestOfflineSettlement.tscn tools/run_tests.ps1
git commit -m "feat: add recoverable offline settlement"
```

**核心终局门：** 新游戏 → 多行星工业 → 戴森工程 → 单机胜利可以完整游玩；保存、退出、离线和恢复不破坏资源守恒或重复进度。

---

## 阶段 6：产品化与大型工厂

### 任务 17：设置、国际化、主题和输入适配

**文件：**

- 创建：`scripts/game/SettingsSystem.gd`
- 创建：`scenes/ui/SettingsWorkspace.gd`
- 创建：`data/i18n/zh_CN.json`
- 创建：`data/i18n/en.json`
- 创建：`scripts/test/TestProductShell.gd`
- 创建：`scenes/test/TestProductShell.tscn`
- 修改：`project.godot`
- 修改：所有活跃 `scenes/ui/*.gd`
- 修改：`tools/run_tests.ps1`

- [ ] **步骤 1：写偏好隔离失败测试**

语言、主题、字号、UI 密度和输入偏好只保存在设备设置，不进入 GameState；切换存档不改变偏好。

- [ ] **步骤 2：抽取玩家可见文本**

正式路径不再硬编码中文；缺失翻译在测试中失败，不静默显示 key。

- [ ] **步骤 3：实现亮/暗主题和字号范围**

所有工作区在 80%～200% 字号下可滚动、无核心控件重叠；颜色不是唯一状态信号。

- [ ] **步骤 4：实现键盘和手柄导航**

菜单、工作区、对话框和画布命令都有焦点顺序、返回路径和可见焦点；破坏性操作需要确认。

- [ ] **步骤 5：实现移动/触摸布局**

窄屏使用顶部状态、底部导航和可折叠抽屉；触摸放置、拖动、连续拉线、缩放和平移与桌面共享领域命令。

- [ ] **步骤 6：提交**

```powershell
git add scripts/game/SettingsSystem.gd scenes/ui/SettingsWorkspace.gd data/i18n project.godot scenes/ui scripts/test/TestProductShell.gd scenes/test/TestProductShell.tscn tools/run_tests.ps1
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

- [ ] **步骤 1：建立合成存档夹具**

至少覆盖小型、中型和大型工厂；夹具不含玩家数据，生成规则固定，记录实体、线路和物流站规模。

- [ ] **步骤 2：建立状态等价基线**

任何空间索引、批处理、LOD 或休眠优化都必须与朴素路径比较持久摘要；不等价即失败。

- [ ] **步骤 3：优化画布**

引入视口裁剪、LOD、线路批绘和命中空间索引；选中、拖动、连接源/目标必须强制保持交互精度。

- [ ] **步骤 4：优化模拟**

只缓存可重建索引和稳定查询；拓扑、供电、配方、库存或容量变化时使相关缓存失效。

- [ ] **步骤 5：定义预算**

把启动时间、固定 tick、画布更新、存档大小与保存时间记录为本机基线。先建立趋势门，不伪造跨机器绝对 FPS 承诺。

- [ ] **步骤 6：提交**

```powershell
git add scripts/game/PerformanceSystem.gd scripts/utils/SpatialIndex.gd scripts/rendering/CardRenderer.gd scripts/rendering/ConnectionRenderer.gd scripts/test/TestPerformanceBudgets.gd scenes/test/TestPerformanceBudgets.tscn tests/fixtures/README.md tools/run_tests.ps1
git commit -m "perf: add deterministic large factory budgets"
```

### 任务 19：内容覆盖审计、可选本地空间站与单机发布门

**文件：**

- 创建：`docs/CONTENT_PARITY.md`
- 创建：`docs/testing/single-player-release-checklist.md`
- 创建（可选）：`scripts/game/LocalSpaceStationSystem.gd`
- 创建（可选）：`scenes/ui/LocalSpaceStationWorkspace.gd`
- 修改：`README.md`
- 修改：`docs/PROJECT_STATUS.md`
- 修改：本计划复选框

- [ ] **步骤 1：完成内容覆盖审计**

逐项记录 DSPONLINE 单机系统是否在 CardFactory 中“已交付/替代实现/明确不采用”。物品、配方、建筑和科技记录功能角色映射，不要求复制名称或素材。

- [ ] **步骤 2：决定本地空间站扩展**

核心终局稳定后再决定是否加入每档唯一空间站、本地合同和装饰。公共主页、收藏、玩家信号和服务器同步继续排除。

- [ ] **步骤 3：执行完整人工旅程**

按发布检查单完成：新游戏、基础工厂、保存加载、蓝图、科技、多行星、星际物流、戴森、离线、终局、设置、窄屏和损坏存档恢复。

- [ ] **步骤 4：验证本地导出**

验证 Windows 单机包；如 Android 导出模板和签名条件具备，再验证 Android 本地包。导出失败不能影响源码门禁，但必须记录真实状态。

- [ ] **步骤 5：最终审查**

使用 `requesting-code-review` 检查状态守恒、存档兼容、输入穿透、错误反馈、性能差分、许可边界和文档真实性。修复所有高置信度问题后重跑全程质量门。

- [ ] **步骤 6：更新权威文档并提交**

```powershell
git add README.md docs/PROJECT_STATUS.md docs/CONTENT_PARITY.md docs/testing/single-player-release-checklist.md docs/current/SINGLE_PLAYER_ROADMAP.md
git commit -m "docs: complete single player parity roadmap"
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
| 阶段 6 | 设置、平台适配、性能与发布证据齐全 | 大工厂优化改变状态、核心 UI 重叠或存档不可恢复 |

## 文档维护规则

- 本计划是程序级路线图；每个阶段开始前可以创建更细的阶段计划，但不得改变本文件的范围边界和停止门，除非先更新设计规格并获得用户批准。
- 每完成一步勾选对应复选框；不能按“已有类似函数”提前勾选。
- 新发现差距先加入设计规格的差距矩阵，再决定插入哪个阶段。
- 在线功能需求若未来重新进入范围，必须新建设计规格和独立计划，不能悄悄加入本单机路线。
