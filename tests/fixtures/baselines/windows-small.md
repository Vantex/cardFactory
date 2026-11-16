# 本地性能报告

环境：{"cpu":"13th Gen Intel(R) Core(TM) i5-13500H","display":"Windows","fixture":"small","fixture_version":1,"godot":"4.7.2-stable (official)","gpu":"NVIDIA GeForce RTX 3050 4GB Laptop GPU","measurement":"synthetic local trend; no universal time threshold","os":"Windows","renderer":"gl_compatibility","stations":2,"ticks":30,"viewport":"1152x648"}

Times are wall-clock durations. draw_submit_ms measures CPU command submission, not GPU time. frame_ms and frame_interval_ms include rendering, scheduling and vsync waits. Headless has no graphical FPS evidence. Monitoring never changes fixed ticks.

| 指标 | 样本 | 平均 | P50 | P95 | 最大 |
|---|---:|---:|---:|---:|---:|
| engine_to_test_scene_ready_ms | 1 / 1 | 2971.269 | 2971.269 | 2971.269 | 2971.269 |
| fixture_create_ms | 1 / 1 | 0.209 | 0.209 | 0.209 | 0.209 |
| reference_update_ms | 30 / 30 | 1.128 | 1.115 | 1.184 | 1.401 |
| phase_dyson_decay_ms | 30 / 30 | 0.002 | 0.001 | 0.002 | 0.003 |
| phase_power_ms | 30 / 30 | 0.688 | 0.678 | 0.746 | 0.755 |
| phase_production_ms | 30 / 30 | 0.076 | 0.075 | 0.082 | 0.083 |
| phase_handcraft_ms | 30 / 30 | 0.002 | 0.002 | 0.002 | 0.002 |
| phase_belt_ms | 30 / 30 | 0.134 | 0.133 | 0.142 | 0.146 |
| phase_logistics_ms | 30 / 30 | 0.040 | 0.038 | 0.047 | 0.075 |
| phase_dyson_launch_ms | 30 / 30 | 0.011 | 0.011 | 0.012 | 0.014 |
| phase_galaxy_ms | 30 / 30 | 0.002 | 0.002 | 0.002 | 0.003 |
| phase_research_ms | 30 / 30 | 0.011 | 0.011 | 0.012 | 0.013 |
| phase_endgame_ms | 30 / 30 | 0.001 | 0.001 | 0.002 | 0.002 |
| phase_progression_ms | 30 / 30 | 0.062 | 0.059 | 0.068 | 0.142 |
| phase_statistics_ms | 30 / 30 | 0.001 | 0.001 | 0.001 | 0.002 |
| fixed_tick_ms | 30 / 30 | 1.044 | 1.030 | 1.123 | 1.252 |
| optimized_update_ms | 30 / 30 | 1.048 | 1.033 | 1.127 | 1.259 |
| serialize_ms | 1 / 1 | 2.836 | 2.836 | 2.836 | 2.836 |
| save_bytes | 1 / 1 | 11789.000 | 11789.000 | 11789.000 | 11789.000 |
| file_write_ms | 1 / 1 | 0.240 | 0.240 | 0.240 | 0.240 |
| save_verified_ms | 1 / 1 | 13.177 | 13.177 | 13.177 | 13.177 |
| load_verified_ms | 1 / 1 | 5.916 | 5.916 | 5.916 | 5.916 |
| reference_card_draw_submit_ms | 32 / 32 | 19.082 | 17.949 | 19.206 | 52.580 |
| reference_connection_draw_submit_ms | 32 / 32 | 0.352 | 0.332 | 0.487 | 0.833 |
| reference_frame_ms | 30 / 30 | 34.306 | 33.908 | 36.853 | 36.966 |
| optimized_card_draw_submit_ms | 32 / 32 | 14.868 | 14.679 | 15.431 | 20.227 |
| optimized_connection_draw_submit_ms | 32 / 32 | 0.064 | 0.063 | 0.067 | 0.113 |
| optimized_frame_ms | 30 / 30 | 28.265 | 28.198 | 29.480 | 30.760 |
