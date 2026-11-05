# 运行验证与还原状态

测试环境：macOS、Apple M3 Pro、Godot 4.7.2，Compatibility/OpenGL 渲染器。版本：0.1.0。

## 入口与启动流程（M1，本次新增）

- 游戏入口已切换到原生移植的 `Main`（`game/core/main.gd`，`scenes/main.tscn` 的根节点）；旧的近似实现 `game/main.gd`、`battle.gd`、`unit.gd`、`specials.gd`、`achievements.gd`、`original_scene.gd` 已删除，`game/content.gd` 只保留 `BmpFrames` 等新代码实际用到的资源索引（`symbols`/`bounds`/`resources`/`isolated_profile`），不再读取或维护旧的 `profile`/`campaign.json` 读写逻辑（迁移到 `game/memory/stored_data.gd` + `game/memory/legacy_save.gd`）。
- 实际运行一次（非 headless，窗口 700×600）走完完整启动流程并逐步截图：预载画面（分阶段文案 Caching/Preparing animations/.../Final preparations）→ 点击开始按钮 → MaxGames 片头（`maxgLogoIntro`，`done` 信号）→ 主菜单 → 序章漫画（`comix_intro`，依 `NUMPAN_COMIX` 标志选页）→ 点击"跳过"→ 地图 → 点击关卡旗帜 → 关卡弹窗 → 点击"开始战斗"→ 关卡过场 `LevelIntro`（原版 `levelIntro`，友军行军 + "点击跳过"）→ 第 1 关战斗 HUD（目标弹窗、生命/金钱/敌波次面板）。全程通过 `OS.add_logger` 捕获脚本错误，捕获结果为 0 条。
- `Main.load_resources`：按原版 `loadResources` 的 case 编号顺序逐步调用各类 `init_resources()`（内部的 `cache(n)` 数量与原版 `Main.as` 的每个 case 一致，已用脚本逐条核对无遗漏/数量不符），并在 case 76/77/86~89/90/91/98/99 处补齐原版对应的单例初始化（`buttonClass.init`、`storedData.init`、`soundLibrary.init`、`Sounds.initSoundsFirst`、`gameUniverse.initOnce`/`loadLevels`、`gameMapObject.initOnce`、六段漫画、`arrowSwarm`、`miniIcons`、`extDataManager`）。不分帧（一次性在进入第一个界面前跑完），预载进度条直接跳到 100%，但保留预载界面的声音/音乐开关按钮及其状态。
- `Main.fadeClearLoadUnfade`：黑屏淡入 0.3 秒、延迟 0.1 秒、清空 `gameScreensContainer`、`RWTween.kill_all(false, false, true)`（只清延迟调用）、加入新面板、按需 `gameUni.init(level)`、淡出 0.3 秒；时序用 `tests/main_flow.gd` 以 `RWTween` 手动时钟逐段断言（黑屏显隐、容器清空时机、`init` 参数转发）。
- `Main.loadGame(0)`：`LevelIntro.is_shown == false` 时改写为 `-2`（教学关），已覆盖未看过开场、已看过且 `canEndIntro` 为真两种分支；`Main.loadMap`：按 `NUMPAN_COMIX` 标志依次检查 `comix_intro`/`two`/`three`/`four`/`five`/`end`，全部看过才显示地图；两者均有测试覆盖。
- Armor Games 站点 API（`agi`/Kong 连接、`checkArmorQuests`/`setQuestAchieved` 的任务提交、`onlineSave`/`onlineLoad`、站点域名探测）未移植，保留为注释与空实现；`Main.is_armor`/`is_kong`/`is_external_api_enabled` 恒为 `false`，与离线运行下的原版行为一致。
- **已知偏差**：实际运行截图中地图的 `bOnline`（"Online data storage"）和 `eStorageFailure`（"STORAGE SYSTEM FAILURE"）两个提示即使在 `is_armor == false`、`StoredData.is_save_ok == true` 时仍显示为可见，与 `game_map_object.gd._added()` 的显式 `else` 分支（设为不可见）不符；该文件由另一位代理（P）负责，这里未修改，只记录现象，留待后续排查（可能是 `markers` 静态单例在多次 `GameMapObject.create()`/`init_once()` 之间的时序或帧重置覆盖了显式设置）。

## 旧存档迁移（M1，本次新增）

- `game/memory/legacy_save.gd`：首次启动时，若新存档 `user://RoyalDefenderGame7.json` 不存在而旧存档 `user://campaign.json` 存在，自动转换并写入新存档；旧文件保持不变、不删除。迁移只在非隔离模式下触发（`Main._load_step(76)`）。
- 字段对应：`slots[0]`→关卡星数（`NUMPAN_LEVELS`）、`slots[1]`→兵种解锁（`NUMPAN_UNITS`）、`slots[2]`→技能（`NUMPAN_ABILS`）、`slots[4]`→成就（`NUMPAN_ACHIVES`）、`slots[6]`→兵种加成（`NUMPAN_UNIT_BONUSES`）、`slots[7]`→漫画标志（`NUMPAN_COMIX`）、`slots[8]`→zanaves、`slots[9]`→开场教学、`slots[10]`→三级兵、`slots[11]`→已揭示敌人、`slots[12]`→难度（`NUMPAN_DIFFICULTY`）、`slots[13]`/`slots[14]`→中/高难星数；`sound`/`music`/`autopause` → `mainParams.sound`/`music`/`autop`。
- 未迁移项：旧存档没有 `hints`（战内提示开关）对应字段，迁移后保持新存档默认值 `true`；旧存档的 `intro_seen` 在新存档里没有对应字段（开场漫画是否看过已由 `slots[7].comix_intro` 表达），不迁移，记入迁移报告但不报错。槽位长度或类型对不上时该槽单独保持新存档默认值，同样记入报告，不影响其余槽位。
- `tests/main_flow.gd` 用隔离模式验证：纯函数级别的字段映射（含"对不上保持默认值"的分支）、以及端到端的文件级迁移（新存档不存在时执行一次、已存在时不重复执行、旧文件不被删除）。

## 已验证（P0–P5 已有内容，未变动）

- 6,620 个资源定义均有本地对应文件，包含 2,610 组 SpriteFrames、14,867 帧动画、145 个声音、21 个字体、3,249 个矢量形状及 23 个变形形状。
- 序章和全部 24 关均可建立原生战斗场景；检查初始兵种、金钱、背景和路径数据。
- 313 个事件全部通过原生调度器执行，覆盖对白、敌军、友军、召唤、箭雨事件及全局波次。
- 六段漫画完成翻页；62 页游戏手册及全部敌人说明可进入；升级、地图、成就和战斗界面已实际渲染检查。
- 独立验证近战伤害、远程弹道命中、治疗、眩晕、招募、进阶分支、星级加成、尸体宽限时间及复活。
- 战斗规则检查覆盖诅咒对生命上限和当前生命的比例调整、保护状态每击 1 点伤害、群体复活、压制与破甲持续时间。
- 第 1 关固定种子打通并观察结束；第 2–24 关加速冒烟均跑到帧数上限或败北结束（`tests/battle_all_levels.gd`），其中第 2 关在本次运行中出现下方"测试运行中已知问题"所述的瞬时脚本错误，与 `Main` 本身无关，其余 22 关无核心脚本错误。这些结果不构成难度与原作一致的证据。
- 导出为 macOS 通用应用（`./dev/godot.sh export`），在工程目录之外（`/tmp`）启动 `build/Royal Warfare 1.app`，headless 与窗口两种方式各运行一次，均无脚本错误；应用内部包含 Godot 运行时和全部游戏资源，无需工程、反编译工具或 Flash 环境。

`tests/smoke.gd` 现在只做资源完整性检查（12,130+ 项：资源文件、背景、精灵帧数、主场景根节点为 `Main`），不再依赖旧的 `battle.gd`/`unit.gd` 行为。界面与战斗相关的行为检查已分散到 `tests/menu_screens.gd`、`upgrade_panel.gd`、`comics.gd`、`battle_ifaces.gd`、`main_game_ui.gd`、`clips_runtime.gd`、`level_intro.gd`、`battle_level1.gd`、`battle_all_levels.gd` 以及本次新增的 `tests/main_flow.gd`。所有测试须带 `-- --isolated-profile`。

## 测试运行中已知问题（不在本任务文件范围内）

- `tests/battle_level1.gd`、`tests/battle_all_levels.gd` 在结束关卡（`stop_level()` 清理场景树）时，`game/ifaces/hints_manager.gd:98` 的 `removed()` 在 `main_game_ui_ex.gd._exit_tree()` 回调内调用 `remove_child()`，与引擎"父节点正在增删子节点期间不能再次 `remove_child`"的限制冲突，产生一条 `SCRIPT ERROR`。这发生在 `game/ifaces/` 下战内 HUD 相关文件内，不属于本次 `Main` 移植改动的文件，复现与 `Main` 的接入方式无关（同样的错误在仅 `Main.new()`、未跑完整 `load_resources` 的测试 harness 下出现）。由于 `dev/godot.sh test` 的测试序列使用 `set -e`，该失败会中止其后的 `battle_all_levels`/`main_flow` 两步；单独运行这两个脚本（以及其余全部测试脚本，含 `main_flow.gd`）均可独立完成并给出结果。**当前 `./dev/godot.sh test` 顺序执行尚不能"全部通过"，卡在这一步**，待该文件的负责人修复后复查。

## 尚未完成的等价验收

当前实现全部 43 种具体单位技能的原生效果分派，参数来自一代；但原版的攻击动画判定时机、近战围攻与追击、施法目标选择、部分范围技能的受益目标和特效节奏仍需逐项对照。Godot 网格寻路和局部避障与原算法不同，复杂地图的走位表现需要实战验证。

90 个界面和组件已拆分为原生场景。部分界面仍使用提取的首帧作为静态组件；按钮位置和美术得以保留，但所有悬停提示、徽章动画、难度旗帜、战后新成就列表以及首领退场动画尚未逐项还原。网页平台登录、外部排行榜和赞助平台接口没有移植为原服务（见上文"入口与启动流程"）。

全战役的三种难度、48 项成就、首领多阶段战斗、所有职业组合尚未经过人工完整通关。与原版 Flash（`royal-warfare-1-flash-reference`）的逐屏/逐操作并排对照尚未进行——本次验证的"无脚本错误"是基于原生实现自身的运行观察，不是与原版行为的等价性证明。当前不会将"资源齐全""事件测试通过""启动流程无报错"标成"100% 无损完成"。

## 数据兼容说明

保留原数值表，包括弓手招募冷却表中的 `2223` 和成就"进阶"规则对眩晕计数器的引用。这些是当前重建数据中的原值；后续若调整，应作为明确的玩法改动记录。

关卡 24 和单位数据中的不合法 XML 注释已规范化，以便工具读取；原始字节备份仅保存在本地研究目录。游戏内容的节点值全部保留。

旧近似实现读取的摘要 JSON（`data/units.json`、`story.json`、`special_parameters.json`、`bonuses.json`、`encyclopedia.json`、`achievement_rules.json`、`arrows.json`、`backgrounds.json`、`boss_support.json`、`names.json`、`recruitment.json`、`upgrades.json`）已随旧实现一起删除；运行时的单位属性、技能参数、关卡事件、地图路线等全部来自 `data/xml/`（`RWXml`/`ExtDataManager` 解析），`data/campaign.json`/`data/geometry.json` 仅供 `tests/levels_data.gd`/`tests/universe_core.gd` 做数据一致性校验，不在运行时被读取。
