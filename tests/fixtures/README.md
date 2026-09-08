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
