# CardFactory Phase 2: DSPONLINE-Inspired Godot Workspace Design

## Status and authority

用户已明确要求直接参考 DSPONLINE 的成熟 UI/设计并在 Godot 中实现，不再进行方案讨论。本规格因此记录自主选择的实现方案，并作为第二阶段验收依据。参考范围是布局、信息层级和交互行为；不复制 DSPONLINE 源码或素材。

## Goal

把当前“自动生成两张测试卡 + 零散标签”的主场景替换为一个真正可操作的工厂工作区。玩家从空白画布开始，能够放置矿机和加工建筑、检查状态、选择配方、拖动节点、从输出端口连接到输入端口，并看到生产链运行。

## Screen composition

- 顶部 52 px 状态栏：产品名、运行/暂停、速度、电力供需、建造点、建筑/连接数量和时间。
- 左侧 216 px 资源栏：新手目标、聚合库存、生产概况和操作提示，可折叠。
- 中央世界画布：暗色点阵背景、可平移缩放的节点卡片、方向连接、选择与连接预览。
- 右侧 286 px 检查器：无选择时显示工厂概览；有选择时显示建筑身份、状态、进度、电力、I/O、配方、连接与删除动作，可折叠。
- 底部 92 px 建造坞：常用建筑卡、快捷键、用途、建造点成本和当前放置模式。
- 中央顶部画布条：当前模式、缩放比例和取消提示。
- 底部中央短时通知：成功为绿色、提醒为黄色、失败为红色。

## Visual language

- 背景使用近黑绿色，面板使用分层深灰绿；边界细而清晰。
- 青色表示选择/可连接，绿色表示运行/成功，黄色表示等待/警告，珊瑚红表示阻塞/非法操作。
- 卡片固定为 232×144 世界单位：54 高标题区、状态/进度区、输入输出区和页脚；输入端口在左、输出端口在右。
- 连线使用二次曲线；活动连接带流动粒子，选择中的草稿线随指针移动。
- 不依赖外部图片素材，建筑和物品使用 JSON 中的 symbol 或简洁字符标识。

## Interaction model

1. 点击建造坞或 Q/W/E/R 进入放置模式；卡片随指针预览，左键确认，Escape 取消。
2. 放置由 `GameState.try_place_building` 原子验证并扣建造点；失败不改变状态。
3. 点击卡片选中，点击空白取消；按住卡片拖动，释放时提交世界坐标。
4. 从卡片右侧输出端口按下并拖到另一卡片左侧输入端口，释放后提交连接；Escape 或空白释放取消。
5. 若目标加工建筑尚未设置配方，连接时自动选择第一个接受该物品的配方；已选但不兼容时拒绝。
6. 右侧检查器可显式选择合法配方；变更配方清空进度，但不偷偷删除既有连接。
7. Delete 或检查器按钮删除所选建筑及其所有连接。
8. 中键/右键拖动画布，滚轮以指针为中心缩放；UI 面板消费输入，不能穿透到画布。
9. Space 暂停/继续；1/2/3 切换模拟速度。

## Game-state additions

- `construction_points: int = 12`。
- 低阶成本：矿机 1、熔炉 2、制造台 3、发电机 2；只在放置成功时扣减。
- `try_place_building(type, position) -> Dictionary`。
- `try_add_connection(source_id, target_id) -> Dictionary`。
- `get_building_output_item`、`get_compatible_recipes` 等只读辅助方法。
- 所有失败结果统一 `{ok:false, message:String}`；成功结果包含新 ID 和消息。

## Component responsibilities

- `FactoryWorkspaceUI.gd`：创建主题化界面、聚合显示、选择/配方/删除命令和通知；不直接写状态字典。
- `InputHandler.gd`：唯一画布输入仲裁器，维护放置/拖动/连接草稿，完成相机坐标转换和命中测试。
- `CardRenderer.gd`：纯读取 GameState + InputHandler 交互状态，绘制背景、卡片、端口、进度和预览。
- `ConnectionRenderer.gd`：纯读取连接，绘制曲线、方向、物品标签和活动流动反馈。
- `GameState.gd`：验证、资源扣减和原子状态变更。
- `Main.gd`：组合对象、连接信号并启动空白新游戏，不再生成测试生产线。

## Data flow

`UI/Pointer intent → InputHandler or FactoryWorkspaceUI → GameState command → EventBus signal/result → UI selection/notice + renderers read state → SimulationEngine updates → HUD/card redraw`。

## Error handling

- 未知建筑、建造点不足、重叠放置、无输出、自连接、重复连接、配方不兼容和实体失效均给出具体中文反馈。
- 失败命令不扣资源、不创建半条连接、不更改选择。
- UI 若持有已删除 ID，在下一次刷新时自动回到概览。

## Test strategy

- 先扩展无窗口 Phase 2 测试：建造成本、失败原子性、配方兼容/自动选择、重复和自连接拒绝、删除级联。
- 场景结构测试：主场景存在 Camera2D、FactoryWorkspaceUI、renderers 和 InputHandler，旧 HUD/BuildingPanel 不再挂载。
- UI 契约测试：建造坞按钮、三栏、状态栏、检查器和通知节点可被查找，选择后检查器刷新。
- 最后运行 Phase 1 全量测试门、Phase 2 门和主场景 120 帧启动验证。

## Deferred

多选/框选、蓝图、缩略图、移动端布局、云存档、星图、科技、批量连接和高级物流检查器不属于第二阶段。旧未挂载 UI 的删除也延后到新工作区稳定之后。
