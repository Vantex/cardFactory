# 当前交接记录

任务 17「设置、主题和桌面输入」已完成，下一项为 [任务 18：大型工厂性能与稳定性预算](SINGLE_PLAYER_ROADMAP.md)。任务 16 基线 `3ea0dbf`；本次在本地 main 提交 `feat: add accessible local game settings`，不推送。

## 用户当前范围

用户明确取消国际化与手机适配：保留中文，按电脑游戏操作。不能根据旧路线图再次加入语言切换、移动导航、触摸抽屉或手势。

## 交付与证据

LocalSettings 独立保存设备主题、80%～200% 字号、密度、滚轮方向和手柄光标速度；不进入 GameState，切换槽位不改变设置，写入失败不安装候选值。正式开始菜单和工厂顶栏都有设置入口。保留桌面顶栏、左右侧栏和建造坞，最小窗口 1000×600；大字号按控件尺寸排列并支持滚动，动态控件应用主题和可见焦点。

保留鼠标与原快捷键；F6 / Y 切换画布焦点，键盘/手柄支持选择、放置、移动、连线、缩放和平移，删除仍由确认对话框提交。关闭工作区返回界面，打开设置重置未完成的输入状态。

权威验证入口 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1` 包含十三场景，每次使用独立设备设置路径。最终日志 `.godot/task17-final-gate.log`；Main 120 帧启动日志 `.godot/task17-final-main.log`。OpenGL 实际渲染截图见 `.godot/task17-settings.png` 与 `.godot/task17-factory-1000x600.png` / `1152x648.png`。

[实施计划](TASK17_PLAN.md)与[验收记录](TASK17_ACCEPTANCE.md)描述边界。没有实体手柄硬件认证、完整人工通关或全系统高 DPI 认证。日志中 user://、着色器缓存及根证书限制提示不代表脚本通过与否。

## 工作区保留事项

- 主仓库 `D:\AI_Program\CardGame\card-factory`，分支 main；没有本次任务分支或 worktree，没有 fetch/push。
- 保留用户路线图完整单机目标和任务 19～27 扩展；本次仅提交任务 17 范围修订和完成标记。
- 保留 `project.godot` 原有 viewport_width / viewport_height 两行删除；本次仅提交 LocalSettings 注册和最小桌面窗口尺寸。
- 不操作 `.worktrees/recovery-baseline`。任务 12 备份仍在 `D:\AI_Program\CardGame\task12-premerge-backup-20260905`。
- `D:\AI_Program\CardGame\DSPONLINE` 仅为许可范围内参考；账号、云存档和旧档导入不在范围内。

离线结算仍限 120 秒、1×、60 Hz，schema v9；后续更改状态或模拟规则时需核对在途离线事务兼容性。物流/戴森配置仍不在蓝图 v1 复制范围。

用户追加要求自动识别可用分辨率调整 UI。DesktopLayout 已按窗口尺寸实时计算比例，并覆盖桌面窗口、1080p、1440p、4K 和宽屏；字号偏好保持独立，画布命中区域同步更新。

最终验证：完整十三场景门禁退出 0，成功标记各一次；无脚本/解析错误或生命周期泄漏。Main 无窗口启动 120 帧退出 0，OpenGL 渲染版 TestProductShell 退出 0，六种桌面尺寸与三个字号档位通过。
