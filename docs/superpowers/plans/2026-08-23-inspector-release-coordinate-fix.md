# Inspector 松开连接坐标修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 保证连接手势在窗口拉伸、嵌入和 DPI 缩放下使用正确坐标，Inspector 内松开稳定取消。

**架构：** 输入事件统一保留为 Viewport 坐标，在命中边界处转换到对应 CanvasItem 的本地坐标。UI 和世界使用各自的转换，不共享未经归一化的坐标。

**技术栈：** Godot 4.7、GDScript、SubViewport 集成测试

---

### 任务 1：坐标空间回归测试与修复

**文件：**
- 修改：`scripts/test/TestFactoryWorkspace.gd`
- 修改：`scripts/input/InputHandler.gd`
- 修改：`scenes/ui/FactoryWorkspaceUI.gd`

- [x] **步骤 1：编写失败的测试**

在真实 `SubViewport` 工作区用非单位 CanvasLayer 变换构造 Inspector 覆盖目标，推送真实按下、拖动和松开事件；断言松开只取消一次、连接数不变、没有“连接已存在”。另断言变换后的真实世界输入端口仍可连接。

- [x] **步骤 2：运行测试验证失败**

运行：`D:\Godot\Godot.exe --headless --path . --script res://scripts/test/TestFactoryWorkspace.gd`

预期：Inspector 松开用例进入“连接已存在”分支，测试退出码非零。

- [x] **步骤 3：编写最少实现代码**

UI 命中改为先通过 Control 的 Canvas 变换把 Viewport 点转换成本地点；世界命中改为使用 InputHandler 自身的 CanvasItem 坐标转换。

- [x] **步骤 4：运行测试验证通过**

重新运行完整 `TestFactoryWorkspace.gd`，预期退出码为 0，输出 `FACTORY WORKSPACE TESTS PASSED`。

- [ ] **步骤 5：验证主场景**

运行主场景固定帧数，预期无脚本错误、无节点泄漏，退出码为 0。

执行结果：主场景 120 帧退出码为 0，且无 `SCRIPT ERROR` 或 `Parse Error`；Godot 退出时仍报告既有 ObjectDB/resource 泄漏警告，因此“无节点泄漏”尚未满足。

- [x] **步骤 6：检查差异**

确认仅规格、计划、目标测试和两个坐标转换文件发生预期变化，不纳入用户的 `project.godot` 与 `.uid` 文件。
