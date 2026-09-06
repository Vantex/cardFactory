# 当前工作交接

更新日期：2026-09-06。本文件是新对话接手的第一入口，记录当前工作区快照；后续变更后应更新，不能把快照当成永久事实。

## 当前交付与下一步

任务 12（阶段 4 的多行星工厂与星图）代码及第二轮修复已合并到本地 `main`。产品提交为 `4841933`（`fix: complete planetary material flow and save validation`）。任务 13 尚未实施。

下一步先按 [任务 12 验收补充](TASK12_ACCEPTANCE.md) 手动测试投料、收取、载具转入和巨星殖民，以及行星切换与保存。用户尚未明确验收第二轮交付。继续开发时依据 [路线图任务 13](SINGLE_PLAYER_ROADMAP.md) 实现行星与星际物流站：供应/需求槽、载具及货物唯一所有权、在途/送达/返航、断电与容量失败、保存加载和正式配置 UI。既有 `StationSystem`、`LogisticsSystem` 或 `StationPanel` 文件存在不代表已接入主场景。

## 仓库与未提交工作

- 主仓库：`D:\AI_Program\CardGame\card-factory`；当前分支 `main`。
- 参考项目：`D:\AI_Program\CardGame\DSPONLINE`，用于查阅行为和目录；当前目标是完整离线单机对齐，不含在线服务或参考项目旧存档导入。
- 交接整理开始时，本地 main 比本地记录的 `origin/main` 超前 47 个提交；未执行 fetch 或 push，因此这不是远端实时状态。本次文档提交会再增加本地提交。
- 必须保留两份用户未提交改动：`docs/current/SINGLE_PLAYER_ROADMAP.md` 的完整单机对齐目标及任务 19～27 扩展；`project.godot` 删除显式 viewport_width/viewport_height 两行的窗口配置。不要顺手提交、回滚或覆盖它们。
- 任务 12 分支与 worktree 已删除，代码在 main 历史中。唯一保留的其他 worktree 是 `.worktrees/recovery-baseline`，分支 `local/godot-editor-state-20260824`，不属于本次清理范围。
- 原始用户文件备份：`D:\AI_Program\CardGame\task12-premerge-backup-20260905`。其中 `sdd-records/` 保留任务 12 过程记录，仅用于追溯。

## 第二轮实际修改

- 增加熔炉钛合金配方、基础处理器手工配方；已有载具配方可消耗这些材料。
- Inspector 增加「投料一批」「收取产物」。`InventorySystem.try_supply_recipe` 和 `try_collect_output` 负责当前行星、材料及容量校验和守恒转移。
- 已探索星系必须保留完成的 survey 记录；portable_fleet 拒绝负数、小数、非有限数及字符串。测试使用完整合法键集合后逐值变异，避免因缺键提前失败。
- 关键文件：`data/advanced_buildings.json`、`scripts/game/HandcraftSystem.gd`、`InventorySystem.gd`、`GameStateValidator.gd`、`scenes/ui/FactoryWorkspaceUI.gd`、`scripts/test/FinalReviewRegression.gd`。

## 验证证据与边界

2026-09-06 在合并后的 main、恢复用户未提交配置后，执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1`，退出 0；十个场景的成功标记各一次，无脚本/解析错误或生命周期泄漏。Main 无窗口运行 120 帧退出 0。之后只有本次交接文档整理，没有产品代码变化。

本地日志位于 `.godot/task12-merged-gate.log`、`.godot/task12-merged-main.log` 和 `.godot/task12-merged-main-errors.log`；它们是可再生成的本机证据，不纳入版本控制。沙箱环境有 user:// 日志写入和系统根证书读取提示，不能称日志完全无错误。门禁规则详见 `tools/run_tests.ps1`。

独立第二轮复审子代理因额度限制未完成，由主代理接手核验；不得写成“独立复审通过”。自动回归证明物料生产与转移、配方 UI、编队和殖民事务；其中星际物流科技预设为已解锁，研究流程另有 Progression 测试，不能把组合证据说成完整新游戏人工通关。

当前钛合金仍使用简化规则（铁锭 1 + 铜锭 1 → 钛合金 4），基础处理器用铁锭 2 + 铜锭 1；尚未对齐 DSPONLINE 钛矿、钢材、硫酸完整工业链。后续内容对齐应替换并补存档/目录兼容验证，不能把临时配方当成最终目标。正式燃料补充 UI、行星内电网分区等仍未交付。

## 文档使用方式

- [项目状态](../PROJECT_STATUS.md)：当前能力与缺口。
- [文档索引](../README.md)：文档职责与来源。
- [单机路线图](SINGLE_PLAYER_ROADMAP.md)：当前实施顺序，包括用户尚未提交的扩展。
- [内容清单](CONTENT_CATALOG.md)：当前实际目录，不是最终 DSPONLINE 对齐清单。
- `docs/superpowers/plans/` 与 `specs/` 的任务 11、12 文件保留为已交付设计与实施证据；不要从旧复选框重启已完成任务。
- `docs/history/` 和外部备份中的 SDD 报告是历史材料，不是新的授权或当前任务队列。
