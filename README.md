# CardFactory

> 本分支归档后续本地开发文档，代码仍是较早的 GitHub `main` 基线。请从[开发现状与续作指南](docs/current/DEVELOPMENT_HANDOFF.md)进入，查看任务 27 的当前能力、待办、验证边界和后续实现顺序。

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

全新检出或新建 worktree 后直接运行门禁：

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

门禁会先自动执行无窗口编辑器导入，生成资产缓存和全局脚本类缓存，再运行真实 Godot 测试场景：`TestBaseline`、`TestFactoryWorkspace`、`TestStatePersistence` 与 `TestSimulationCore`。正常通过必须同时满足：Godot 退出码为 0；每个场景的完整成功标记各出现一次；输出不包含 `SCRIPT ERROR`、`Parse Error`、对应失败标记、ObjectDB 泄漏或仍被占用的资源。引擎级 `--quit-after 600` 保证测试进程有界结束。

## 当前可玩工作区（Phase 2）

主场景从离线开始菜单进入。玩家可在 10 个本地槽位中新建或继续游戏，并在工厂画布放置矿机、熔炉、制造台和发电机，选择配方、移动卡片，以及从输出端口连接到输入端口；矿机到熔炉的链路会将 `iron_ore` 送入熔炉并生产 `iron_ingot`。放置和连接由 `GameState` 原子验证：失败不会扣除建造点或留下半条连接。

操作如下：

- `Q` / `W` / `E` / `R`：分别进入矿机、熔炉、制造台、发电机的放置模式。
- 左键：在放置模式确认放置；空闲时选择卡片，按住卡片拖动；在右侧输出端口按下，拖到另一张卡片左侧输入端口并释放以创建连接。空白或 UI 上释放会取消连接并显示原因。
- 右键或中键拖动：平移画布。
- 滚轮：以指针为中心缩放画布。
- `Escape`：有放置、拖动或连接操作时先取消该操作；画布空闲时保存并返回开始菜单。
- `Delete`：删除当前选择的建筑及其连接。
- `Space`：暂停或继续模拟；`1` / `2` / `3`：切换 1×、2×、3× 模拟速度。

固定 UI 包含顶部状态栏、左侧资源栏、中央画布、右侧检查器、底部建造坞和短时通知。顶部按钮可暂停/继续并切换 1×/2×/3×；资源栏显示当前新手引导、聚合库存和生产概况；检查器提供配方、开始连接与删除动作。失败原因通过不拦截画布的短时通知显示。UI 面板会消费指针输入，中央画布保持可交互。

连接的 `enabled` 字段表示持久运输许可，`active` 只表示当前模拟帧是否真的发生物流传输；新连接默认启用但在首次运输前不会显示为活动。

模拟使用 60 Hz 固定步长，并在单个渲染帧最多追赶 10 个 tick；超出的模拟时间保留到后续帧，不会静默丢失。每个 tick 固定按“电力 → 生产/采集 → 线路 → 研究边界 → 统计”推进。断电会停止生产和物流，欠电按供电倍率减速，恢复供电后保留原进度。燃料发电机必须有燃料才能发电；新放置的基础发电机带有 300 秒启动燃料，后续补充燃料由行星库存任务接入。太阳能和风能使用可保存的 0～1 发电倍率。

## 本地存档

新游戏创建槽位时立即保存；活动会话每 120 秒自动保存，返回菜单和正常关闭窗口前也会保存。每次写入先生成临时档并读回验证，验证成功后才替换主档；上一份有效主档保留为 `.bak`，主档损坏时自动恢复。槽位元数据记录 schema、保存时间、游玩时长、活动行星和规范状态摘要。当前界面没有单独的“立即保存”按钮。

存档默认位于 Godot 的 `user://saves/`。开始菜单提供继续最近游戏和槽位管理；槽位页提供新游戏、继续、删除确认及返回。损坏档、未知未来版本和不可写目录会停留在菜单并显示可操作原因，不会安装半初始化状态。

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

## 当前未完成系统与续作范围

当前已交付的第二阶段不包含多选或框选、蓝图、建筑缩略图、移动端布局、目标/胜负系统、minimap 或高级面板。仓库中存在的相关旧 UI 或局部 API 没有接入当前主场景，不能视为已交付功能。

版本化 `GameState` codec、多槽本地存档、固定步长和真实供电倍率已经接入正式入口；云存档、存档压缩和独立的手动保存按钮仍不在当前范围。科技、空间站、行星、星系、戴森球和高级物流能力同样不在活跃工作区范围内。`scripts/test/` 中除 `TestBaseline.gd`、`TestFactoryWorkspace.gd`、`TestStatePersistence.gd` 与 `TestSimulationCore.gd` 外的旧打印式脚本不属于门禁。

后续已批准按完整单机玩法继续开发；账号、云存档、排行榜、在线社交和服务器运维明确排除。详细差距和实施顺序见[单机差距设计](docs/current/SINGLE_PLAYER_GAP_ANALYSIS.md)与[实施路线图](docs/current/SINGLE_PLAYER_ROADMAP.md)。

`DSPONLINE` 仅可在其非商业许可范围内作为行为和架构参考；本项目不复制其源码、素材或商标。

## 文档权威边界

- 安装、运行、操作和测试命令以本 `README.md` 与 `tools/run_tests.ps1` 为准。
- 当前功能完成度、已知缺口和测试证据以 [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) 为准。
- 后续范围、优先级和实施步骤以 [`docs/README.md`](docs/README.md) 指向的 `docs/current/` 文档为准。

带日期的审计、测试指南、设计和阶段计划统一保存在 [`docs/history/`](docs/history/README.md)，只用于追溯，不证明当前能力，也不自动成为当前待办。
