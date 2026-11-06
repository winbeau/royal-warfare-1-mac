# 第二章 M0 框架实施规格

总方案见 `docs/chapter-2-plan.md`。本文是 M0 交给编码代理的实施规格，分两个工作包并行开发：

- **WP-A**：章节流程、存档与界面；
- **WP-B**：战斗框架。

两包的文件归属互不重叠，交界处由下文第 1 节的接口约定连接。新职业、新武器、美术管线不在 M0 里，见后续规格。

## 0. 公共规则（两包都必须遵守）

- 第二章是二次开发。**一代的行为不得改变**。改共享文件时，只能加默认值等于原行为的分支或钩子，不改动一代的 RWRandom 调用次数与顺序。
- 禁止的 git 操作：reset、restore、stash、clean、`checkout --`、switch。不提交，不推送，由主会话负责。
- 禁止 `pkill` 或 `killall` Godot。Godot 一律加 `--headless` 运行，每次都带 `--log-file <scratchpad>/<名字>.log`。测试再加 `-- --isolated-profile`。
- **不要跑 `./dev/godot.sh test`**，全量测试由主会话跑。只跑自己的测试文件和下面列出的一代回归测试：
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file <scratchpad>/<t>.log --script tests/<t>.gd -- --isolated-profile
  ```
- **新加了 `class_name` 脚本后要导入一次**，否则 `--script` 运行时找不到类。两个代理共用一个工作区，导入时必须先拿锁：
  ```
  mkdir build/.godot_import_lock && (/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import --quit --log-file <scratchpad>/import.log; rmdir build/.godot_import_lock)
  ```
  `mkdir` 失败说明对方正在导入。这时先做别的事，稍后重试，不要循环等待，也不要删除别人的锁。
- 代码风格：GDScript 用 tab 缩进和静态类型，注释用中文。二章代码放在 `game/ch2/` 下，命名用 snake_case，不沿用原版类名映射。
- 二章文本只通过 `Ch2Text`（`game/ch2/ch2_text.gd`，已写好）读取，不在代码里写死英文剧情文本。

## 1. 接口约定（两包之间的边界）

| 接口 | 归属 | 约定 |
| --- | --- | --- |
| `Main.current_chapter: int = 1` | A | 进入二章地图时置 2，回到一代地图时置 1 |
| `GameUniverse.chapter: int = 1` | B 加字段，A 赋值 | `Main.load_game` 在调用 `fade_clear_load_unfade` 前写 `game_uni.chapter = current_chapter` |
| 二章关卡下标 | 共同 | `Main.load_game(n)` 的 `n` 为 0 基，二章第 1 关是 `n = 0`。`GameUniverse.cur_level_num = n` |
| `LevelCh2.compute_stars() -> int` | B | 返回 1–3 星。A 的胜利面板调用它，用鸭子类型 `level_info.call("compute_stars")` |
| `LevelCh2.level_number: int` | B | 1 基关号 |
| `data/ch2/levels/NN.json` 的 `"background"` | B 写数据，A 读 | 例如 `"01-mist-bay"`，对应 `assets/backgrounds/ch2/<bg>.png` |
| `StoredData.ch2_*` API | A | 见 2.2；B 只读 `StoredData.ch2_stars` 用于测试 |

## 2. WP-A：章节流程、存档与界面

**文件归属**：`game/core/main.gd`、`game/memory/stored_data.gd`、`game/content.gd`、`game/ifaces/game_map_object.gd`、`game/ifaces/popup_mission_ex.gd`、`game/ifaces/victory_panel_ex.gd`、`game/ch2/ifaces/*`（新建）、`export_presets.cfg`、`tests/ch2_flow.gd`（新建）。

### 2.1 Main

- 新增 `current_chapter`。
- `load_map()` 开头加分流：`current_chapter == 2` 时调用 `load_ch2_map()` 后返回，一代的漫画分支不动。
- `load_game(param1, param2)`：
  - `param1 == 0` 时的 LevelIntro 判断只在 `current_chapter == 1` 时执行；
  - 写 `game_uni.chapter = current_chapter`；
  - 每章各记一个 `last_level_num`，`-1` 重玩的是本章的上一关。
- 新增：
  - `load_ch2_map()`：置 `current_chapter = 2`，播地图音乐，`fade_clear_load_unfade(ch2_map)`。`ch2_map` 用懒加载属性，写法同其他界面。
  - `load_ch1_map()`：置 `current_chapter = 1`，然后调用 `load_map()`。
- `load_upgrade_panel()` 在 M0 不变（第二页留到 M1）。

### 2.2 StoredData（存档）

- 存档 JSON 增加顶层键 `"ch2"`，一代的 `aGameData`、`mainParams`、`endGameFlag` 都不动。默认值：
  ```json
  {"stars": {"1": [0 × 36], "2": [0 × 36], "3": [0 × 36]}}
  ```
  键是难度，数组下标是关号减 1。
- 读写规则：
  - `init()` 读取，缺失或类型不对时用默认值；
  - `save_shared_data()` 写回；
  - 隔离模式下同样只留在内存里（沿用现有的 `_isolated_blob` 机制）；
  - `reset_data()` 和 `sponsor_unlock()` 不碰 `ch2`；旧存档迁移也不碰。
- 新增 API：
  - `ch2_stars(n: int, dif := -1) -> int`：`dif = -1` 时取三个难度里的最大值；
  - `ch2_record_victory(n, stars, dif)`：只在新星数更高时覆盖；
  - `ch2_level_unlocked(n) -> bool`：`n == 1`，或第 `n-1` 关在任一难度已有星；
  - `ch2_available() -> bool`：`end_game_flag` 已完成，或 `Content.ch2_debug_unlock` 为真。
- `Content` 在 `_ready` 里解析用户参数 `--ch2-unlock`，结果存进 `ch2_debug_unlock`。

### 2.3 一代地图上的「东渡」船

- 在 `GameMapObject._added()` 加好 markers 之后，若 `StoredData.ch2_available()` 为真，加一个原生 Control 按钮 `Ch2ShipButton`：
  - 文件 `game/ch2/ifaces/ch2_ship_button.gd`，贴图 `assets/ch2/ui/ship_east.png`（2 倍图，显示时缩放 0.5）；
  - 中心放在逻辑坐标约 (650, 440)，即东侧海面；
  - 以帧计时做 ±2 px 的上下浮动；悬停时 modulate 提亮到 1.15，光标变手形；
  - 点击调用 `Main.load_ch2_map()`。
- 按钮必须在 `_removed` 里摘掉，参照该文件里摘除弹窗单例的写法，否则下次回地图会重复添加。
- 命中区域不能和 markers 里任何按钮或旗帜的包围盒重叠，由测试断言。

### 2.4 二章地图 `game/ch2/ifaces/ch2_map_screen.gd`

继承 Control，尺寸 700×600。

- **底图**：`assets/ch2/map/landmarks.png`，1400×1200，缩放 0.5。
- **水车**：按 `data/ch2/map_watermills.json` 放 7 个 AnimatedSprite2D。
  - 帧来自 `assets/ch2/map/watermill_atlas.png`：64×64 一格，10 列 8 行共 80 帧，15 fps；
  - 脚底原点 (32, 48)，每个水车的 `phase_frame` 是起始帧，`scale` 是缩放；
  - 先确认 landmarks.png 上那 7 处没有画死的静态水车，有就报告，不要自己修图。
- **旗帜**：36 面，坐标取 `data/ch2/campaign.json` 的 `map_position_px`（700×600 逻辑坐标）。
  - 外观与星级显示复用一代地图旗帜用的同一个剪辑和帧规则，照抄 `game_map_object.gd` 的做法；
  - 显示规则与一代一致：已通关的显示星级；下一关显示一代那样的红圈；未解锁的不显示；
  - 点击旗帜打开二章模式的任务弹窗（见 2.5）。
- **按钮**：
  - 返回一代地图：用船图水平翻转，放左下，调用 `load_ch1_map()`；
  - 升级面板和主菜单：外观复用一代地图上对应按钮的剪辑。
- **标题与小节名**：用一代地图的字体（FlashText 或同一字体资源）显示 `Ch2Text.glossary().chapter` 的英文章名，以及当前小节名 `Ch2Text.section_name(n)`。不要另造字体。

### 2.5 任务弹窗二章模式

`PopupMissionEx` 新增 `init_ch2(level_n: int)`，复用同一个实例与动画：

- 标题取 `Ch2Text.level(n).name`，正文取 `briefing`；
- 缩略图取 `assets/backgrounds/ch2/<background>.png`，background 从 `data/ch2/levels/NN.json` 读取；
- 难度选择沿用一代；
- 开始按钮调用 `main.load_game(n - 1)`；
- 若 `data/ch2/levels/NN.json` 不存在：开始按钮禁用，并显示 “Coming soon.”；
- 一代路径 `init(pos)` 的行为不得改变。

### 2.6 胜利面板二章分支

`VictoryPanelEx.init` 在 `GameUniverse.inst.chapter == 2` 时：

- 星数取 `level_info.call("compute_stars")`，星级动画沿用一代；
- 改为调用 `StoredData.ch2_record_victory(level_number, stars, dif)`；
- **跳过**：一代的 COM_VICTORY 存档、第 5/11/17/20/23 关的漫画解锁、`set_end_game_completed`、`check_achievements`（`a_numbers` 置空）；
- 其余逻辑照旧（统计、按钮、`save_shared_data`）。

失败面板不改。它的重开、回地图按钮经由 Main 的分流自然回到二章。

### 2.7 导出

在 `export_presets.cfg` 的 `include_filter` 里加入：

- `data/ch2/*.json`
- `data/ch2/text/*.json`
- `data/ch2/levels/*.json`
- `data/ch2/maps/*.json`
- `data/ch2/masks/*.png`

### 2.8 测试 `tests/ch2_flow.gd`

用真实输入，参考 `tests/input_e2e.gd` 的点击与等待写法：

1. 隔离存档、`end_game_flag` 未完成：一代地图上没有船。
2. 置 `end_game_flag` 完成后重进一代地图：船出现，且与 markers 不重叠。真实点击船后，进入二章地图，`current_chapter == 2`。
3. 二章地图上第 1 面旗可见，第 2 面不可见。真实点击第 1 面旗，弹窗标题与正文等于 `Ch2Text.level(1)`。
4. 点开始后，`main.last_level_num` 与 `game_uni.chapter == 2` 正确（M0 期间 A 包的测试到这一步为止，战斗内容由 B 包测试）。
5. 胜利面板分支：用一个定义了 `compute_stars()` 返回 2 的桩关卡调用 `vic_panel.init`，检查以下几点：
   - 存档 `ch2_stars(1) == 2`；
   - `ch2_level_unlocked(2)` 为真；
   - 一代的漫画标志和 `NUMPAN_LEVELS` 未变。
6. 二章地图上点返回船：`current_chapter == 1`，显示一代地图。

一代回归：`main_flow`、`menu_screens`、`input_e2e`、`input_e2e_new_save`、`comics`、`ifaces_f3`。

## 3. WP-B：战斗框架

**文件归属**：

- `game/core/game_universe.gd`
- `game/levels/level_template.gd`
- `game/service/path_parser.gd`
- `game/living/living_object.gd`（仅限下文 3.6 所列改动）
- `game/ch2/`（`ifaces` 除外）
- `data/ch2/levels/`、`data/ch2/maps/`、`data/ch2/masks/`、`data/ch2/portraits.json`
- `dev/ch2_tools/`
- `tests/ch2_director.gd`、`tests/ch2_levels_data.gd`、`tests/ch2_battle.gd`

### 3.1 核心钩子（默认值等于一代行为）

- **LevelTemplate** 新增两个方法：
  - `allows_default_end() -> bool`，返回 true；
  - `uses_lives() -> bool`，返回 true。
- **GameUniverse**：
  - 新增字段 `chapter := 1`；
  - `load_level(param1)`：`chapter == 2` 时 `level_info = LevelCh2.new(param1 + 1)`，否则走原来的路径；
  - `check_end()` 开头：`if not level_info.allows_default_end(): return`；
  - `minus_health()` 开头：`if level_info != null and not level_info.uses_lives(): return`；
  - `continue_loading_level_data()`：`chapter == 2` 时调用 `PathParser.parse_ch2(level_info, self)`，否则照旧调用 `parse(bg_name, self)`；
  - `init()` 里若 `chapter == 1`，确保生命数 HUD 可见，并清掉残留的二章目标栏。`ingame_ui` 跨关复用，二章会隐藏它。
- 这些分支在一代路径上不改变任何行为，也不改变任何随机数调用。

### 3.2 地图几何：`PathParser.parse_ch2`

数据来自 `data/ch2/maps/<bg>.json`，已从设计包的 `first-six-layouts.json` 转换而来，是粗略的设计意图。

- **路线**：
  - `enemies[i]` 是一条折线（起点在画面外，例如 x=710），作为 MapRoute，编号 `numb = i + 1`；
  - 友军入场路线 0 由关卡 JSON 的 `friendly_route` 给出；没有给出时用 `[recruit + (-40, 0), recruit]`；
  - 先查清一代 `add_soldier` 经 `add_to_game(0, 0)` 加 `set_route(0)` 时怎样使用路线 0，保证新兵从 recruit 锚点附近入场。
- **掩码**：`data/ch2/masks/<bg>.png`，700×600 RGB8，非 0 表示障碍。用 `RWBitmapData` 读取，它在资源不存在时会退回 `Image.load_from_file`。
- **绕障路点** `obstacle_way_points`：
  - 运行时由障碍多边形经 `Geometry2D.offset_polygon(poly, 18)` 外扩后沿边采样，间距约 25 px；
  - 子节点命名必须符合 `LivingObject.check_obstacles` 的解析规则。先看 `data/level_layout.json` 里 `eObstacleWP` 子剪辑的真实命名再仿造：第 2 个字符是环号，从第 4 个字符起是序号；
  - 环号只有一位数，障碍超过 9 个就合并小障碍，或者报告；
  - 用 `RWLayoutClip.from_item()` 能接受的字典来构造。
- **防守旗**：`def_flag_object = null`。
- **种类**：
  - `kind == "bridge_override"` 的多边形表示桥面，要从水面障碍里挖回可通行区；
  - 其他种类一律当障碍。

### 3.3 掩码工具 `dev/ch2_tools/build_masks.gd`

以 Godot headless 脚本运行：

- 读取全部 `data/ch2/maps/*.json`，先画障碍多边形，再挖掉桥面多边形，输出 `data/ch2/masks/<id>.png`；
- 另出检查图到 `build/ch2_masks_debug/<id>.png`：
  - 700×600 底图上叠半透明红色掩码；
  - 敌路画成蓝线，护送路线画成绿线，锚点画成黄点。
- 第 01、02 关先跑出来，自己用 Read 看检查图，确认障碍和底图里的海、盐池、村屋大致吻合。不吻合就修正 `data/ch2/maps` 里的多边形，并在报告中说明改了什么。

### 3.4 关卡类 `LevelCh2` 与任务导演

`game/ch2/level_ch2.gd` 继承 LevelTemplate。

- **`_init(n)`**：
  - 读取 `data/ch2/levels/%02d.json`；
  - 置 `level_bg = "ch2/" + background`；
  - `level_caption` 和 `level_description` 取自 `Ch2Text.level(n)`。
- **`load_xml_data()`**：`a_waves = []`，然后调用 `GameUniverse.inst.continue_loading_level_data()`。
- **`get_locked_units()`**：按 JSON 的 `locked` 锁定招募按钮，写法参照 `level_5.gd`。
- **`loading_completed_handler()`**：
  - 设置金钱；
  - 放置开局兵力，参照一代关卡预置单位的写法；
  - 放置盟军和任务物件；
  - 隐藏生命数 HUD（`e_hp`）；
  - 建立目标栏；
  - 启动导演。
- **其余钩子**：
  - `level_custom_actions()` 调用 `director.update()`；
  - `allows_default_end()` 和 `uses_lives()` 都返回 false；
  - `got_text` 和 `chat_closed` 转给导演；
  - `clear_data()` 释放目标栏，并恢复生命数 HUD。
- **`compute_stars()`**：
  - 胜利得 1 星；
  - 达到关卡 JSON 里 `stars.2` 的条件再加 1 星；
  - 达到 `stars.3` 的条件得满 3 星。
  - 条件只用两种：`losses_max`（本关死亡的己方可控单位数）和 `optional`（可选目标已完成）。

`game/ch2/ch2_director.gd` 是导演：纯逻辑类，持有关卡 JSON 与 GameUniverse，每个逻辑帧 `update()` 一次。

- **阶段状态**：`pending → active → done`。
  - 条件为真时由 pending 进入 active，执行 `do` 里的动作；
  - 本阶段出兵全部完成，且排队的对白与招募窗口都已消耗，即为 done。
- **条件**（可嵌套 `all` / `any`）：
  - `time_s`：本阶段等待开始后经过的秒数，乘 30 换成帧；
  - `phase_done: id`；
  - `cleared: id`：该阶段已经 done，且场上敌人数为 0；
  - `flag: "objective.event"`：目标对象发出的事件，例如 `ferrymen.joined`、`ferrymen.at_mid`、`workers_1.arrived`；
  - `window_closed: id`：招募窗口已结束；
  - `dialogue_done: "D01-a"`。
- **动作**：
  - `spawn`：
    - 参数为 `units: [[kind_id, level, count], ...]`、`route`、`prob`（默认 0.97）、`delay_s`；
    - 导演自己每帧判断 `RWRandom.rand() > prob`，满足就调用 `gu.load_enemy(kind, lvl, route)` 出一个；
    - 不放进一代的波次队列，因为一代的 ENEMY_SPAWN 要等场上清空才计时，做不到二章需要的同时来敌；
    - 难度改等级的规则与一代相同：难度 2 时等级小于 3 的加 1，难度 3 时一律为 3；
    - kind 用设计包的 id，例如 `RW_ZOMBIE`，在 `game/ch2/ch2_kinds.gd` 里映射到一代常量。
  - `recruit_window`：往 `gu.cur_wave_info` 推入一条 GLOBAL_WAVE 记录，表头带 `"ch2_tag": id`。复用一代的红按钮、45 秒倒计时和招募开放逻辑；导演看到带该标签的记录被移出队列，就判定窗口结束。
  - `dialogue: "D01-a"`：
    - 往队列推入 GAME_CHAT，表头带 `ch2_tag`；
    - 每行写成 `{"unitNumberInPanel": 头像 kind, "txt": "<speaker>: <en>"}`；
    - 头像 kind 查 `data/ch2/portraits.json`（说话人到一代兵种 kind 的占位映射，M1 换成新头像）；
    - 对白文本来自 `Ch2Text.dialogue()`。
  - `warn: route`：
    - 在聊天栏发一条 “Enemies approaching from the …” 一类的短消息，方位词由该路线入场点所在的画面边推出；
    - 在入场点附近显示约 3 秒的箭头标记，箭头用一代现有的剪辑或符号，不新画。
  - `objective_state: {id, state}`：显式改变目标状态。
- **胜负**：
  - 每帧评估关卡 JSON 的 `victory` 与 `failure`，满足就调用 `gu.end_game(VICTORY / DEFEAT)`；
  - 失败条件 `no_combat_power`：没有活着的玩家可控战斗单位，且金钱低于当前最便宜的可招募兵种价格；
  - `phases_done`：全部阶段都已 done；
  - `enemies_alive: 0`：场上没有敌人。
- **波次显示**：用 `draw_current_wave(已完成的作战阶段数, 作战阶段总数)`。

### 3.5 目标对象（`game/ch2/objectives/`）

| 类型 | 行为 |
| --- | --- |
| `escort` | 护送 NPC，沿 `path` 锚点依次前进，外观沿用一代 npc 系精灵。前方 60 px 内有敌人就停下，清除后继续；到达各锚点时发出 `<id>.at_<锚点>` 事件。生命归零时不立即死亡，而是进入**倒地**：倒地期间不受伤害，敌人不以其为目标；`downed_window_s` 秒内有任一玩家可控友军在 30 px 内停留满 2 秒，就以 30% 血量扶起；超时则死亡。存活数低于 `min` 时目标失败 |
| `evac` | 分批撤离：`batches` 批，每批 `size` 人，从 `from` 走到 `to`，到达即计数。可以作为普通 NPC 被杀死，不设倒地。每批由导演事件放出，例如 `workers_1.start`。到达数不够 `min_per_batch` 时目标失败 |
| `protect` | 静态设施：有血量和血条，敌人会攻击它，玩家不能选中，不画精灵（画在底图里），命中热区由 JSON 的 `rect` 给出。血量归零目标失败 |
| `pickup` | 可选目标：任一玩家可控单位进入圆形区域，即完成并发放奖励金币 |
| `reach` | 指定数量的玩家单位进入区域即完成 |

**实现要求**：

- 尽量继承一代现有类（NpcClass、LivingObject），复用其寻敌与受击路径。
- 倒地期间不被攻击：先看一代已有的“不可被攻击”机制，例如 `LivingObject.v_untouchable_units`，能用就用。
- 确需改 LivingObject 时，只允许按 3.6 加默认不生效的字段与判断，并在报告里写清楚。

### 3.6 盟军不可控（LivingObject 与 GameUniverse 的最小改动）

- `LivingObject` 新增 `var ch2_uncontrollable := false`。
- GameUniverse 以下选中入口跳过 `ch2_uncontrollable` 为真的单位：
  - `friendly_unit_clicked`；
  - 框选 `stop_selection_box`；
  - `select_all_of_type`；
  - 编组热键。
- 默认值为 false，因此一代不受影响。
- 盟军用 `add_soldier(kind, null, level, true)` 生成，再设成不可控，并驻守 JSON 给出的 `hold` 锚点：用一代的 `zero_point`、站定或防守姿态语义，按 RW1 友军索敌半径自动交战。
- 设施（protect）同样不可控。

### 3.7 关卡数据 `data/ch2/levels/01.json`、`02.json`

- **依据**：设计包 `../royal-chapter-2/design/levels.json` 第 1、2 关的阶段、胜负、盟军与配额，以及 `data/ch2/maps/` 的锚点。
- **格式**：见 `docs/chapter-2-plan.md` 3.2 的示例，并补充以下字段：
  - `background`；
  - `locked`；
  - `friendly_route`（可选）；
  - `start.units`：开局兵力，用一代兵种，按设计说的 6–8 人起测；
  - `allies`：盟军。M0 用一代 `FR_WARRIOR` 3 级充当刀盾盟兵，`kind` 写 `FR_WARRIOR` 并注明占位；
  - `stars`。
- **目标 id 与对白**：
  - 目标 id 必须等于 `data/ch2/text/levels.json` 里对应关卡的 `objectives[].id`，目标栏文字由 `Ch2Text.objective()` 取得；
  - 对白 id 用 `dialogue.json` 里第 1、2 关的事件。
- **数值**：出兵数量与概率是起测值，在 JSON 里加 `"_tuning": "起测值"` 标注。

### 3.8 目标栏 `game/ch2/ifaces_battle/objective_hud.gd`

- 上方居中的小条，`mouse_filter = IGNORE`，不挡任何点击。
- 字体用一代 HUD 的字体资源，或 FlashText。
- 每个目标一行，文字由 `Ch2Text.objective()` 取得，`{n}/{min}/{total}` 实时替换。
  - 完成的目标变暗并打勾；
  - 接近失败时变红，例如设施血量低于 30%，或护送者倒地。
- 挂在 GameUniverse 下、`ingame_ui` 之上。

### 3.9 测试

- **`tests/ch2_levels_data.gd`**：对 `data/ch2/levels/*.json` 逐关检查：
  - 必填字段齐全；
  - 目标 id 都存在于 `levels.json`，对白 id 都存在于 `dialogue.json`；
  - 敌人 kind 都能映射到一代常量；
  - 每条敌路起点在画面外，且第二个点在画面内；
  - 锚点不在掩码障碍里；
  - **可达性**：把掩码按 8 px 腐蚀成通行图，从每条敌路进入画面的第一个点、recruit 锚点和友军路线终点出发做 BFS，必须能到达全部目标锚点。
- **`tests/ch2_director.gd`**：固定种子，覆盖以下内容：
  - 条件组合求值；
  - spawn 的逐帧概率出兵，总数等于配置；
  - recruit_window 与 dialogue 进队、出队后阶段推进；
  - victory 与 failure 判定；
  - 护送者的倒地、扶起、超时死亡；
  - `compute_stars`。
- **`tests/ch2_battle.gd`**：参照 `tests/battle_level1.gd` 与 `tests/support/battle_harness.gd`，第 01、02 关各跑两局，以 1 倍和 2 倍速：
  - **胜局**：测试脚本把每个出生满 N 帧的敌人直接杀死，以此推进阶段。断言全部阶段推进、胜利触发、星数在 1–3 之间、过程中没有脚本错误；
  - **败局**：直接杀死护送者或设施，并让倒地窗口超时，断言失败触发。
- **一代回归**：`smoke`、`universe_core`、`levels_data`、`battle_ifaces`、`main_game_ui`、`extra_obstacles`、`battle_level1`。最后跑一次 `battle_all_levels`，它较慢。

## 4. 交付与汇报

每个工作包完成后汇报（不超过 40 行），内容包括：

- 改动的文件清单，以及每个文件的一句话说明；
- 对一代共享文件的每一处改动，并说明它为什么不改变一代行为；
- 各测试的结果（checks 与 failures 数量）；
- 未解决的问题，以及偏离规格的地方。

不要提交。主会话审阅 diff、跑全量测试，然后提交。
