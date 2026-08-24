# Tech Stack

> **历史归档（2026-08-23 工作区交付）：** 本技术转换说明只用于当时工厂工作区交付；请以[项目状态](../../../../PROJECT_STATUS.md)和[当前设计](../../../../current/SINGLE_PLAYER_GAP_ANALYSIS.md)为准。

## Reference application

- React 19 + TypeScript + Vite。
- `@xyflow/react` 提供无限画布、节点、端口、边、框选、缩放和缩略图。
- CSS Grid 形成左资源栏、中央画布、右检查器，建造坞固定在底部。
- React 状态/回调把 UI 意图提交给大型模拟 engine。

## Target application

- Godot 4.4，GDScript 2.0。
- Node2D 自绘卡片和连接；Camera2D 提供画布平移/缩放。
- CanvasLayer + Control 容器提供固定 HUD、资源栏、检查器和建造坞。
- Autoload `GameManager`、`DataManager`、`EventBus` 提供状态、内容与信号。

## Migration blockers and decisions

- ReactFlow 没有 Godot 直接等价物：用 Camera2D 世界坐标、InputHandler 命中测试和自绘 renderer 组合。
- React CSS 不可直接迁移：只保留 236/306 三栏比例、暗色工业色板、青色选择、黄色警告、红色错误等视觉语义。
- DSPONLINE 许可不支持直接复制其源码/素材用于目标产品：实现以行为和布局观察为依据，GDScript 与 Godot Theme 全新编写。
- CardFactory 当前状态是可变 Dictionary：UI 不直接写字段，新增窄命令方法控制原子性。
