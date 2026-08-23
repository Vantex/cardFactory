# CardFactory 恢复可信基线实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 让 CardFactory 能从干净检出导入、通过一个真实测试门禁运行，并消除主场景、数据和存档基线中的确定错误。

**架构：** 保留现有 `GameState → SimulationEngine → systems` 结构，只修复当前活跃链路。新增一个轻量 Godot 测试场景和 PowerShell 门禁脚本；数据校验仍归 `DataManager`，不引入第三方测试框架。

**技术栈：** Godot 4.7.2、GDScript、Windows PowerShell 5.1 / PowerShell 7、Git

**已验证环境：** Godot 默认路径为 `C:\Program Files\Godot\Godot.exe`；统一测试命令和 `-GodotPath` 覆盖方法见根目录 `README.md`。

**执行修订：** Task 3 为兼容 Windows PowerShell 5.1，改用 `System.Diagnostics.Process` 异步捕获并分别转发 Godot stdout/stderr，保留原失败标记语义；Task 6 增加引擎级 `--quit-after 600`，使测试脚本异常、无法自行调用 `quit()` 时门禁仍有界退出。终审补强为 DataManager 增加文件级结构化失败与成功加载清单，并要求 TestBaseline 精确见证四个当前 JSON；PowerShell 门禁还要求完整行 `BASELINE TESTS PASSED` 恰好出现一次，关闭 Godot 提前退出或测试场景未完成时的假绿，但不扩展为通用 JSON schema 校验。

---

## 文件结构

- 创建 `tools/run_tests.ps1`：统一启动 Godot 测试场景，检测脚本/解析错误并返回可靠退出码。
- 创建 `scripts/test/TestBaseline.gd`：真实实例化核心系统，断言统计契约、数据完整性和存档降级行为。
- 创建 `scenes/test/TestBaseline.tscn`：基线测试入口。
- 修改 `autoload/DataManager.gd`：确定性加载、重复 ID 和引用完整性校验。
- 修改 `scripts/game/SimulationEngine.gd`、`scenes/ui/HUD.gd`：统一统计数据契约。
- 修改 `scripts/game/SaveSystem.gd`：用户目录不可用时安全失败。
- 修改 `data/*.json`：清理重复配方和无定义物品引用。
- 创建 `README.md`、`docs/PROJECT_STATUS.md`：唯一运行方法与权威状态。
- 修改 `.editorconfig`、`project.godot` 和全部 Godot 文本资源：UTF-8 无 BOM、LF。

### 任务 1：恢复干净导入

**文件：**
- 修改：`.editorconfig`
- 修改：`project.godot`
- 修改：`autoload/**/*.gd`、`scripts/**/*.gd`、`scenes/**/*.gd`、`scenes/**/*.tscn`、`data/*.json`

- [x] **步骤 1：记录红灯**

运行：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --editor --quit
```

预期：13 个 `.tscn` 在第 1 行报告 `Parse Error: Expected '['`。

- [x] **步骤 2：统一编码**

对 `.gd`、`.tscn`、`.json` 使用 UTF-8 无 BOM 与 LF；删除 `project.godot` 中的乱码配置键 `"ï»¿config_version"`。

- [x] **步骤 3：验证绿灯**

在无 `.godot` 缓存的工作树中重新运行编辑器导入，预期不再出现 `res://... Parse Error`。

- [x] **步骤 4：Commit**

```powershell
git add .editorconfig project.godot autoload scripts scenes data
git commit -m "fix: normalize Godot text resources"
```

### 任务 2：建立真实测试门禁并重现统计断链

**文件：**
- 创建：`tools/run_tests.ps1`
- 创建：`scripts/test/TestBaseline.gd`
- 创建：`scenes/test/TestBaseline.tscn`

- [x] **步骤 1：编写失败的统计契约测试**

测试真实 `GameState` 和 `SimulationEngine`：调用 `get_statistics()` 后必须返回键 `total_buildings`、`total_connections`、`elapsed_time`、`production`、`consumption`。如果缺键则累计失败并以非零退出码退出。

- [x] **步骤 2：编写门禁脚本**

门禁运行 `TestBaseline.tscn`，同时检测输出中的 `SCRIPT ERROR`、`Parse Error` 和 `BASELINE TESTS FAILED`；任一命中都退出 1。

- [x] **步骤 3：验证红灯**

运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```

预期：FAIL，现有 `StatisticsSystem` 不存在 `get_all_statistics()`。

- [x] **步骤 4：Commit 测试门禁**

```powershell
git add tools/run_tests.ps1 scripts/test/TestBaseline.gd scenes/test/TestBaseline.tscn
git commit -m "test: add executable Godot baseline gate"
```

### 任务 3：修复统计契约和主场景错误

**文件：**
- 修改：`scripts/game/SimulationEngine.gd:65`
- 修改：`scenes/ui/HUD.gd:69`
- 测试：`scripts/test/TestBaseline.gd`

- [x] **步骤 1：最小实现**

让 `SimulationEngine.get_statistics()` 返回 `statistics_system.get_statistics_summary()`；HUD 使用摘要中的 `production`、`total_buildings` 和 `total_connections`，不读取不存在的 `item_totals`。

- [x] **步骤 2：验证绿灯**

运行基线门禁与主场景 120 帧；预期统计契约测试通过且无 `SCRIPT ERROR`。

- [x] **步骤 3：Commit**

```powershell
git add scripts/game/SimulationEngine.gd scenes/ui/HUD.gd
git commit -m "fix: align runtime statistics contract"
```

### 任务 4：数据完整性校验

**文件：**
- 修改：`autoload/DataManager.gd`
- 修改：`data/base_metals.json`
- 修改：`data/electronics.json`
- 测试：`scripts/test/TestBaseline.gd`

- [x] **步骤 1：编写失败的数据测试**

断言 `DataManager.get_validation_errors()` 为空。每项错误包含 `code`、`source`、`id` 和 `message`，可抓住重复 ID、配方输入/输出缺失物品、配方建筑不存在。

- [x] **步骤 2：验证红灯**

预期至少报告重复的 `recipes/gear_recipe`，以及未定义的 `magnet`、`diamond` 引用。

- [x] **步骤 3：实现验证器和确定性加载**

文件名排序后加载；遇到重复 ID 保留首个定义并记录错误；加载完成后遍历全部配方引用。

- [x] **步骤 4：修复当前数据**

删除错误的重复 `gear_recipe` 定义；补齐 `magnet` 和 `diamond` 物品定义，使验证结果为 0。

- [x] **步骤 5：验证并 Commit**

```powershell
git add autoload/DataManager.gd data scripts/test/TestBaseline.gd
git commit -m "fix: validate static game data"
```

### 任务 5：存档不可用时安全降级

**文件：**
- 修改：`scripts/game/SaveSystem.gd:8`
- 测试：`scripts/test/TestBaseline.gd`

- [x] **步骤 1：编写失败的测试**

向 `SaveSystem` 构造函数注入确定无效的 `invalid://baseline/` 路径，断言不会产生脚本错误，且 `is_storage_available()` 为 `false`、`save_game()` 返回 `false`。默认构造仍使用 `user://saves/`。

- [x] **步骤 2：验证红灯**

预期现有构造函数对空 `DirAccess` 调用 `dir_exists`，门禁失败。

- [x] **步骤 3：最小实现**

允许构造函数注入保存目录，缓存目录初始化结果；`DirAccess.open()` 返回空时停止；所有写操作先检查可用性并返回 `false`。

- [x] **步骤 4：验证并 Commit**

```powershell
git add scripts/game/SaveSystem.gd scripts/test/TestBaseline.gd
git commit -m "fix: handle unavailable save storage"
```

### 任务 6：建立权威项目说明与全量验收

**文件：**
- 创建：`README.md`
- 创建：`docs/PROJECT_STATUS.md`
- 修改：`docs/superpowers/plans/2026-08-23-cardfactory-recovery-baseline.md`

- [x] **步骤 1：编写 README**

记录 Godot 版本、启动命令、测试命令、目录结构、当前可玩闭环和明确非目标。

- [x] **步骤 2：编写权威状态**

只记录由测试证明的能力和已知缺口；声明根目录旧审计为历史参考，不再使用百分比。

- [x] **步骤 3：全量验证**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
& 'C:\Program Files\Godot\Godot.exe' --headless --path . --quit-after 120 res://scenes/main/Main.tscn
git status --short
```

预期：基线门禁退出 0；主场景无 `SCRIPT ERROR`/`Parse Error`；只剩本任务文档、runner 有界参数和干净导入生成的基线 companion UID 待提交。

- [x] **步骤 4：Commit**

```powershell
git add README.md docs/PROJECT_STATUS.md docs/superpowers/plans/2026-08-23-cardfactory-recovery-baseline.md
git commit -m "docs: establish authoritative project baseline"
```
