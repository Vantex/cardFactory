# Project Structure

> **历史归档（2026-08-23 工作区交付）：** 本结构只服务当时 Phase 2 迁移，不定义当前后续架构；请以[项目状态](../../../../PROJECT_STATUS.md)和[当前设计](../../../../current/SINGLE_PLAYER_GAP_ANALYSIS.md)为准。

## Project type

DSPONLINE 是浏览器/Electron 驱动的单页工厂模拟器；CardFactory 是 Godot 4 桌面项目。本阶段不是全量移植，而是把前者的主工厂工作区信息架构和交互语言重新实现到后者的活动主场景。

## Functional domains

- 工作区组合：DSPONLINE `src/App.tsx`；目标 `scenes/ui/FactoryWorkspaceUI.gd`。
- 画布交互：DSPONLINE ReactFlow 回调；目标 `scripts/input/InputHandler.gd` 与 `Camera2D`。
- 节点和物流视觉：DSPONLINE `FactoryNodes.tsx` / `FactoryEdges.tsx`；目标两个 Node2D renderer。
- 游戏命令与状态：DSPONLINE engine 函数；目标 `scripts/game/GameState.gd`。
- 数据与模拟：CardFactory `DataManager`、`SimulationEngine` 及各 system，本阶段冻结。

## Layers

1. CanvasLayer 工作区：状态展示、建造选择、检查器命令、反馈。
2. Node2D 画布：相机、卡片、连接和指针交互。
3. GameState 命令边界：验证并原子修改字典状态。
4. 模拟系统：电力、物流、生产和统计更新。
5. JSON 内容：建筑、物品和配方定义。

## Runtime entry

`project.godot` 加载 `scenes/main/Main.tscn`；Main 组合渲染层、输入层、Camera2D 与 FactoryWorkspaceUI。旧 HUD/BuildingPanel 不再挂载，但可留待后续清理。
