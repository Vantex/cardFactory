# CardFactory 文档索引

这里是仓库文档的唯一导航入口。判断项目“现在能做什么”和“下一步做什么”时，按下列顺序阅读。

## 当前权威文档

| 顺序 | 文档 | 用途 |
|---|---|---|
| 0 | [当前工作交接](current/HANDOFF.md) | 接手快照、未提交工作、验证证据、待验收事项与下一步 |
| 1 | [项目状态](PROJECT_STATUS.md) | 只记录当前代码和正式门禁能够证明的能力、缺口与风险 |
| 2 | [单机差距分析](current/SINGLE_PLAYER_GAP_ANALYSIS.md) | 定义 CardFactory 对照 DSPONLINE 的单机范围、差距和明确排除项 |
| 3 | [单机实施路线图](current/SINGLE_PLAYER_ROADMAP.md) | 当前唯一在执行的后续路线，包含阶段、任务、停止门和验证要求 |
| 4 | [仓库 README](../README.md) | 安装、运行、操作和测试入口 |

交接记录负责工作区快照，项目状态负责已交付事实，路线图负责目标与顺序；出现冲突时核对当前用户要求及代码/测试证据，不用旧状态文档否定新的已批准范围。

任务 12 的手动检查见 [验收补充](current/TASK12_ACCEPTANCE.md)。`docs/superpowers/plans/` 和 `specs/` 中任务 11、12 的文件保留为已交付批次的设计追溯，不是另一份活跃路线图。

## 历史文档

[历史归档](history/README.md)保存已经结束的设计、计划、审计、测试说明和架构工件。它们用于追溯当时为什么这样做，不证明当前功能状态，也不能作为新的实施入口。

历史文件按交付批次整体归档：

- `2026-08-21-initial-development`：项目初始设计、旧三阶段计划、早期审计和测试指南。
- `2026-08-23-workspace-delivery`：可信基线、DSPONLINE 风格工作区和 Inspector 坐标修复交付记录。

## 维护规则

- `docs/PROJECT_STATUS.md` 只写已被当前运行树和正式门禁证明的事实。
- `docs/current/` 只保留当前批准的范围与路线；新路线替代旧路线时，旧文件整体移入 `docs/history/`。
- `docs/history/` 中的复选框、状态和命令保持历史语境，不重新解释为当前待办。
- 测试方法以根 README 和 `tools/run_tests.ps1` 为准；历史测试手册不属于门禁。
- 不在仓库根目录散放新的开发记录；当前文档进入 `docs/current/`，完成的批次进入带日期的历史目录。
