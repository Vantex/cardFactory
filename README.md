# CardFactory

CardFactory 是一个使用卡牌式二维界面表达工厂生产链的 Godot 原型。当前可信基线要求 **Godot 4.7.2**；其他 Godot 版本尚未验证。

## 启动与测试

在仓库根目录使用 Windows PowerShell 5.1 或 PowerShell 7。Godot 默认安装路径为 `C:\Program Files\Godot\Godot.exe`。

启动编辑器：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --editor --path .
```

启动主场景：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path .
```

项目唯一的自动化测试门禁是：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

PowerShell 7 也可用同一脚本：

```powershell
pwsh -NoProfile -File .\tools\run_tests.ps1
```

Godot 不在默认位置时，通过 `-GodotPath` 覆盖：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1 -GodotPath 'D:\Tools\Godot\Godot.exe'
```

门禁运行真实 Godot 测试场景，捕获标准输出和错误输出；非零 Godot 退出码，或输出包含 `SCRIPT ERROR`、`Parse Error`、`BASELINE TESTS FAILED`，都会使脚本退出 1。引擎级 `--quit-after 600` 保证测试脚本来不及自行退出时进程仍有界结束。

## 当前原型

主场景启动时会创建矿机和熔炉，并建立一条传送连接。`GameManager` 驱动 `SimulationEngine`，依次更新电力、传送带、生产和统计系统，因此当前真实接通的原型链路是：

```text
矿机生产 iron_ore → 传送带转移 → 熔炉按 iron_ingot_recipe 生产 iron_ingot
```

这是一条自动放置的局部原型链，不是已经完成的玩家建造、资源成本、目标反馈和胜负条件闭环。

当前自动化只保证：

- 统计摘要返回 `total_buildings`、`total_connections`、`elapsed_time`、`production`、`consumption`；
- 四个静态数据文件可加载，重复 ID 与配方物品/建筑引用完整性校验结果为空；
- 注入无效存档目录时安全报告不可用并拒绝写入。

## 目录

```text
autoload/       全局事件、游戏管理和静态数据加载
data/           物品、建筑与配方 JSON
scenes/         主场景、UI 和测试场景
scripts/game/   状态与模拟系统
scripts/test/   权威基线测试及历史打印式测试
tools/          唯一测试门禁脚本
docs/           权威状态、已批准恢复文档及历史材料
```

## 非目标与未完成系统

当前阶段不新增玩法，也不以函数数量或旧文档中的完成率判断可用性。电力效率尚未影响生产速度；存档中的 `Vector2` JSON 往返尚未解决；科技、空间站、行星、星系、戴森球和高级 UI 多数未接入主运行树或仅有空壳。`scripts/test/` 中除 `TestBaseline.gd` 外的旧打印式脚本不属于门禁。

`DSPONLINE` 仅可在其非商业许可范围内作为行为和架构参考；本项目不复制其源码或素材，也不把其高级能力作为当前阶段的前置条件。

## 文档优先级

发生冲突时依次以以下资料为准：

1. 本 `README.md`；
2. [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md)；
3. 已批准的[恢复规格](docs/superpowers/specs/2026-08-23-cardfactory-recovery-baseline-design.md)与[恢复计划](docs/superpowers/plans/2026-08-23-cardfactory-recovery-baseline.md)。

其余带日期的审计、测试指南、设计和阶段计划均为历史参考，不证明当前能力。
