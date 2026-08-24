# CardFactory 项目状态

本文只记录可由当前代码和权威门禁证明的状态。运行与测试方法以根目录 [`README.md`](../README.md) 为准。

## Phase 2：已完成

Phase 2 的工厂工作区已接入主场景，并由正式测试门和无窗口主场景启动验证覆盖。Stage 0 的可信门禁、版本化权威状态和可靠本地存档入口也已完成；目标、minimap 和高级系统仍未交付。

## 活跃运行树与数据流

`project.godot` 注册 `EventBus`、`GameManager` 和 `DataManager` 三个 autoload，并以 `scenes/main/Main.tscn` 为主场景。

```text
project.godot
├─ DataManager → 按文件名排序加载 data/*.json → 重复 ID/配方引用校验
├─ GameManager → SaveSystem → GameState → SimulationEngine
│                              ├─ PowerSystem
│                              ├─ BeltSystem
│                              ├─ ProductionSystem
│                              └─ StatisticsSystem
└─ Main.tscn → AppShell → StartMenu + SaveSlotsPanel
               + WorldCamera + CardRenderer + ConnectionRenderer
               + InputHandler + FactoryWorkspaceUI
```

主场景先显示离线开始菜单和 10 个本地槽位；会话启动后才启用工厂输入与模拟。`AppShell` 只发送新游戏、继续、删除和返回意图，`GameManager` 统一协调保存、状态替换、自动保存和退出握手。`FactoryWorkspaceUI` 发出建造、连接、删除、暂停和速度意图；`InputHandler` 仲裁画布操作；两个 renderer 只读 `GameState`。`GameState` 负责原子规则，`SimulationEngine` 更新电力、物流、生产和统计。

## 已验证能力

权威门禁：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

它先自动执行一次无窗口编辑器导入，再顺序运行 `TestBaseline`、`TestFactoryWorkspace` 与 `TestStatePersistence`，要求各自唯一的成功标记。门禁会在 Godot 非零退出、`SCRIPT ERROR`、`Parse Error`、失败标记、成功标记缺失/重复、ObjectDB 泄漏或资源仍被占用时失败。全新检出不再需要人工预热全局脚本类缓存。

工作区测试覆盖：

- 初始 12 点建造点；成功放置才扣除成本，未知建筑、点数不足和任意 232×144 卡片矩形重叠均不改变状态，边缘相邻合法。
- 矿机到熔炉自动选择可兼容配方；自连接、重复连接和配方不兼容连接被拒绝；删除建筑级联删除连接。
- 主场景包含 `WorldCamera`、`CardRenderer`、`ConnectionRenderer`、`InputHandler` 和 `FactoryWorkspaceUI`，不再挂载旧 `HUD` 或 `BuildingPanel`。
- 顶栏动态显示运行/暂停、速度、电力、建造点、数量和时间；资源栏显示上下文新手引导、聚合库存、生产概况和操作提示；检查器显示建筑状态、进度、电力、缓冲区、配方以及连接/删除动作；建造坞显示快捷键、成本、用途和当前模式。
- 失败放置及自连接、重复连接、配方不兼容等原因会以中文短时通知显示；通知自动隐藏且不参与 UI 命中测试，其他 UI 面板仍阻止输入穿透到画布。
- 连接手势在非单位 Viewport、CanvasLayer 和世界 CanvasItem 变换下分别换算 UI 与世界坐标；在 Inspector 内松开会取消，不会误命中其下方建筑并报告“连接已存在”。
- 画布支持 Q/W/E/R 放置、同次按压的左键选择/拖动、输出端口按下后在输入端口释放完成连接、右键/中键平移、滚轮缩放、`Escape` 取消、`Delete` 删除、`Space` 暂停与 `1` / `2` / `3` 速度切换。
- 连接以 `enabled` 保存持久运输许可，以 `active` 表示当前帧实际物流；禁用连接不运输，启用但无货物的连接保持非活动。
- 矿机到熔炉的模拟链路将铁矿传入熔炉并生产铁锭。
- `GameState` 使用整数 schema 版本；`GameStateCodec` 生成稳定排序的 JSON 兼容快照并恢复 `Vector2`，`GameStateValidator` 拒绝悬空连接、负库存和不稳定 ID，`SaveMigrationRegistry` 逐版本迁移并拒绝未知未来版本。状态摘要排除暂停、倍速、节点引用、交互锁和当前帧连接流量；`GameManager` 替换状态时会同步重建模拟服务。
- `SaveSystem` 使用临时档写入后校验、有效主档轮换备份和摘要验证完成原子槽位保存；覆盖无效槽、损坏 JSON、异常元数据、未来版本、中断临时档和损坏主档的备份恢复。加载失败不替换当前状态。
- 新游戏立即落盘，活动会话每 120 秒自动保存，返回菜单和窗口关闭前使用同一保存协调器；保存不会改变玩家暂停意图，重叠写入会被拒绝。开始菜单提供继续最近游戏，槽位页提供新建、继续、删除确认和可操作错误提示。
- 用户已手动验收开始菜单、槽位页面、进入游戏及保存/继续流程；真实窗口布局未复现旧的 UI 重叠问题。

以下命令验证主场景能无窗口启动 120 帧；它不替代正式测试门：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
```

## 已知缺口与延期范围

- 多选/框选、蓝图、建筑缩略图和高级检查器面板延期。
- 移动端布局、云存档、正式目标/胜负系统和 minimap 未进入活跃主场景；资源栏中的新手目标只是上下文操作引导。
- 本地存档已经交付，但当前没有单独的“立即保存”按钮；保存以新建、120 秒自动保存、返回菜单和退出握手触发。
- 云同步、云备份、云恢复、存档压缩、解压和迁移均为延期能力，当前统一返回 `ERR_UNAVAILABLE`，不会伪装成功；`PerformanceSystem` 也明确报告未启用 Worker 支持。
- `PowerSystem` 会计算并写入 `power_efficiency`，但 `ProductionSystem` 没有消费该值，电力不足尚不影响生产速度。
- 科技、空间站、行星、星系、戴森球及高级物流功能多数没有进入当前主场景和活跃模拟编排，部分实现只是占位或局部 API。
- `TestCompletedFeatures.gd`、`TestPhase*.gd` 等旧测试主要打印计数或结果，没有统一非零失败语义，不属于权威门禁。

## 下一阶段建议

用户已批准继续对齐 DSPONLINE 的完整单机玩法，并明确排除账号、云存档、排行榜、在线社交和服务器运维。版本化状态与可靠本地存档已经完成；下一项按[单机实施路线图](current/SINGLE_PLAYER_ROADMAP.md)实施固定步长和真实电力闭环，再依次建设完整行星工厂、科技推进、多行星物流、戴森终局及产品化。

`DSPONLINE` 只在其非商业许可范围内作为行为和架构参考；不复制其源码或素材，也不把账号、云档、多核 Worker、排行榜等高级能力作为 CardFactory 当前开发的前置条件。

## 文档口径

根 `README.md`、[文档索引](README.md)与本文是开发者入口。`docs/current/` 定义后续范围；`docs/history/` 只保存已结束批次的背景与交付记录，不能单独证明功能已经接入或通过测试。
