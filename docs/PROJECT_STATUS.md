# CardFactory 项目状态

本文只记录可由当前代码和权威门禁证明的状态。运行与测试方法以根目录 [`README.md`](../README.md) 为准。

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
└─ Main.tscn → Main.gd + CardRenderer + ConnectionRenderer + InputHandler + HUD + BuildingPanel
```

`Main.gd` 自动放置矿机与熔炉并建立 `iron_ore` 连接。每帧由 `GameManager` 调用模拟引擎，更新顺序为电力、物流、生产、统计。矿机写入输出缓冲，传送带把矿石移入熔炉输入缓冲，熔炉使用 `iron_ingot_recipe` 生成铁锭。HUD 消费稳定统计摘要，不再读取旧的 `item_totals` 字段。

## 已验证能力

权威门禁：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

它使用真实 `GameState`、`SimulationEngine`、`DataManager` 和 `SaveSystem`，验证：

- 统计摘要是 Dictionary，且包含建筑数、连接数、运行时间、生产和消耗五个合同字段；
- 门禁断言静态数据的结构化完整性错误为空；同次 DataManager 加载日志报告 38 items、30 buildings、20 recipes；
- 无效存档目录不会导致脚本异常，存储状态为不可用且保存操作返回 `false`；
- 测试断言失败、Godot 非零退出、`SCRIPT ERROR`、`Parse Error` 或 `BASELINE TESTS FAILED` 都使门禁非零退出；
- 测试脚本异常而不能调用 `quit()` 时，`--quit-after 600` 仍会让进程有界结束。

以下命令用于验证干净导入和活跃主场景，不替代上述测试门禁：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --editor --quit
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
```

## 已知缺口

- `PowerSystem` 会计算并写入 `power_efficiency`，但 `ProductionSystem` 没有消费该值，电力不足尚不影响生产。
- `SaveSystem` 直接将包含 `Vector2` 的状态交给 JSON；位置值的可靠序列化与加载后类型恢复尚未解决。
- 科技、空间站、行星、星系、戴森球以及高级 UI 多数没有进入主场景和活跃模拟编排，部分实现只是占位或局部 API。
- 主场景当前自动放置固定原型链；玩家建造、成本约束、明确目标反馈、失败/胜利条件和持续进度闭环尚未完成。
- `TestCompletedFeatures.gd`、`TestPhase*.gd` 等旧测试主要打印计数或结果，没有统一非零失败语义，不属于权威门禁。
- 当前数据校验聚焦重复 ID 和配方物品/建筑引用，不是通用 JSON schema 校验。

## 下一阶段建议

按可玩闭环优先级推进：

1. 把放置、连接、配方选择、成本扣除和无效操作反馈接成玩家可操作的铁矿到铁锭流程，并为该流程增加行为断言。
2. 让电力供需真实调节生产效率，覆盖断电、欠电与恢复供电。
3. 定义存档 schema，显式编码和恢复 `Vector2`，补充保存—加载往返测试。
4. 增加最小目标与进度反馈，再扩展科技或更多生产配方。
5. 只有基础闭环稳定后，再逐项评估空间站、行星、星系、戴森球和高级 UI。

`DSPONLINE` 只在其非商业许可范围内作为行为和架构参考；不复制其源码或素材，也不把账号、云档、多核 Worker、排行榜等高级能力作为 CardFactory 当前开发的前置条件。

## 文档口径

根 `README.md` 与本文是开发者入口。已批准的 2026-08-23 恢复规格和计划记录本次基线决策；其余日期文档是历史材料，不能单独证明功能已经接入或通过测试。
