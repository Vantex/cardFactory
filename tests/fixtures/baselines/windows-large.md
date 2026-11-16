# 本地性能报告

环境：{"cpu":"13th Gen Intel(R) Core(TM) i5-13500H","display":"Windows","fixture":"large","fixture_version":1,"godot":"4.7.2-stable (official)","gpu":"NVIDIA GeForce RTX 3050 4GB Laptop GPU","measurement":"synthetic local trend; no universal time threshold","os":"Windows","renderer":"gl_compatibility","stations":64,"ticks":30,"viewport":"1152x648"}

Times are wall-clock durations. draw_submit_ms measures CPU command submission, not GPU time. frame_ms and frame_interval_ms include rendering, scheduling and vsync waits. Headless has no graphical FPS evidence. Monitoring never changes fixed ticks.

| 指标 | 样本 | 平均 | P50 | P95 | 最大 |
|---|---:|---:|---:|---:|---:|
| engine_to_test_scene_ready_ms | 1 / 1 | 2971.269 | 2971.269 | 2971.269 | 2971.269 |
| fixture_create_ms | 1 / 1 | 4.777 | 4.777 | 4.777 | 4.777 |
| reference_update_ms | 30 / 30 | 43.436 | 43.268 | 44.767 | 44.912 |
| phase_dyson_decay_ms | 30 / 30 | 0.003 | 0.003 | 0.004 | 0.004 |
| phase_power_ms | 30 / 30 | 6.387 | 6.376 | 6.843 | 6.909 |
| phase_production_ms | 30 / 30 | 2.457 | 2.422 | 2.688 | 2.718 |
| phase_handcraft_ms | 30 / 30 | 0.003 | 0.003 | 0.004 | 0.004 |
| phase_belt_ms | 30 / 30 | 4.844 | 4.753 | 5.569 | 5.669 |
| phase_logistics_ms | 30 / 30 | 7.069 | 7.022 | 7.412 | 7.443 |
| phase_dyson_launch_ms | 30 / 30 | 0.469 | 0.458 | 0.592 | 0.620 |
| phase_galaxy_ms | 30 / 30 | 0.004 | 0.004 | 0.005 | 0.005 |
| phase_research_ms | 30 / 30 | 0.287 | 0.287 | 0.319 | 0.320 |
| phase_endgame_ms | 30 / 30 | 0.003 | 0.003 | 0.003 | 0.004 |
| phase_progression_ms | 30 / 30 | 1.143 | 1.072 | 1.904 | 2.196 |
| phase_statistics_ms | 30 / 30 | 0.002 | 0.002 | 0.003 | 0.003 |
| fixed_tick_ms | 30 / 30 | 22.699 | 22.570 | 23.874 | 24.217 |
| optimized_update_ms | 30 / 30 | 22.711 | 22.584 | 23.886 | 24.230 |
| serialize_ms | 1 / 1 | 87.315 | 87.315 | 87.315 | 87.315 |
| save_bytes | 1 / 1 | 332165.000 | 332165.000 | 332165.000 | 332165.000 |
| file_write_ms | 1 / 1 | 0.347 | 0.347 | 0.347 | 0.347 |
| save_verified_ms | 1 / 1 | 226.267 | 226.267 | 226.267 | 226.267 |
| load_verified_ms | 1 / 1 | 93.737 | 93.737 | 93.737 | 93.737 |
| reference_card_draw_submit_ms | 32 / 32 | 108.704 | 108.836 | 111.954 | 113.022 |
| reference_connection_draw_submit_ms | 32 / 32 | 9.327 | 9.360 | 9.861 | 10.141 |
| reference_frame_ms | 30 / 30 | 227.039 | 226.131 | 233.153 | 235.231 |
| optimized_card_draw_submit_ms | 32 / 32 | 16.884 | 16.496 | 20.143 | 24.687 |
| optimized_connection_draw_submit_ms | 32 / 32 | 1.836 | 1.771 | 2.011 | 2.947 |
| optimized_frame_ms | 30 / 30 | 35.967 | 35.515 | 40.975 | 41.312 |
