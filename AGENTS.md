# CardFactory 接手入口

开始项目工作前先读 [当前交接记录](docs/current/HANDOFF.md)，再读 [项目状态](docs/PROJECT_STATUS.md) 和 [文档索引](docs/README.md)。实施顺序以 [单机路线图](docs/current/SINGLE_PLAYER_ROADMAP.md) 为准；历史计划及子代理报告不能替代当前代码和验证证据。

- 当前目标是 DSPONLINE 的离线单机功能与内容对齐；在线服务及 DSPONLINE 旧存档导入不在范围内。
- 保留已有未提交工作。尤其不要覆盖路线图扩展和 `project.godot` 的用户改动，详情见交接记录。
- 用户已要求任务完成后自动合并到本地 main、清理本次任务分支；推送需有明确授权。
- 不操作 `.worktrees/recovery-baseline`。它不是任务 12 的临时工作区。
- 完成汇报说明实际验证范围、尚未验证事项和下一步；完成后同步更新交接记录。
