# 当前交接记录

任务 18「大型工厂性能与稳定性预算」已实现；下一项为任务 19「冻结 DSPONLINE 单机对齐基线」，本轮未开始。任务 17 基线为 `6caf276`。本次按既有授权提交到本地 main，不推送。

## 当前范围

电脑游戏、中文界面；保留分辨率自适应和原有鼠标键盘操作，不加入国际化或手机适配。任务 18 追加范围为可开关的运行时监测和 JSON / Markdown 报告。

## 交付

设置页可开始监测，返回工厂操作后停止并导出报告；默认关闭，每项最多保留 3600 样本。记录十二个模拟阶段、固定步、帧间隔、绘制 CPU 提交、内存、积压和保存时间；监测状态不进入游戏存档。

优化传送带排序中的重复配置查询、空间索引同步与负坐标边界、视口裁剪、样式复用和缩小视图批绘。模拟不跳步，缓存不跨 tick 保留可变库存/供电结果。三档工厂固定为 32/256/1024 建筑、8/64/256 线路、2/16/64 物流站；比较朴素和优化路径的状态摘要，并验证实际存档往返。测试复现并修复了线路整数经 JSON 读回后引发的摘要不一致，schema 仍为 v9。

[实施记录](TASK18_PLAN.md)、[验收及实测](TASK18_ACCEPTANCE.md)、[夹具和趋势比较](../../tests/fixtures/README.md)描述详细边界。原始本机图形报告保存在 `tests/fixtures/baselines/windows-*.json` / `.md`。

本机大型场景模拟更新平均 43.44 → 22.71 ms，单独图形帧平均 227.04 → 35.97 ms。图形基准没有同时运行完整 UI 和实时模拟，不代表整个游戏 FPS；固定步 P95 23.87 ms，尚未达到 60 Hz 的 16.67 ms 预算。后续性能优化可优先看电力、物流阶段。

## 验证

正式入口 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` 已包含十四场景；日志 `.godot/task18-final-gate.log`。正式 Main 120 帧日志 `.godot/task18-final-main.log`。实际 OpenGL 基准日志 `.godot/task18-render.out.log` / `.err.log`，LOD 截图 `.godot/task18-lod-1024.png` 已查看。环境的日志目录、着色器缓存和根证书提示与脚本检查分开记录。没有长期压力、全显卡或完整通关认证。

## 保留事项

- 主仓库 `D:\AI_Program\CardGame\card-factory`，分支 main；没有本轮分支/worktree，没有 fetch/push。
- 保留用户路线图完整单机目标和任务 19～27 扩展；仅提交任务 18 本身的完成记录。
- 保留 `project.godot` 原有 viewport_width / viewport_height 两行删除；本次不提交该文件。
- 不操作 `.worktrees/recovery-baseline`。任务 12 备份仍在 `D:\AI_Program\CardGame\task12-premerge-backup-20260905`。
- `D:\AI_Program\CardGame\DSPONLINE` 仅为许可范围内参考；账号、云存档和旧档导入不在范围内。
- 离线结算仍限 120 秒、1×、60 Hz；后续改状态或规则须核对在途事务兼容性。物流/戴森配置仍不在蓝图 v1 复制范围。
