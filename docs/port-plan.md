# 原生忠实移植方案

目标：使 Godot 版的手感、节奏、AI、数值与原版 Flash 一致。做法是把原版 `gameCore` 的 AS3 逻辑逐类移植成原生 GDScript，**不建 Flash 运行时模拟层**。原版反编译源码位于本地 `editable/scripts/`，只读、不提交，下文以 `S/` 指代。

## 1. 原版运行模型（移植必须保持的事实）

| 方面 | 原版 | Godot 对应 |
| --- | --- | --- |
| 舞台与帧率 | 700×600，30 fps（SWF 头和 `Preloader.as:25`） | 视口 700×600，`physics_ticks_per_second=30` |
| 逻辑时钟 | 只有 `gameUniverse.globalUpdate` 一个 ENTER_FRAME，单位、技能、特效都由它手动 `update()`；冷却、持续时间、尸体保留均以帧计 | `GameUniverse._physics_process` 是唯一驱动；移植逻辑**不使用 delta** |
| 2x 速度 | 同一帧内调用两次 `mainUpdateFunction` 和 `updateEffects` | 相同 |
| 实时通道 | TweenMax 按墙钟时间运行：箭和火球的贝塞尔飞行、命中回调、淡出、`delayedCall`。它不受 2x 速度和 `pause()` 影响，只受 `TweenMax.pauseAll` 影响；切屏时 `killAll` | `RWTween` 自动加载，提供同样的 pause_all/resume_all/kill_all 语义 |
| 动画 | `BmpFrames`：启动时把 MovieClip 逐帧烘焙成位图。每逻辑帧推进 1 帧，帧命令码 STOP=1/DONE=2/ACTION=3 来自子剪辑 `c_stop`/`c_done`/`c_action`；同一帧有多个时取 action > done > stop | 现有 SpriteFrames 图集 + `data/anim_commands.json` 命令码表；由逻辑手动设帧，不自动播放 |
| 命中时刻 | 近战在 DONE 帧结算；远程在 DONE 帧出手，箭落地回调时结算 | 相同 |
| 随机数 | `utils/Utility.rand` 是 xorshift32，种子取 `Math.random`，164 处调用（含音效分支） | `RWRandom`，算法和**调用顺序**一致，可设种子 |
| 寻路 | 无 A*。障碍掩码 `pathBD` 为 700×600 不透明位图，用 `draw(obstacle)` 按 obstacle 的**本地坐标**绘制，`getPixel != 0` 即不可走。绕障走 `eObstacleWP` 环形路点，主路线取背景里的 `route*/node*` | 预导出掩码和路点数据，逐函数移植 `checkObstacles` |
| 近战站位 | `serviceUtils/battle`：1 个防守者 + 最多 6 个攻击槽 + 等待队列，无单位推挤 | 逐函数移植 |
| 层级 | 每帧 `ArrayZSorter` 按 y 排序，y 相同按 uid；`uid = globalCounter + randRange(1,20)` 也消耗 RNG | 相同排序规则 |
| 数据 | 嵌入 XML（`data/xml/`）+ 每关一个子类钩子；技能参数硬编码在各技能类里 | 运行时直接解析 `data/xml/*.xml`（`RWXml`），技能常量随类移植 |

## 2. 目录与命名映射

| 原版包 | Godot 目录 |
| --- | --- |
| `utils/`、`bmpani/`、`org/webr3` | `game/rw/` |
| `gameCore/gameUniverse.as`、`globalData.as` | `game/core/` |
| `gameCore/living/` | `game/living/` |
| `gameCore/specials/` | `game/specials/` |
| `gameCore/projectiles/` | `game/projectiles/` |
| `gameCore/levels/` | `game/levels/` |
| `gameCore/serviceUtils/` | `game/service/` |
| `gameCore/Memory/` | `game/memory/` |
| `gameCore/ifaces/` | `game/ifaces/` |
| `Main.as` | `game/core/main.gd`（含启动流程、切屏），`game/core/preloader.gd`（预载/开始按钮/片头） |

- 每个原类对应一个文件。文件名用原类名的 snake_case（`livingObject` → `living_object.gd`），`class_name` 用 PascalCase（`LivingObject`、`ArrowEx`、`SpecStun`）。文件首行注释写 `# 移植自 S/gameCore/living/livingObject.as`。
- 字段、方法、局部常量统一取原名的 snake_case，**保留原拼写和错字**：`curStanse` → `cur_stanse`，`mainAlgUpdateSprite` → `main_alg_update_sprite`，`achives` 不改成 achieves。常量保持原名，例如 `C_DEATH_TIME_AVALIABLE`。这样任何一个 Godot 符号都能机械地反查原版，分头移植的文件之间也不需要额外约定接口。
- 静态单例 `X.self` / `X.instance` 统一写成 `static var inst`。
- AS3 的 getter/setter 改为同名 GDScript 属性（`var cur_damage: float: get = ..., set = ...`）。
- 单位和特效是 `Node2D`，自身没有 `_process`。分析脚本（统计、站点 API、域名锁、`bLoader`、预载进度）不移植。

### 运行时接口约定

- `RWTween` 是静态外观（autoload 节点名为 `RWTweenRunner`），代码中一律直接写 `RWTween.to(...)`、`RWTween.delayed_call(...)`，测试中也一样。
- 声音节点的 autoload 名为 `SoundSystem`，代码通过 `Sounds.inst`、`SoundLibrary.inst` 访问。

### 界面类与剪辑场景

原版界面类继承符号类，例如 `mainGameUI_ex extends mainGameUI`。Godot 中的对应做法如下：

- `pipeline/clips.py` 生成的 `scenes/clips/<符号类名>.tscn`，其根节点是 `FlashClip`。子节点名保留原实例名（如 `eUnitPanel`），文本框是 `FlashText`。
- 界面类写成 `class_name XxxEx extends FlashClip`，放在 `game/ifaces/`。为它建一个继承场景 `scenes/ifaces/<snake>.tscn`：继承对应的 `scenes/clips/<符号类名>.tscn`，并把根节点脚本换成该界面类。创建实例时用 `preload("res://scenes/ifaces/<snake>.tscn").instantiate()`。
- 符号类上声明的实例字段（`public var eUnitPanel`）写成 `@onready var e_unit_panel: FlashClip = $eUnitPanel`。更深层的访问直接用原实例名路径，如 `$eUnitPanel/sSensPanel/sArmor`。
- `gotoAndStop(n)` 写成 `goto_and_stop(n)`，帧号从 1 开始。`TextField.text`、`htmlText` 分别写成 `FlashText.text`、`html_text`。
- 按钮行为（悬停提亮、点击音）由 `utils/buttonClass` 移植而来的 `ButtonClass` 提供。

## 3. AS3 → GDScript 语义规则

1. **除法**：AS3 的 `/` 总是浮点除法，GDScript 中 int/int 会整除。两边可能都是 int 时，必须写 `float(a) / b`。
2. **取整**：`int(x)` 向零截断，GDScript 的 `int()` 相同。`Math.round(x)` 要写成 `floor(x + 0.5)`，因为 AS3 中 -2.5 → -2，而 GDScript 的 `round` 会得 -3。`Math.floor/ceil` 直接对应。
3. **位运算**：`uint` 和 `<<` 的结果要 `& 0xFFFFFFFF`。`>>>` 写成先掩码再 `>>`。AS3 移位数按 mod 32 计算，`>>>35` 实际是 `>>>3`。
4. **取余**：对浮点数用 `fmod`，对 int 用 `%`，符号随被除数，与 AS3 一致。
5. **默认值**：AS3 的 `Number` 字段默认是 NaN，GDScript 是 0.0。原逻辑如果依赖未初始化值，按原语义显式初始化，并加注释。
6. **工具函数**：`Point.interpolate(p1, p2, f)` 等于 `p1*f + p2*(1-f)`（f=1 时返回 p1），方向容易写反。`Point.distance` 对应 `distance_to`。`rotation` 是角度，`Math.atan2` 是弧度。
7. **数组**：`Array.sort()` 无参数时按字符串排序，`sortOn`、自定义比较函数要照原样保留。`splice`、`indexOf`、`shift`、`unshift` 用 Godot 对应方法实现，语义保持一致。
8. **Dictionary 遍历**：`for each` 遍历 Object/Dictionary 时，AS3 的顺序不确定，Godot 按插入顺序。凡是会影响 RNG 调用顺序的遍历，注释"原版顺序不确定"。
9. **随机数**：一律调用 `RWRandom.rand()` / `RWRandom.rand_range(a, b)`，调用次数和位置与原版逐一对应。纯装饰性的 `Math.random()` 可以用 `randf()`。

## 4. 反编译破损

含 `§§goto`、`§§push/§§pop`、`while(true)`、`if(false)` 的函数不能直译。主要集中在：
- `livingObject` 的 update、manageWalkNormal、mainAlgUpdateSprite、checkObstacles、setStance、bringDamage、minusUnits；
- `gameUniverse` 的 mainUpdateFunction、makeUnitDead、continueLoadingLevelData；
- `battle` 的 init、addMeleeAttacker；
- 若干 `spec*` 和 `ifaces`。

处理方式：对照 `editable/pcode/` 中 ffdec 导出的 P-code 重建控制流，并在函数上方注释 `# 反编译破损，按 P-code 重建`。无法确定的地方，在函数注释中写明推断依据，同时记入 `docs/verification.md`。

原版疑点照原样保留，不作修正：`A_ARCHER_COOLDOWN_TAB` 中的 `2223`；`minusUnits` 中 `FR_KNIGHT` 出现两次、缺少 `FR_SWORDMASTER`（需用 P-code 确认是否为原作 bug）。

## 5. 分阶段计划

新核心与旧实现并存于各自目录，等新核心能跑通战斗后再切换入口，随后删除旧的 `battle.gd`、`unit.gd`、`specials.gd`。资源编号、`assets/` 和 UI 场景保持不变。

- [x] **P0 数据准备**：导出动画命令码表 `data/anim_commands.json`、障碍掩码 `assets/paths/`、路点环和路线校验；导出破损类的 P-code；在本地固化导出命令。
- [x] **P1 运行时基础**（`game/rw/`）：`RWRandom`、AS3 数值工具、`RWTween`、`RWXml`、`BmpFrames`、`Sounds`/`soundLibrary`，并配套单元测试。
- [ ] **P2 战斗核心**（类已移植，端到端集成中）：`GameUniverse` 主循环、事件调度、查询 API、输入；`LivingObject`；`battle`；寻路；`meleeFighter`/`rangedFighter`/`mageClass`/`priestClass`/`meleeRogue`/`npcClass`；`arrow_ex`、`smallFireball_ex`、`visualsTemplate`；`levelTemplate` 和第 1–3 关。以第 1 关可完整游玩作为切换节点。
- [ ] **P3 兵种与技能**（类已移植，集成验证中）：其余 40 余个具体兵种、45 个技能、各类特效。
- [ ] **P4 关卡**：第 4–24 关的子类钩子、`levelIntro` 教学关。
- [ ] **P5 界面**（层级剪辑场景已导出，`Main` 已切换为入口并驱动全部切屏）：`mainGameUI_ex`、胜负面板、地图、升级面板、成就、手册、漫画、弹窗、主菜单、暂停菜单，按实例名对应节点，补齐图标多帧状态、提示、动画和滤镜效果。M1 已完成 `Main.as` 本体移植（启动流程、`fadeClearLoadUnfade`、各 `loadX`、音乐切换）并删除旧的 `game/main.gd` 等近似实现，入口场景 `scenes/main.tscn` 已指向新 `Main`；地图 `bOnline`/`eStorageFailure` 的显隐状态与 `is_armor`/`is_save_ok` 不一致，待排查（见 docs/verification.md）。
- [ ] **P6 存档与统计**：按 `storedData` 的槽位结构存档，移植 `globalData` 的 48 项成就统计和 `bonusCalculator`（已有实现，尚未逐项验收）。M1 新增 `game/memory/legacy_save.gd`：首次启动把旧近似实现的 `user://campaign.json` 迁移到新存档 `user://RoyalDefenderGame7.json`（二次开发，原版没有对应逻辑）。
- [ ] **P7 验收**：逐项与原版 Flash 并排对照；固定种子回归测试；更新 `docs/verification.md`。

## 6. 验证

- 每个阶段都运行 `./dev/godot.sh test`。测试一律带 `-- --isolated-profile`。
- 每移植一套机制，都补一个确定性测试：固定 `RWRandom` 种子，按帧推进，断言原版公式下的结果，例如命中帧、伤害、冷却帧数、站位槽坐标。
- 与原版的并排对照，记录关卡、难度、星级、兵种、操作步骤和观察结果，写入 `docs/verification.md`。
