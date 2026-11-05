# 移植自 S/Main.as（原版的文档类之一：预载完成后由 Preloader 创建）
# 这里 Main 是 scenes/main.tscn 的根节点，Preloader 作为其最上层子节点。
#
# 不移植（原版保留为注释）：
# - 站点锁与域名探测 rnmr / mdmn / gur、GlobalTracker 统计；
# - Kongregate 与 Armor Games API：loadFinished 里的 AGI2.swf / kongregate_api_path 连接、sendKongData、setQuestAchieved 的提交。
#   isExternalApiEnabled / isKong / isArmor 在原版只有 API 连接成功后才会为 true，离线运行始终为 false，这里同样保持 false。
#   参考仓库里的包是 Armor Games 版，但没有 AGI 就没有任何 Armor 功能（地图的在线存档按钮 bOnline 因此隐藏）。
# - loadResources 的分帧缓存：改为在 _ready 之后依次调用各类的 init_resources()（其中的 cache(n) 数量与原版 Main 一致），
#   顺序和 case 编号保持一致；为了让预载文字能刷新，每若干步让出一帧。
class_name Main
extends Node2D

const GAME_WIDTH := 700
const GAME_HEIGHT := 600
const DEBUG_MODE := false

## 原版 fadeClearLoadUnfade 的 optionalInit 默认值。
const NO_INIT := -999

static var inst: Main  # 原版 Main.self
static var is_external_api_enabled: bool = false
static var is_kong: bool = false
static var is_armor: bool = false

var counter: int = -1
var total_iterations: int = 100

var g_map: GameMapObject = null
var game_uni: GameUniverse = null
var upgrade_panel: UpgrPanelEx = null
var main_menu: MainMenuScreen = null
var achives_menu: AchivesScreenEx = null
var fade_black_screen: ColorRect
var game_screens_container: Node2D
var sponsor_url: String = "http://www.maxgames.com"
var strategy_guide_url: String = "http://www.maxgames.com/guides/royal-warfare.html"
var host_it_url: String = "http://www.maxgames.com/free-games.html"
var last_level_num: float = 0
var comix_intro: IntroComicsEx
var comix_act_two: ComixTwoEx
var comix_act_three: ComixThreeEx
var comix_act_four: ComixFourEx
var comix_act_five: ComixFiveEx
var comix_end: ComixFinalEx
var how_to_screen: HowtoPlayScreenEx = null
var ingame_guide: StartTutorial
var credits_screen: CreditsScreenEx
var sound_lib: SoundLibrary
var current_battle_music: String  # 原版 CURRENT_BATTLE_MUSIC
var current_music: AudioStream = null
var ar_swarm: ArrowSwarm
var start_game_button: FlashClip  # StartPlayButton
var ingame_unit_guide: UnitTutorial
var sound_class: Sounds
var max_logo: FlashClip  # maxgLogoIntro
var a_armor_quests: Array = []

var preloader: Preloader = null
var resources_loaded: bool = false


func _init() -> void:
	inst = self


## 原版 init()（ADDED_TO_STAGE 之后）：设定舞台尺寸并开始 loadResources。
func _ready() -> void:
	inst = self
	preloader = Preloader.new()
	add_child(preloader)
	preloader.loading_finished()
	# 先让出两帧，使预载画面在载入前显示出来。
	await get_tree().process_frame
	await get_tree().process_frame
	await load_resources(true)


## 原版 loadResources(Event)：每帧执行一个 case。这里按同样的 case 顺序一次跑完。
## frame_yield 为 true 时每 4 步让出一帧（仅为刷新预载文字）；测试传 false，则不会 await，同步完成。
func load_resources(frame_yield: bool = false) -> void:
	for n in range(0, total_iterations + 1):
		update_counter(n)
		if n == total_iterations:
			StoredData.save_data(StoredData.COM_SAVE_DATA_TO_SHARED, null)
			load_finished()
		else:
			_load_step(n)
		if frame_yield and n % 4 == 3:
			await get_tree().process_frame
	resources_loaded = true


func update_counter(n: int) -> void:
	counter = n
	var percent := int(floorf(float(counter) / total_iterations * 100))
	if preloader != null and is_instance_valid(preloader) and preloader.prel != null:
		preloader.cache_updated(percent)


## case 0..75、92、93、97：各类的 BmpFrames 烘焙与对象池。init_resources() 内含与原版一致的 cache(n)。
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
	}


func _load_step(n: int) -> void:
	match n:
		76:
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
		77:
			GameUniverse.init_once()
			game_uni = GameUniverse.new()
		78:
			GameUniverse.load_levels(0, 3)
		79:
			GameUniverse.load_levels(3, 7)
		80:
			GameUniverse.load_levels(7, 10)
		81:
			GameUniverse.load_levels(10, 13)
		82:
			GameUniverse.load_levels(13, 16)
		83:
			GameUniverse.load_levels(16, 19)
		84:
			GameUniverse.load_levels(19, 22)
		85:
			GameUniverse.load_levels(22, 24)
		86:
			GameMapObject.init_once()
			g_map = GameMapObject.create()
			upgrade_panel = UpgrPanelEx.create()
			upgrade_panel.init_once()
			main_menu = MainMenuScreen.create()
			main_menu.init_once()
			achives_menu = AchivesScreenEx.create()
			achives_menu.init_once()
			how_to_screen = HowtoPlayScreenEx.create()
			# 原版 howToScreen.initOnce() 只做 Rasterizer.rasterize(eBg)（位图缓存），没有可移植的行为。
			credits_screen = CreditsScreenEx.create()
			credits_screen.init_once()
		87:
			comix_intro = IntroComicsEx.create()
			comix_intro.init()
			comix_act_two = ComixTwoEx.create()
			comix_act_two.init()
			comix_act_three = ComixThreeEx.create()
			comix_act_three.init()
			VinDefPanelAchivesController.init_once()
		88:
			comix_act_four = ComixFourEx.create()
			comix_act_four.init()
			comix_act_five = ComixFiveEx.create()
			comix_act_five.init()
			comix_end = ComixFinalEx.create()
			comix_end.init()
			ingame_guide = StartTutorial.create()
			ingame_unit_guide = UnitTutorial.create()
		89:
			# 原版是 700x600 纯黑 BitmapData 的 Bitmap；先加容器，再加黑幕，故黑幕在容器之上。
			game_screens_container = Node2D.new()
			add_child(game_screens_container)
			fade_black_screen = ColorRect.new()
			fade_black_screen.color = Color.BLACK
			fade_black_screen.size = Vector2(GAME_WIDTH, GAME_HEIGHT)
			fade_black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fade_black_screen)
			fade_black_screen.visible = false
			if preloader != null and is_instance_valid(preloader):
				move_child(preloader, get_child_count() - 1)  # 预载画面（原版的父级 Preloader）始终在最上层
			ButtonClass.init_sounds()
		90:
			MiniIcons.bmp_frame = BmpFrames.from_symbol("miniIconsAni")
			MiniIcons.cache(150)
		91:
			ar_swarm = ArrowSwarm.new()
		98:
			ExtDataManager.new().init()
		99:
			pass  # BmpFrames.disposeScratch()：位图烘焙的临时缓冲，Godot 版没有对应物
		_:
			for c: Callable in _resource_steps().get(n, []):
				c.call()


## Sounds 的实例是 autoload 节点 SoundSystem（docs/port-plan.md）；未在树中（测试）时退回已有单例。
func _sounds_node() -> Sounds:
	var tree := get_tree()
	if tree != null:
		var node := tree.root.get_node_or_null("SoundSystem")
		if node != null:
			return node
	return Sounds.inst


## 原版 loadFinished()：预载文字收尾，显示声音/音乐开关和开始按钮。站点探测与 API 连接见文件头。
func load_finished() -> void:
	preloader.cache_done()
	var obj: Dictionary = StoredData.main_params
	var prel: FlashClip = preloader.prel
	var b_sound: FlashClip = prel.get_node("bSound")
	var b_music: FlashClip = prel.get_node("bMusic")
	_draw_preloader_toggles()
	b_sound.visible = true
	b_music.visible = true
	RWTween.from(b_sound, 0.6, {"alpha": 0})
	RWTween.from(b_music, 0.6, {"alpha": 0})
	ButtonClass.add_button_scale(b_sound, clicked_sound_preloader)
	ButtonClass.add_button_scale(b_music, clicked_sound_preloader)
	# GlobalTracker.trackPage(domain)：不移植。
	start_game_button = (load("res://scenes/clips/StartPlayButton.tscn") as PackedScene).instantiate() as FlashClip
	prel.add_child(start_game_button)
	start_game_button.position = preloader.coords
	ButtonClass.add_button_on_frames_rd(start_game_button, start_clicked)
	RWTween.from_to(start_game_button, 0.4, {"colorMatrixFilter": {"brightness": 1.5}}, {"colorMatrixFilter": {"brightness": 1}})
	# start_game_button.filters = [DropShadowFilter(3, 45, 0, 1, 3, 3, 0.6)]：投影滤镜未移植。
	is_external_api_enabled = false
	is_kong = false
	is_armor = false
	# 域名为 armorgames.com / kongregate.com 时的 API 连接：不移植（见文件头）。
	if obj == null:
		return


## 预载画面的声音/音乐开关帧：开为 1，关为 2。
func _draw_preloader_toggles() -> void:
	var obj: Dictionary = StoredData.main_params
	var prel: FlashClip = preloader.prel
	prel.get_node("bSound").goto_and_stop(1 if obj.get("sound", false) == true else 2)
	prel.get_node("bMusic").goto_and_stop(1 if obj.get("music", false) == true else 2)


func clicked_sound_preloader(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var prel: FlashClip = preloader.prel
	var obj: Dictionary = StoredData.main_params
	if target == prel.get_node("bSound"):
		var t: bool = not bool(obj.get("sound", false))
		sound_class.sound_on = t
		obj["sound"] = t
		StoredData.main_params = obj
	elif target == prel.get_node("bMusic"):
		var t2: bool = not bool(obj.get("music", false))
		sound_class.music_on = t2
		obj["music"] = t2
		StoredData.main_params = obj
	_draw_preloader_toggles()
	ButtonClass.play_click_sound(null)


## 原版 startClicked：开始按钮点击后收起预载元素，0.9 秒后播 maxgLogoIntro。
func start_clicked(_param1: Variant = null) -> void:
	var prel: FlashClip = preloader.prel
	var b_sound: FlashClip = prel.get_node("bSound")
	var b_music: FlashClip = prel.get_node("bMusic")
	ButtonClass.remove_button_on_frames(start_game_button, start_clicked)
	ButtonClass.remove_button_scale(b_sound, clicked_sound_preloader)
	ButtonClass.remove_button_scale(b_music, clicked_sound_preloader)
	_draw_preloader_toggles()
	RWTween.to(b_sound, 0.3, {"alpha": 0})
	RWTween.to(b_music, 0.3, {"alpha": 0})
	RWTween.to(start_game_button, 0.3, {"alpha": 0, "onComplete": remove_button})
	preloader.remove_elements_to_show_intro()
	RWTween.delayed_call(0.9, show_intro)


func show_intro() -> void:
	max_logo = (load("res://scenes/clips/maxgLogoIntro.tscn") as PackedScene).instantiate() as FlashClip
	preloader.prel.add_child(max_logo)
	var params: Dictionary = StoredData.main_params
	if params.get("sound", true) == false:
		max_logo.goto_and_play(274)
	max_logo.position = Vector2(104, 215)
	max_logo.done.connect(max_done)
	ButtonClass.add_event_listener(max_logo, ButtonClass.CLICK, load_more_games)


func max_done() -> void:
	ButtonClass.remove_event_listener(max_logo, ButtonClass.CLICK, load_more_games)
	max_logo.get_parent().remove_child(max_logo)
	max_logo.queue_free()
	max_logo = null
	preloader.remove_bg()
	RWTween.delayed_call(0.2, load_main_menu)


func remove_button() -> void:
	if start_game_button != null and is_instance_valid(start_game_button) and start_game_button.get_parent() != null:
		start_game_button.get_parent().remove_child(start_game_button)
		start_game_button.queue_free()


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
	if param2 == true:
		play_game_music()
	if param1 == 0:
		if LevelIntro.is_shown == false:
			param1 = -2
		elif LevelIntro.can_end_intro == false:
			param1 = -2
			LevelIntro.is_shown = true
	if param1 == -1:
		param1 = int(last_level_num)
	else:
		last_level_num = param1
	fade_clear_load_unfade(game_uni, param1)


func play_map_music() -> void:
	if current_music != sound_lib.get_sound(sound_lib.MAP_MUSIC):
		if current_music != null:
			sound_class.stop_music(current_music)
	current_music = sound_lib.get_sound(sound_lib.MAP_MUSIC)
	sound_class.play_music(current_music, true, 0, 0.25)


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


## ingame_guide 只在 load_resources 的 case 88 创建。战斗端到端测试的轻量级 harness
## （tests/support/battle_harness.gd）只 `Main.new()` 不跑完整 load_resources，这里按资源未就绪静默跳过，
## 不影响真实运行（真实运行时 load_resources 总在进入任何关卡之前完成）。
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
