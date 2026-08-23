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

全新检出或新建 worktree 后，先让 Godot 建立导入缓存和全局脚本类缓存：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --editor --quit
```

然后运行门禁：

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

门禁运行真实 Godot 测试场景：`TestBaseline` 与 `TestFactoryWorkspace`。正常通过必须同时满足：Godot 退出码为 0；每个场景的完整成功标记各出现一次；输出不包含 `SCRIPT ERROR`、`Parse Error` 或对应失败标记。引擎级 `--quit-after 600` 保证测试进程有界结束。当前门禁不会自动执行首次导入；跳过上述导入步骤时，全新工作树可能因全局脚本类缓存尚未建立而解析失败。

## 当前可玩工作区（Phase 2）

主场景从空白画布开始。玩家可放置矿机、熔炉、制造台和发电机，选择配方，移动卡片，并从输出端口连接到输入端口；矿机到熔炉的链路会将 `iron_ore` 送入熔炉并生产 `iron_ingot`。放置和连接由 `GameState` 原子验证：失败不会扣除建造点或留下半条连接。

操作如下：

- `Q` / `W` / `E` / `R`：分别进入矿机、熔炉、制造台、发电机的放置模式。
- 左键：在放置模式确认放置；空闲时选择卡片，按住卡片拖动；在右侧输出端口按下，拖到另一张卡片左侧输入端口并释放以创建连接。空白或 UI 上释放会取消连接并显示原因。
- 右键或中键拖动：平移画布。
- 滚轮：以指针为中心缩放画布。
- `Escape`：取消当前放置、拖动或连接操作。
- `Delete`：删除当前选择的建筑及其连接。
- `Space`：暂停或继续模拟；`1` / `2` / `3`：切换 1×、2×、3× 模拟速度。

固定 UI 包含顶部状态栏、左侧资源栏、中央画布、右侧检查器、底部建造坞和短时通知。顶部按钮可暂停/继续并切换 1×/2×/3×；资源栏显示当前新手引导、聚合库存和生产概况；检查器提供配方、开始连接与删除动作。失败原因通过不拦截画布的短时通知显示。UI 面板会消费指针输入，中央画布保持可交互。

连接的 `enabled` 字段表示持久运输许可，`active` 只表示当前模拟帧是否真的发生物流传输；新连接默认启用但在首次运输前不会显示为活动。

## 目录

```text
autoload/       全局事件、游戏管理和静态数据加载
data/           物品、建筑与配方 JSON
scenes/         主场景、工作区 UI 和测试场景
scripts/game/   状态与模拟系统
scripts/input/  世界画布输入仲裁
scripts/rendering/ 卡片与连接渲染
scripts/test/   权威基线与工作区测试
tools/          唯一测试门禁脚本
docs/           权威状态、规格、计划和交付记录
```

## 非目标与未完成系统

第二阶段不包含多选或框选、蓝图、建筑缩略图、移动端布局、云存档、目标/胜负系统、minimap 或高级面板。仓库中存在的相关旧 UI 或局部 API 没有接入当前主场景，不能视为已交付功能。

存档的 `Vector2` JSON 往返尚未解决；电力效率目前也不会调节生产速度。科技、空间站、行星、星系、戴森球和高级物流能力同样不在活跃工作区范围内。`scripts/test/` 中除 `TestBaseline.gd` 与 `TestFactoryWorkspace.gd` 外的旧打印式脚本不属于门禁。

`DSPONLINE` 仅可在其非商业许可范围内作为行为和架构参考；本项目不复制其源码或素材，也不把其高级能力作为当前阶段的前置条件。

## 文档优先级

发生冲突时依次以以下资料为准：

1. 本 `README.md`；
2. [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md)；
3. 已批准的 [Phase 2 设计规格](docs/superpowers/specs/2026-08-23-cardfactory-phase2-dsponline-ui-design.md) 与 [实现计划](docs/superpowers/plans/2026-08-23-cardfactory-phase2-dsponline-ui.md)。

其余带日期的审计、测试指南、设计和阶段计划均为历史参考，不证明当前能力。
