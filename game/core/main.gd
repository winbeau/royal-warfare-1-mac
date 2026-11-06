# 移植自 S/Main.as（原版的文档类之一：预载完成后由 Preloader 创建）
# 这里 Main 是 scenes/main.tscn 的根节点。
#
# 不移植（原版保留为注释）：
# - 站点锁与域名探测 rnmr / mdmn / gur、GlobalTracker 统计；
# - Kongregate 与 Armor Games API：loadFinished 里的 AGI2.swf / kongregate_api_path 连接、sendKongData、setQuestAchieved 的提交。
#   isExternalApiEnabled / isKong / isArmor 在原版只有 API 连接成功后才会为 true，离线运行始终为 false，这里同样保持 false。
#   参考仓库里的包是 Armor Games 版，但没有 AGI 就没有任何 Armor 功能（地图的在线存档按钮 bOnline 因此隐藏）。
#
# 二次开发（用户要求的启动提速，记录于 docs/verification.md「用户要求的玩法改动」）：
# - 不再有预载画面、Start 按钮和 MaxGames 片头：_ready 只同步做进主菜单必需的几步（存档/声音、容器、主菜单），
#   然后直接显示主菜单；原版 loadResources 的其余 case 改成可重入的"作业"。
# - 地图、升级面板、成就、手册、制作人员、6 段漫画、教学、GameUniverse 等界面在第一次访问字段时创建（lazy 属性），
#   菜单出现后再按每帧预算在后台依次预热；进战斗前（load_game）同步补齐所有兵种/特效的 init_resources 与对象池。
# - 作业内容和原版 case 一致，只是执行时机后移；对象池只是缓存，不影响玩法结果。
class_name Main
extends Node2D

const GAME_WIDTH := 700
const GAME_HEIGHT := 600
const DEBUG_MODE := false

## 原版 fadeClearLoadUnfade 的 optionalInit 默认值。
const NO_INIT := -999

## 菜单出现后，后台预热每帧最多占用的毫秒数（单个作业不会被打断）。
const WARM_BUDGET_MSEC := 4.0

static var inst: Main  # 原版 Main.self
static var is_external_api_enabled: bool = false
static var is_kong: bool = false
static var is_armor: bool = false

# 下列界面字段在 lazy_screens 为 true（真实启动）时，首次访问会自动创建；
# 战斗测试的轻量 harness 只 Main.new()，lazy_screens 为 false，字段保持纯变量（未创建即 null）。
var lazy_screens: bool = false
var g_map: GameMapObject = null:
	get:
		if g_map == null and lazy_screens:
			_make_map()
		return g_map
var game_uni: GameUniverse = null:
	get:
		if game_uni == null and lazy_screens:
			_ensure_levels()
			game_uni = GameUniverse.new()
		return game_uni
var upgrade_panel: UpgrPanelEx = null:
	get:
		if upgrade_panel == null and lazy_screens:
			upgrade_panel = UpgrPanelEx.create()
			upgrade_panel.init_once()
		return upgrade_panel
var main_menu: MainMenuScreen = null
var achives_menu: AchivesScreenEx = null:
	get:
		if achives_menu == null and lazy_screens:
			achives_menu = AchivesScreenEx.create()
			achives_menu.init_once()
		return achives_menu
var fade_black_screen: ColorRect
var game_screens_container: Node2D
var sponsor_url: String = "http://www.maxgames.com"
var strategy_guide_url: String = "http://www.maxgames.com/guides/royal-warfare.html"
var host_it_url: String = "http://www.maxgames.com/free-games.html"
var last_level_num: float = 0
## 二次开发：当前所在章节（1 或 2）。二章各自记一个 last_level_num（0 基关号），-1 重玩本章上一关。
var current_chapter: int = 1
var last_level_num_ch2: float = 0
var dev_ch1_visit: bool = false  # dev 版：为真时 load_map 不重定向到二章地图
var ch2_map: Ch2MapScreen = null:
	get:
		if ch2_map == null and lazy_screens:
			ch2_map = Ch2MapScreen.create()
		return ch2_map
var comix_intro: IntroComicsEx = null:
	get:
		if comix_intro == null and lazy_screens:
			comix_intro = IntroComicsEx.create()
			comix_intro.init()
		return comix_intro
var comix_act_two: ComixTwoEx = null:
	get:
		if comix_act_two == null and lazy_screens:
			comix_act_two = ComixTwoEx.create()
			comix_act_two.init()
		return comix_act_two
var comix_act_three: ComixThreeEx = null:
	get:
		if comix_act_three == null and lazy_screens:
			comix_act_three = ComixThreeEx.create()
			comix_act_three.init()
		return comix_act_three
var comix_act_four: ComixFourEx = null:
	get:
		if comix_act_four == null and lazy_screens:
			comix_act_four = ComixFourEx.create()
			comix_act_four.init()
		return comix_act_four
var comix_act_five: ComixFiveEx = null:
	get:
		if comix_act_five == null and lazy_screens:
			comix_act_five = ComixFiveEx.create()
			comix_act_five.init()
		return comix_act_five
var comix_end: ComixFinalEx = null:
	get:
		if comix_end == null and lazy_screens:
			comix_end = ComixFinalEx.create()
			comix_end.init()
		return comix_end
var how_to_screen: HowtoPlayScreenEx = null:
	get:
		if how_to_screen == null and lazy_screens:
			# 原版 howToScreen.initOnce() 只做 Rasterizer.rasterize(eBg)（位图缓存），没有可移植的行为。
			how_to_screen = HowtoPlayScreenEx.create()
		return how_to_screen
var ingame_guide: StartTutorial = null:
	get:
		if ingame_guide == null and lazy_screens:
			ingame_guide = StartTutorial.create()
		return ingame_guide
var credits_screen: CreditsScreenEx = null:
	get:
		if credits_screen == null and lazy_screens:
			credits_screen = CreditsScreenEx.create()
			credits_screen.init_once()
		return credits_screen
var sound_lib: SoundLibrary
var current_battle_music: String  # 原版 CURRENT_BATTLE_MUSIC
var current_music: AudioStream = null
var ar_swarm: ArrowSwarm = null:
	get:
		if ar_swarm == null and lazy_screens:
			ar_swarm = ArrowSwarm.new()
		return ar_swarm
var ingame_unit_guide: UnitTutorial = null:
	get:
		if ingame_unit_guide == null and lazy_screens:
			ingame_unit_guide = UnitTutorial.create()
		return ingame_unit_guide
var sound_class: Sounds
var a_armor_quests: Array = []

## 主菜单已显示、可点击（原版是 loadResources 全部完成）。其余作业仍可能在后台预热。
var resources_loaded: bool = false
## 后台预热队列已跑完（测试用来等待稳定状态；真实游玩不需要等）。
var warmup_done: bool = false

var _jobs_done: Dictionary = {}  # 已执行的作业键：作业只执行一次
var _warm_queue: Array = []  # 后台预热队列：[键, Callable]


func _init() -> void:
	inst = self


## 原版 init()（ADDED_TO_STAGE 之后）+ loadResources 中进主菜单必需的部分，然后直接显示主菜单。
func _ready() -> void:
	inst = self
	var t0 := Time.get_ticks_msec()
	_boot()
	if OS.get_environment("RW_BOOT_TIMING") != "":
		print("BOOT menu_ready_msec=", Time.get_ticks_msec(), " boot_cost_msec=", Time.get_ticks_msec() - t0)


func _boot() -> void:
	lazy_screens = true
	# 主菜单背景的士兵动画场景体量最大：让加载线程与下面的存档/声音初始化并行读盘，随后的 load() 直接取缓存。
	for path in ["res://scenes/ifaces/mm_anim_soldiers_ex.tscn", "res://scenes/clips/mmAnimSoldiers.tscn"]:
		ResourceLoader.load_threaded_request(path)
	# 原版 case 76：存档/声音。
	ButtonClass.init()
	# 二次开发：首次启动时把旧版 user://campaign.json 转成新存档（新存档已存在则不动；隔离模式不碰磁盘）。
	if not StoredData.isolated:
		LegacySave.migrate_if_needed()
	StoredData.init()
	sound_lib = SoundLibrary.new()
	sound_lib.init()
	sound_class = _sounds_node()
	sound_class.init_sounds_first(StoredData.main_params)
	current_battle_music = sound_lib.BATTLE_MUSIC
	# 原版 case 89：原版是 700x600 纯黑 BitmapData 的 Bitmap；先加容器，再加黑幕，故黑幕在容器之上。
	game_screens_container = Node2D.new()
	add_child(game_screens_container)
	fade_black_screen = ColorRect.new()
	fade_black_screen.color = Color.BLACK
	fade_black_screen.size = Vector2(GAME_WIDTH, GAME_HEIGHT)
	fade_black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_black_screen)
	fade_black_screen.visible = false
	ButtonClass.init_sounds()
	is_external_api_enabled = false
	is_kong = false
	is_armor = false
	# 域名为 armorgames.com / kongregate.com 时的 API 连接：不移植（见文件头）。
	# 主菜单（原版 case 86 的一部分）：直接放进容器，不做切屏淡入。
	main_menu = MainMenuScreen.create()
	main_menu.init_once()
	play_menu_music()
	game_screens_container.add_child(main_menu)
	StoredData.save_data(StoredData.COM_SAVE_DATA_TO_SHARED, null)
	resources_loaded = true
	_queue_warmup()


# ---- 作业：和原版 loadResources 的 case 一一对应，只是改为可重入、按需、可后台分帧 ----

func _run_job(key: Variant, fn: Callable) -> void:
	if _jobs_done.has(key):
		return
	_jobs_done[key] = true
	fn.call()


## 原版 case 77..85：GameUniverse 静态数据与 24 关模板。
func _ensure_levels() -> void:
	_run_job("levels", func() -> void:
		GameUniverse.init_once()
		for r: Array in [[0, 3], [3, 7], [7, 10], [10, 13], [13, 16], [16, 19], [19, 22], [22, 24]]:
			GameUniverse.load_levels(r[0], r[1]))


func _make_map() -> void:
	_ensure_levels()
	GameMapObject.init_once()
	g_map = GameMapObject.create()


## 原版 case 0..75、90..93、97、98 以及 87 里的 VinDefPanelAchivesController.init_once：战斗需要的全部资源。
func _ensure_battle_resources() -> void:
	_ensure_levels()
	var steps := _resource_steps()
	for n: int in steps.keys():
		_ensure_resource_step(n, steps)
	_job_mini_icons()
	_job_vin_def_achives()
	_job_ext_data()
	_touch(ar_swarm)  # 触发创建（原版 case 91）
	_touch(game_uni)  # 触发创建（原版 case 77）


func _touch(_v: Variant) -> void:
	pass


func _job_mini_icons() -> void:
	_run_job("mini_icons", func() -> void:
		MiniIcons.bmp_frame = BmpFrames.from_symbol("miniIconsAni")
		MiniIcons.cache(150))


func _job_vin_def_achives() -> void:
	_run_job("vin_def_achives", func() -> void: VinDefPanelAchivesController.init_once())


func _job_ext_data() -> void:
	_run_job("ext_data", func() -> void: ExtDataManager.new().init())


func _ensure_resource_step(n: int, steps: Dictionary) -> void:
	_run_job(n, func() -> void:
		for c: Callable in steps.get(n, []):
			c.call())


## 菜单出现后的后台预热顺序：玩家最可能的下一步在前（地图、未看过的开场漫画），战斗资源其后，其余界面最后。
func _queue_warmup() -> void:
	var steps := _resource_steps()
	_warm_queue = [["levels", _ensure_levels], ["map", func() -> void: g_map = g_map]]
	var flags: Variant = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	if flags is Dictionary and (flags as Dictionary).get("comix_intro", 1) == 0:
		_warm_queue.append(["comix_intro", func() -> void: comix_intro = comix_intro])
	for n: int in steps.keys():
		_warm_queue.append([n, _ensure_resource_step.bind(n, steps)])
	_warm_queue.append(["mini_icons", _job_mini_icons])
	_warm_queue.append(["vin_def_achives", _job_vin_def_achives])
	_warm_queue.append(["ext_data", _job_ext_data])
	_warm_queue.append(["ar_swarm", func() -> void: _touch(ar_swarm)])
	_warm_queue.append(["game_uni", func() -> void: _touch(game_uni)])
	for pair: Array in [
		["upgrade", func() -> void: upgrade_panel = upgrade_panel],
		["achives", func() -> void: achives_menu = achives_menu],
		["how_to", func() -> void: how_to_screen = how_to_screen],
		["credits", func() -> void: credits_screen = credits_screen],
		["comix_two", func() -> void: comix_act_two = comix_act_two],
		["comix_three", func() -> void: comix_act_three = comix_act_three],
		["comix_four", func() -> void: comix_act_four = comix_act_four],
		["comix_five", func() -> void: comix_act_five = comix_act_five],
		["comix_end", func() -> void: comix_end = comix_end],
		["guide", func() -> void: ingame_guide = ingame_guide],
		["unit_guide", func() -> void: ingame_unit_guide = ingame_unit_guide],
	]:
		_warm_queue.append(pair)
	set_process(true)


func _process(_delta: float) -> void:
	if _warm_queue.is_empty():
		set_process(false)
		warmup_done = true
		return
	# 战斗进行中不占用帧时间；回到地图/菜单后继续。
	for c in game_screens_container.get_children():
		if c is GameUniverse:
			return
	var t0 := Time.get_ticks_usec()
	while not _warm_queue.is_empty():
		var job: Array = _warm_queue.pop_front()
		(job[1] as Callable).call()
		if (Time.get_ticks_usec() - t0) / 1000.0 >= WARM_BUDGET_MSEC:
			break
	if _warm_queue.is_empty():
		set_process(false)
		warmup_done = true
		if OS.get_environment("RW_BOOT_TIMING") != "":
			print("BOOT warmup_done_msec=", Time.get_ticks_msec())


func _resource_steps() -> Dictionary:
	return {
		0: [BloodEx.init_resources],
		1: [HealEffectEx.init_resources],
		2: [BlockedVisual.init_resources, MissVisual.init_resources],
		3: [StunnedEffectVisual.init_resources],
		4: [StunnedWaveVisual.init_resources, StunnedSmallWaveVisual.init_resources],
		5: [ArrowEx.init_resources, SmallFireballEx.init_resources],
		6: [SlowEffectVisual.init_resources],
		7: [HeadShotEffectVisual.init_resources],
		8: [PoisonEffectVisual.init_resources, WeakSpotEffectVisual.init_resources],
		9: [RoundAttackEffectVisual.init_resources],
		10: [RessurectEffectVisual.init_resources],
		11: [RockFallingVisual.init_resources],
		12: [BetrayVisual.init_resources],
		13: [BlessVisual.init_resources],
		14: [CurseVisual.init_resources, SilencedVisual.init_resources],
		15: [IceVisual.init_resources, TauntedVisual.init_resources],
		16: [FlashVisual.init_resources],
		17: [CritVisual.init_resources, BrokenArrowVisual.init_resources],
		18: [FriendWarrior.init_resources],
		19: [FriendSwordMaster.init_resources],
		20: [FriendKnight.init_resources, FriendKing.init_resources],
		21: [FriendArcher.init_resources],
		22: [FriendSniper.init_resources],
		23: [FriendCrossBowMan.init_resources],
		24: [FriendBlueMage.init_resources],
		25: [FriendRedMage.init_resources],
		26: [FriendBlackMage.init_resources],
		27: [FriendPriest.init_resources],
		28: [FriendHealer.init_resources],
		29: [FriendBlesser.init_resources],
		30: [UndeadZombie.init_resources],
		31: [UndeadDarthKnight.init_resources],
		32: [UndeadSkeletonArmored.init_resources],
		33: [UndeadSkeleton.init_resources],
		34: [UndeadSkeletonCapitan.init_resources],
		35: [UndeadSkeletionArcher.init_resources],
		36: [FriendScoutRogue.init_resources],
		37: [FriendScoutAssasin.init_resources],
		38: [FriendScoutSaboteur.init_resources],
		39: [],  # 原版 case 39 为空
		40: [CoinVisual.init_resources],
		41: [TauntVisual.init_resources],
		42: [SuppressVisual.init_resources],
		43: [CorruptVisual.init_resources, FbSmokeVisual.init_resources],
		44: [ParryVisual.init_resources, UnitKilledVisual.init_resources],
		45: [RoundAttackVisual.init_resources],
		46: [HarmResistVisual.init_resources],
		47: [StrongHealVisual.init_resources],
		48: [GroundFlagAttack.init_resources, GroundFlagHeal.init_resources],
		49: [GroundFlagMove.init_resources, GroundDefFlag.init_resources],
		50: [CorpseExplosionVisual.init_resources],
		51: [EnchantVisual.init_resources],
		52: [GitGlowVisual.init_resources],
		53: [BackstabVisual.init_resources],
		54: [CallConfusionVisual.init_resources],
		55: [UndeadGrayZombie.init_resources],
		56: [MonsterOgre.init_resources],
		57: [UndeadWitch.init_resources],
		58: [UndeadVampire.init_resources],
		59: [MonsterKamikaze.init_resources, MonsterShieldKamikaze.init_resources],
		60: [UndeadShaman.init_resources],
		61: [UndeadDarthGuardian.init_resources],
		62: [UndeadStormTrooper.init_resources],
		63: [UndeadDarthArcher.init_resources],
		64: [UndeadSeeker.init_resources],
		65: [MonsterHound.init_resources],
		66: [MonsterGreenHound.init_resources],
		67: [UndeadPlagueZombie.init_resources],
		68: [WeaknessVisual.init_resources],
		69: [UndeadRanger.init_resources],
		70: [MonsterTroll.init_resources],
		71: [RegenVisual.init_resources],
		72: [UndeadVampireLord.init_resources],
		73: [UndeadVampireKing.init_resources],
		74: [UndeadSummoner.init_resources, SummonVisual.init_resources, SummonSingleVisual.init_resources, SummonKingVisual.init_resources],
		75: [UndeadGhost.init_resources],
		92: [FriendWiseman.init_resources, NpcOldman.init_resources],
		93: [NpcMan.init_resources, NpcWoman.init_resources],
		97: [CantMoveVisual.init_resources, FreeMoveVisual.init_resources, HoldGroundVisual.init_resources],
		100: _ch2_unit_inits(),
	}


## 二次开发：二章单位类的预热。D1 提供静态 init_resources()；类或方法尚不存在时跳过。
## 用全局类表按名字取脚本，避免本文件在这些类缺失时无法编译。
func _ch2_unit_inits() -> Array:
	var calls: Array = []
	for cls_name: String in ["Ch2Warden", "Ch2Musketeer", "Ch2DarthLancer"]:
		var scr: Script = IfaceUtil.global_script(cls_name)
		if scr != null and scr.has_method("init_resources"):
			calls.append(Callable(scr, "init_resources"))
	return calls


## Sounds 的实例是 autoload 节点 SoundSystem（docs/port-plan.md）；未在树中（测试）时退回已有单例。
func _sounds_node() -> Sounds:
	var tree := get_tree()
	if tree != null:
		var node := tree.root.get_node_or_null("SoundSystem")
		if node != null:
			return node
	return Sounds.inst


## 屏幕切换：黑幕淡入 0.3 秒 -> 延迟 0.1 秒 -> 清空容器、killAll(只清延迟调用)、加入新界面、按需 gameUni.init -> 黑幕淡出 0.3 秒。
## panel 为要显示的界面（Node），optional_init 为 NO_INIT 时不初始化关卡。
func fade_clear_load_unfade(panel: Node, optional_init: int = NO_INIT) -> void:
	var changes := func() -> void:
		for child in game_screens_container.get_children():
			game_screens_container.remove_child(child)
		RWTween.kill_all(false, false, true)  # TweenMax.killAll(false, false, true)：只杀延迟调用
		game_screens_container.add_child(panel)
		if optional_init != NO_INIT:
			game_uni.init(optional_init)
		RWTween.to(fade_black_screen, 0.3, {"alpha": 0, "onComplete": unfaded})
	var faded := func() -> void:
		RWTween.delayed_call(0.1, changes)
	fade_black_screen.visible = true
	fade_black_screen.modulate.a = 0.0
	RWTween.to(fade_black_screen, 0.3, {"alpha": 1, "onComplete": faded})


func unfaded() -> void:
	fade_black_screen.visible = false


func load_main_menu(_e: Variant = null) -> void:
	current_chapter = 1  # 二次开发：主菜单的 Play 总是回到一代地图
	dev_ch1_visit = false
	play_menu_music()
	fade_clear_load_unfade(main_menu)


func play_menu_music() -> void:
	if current_music != sound_lib.get_sound(sound_lib.MENU_MUSIC):
		if current_music != null:
			sound_class.stop_music(current_music)
	current_music = sound_lib.get_sound(sound_lib.MENU_MUSIC)
	sound_class.play_music(current_music, true, 0, 0.25)


func load_intro() -> void:
	fade_clear_load_unfade(comix_intro)


func load_act_two() -> void:
	fade_clear_load_unfade(comix_act_two)


func load_act_three() -> void:
	fade_clear_load_unfade(comix_act_three)


func load_act_four() -> void:
	fade_clear_load_unfade(comix_act_four)


func load_act_five() -> void:
	fade_clear_load_unfade(comix_act_five)


func load_final() -> void:
	fade_clear_load_unfade(comix_end)


## 地图：按 comix_* 标志先放尚未看过（值为 0）的漫画，-1 表示未解锁，1 表示已看。
func load_map() -> void:
	# 二次开发：dev 版主菜单 Play 直接进二章地图（经二章地图的船去一代时 dev_ch1_visit 为真，放行）
	if current_chapter == 2 or (StoredData.dev and not dev_ch1_visit):
		load_ch2_map()
		return
	play_map_music()
	var flags: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	if flags["comix_intro"] == 0:
		fade_clear_load_unfade(comix_intro)
	elif flags["comix_two"] == 0:
		fade_clear_load_unfade(comix_act_two)
	elif flags["comix_three"] == 0:
		fade_clear_load_unfade(comix_act_three)
	elif flags["comix_four"] == 0:
		fade_clear_load_unfade(comix_act_four)
	elif flags["comix_five"] == 0:
		fade_clear_load_unfade(comix_act_five)
	elif flags["comix_end"] == 0:
		fade_clear_load_unfade(comix_end)
	else:
		fade_clear_load_unfade(g_map)


## 关卡下标为 0 基（第 1 关 = 0）。-2 是开场过场（levelIntro）；-1 表示重玩上一关。
func load_game(param1: int = -1, param2: bool = true) -> void:
	_ensure_battle_resources()  # 后台预热未完成时在这里同步补齐，保证进入任何关卡前资源就绪
	if param2 == true:
		play_game_music()
	if param1 == 0 and current_chapter == 1:
		if LevelIntro.is_shown == false:
			param1 = -2
		elif LevelIntro.can_end_intro == false:
			param1 = -2
			LevelIntro.is_shown = true
	if param1 == -1:
		param1 = int(last_level_num_ch2 if current_chapter == 2 else last_level_num)
	elif current_chapter == 2:
		last_level_num_ch2 = param1
	else:
		last_level_num = param1
	# 二次开发：GameUniverse.chapter 由 B 包（战斗框架）添加。
	game_uni.chapter = current_chapter
	fade_clear_load_unfade(game_uni, param1)


func play_map_music() -> void:
	if current_music != sound_lib.get_sound(sound_lib.MAP_MUSIC):
		if current_music != null:
			sound_class.stop_music(current_music)
	current_music = sound_lib.get_sound(sound_lib.MAP_MUSIC)
	sound_class.play_music(current_music, true, 0, 0.25)


## 二次开发：进入第二章地图（东渡）。
func load_ch2_map() -> void:
	current_chapter = 2
	play_map_music()
	fade_clear_load_unfade(ch2_map)


## 二次开发：回到一代地图。
func load_ch1_map() -> void:
	current_chapter = 1
	dev_ch1_visit = true  # dev 版从二章地图的船主动去一代地图时，不再被 load_map 拉回二章
	load_map()


func reload_map() -> void:
	play_map_music()
	fade_clear_load_unfade(g_map)


func play_game_music() -> void:
	sound_class.stop_music(current_music)
	current_music = sound_lib.get_sound(current_battle_music)
	sound_class.play_music(current_music, true, 0, 0.23)


func load_upgrade_panel() -> void:
	play_map_music()
	fade_clear_load_unfade(upgrade_panel)


func load_more_games(_e: Variant = null) -> void:
	OS.shell_open(sponsor_url)


func load_strategy_games(_e: Variant = null) -> void:
	OS.shell_open(strategy_guide_url)


func load_host_it_page(_e: Variant = null) -> void:
	OS.shell_open(host_it_url)


func load_achievements(param1: bool = false) -> void:
	achives_menu.is_map = param1
	fade_clear_load_unfade(achives_menu)


func load_how_to() -> void:
	fade_clear_load_unfade(how_to_screen)
	how_to_screen.ingame = false


## 战内手册：直接盖在战斗界面之上（Main 的子节点），并暂停战斗。
func load_how_to_ingame() -> void:
	_add_on_top(how_to_screen)
	how_to_screen.ingame = true
	game_uni.pause()


## ingame_guide 在真实运行中首次访问时创建（lazy_screens）。战斗端到端测试的轻量级 harness
## （tests/support/battle_harness.gd）只 `Main.new()`，lazy_screens 为 false，这里按未创建静默跳过。
func add_tutorial(param1: float) -> void:
	if ingame_guide == null:
		return
	if StoredData.main_params.get("hints", false):
		_add_on_top(ingame_guide)
		ingame_guide.init(param1)


func load_credits() -> void:
	fade_clear_load_unfade(credits_screen)


func stop_music_ingame() -> void:
	if sound_class == null:
		return
	sound_class.stop_music(current_music)


func add_unit_hint(param1: int) -> void:
	if ingame_unit_guide == null:
		return
	_add_on_top(ingame_unit_guide)
	ingame_unit_guide.init(param1)


func unpause_music(param1: Variant = null) -> void:
	if sound_class == null or sound_lib == null:
		return
	if sound_class.music_on:
		if param1 == "menu":
			current_music = sound_lib.get_sound(sound_lib.MENU_MUSIC)
		elif param1 == "gameplay":
			current_music = sound_lib.get_sound(sound_lib.BATTLE_MUSIC)
		else:
			current_music = sound_lib.get_sound(sound_lib.MAP_MUSIC)
		sound_class.unpause_music(current_music)


func pause_music(_param1: Variant = null) -> void:
	current_music = null
	if sound_class == null:
		return
	sound_class.pause_music()


## AS3 addChild：已在别处则先摘下，再放到最上层。
func _add_on_top(node: Node) -> void:
	var parent := node.get_parent()
	if parent == self:
		move_child(node, get_child_count() - 1)
		return
	if parent != null:
		parent.remove_child(node)
	add_child(node)


## storedData.onlineSave / onlineLoad 只在 Main.isArmor 下经 agi.storage 工作（站点云存档），不移植；is_armor 恒为 false。
func online_save() -> void:
	pass


func online_load() -> void:
	pass


## Armor Games 任务提交（agi.quests）：站点 API，不移植。保留任务列表的构造以便日后接入。
func check_armor_quests() -> void:
	a_armor_quests = []
	for pair in [
		[StoredData.AB_11_KILL_BOMBERMAN, "bombermanDetonated"],
		[StoredData.AB_29_COMPLETE_1MISSION, "firstMissonCompleted"],
		[StoredData.AB_19_HEAL_DAMAGE, "damageHealed"],
		[StoredData.AB_18_MAKE_DAMAGE, "damageDealed"],
		[StoredData.AB_14_SHOOT_OGRE, "shootTheOgre"],
		[StoredData.AB_37_FRIENDS_RESSURECTED, "ressurectedAllies"],
		[StoredData.AB_31_COMPLETE_21MISSION, "destroyedPortal"],
		[StoredData.AB_24_24MISSIONS_3STARS, "Master"],
	]:
		if StoredData.check_if_achievement_not_done(pair[0]) == false:
			a_armor_quests.append(pair[1])
	set_quest_achieved()


func add_armor_quests(param1: Array) -> void:
	a_armor_quests = param1
	if is_armor == true:
		set_quest_achieved()


func set_quest_achieved() -> void:
	pass  # agi.quests.submit：不移植；is_armor 在离线运行中恒为 false


func send_kong_data() -> void:
	pass  # kongregate.stats.submit：不移植
