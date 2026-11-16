# 本地性能报告

环境：{"cpu":"13th Gen Intel(R) Core(TM) i5-13500H","display":"Windows","fixture":"medium","fixture_version":1,"godot":"4.7.2-stable (official)","gpu":"NVIDIA GeForce RTX 3050 4GB Laptop GPU","measurement":"synthetic local trend; no universal time threshold","os":"Windows","renderer":"gl_compatibility","stations":16,"ticks":30,"viewport":"1152x648"}

Times are wall-clock durations. draw_submit_ms measures CPU command submission, not GPU time. frame_ms and frame_interval_ms include rendering, scheduling and vsync waits. Headless has no graphical FPS evidence. Monitoring never changes fixed ticks.

| 指标 | 样本 | 平均 | P50 | P95 | 最大 |
|---|---:|---:|---:|---:|---:|
| engine_to_test_scene_ready_ms | 1 / 1 | 2971.269 | 2971.269 | 2971.269 | 2971.269 |
| fixture_create_ms | 1 / 1 | 1.180 | 1.180 | 1.180 | 1.180 |
| reference_update_ms | 30 / 30 | 9.631 | 9.537 | 10.298 | 10.953 |
| phase_dyson_decay_ms | 30 / 30 | 0.002 | 0.002 | 0.003 | 0.003 |
| phase_power_ms | 30 / 30 | 2.003 | 1.995 | 2.202 | 2.237 |
| phase_production_ms | 30 / 30 | 0.595 | 0.587 | 0.652 | 0.790 |
| phase_handcraft_ms | 30 / 30 | 0.002 | 0.002 | 0.003 | 0.003 |
| phase_belt_ms | 30 / 30 | 1.185 | 1.159 | 1.453 | 1.485 |
| phase_logistics_ms | 30 / 30 | 0.602 | 0.590 | 0.669 | 0.676 |
| phase_dyson_launch_ms | 30 / 30 | 0.086 | 0.084 | 0.095 | 0.109 |
| phase_galaxy_ms | 30 / 30 | 0.002 | 0.002 | 0.003 | 0.003 |
| phase_research_ms | 30 / 30 | 0.068 | 0.067 | 0.073 | 0.077 |
| phase_endgame_ms | 30 / 30 | 0.002 | 0.002 | 0.003 | 0.003 |
| phase_progression_ms | 30 / 30 | 0.286 | 0.276 | 0.335 | 0.545 |
| phase_statistics_ms | 30 / 30 | 0.001 | 0.001 | 0.002 | 0.002 |
| fixed_tick_ms | 30 / 30 | 4.854 | 4.816 | 5.169 | 5.348 |
| optimized_update_ms | 30 / 30 | 4.861 | 4.823 | 5.176 | 5.354 |
| serialize_ms | 1 / 1 | 21.026 | 21.026 | 21.026 | 21.026 |
| save_bytes | 1 / 1 | 83844.000 | 83844.000 | 83844.000 | 83844.000 |
| file_write_ms | 1 / 1 | 0.125 | 0.125 | 0.125 | 0.125 |
| save_verified_ms | 1 / 1 | 58.248 | 58.248 | 58.248 | 58.248 |
| load_verified_ms | 1 / 1 | 24.773 | 24.773 | 24.773 | 24.773 |
| reference_card_draw_submit_ms | 32 / 32 | 37.267 | 37.143 | 38.734 | 39.000 |
| reference_connection_draw_submit_ms | 32 / 32 | 2.246 | 2.220 | 2.457 | 2.756 |
| reference_frame_ms | 30 / 30 | 76.473 | 76.453 | 78.433 | 80.687 |
| optimized_card_draw_submit_ms | 32 / 32 | 16.434 | 16.014 | 17.548 | 24.610 |
| optimized_connection_draw_submit_ms | 32 / 32 | 0.718 | 0.710 | 0.803 | 0.818 |
| optimized_frame_ms | 30 / 30 | 32.659 | 32.506 | 35.040 | 35.762 |
