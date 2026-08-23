# Architecture Index

## Implementation Guide

This index is not the full contract. Do not implement from this file alone; follow the artifact paths below.

### Global artifacts

- `unit_graph.yaml`：所有实现者读取；定位公共入口、源证据、依赖和动态场景入口。
- `migration_boundary.yaml`：所有实现者读取；`must_rewrite` 是实施范围，`source_anchors` 不是复制或改写清单。
- `wire_contracts.yaml`：读取 `unit == factory-workspace` 的行，保持 UI→GameState 请求、结果和错误原子性。
- `shared_modules.yaml`：当前无跨单位模块；不得据此把 React 子组件伪拆成公共服务。
- `cross_unit_state.yaml`：当前无跨单位隐式状态；选择态保持在工作区控制器中。
- `seams.yaml`：读取 `cut_between` 包含 factory-workspace 的切点；不得重构冻结的模拟/数据层。
- `project-structure.md`、`tech-stack.md`、`data-model.md`：用于目标分层、技术转换和实体不变量。

### Unit: factory-workspace

- external trigger：玩家进入 `Main.tscn` 后操作主工厂页面。
- must read：
  - `units/factory-workspace/behavior.yaml`：实现所有 `must_preserve` 的放置、选择、移动、连接、配方、删除与反馈行为。
  - `units/factory-workspace/bindings.yaml`：完成 Main 场景、Camera2D、InputHandler、EventBus 和 CanvasLayer 接线。
  - `units/factory-workspace/unit_decomposition.yaml`：只作为后续拆分证据，不把 candidate 当成本阶段目标结构。
- relevant global rows：
  - `wire_contracts.yaml` 中 `unit: factory-workspace`。
  - `seams.yaml` 中 migrated_side 为 factory-workspace。
  - `migration_boundary.yaml` 中全部 `must_rewrite`。
- before DONE report：列出已读工件、实现的 must_preserve、任何延后项，以及测试、解析、启动与交互验证证据。
