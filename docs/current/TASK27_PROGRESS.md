# 任务 27 执行进度

## 接续记录（2026-11-16）

- 在下述资源输出集成后，矿机批量安装的 703 个冻结源命令对照与 16 份实际付费安装主档重开通过（`install-valid-world.json`）。四个远端资源曾因测试状态缺勘探前置保存失败；补齐测试前置后通过，未将控制状态算作赚取成长。定义专项复用 live60 真源金标，240 个实际采矿案例产生 16 个原矿/流体及 3 个采集器的具体断言（`resource-definitions.json`）。两项专项退出 0、各一个成功标记，均尚未接入总门或登记。正式 UI 新安装按钮尚待重验，65 场景声明和 262 已登记不变。
- 续作先复现实际组规模对需电及退款的影响：安装写 `machine_count`，相关两个逻辑仍调用仅读 `station_stack_count` 的查询。然后按设备、光标、托盘的同一拥有权边界完成物资操作及各入口，详见 [开发现状与续作指南](DEVELOPMENT_HANDOFF.md)。未做新全量门、打包或最终发布验收。

## 当前执行：采用新工作流，B1 资源与开局（2026-10-07）

用户已要求按 [工作流调整方案](TASK27_WORKFLOW_PROPOSAL.md) 继续完成任务 27。现有台账已对全部 811 个待验收条目完成第一遍归组：B1 40、B2 505、B3 121、B4 81、B5 64；只是调度归组，没有授予验证状态。矩阵仍为 262 已验证、514 实现中、297 未实现、26 在线排除。

B1 输入为现有 MAIN 初始储量基线和 `.godot/task27-manual-probe/` 手采候选。批次交付条件：资源输出具备唯一所有者，手采/自动生产/领取/实际带运输/保存接续闭合；正常、近满仓、旧小数、失败无副作用及正式 UI 入口通过；从真实新游戏获得材料、制造、首研究并重开续产；只有完整具体契约得到断言的 key 才登记。所有 40 项继续逐项核实，专项通过不能代替整个批次完成。

- 资源输出的 9 个产品文件已从唯一候选接入 MAIN，用户 `project.godot` SHA `6bfd8d91…` 保持。真实 Godot 的 `float-before.json` 退出 1、11 个失败；累计扣减和按原始库存计算手采空位修复后通过。独立复核发现的旧原生矿机分流问题另有 `legacy-buffer-before` 两个失败及 `after` 通过，分流要求源目录 `source_id`，保持原生自有缓存。
- 已把手采、领取、拥有权接续、正式 UI、边界、小数和真实开局旅程接入现有测试入口。`main-b1-formal2.json` 实际退出 0，7 个唯一成功标记，无脚本/解析/生命周期泄漏；首轮新增测试的类型推断错误已修正，失败记录保留。现声明 65 场景，本轮不是新的全量门。
- 本批相关检查已通过：208 源手采案例；1536 资源领取/32 主档；176 流程/880 主档接续/352 实际 60 tick 会话；13 固体与 3 流体正式 UI、13 主档；旧容量、模拟、库存、物流和戴森等受影响场景。源领取夹具只证明资源分支，不授整个设备领取端点。
- 真实新游戏旅程使用实际施工件、三风机供电、矿脉手采/收取、矿机到矿炉的付费传送带、制造三个蓝矩阵、实验室首研究、primary 重开和继续采矿；不注入材料/科技。JSON 往返只允许数值绝对误差 `1e-12`，其余结构严格一致。有界只读复核已关闭已发现问题，不表示最终审查或人工通关。
- 当前证据入口：`.godot/task27-next-resource-manual/`。旧 focused 7/8、边界修正和先前各批通过记录保留历史语境。

下一步：集中补齐 B1 矿机批量安装和托盘/光标/设备之间的物资操作契约；手采已接入完整行为汇总和登记映射，但尚未运行更新后的完整 harness、登记新 key 或更新 Windows 包。批次稳定前不重复运行旧昂贵总门。

## 既有执行与历史证据

任务仍在进行；本文件记录已运行证据及下一批工作，不是发布验收。起点 `d1d3690`，当前改动尚未提交，用户的 `project.godot` 修改继续保留。

## 已完成批次

- 建立 1099 项可追溯覆盖清单及差异台账；行为运行器把逐 key 实际断言接入登记门。伪造状态、部分断言、错误源版本、夹具漂移及未知 key 均有拒绝检查。
- 修复三种源传送带中的 Mk.I/Mk.II 额定速度：6/12/30 每秒。9 个容量组合、实际运输守恒、禁用和保存往返通过；3 个 belt key 各有 13 条实际断言，已登记为“已验证”。原生旧带明确的 flow_rate 保持兼容。
- 修复新游戏原矿和施工件库存、Q/W/E/R/T 对应源施工件、源成长指引，以及研究首次完成的施工件奖励。旧存档教学库存不迁移；已付施工件允许直接部署。
- 普通/速通 × 三档难度开局及磁盘保存通过。76 个科技定义的奖励、重复完成和行星解锁边界通过；不表示 76 项完整研究旅程全部通过。
- 自动旅程从真实开局原矿制造 3 枚蓝矩阵，实验室真实消耗并完成首项研究，保存通过。原生教学链使用实际 v9 旧档继续入口另行验证；没有把注入旧档旅程记为源新游戏通关。
- 冻结源执行器可以直接加载完整源游戏引擎；不写参考仓库，不加载网页组件或服务器。基础金标由真实完整 createInitialState 和 completeTechnology 生成，新增实际加载模块哈希，不改变冻结提交和目录定义。
- 补齐生产计划计算与正式分析入口，支持名称/物品/目标产量/行星范围/替代配方、删除及 schema v9 保存。8 个源计算场景和 8 个命令金标通过；4 个具体回调已取得行为证据，统计工作区整体仍保持未实现。普通配方生产金标正在进一步运行。
- 73 个有材料输出的普通配方已执行完整源引擎金标并完成实际转换、前置科技、缺料/满缓存/断电及部分周期保存检查。单位适配后，半周期固定步结果也通过；按源每步六位舍入计算相位误差界限，没有通过修改预计消耗/产出消除差异。73 个具体 recipe key 已登记，其余 7 个专用配方由后续独立批次验证，见下文。
- 第一批独立审查发现并修复登记器缺少指纹、计划按钮焦点冻结、名称失焦丢失和旧物品错误计算。登记器现在要求完整 138 个代码/目录依赖集合，拒绝缺代码、缺目录、额外路径及旧内容。真实焦点回归还覆盖研究完成时草稿保持、关闭分析页保存。
- 修复普通源生产漏用行星工业特化倍率，12 个特化行星的材料与周期相位金标通过；原生旧建筑保留原有计算。修复源施工件总数显示 0，六种开局与正式桌面现显示 13 个建筑件，不含传送带与旧额度。
- 源普通设备配方切换的 5 个命令金标通过：重复选择保留相位，切换返还全部缓存和付费线路，科技/设备锁定及不兼容选择不变，v9 保存往返通过。退款保持设备所在行星，容量不足原子拒绝，这是守恒适配；专用能量/射线分支尚未全部比较，不把整个 endpoint 登记为已验证。补查的自动选配方失败会拒绝连线并保留带件。
- 内容包计划的四种实际源状态通过：锁定/解锁、半利用率自定义机器、前缀相近但不同的科技 ID。正式选择器随目录变化刷新，设备名称正确，计划保护包引用且真实磁盘往返通过。独立复核发现的配方/科技前缀误匹配和合法长名称导致保存失败均有失败复现；长名称提前应用源读档的 40 字上限。此专项不将完整内容包或统计工作区登记为已验证。
- 专用设备命令已补 24 个完整冻结引擎案例。源能量枢纽的配方选择与充放电切换分开；切换返还缓存和付费带件、保留真实能量及喷涂余量，重复模式不改写配方。批量配置先合计行星容量及带件退款，容量不足全部不变。射线切换立即刷新源接收站功率/效率，并使用未舍入发电量、排除满光子缓存。普通 5 个命令、电网和戴森专项通过；专用生产及整体命令证据仍继续补，不提前标绿 endpoint。
- 七个专用配方的 49 个实际源模拟和 21 个中周期磁盘接续检查通过。修复配方独立科技门限、专用产率/利用率、整颗电池容量、微量残余幽灵电池及光子分配/生产精度不一致。源实验室和发射器真实断电时均停止；重开保存后完整持久所有权与不间断模拟一致。递归核对仅接受 JSON 数值类型和最后浮点位差异，绝对误差上限 1e-9。源取整丢弃的小数缓存与本地连续物流的实有余量分别检查：整颗投影与原始源金标一致，本地小数所有权在转换和磁盘接续后保留，明确记录守恒适配。
- 最新总门实际通过 87 个 key 和拒绝检查，141 个实现依赖指纹匹配；七个专用配方已登记。复审指出的失败总门仍写证据已修复：开始即作废旧报告，仅全部通过时写入成功状态与当前 manifest 哈希。刻意失败场景退出 1 且证据不存在，Node 登记器拒绝，manifest/rules/matrix 哈希未变。
- 专用设备与证据门禁的有界只读复审关闭此前两处 P2，未发现新的高置信度问题；该结论不代表任务 27 的最终审查。
- 有限研究新增 496 个实际源边界：69 项有效科技的半周期、首次/末次支付、前置条件、停止与完成奖励，以及 7 项弃用定义的拒绝。首轮恰有 69 个完成账本清空失败，修复后通过；仅源研究桥保留投入与累计进度，旧原生清理分支保留。69 科技各两次磁盘保存均在未完成相位，138 次接续的完整持久状态与不间断执行一致。源与本地输入资助已完成/已领奖战役，避免把其他奖励混入研究专项；不证明全成本成长旅程。
- 有限研究复审发现“暂停后重选必然不变”与实际源金标相反，已修复命令与断言：源科技可重选恢复，选择/暂停/恢复清零源实验室相位，重复断言直接使用导出的实际源结果。496 案例专项及 29 场景完整门通过；143 依赖与各类拒绝检查匹配，76 科技 key 已登记，累计 163 项。
- 研究命令扩为 30 个真实源命令及各自前/后实际源存档迁移。双实验室相位、独立源暂停、队列级联/跳过、完整成本边界和连续结算、无效及重复选择通过；60 份独立目录磁盘保存与完整规范状态一致。保持实时队列及材料账本，编码仅在静默副本上按源读档规则生成规范结果，不发全局完成/队列事件。旧 v9 源暂停迁移与原教学暂停、二者共存保存也通过。新增专项已接入 30 场景门及 145 项依赖；未给含无限研究分支的 endpoint 授予新 key。
- 本批有界独立审查发现教学暂停当前行的无效排队按钮；实际内容包回归另复现规范编码遗漏实时阻塞研究引用。两者均先复现失败再修复：当前行按当前 ID 禁用，正式保护同时保留原始当前/暂停/队列引用。专项从恰 3 个失败转为通过。完整门首轮另检出零成本科技虚假进度及保存失败，已按真实成本修复：零成本进度为 0，付费自定义成本 2 的时长为 6；实际实验室两次支付与 2 次磁盘保存通过。30 场景完整门、163 key、145 项依赖和证据拒绝检查通过，有界复审关闭已发现问题；此次审查不是任务 27 最终审查。
- 无限研究本批已扩为 115 个源模拟、15 个命令和 65 个精确预算，195 份结果存档及 25 次未完成周期接续通过；补齐持续供料整步结算、60 Hz、部分喷涂低供电、六位相位舍入和微小工作量 EPS 停止门。研究查询新增 15 状态 × 78 个科技 ID 的 1170 行实际源返回值；先复现 946 个差异，修复后 4 个 query key 专项通过，原始与规范拥有权同时保持。 原 45 模拟批次复现 249 个失败和正式 UI 6 个失败后修复；复审扩充又以真实源/Godot 复现持续供料余时重用 68 个失败、原 EPS 判定 40 个失败、正确单风机部分喷涂 12 个失败及微量工作量停止 40 个失败，均有绿证据。首次补风机案例错误展开源聚合数量，已改为真实公开放置 1 台，不把误映射的功耗失败作为修复证据。源积分、精确预算、有限/无限并存、独立自动续层、JSON 合法整数优先级和正式 Main 控制均通过。有界复审关闭已发现问题；32 场景完整门通过，149 个依赖和 7 个新 key 已登记；该阶段的结算批次随后完成，2 个新 key 已登记，不授予不存在的五种定义 key 或全成长结论。

- 研究完成边界新增 76 定义 × 6 个成本状态和 10 个命令状态，466 对纯/原地接口结果及 238 次实际磁盘往返专项通过。纯接口保持原始与规范输入拥有权且不发送实时完成/解锁/队列事件；原地接口返回精确有序完成列表，重复结算不再奖励。资助输入改为通过真实源公开接口完成星际研究，记录其殖民及施工奖励，不能把不一致输入导致的 235 个迁移差异当成本地运行修复。该批有界复审已关闭问题，33 场景门退出 0，33 个唯一成功标记、172 个实际 key 和 151 个依赖均通过，2 个 key 已登记。
- 研究控制端点新增 64 个实际源不可变命令，复用既有有限/无限场景输入后重新执行完整源引擎，另覆盖全部七个弃用定义的闲置/队列拒绝、空 ID 和深层依赖移除。64 案例及 128 次前/后真实磁盘往返首轮通过；没有虚构红绿修复。有界复审发现 14 个弃用目标仍已完成，不能单独证明弃用条件拒绝；新增未完成/前置已完成/非当前非队列预置断言，重新导出冻结源结果。首个 34 场景门已主动中止，不作为通过；修正金标后专项与独立复审通过，第二轮 34 场景门退出 0，177 个实际 key/153 个依赖、全部拒绝检查与 100 源文件哈希通过，5 个 endpoint key 已登记，不等同于完整成长。

## 当前证据

| 范围 | 本地日志 | 结果与限制 |
|---|---|---|
| 完成边界专项 | .godot/task27-research-boundaries-after.log | 466 对接口及 238 次磁盘往返退出 0，有界复审已关闭；2 key 已登记 |
| 完成边界完整门 | .godot/task27-research-boundaries-full-gate.log | 退出 0，33 个唯一成功标记、172 key/151 依赖及全部拒绝检查通过，2 个结算 key 已登记 |
| 研究控制首轮 | .godot/task27-research-controls-before.log | 首轮退出 0，但弃用目标已完成，不能独立证明弃用拒绝；后续已修正 |
| 弃用预置红/绿 | .godot/task27-research-controls-deprecated-before.log / -after.log | 原金标被 14 个独立预置检查拒绝，实际源重新导出后 64 案例/128 次保存通过，复审关闭 |
| 研究控制完整门 | .godot/task27-research-controls-full-gate2.log | 34 个唯一成功标记，177 key/153 依赖与 100 源文件哈希通过，5 key 已登记 |
| 战役/成就初轮与修复专项 | .godot/task27-progression-boundaries-before.log / -power-after.log | 353 个源边界加 6 个实际待领奖重开序列、166 次保存，45 key 专项通过；本批复审已关闭 P2，35 场景完整门通过，45 个定义 key 已登记 |
| 战役/成就完整门 | .godot/task27-research-progression-full-gate.log | 退出 0，35 个唯一成功标记、222 key/158 依赖、全部拒绝检查与 100 源文件哈希通过；45 个定义已登记 |
| 源传送带真实差异复现 | `.godot/task27-belts-before.log` | Mk.I/Mk.II 的容量和运输断言失败；Mk.III 通过 |
| 传送带修复及证据门 | `.godot/task27-registered-gate.log` | 3 个 key 及拒绝检查通过；后来完整引擎重导金标须刷新证据 |
| 画布正式传送带检查器 | `.godot/task27-canvas-belts.log` | 额定速度、并联堆叠和真实运输通过 |
| 新开局及首项研究 | `.godot/task27-startup-journey.log` | 开局、奖励边界和原矿到首项研究通过 |
| 24 场景全量门 | `.godot/task27-first-full-gate.log` | 退出 0，24 个唯一成功标记，无脚本错误或生命周期泄漏；针对当时金标和代码 |
| 计划正式操作及保存 | `.godot/task27-planning-controls2.log` | 8 个计算、8 个命令、正式增删改和替代配方、有效保存和损坏拒绝通过 |
| 计划回调登记门 | `.godot/task27-planning-registered.log` | 7 个具体 key 通过；源计划命令失败会撤回对应 key |
| OpenGL 产品界面 | `.godot/task27-product-planning3.log` | 包含 1080p 计划页及 1000×600 大字号，成功标记齐全；截图已检查，后续缩短说明文字需在最终门中复核 |
| 统计/资料库布局回归 | `.godot/task27-statistics-plan-layout.log` | 既有统计、诊断、资料库和定位检查通过 |
| 73 配方半周期固定步 | `.godot/task27-production-half-cycle.log` | 实际输入/输出与归一化相位通过，无脚本错误或泄漏 |
| 80 key 实际证据 | `.godot/task27-recipe-evidence2.log` | 73 配方边界、3 传送带、4 计划操作通过；坏产出金标撤回对应 recipe key |
| 26 场景阶段全量门 | `.godot/task27-second-full-gate.log` | 退出 0，26 个唯一成功标记，无脚本错误或生命周期泄漏；早于本批审查修复 |
| 计划焦点红/绿 | `.godot/task27-planning-focus-before.log` / `-after.log` | 实际 grab_focus 与失焦提交；按钮保持焦点时库存更新；不支持的旧物品不进入源计划选择器 |
| 研究期间草稿红/绿 | `.godot/task27-planning-draft-before.log` / `-after.log` | 研究刷新保留焦点和草稿，关闭分析页保存 |
| 行星生产红/绿 | `.godot/task27-industrial-before.log` / `-after.log` | 12 个源特化行星的相位真实失败后修复，73 个基线配方同时通过 |
| 配方切换红/绿 | `.godot/task27-recipe-commands-before2.log` / `-after.log` | 5 个命令、缓存/5 段付费带件退款与容量拒绝通过 |
| 锁定设备自动连接红/绿 | `.godot/task27-locked-auto-recipe-before.log` / `-after.log` | 失败选配方不扣带件，不创建连接 |
| 施工件计数红/绿 | `.godot/task27-kit-counter-before.log` / `-after.log` | 六种真实开局、首项研究及保存通过 |
| 审查修复产品门 | `.godot/task27-product-review-fixes.log` | OpenGL 正式施工件计数、1080p 与小窗口计划页通过；截图待本批最终复核 |
| 更新后的 80 key 登记门 | `.godot/task27-refreshed-registered.log` | 当时 138 个依赖指纹及更新计划金标通过；性能优化后须刷新 |
| 27 场景审查修复全量门 | `.godot/task27-third-full-gate.log` | 退出 0，27 个唯一成功标记，无脚本错误、解析错误或生命周期泄漏；早于性能优化 |
| 正式 Windows EXE 独立启动 | `.godot/task27-standalone-boot.log` | release EXE/PCK 无编辑器、参考源或 Node 的 headless 启动，运行目录完整；不代表图形或完整旅程 |
| Windows 两进程自动旅程 | `.godot/windows-package-check/ebf00047f3ff425d8bbcf706c9828f5e/` | 相同 EXE/PCK 外部临时 autoload；干净开局、真实首项研究、计划编辑、保存退出、新进程继续、损坏主档和正式快照恢复通过；玩家档案隔离，自动信号调用不算人工 |
| 同机 OpenGL 三档性能 | `.godot/task27-performance.log` | 与任务 18 的 context 全部一致；中/大固定步和三档保存超旧趋势门，任务 26 对照与根因调查进行中 |
| 保存 metadata 损坏红/绿 | `.godot/task27-commit-metadata-before.log` / `-after.log` | 改写后主档的 metadata 不同也须拒绝；临时档完整验证、备份与失败恢复保留 |
| 电力动态环境 | `.godot/task27-power-refresh.log` | 下一步读取改变的亮度/难度/个体倍率，跨行星及跨电网分配正确 |
| 性能修复后三档 OpenGL | `.godot/task27-performance-optimized4.log` | 三档均通过任务 18 旧趋势门；大型固定步仍非 60 Hz，完整边界见性能复核 |
| 性能批次完整门 | `.godot/task27-performance-full-gate.log` | 退出 0，27 个唯一成功标记，无脚本/解析错误或生命周期泄漏；早于内容包计划修复 |
| 内容包计划前缀红/绿 | `.godot/task27-planning-prefix-before.log` / `-after.log` | 合法相近 ID 保持不同的配方、设备与科技门限；四种实际源计算通过 |
| 长名称保存红/绿 | `.godot/task27-planning-long-name-before.log` / `-after.log` | 正式创建长名称计划与真实磁盘读回从失败转为通过；源 storage 实际迁移金标独立记录 |
| 内容包批次 80 key 登记门 | `.godot/task27-pack-planning-80-registered.log` | 当时 100 文件冻结源台账、138 个实现依赖指纹及实际行为/拒绝检查通过；后续专用设备修改须刷新 |
| 内容包批次完整门 | `.godot/task27-pack-planning-full-gate.log` | 退出 0，27 个唯一成功标记，无脚本/解析错误或生命周期泄漏 |
| 内容包批次 OpenGL 产品门 | `.godot/task27-pack-planning-product.log` | 正式工作区与分辨率/字号检查通过，计划页截图已查看；不代表人工旅程 |
| 当前 Windows 默认渲染器 | `.godot/task27-pack-planning-default.log` | D3D12 12_0 / Forward Mobile / RTX 3050，两个实际进程的局部自动旅程通过 |
| 当前 Windows OpenGL / headless | `.godot/task27-pack-planning-opengl.log` / `-headless.log` | 相同 EXE/PCK 的两个实际进程局部自动旅程均通过；不是人工或全成长链 |
| 专用设备命令红/绿 | `.godot/task27-special-commands-before.log` / `-after.log` | 初始真实源状态失败后修复，扩充至 23 个案例后通过；最后重复模式遗漏单独复现 |
| 重复模式红/绿 | `.godot/task27-special-repeat-mode-before.log` / `-after.log` | 24 个源命令、原有 5 个普通命令及合计容量预检通过；无脚本/解析错误或泄漏 |
| 专用电力/戴森回归 | `.godot/task27-special-power-regression.log` / `-dyson-regression.log` | 两个领域专项通过；重复模式的最后修改另有命令专项 |
| 专用模拟首轮红/绿 | `.godot/task27-special-production-before.log` / `-after.log` | 首轮材料/能量一致，专用指标缺失后修复；这份 7 案例日志早于扩充边界 |
| 26 个边界红/绿 | `.godot/task27-special-boundaries-before.log` / `-after.log` | 源发射配方的科技锁定和储能零输出键从失败转为通过 |
| 电池周期/容量红/绿 | `.godot/task27-special-cells-before.log` / `-after.log` | 32 例验证真正完成转换的瞬时产率及不足一颗输出空间的守恒 |
| 微量残余和竞争红/绿 | `.godot/task27-special-residual-before.log` / `.godot/task27-special-final.log` | 35 例从真实幽灵电池/分占能量失败转为通过；后续光子精度另查 |
| 光子精度红/最终绿 | `.godot/task27-special-photon-epsilon-before.log` / `.godot/task27-special-40-final.log` | 40 例和 14 个磁盘中周期接续通过，退出 0，无脚本/解析错误或生命周期泄漏 |
| 最新电力/戴森/命令 | `.godot/task27-special-current-power.log` / `-dyson.log` / `-commands.log` | 三个领域专项退出 0，唯一成功标记且无脚本/解析错误或泄漏 |
| 能源 EPS 与小数守恒红/绿 | `.godot/task27-special-energy-epsilon-before.log` / `.godot/task27-special-49-final.log` | 微量输出余量归一化；49 个源案例、21 次磁盘接续通过，小数所有权适配单独断言 |
| 失败总门拒绝登记 | `.godot/task27-harness-fault.log` / `.godot/task27-failed-harness-recording.log` | 实际失败退出 1、旧报告作废且不写新报告；Node 拒绝，三份登记文件哈希未变 |
| 专用设备批次 87 key 总证据门 | `.godot/task27-special-harness-green.log` | 退出 0、唯一成功标记、当时 87 个实际 key、141 个依赖及拒绝检查通过；后续研究由新总门覆盖 |
| 有限研究账本红/绿 | `.godot/task27-research-before2.log` / `.godot/task27-research-after.log` | 427 案例首轮恰 69 个 last_payment 清空失败；修复后 76 个 scope key 与 138 次未完成相位磁盘接续通过；重复选择语义随后复审修复 |
| 暂停重选语义修复 | `.godot/task27-research-repeat-selection-after.log` | 依据源实际重复选择状态，恢复暂停研究与 no-op 分开断言；427 案例通过 |
| 有限研究半周期/隔离 | `.godot/task27-research-496-final.log` / `.godot/task27-research-496-isolated.log` | 半周期真实源战役电力奖励干扰后，两边输入明确资助已领奖任务；496 案例通过，无脚本/解析/生命周期错误 |
| 有限研究完整门及登记 | `.godot/task27-research-full-gate2.log` | 退出 0，29 个唯一场景成功标记；163 个实际 key、143 个实现依赖、全部拒绝检查及正常报告通过，76 个科技 key 已登记 |
| 研究动态命令初轮红 | `.godot/task27-research-command-probe-before.log` | 10 个真实源命令中 5 组出现 13 个断言失败；完成边界、队列级联移除和独立暂停研究须修复，尚未登记 endpoint |

| 研究命令 30 场景完整门 | `.godot/task27-research-commands-full-gate2.log` | 退出 0，30 个唯一场景标记，163 key/145 依赖及拒绝检查通过；60 份源迁移保存与 2 次自定义付费保存通过 |
| 无限研究持续供料与原 EPS | `.godot/task27-infinite-funded-before.log` / `-funded-after.log`；`-epsilon-before.log` / `-epsilon-after.log` | 68 个余时重用及 40 个 EPS 失败转绿；实际源整步及固定步回归 |
| 本批低供电/舍入/停止 | `.godot/task27-infinite-low-power-before.log` / `-low-power-after.log`；`-epsilon-idle-before.log` / `-epsilon-idle-after.log` | 正确单风机 12 个失败、微小工作量 40 个失败转绿；最新 115 模拟/15 命令/65 预算专项通过，舍入红例在 review-boundaries-before 中单独核对 |
| 研究查询红/绿 | `.godot/task27-research-queries-permanent-before.log` / `-queries-final.log` | 946 个实际差异转绿，1170 行与 4 个 query key；新原始队列误清拒绝等待完整门 |
| 本次 32 场景完整门 | `.godot/task27-research-combined-full-gate.log` | 退出 0，32 个唯一成功标记，170 key/149 依赖、原始队列误清拒绝及全部总门检查通过；7 个 key 已登记，上次 31 场景中止不算通过 |

全量日志中的错误配方、无效保存路径属于拒绝用例；user:// 日志、编辑器设置和证书错误属于 sandbox 环境提示。不能只看退出码判定通过。

## 战役控制批次（已登记）

战役控制领域 138 个源案例和 138 次真实保存已通过；旧教学兼容、战役域切换、源任务顺序及读档不解锁成就的有界复审已关闭。正式 Main 的按钮、32 任务状态及 40 个源 App 回调对照已通过，修复禁用状态、行星/建筑定位、放置、银河入口和精确物品焦点；新增原矿聚焦禁止误制造其他配方。UI 批曾因额度中断；后续独立复审发现两条 P2，修复与变异拒绝证据见下文。修复后 38 场景门通过，5 个 callback/workspace key 已登记。

战役领域夹具仅资助其他完成记录、材料和设备缓存；138 次实际源保存结果重新执行，跨行星/设备输入输出/真实拾取货物的合计库存均比较。初轮主树 130 例复现 389 个差异；副本先扩到 131 并区分战役/成就读档，再以完整开局复现 6 条自动跟踪顺序差异、旧教学/自定义目录 3 条回归和缓存实例切换 1 条回归，均有红绿证据。追加库存案例曾使用小数缓存，被实际源存档拒绝；最终改为合法整数拆分输入，138 源案例已重新导出并复审全字段一致。货物适配遗漏的 8 条差异属于测试输入桥问题，补映射后通过，不当作产品缺陷。

UI 金标执行同一冻结 App.tsx 的真实回调代码；React setters、工作区和镜头调用为声明的宿主边界，行星变化和任务选择执行实际冻结引擎。40 例不是渲染 React 或人工键鼠。初轮 before.log 是测试搭建错误，不算产品红例；before2.log 是实际按钮/导航红例，focus-before.log 为 12 条精确物品聚焦红例，final.log 及 integrated.log 专项通过。完整门还会核对异步行为运行、缺失/重复/漂移回调、错误目的行星和错误材料缺口撤回所有 5 key。

新域标记为 schema v9 可选 progression_facts.source_campaign_enabled；新源经济显式启用，无标记旧档仅已有 DSP 跟踪时推断源战役。旧教学 source_galaxy 非空仍继续 native 任务；显式选择源任务使已创建模拟器刷新目录。当前 35 场景登记快照保留在 .godot/task27-research-progression-pre-record-evidence.json，不能用于后来运行树。

## 剩余与接续

当前矩阵 532 候选、227 已验证、314 未实现、26 在线排除；846 个非在线 key 尚待证据。研究控制第二轮 34 场景完整门通过：177 个实际 key/153 个实现依赖、全部拒绝检查及 100 源文件哈希一致，5 个控制 key 已登记。战役/成就新增 353 个实际源边界，已修复采矿设备误计工业星系、蓝图/轨道整数摘要及保存后供电查询丢失；353 个边界加 6 个真实待领奖重开/释放/补发序列、166 次磁盘往返和 45 个定义专项通过，已接入 35 场景总门与 158 个依赖；本批复审已关闭 P2，35 场景完整门已通过，222 个实际 key/158 个依赖及 100 源文件哈希一致，45 个定义 key 已登记。35 场景证据对应本次登记时的运行树；战役控制修复已接回主树；38 场景完整门已通过，5 个界面 key 已登记，UI 批两条 P2 独立修复复核已关闭。继续战役/成就、统计/喷涂/内容包和完整成长；当前包须重建。

最初 [发布清单](../testing/single-player-release-checklist.md) 已建立。官方 Godot 4.7.2 模板下载和 SHA512 校验完成；匹配的 x86_64 文件只提取到项目 `.godot/`，没有安装到系统模板目录。`export_presets.cfg` 与 `tools/export_windows.ps1` 已实际导出正式 release EXE/PCK，266 个资源的 MD5/内容 SHA256、当前 JSON 目录和开发文件排除检查通过；新增资源 remap 目标核验继续随最终打包验证。许可证/NOTICE、包清单与 SHA256SUMS 在 `.godot/exports/windows/`。

2026-10-03 接续运行包：`tools/check_windows_package.ps1` 使用与正式包 SHA256 相同的 EXE/PCK，通过外部临时 `override.cfg` 加载自动入口；正式包本身不含测试入口。有效 user data 路径实测在独立目录内，干净开局没有注入物料；完成实际首项研究和计划，第二进程继续、损坏隔离主档、正式确认恢复快照均通过。它只证明局部自动旅程；完整成长、人工键鼠及所有模式依然待验收。

三档实际 OpenGL 夹具与任务 18 基线的 context 匹配。任务 26 同机对照确认主要退化已存在；去除重复统计/编码/迁移及连接扫描后，固定步 P95 为 3.003/8.807/32.451 ms，保存为 15.300/67.798/277.327 ms，七类指标均通过原趋势门。没有调整门限。大型工厂仍未达到 60 FPS；环境、原始报告、等价证据和限制见 [性能复核](../testing/task27-performance.md)。源配方切换仍需专用设备分支的完整比较。

内容包计划修复后的包已重新导出，仍为 266 个资源；EXE SHA256 为 `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`，PCK 为 `edf2c7c902877f06ec49d0173a0f7bd50f527ba01d85aacbef4568c9ac82eb45`。默认 D3D12、OpenGL 和 headless 两进程旅程均退出 0、每阶段唯一成功标记，无脚本/解析错误或生命周期泄漏。记录分别位于 `.godot/windows-package-check/bc1cd4add0a34e8cafa4b56e15cda665/`、`76534c2bf1e64a09a01b071324057873/`、`1e2a41b0e816492285c15c81e980b4e2/`，result.json 校验值与该次包一致。该包尚未包含后续专用设备修复，须重建后更新包证据。它们只证明局部自动操作，不能替代完整成长链或人工旅程。

完整桌面成长旅程、人工键鼠记录、Windows 包完整旅程及最终审查仍待执行。人工 Windows 控制能力当前未提供；自动 UI 证据和人工旅程分别记录。任务 27 和路线图完成框保持未完成，未运行最终发布验收，未推送。


### 战役 UI 独立复审修复（2026-10-04）

两条 P2 均有实际验证：原活动槽位 4 在专项后失去引擎/监测器/会话/计时/保存状态，日志 .godot/task27-campaign-ui-isolation-before.log 六项业务失败；测试运行器现隔离新监测器与初始状态，完整恢复 15 个 GameManager 服务与事务字段，以及原 processing/设备设置。修复专项 .godot/task27-campaign-ui-isolation-after2.log 唯一通过标记、无脚本/解析或生命周期失败，核对原持久内容和监测样本，并真实继续保存。

新增真实本地建筑非空选择与连接模式前置；正式打开按钮执行清理后，再独立重设非空选择/连接，通过正式 smelt_iron 路由按钮验证导航自身清理。隔离副本仅移除产品清选中调用，.godot/task27-campaign-ui-selection-mutant.log 实际拒绝打开和导航两个断言，未修改主树产品实现。最初非空路由测试错选不存在的 technology 任务已更正，该失败日志不作为产品缺陷或通过证据。101 个实际源文件哈希及最近 138 份 save_0.json 已只读核验。

修复前 38 场景门 session 98132 主动终止，退出 1，没有完整通过日志。本批修复后完整门重跑 .godot/task27-research-campaign-controls-full-gate2.log；已核对 38 个唯一成功标记、227 个实际 key、164 个依赖及 101 个源文件哈希，保存登记前报告 .godot/task27-research-campaign-controls-pre-record-evidence.json，五个 callback/workspace key 已登记；独立修复复核已关闭两条 P2。任务 27 全成长、逐项余项、人工与当前包仍未完成。


### 世界与托盘查询下一批（已合入，完整门待完成）

实际冻结源 exporter 导出 248 个状态、5456 个世界行及 42548 个容量结果；独立只读重执行完全一致，24 个实际模块哈希与预期一致。覆盖三个种子/基线、22 行星、8 星系、78 物品、六种殖民状态、未知星系/托盘目标，以及物资/舰队不足、远程库存不抵本地成本、先遣所有权、在途任务和容量边界。原始小数/越界/无穷容量明确只验证查询，不声称合法保存或命令付款。

主树新增 exporter、fixture、runner 和专项场景，均未接当前完整门；产品改动仅存在 .godot/task27-campaign-fix-probe。主树缺少对应公开 providers 与容量投影，before 63884 个未满足断言不是 63884 个产品 bug。隔离副本新增来源查询、容量 getter，并通过来源漂移/漏例/重复/漏物品/错容量/错中文原因和原始库存误改拒绝检查。

独立复审发现新 provider 与旧正式消费仍分裂；真实1920×1080星图专项 .godot/task27-world-queries-formal-before.log 复现12项差异。副本的既有勘探 availability/殖民 summary/正式按钮和详情改为复用同一源查询；.godot/task27-world-queries-formal-after.log 已通过所有查询、拒绝检查及8个实际源状态的正式星图控件，唯一成功标记，无脚本/解析和生命周期失败。共享勘探前置采用源 EPS，因此也影响命令准入；本批只证明查询与显示，不授予支付、任务推进、实际旅行或连续物流写入 key。独立复核已关闭正式消费分裂 P2；修复后旧模式/星图/战役 UI 三项专项通过（.godot/task27-world-formal-probe-modes.log、-galaxy.log、-campaign-ui.log）。四个产品文件已合入主树，.godot/task27-world-queries-main.log 通过查询、拒绝及正式控件；七个 query key 等待 39 场景/167 依赖完整门，不提前登记。


### Windows 保存摘要真实失败与修复（2026-10-04）

战役 UI 版本 PCK 907f8545a982f5d7d057f6f67736cf8d15817341b5763b32df988696927eb5ac 的 headless 和 D3D12 两进程局部旅程通过；OpenGL 独立运行 .godot/windows-package-check/b7b03f9beb46462b919c1194071ee854/new.log 在研究和计划后保存/快照/返回菜单失败，该次没有 resume 通过或 result.json。失败目录及初档/紧急临时档/快照临时档均保留；不能用另两种渲染器的成功掩盖这次失败。

从该次实际初档 seed 59751067 重放真实三蓝矩阵、风机/实验室、首研究和计划，完整重现原摘要 090fe7d685479d1507ab711f4b20853d0562fca42f3bed74c92e9f6dca5bd07b。根因为 Godot full-precision JSON 写入/解析后 elapsed_time 与 plan.createdAt 跨过默认字符串化舍入边界（42.1666666666656 → 42.1666666666655），原摘要与文件读回摘要不同；不是渲染器导致。SaveSystem 新写入摘要使用同一 full-precision 文件数值解析表示，再调用原摘要规范化。读取算法、schema v9、状态校验和提交/备份握手保持原约束；旧失败临时档仍被拒绝。

真实重放 red/green 为 .godot/task27-save-digest-replay-before.log / -after.log；2530 tick 时钟与真实计划的普通保存、重开再次保存、紧急点、快照及篡改摘要拒绝回归通过；主树 .godot/task27-save-float-main.log 唯一 SAVE RECOVERY TESTS PASSED。副本 .godot/task27-save-float-blueprints-after.log 包含旧成功档保持原摘要与轨道/蓝图所有权通过。本批独立只读审查无新高置信度 P1/P2。保存修复和 TestSaveRecovery 已合入并加入 167 项依赖，.godot/task27-research-world-queries-full-gate.log 的 39 场景门正在运行；Windows 包已按本次版本重建，三种渲染器局部旅程正在检查，完成结果另行登记。


### 当前包保存修复核验（局部自动旅程）

39 场景运行树版本已重建为 266 个资源，数据字节/MD5/路径与 remap 目标检查通过，无开发测试/工具/夹具；许可证、NOTICE 和 SHA256SUMS 保留。EXE SHA256 d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562，PCK SHA256 c1c2d750f760c5b4722391e8c63461f0a7e85b363c6b662249f4ebd2a0d632b6。包含本次世界查询/正式星图消费与保存修复；尚不包含下一批世界设置原型。

headless .godot/windows-package-check/cb1431781fc7438a9ae27ff35d0ca1b9/、OpenGL 914ff545dc0a4c128112255aa129fda0/、默认 D3D12 e69d0043683643d2b6d6b8ddd533e0bd/ 均在字节一致的导出包上跑过 new/resume/rounding 三个独立进程。每阶段唯一成功标记，无脚本/解析/业务失败与生命周期泄漏；result.json 的 EXE/PCK 校验值和本次包一致。new/resume 证明实际开局原矿、三蓝矩阵、付费风机/实验室、首研究与计划、暂停/保存/退出、新进程继续、隔离损坏主档及实际确认后快照恢复。rounding 是独立受控的 2530 tick/真实计划数值回归，准确覆盖已发现的舍入边界，普通保存/重开再保存/紧急点/快照均通过，摘要不匹配的篡改档仍被拒绝。

这三种渲染方式的修复验证已通过，不代表完整成长链、最终发布或人工键鼠旅程。原失败 b7b03f9beb46462b919c1194071ee854/ 保留；39 场景完整门仍在运行，七个世界查询 key 尚未登记。


### 世界查询完整门收口（2026-10-04）

.godot/task27-research-world-queries-full-gate.log 退出 0，39 个唯一成功标记，无脚本/解析、业务断言或生命周期失败；234 个实际 key、167 个当前实现指纹、101 个冻结源哈希和全部拒绝检查一致。登记前报告保存为 .godot/task27-research-world-queries-pre-record-evidence.json。七个世界/殖民/托盘 query key 已按实际报告登记，矩阵为 527 实现中、234 已验证、312 未实现、26 在线排除。当前三渲染器 Windows 包 c1c2d750f760c5b4722391e8c63461f0a7e85b363c6b662249f4ebd2a0d632b6 的九个阶段已通过；不包含下一批世界设置修复。


## 世界设置与标准 JSON 保存收口（2026-10-04）

- 上次完整门已实际结束：.godot/task27-research-world-controls-full-gate.log，40 个唯一成功场景、238 实际 key、171 实现依赖和 101 源文件哈希均通过；快照 .godot/task27-research-world-controls-pre-record-evidence.json。此门的保存 writer 未修复标准 JSON 缺陷，不据此登记 4 个世界控制 key。
- 当前 890 个源设置案例包括 UTF16 奇数截断及原始单元去重、ECMAScript 空白、C0、容量/角色/名称、真实重复和磁盘往返。正式星图及旧成功档案 d53df4ab… 已通过。
- 原包 429a0f88… 的实际 US31 元数据存档被标准 JSON.parse 拒绝；原 Godot stringify 对 C0 字面输出及 VT 的非标准 \v 已独立复现。writer 和写前摘要解析现按标准转义，reader、旧摘要算法、schema v9 和事务提交校验不变。一次片段拼接避免按控制字符数重复复制全档。
- .godot/task27-json-controls-recovery-main2.log 通过；.godot/task27-audit-strict-json.mjs 检查主档/备份/emergency/snapshot 4 文件与实际 GDScript 147-case 转义矩阵（0～20 前置反斜线）通过。控制字符 1～31、引号、literal 反斜线完整；原始 NUL 输入不在该批证明范围。有界独立审查和性能改法复核均无阻断发现。
- 当前 Windows 包 PCK 为 7470e74c6bf8b63b6af8c2838067f88d0ea74f0494c5710818898b88993ac203（EXE d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562）。三种渲染方式分别通过 new/resume/rounding/world 四进程，共 12 阶段；标准 Node JSON.parse 各核对 12 个实际保存文件，其中 3 个完整 C0/反斜线主档、紧急点和快照。该检查为首项研究局部自动旅程与受控保存专项，不是完整成长或人工通关。
- 包日志 .godot/task27-world-controls-json-package-{headless,opengl,default}.log；隔离目录分别 81a24d8225c14c1c828492b9b87faae7、5cc516323fc74f6abce40de1fad0890c、5413720de50440f7ace70718afd98751。标准 JSON 检查已接入 tools/check_windows_package.ps1；Node 仅用于主机验收，不是包内运行依赖。
- 当前重跑 .godot/task27-research-world-controls-full-gate-json.log，冻结 .godot/task27-world-controls-json-runtime-frozen-sha256.json 的 171 个依赖。通过并核对后才登记新增 4 key。运行时不要修改这些依赖或 manifest。
- 下一批 world commands gold 为 879 个实际不可变源命令（3 种 seed/baseline），含重复、原始源保存迁移、积分物资与 fleet 支付、所有行星/恒星系。原始金标保留源数组与计算殖民；首次 684 断言失败混含缺零表示问题，修正表示后无盘检查为 180 差异，不能说成 684 个产品 bug。克隆命令修复后 879 实际保存已成功，仍有 132 源保存迁移差异，尚未标为通过。
- 源 storage.migrateGame 会删除已解锁星系的后台勘探并修补进度；CardFactory 保留已有未完成勘探的保存接续。命令输出/库存/可用世界与源比较，源迁移原文独立保留，真实本地保存需精确保留运行中的 mission/progress，不能声称两个 reader 内部状态完全相同。原有合法源模式的延迟勘探档案继续兼容。
- 主仓新 world-command runner/test/gold 尚未接入 harness、run_tests 或 key 登记；产品修复仅在 .godot/task27-campaign-fix-probe。继续完善 computed-owned 原始前置、勘探时间边界、拒绝变异、正式星图和独立复审。

### 世界指令专项与接续已通过（总门集成待完成）

隔离副本 `.godot/task27-world-commands-after5.log` 为零错误、3 个实际 key、1,047 次真实保存：879 个不可变源命令与重复/拥有权、168 组真实源模拟勘探边界均通过，12 个正式 Main 星图按钮和两份实际旧成功本地存档也通过。补齐先遣计算所有权、已解锁后台勘探、当前行星重复选择无副作用、原始托盘别名和已有资源/视口/缓存记录保留。产品修复仍只在副本，尚未接主仓总门或登记 key。

此前 after4 的 9 处失败为 8 处十进制 `1/60` 输入读回的浮点步长差异和一处把 reader 的迁移摘要误当磁盘摘要的测试错误；分别保留真实浮点诊断和原磁盘字节/摘要检查。五类 60 Hz 输入现在声明精确分数时钟并核对原始 seconds，其余三类禁止覆盖；源 879 命令/168 trace/实际文件哈希与说明补充前完全相同。`.godot/task27-world-commands-clock-after.log` 的 12 种缺失/多余/错误 clock、原始时间及 steps 变异全部被拒绝。运行器 scope 明确记录这一读取适配，未修改源预期、支付或进度精度规则。

`.godot/task27-world-commands-resume-after2.log` 的 21 组实际 SimulationEngine 接续通过：每次严格推进一 tick，第三步暂停不推进，真实写盘/重开并创建新模拟器后继续六步，逐步核对源勘探、库存、舰队及计算所有权。暂停是现有 codec 排除的运行态字段；首次测试误要求它持久化产生 21 次失败，删除了这一错误要求，未改变产品存档契约。该检查只证明受控勘探接续，其他模拟阶段的 metrics/campaign 不作为完整工厂等价证据。

独立复审关闭三个 P2：旧原生已解锁进度恢复原 `is_equal_approx` 容差；旧 source 存档的磁盘摘要与 reader 迁移返回摘要分别核对；clock 的完整输入约束已落实且实际变异拒绝。旧进度 `.999999` 的 before 失败/after 成功与 `.9` 拒绝均保留。审查仅覆盖这批，最终全任务审查仍待完成。

当前主树 JSON writer 的 40 场景完整门仍在运行，171 个依赖及 manifest 保持冻结。隔离副本已导出包含世界指令修复的受控 Windows 包，266 资源检查通过；PCK `b92430f18622a5e7af0cbc6fb44c1293cd9faeec8853a717bb1584b593e0a8a5`，运行阶段结果待核对，不能替代当前主树的 `7470e74c…` 包证据。

### 世界设置登记完成，世界指令合入（2026-10-04）

`.godot/task27-research-world-controls-full-gate-json.log` 退出 0，40 个唯一成功场景、238 个实际 key、171 个当前实现依赖、101 个冻结源哈希与拒绝检查一致，未发现脚本/解析/断言/生命周期失败。完整门生成的 4 个控制字符保存文件及 147 个实际 GDScript 转义案例标准 JSON 核验通过。原未修复 writer 的登记前报告另存 `.godot/task27-research-world-controls-before-json-evidence.json`；当前登记前报告为 `.godot/task27-research-world-controls-pre-record-evidence.json`。四个世界设置 key 已按当前报告登记，清单、归属和防伪登记检查通过；真实矩阵为 238 已验证、524 实现中、311 未实现、26 在线排除，835 非在线项仍待验收。

世界指令修复及 harness/test/recorder 的 9 个文件已从经审查副本合入主树，实现依赖扩为 175，指纹保存 `.godot/task27-world-commands-runtime-frozen-sha256.json`；3 个指令 key 未登记。主树专项 `.godot/task27-world-commands-main.log` 正在运行，完成后运行相关旧模式及 41 场景完整门。当前候选并非全部通过，不能通过接入 runner 或导出包成功提前标绿。

隔离副本包 `b92430f1…` 已通过三渲染器的 new/resume/rounding/world/worldcommands 五进程共 15 阶段，标准 JSON 实际核对 81 个保存文件与 9 个完整控制字符恢复文件；worldcommands 使用包外受控金标的 8 个命令、3 个精确 60 Hz 保存接续和两份实际旧本地存档，不是完整付费成长旅程或人工输入。headless 目录 `.godot/windows-package-check/24ee72d9a8b64b958ec703c0e0b630d6`、OpenGL `98449c45c8fe4750af1faeec56d1a494`、默认 D3D12 `caebd708b4c64a3d85adaae37c5f464c`；日志 `.godot/task27-world-commands-package-clone-{headless3,opengl2,default2}.log`，包校验值、唯一标记及错误/泄漏拒绝均一致。

最初包外 probe 把 JSON 数值 Dictionary 与整数字面 Dictionary 直接比较，产生三处 clock 检查误报；改为逐字段精确约束后同一 PCK 的 worldcommands 通过。首次图形两进程业务断言虽通过，但嵌套副本的长 user:// shader_cache 路径引发缓存错误，整体拒绝；原 `3bf49185…` / `b74dbccd…` 目录和日志保留。测试目录缩短且 PCK 字节未变后，全部图形五阶段通过；未放宽错误过滤或改变产品渲染/保存逻辑。`check_windows_package.ps1` 支持指定短测试目录，每轮仍创建独立 GUID；实际 profile 与断言路径必须留在该目录。

副本旧模式检查先暴露了未同步的旧元数据 overflow 断言，已同步主树在 40 场景门通过的源金标版本；另两处纯挂机 stable 在并行负载时未满足全额预算/第二周期断言，原因仍待以单独运行的实际摘要核对，不能作为通过。旧星图/物流 `.godot/task27-world-commands-galaxy-clone.log` 通过，当前产品树的旧模式和新的完整门仍将实际复核。

### 主树专项、当前包与新完整门（2026-10-04）

主树 `.godot/task27-world-commands-main.log` 退出 0，零业务错误、3 个实际指令 key、1,047 次保存、12 个正式控件、12 个异常 clock 拒绝、21 组真实固定步保存接续及两份实际旧档通过，无脚本/解析/Unicode 或生命周期异常。主树 `.godot/task27-world-commands-modes-main.log` 单独运行通过；未调整纯挂机 30 秒预算或周期断言，之前并行负载失败日志保留，不能以该次通过声称负载场景也满足全额计算预算。

主树当前包与副本包字节不同，因此独立重建并重新验收：266 个资源检查通过，EXE `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`，PCK `d4dd60f2bc5d7607c9209d74d263ef8d50ec9d294903b712f70714af7e003b29`。三种渲染器各跑 new/resume/rounding/world/worldcommands 五进程，共 15 阶段；81 个实际保存文件标准 JSON 与 9 个控制字符恢复原文检查通过。headless `3546615b7d194f938da6da19ab583043`、OpenGL `74c0642d5ff54c29bc0ae8b92bc7311b`、默认 D3D12 `f808dbf7f0b1412f82eaed0fc08e45cb`，日志 `.godot/task27-world-commands-package-main-{headless,opengl,default}.log`。仍仅为首项研究旅程和受控保存/世界指令专项。

原 harness 的缺失/错误传送带负例会重跑全部其他领域及 890 次保存；已抽取同步 `run_belts`，四种源/案例/容量负例仅执行实际传送带域。完整正例仍执行所有领域和全部各域负例，新增重新实际执行并严格比较三项 belt 的 keys/proofs/claims 与完整正例；单域结果没有完整指纹，也不能验证当前完整 manifest。隔离 `.godot/task27-belt-domain-proof.log` 对照原实际完整报告，三 key 各 13 条断言及 fixture hash 一致，四种异常全部拒绝；有界独立审查通过。日志的已知 sandbox user:// 日志/证书错误仍保留，不称为“无错误日志”。新完整 harness 的实际结果仍须等待总门。

41 场景门已启动，日志 `.godot/task27-research-world-commands-full-gate.log`，会话 47186。当前 175 个依赖冻结为 `.godot/task27-world-commands-runtime-frozen-sha256.json`（包含本次传送带测试抽取），manifest 为 238 已验证；3 个指令 key 尚未登记。期间不改这 175 个依赖、已运行夹具或 manifest。结束后核对 41 唯一场景、241 实际 key、175 当前指纹、101 源哈希及完整拒绝证据，通过才登记。下一批可准备未接入的独立 exporter/fixture/test，不变更当前运行树。

### 库存丢弃独立批次（主树完整门期间）

冻结源实际导出 1,967 个不可变命令：78 物品、42 施工件、22 行星和 40 个实载模块哈希；其中 1,757 个案例进入保存检查。请求逐项取整后合并重复物品，bool/nonfinite 无效，托盘与 portable fleet 独立；施工件命令清空整栈并保留已放置实体与制造目标。原始 source storage 输出取自首次命令，647 个首次结果不同于重复结果；独立审查提取源函数原文并在内存逐例重算，结果与金标一致。

首次 runner 的非有限标记比较错误已修正，旧失败日志保留；有效修复前 `.godot/task27-inventory-discard-before2.log` 为 1,803 条断言失败、零 key，未有脚本/解析错误。原因是未列入 literal colonized 的远程托盘被拦住、缺少施工件整栈 provider。隔离 `.godot/task27-inventory-discard-after2.log` 为零行为错误、2 个实际 key、无盘正例通过。首个产品修复运行另有 GDScript 的 Variant 类型推断编译错误，补显式 bool 后再验证；不把该失败运行当行为证据。

四个产品修改仍只在 `.godot/task27-inventory-discard-product/` 及 `.godot/task27-campaign-fix-probe/`。连续库存守恒有明确适配：源原文 7.9 丢弃 3 后为 4，再丢弃为 1；本地保留小数余量，比较 4.9 和 1.9。源金标原文未覆盖改写。其余非零库存严格比较，零施工件和保存补空 known bank 仅作表示归一化。本地 codec 和磁盘需独立精确保留结果。

`.godot/task27-inventory-discard-ui2.log` 的 48 个实际 Main 控件（6 托盘、42 施工件）、3 个 stale confirmation 及非空付费设备/真实目标/制造队列保存往返通过。第一次 UI 失败是原生 Window 下一帧才隐藏、SpinBox 整数输入和实际 electromagnetism 前置未满足；第二次日志实际记录 cancel 前后 visible true/false 且状态不变，保留原失败。引擎小数请求由金标覆盖，UI 提交取整数量；自动信号仍不是人工键鼠。当前完整独立批次 `.godot/task27-inventory-discard-full.log` 会话 26800 正在验证全部磁盘/负例。

有界独立审查未发现 P1/P2，但审查当时仅核对无盘正例；新的 UI/磁盘证据须由主 Agent 核验。已准备五个 harness/recorder/run_tests 集成文件于 `.godot/task27-inventory-discard-integration/`，尚未应用主树。再次核对 175 个当前依赖和先前 13 个行为夹具均未变；此批两个 key 不登记，41 场景门仍为会话 47186。日志的已知 sandbox 日志写入/证书错误保留，不称为无错误日志。

### 世界指令登记与库存证据收口（2026-10-05）

世界指令完整门 .godot/task27-research-world-commands-full-gate.log 已退出 0，41 个唯一成功场景、241 个实际 key、175 个当前实现依赖、101 个源哈希及拒绝检查通过。标准 JSON 的 4 个实际恢复文件和 147 个转义案例再次核对通过。登记前报告 .godot/task27-research-world-commands-pre-record-evidence.json 保留；3 个指令 key 已登记，清单/归属/防伪检查通过。当前矩阵 241 已验证、522 实现中、310 未实现、26 在线排除；832 个非在线余项未完成。

库存隔离 .godot/task27-inventory-discard-full.log 已退出 0，1,967 正例、1,757 次磁盘保存、两个实际 key、48 正式控件、3 旧确认框、非空设备/目标/队列保存及六类负例通过。该次 Test 源 SHA 为 5f5d4d35…，八文件快照 .godot/task27-inventory-discard-probe-verified-sha256.json 保留。随后仅强化托盘旧确认框必须实际选中 iron_ore 且库存至少 3 的前置，当前 Test SHA 为 05205be0…；UI3 日志单独通过，快照 .godot/task27-inventory-discard-ui3-verified-sha256.json。不能将旧 full 的全文验证冒充当前 Test 全文。

隔离删除施工件及托盘两个 session guard 后，.godot/task27-inventory-discard-session-mutant.log 恰好两条对应失败，无脚本/解析/生命周期错误；产品已从 canonical stage 恢复并核对八文件字节一致。此前独立源/算法审查通过；后续集成/UI 复审因额度中断，现已续上，结论待回收。库存四产品和五集成文件仍待主树接入，新完整门和两个 key 登记尚未完成。

### 库存主树接入与当前 Windows 包（2026-10-05）

集成/UI/非空磁盘有界独立复审关闭，无高置信 P1/P2。校验世界完整门 175 依赖、五文件原始 SHA 和八文件当前 UI3 证据后，四产品及五集成文件已合入主树，原文备份在 .godot/task27-discard-pre-integration-backup/，前后 SHA 在 .godot/task27-discard-main-integration-sha256.json。主树当前 Test 全文专项 .godot/task27-inventory-discard-main.log 已退出 0：1,967 正例、1,757 磁盘、48 控件、3 旧确认框、非空实体/目标/队列保存与六类负例均通过，无脚本/解析/生命周期错误，已知 sandbox 日志/证书消息保留。

42 场景完整门 .godot/task27-research-inventory-discard-full-gate.log 已启动，会话 8955。当前 177 实现依赖冻结于 .godot/task27-inventory-discard-runtime-frozen-sha256.json，夹具/manifest/catalog/门入口另存 .godot/task27-inventory-discard-gate-inputs-sha256.json，保持不变；期望 243 实际 key，两个库存 key 暂不登记。

当前 Windows PCK 为 313cf74be0a203002857ffc42d4112dfa84013be581da431e06104b079439f5e，EXE 仍为 d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562。266 资源检查通过。包外新增 discard 阶段使用10个实际源案例检查首次/重复、未确认不变和精确磁盘保存；不包含产品内测试代码，不代表完整成长或人工UI。headless 1d6a189cf00a4bb29bc59d64728089a5、OpenGL 7f416ac5703e4177b80a7613ea968c51、默认 D3D12 5f09e99ea620421cab957786145d9389 各六阶段通过，111 个实际保存标准 JSON 与9个C0恢复原文核对通过。日志 .godot/task27-discard-package-main-{headless,opengl,default}.log，当前包/副本/插桩SHA和唯一标记已审计一致。

### 科技效果只读查询准备

新增 task27-effect-queries.json 源执行金标：147 受控状态、12,054 recipe行，三难度、有限效果各自开启和非连续组合、四无限领域独立边界/上限及混合等级，覆盖八查询。初轮被输入前置拒绝：catalog 的全科技顺序与实际源定义顺序不同；改为无重复精确集合检查，其他 input 字段继续严格一致，没有改源输出或产品公式。after 专项零错误、8实际key与七类拒绝通过。runner/test/scene 尚未接总门或指纹；当前冻结177依赖不变，有界复审待回收。这是受控查询证据，不是实际赚取等级、生产吞吐、全成长或合法存档证明。

### 科技效果修复复审与两批查询集成准备（2026-10-05）

独立复审发现一条验证 P2：输入 levels 用通用1e-9容差校验后再int截断，±5e-10非法等级可能拿到完整证明。先只增加这两个负例，.godot/task27-effect-queries-level-before.log 退出1、恰好两条拒绝断言失败，原正例仍8key；再补 _levels_match 严格有限数值、非bool、非负整数、0..1000和声明值exact，level-after.log退出0/8key。源 fixture/产品算法未改。独立修复复审关闭该P2，查询/provider及包新增阶段有界审查无剩余阻断发现。effect gold实载24个源模块，哈希均一致。

另已导出432实际源物流标量输入，16有限engine/capacity组合×9 galactic等级×3difficulty；三个query原始值与真实StationSystem.logistics_snapshot比较，先用独立资助施工件实际放置 paid station，查询前后完全保留raw/canonical。初次before被JSON float与GDS int数组的严格类型比较拒绝；改为每个声明levels按finite数值类型和exact相等，不放宽等级范围，不改源值。after.log退出0/3key，八种结构/输入负例、错误remote容量仅拒1key、codec隐藏的raw阻塞queue变异拒全部。物流批有界复审待回收。

两批共11key的五集成文件准备于 .godot/task27-read-query-integration/，基于main当前177源SHA，预期181实现依赖、44唯一场景；已在隔离副本应用，13文件SHA在 .godot/task27-read-query-staged-sha256.json。真实autoload scene解析 .godot/task27-query-integration-parse.log 通过。CLI --check-only不初始化autoload，导致既有DataManager/EventBus符号未定义的旧失败保留；该诊断方式不用于产品通过结论。main177依赖、正在运行的42门输入与manifest均未改。

完成42门审计并登记库存两个key后，可运行 .godot/task27-integrate-read-queries-main.mjs 接入这五个已准备集成文件；该helper要求真实243-key完整报告、库存已登记、原始177依赖/夹具和13源SHA一致，执行前仍须核对物流/集成独立复审结论。当前新增query仅是受控只读证明，完整成长/人工/最终发布仍待完成。

### 完整门 PureIdle 失败定位与测试拆分（2026-10-05）

42 场景门 .godot/task27-research-inventory-discard-full-gate.log 退出 1，仅 19 个唯一成功标记，TestLocalContentPacks 的 stable 全额 650 秒与第二周期校准两断言失败；没有生成新的 243-key 报告，旧 241-key 报告不能代替该门。quiet1 单独实跑同样两失败。未改产品的 diagnostic1 实际记录 stable 用时 30.025698 秒、exact_ticks 3242、settled_wall 624.033333333311、validation_count 1、partial true、原因是既有 30 秒计算上限；extreme 约 18 秒完成 650 秒、一次校准。根因是旧周期测试同时假定当前机器在生产计算期限内完成全部校准，产品部分结算符合既有规则。

仅修改 PureIdleRegression：测试子类延长期限专测完整周期，原 650/ready/not-partial/0.02 误差及 stable2/extreme1 校准断言保留；另用原生产品类验证真实 30,000,000us 期限，先支付一个实际 tick，再使期限到限，严格检查 partial/ready、时间与 tick 不再增长、候选及 live 原文不变。生产预算和算法未改。独立有界复审无 P1/P2；.godot/task27-content-packs-deadline-fixed.log 退出 0、唯一成功标记，无脚本/解析/业务断言/生命周期失败，已知 sandbox 日志及证书错误保留。单机模式专项正在复核，通过后重跑完整门。

物流标量、11-key 组合集成及证据复用 helper 的独立审查均关闭，无剩余 P1/P2。原 170 路径基线另存 .godot/task27-query-reuse-before-deadline-fix-sha256.json，新基线只变 PureIdleRegression；补充 .godot/task27-query-reuse-product-resources-sha256.json 冻结 260 路径（所有 autoload/data/非测试 scenes/scripts/shaders、UID、project/icon），接入与审计均校验路径集合和全部字节。先前失败的 42 门会被审计硬拒，不能复用其 19 个通过标记。后续实际完成新 42 门后，只复制五个已审测试/工具文件，以 40 未变场景证据加四个新实跑场景形成 44 场景证据集；不宣称新完整 44 场景执行，最终发布仍须实际运行全部门。

两项受影响专项已审计通过：content-packs-deadline-fixed / single-player-modes-deadline-fixed 唯一成功标记，除已知日志/证书环境错误外无其他错误、脚本/解析/断言/泄漏。177实现与34门输入SHA未变；原失败完整门保留为 .godot/task27-research-inventory-discard-full-gate-failed-before-deadline-fix.log。修正后的42场景门已启动，会话73902，输出仍为 canonical inventory-discard-full-gate.log；完成前不登记库存、不接查询集成。

产品资源复审发现根 icon.svg.import 的实际导入参数遗漏；已纳入根 .import 并取消递归过滤.import。原260快照另存 before-import-metadata，全部旧路径SHA未变，唯一新增 icon.svg.import；当前261集合的新增/删除/修改只读负例均被拒，独立修正复审关闭，无剩余P1/P2。

下一批航线只作隔离准备：tools/export_task27_route_queries_gold.mjs 从24个实际冻结模块导出3,168受控状态、44场景，覆盖22行星/三环境种子/三难度、有限和无限效果、三中继策略、预算1..4、优先级/同优先级/锁定/交接/电梯及载具数量。源查询前后raw不变且重复返回一致；216不可用/720中继结果。金标与本地诊断入口保存在 .godot/task27-next-routes/，SHA保存在preparation-sha256.json，未实跑本地诊断、未接总门、未登记key。气态行星不能放置星际站，源先实际支付home施工件后仅为受控查询调整planetId；这不证明目标行星可放置、合法存档、实际派遣或赚取成长。当前42门输入与261产品字节仍未改。

### 航线查询隔离修复与实际诊断（2026-10-05）

首次本地实际对照 diagnostic1 退出1：3168案例中144不一致、1710字段差异，全部来自交接中/电梯模式hub。源只读路径仍纳入enabled hub，本地路径为实际派遣排除不可用hub；不是航程数学差异。候选只在 .godot/task27-next-routes/product/ 和隔离副本应用：原 economics 默认派遣守卫保持，新 query_economics 提供源只读路径选择，trip_seconds 共用原科技/难度公式。主树 InterstellarRouteSystem SHA 0d36f8ef… 及261产品资源保持不变，未注册或接主树。

diagnostic2 虽退出0但有类型推断解析错误，没有结果文件，保留为失败证据。修复诊断入口后 diagnostic3 实际3168/0差异、三个实际_dispatch守卫通过；diagnostic4 修正scope文字并再次实际通过。活动中继派遣检查500货物、4载具、16翘曲器的停放/在途/消耗守恒，交接及电梯拒绝无航线且raw/canonical不变。范围为受控查询和三个派遣守卫，不代表完整派遣、吞吐、合法存档或赚取成长。对应有效日志无脚本/解析/业务断言/泄漏，仍保留已知sandbox日志/证书错误。独立产品局部审查关闭，无P1/P2。

隔离默认航线回归 route-default-regression1 的诊断代码把整数failures当数组，虽然退出0但报脚本错误及泄漏，不计通过；修正入口后 route-default-regression2 唯一成功标记通过，实际执行既有金标、派遣、在途保存、断电暂停、量子切换接续。正式runner/test/scene草稿在 .godot/task27-next-routes/integration/，独立重建44场景和3168精确输入，准备14类结构/输入拒绝、错route金标单key拒绝和raw队列变异双key拒绝；只复制隔离副本，专项会话23533运行中，独立局部审查待回收。42门会话73902仍在最后完整harness，当前已登记仍241，不提前登记库存或新查询。

### 库存完整门收口与查询主树接入（2026-10-05）

会话73902实际退出0；.godot/task27-audit-completed-gate.mjs inventory-discard 42 审计42唯一成功标记、243实际key、177实现依赖、101冻结源文件、harness passed/failures0/rejections_checked true和每项proof/claim/fixture哈希一致。预登记证据保留在 .godot/task27-research-inventory-discard-pre-record-evidence.json，原manifest SHA7448faba82de0284bf8c46f7d692d2088cb0646f74e05b530fe0d616d2ee2bff。两个库存key已通过真实报告登记，台账/归属/拒绝登记检查通过；当前243已验证、521实现中、309未实现、26在线排除，830非在线待验收。

冻结170测试/夹具和261产品资源再次核对一致后，.godot/task27-integrate-read-queries-main.mjs 仅复制五个已审集成文件并保存原文备份，13批次文件SHA记录在 .godot/task27-read-query-main-sha256.json，产品字节未改，预期181依赖。四受影响场景会话18634已启动，效果、物流标量、启动三个场景通过，完整行为及拒绝harness运行中。完成后须运行严格impact审计并登记11key；该门复用40个未变场景+4新实跑，不能称为新完整44门。

航线正式suite1实际退出0、3168案例/2实际key、14类输入/结构拒绝、错输出单key拒绝、raw队列变异双key拒绝和三个_dispatch守卫通过；但独立审查发现两条P2：只要求五主模块允许删实载galaxyCatalog来源、证据写入依赖诊断预建目录。未接主树或登记。缺galaxyCatalog的独立实际负例会话89746运行中；随后补24实载模块精确集合、缺非核心模块负例和可靠证据输出，再复核。

### 航线来源与新环境修复闭环（2026-10-05）

route-provenance-before.log实际退出1，删galaxyCatalog后 errors0/keys2/passedfalse，恰好来源拒绝断言失败；无脚本/解析/泄漏。Runner补精确24唯一模块集合及每个实际catalog哈希，Test新增缺非核心模块与额外未知null路径拒绝。证据移到.godot根，检查目录/open/write，放到全部拒绝和dispatch guard之后；standalone_checks明确不能替代完整harness。独立聚焦复核关闭两条P2。

隔离副本的旧诊断目录校验workspace绝对路径后完整改名保留，原目录确实不存在；source-fixed suite会话82337实际退出0，唯一成功标记、3168受控状态/2key、16结构输入拒绝、错输出单key拒绝、raw变异双key拒绝和三个实际派遣守卫通过。实际证据与runner/scene/candidate产品SHA已审计并保留source-fixed-suite-sha256.json；源exporter再次实际执行，repeat金标与原文逐字节一致，SHA8833b4d7…、24模块。主树产品仍0d36f8ef…未改。

后续五个航线集成文件已在 .godot/task27-next-routes/integration/ 按main当前181原文SHA准备，只应用隔离副本并保留五原文。真实autoload route-integration-parse.log通过，183依赖登记拒绝检查和归属检查通过，预期45场景；这不替代实际完整harness。五文件独立局部审查待回收。主树两批11查询的完整harness会话18634仍在运行，完成严格impact审计及登记后才允许把航线产品/fixture/runner/五集成文件接入main。

### 查询登记、航线主树接入与新包（2026-10-05）

会话18634实际退出0，四个新场景均唯一成功标记且无非预期错误/脚本/解析/业务断言/生命周期失败。.godot/task27-audit-query-impact.mjs实际通过：复用40个未变场景+4新实跑形成44场景证据集，254实际key/181依赖/101源哈希，全部fixture/proof/claims与harness一致；不是新完整44门。预登记报告、validation-receipt保留，receipt另绑定当时manifest SHA和报告SHA。11查询已登记，台账/归属/拒绝录入检查通过，当前254已验证、518实现中、301未实现、26在线排除，819非在线待验收。

航线五文件有界独立审查关闭，无P1/P2；reviewed-sources-sha256.json冻结11个实际已审产品/fixture/runner/scene/集成/exporter源。integrate-route-main.mjs验证已完成查询报告/receipt/254登记、原181指纹、261产品资源、五原文和全部11源SHA后，实际复制10文件到main并保留原文备份。183依赖拒绝录入检查通过，两个航线key尚未登记。新45场景完整门会话15514启动，日志 .godot/task27-research-route-queries-full-gate.log；183实现、39门输入、261产品资源另冻结于 .godot/task27-next-routes/，完成后须完整审计而非复用旧包/旧报告。

包外新增routequeries阶段24受控源案例，三难度/三环境、策略/预算/锁定/优先级/交接/电梯/载具边界；只比较只读查询和raw/canonical不变，不作合法保存/派遣吞吐/成长声明。三包工具备份后已接main，PowerShell/Node语法检查、隔离24case提取通过。重新导出PCK99743ae6d2600ec29f57a2712c6bb3c26b3a8c4a349f77e989367c37a1f66eca，EXE仍d34d36f3…，266资源检查通过。新包headless七阶段已退出0，37实际保存/3C0原文和24查询标记已读；OpenGL运行中，默认D3D12与总SHA/日志审计待执行。旧313cf74b…的三种18阶段/111保存/9C0证据只属于旧包。

### 暂停接手与对象快照补强（2026-10-05）

先前包三种渲染方式均完成七阶段，日志 task27-route-package-main-headless/opengl/default.log，总审计 audit-route-packages.mjs 通过：21唯一阶段、各24真实源查询、111份实际标准JSON保存和9个完整C0恢复文件，当前PCK99743ae6…对应266资源。旧包运行结果保留；独立复审指出 _route_ownership 保存了 command_history/SpatialIndex 的对象引用，canonical又不包含这些字段，因此其中“所有raw不变”的结论须补强。

共享 EffectQueryBehaviorRunner 快照也存在同类问题。nested-ownership-before.log 实际退出1且确认历史变更漏检；进一步 alias-snapshot-mutant 只恢复旧快照而保留九种非空反例，实际退出1、恰好七种对象内部变更漏报，替换对象本身的两种反例仍能检测。nested-ownership-fixed.log 实际退出0、九种检查 errors0，无脚本/解析/泄漏。修复暂存于 .godot/task27-next-routes/nested-ownership-fix/ 并仅应用隔离副本：反射两个可变 RefCounted 的 script fields、按值复制容器，identity保存为字符串，并为effects/scalars/routes及完整harness增加真实变异拒绝；有界独立复审进行中。

初跑隔离 effects通过，scalar432正常案例/3key通过，但新增索引clear反例失败，因为付费ConstructionSystem建站没有填充懒加载索引，clear空索引无实际变化。反例已改为插入实际索引条目，原失败日志完整保留于 nested-impact-isolated/；修正重跑会话4246，日志 nested-impact-isolated-fixed/。九种元检查原本具有非空历史与索引，证据不受此修正影响。

主树45场景完整门会话15514继续运行，183实现/39输入/261产品 SHA再次核对未变；五个主树测试文件尚未替换。只有外部 WindowsPackageProbe.gd 已按暂存SHA接入，不修改PCK，七阶段补强headless重跑会话74631（task27-route-package-nested-headless.log）。待45完整门审计后，应用测试补强并重跑受影响五场景，严格核对其余40场景可复用输入与全部产品路径/字节。航线两项暂不登记；整体任务27尚未完成。

### 配额暂停后的实际恢复（2026-10-05）

20:55接手时原15514/4246进程会话已过期，Godot无残留；根据落盘证据继续，未重新运行已经完成的整门。隔离修正三查询receipt全部exit0/passedtrue，实际route3168状态/2key、三个dispatch guards和新增对象变异拒绝通过。独立有界复审关闭对象引用P2，无新增P1/P2。

audit-original-route-gate.mjs实际通过：原完整45场景日志全部唯一标记与run_tests声明顺序完全一致，实际报告256key/183依赖/101源哈希、全部proof/claims与harness拒绝一致；174现有场景/测试/fixture/project输入绑定先前基线及已审集成SHA，261产品路径与字节集合一致。审计初次严格stderr拒绝了12条既有输出，逐条核对来源后确认五条是实际错误配方拒绝、六条是sandbox编辑器目录/设置不可写、一条是TestBaseline主动invalid://保存失败，数量和顺序与已审42门完全一致；无新增ERROR。原进程退出码在会话过期后无法再次取得，receipt记null，不声称已重新读取原进程exit0。原报告保留original-45-gate-evidence.json及SHA。由于旧快照有已证实盲点，此报告不单独支持航线登记。

apply-nested-tests-main.mjs验证完整门、隔离三个真实receipt及所有原文/暂存/clone SHA后，只应用五个测试文件；全部261产品保持原样。新183依赖/174测试输入冻结于nested-runtime-frozen-sha256.json与nested-test-inputs-frozen-sha256.json，39原门输入保持一致。五场景main impact会话6140启动，实际effect147/8key与scalar432/3key已通过，其余航线/startup/fullDSP继续，receipt逐场景落盘，不依赖暂停后仍能读取进程会话。

补强包三渲染器七阶段均实际exit0，audit-nested-route-packages.mjs实际通过：headless985f8499…、OpenGL6fb08e48…、默认8057fd42…，21唯一阶段、各24源查询/九种内部对象变更检查、111实际标准JSON/9完整C0恢复文件；EXE/PCK及探针SHA与当前字节对应，产品来自PCK、266资源无开发测试，39门输入和261产品仍一致，183依赖只有五个已审测试变化。最终receipt为nested-package-validation-receipt.json。183录入完整性与归属检查实际通过。航线两项仍不登记，等待新的完整harness及40旧场景+5新场景严格impact审计；不宣称第二次新完整45门或整体任务27完成。


### 航线及对象快照批次收口（2026-10-05）

- 主树五场景 impact 会话 6140 实际退出 0；日志、唯一标记、无脚本/解析错误及完整行为报告已核对。`.godot/task27-next-routes/nested-main-validation-receipt.json` 绑定 40 个未变场景复用与五个新实跑场景、全部 174 场景/夹具输入及 261 产品文件。原完整 45 场景退出状态因额度中断无法重新取回，保留 null；其实际日志和报告已严格审计，不冒充重新运行的退出 0。
- `.godot/task27-next-routes/nested-pre-record-evidence.json` 保存登记前报告，256 key、183 依赖、101 源哈希，SHA256 049fabd473a5ae8c467fc0975e65947ffb903b891171eaeae562d5f93f9e697c。登记改变 manifest 后应使用该 receipt 的登记前 manifest SHA 审计，不能将旧 harness 当作登记后的 manifest 快照。
- 两项航线查询已经实际登记；会话 53236 退出 0，台账生成、183 依赖登记完整性及归属回归均通过。矩阵 256 已验证 / 518 实现中 / 299 未实现 / 26 在线排除，817 非在线待验收。
- 三渲染器补强包审计 `.godot/task27-next-routes/nested-package-validation-receipt.json` 通过；同一当前 EXE/PCK 下 21 阶段、111 保存、9 C0 文件、每种 24 查询及九种内部对象变更拒绝通过。
- 下一批隔离候选 `.godot/task27-next-sail-lifetime/` 实际源两次字节一致，153 状态 / 12546 配方查询 / 九接口 / 24 模块，SHA256 6f3788541d1e5f72376366d4848c0f2c11de4270db63d8324eac4ee2d79af48c。`isolated-sail-suite.log` 实际退出 0，3672 次旧/新衰减精确比较通过；独立复审无 P1/P2。此候选不替代主树八项旧夹具，接续采用独立太阳帆寿命单项 runner/fixture/scene。尚未主树接入或登记，不是全成长或发布验收。


### 太阳帆寿命独立单项接入（2026-10-05，正在验证）

太阳帆寿命独立夹具两次冻结源导出一致（153 状态、24 模块，SHA256 e3871758…），隔离单项及 20 个拒绝检查通过；3672 次旧/新衰减比较和独立复审关闭。九文件主树接入及包外三文件接入已完成，当前 185 依赖、46 声明场景，旧八项效果夹具与用户 project.godot 保持。六个相关主树场景已通过，七场景 impact 会话 12821 的最后完整行为 harness 正在运行；Solar key 尚未登记。新 PCK 7073c620… 的 266 资源检查及 headless/OpenGL 各七阶段通过，默认渲染器会话 60348 进行中；各含 153 Solar 查询、24 航线和九种对象拒绝。

- 新单项夹具 `task27-sail-lifetime.json` 与前一轮独立复审的九查询源结果逐行一致，实际新导出重复字节一致。原八项 `task27-effect-queries.json`、proof assertion 列表及其登记 SHA 不改。
- `isolated-dedicated-sail.log` 实际退出 0、唯一成功标记，153 状态/20 反例；首次 lambda 内 match 末括号解析失败已保留 `isolated-dedicated-sail-before-parse-fix.log`，改 if/elif 后重新实跑通过。独立 review 无 P1/P2，五份 harness/mapper 接入与三个包外探针文件均已复核。
- `main-runtime-frozen-sha256.json` 冻结 185 依赖，`main-product-frozen-sha256.json` 冻结 261 产品。产品变化仅 SourceDysonEngineering 提取既有 1200×科技倍率表达式，由衰减调用复用；旧/新 3672 个结果比较已通过且产品 SHA 与该候选一致。七场景相关主树门是 batch impact，不能称完整新 46 场景门。
- 冻结源 PS 检查已输出 FROZEN SOURCE FILES MATCH，后续会再次启动完整 DSP 场景；为了避免和正式 impact harness 重复写同一 evidence，本轮识别并停止仅带 `--parity-manifest` 的额外 Godot 35400，source-parity-check.log 的退出 1 是主动终止，不登记为完整检查通过。正式会话 12821 保持。最终 source101 校验由本批完整行为审计核对。
- 新导出 EXE d34d36f3… / PCK 7073c620f0a8a84b4761df0b4737fd3181c809667c09a6b66eb4ba6b7949d757。六场景 receipt 逐场景落盘于 `.godot/task27-next-sail-lifetime/main-impact/receipt.json`；三种包 capture/审计脚本同目录，尚须总审计后登记单项。


### 下一批建筑容量源差异及隔离修复（2026-10-05，尚未接 main）

- 太阳帆当前包三渲染器实际退出 0，`.godot/task27-next-sail-lifetime/package-validation-receipt.json` 总审计通过：PCK 7073c620…，21 唯一阶段、111 实际保存、9 C0、每种 153 Solar+24 航线查询+九对象变更；185 依赖/261 当前产品 SHA 对应。Solar 主树会话 12821 仍在最后完整 harness，key 不提前登记。
- `.godot/task27-next-capacity-queries/` 是下一批恢复入口。冻结源实际两次导出 39 建筑×8 堆叠×11 缓冲上限 profile，3432 状态/10296 查询/24 实载模块，金标 SHA256 3c6c385d935afea68a41e72296a1cd40b00e6d9f234eadfc96b03a0108016691 字节一致。
- 原 getter 默认 profile 的 312 状态/936 对照实际退出 1：653 差异（buffer312、input190、output151），无 Script/Parse/leak，原结果保存在 initial-capacity-mismatches.json；根因旧 getter 使用 60/槽位而不是 data 中已有 source_input_capacity/source_output_capacity、machine_count、源上限归一化。其余3120 profile 当时未以不等价本地输入冒充复现。
- `candidate/scripts/game/` 四文件（GameState/Codec/Validator/SourceEntityCapacitySystem）仅接隔离 clone：source_id 建筑走真实容量提供者，源整数/边界上限按源执行；可选 schema9 source_buffer_limits 在 copy/codec/validator 接续，默认空字段不新增保存字段，旧教学 getter 保留。Main 当前字节与 fix-original-sha256.json 对应，未修改。
- `fixed-capacity-comparison.log` actual exit0，所有3432 profile 实际写入 clone state.source_buffer_limits，10296 源返回值完全一致，原始/规范拥有权稳定。`isolated-capacity-persistence.log` actual exit0，五次真实保存/reload、copy独立、旧v9默认、省略默认字段及九种无效保存配置拒绝；`isolated-state-persistence.log` 旧完整持久化场景 actual exit0。
- 首次磁盘测试10个失败并非保存字段丢失：diagnostic 显示原整数经JSON读回成为等值float。保留 before-diagnostic/diagnostic 日志，测试改递归精确数值相等，无 epsilon，并完整检查字段集/数组顺序；修复后通过。产品未为该测试调整数值。
- `isolated-validation-receipt.json` 严格绑定旧/main/candidate/clone SHA、源金标、真实日志和五份标准 JSON。独立复审正在审四产品文件与该实际证据，尚无正式runner/fixture/key/harness/mapper接入、manual vein容量或新包接受结论；不宣称三 key 已验证。clone 现含容量候选，不能再将其作为早期Solar三文件副本。下一步先收口Solar真实harness与登记，然后补容量正式行为/必要源边界、复审和主树/保存/包验证。


### 太阳帆寿命单项收口（2026-10-05）

- 七场景 impact 会话 12821 实际退出 0，唯一标记、无脚本/解析/泄漏与当前 SHA 审计通过；`.godot/task27-next-sail-lifetime/main-validation-receipt.json` 绑定 257 实际 key/185 依赖/101 源文件和 306 条 Solar 断言；原 256 项规则的 fixture SHA/assertions 均与此次真实报告保持一致。并非新的完整 46 场景运行。
- `pre-record-evidence.json` 保存实际登记前报告，SHA256 1a1e3f2db18dabf34eddd759c46ce0efa350a92960c0be70cc275b26ac3985ad；登记前 manifest SHA 为 9d2862ffeba0f0fa1657d254f57823122ac6ca493f8b13e47524080b33d888da。登记改变 manifest 后不要把这个 harness 当成新 manifest 快照；其 receipt 保留真实登记前对应关系。
- 太阳帆寿命 key 已实际登记；台账生成、185 依赖录入完整性和归属回归均退出 0。矩阵 257 已验证 / 518 实现中 / 298 未实现 / 26 在线排除，816 非在线待验收。
- 当前 PCK 7073c620… 三渲染器 21 阶段总审计已通过，111 保存/9 C0，每种 153 Solar+24 航线查询及九种对象变更拒绝；源和包外探针/EXE/PCK/copied gold 与当前字节一致。旧 PCK 99743ae6… 是此前航线批次，313cf74b… 是此前库存批次，各自仅保留历史证据。
- 容量候选四产品文件独立复审无 P1/P2，reviewer 独立回放冻结源 3432 状态/10296 查询，五份实际保存 JSON 校验通过，已关闭候选基础问题。接续继续正式 runner、必要源边界/带实体保存、主树/harness/包；三 key 尚未验收，容量候选尚未进 main。


### 容量矿脉增量复测（2026-10-05）

- actual sessions 78253/78791 均退出 0，manual-capacity-fixed.log 为 4224 次比较/零差异，building-capacity-after-manual-fix.log 为 10296 次比较/零差异；唯一标记齐全、无脚本/解析/泄漏，只有此前已辨识的日志/证书环境提示。
- 冻结源 manual-vein-source.json 与 repeat 字节一致，SHA256 a70dcd038299c35ac323520567cd98573a66e2be630a6284ba6f20b8902b87bc；16 种源资源、1408 合成查询状态，实际默认 mining_machine/oil_extractor/water_pump 提供输出基数。首次猜测不存在的 advanced_mining_machine 导出被源定义检查拒绝，未写金标；随后按真实冻结定义修正。
- manual-capacity-initial-mismatches.json 保留旧候选 2464 个差异。manual-candidate-sha256.json 绑定四文件当前候选；building-only-* 保留先前基础候选，旧 isolated-validation-receipt.json 仅绑定其历史字节，不能直接用来证明当前两文件增量。
- 主树三旧产品文件与原 SHA 保持一致；容量三 key 尚未登记。继续矿脉增量有界复审、真实建造实体保存、正式独立金标与行为 runner。


### 容量主树接入与当前门禁（2026-10-05，三 key 尚未登记）

- 正式 `task27-capacity-queries.json` 经真实冻结源两次导出，4840 状态/14520 查询/24 实载模块，SHA256 80c56fc77fe143bedcc0565423e5acfabde66ca6938885c4e2343145ee8c55e5；combined 金标每行与此前 building/manual 实际源返回值一致。独立 reviewer 回放全部14520且来源/输入/结果/拥有权及接线、包探针无 P1/P2。
- `isolated-formal-capacity-with-save.log` 会话53052实际退出0：三实际query key、24来源/输入/输出/拥有权拒绝及5实体保存。`candidate-validation-receipt.json` 绑定全部候选、源fixture、clone与实存档。实体探针首次preload路径错误及storage测试误写1000分别保留失败日志；storage源值600，修正测试后实际通过，未为此修改产品。
- 四产品 GameState/Codec/Validator/SourceEntityCapacitySystem 与正式 runner/persistence/harness/mapper、包外探针已实际进入 main。`main-apply-receipt.json`、`main-runtime-frozen-sha256.json` 为189依赖，全部旧金标和用户project SHA保持；导出后 `main-product-frozen-sha256.json` 为263产品资源，含新helper/uid。47声明场景，本次选7相关场景，不伪称新全量47门。
- 最初 impact 会话50446 在六场景后退出1：前五通过，InventoryConstruction实际exit0/唯一成功/全部断言通过，但外层将显式拒绝 circuit_recipe 的日志当 unexpected ERROR。`resume-main-harness.mjs` 核对唯一精确诊断及其实际立即PASS，保存原失败receipt后修正分类；没有修改产品或重跑有效五场景。相关6个真实结果保留，完整DSP harness 会话29325继续，报告不可提前验收。
- 新 PCK 7fa857ea188bd3b7fa5dccc60f68e9adb5369000fffc6c74fd4068213f3404cc，268资源，开发/测试/fixture文件未进包；EXE仍d34d36f3…。headless32804与OpenGL16891实际exit0，每组七阶段/37保存/3C0/4840容量+153Solar+24路线状态及九内部对象变更；默认渲染器30196运行中，三组合审计待完成。
- Scope 保持受控只读容量；正式资源选取仍缺fire_ice/fractal_silicon/kimberlite_ore/optical_grating_crystal/organic_crystal/spiniform_stalagmite_crystal/unipolar_magnet/sulfuric_acid八种。合成绑定不能冒充真实采集；实体保存仅铁矿三矿机、熔炉/仓储。三key未登记，矩阵仍257/518/298/26。


### 容量三项登记收口与真实站点字段修复（2026-10-06）

- 实际付费放置并堆叠到 2 座物流站后，旧候选 input/output 为 600，冻结源应为 1200；原 paid-station-before-fix.log 退出 1。根因读取 machine_count，而真实站点写 station_stack_count。提供者现按 kind=station 优先读实际堆叠字段，保留旧字段回退；正式查询和包探针输入也改为真实字段。修正后的 probe、4840 状态专项、24 拒绝和五次六实体保存均实际退出 0；保存包含三铁矿机、熔炉、仓储与付费站点。独立复审额外回放四种源站的 1056 查询，无 P1/P2。
- 旧完整 harness 29325 在缺陷确认后识别并停止精确 Godot PID1740，退出 1，不能作为完整通过。原日志/receipt/7fa857ea 包证据保留。当前主树 26027 完整 harness 实际退出 0；main-validation-receipt.json 审计 260 key/189 依赖/101 源哈希，原257 proof的金标哈希和完整断言保持，每项容量 key 为9680实际断言。本批两场景新实跑+五未变相关场景复用，不是新全量47门。
- pre-record-evidence.json SHA256 6318d080702d15a64ea14f80e233142e96cf6873e27b9d3280ebc5dc87376b78，登记前 manifest SHA256 54d74a362fac9aed0ce3aecb379c1df98a6f83589064b4a7e7d40dbf7c7adcfb。三项容量已由 record_parity_verification 实际登记，checklist、189依赖录入完整性与归属回归均退出0。当前矩阵260/515/298/26，813非在线待验收；登记后的manifest不冒充旧报告原始快照。
- 当前 PCK 08cde4c04e502502a7bacc10a841f8fbf1ac4e0bc46cf67ee04f0f4a7ee5085b、268资源，headless96893/OpenGL43691/default73605均实际退出0；package-validation-receipt.json严格审计21唯一阶段/111实际保存/9C0，每种4840容量状态/14520查询、153Solar、24航线、九内部对象反例与当前189依赖/263产品SHA。此包只证明局部自动旅程，旧Solar及7fa包是历史证据。
- 下一批槽位金标两次真实源导出2816查询/24模块，SHA256 5a22b0aead28376ced5a1ba787de2e2b2ac02d72e3905f0dc734f0292e436522；初步probe退出1，输入映射还须核对，未登记。路线实际站点形状probe首次退出2：把初始化源星图缓存也纳入查询前后比较；该结果是探针边界问题，尚不能声称功耗复现通过。后续在准备目录分离初始化再定位；无槽位/路线产品改动进入本次已冻结main。


### 航线功耗真实堆叠字段修复接入（2026-10-06，主树新报告待验收）

- 首次实际形状 probe 把 InterstellarRouteSystem 初始化时填充的 _source_catalog_cache 纳入 query 拥有权边界，退出2；分离初始化后 readonly 查询拥有权保持，原产品3168状态/47520字段实际退出1，4128差异仅为powerKw/energyMjPerTrip（各2064）。原失败及输出保留，不用早期探针错误声称产品查询有副作用。
- 根因为实际站点只写 station_stack_count，_rated_power 原只读 machine_count。候选优先实际字段并保留旧字段回退，其他路线/派遣守卫未改；runner与包探针删除合成 machine_count 别名，旧fixture及claims不改。三个实际 paid 保存测试先补齐资助殖民的托盘/视口与探索进度；早期无效保存日志保留。最终旧产品合法3保存反例抓到堆叠2/3在保存前后错误，原始合法两站各消耗2/4/6件。修正后47520字段零差异，三份真实保存和15字段重开结果均通过。
- isolated-formal-route-fixed.log 会话81291实际退出0，3168状态/2实际key、16输入拒绝、单项输出拒绝、raw/nested对象变异和三个派遣守卫通过；追加三次真实保存通过。isolated-validation-receipt.json绑定4候选SHA和实存档。独立reviewer核对源契约、所有字节与修复前后六份JSON，并独立源回放45字段一致，无P1/P2。殖民/科技/材料前置资助，不是赚取成长或完整派遣。
- 四文件已进入main，189实现依赖、47声明场景、263产品资源；main-apply-receipt.json与新SHA冻结完整。主树会话95642执行TestParityRouteQueries、TestSinglePlayerModes、TestStatePersistence与完整TestDSPOnlineParity，新报告尚待验收，旧容量报告不能冒充此实现。
- 新导出PCK c326a6e4589236b4a79886449c83f610c1d4015f3d36008d971fbf0a48894155、268资源，开发/测试文件未入包；包headless83833/OpenGL38758运行，default与总审计待补。旧容量08c包的实际21阶段证据是历史，已保留隔离副本。
- 下一槽位输入核对：GameState.add_building不覆盖station slot，旧2816探针确实写入raw数量、maxStock及11全局上限；1414差异由忽略rated/global limit造成，分别interstellar122/orbital186/planetary402/launcher704。冻结源默认rated分别1000/2000/600/0，不能把所有站统一当600。槽位候选仍只在研究阶段，未接main。

### 航线真实字段修复收口与槽位复审接续（2026-10-06）

- 主树95642四场景实际退出0，包括完整DSP行为及其拒绝检查。main-validation-receipt.json绑定260 key/189依赖/101源哈希、三份真实两站付费保存；pre-record-evidence.json SHA256 6ebb383e07e3a721e045b5d747f4130112be24e81012ae2d8118300ed8560296。两个已有航线key由工具刷新，manifest/rules字节保持，checklist、录入完整性与归属回归均通过。47声明场景，本批仅四新相关场景，旧容量08c及Solar报告保留历史。
- 新PCK c326a6e4589236b4a79886449c83f610c1d4015f3d36008d971fbf0a48894155 三种渲染器包实际退出0，package-validation-receipt.json审计21阶段、111真实标准JSON保存和9C0恢复文件；每种4840容量状态/14520查询、153Solar、24航线、九内部对象变异，189依赖/263产品资源及268包资源匹配。
- 槽位原2816查询实际1414差异，正式源金标补8缺buildingId案例后2824查询，两次字节一致SHA61b097ffff914410faeb3e727c4aaef00bda4de46897295d59a7514adb5d4149。五产品候选与八实际保存初版通过，但独立复审发现公开旧capacity=100配置与新rated容量600冲突：原保存guard拒绝入库后状态、原arrival guard阻塞实际派出货物。原8保存证据移入before-low-capacity-review，不能充作最终6产品证明。
- 已补真实付费小配置、满rated入库、限额下降后25货物在途保存/重开/完成125与75并返回载具、native配置等四新增保存。source储存/送达按既有1000×堆叠绝对保留容量（采集器2000×），准入仍按rated/global/maxStock，native/custom仍按旧配置。review-original-guards-reproduction.log实际exit1/11保存/2业务失败；review-low-capacity-fixed-final.log实际exit0/12保存/0错误。首次复跑遗漏codec剔除的临时power，日志保留；恢复受控power后才重新复现旧arrival守卫。最后补源1001与native101恶意保存拒绝检查、增量复审进行中；未接入主树或标绿。

### 槽位复审关闭并接入主树（2026-10-06，新完整报告待实跑）

- 41224最终隔离专项实际退出0，2824查询/5648断言/25拒绝/12实际保存。reviewed-isolated-validation-receipt.json绑定6产品+3测试+scene十SHA和十二JSON；source1001/native101非法保存拒绝。独立复审核对实际源、十SHA和新增四保存，关闭低旧capacity与arrival原P2，无新P1/P2。
- six products +正式导出/harness/mapper/包探针已进main，192依赖/48声明场景/263产品资源，旧fixture与用户project保持；正式tools/export_task27_slot_capacity_gold.mjs实际两次61b097ff…字节一致。主树9场景85232运行，前两专项已通过，完整harness尚未验收，旧189依赖报告已保存为previous-route-evidence.json。槽位key未登记，矩阵260/515/298/26。
- 新PCK a53517be6dac91b76fb9e13abebaa6f1e8ebb414207ce6fb206eaa061981d8a8、268资源，headless94083/OpenGL49627实际退出0，default66967及21阶段总审计待完成。包增加2824受控slot查询，不冒充十二源付费保存/实际承诺送达或全成长。下一item input源导出仅在忽略目录进行，当前实现SHA冻结不改。

### 槽位容量正式收口与物品输入容量隔离接续（2026-10-06）

- 主树85232九新相关场景实际退出0，main-validation-receipt.json绑定完整harness261key/192依赖/101源哈希、所有旧260proof精确保持和12实际源付费/native保存；预录入报告SHA 0573fd4e3b89d67ca846cc6d9bcc5fd7c775366397e54222b56fbdea918a4214。2824源金标61b097ff…、5648断言/25拒绝已正式登记commands:engine.getStationSlotCapacity，当前261/514/298/26。48声明场景，本批不是新48全量门。
- 当前槽位修复PCK a53517be6dac91b76fb9e13abebaa6f1e8ebb414207ce6fb206eaa061981d8a8 三渲染器实际通过，package-validation-receipt.json审计21阶段、111真实保存JSON和9C0；每种2824slot、4840容量/14520查询、153Solar、24航线和九内部对象变异。192依赖/263产品SHA/268包资源保持。
- 下一物品输入容量在忽略clone实施四产品原型：45696查询源两次SHA2ef24694…，真实核心覆盖激活36状态/108比较两次SHA065b490b…；原付费maxStock1带实际送2件被抓获，修正后1+1守恒。独立复审发现ContentPack只更新physical容量，实际105比较差异已复现并修正已有source_input/output字段同步，36状态零差异；四产品复审已关闭P2。
- 6520实际隔离存档10份均primary摘要读回，覆盖付费station、实际付费喷涂及可选proliferator限额1、真实均分受限1/其余5、允许核心覆盖capacity300、native保持；不是赚取材料成长。严格完整ownership/正式proof会话78193实际退出0，45696查询/91392断言通过，isolated-validation-receipt.json绑定四产品SHA、两金标和十真实保存；拒绝测试未完成，未进main/harness/mapper/package/登记。首次新probe的错误属于dsp_splitter别名、native不支持源stock API及浮点字典/运行瞬态断言，日志保留；未作为新增产品反例。

### 物品输入容量主树验证进行中（2026-10-06）

最终隔离收据绑定12候选/14接入SHA，199依赖与49场景集合经独立复审一致；高容量保存P2已关闭，14实际primaryJSON已独立解析。main-apply-receipt.json与formal-source-export-receipt.json已实际生成；6产品及五永久测试已进main，三金标正式工具各两次字节不变。main-impact.ps1十二相关场景与run-packages.ps1三renderer仍在运行，登记保持261。原a535PCK已保留在槽位批verified-CardFactory.pck，新6f256d01…资源导出268检查通过，尚待完整包收据；当前包不能冒充旧a535证据。下一资源储量仅有忽略目录4328源查询两次SHAe6cf8b35…，没有main修改或登记。

### 资源放置和正式选取隔离验证（2026-10-06）

资源批接续（2026-10-06）：仅在.godot/task27-resource-probe与task27-next-resource-reserve/candidate隔离修正3产品和目录生成器；原正式源16资源实际付费安装两次SHAf30f6792…，主树原放置13/16差异已复现，修正source extractor最近合法资源点及13固体/1油/2海洋目录后清零。四永久测试+场景+正式fixture/exporter已暂存，独立审查七文件无高置信P1/P2；permanent-validation-receipt.json实际核对16付费放置、15原子/距离/等距/native/custom边界、23源fixture拒绝和32primary磁盘往返。正式Main Inspector实际16资源选择、13绑定变化、15失败不变、16后续磁盘往返通过；含先前缺失八种资源，但尚不构成MAIN/PCK正式资源验收。三个集成文件暂存为204预计依赖/50声明场景，harness将实际运行资源保存/UI检查但不授新key；MAIN当前199容量批冻结保持，待容量收口后接入。源储量4328查询两次SHAe6cf8b35…仅为显式mode参数原型，未接公共设置/矿业。下一吞吐5760实际source installMiner数量1/2/3+付费供电/断电+完整advanceSimulation、储量/缓冲/研究边界两次SHAe55bb244…；本地差异诊断运行中，未宣称吞吐通过。全部使用受控科技和资助建造件，不代表完整赚取成长。

第一版永久UI测试在_ready期间挂载tree.root触发busy children；实际失败日志保留。最终helper先await process_frame，isolated-permanent-tests-ready.log实际退出0、唯一PASS、零Script/Parse/泄漏；32实际存档均解析核对。不是产品修复失败，也不复用失败日志。源库101哈希与主树199冻结已实际核对，尚无MAIN/PCK接入或安装key登记。

### 物品输入容量正式收口（2026-10-06）

- 冻结源45696查询24模块两次SHA2ef24694…、实际允许core pack注册/激活36状态26模块/108provider比较两次SHA065b490b…；另有high pack36状态26模块/144返回值两次SHAc89bdcf2…；源金标未反推。原真实付费station maxStock1普通带送2已实际捕获，修正后输入1/来源1；实际核心input/output覆盖原105差异清零。新helper处理slot归一化、first duplicate、legacy stored item、collector排除、station优先及精确spray tier/限额。native/custom物理准入和黑洞/量子专用分支保持。
- 原轻量候选810浮点tier membership+16缺building问题已在诊断修正，首版map/template保留历史且禁止重跑。最终十二候选SHA及十四集成SHA已复审；严格45696/91392、29拒绝/九旧对象变异与十四实际paid building/belt/spray/balanced/core/native磁盘往返通过。真实合法pack2000入库1500却保存失败已复现，storage retained bound与validator前置amount上限同步修复；实际1500/降准入保留1500/星际2500/采集器4000四磁盘往返通过，native/type/physical capacity约束保持。persistent比较不声明command history磁盘恢复；controlled供料/科技/power不等同于赚取成长。
- main-validation-receipt.json绑定十二新相关场景，包含完整harness262key/199依赖/101源哈希，所有旧261proof精确保持；预录入报告SHA 0c0ff3549b62bc914a4b3eb063c18852eae8f85848c3f9db9a891574120699df。新commands:engine.getEntityItemInputCapacity从未实现登记，当前262/514/297/26，录入完整性/归属回归和台账通过；49声明场景，本批不是新49全量门。
- 当前PCK 6f256d0160099a4b89abbd0935c9f45d6bcd6efb5ce82cc767b4dffe9b99ee26 三种renderer包实跑0，package-validation-receipt.json审计21阶段/111真实保存JSON/9C0；每种45696item query含非空history/spatial哨兵、36低容量及36高容量实际核心包激活比较与restore、2824slot/4840capacity/153Solar/24route/九对象守卫。199依赖/263产品SHA/268资源保持。完整成长、人工旅程、八种正式资源选取和全部安装吞吐仍待验收，任务27整体未完成。

### 资源放置接入主树，采矿产量差异复现（2026-10-06）

资源批接续（2026-10-06）：已将独立复审通过的3产品、目录生成器、四永久测试/场景/正式fixture/exporter及三个harness集成文件接入主树，main-apply-receipt.json绑定204依赖/50声明场景/263产品。原正式源16资源实际付费安装两次SHAf30f6792…，旧放置13/16差异已复现修正；13固体/1油/2海洋目录和最近合法资源绑定覆盖先前缺失八种资源。隔离永久场景16付费绑定、15原子/距离/等距/native/custom边界、23fixture拒绝及32primary保存实际通过，正式Main Inspector实际16选择/13绑定变化/15失败不变/16保存；三渲染器隔离PCK09eee844…资源专项实际通过96保存，不能代替主树完整包。主树十二相关场景会话60109已有十一通过，完整DSP harness仍运行。主树新PCK2d0f392d…实际导出268资源，八阶段包检查headless35573/OpenGL55283/default38479运行中，尚无完整MAIN/PCK资源收口结论；旧物品容量6f包已保留历史。矩阵保持262/514/297/26，不登记installMiner。储量4328源查询两次SHAe6cf8b35…仍仅显式mode原型。吞吐5760实际源advanceSimulation两次SHAe55bb244…；修正探针detached site后本地实际3069案例差异已复现，整数周期/数量/消耗余数待修。受控科技、资助建造和合成数量不代表赚取成长。

原throughput-detached-site-diagnostic.log的3456差异来自探针失效的site引用，不作储量证据。throughput-live-site-before-fix.log实际退出1、3069/5760差异：output3069、progress2760、utilization2760、production_rate1993、remaining759、remainder274；无脚本/解析/泄漏。正式源码和主树资源验证冻结，后续产量修改使用新的忽略副本。

### 资源放置与正式选取收口（2026-10-06）

任务 27 继续实施，当前登记矩阵为262已验证、514实现中、297未实现、26在线排除，811非在线key待验收。资源放置批已正式收口：3产品及目录生成器修正原13/16绑定差异，覆盖全部16源资源和先前缺失八种资源；16付费绑定、15放置边界、23fixture拒绝、正式Main16选择/13绑定变化/15失败不变和32primary磁盘往返通过。主树十二相关场景实际退出0，含完整harness262key/204依赖/101源哈希，全部旧262proof/claim保持；50声明场景，本批并非新完整50门。当前PCK2d0f392d…/268资源三渲染器各八阶段实际通过，合并审计24阶段/207保存JSON/9C0，含96资源primary和此前物品/内容包/槽位/容量/Solar/航线查询及拥有权守卫。独立复审指出旧证据哈希与Windows跨盘路径审计缺口，修正后反例拒绝、实际证据复核通过，无未关闭P1/P2。本批不登记installMiner，完整数量/守卫/吞吐、源资源模式、完整赚取成长、人工旅程和最终发布仍待验收。容量6f/槽位a535/航线c326及之前包证据保留历史；恢复入口.godot/task27-next-resource-reserve/。未提交/未推送，用户project.godot保留。

资源批接续（2026-10-06）：主树资源放置和正式选取已收口，main-validation-receipt.json与package-validation-receipt.json绑定当前204依赖/263产品/2d0fPCK。全部使用受控科技和资助建造件，不代表完整赚取成长或全部安装命令守卫。下一采矿候选仅在.godot/task27-source-mining-probe与task27-next-source-mining/candidate隔离修改ProductionSystem：整数周期、四位相位、实际source容量/数量、十分之一储量余数；源5760默认advanceSimulation两次e55bb244…对齐1秒调用后候选实际退出0/零差异。早期.25步长与源1秒调用的相位/末步状态差异不能充作源bug；60Hz实际源session金标和候选、真实供电/partial-save接续仍在验证。储量4328源查询两次e6cf8b35…仍仅显式mode原型，未接公共设置/矿业；不宣称吞吐批已交付。

完整主树报告SHA 120bbb34df4c549ac36bc3fe445cbd5e3416cd49a5b45a3b0cdea5bd8bbc5902，manifest/rules字节保持。两条审计P2已有实际内存反例，修复和复审闭合；未删除有效运行产物，没有为审计脚本修正重跑产品场景。

### 采矿整数周期、60Hz对照及旧小数存档兼容（2026-10-06，隔离实施）

资源批接续（2026-10-06）：上一资源放置批已正式收口，MAIN204/50声明场景、PCK2d0f/268资源及12相关场景/三renderer24阶段完整证据保持。下一采矿仅在task27-source-mining-probe与新的task27-source-mining-compat-probe隔离推进，MAIN未改。原 source5760默认advanceSimulation两次e55bb244…，5632及CB0e候选默认1秒对照均实际5760零差异；bounded60源两次3de36209…与完整实时60tick源两次ceacc112…各5760实际会话。真实源last-step-trace确认1秒预算最后tick稍缩短，frost三资源phase0.3546，而60个完整tick为0.3547；不放宽相位容差，不混用两种调用证据。CB0e候选实际16count1/level1资源付费放置和33付费太阳能卡片，32partial/resumed primary往返通过，但独立复审抓到旧合法小数存量取整丢失及depletion_remainder无保存校验两P2。新2产品兼容候选SHA6324df7c…/20e80150…保留旧stock/reserve小数，只有完成周期才写余数，校验可选有限非bool整数0..9；同一旧真实Production适配器生成小数存档测试在CB clone实际退出1、在新compat clone实际退出0/4primary保存/18非法余数拒绝。新compat32付费保存39893、5760default22623、5760live60 63163运行中；旧CB live60 36028仍运行，不代替新候选证据。储量4328仍是显式mode参数原型；没有公共resource mode/安装group command/完整earned growth声明，本批不登记新key。

原paid-save初版16partial成功但全部resume exact因elapsed1.0000000000000013→1.000000000000001的既有JSON表示失败；测试按SaveSystem真实序列化canonical严格比较，未修改产品计时，也不提高生产/储量比较容差。CB0e paid-save-live60.log实际退出0/32存档，legacy-before-compat-fix.log实际退出1保存四份但抓到库存/储量损失及18非法余数未拒绝；legacy-compat-candidate.log实际退出0，保留铁矿0.495/99.5545后产1成为1.495、debt9有效余量98.6545，油0.33/99.67后产1成为1.33/98.67。新两个候选未进入main、harness、mapper、包或登记。


## 采矿正式回归准备（2026-10-06）

资源批接续（2026-10-06）：上一资源放置批已收口，MAIN204/50声明场景、PCK2d0f/268资源及12相关场景/三renderer24阶段证据保持；本批未进MAIN。下一采矿当前2产品候选7f75953d…/20e80150…及17 formal-stage文件仅在task27-source-mining-compat-probe。两次实际源默认5760金标e55bb244…、完整60Hz5760金标ceacc112…保持，bounded60金标3de36209…与last-step-trace证明最后截短tick不能混作实时整tick。6324旧兼容候选曾通过5760default/live60和32付费primary；独立复审再抓到近满仓EPS多放一件，真实旧算法生成179.00005库存并保存重开，before实际exit1/180.00005，7f修复后实际exit0/保留179.00005。原小数丢失/非法余数两P2已修复；新finite provider比较拒绝NaN/±Inf/bool/string/null及超误差。small-finite-legacy-fixed.log实际exit0，8非法数值拒绝、3真实旧primary复制加载+3续采保存、27非法debt拒绝/3小数边界。隔离PCK268资源仅resourcemining/headless实际exit0，38primary JSON独立审计通过，非三renderer完整旅程。正式11520数值/64corpus拒绝/32paid+6legacy主档专项session56674在运行，日志permanent-tests-finite-final.log；之前1353与61975已主动停止，均不是通过证据。当前正式集成候选213依赖/51场景；MAIN仍204/50。下一步专项实际完成与复审后20文件apply-main，再MAIN12相关含完整harness、当前9阶段×3renderer包及审计。公开resource mode/group安装/完整赚取成长仍待验收，本批不登记新key；所有恢复入口.godot/task27-next-source-mining/。


## 采矿主树接入（2026-10-06）

采矿主树接续（2026-10-06）：20已复审文件已实际接入MAIN，当前213依赖/51声明场景/263产品；用户project.godot SHA6bfd8d…保留，未提交/未推送。正式隔离专项actual exit0，两cadence11520零差异/64corpus拒绝/32paid primary+3实际旧primary复制加载+3续采保存/27debt拒绝/3小数边界，8非法数值比较反例通过；独立复审7项产品/测试/审计发现均关闭，receipt6baf21de…与review-receipt绑定当前17formal+3package。旧资源批MAIN204/50、PCK2d0f为完整历史证据，previous-resource-evidence SHA120bbb…与verified-CardFactory.pck保留；当前新PCK717fa0e0…已导出268资源并通过内容检查，但其三renderer各9阶段仍待完成。MAIN12相关含完整213依赖/262key harness会话62882正在运行；包会话62931headless/15547opengl/51691default正在运行，输出本批main-impact/receipt.json和package-{renderer}.log。矩阵仍262已验证/514实现中/297未实现/26online排除，811非在线key待验收，本批不新增installMiner/resource-mode/group/earned-growth声明。待实际MAIN与包审计和独立复核后收口；恢复入口.godot/task27-next-source-mining/。


## 采矿导出包审计完成（2026-10-06）

采矿主树接续（2026-10-06）：20已复审文件已实际接入MAIN，当前213依赖/51声明场景/263产品，用户project.godot改动保留，未提交/未推送。正式隔离专项实际退出0，11520零差异/64金标拒绝/32付费primary+3实际旧primary加载/3续采保存/27余数拒绝/3小数边界及8非法数值比较反例通过；独立复审7项发现均关闭。当前717faPCK/268资源三种渲染方式均已实际退出0，每种9阶段；包收据750631ed…合并审计27阶段/321保存JSON/9C0/96资源primary/114采矿primary，独立只读复核已完成、无未关闭P1/P2。旧资源2d0f包及报告120bbb…保留历史。MAIN12相关场景会话62882已11场景实际退出0，最后完整213依赖/262key harness仍在运行，尚无本批新MAIN收据，不能复用旧报告冒充通过。矩阵仍262已验证/514实现中/297未实现/26在线排除，811非在线key待验收，本批不新增installMiner/resource-mode/group/earned-growth声明。恢复入口.godot/task27-next-source-mining/，待最后harness及MAIN独立复核后收口。

## 采矿主树与导出包正式收口（2026-10-06）

任务 27 继续实施，矩阵保持262已验证、514实现中、297未实现、26在线排除，811非在线key待验收。采矿批已接入主树并收口：16源资源的整数周期、四位相位和十分之一储量余数完成对照，保留合法旧小数库存/储量，拒绝非法可选余数，并修复近满仓多产一件。两种实际源模拟节奏各5760案例，共11520数值对照零差异；64金标漂移拒绝、8非法数值比较反例、32真实付费全引擎primary保存、3实际旧primary复制加载/3续采保存、27非法余数拒绝及3小数边界通过。主树12相关场景实际退出0，含完整262key/213依赖/101源哈希harness，旧262proof/claim保持；当前51声明场景，本批并非新完整51场景门。当前PCK717fa0e0…/268资源三种渲染方式各9阶段实际退出0，合并审计27阶段/321保存JSON/9C0，含96资源primary和114采矿primary，旧查询及拥有权检查保持。产品、测试、审计的7项发现已修复并独立复核，无未关闭P1/P2。数量/模式是受控数值输入，真实付费安装覆盖count1；本批不新增installMiner/resource-mode/group安装key，也不证明完整赚取成长、人工旅程或最终发布。旧资源2d0f及容量/槽位/航线包保留历史；恢复入口.godot/task27-next-source-mining/。未提交/未推送，用户project.godot改动保留。

采矿批接续（2026-10-06）：main-validation-receipt.json、package-validation-receipt.json及main-package-review-receipt.json绑定当前213依赖/263产品/717faPCK与实际证据。下一批从公开getResourceReserveSnapshot及资源模式切换开始；现有4328源查询仅为显式mode参数原型，需接入真实状态、正式设置、采矿和保存兼容后才登记。完整安装数量/守卫、完整赚取成长、人工旅程及最终发布继续待验收；不得将受控资金/科技或合成数量当作对应证明。

完整主树报告SHA ca0bafb90ad228aca2d1468dbdbbc03c546e5ca3128806c566c71a3264e257c0；当前包SHA 717fa0e087c753b09198d0bc0882096449f8008908bf2bb165d9730c769883f0。MAIN与包收据绑定当前20文件，保留旧资源报告120bbb34…及旧2d0f包。此前仍在运行的记录为历史过程，只有本节对应的新12场景/三渲染器完成收据作为当前批通过依据。未重跑已完成且输入未变的产品检查。

## 资源模式候选与旧小数兼容（2026-10-07）

资源模式候选接续（2026-10-07）：隔离副本已实施持久resource_mode、公开储量查询、统一无限判定和正式设置确认/取消/关闭/忙碌/旧会话保护；旧schema v9缺省finite。5正式场景实际退出0，4328原源查询、36金标漂移拒绝、48受控容量付费全引擎序列/144阶段主档、312手采资源领域投影/6主档及正式Main入口通过。旧小数P2已实际失败复现并修复，5边界/35主档/14逐件手采保持原始小数与整数余数，源整数取整金标不变；本批合计187不同primary+1UI备份。完整11520采矿回归/64金标拒绝/38主档通过，正式三个导出器重导字节一致，产品/正式测试/审计独立复审无未关闭P1/P2。MAIN仍为263产品/213依赖/51声明场景/717faPCK；32文件接入准备在忽略目录完成，候选264产品/224依赖/56声明场景的完整harness运行中。尚未接入MAIN或登记新key；14初始容量差距及源手采进入vein.outputs、原生进入tray的差距明确待修复。恢复入口.godot/task27-next-resource-mode/；完整安装/赚取成长/人工/最终发布仍待验收，未提交/未推送。

原容量序列出现322差异：无限耗尽矿脉未恢复，以及14有限资源初始容量因native site ID参与jitter而与源vein ID不同。未覆盖/reset合法旧储量；受控序列仅将已捕获native容量作为明确源输入，原始source容量结果另存历史。查询ratio由源原始IEEE754位传递，解决JSON跨运行时读回精度问题，未放宽精确比较。手采第一次探针误改PlanetSystem返回的副本，修正为真正登记记录后通过；手采证据限定数量/余数/事实，未授manualMine完整key。

实际旧primary复现0.55/利用9时自动5件而查询耗尽、手采拒绝；修复原生登记资源点的有效余量读取，保留query显示取整及显式源vein投影金标。原生识别纯读完整六字段，不依赖kind缺省、ID字符串格式或暖Galaxy缓存；复制记录带kind=vein亦验证。subunit/crossunit/exhausted/level8/level1五profile，35主档及14逐件续采保存/模式往返通过。独立产品P2关闭。

正式测试最初误用不存在的SOURCE_CATALOG_PATH导致Parse/Script错误，修正为既有ROOT路径后重跑三个受影响场景；错误日志保留，不计通过。审计发现permanent未绑定已审264产品全表的P2，补deepEqual及收据SHA约束，实际在隔离Production添加无语义注释的漂移反例被拒绝且未写通过收据，finally恢复原字节；独立复审关闭。正式收据SHAc9f16308583058022f47bee2fe4377486243a9ae8ee7979aa4a23ac77869d7a1，候选收据SHA2ce2c2b6d6ff1ff9addbe81f6de860b561368992b69e161f818ddc851465d9f4，旧/失败日志均保留。

## 资源模式主树接入与星图修复（2026-10-07）

资源模式主树接续（2026-10-07）：已复审33文件接入MAIN，当前264产品/224实现依赖/56声明场景，矩阵保持262已验证、514实现中、297未实现、26在线排除。隔离5正式场景、4328查询/36漂移拒绝、48受控容量全引擎序列/144阶段主档、312手采领域投影/6主档、5旧小数边界/35主档及正式Main设置通过；合计187不同primary+1UI备份。旧小数query/manual/production不一致与真实Main星图无限标签P2已失败复现、修复并独立复审关闭；星图有限显示保留原储量。11520采矿回归/64金标拒绝/38主档、11候选相关场景及三个正式导出器字节重导一致通过。隔离原224依赖完整harness仍在运行，主树6专项及12相关场景正在重跑，尚不计通过；当前717faPCK只作历史，当前主树Windows包待导出验证。未登记新key；14初始容量差距和源手采输出目的地差距待修复。恢复入口.godot/task27-next-resource-mode/；完整56场景、安装/赚取成长/人工/最终发布仍待验收，未提交/未推送；用户project.godot改动保持。

原始264产品候选保持供正在运行的harness使用；新显示修复在独立display-probe中验证，保留32文件历史stage并形成33文件final-stage。显示收据SHAf0c83976b7afc079b64436ba01c571eda2b169522c13bfef99662c2305113cb8，final-stage map SHAa37865af2595ed13a93a2967be32affebcf3c288148bdb308b3efcad275fee90。MAIN接入脚本先核对旧263产品、213依赖/262proof证据、全部33原始和目标哈希、保存JSON、旧fixture及用户配置；备份后逐文件写入并核对224依赖/56场景/264产品。接入收据SHA62621117c84a6e082a1f73918055b9f9e89b6a1a5e0f3aa8e896a7f119255c53。主树测试与新PCK证据尚待后续收口；不复用旧包或旧完整harness声称当前产品通过。

## 资源模式MAIN与Windows包验证（2026-10-07）

资源模式批接续（2026-10-07）：33已审文件已接入MAIN，Godot仅新增1个helper UID，当前265产品/224实现依赖/56声明场景。主树12相关+6正式场景实际退出0，含完整262key/224依赖/101源哈希行为及拒绝harness；旧262proof/claim逐项未变。4328查询/36金标漂移拒绝、48受控容量全引擎模式序列/144阶段主档、312手采领域投影/6主档、5旧小数边界/35主档及正式Main设置和星图显示通过，合计187不同primary+1备份。11520采矿/64金标拒绝/38主档保持。当前PCK4c7e3669…/270资源的headless、OpenGL及默认D3D12三方式各10阶段实际退出0；审计30阶段/885保存JSON/9C0/561模式primary+3backup，保留旧资源/采矿/查询和拥有权检查。产品/测试/审计发现已修复，最终MAIN/PCK收据复核中。矩阵仍262已验证、514实现中、297未实现、26在线排除，不授新key；完整56场景门、赚取成长、人工和最终发布未完成。初始容量下一批仅隔离候选：12源初始状态/1268资源点重复金标一致，原1181容量差异修复后0差异，旧容量兼容/36非法值拒绝/实际旧续采逐字段相等通过；未接入MAIN。手采输出目的地差距仍待修复。恢复入口.godot/task27-next-resource-mode/及.godot/task27-next-resource-capacity/；未提交/未推送，用户project.godot改动保留。

MAIN收据SHA65266e5d35dfa68797d91aa2e969f82f8c0bbb6fa4b7d2f00ba4af77c8723f4a，独立保留完整当前evidence SHAff962e4a51c1e9f67ac73987acfe4e24492e03d233e464405669c669761aa2b5；三个PCK合并收据SHA647d202197550b8b50e3651e4568de2b5e19401d27a02684a43e880176d4a0d0，当前PCK SHA4c7e3669d99f7a287e1e6a43ae76ecf0a76c19d7a8fca03b70e88ded4e4310e9。MAIN审计最初对UI场景名构建成Ui，会拒绝正式文件；修正为UI后六专项和完整收据actual0，独立复审关闭。原32文件/264产品候选full224harness亦actual0并单独审计保留，不能替代最终265产品的MAIN结果。

图形包首次长隔离路径的resume业务断言通过但shader cache错误被严格拒绝；平台获批重跑同样失败，未扩大错误白名单。相同PCK/checker换短目录后两种图形各完整10阶段actual0。实际缓存目录269对236字符，证据支持Windows缓存路径兼容性问题；四份失败目录均保留，不作为通过。实际成功图形包位于.godot/rmode-gl/和.godot/rmode-dx/，headless位于本恢复目录/package-headless/。旧717fa采矿PCK保持历史，不覆盖为当前证据。

## 初始储量下一批隔离进展（2026-10-07）

六seed（含0与31bit最大值）×两baseline选择，共12actual frozen createInitialState、1268veins，重复导出SHA5bec2f902e4e452253a8678e8d85bbb2af478c7a7548a274ab7e46facad0170c。原MAIN87相等/1181容量差异实际exit1，资源集合/无限判定均一致。候选只改GalaxySystem和Validator，28历史sourceID别名取自冻结engine，其他行星生成sourceID作为jitter键；native ID/位置/绑定保留。实际候选1268相等/0差异，候选收据SHA1d4acaa7db9853deee577675b97f0ae6aafbaf96cd5594a34ced5db17bdeb0ee，独立复审关闭有界候选。

只改生成ID的第一代候选会被现有Validator拒绝3份旧primary，错误invalid_resource_reserve；改为接受精确新source容量或精确旧native容量，保留正数/余量上界/整数余数约束。3实际旧copy/load+3重存及12新home primary往返/36非法容量与余量拒绝通过；旧raw资源及building完全保持。后续另补3旧primary各60tick全引擎续采，在当前MAIN与候选各实际写回/重开3主档，整份persistent state逐字段相等；收据SHA96ca4066bd520f799ddaf8251f71e6f1cd75a68537e94acd92a0fd9689da84e8。不能据此称1268点都已持久化或完整殖民/安装/成长通过。

探针前期var字符串推断Parse错误退出0无PASS、直接.gd非场景入口无断言、new-state JSON数字格式字符串不同均未计通过；改用正式.tscn入口、显式String和JSON解析后的严格结构数字精确比较，不用epsilon。失败/诊断日志保留。下一步先转正式金标guard/两个场景，显式处理历史模式序列受控容量再回归；仍不改当前265产品的MAIN或矩阵，不覆盖合法旧储量。

资源模式本批最终收据独立复审已完成：只读重放MAIN与PCK审计，生成收据逐字节一致，无未解P1/P2。当前4c7e PCK另存本恢复目录/verified-CardFactory.pck，旧717fa保留；closure收据SHA6f5a9d439ee4e46f9103fd184e5d39b06adae29cb4f80c125c43f54db5722c38，复审收据SHAe339e9ba66bd7f46e6ee58dd491e6a78b84b1cfbdc0886ec62ff9bc65a950a14。本批验证收口不代表整个任务27完成，当前矩阵/56声明场景与完整旅程边界保持。


## 初始储量 MAIN 与 Windows 包接续（2026-10-07）

初始储量批接续（2026-10-07）：16已审文件接入MAIN，仅GalaxySystem和GameStateValidator两产品文件改变；265产品/228实现依赖/58声明场景。12冻结源初始状态/1268资源点金标重导字节一致，原1181容量差异修复后0差异；新生成和实际登记1268资源点、12完整primary重开、19金标漂移拒绝通过。3真实旧primary复制/3重存/3完整60tick续采及36非法容量/余量拒绝通过，续采全部持久状态与修复前MAIN逐字段精确相同，旧容量/合法小数/绑定未重置。主树7正式+11相关场景本轮实际退出0；隔离副本已完成的11520采矿专项和完整262key harness以265产品/228依赖/101源哈希及全部输入字节绑定复用，共18主树实跑+2隔离实跑证据，旧262proof/claim及原金标逐项未变；新增容量批18primary+3旧backup，模式187primary+1backup、采矿38primary、资源32primary保持。当前PCKbe3e600e…/270资源三种渲染方式各11阶段实际退出0，合并审计33阶段/948保存JSON/9C0，其中54容量primary+9旧backup、561模式primary+3backup；产品/测试/审计及最终MAIN/PCK独立复核关闭。矩阵仍262已验证、514实现中、297未实现、26在线排除，不授新key；初始化测试提供殖民前置，不证明赚取殖民或完整成长。完整58场景门、手采输出目的地、人工及最终发布仍待完成。恢复入口.godot/task27-next-resource-capacity/；未提交/未推送，用户project.godot改动保留。

验证绑定：MAIN收据 ce7a8ef40b57e0ee76fbf550ff9e88baf3064ca1cc0b764076d56cca65dc2f52；包收据 50afa57ca0acfd6bf18e7299d95b2ce3f3a5e261adaa08412a47313a2bca4120；包后置不可变绑定 b77680641958bce30029fc1cfc80d1aa2f5fe92c184b9e699a1b6a05f30e25d9；最终独立复核 569e5860e5d2d95de4b48f832007cda11abdabc606e2e0816521ae29f0c490ab。原资源模式 PCK 4c7e3669… 已保留 .godot/task27-next-resource-mode/verified-CardFactory.pck；本批新包亦单独留存，历史门禁不替代当前证据。

下一批手采只读研究：.godot/task27-next-resource-manual/ownership-research-receipt.json绑定176冻结源流程/880阶段/352真实60tick源会话，重导字节相同；当前储量MAIN实际16默认案例中3流体匹配、13固体产出目的地差异（期望失败退出1）。原208手采函数金标保留。原产品265/228字节未改变，未修native缓存/正式UI/新key；需继续共享输出、部分收取、所有权与旧档兼容链。
