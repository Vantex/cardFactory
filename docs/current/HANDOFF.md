# 当前交接记录

任务 16「安全离线结算与离线报告」已完成，下一项是 [任务 17：设置、国际化、主题和输入适配](SINGLE_PLAYER_ROADMAP.md)。任务 15 基线提交为 `ba8d561`；本次在本地 main 提交 `feat: add recoverable offline settlement`，未推送。

## 当前能力与证据

正式继续入口按存档时间戳执行独立状态副本的精确重放：最多 120 秒、1×、60 Hz，每帧最多 60 tick / 8 ms，单个 tick 不可抢占。生产、物流、科研、戴森、终局及战役进度采用同一固定步长顺序。计算和报告期间工厂输入关闭，提交成功才安装结果。报告包含真实离线、模拟及跳过时长、实际产出、新科技和目标、阻塞与终局阶段。

槽位旁的校验事务记录保存 pending 起点和 prepared 结果；写入失败可重试，恢复与重复提交依靠收据和时间边界避免重复应用。放弃尚未准备的收益会保存跳过边界；时钟回拨不降低边界，旧档无时间戳只建立起点。保留 schema v9，存档 JSON 使用完整浮点精度，修复长重放后的摘要验证失败。

最终 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` 退出 0，十二场景成功标记各一次，无脚本/解析错误或生命周期泄漏；Main 无窗口启动 120 帧退出 0。日志为可重新生成的 `.godot/task16-final-gate.log`、`.godot/task16-final-main.log`。环境仍有 user:// 日志及根证书读取提示，不宣称日志完全无错误。

[实现计划](TASK16_PLAN.md)与[验收记录](TASK16_ACCEPTANCE.md)记录边界、失败注入和复现步骤。自动回归覆盖在线等价、上限、放弃、回拨、事务恢复、备份恢复、写入失败、正式界面重试与输入拦截；没有完整新游戏人工通关、真实断电实验或大型工厂性能认证。恢复计算期间经过的现实时间不另补模拟，未来 schema 或模拟规则变更需核对在途事务兼容性。

## 工作区保留事项

- 主仓库 `D:\AI_Program\CardGame\card-factory`，当前分支 main；没有本次任务分支或 worktree，没有 fetch/push。
- 保留用户 `docs/current/SINGLE_PLAYER_ROADMAP.md` 的完整单机目标和任务 19～27 扩展，以及 `project.godot` 删除 viewport_width/viewport_height 的两行差异。本次只提交任务 16 五个完成标记。
- 不操作 `.worktrees/recovery-baseline`。任务 12 备份仍在 `D:\AI_Program\CardGame\task12-premerge-backup-20260905`。
- 参考项目 `D:\AI_Program\CardGame\DSPONLINE` 仅用于许可范围内的行为与架构参考；在线服务和参考项目旧存档导入不在范围内。

现有物流与戴森目标配置不属于蓝图 v1 复制范围。正式燃料补充 UI、行星内电网分区、完整工业内容等继续按路线图推进。
