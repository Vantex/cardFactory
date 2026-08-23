# CardFactory 项目状态

本文只记录可由当前代码和权威门禁证明的状态。运行与测试方法以根目录 [`README.md`](../README.md) 为准。

## Phase 2：已完成

Phase 2 的工厂工作区已接入主场景，并由正式测试门和无窗口主场景启动验证覆盖。该结论仅表示本阶段的建造、连接、配方和画布交互闭环已交付，不表示存档、目标、minimap 或高级系统已完成。

## 活跃运行树与数据流

`project.godot` 注册 `EventBus`、`GameManager` 和 `DataManager` 三个 autoload，并以 `scenes/main/Main.tscn` 为主场景。

```text
project.godot
├─ DataManager → 按文件名排序加载 data/*.json → 重复 ID/配方引用校验
├─ GameManager → GameState → SimulationEngine
│                              ├─ PowerSystem
│                              ├─ BeltSystem
│                              ├─ ProductionSystem
│                              └─ StatisticsSystem
└─ Main.tscn → WorldCamera + CardRenderer + ConnectionRenderer
               + InputHandler + FactoryWorkspaceUI
```

主场景不再自动放置测试生产线。`FactoryWorkspaceUI` 发出建造、连接、删除、暂停和速度意图，并动态显示电力、库存、生产、检查器和短时反馈；`InputHandler` 仲裁中央画布的放置、选择、拖动、端口连接、平移和缩放；两个 renderer 只读 `GameState` 绘制卡片和连接。`GameState` 负责建造点扣除、矩形重叠检查、放置和连接的原子验证，`SimulationEngine` 继续更新电力、物流、生产和统计。

## 已验证能力

权威门禁：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

它顺序运行 `TestBaseline` 与 `TestFactoryWorkspace`，要求各自唯一的成功标记。门禁会在 Godot 非零退出、`SCRIPT ERROR`、`Parse Error`、失败标记或成功标记缺失/重复时失败。

工作区测试覆盖：

- 初始 12 点建造点；成功放置才扣除成本，未知建筑、点数不足和任意 232×144 卡片矩形重叠均不改变状态，边缘相邻合法。
- 矿机到熔炉自动选择可兼容配方；自连接、重复连接和配方不兼容连接被拒绝；删除建筑级联删除连接。
- 主场景包含 `WorldCamera`、`CardRenderer`、`ConnectionRenderer`、`InputHandler` 和 `FactoryWorkspaceUI`，不再挂载旧 `HUD` 或 `BuildingPanel`。
- 顶栏动态显示运行/暂停、速度、电力、建造点、数量和时间；资源栏显示上下文新手引导、聚合库存、生产概况和操作提示；检查器显示建筑状态、进度、电力、缓冲区、配方以及连接/删除动作；建造坞显示快捷键、成本、用途和当前模式。
- 失败放置及自连接、重复连接、配方不兼容等原因会以中文短时通知显示；通知自动隐藏且不参与 UI 命中测试，其他 UI 面板仍阻止输入穿透到画布。
- 画布支持 Q/W/E/R 放置、同次按压的左键选择/拖动、输出端口按下后在输入端口释放完成连接、右键/中键平移、滚轮缩放、`Escape` 取消、`Delete` 删除、`Space` 暂停与 `1` / `2` / `3` 速度切换。
- 连接以 `enabled` 保存持久运输许可，以 `active` 表示当前帧实际物流；禁用连接不运输，启用但无货物的连接保持非活动。
- 矿机到熔炉的模拟链路将铁矿传入熔炉并生产铁锭。

以下命令验证主场景能无窗口启动 120 帧；它不替代正式测试门：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
```

## 已知缺口与延期范围

- 多选/框选、蓝图、建筑缩略图和高级检查器面板延期。
- 移动端布局、云存档、正式目标/胜负系统和 minimap 未进入活跃主场景；资源栏中的新手目标只是上下文操作引导。
- `SaveSystem` 直接将包含 `Vector2` 的状态交给 JSON；位置值的可靠序列化与加载后类型恢复尚未解决，因此不能将保存/加载视为已交付能力。
- `PowerSystem` 会计算并写入 `power_efficiency`，但 `ProductionSystem` 没有消费该值，电力不足尚不影响生产速度。
- 科技、空间站、行星、星系、戴森球及高级物流功能多数没有进入当前主场景和活跃模拟编排，部分实现只是占位或局部 API。
- `TestCompletedFeatures.gd`、`TestPhase*.gd` 等旧测试主要打印计数或结果，没有统一非零失败语义，不属于权威门禁。

## 下一阶段建议

1. 为存档定义 schema，显式编码和恢复 `Vector2`，补充保存—加载往返测试。
2. 让电力供需真实调节生产效率，覆盖断电、欠电与恢复供电。
3. 在现有上下文新手引导之上定义正式目标与进度状态，再评估多选、蓝图、移动端和高级面板。
4. 只有基础闭环稳定后，再逐项评估 minimap、科技、空间站、行星、星系和戴森球。

`DSPONLINE` 只在其非商业许可范围内作为行为和架构参考；不复制其源码或素材，也不把账号、云档、多核 Worker、排行榜等高级能力作为 CardFactory 当前开发的前置条件。

## 文档口径

根 `README.md` 与本文是开发者入口。已批准的 2026-08-23 Phase 2 设计规格和实现计划记录本次范围与验收依据；其余日期文档是历史材料，不能单独证明功能已经接入或通过测试。
