# 单机对齐基线

- `dsponline_source_catalog.json`：源目录原始定义、来源提交、文件哈希、目录规模。
- `dsponline_source_catalog.sha256`：冻结目录字节校验。更新源版本需要显式重导出并审查差异。
- `dsponline_single_player_manifest.json`：每项对应目标、状态、缺口和任务归属。
- `rule_cases.json`：每项验收规格及当前行为验证状态。pending_behavior 是待完成规格，不是已通过的玩法测试。
- `exclusions.json`：逐项固定在线白名单和按用户要求排除的移动/语言回调。

登记门（不需要安装 DSPONLINE）：

```powershell
./tools/check_dsponline_parity.ps1
```

对照本地参考源码文件哈希：

```powershell
./tools/check_dsponline_parity.ps1 -SourcePath ../DSPONLINE
```

最终发布门：

```powershell
./tools/check_dsponline_parity.ps1 -RequireComplete
```

当前发布门预期失败，因为逐项源行为与完整旅程还未完成任务 27 验收。登记门拒绝缺失条目、无规则规格、无解释缺口、非法映射、重复 ID、未登记在线排除和只有文字“已验证”却没有运行证据的记录。今后应在 TestDSPOnlineParity 中执行真实行为比较，将通过的 key 交给验证器；仅修改 manifest/case 的标记不能通过。

更新源基线（显式维护动作，不是日常门禁的一部分）：

```powershell
./tools/export_dsponline_parity.ps1 -SourcePath ../DSPONLINE
```

需要 Node 24 的 TypeScript 类型剥离功能；只加载四个已审查的纯目录模块。要求源 Git 工作区干净，记录当前提交。日常 Godot 门禁不依赖 Node 或参考仓库。

`tools/build_parity_matrix.mjs` 是首次建立候选映射的工具，会覆盖 manifest、规则规格和矩阵；后续人工完善映射或行为证据后不要直接重跑。其同名/同函数名结果均为候选，不是行为一致证明。

操作枚举范围为桌面组件显式回调契约、engine 的公开状态操作/查询、动态命令族；不包含触摸控件和网络内部实现。多个回调可能属于同一玩家操作，目录数量不等于玩法数量。场景并不宣称完整原版行为已通过，最终行为金标由任务 27 验证。

任务 26 的 behavior/task26-*.json 包含真实执行冻结源导出的星图、航线、合同、戴森、恒星系施工/模块、枢纽、装饰和内容包金标。新增内容包夹具有 13 个清单与 72 个版本范围，并记录源哈希；导出工具 tools/export_task26_content_packs_gold.mjs 要求冻结提交和干净源工作区。扩充源来源文件后更新目录字节校验，不更改冻结提交或源定义。适配差异见 [任务 26 验收](../../../docs/current/TASK26_ACCEPTANCE.md)。
