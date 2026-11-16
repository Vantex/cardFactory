# 确定性性能夹具

`PerformanceFixtures.create_factory` 是唯一生成规则（版本 1），不读取玩家存档、不使用随机数。

| 档位 | 建筑 | 线路 | 行星物流站 |
|---|---:|---:|---:|
| small | 32 | 8 | 2 |
| medium | 256 | 64 | 16 |
| large | 1024 | 256 | 64 |

每四个建筑包含太阳能供电、库存和冶炼链；每十六个建筑包含一个物流站，供需交替。固定网格包含负坐标；供应站有运输机和矿石。所有档位运行 30 个 60 Hz 固定步，并比较未优化与优化/监测路径的持久化摘要；生成存档必须通过正式验证和读回校验。

普通门禁运行无窗口版本。实际绘制须运行图形版本：

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path . --rendering-method gl_compatibility res://scenes/test/TestPerformanceBudgets.tscn
```

输出位于 `.godot/performance-tests/`，每次生成独立 JSON 和 Markdown。图形版本用 1152×648 SubViewport，预热切换帧后分别采集 30 帧参考/优化耗时。它测量该机器当前环境的受控场景，不代表完整 UI、其他显卡或整个游戏的 FPS 保证；无窗口模式没有绘制结论。创建夹具耗时不是冷启动耗时。

保留同一机器/引擎/显卡/渲染器/场景的已接受 JSON 作为本地基线，然后执行：

```powershell
./tools/compare_performance.ps1 -Baseline baseline.json -Candidate candidate.json
```

趋势门槛默认为各项 P95 不超过基线的 135% 加 2 ms 噪声余量；环境不匹配、指标缺失或退化均失败。该门槛只比较本地趋势，可显式调整；首轮报告用于建立基线，常规跨机器门禁不硬编码绝对耗时。样本数量较少的创建/保存/加载指标仅作粗粒度信号，重复运行后再判断退化。时间单位 ms，存档大小 bytes。

首份已接受图形基线保存在 [baselines](baselines/windows-large.md)。engine_to_test_scene_ready_ms 记录引擎启动至测试场景 ready；创建工厂、验证保存、验证加载分别计时。参考和优化模拟更新的计时边界相同，优化路径包含监测开销。

task27-legacy-blueprint-dyson-save.json 是任务 27 修复前的本地代码实际成功写出的合成存档，含浮点蓝图旋转与戴森轨道几何。原摘要 5cef5ebf27b5bb1c6eca7528b59e62e10f846751f79b494b5b5a434ca9f53ab0 保留；新代码实际读取它，以验证摘要兼容和蓝图/太阳帆所有权。它没有玩家数据，不是 DSPONLINE 旧档导入夹具，也不授予对齐 key。

task27-legacy-metadata-save.json 是任务 27 世界设置修复前，本地主树旧 setter 和 SaveSystem 实际成功写出的合成存档。标签包含旧规则接受的纯 NBSP、全角空格和 BOM；原摘要 d53df4abced34d6070f9651d386c503c0e98bd97b38931f5fd519f873cb3ab9c 保留。专项要求加载、原元数据及再次保存后的完整拥有权保持，不能通过静默规范化旧内容修复。没有玩家数据，不是 DSPONLINE 旧存档导入。

task27-legacy-survey-save.json 是世界指令修复前，本地主树实际成功写出的已支付、半程、延迟解锁的源星系勘探存档。文件 SHA-256 为 ff2587150e9780672e5bf4178e9af8241d760b7401c751dfb7bf4df48dd75167，磁盘原摘要 ca53bc0584ed70634ce8917d17989129c3b92e83a31813706f4547e9ef3886aa；现有 reader 在验证原摘要后返回迁移后的摘要 0156f21cfc6ca82d398cae003d335c50a554e863632f766b809f0422a7742541，两者按各自契约检查。专项要求完整持久拥有权往返、后半程完成、重复接续不再次收费；没有改变 reader 摘要或导入 DSPONLINE 旧档。

task27-legacy-survey-progress-save.json 是同一旧主树实际接受并写出的原生星系已解锁、进度 0.999999 的存档，验证已有 is_equal_approx 容差继续有效。它必须按原值加载、再次保存和重开，真正未完成的 0.9 仍被拒绝。两个夹具均为无玩家数据的本地合成兼容样本，不单独授予源对齐 key。
