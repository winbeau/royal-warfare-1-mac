# 移植自 S/gameCore/gameUniverse.as
# 战斗世界：唯一的逻辑驱动 global_update（一次 _physics_process = 一个 ENTER_FRAME，30 fps），
# 事件调度、单位/特效更新、区域查询、选择框与键盘/鼠标输入。移植逻辑不使用 delta。
# 站点 API（Kong、GlobalTracker、sendKongData、域名锁）不移植。
class_name GameUniverse
extends Node2D

# --- 静态 ---
static var a_level_templates: Array = []  # 各关模板脚本路径（原版为类数组）
static var a_levels_templates_inited: Array = []
static var a_levels_back_grounds: Array = []  # 原版为背景 MovieClip；这里存背景类名（assets/backgrounds/<名>.png）
static var selection_ramka: RamkaEx
static var number_of_levels_reloaded: int = 0
static var inst: GameUniverse
static var MAX_SCREEN_WIDTH: int = 700
static var MAX_SCREEN_HEIGHT: int = 600
const DEFEAT := "defeat"
const VICTORY := "victory"
static var need_to_show_intro: bool = true

# 原版 aLivingClasses：下标即兵种 kind。类按 game/living/<snake>.gd 动态载入，避免对尚未移植的类硬依赖。
const A_LIVING_CLASSES: Array[String] = [
	"undeadDarthKnight", "friendWarrior", "friendArcher", "undeadSkeletionArcher", "friendPriest", "friendBlueMage",
	"undeadZombie", "friendSwordMaster", "friendRedMage", "friendBlackMage", "friendHealer", "friendBlesser",
	"friendSniper", "friendKnight", "friendCrossBowMan", "undeadSkeletonArmored", "undeadSkeleton",
	"undeadSkeletonCapitan", "friendScoutRogue", "friendScoutAssasin", "friendScoutSaboteur", "undeadGrayZombie",
	"monsterOgre", "undeadWitch", "undeadVampire", "monsterKamikaze", "undeadShaman", "undeadDarthGuardian",
	"undeadStormTrooper", "undeadDarthArcher", "undeadSeeker", "monsterHound", "monsterGreenHound",
	"undeadPlagueZombie", "undeadRanger", "monsterTroll", "undeadVampireLord", "undeadVampireKing",
	"undeadSummoner", "undeadGhost", "monsterShieldKamikaze", "friendKing", "friendWiseman", "npcOldman", "npcMan",
	"npcWoman",
]

# --- 实例 ---
var _cur_level_num: int = 0
var units_cont: Node2D
var a_display_objects_vector: Array = []
var ingame_ui: MainGameUIEx
var a_all_units: Array = []  # Vector.<livingObject>
var current_selected_unit: LivingObject = null
var a_selected_units: Array = []
var effects_cont: Node2D
var temp_enemy_loaded: int = 0
var a_waiting_death: Array = []
var _global_counter: int = 0
var bg_mc: Node2D
var selection_box_start_coords: Vector2 = Vector2.ZERO
var selection_box_is_shown: bool = false
var num_lifes: int = 0
var level_info: LevelTemplate
var cur_select_index: int = 0
var a_effects: Array = []  # Vector.<visualsTemplate>
var a_effects_to_delete: Array = []
var current_money: float = 0.0
var time: int = 0
var last_wave_time: int = 0
var check_enemy_exist_counter: int = 0
var total_waves: int = 0
var cur_wave: int = 0
var vic_panel: VictoryPanelEx = null
var def_panel: DefeatPanelEx = null
var pause_panel: PauseMenuEx = null
var cur_wave_info: Array = []
var res_point: Vector2 = Vector2.ZERO
var unit_cache: SimpleCache
var a_enemy_spawn_timer: Array = []
var bottom_effects_cont: Node2D
var g: GlobalData
var o_unit_groups: Dictionary = {}
var s_lib: SoundLibrary
var can_start_global_wave: bool = false
var backup_global_counter: int = 0
var is_shown_red_button: bool = false
var global_wave_counter: int = 0
var cur_time: float = 0.0
var cur_num_enemies: int = 0
var a_revealed_units: Array = []
var zombie_sound_counter: int = 0
var next_zombie_sound_time: int = 0
var dif_num: int = 0
var a_fireballs: Array = []
var circles_are_shown: bool = false
var hints_update_counter: int = 0
var a_units_xml_params: Array = []
var num_max_lives: float = 0.0
var is_end_game: bool = false
var unit_xml: RWXml
var a_obstacles: Array = []  # Vector.<obstacle>
var a_path_map: Array = []  # Array[MapRoute]
var path_bd: RWBitmapData = null
var obstacle_way_points: RWLayoutClip
var def_flag_object: RWLayoutClip
var healt_bar_cont: Node2D
var is_paused: bool = false
var cur_speed: int = 1
var is_controlled_pause: bool = false

# --- 驱动与输入状态（替代 addEventListener / removeEventListener）---
var _update_enabled: bool = false  # ENTER_FRAME 监听 globalUpdate 是否存在
var _bg_click_enabled: bool = false  # bgMc CLICK -> groundClicked
var _bg_down_enabled: bool = false  # bgMc MOUSE_DOWN -> startSelectionBox
var _stage_listeners: bool = false  # stage MOUSE_UP / KEY_UP / KEY_DOWN
var _sel_move_enabled: bool = false  # stage MOUSE_MOVE -> selectionBoxMove
var _press_target: Variant = null  # 左键按下时命中的单位或 bg_mc（用于合成 CLICK）
## 测试用：非 null 时替代真实鼠标位置（舞台坐标）
var mouse_override: Variant = null

var mouse_x: float:
	get:
		return _mouse_pos().x
var mouse_y: float:
	get:
		return _mouse_pos().y

var get_cur_selected: LivingObject:
	get:
		if a_selected_units.size() > 0:
			return a_selected_units[0]
		return null

var get_num_selected_units: int:
	get:
		return a_selected_units.size()

var global_counter: int:
	get:
		return _global_counter
	set(v):
		_global_counter = v

var cur_level_num: int:
	get:
		return _cur_level_num
	set(v):
		_cur_level_num = v


## RWTween 自动加载节点。经场景树取得，使 `--script` 测试（自动加载尚未注册标识符时即编译本脚本）也能解析。
static func tween_node() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("RWTween")


func _init() -> void:
	inst = self
	ingame_ui = MainGameUIEx.new()
	vic_panel = VictoryPanelEx.new()
	def_panel = DefeatPanelEx.new()
	pause_panel = PauseMenuEx.new()
	res_point = Vector2(0, 0)


# 原版 initOnce：aLevelTemplates / aSpecials / selectionRamka / new globalData()。
# aSpecials（45 个技能原型）只在 gameUniverse 内部声明、全工程无其他引用，随技能类在 P3 移植时一并处理。
static func init_once() -> void:
	a_level_templates = []
	for i in range(1, 25):
		a_level_templates.append("res://game/levels/level_%d.gd" % i)
	a_levels_templates_inited = []
	a_levels_back_grounds = []
	number_of_levels_reloaded = 0
	selection_ramka = RamkaEx.new()
	GlobalData.new()


## 原版 loadLevels(from, to)：实例化关卡模板并栅格化背景。位图烘焙由 Godot 纹理替代，这里只记录背景类名。
static func load_levels(param1: float, param2: float) -> void:
	var i := int(param1)
	while i < param2:
		var tmpl: LevelTemplate = _new_level_template(i)
		a_levels_templates_inited.append(tmpl)
		a_levels_back_grounds.append(tmpl.level_bg)
		i += 1


static func _new_level_template(n: int) -> LevelTemplate:
	var path: String = "res://game/levels/level_intro.gd" if n == -2 else a_level_templates[n]
	var scr: Script = load(path)
	return scr.new()


func init(param1: int) -> void:
	inst = self
	circles_are_shown = false
	a_fireballs = []
	is_controlled_pause = false
	cur_speed = 1
	hints_update_counter = 0
	is_paused = false
	LivingObject.mass_center = Vector2()
	Sounds.inst.init_sounds()
	s_lib = SoundLibrary.inst
	number_of_levels_reloaded += 1
	if number_of_levels_reloaded > 3:
		SoundLibrary.inst.init()
		number_of_levels_reloaded = 0
	dif_num = StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY]
	a_revealed_units = StoredData.local_game_data[StoredData.NUMPAN_REVEALED_ENEMY].duplicate()
	cur_time = 0
	is_end_game = false
	LivingObject.a_friend_ranged = []
	LivingObject.a_friend_warriors = []
	def_flag_object = null
	cur_num_enemies = 0
	o_unit_groups = {}
	for k in 10:
		o_unit_groups[k] = []
	global_wave_counter = 0
	ingame_ui.unlock_units()
	ingame_ui.e_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ingame_ui.e_fader.visible = false
	last_wave_time = 0
	LivingObject.unit_num_warriors = 0
	LivingObject.unit_num_mages = 0
	LivingObject.unit_num_archers = 0
	LivingObject.unit_num_priests = 0
	LivingObject.unit_num_rogues = 0
	a_effects = []
	a_effects_to_delete = []
	global_counter = 0
	selection_box_is_shown = false
	a_selected_units = []
	current_selected_unit = null
	LivingObject.v_untouchable_units = []
	LivingObject.v_untouchable_time_mark = []
	if ArrowSwarm.inst == null:
		ArrowSwarm.new()  # 原版由 Main 在启动时创建
	ArrowSwarm.inst.reset()
	a_display_objects_vector = []
	a_all_units = []
	a_waiting_death = []
	cur_level_num = param1
	if GlobalData.inst == null:
		GlobalData.new()  # 原版由 initOnce 创建
	g = GlobalData.inst
	g.reset()
	reset_money(0)
	backup_global_counter = 0
	can_start_global_wave = false
	is_shown_red_button = false
	if ExtDataManager.inst == null:
		ExtDataManager.new().init()
	units_loaded(ExtDataManager.inst.get_units_xml())


func units_loaded(param1: RWXml) -> void:
	set_loaded_units_parameters(param1)
	load_level(cur_level_num)


# 兵种类的 unitCost / upgradeCost 是静态字段：经脚本对象设置，类尚未移植时跳过。
func _set_unit_static(cls: String, field: String, v: float) -> void:
	var scr := _living_script(cls)
	if scr == null:
		return
	scr.set(field, int(v) if v == floorf(v) else v)


static func _living_script(cls: String) -> Script:
	var path := "res://game/living/%s.gd" % _snake(cls)
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## camelCase -> snake_case（与端口命名规则一致：friendBlueMage -> friend_blue_mage）
static func _snake(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		if ch != ch.to_lower() and i > 0:
			out += "_"
		out += ch.to_lower()
	return out


func set_loaded_units_parameters(param1: RWXml) -> void:
	unit_xml = param1
	# [类名, xml 节点, 是否有 upgradeCost]
	var table: Array = [
		["friendWarrior", "warrior", true], ["friendSwordMaster", "swordmaster", true], ["friendKnight", "knight", true],
		["friendArcher", "archer", true], ["friendCrossBowMan", "crossbowman", true], ["friendSniper", "sniper", true],
		["friendBlackMage", "blackmage", true], ["friendBlueMage", "bluemage", true], ["friendRedMage", "redmage", true],
		["friendPriest", "priest", true], ["friendHealer", "healer", true], ["friendBlesser", "blesser", true],
		["friendScoutRogue", "rogue", true], ["friendScoutAssasin", "assassin", true], ["friendScoutSaboteur", "saboteur", true],
		["monsterGreenHound", "green_hound", false], ["monsterHound", "hound", false], ["monsterKamikaze", "kamikaze", false],
		["monsterOgre", "ogre", false], ["monsterTroll", "troll", false], ["undeadDarthArcher", "storm_archer", false],
		["undeadDarthGuardian", "storm_guardian", false], ["undeadStormTrooper", "darth_trooper", false],
		["undeadDarthKnight", "darth_knight", false], ["undeadZombie", "zombie", false],
		["undeadGrayZombie", "grey_zombie", false], ["undeadPlagueZombie", "plague_zombie", false],
		["undeadRanger", "ranger", false], ["undeadSeeker", "seeker", false], ["undeadShaman", "shaman", false],
		["undeadSkeletionArcher", "skeleton_archer", false], ["undeadSkeleton", "skeleton", false],
		["undeadSkeletonArmored", "skeleton_arm", false], ["undeadSkeletonCapitan", "skeleton_cap", false],
		["undeadVampire", "vampire", false], ["undeadVampireLord", "vampire_lord", false],
		["undeadVampireKing", "vampire_king", false], ["undeadWitch", "witch", false],
		["undeadSummoner", "Summoner", false], ["undeadGhost", "ghost", false],
		["monsterShieldKamikaze", "shieldKamikaze", false],
	]
	for row in table:
		var node: RWXml = param1.child(row[1])
		_set_unit_static(row[0], "unit_cost", node.to_number("money"))
		if row[2]:
			_set_unit_static(row[0], "upgrade_cost", node.to_number("money_upgrade"))
	a_units_xml_params = []
	for tag in ["zombie", "skeleton", "skeleton_arm", "skeleton_cap", "skeleton_archer", "darth_knight", "grey_zombie",
			"ogre", "witch", "vampire", "kamikaze", "shaman", "storm_guardian", "darth_trooper", "storm_archer", "seeker",
			"hound", "green_hound", "plague_zombie", "ranger", "troll", "Summoner", "ghost", "shieldKamikaze",
			"vampire_lord", "vampire_king"]:
		a_units_xml_params.append(unit_xml.child(tag))


func set_money(param1: float) -> void:
	current_money += param1
	if param1 < 0:
		g.gold_spent += param1
	else:
		g.gold_gained += param1
	ingame_ui.set_money()


func reset_money(param1: float) -> void:
	current_money = param1
	ingame_ui.set_money()


func friendly_unit_clicked(param1: LivingObject) -> void:
	if a_selected_units.size() != 0:
		if a_selected_units.size() == 1:
			if a_selected_units[0] != param1:
				a_selected_units[0].unselect()
				a_selected_units.remove_at(0)
				a_selected_units.append(param1)
				param1.set_selected()
				ingame_ui.show_unit_panel()
			else:
				a_selected_units[0].unselect()
				a_selected_units.remove_at(0)
				ingame_ui.hide_unit_panel()
		else:
			while a_selected_units.size() > 0:
				var u: LivingObject = a_selected_units[0]
				u.unselect()
				a_selected_units.remove_at(0)
			a_selected_units.append(param1)
			param1.set_selected()
			ingame_ui.show_unit_panel()
	else:
		param1.set_selected()
		a_selected_units.append(param1)
		ingame_ui.show_unit_panel()


## AS3 splice(index, 1, item)：index 为 -1（indexOf 未命中）时替换最后一个元素；空数组则直接插入。
static func _splice_replace(arr: Array, idx: int, item: Variant) -> void:
	if idx < 0:
		idx = maxi(arr.size() + idx, 0)
	if idx >= arr.size():
		arr.append(item)
	else:
		arr[idx] = item


func _new_unit(kind: int) -> LivingObject:
	var scr := _living_script(A_LIVING_CLASSES[kind])
	if scr == null:
		push_error("GameUniverse: living class %s is not ported yet" % A_LIVING_CLASSES[kind])
		return null
	var cache: Variant = scr.get("cached_unit_data")
	if cache is SimpleCache:
		return cache.get_data() as LivingObject
	return scr.new() as LivingObject


func add_soldier(param1: int, param2: LivingObject = null, param3: int = 1, param4: bool = false) -> LivingObject:
	var u: LivingObject = _new_unit(param1)
	units_cont.add_child(u)
	u.uid = global_counter + RWRandom.rand_range(1, 20)
	a_display_objects_vector.append(u)
	u.update_stats()
	if param2 == null:
		u.add_to_game(0, 0, param3, param4)
		u.set_route(0)
		a_all_units.append(u)
		if param4 == false:
			_chat_message(u.get_class_name + " hired.")
			g.num_hired += 1
	else:
		param2.minus_units()
		_chat_message(param2.get_class_name + " upgrades to a " + u.get_class_name)
		u.add_to_game(param2.position.x, param2.position.y, 1, false, true)
		_splice_replace(a_all_units, a_all_units.find(param2), u)
		_splice_replace(a_selected_units, a_selected_units.find(param2), u)
		u.cur_group = param2.cur_group
		u.stand_still = param2.stand_still
		if u.cur_group > -1:
			var grp: Array = o_unit_groups[int(u.cur_group)].duplicate()
			_splice_replace(grp, grp.find(param2), u)
			o_unit_groups[int(u.cur_group)] = grp.duplicate()
		u.set_target(param2.get_cur_target, false)
		u.set_battle(param2.get_cur_battle)
		if u.get_cur_battle != null:
			u.get_cur_battle.unit_after_upgrade(u, param2)
		u.attacking_with_ranged_weapon = param2.attacking_with_ranged_weapon
		u.is_defence_stance = param2.is_defence_stance
		u.zero_point = param2.zero_point
		var ratio: float = float(param2.cur_health) / param2.health
		u.cur_health = u.health * ratio
		if u.cur_health <= 0:
			u.cur_health = 1
		var i := 0
		while i < a_all_units.size():
			var o: LivingObject = a_all_units[i]
			if o.get_cur_target == param2:
				o.set_target(u, false)
			i += 1
		u.duplucated_route(param2.get_route())
		u.set_stance_after_upgrade(param2.get_stance)
		u.num_killed = param2.num_killed
		u.set_selected()
		if param2.ext_unlock == true:
			u.unlock_abils_set_max_level()
		param2.set_self_destruct()
	if float(global_counter) / 3 == floorf(float(global_counter) / 3):
		_set_z_index()
	return u


func make_battle(param1: LivingObject, param2: LivingObject) -> void:
	if param1 != null and param2 != null:
		var b := Battle.new()
		b.init(param1, param2)
		if not param1.friendly:
			param1.o_pursue_counter[param2] = 1
		else:
			param2.o_pursue_counter[param1] = 1


func remove_battle(_param1: Battle) -> void:
	pass


# 反编译破损，按 P-code 重建
# 重建结论：先把单位从所属编组移除并置 curGroup = -1（仅当 curGroup >= 0）；
# 若不在 aWaitingDeath 则加入并 setDeathTime，随后反复（直到没有改动）扫描 aWaitingDeath：
# 与本单位 y 相同且 x 差 < 30 的其他尸体，把本单位 y 减 1；最后从选中列表移除、unselect、ingameUI.unitDead。
func make_unit_dead(param1: LivingObject) -> void:
	if param1.cur_group >= 0:
		var grp: Array = o_unit_groups[int(param1.cur_group)].duplicate()
		var idx := grp.find(param1)
		if idx >= 0:
			grp.remove_at(idx)
			o_unit_groups[int(param1.cur_group)] = grp.duplicate()
		param1.cur_group = -1
	var wi := a_waiting_death.find(param1)
	if wi < 0:
		a_waiting_death.append(param1)
		param1.set_death_time(global_counter)
		var changed := true
		while changed:
			changed = false
			var j := 0
			while j < a_waiting_death.size():
				var other: LivingObject = a_waiting_death[j]
				if other != param1:
					if other.position.y == param1.position.y:
						if other.position.x - param1.position.x < 30:
							param1.position.y -= 1
							changed = true
				j += 1
	var si := a_selected_units.find(param1)
	if si >= 0:
		a_selected_units.remove_at(si)
	param1.unselect()
	ingame_ui.unit_dead(param1)


func remove_from_death_array(param1: LivingObject) -> void:
	var idx := a_waiting_death.find(param1)
	if idx >= 0:
		a_waiting_death.remove_at(idx)


func add_click_handler() -> void:
	_bg_click_enabled = true


func add_arrow(param1: ArrowEx) -> void:
	units_cont.add_child(param1)
	param1.uid = global_counter
	a_display_objects_vector.append(param1)


func enemy_escaped() -> void:
	minus_health()


func minus_health(param1: int = 1) -> void:
	num_lifes -= param1
	if num_lifes < 0:
		num_lifes = 0
	ingame_ui.draw_lives(num_lifes)
	if num_lifes <= 0:
		end_game(DEFEAT)


func remove_arrow_from_display_array(param1: Node) -> void:
	var idx := a_display_objects_vector.find(param1)
	if idx >= 0:
		a_display_objects_vector.remove_at(idx)


## 移除 ENTER_FRAME 监听（_physics_process 不再调用 global_update）。
func pause() -> void:
	_update_enabled = false
	is_paused = true


func unpause() -> void:
	is_paused = false
	_update_enabled = true


func _physics_process(_delta: float) -> void:
	if _update_enabled:
		global_update()


func end_game(param1: String) -> void:
	var result := param1
	if is_end_game == false:
		is_end_game = true
		_bg_click_enabled = false
		MainGameUIEx.inst.disable_menu()
		var delayed_remover := func() -> void:
			_update_enabled = false
			if result == DEFEAT:
				add_child(def_panel)
				def_panel.init()
			elif result == VICTORY:
				add_child(vic_panel)
				vic_panel.init(num_lifes, cur_level_num)
		tween_node().delayed_call(2.0, delayed_remover)


func enemy_unit_clicked(param1: LivingObject) -> void:
	ground_clicked(null, param1)


func select_all_of_type(param1: int) -> void:
	unselect_all()
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.friendly == true and u.is_npc == false:
			if u.class_kind == param1:
				a_selected_units.append(u)
				if u.selected == false:
					u.set_selected()
		i += 1
	if a_selected_units.size() > 0:
		ingame_ui.show_unit_panel()


func add_small_fireball(param1: SmallFireballEx) -> void:
	effects_cont.add_child(param1)
	a_fireballs.append(param1)


func remove_small_fireball(param1: SmallFireballEx) -> void:
	var idx := a_fireballs.find(param1)
	if idx >= 0:
		a_fireballs.remove_at(idx)


## 取旗帜类（GroundFlagAttack / GroundFlagMove / GroundDefFlag）的缓存实例；缓存按需建立。
func _flag_data(cls: Script) -> Node2D:
	if cls.get("cached_data") == null:
		cls.call("cache", 0)
	unit_cache = cls.get("cached_data")
	return unit_cache.get_data() as Node2D


func stroy_clicked(param1: int, _param2: RWMouseEvent = null) -> void:
	var u: LivingObject
	var flag_attack: Node2D
	var flag_move: Node2D
	var attack_clicked: bool = MainGameUIEx.is_attack_button_clicked
	ingame_ui.reset_attack_def_button()
	ingame_ui.reset_formation_button()
	res_point.x = 0
	res_point.y = 0
	var p5 := Vector2(0, 0)
	var i := 0
	while i < a_selected_units.size():
		u = a_selected_units[i]
		p5.x = u._x
		p5.y = u._y
		res_point.x += p5.x
		res_point.y += p5.y
		i += 1
	res_point.x /= a_selected_units.size()
	res_point.y /= a_selected_units.size()
	var first: LivingObject = a_selected_units[0]
	first.is_defence_stance = not attack_clicked
	first.set_destination(res_point, true)
	if attack_clicked == true:
		flag_attack = _flag_data(GroundFlagAttack)
		flag_attack.added_to_stage(res_point.x, res_point.y)
		Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_ATTACK), false, 0, 0.4, position.x)
	else:
		flag_move = _flag_data(GroundFlagMove)
		flag_move.added_to_stage(res_point.x, res_point.y)
		if RWRandom.rand() > 0.8:
			Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_MOVE_VOICE), false, 0, 0.4, position.x)
		Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_MOVE_NORMAL), false, 0, 0.4, position.x)
	var p8 := 1
	var p9 := 1
	if a_selected_units.size() > 1:
		if param1 == 0:
			i = 1
			while i < a_selected_units.size():
				u = a_selected_units[i]
				u.is_defence_stance = not attack_clicked
				var px: float = res_point.x + 30 * p9 * p8
				var py: float = res_point.y
				p8 *= -1
				if p8 > 0:
					p9 += 1
				u.set_destination(Vector2(px, py), true)
				if attack_clicked == true:
					flag_attack = _flag_data(GroundFlagAttack)
					flag_attack.added_to_stage(px, py)
				else:
					flag_move = _flag_data(GroundFlagMove)
					flag_move.added_to_stage(px, py)
				i += 1
		elif param1 == 1:
			i = 1
			while i < a_selected_units.size():
				u = a_selected_units[i]
				u.is_defence_stance = not attack_clicked
				var px2: float = res_point.x
				var py2: float = res_point.y + 30 * p9 * p8
				p8 *= -1
				if p8 > 0:
					p9 += 1
				u.set_destination(Vector2(px2, py2), true)
				if first.is_defence_stance == false:
					flag_attack = _flag_data(GroundFlagAttack)
					flag_attack.added_to_stage(px2, py2)
				else:
					flag_move = _flag_data(GroundFlagMove)
					flag_move.added_to_stage(px2, py2)
				i += 1


func add_pro_unit(param1: int, param2: LivingObject) -> void:
	ingame_ui.hide_has_upgrade_button(param2)
	g.num_upgrades += 1
	add_soldier(param1, param2, 1, false)


func remove_from_display_object(param1: LivingObject) -> void:
	var idx := a_display_objects_vector.find(param1)
	if idx >= 0:
		a_display_objects_vector.remove_at(idx)


func unit_resurrected(param1: LivingObject) -> void:
	if a_all_units.find(param1) < 0:
		a_all_units.append(param1)
	if a_display_objects_vector.find(param1) < 0:
		a_display_objects_vector.append(param1)
	var idx := a_waiting_death.find(param1)
	if idx >= 0:
		a_waiting_death.remove_at(idx)
		param1.set_death_time(global_counter)


func remove_effect(param1: VisualsTemplate) -> void:
	var idx := a_effects.find(param1)
	if idx >= 0:
		a_effects_to_delete.append(param1)


## param2 为指定父节点（null 则放入 effects_cont / bottom_effects_cont）。
func add_effect(param1: VisualsTemplate, param2: Node, param3: bool = false) -> void:
	var idx := a_effects.find(param1)
	if idx < 0:
		a_effects.append(param1)
		if param2 == null:
			if param3 == false:
				effects_cont.add_child(param1)
			else:
				bottom_effects_cont.add_child(param1)
		else:
			param2.add_child(param1)


func load_level(param1: int) -> void:
	cur_select_index = 0
	level_info = _new_level_template(param1)
	level_info.load_xml_data()


func _new_container(node_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	return n


func _make_background(bg_name: String) -> Node2D:
	var bg := Node2D.new()
	bg.name = "bg_mc"
	var path := "res://assets/backgrounds/%s.png" % bg_name
	if ResourceLoader.exists(path):
		var spr := Sprite2D.new()
		spr.texture = load(path)
		spr.centered = false
		spr.scale = Vector2(0.5, 0.5)  # 背景图为 2x
		bg.add_child(spr)
	else:
		push_error("GameUniverse: missing background %s" % path)
	return bg


# 反编译破损（while(true)/if(false) 包裹），按 P-code 重建：执行顺序即下方源码顺序。
func continue_loading_level_data() -> void:
	cur_wave_info = level_info.a_waves.duplicate()  # concat()：浅拷贝，内层波次对象仍共享（原版如此）
	var bg_name: String
	if cur_level_num == -2:
		bg_name = _new_level_template(0).level_bg
	else:
		bg_name = level_info.level_bg
	# 清理上一局遗留的容器（原版同一个 gameUniverse 反复使用时旧容器已不在显示列表中）
	for old: Node in [bg_mc, bottom_effects_cont, units_cont, healt_bar_cont, effects_cont, ingame_ui]:
		if old != null and old.get_parent() == self:
			remove_child(old)
			if old != ingame_ui:
				old.queue_free()
	bg_mc = _make_background(bg_name)
	add_child(bg_mc)
	PathParser.parse(bg_name, self)
	units_cont = _new_container("units_cont")
	healt_bar_cont = _new_container("healt_bar_cont")
	bottom_effects_cont = _new_container("bottom_effects_cont")
	add_child(bottom_effects_cont)
	add_child(units_cont)
	add_child(healt_bar_cont)
	effects_cont = _new_container("effects_cont")
	add_child(effects_cont)
	ingame_ui.name = "ingame_ui"
	add_child(ingame_ui)
	ingame_ui.hide_red_button()
	_update_enabled = true
	_bg_click_enabled = true
	_bg_down_enabled = true
	_stage_listeners = true
	total_waves = 0
	a_enemy_spawn_timer = []
	var i := 0
	while i < cur_wave_info.size():
		var type: String = cur_wave_info[i][0]["type"]
		if type == LevelTemplate.ENEMY_SPAWN:
			total_waves += 1
			var t_time: int = int(cur_wave_info[i][0]["time"])
			a_enemy_spawn_timer.append(t_time)
		i += 1
	cur_wave = 0
	ingame_ui.draw_current_wave(cur_wave, total_waves)
	set_lives(20)
	if def_flag_object != null:
		tween_node().delayed_call(2.0, func() -> void:
			var d := def_flag_object
			var f: Node2D
			f = _flag_data(GroundDefFlag)
			f.added_to_stage(d.x, d.y)
			f = _flag_data(GroundDefFlag)
			f.added_to_stage(d.x, d.y + d.height / 4)
			f = _flag_data(GroundDefFlag)
			f.added_to_stage(d.x, d.y + d.height / 2)
			f = _flag_data(GroundDefFlag)
			f.added_to_stage(d.x, d.y + (d.height - d.height / 4))
			f = _flag_data(GroundDefFlag)
			f.added_to_stage(d.x, d.y + d.height)
			Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_ATTACK), false, 0, 0.5, position.x))
	level_info.get_locked_units()
	level_info.loading_completed_handler()


func key_pressed_down(key_code: int, _shift_key: bool = false, _ctrl_key: bool = false) -> void:
	if key_code == 65:
		ingame_ui.enable_attack_def_button()
	if key_code == 90:
		show_ranged_circle()
	if key_code == 16:
		ingame_ui.enable_formation_button()


func show_ranged_circle() -> void:
	if circles_are_shown == false:
		circles_are_shown = true
		var i := 0
		while i < LivingObject.a_friend_ranged.size():
			var u: LivingObject = LivingObject.a_friend_ranged[i]
			if u.is_npc == false:
				u.show_circle()
			i += 1


func hide_ranged_circle() -> void:
	if circles_are_shown == true:
		circles_are_shown = false
		var i := 0
		while i < LivingObject.a_friend_ranged.size():
			var u: LivingObject = LivingObject.a_friend_ranged[i]
			if u.is_npc == false:
				u.hide_circle()
			i += 1


func set_lives(param1: float) -> void:
	num_max_lives = param1
	num_lifes = int(param1)
	ingame_ui.draw_lives(num_lifes)


## KEY_UP 处理（原版 keyPressed）。key_code 为 AS3 keyCode。
func key_pressed(key_code: int, shift_key: bool = false, ctrl_key: bool = false) -> void:
	if key_code == 70:
		ingame_ui.click_archers()
	if key_code == 88:
		stroy_clicked(0, null)
	if key_code == 67:
		stroy_clicked(1, null)
	if key_code == 90:
		hide_ranged_circle()
	if key_code == 83:
		ingame_ui.defend_button_clicked()
	if key_code == 81:
		GameUniverse.inst.select_all_of_type(LivingObject.CLASS_WARRIOR)
		return
	if key_code == 87:
		GameUniverse.inst.select_all_of_type(LivingObject.CLASS_ARCHER)
		return
	if key_code == 69:
		GameUniverse.inst.select_all_of_type(LivingObject.CLASS_MAGE)
		return
	if key_code == 82:
		GameUniverse.inst.select_all_of_type(LivingObject.CLASS_PRIEST)
		return
	if key_code == 84:
		GameUniverse.inst.select_all_of_type(LivingObject.CLASS_THIEF)
		return
	if key_code == 16:
		ingame_ui.reset_formation_button()
		return
	if key_code == 65:
		ingame_ui.reset_attack_def_button()
		return
	if key_code == 78:
		ingame_ui.select_next_unit_with_upgrade()
		return
	if key_code == 32:
		ingame_ui.call_controlled_pause()
		return
	if key_code == 80:
		ingame_ui.call_controlled_pause()
		return
	if key_code == 27:
		unselect_all()
		return
	if key_code == 71:
		unselect_all()
		a_selected_units = get_all_enemies(false)
		draw_rings_on_units()
	# 数字键 0-9：编组（原版十段完全相同的代码，仅编号不同）
	if key_code >= 48 and key_code <= 57:
		var n := key_code - 48
		if shift_key == true or ctrl_key == true:
			disable_old_group(n)
			o_unit_groups[n] = a_selected_units.duplicate()
			_chat_message("Group %d set." % n)
			set_group_number_to_units(n)
		else:
			unselect_all()
			a_selected_units = o_unit_groups[n].duplicate()
			draw_rings_on_units()


func disable_old_group(param1: float) -> void:
	var grp: Array = o_unit_groups[int(param1)].duplicate()
	var i := 0
	while i < grp.size():
		var u: LivingObject = grp[i]
		u.cur_group = -1
		i += 1


func set_group_number_to_units(param1: float) -> void:
	Sounds.inst.play(s_lib.get_sound(s_lib.SELECTION), false, 0, 0.5, position.x, s_lib.SELECTION)
	var i := 0
	while i < a_selected_units.size():
		var u: LivingObject = a_selected_units[i]
		u.cur_group = param1
		i += 1


func draw_rings_on_units() -> void:
	var i := 0
	while i < a_selected_units.size():
		var u: LivingObject = a_selected_units[i]
		u.set_selected()
		i += 1
	if a_selected_units.size() > 0:
		ingame_ui.show_unit_panel()


func unselect_all() -> void:
	while a_selected_units.size() > 0:
		var u: LivingObject = a_selected_units[0]
		u.unselect()
		a_selected_units.remove_at(0)
	ingame_ui.hide_unit_panel()
	if selection_box_is_shown == true:
		selection_ramka.destroy()
		selection_box_is_shown = false
		_sel_move_enabled = false


func start_selection_box(_param1: RWMouseEvent = null) -> void:
	selection_box_start_coords = Vector2(mouse_x, mouse_y)
	_sel_move_enabled = true


func selection_box_move(_param1: RWMouseEvent = null) -> void:
	var d: float = selection_box_start_coords.distance_to(Vector2(mouse_x, mouse_y))
	if d > 30:
		if selection_box_is_shown == false:
			selection_box_is_shown = true
			effects_cont.add_child(selection_ramka)
			_bg_click_enabled = false
	if selection_box_is_shown == true:
		selection_ramka.set_coords_and_size(selection_box_start_coords, Vector2(mouse_x, mouse_y))


## 选择框与单位 sens 的 hitTestObject（两个显示对象的包围盒相交，含边界）。
## sens 是单位下的 Sprite2D，取其全局包围盒；LivingObject 另提供 hit_test_sens_rect 时优先使用。
func _sens_hits_rect(u: LivingObject, r: Rect2) -> bool:
	if u.has_method("hit_test_sens_rect"):
		return u.hit_test_sens_rect(r)
	if u.sens != null and u.sens.texture != null:
		var gr: Rect2 = u.sens.get_global_transform() * u.sens.get_rect()
		return gr.intersects(r, true)
	return r.has_point(u.position)


# 反编译破损（while(true) 包裹），按 P-code 重建：对每个满足条件的单位只执行一次 push + setSelected，
# 循环结束后 destroy 选择框并刷新面板；selectionBoxIsShown 复位与移除 MOUSE_MOVE 监听在任何路径都执行。
func stop_selection_box(_param1: RWMouseEvent = null) -> void:
	if selection_box_is_shown == true:
		while a_selected_units.size() > 0:
			var u: LivingObject = a_selected_units.pop_front()
			u.unselect()
		a_selected_units = []
		var i := 0
		while i < a_all_units.size():
			var c: LivingObject = a_all_units[i]
			if c.friendly == true and c.is_npc == false:
				if _sens_hits_rect(c, selection_ramka.rect):
					a_selected_units.append(c)
					if c.selected == false:
						c.set_selected()
			i += 1
		selection_ramka.destroy()
		if a_selected_units.size() > 0:
			ingame_ui.show_unit_panel()
		else:
			ingame_ui.hide_unit_panel()
	selection_box_is_shown = false
	_sel_move_enabled = false


# 反编译破损，按 P-code 重建
# 重建结论：编队（formation）时按与首选单位的相对偏移摆位；否则在鼠标点 ±15 内随机散布（x 先于 y 取随机数）。
# 与已有目的地距离 < 15 时，x、y 各再偏移 -30 + floor(rand*60)（先 x 后 y），并继续检查后续点（不 break）。
# 旗帜按 y 升序 sortOn("y")，再依次 setChildIndex(i)。
func ground_clicked(param1: RWMouseEvent, param2: LivingObject = null) -> void:
	var flags: Array = []
	var attack_flag: Node2D
	var move_flag: Node2D
	if a_selected_units.size() != 0:
		var lead: LivingObject = a_selected_units[0]
		if lead.friendly == false:
			if param2 != null:
				lead.unselect()
				a_selected_units = []
				a_selected_units.append(param2)
				param2.set_selected()
				ingame_ui.show_unit_panel()
			return
		var attack := false
		var formation := false
		if param1 != null:
			if MainGameUIEx.is_attack_button_clicked == true:
				attack = true
			if MainGameUIEx.is_formation_clicked == true:
				formation = true
		else:
			formation = false
			attack = true
		ingame_ui.reset_attack_def_button()
		ingame_ui.reset_formation_button()
		lead.sprioritized_healing_target = null
		lead.is_defence_stance = not attack
		lead.reset_obstacles()
		var dests: Array = []  # Vector.<Point>
		if param2 == null:
			var p7 := Vector2(mouse_x, mouse_y)
			dests.append(p7)
			lead.set_destination(p7, true)
			lead.archer_goto_target = false
		elif lead.can_attack_enemy(param2) == true:
			lead.set_target(param2)
			lead.pursuit_target()
		if attack == true:
			attack_flag = _flag_data(GroundFlagAttack)
			flags.append(attack_flag)
			attack_flag.added_to_stage(mouse_x, mouse_y)
			Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_ATTACK), false, 0, 0.44, position.x)
			lead.set_free_move()
			ingame_ui.disable_defend_button_animation()
		else:
			if RWRandom.rand() > 0.8:
				Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_MOVE_VOICE), false, 0, 0.4, position.x)
			Sounds.inst.play(s_lib.get_sound(s_lib.FLAG_MOVE_NORMAL), false, 0, 0.44, position.x)
			move_flag = _flag_data(GroundFlagMove)
			flags.append(move_flag)
			move_flag.added_to_stage(mouse_x, mouse_y)
		if a_selected_units.size() > 1:
			var i := 1
			while i < a_selected_units.size():
				var u: LivingObject = a_selected_units[i]
				u.reset_obstacles()
				u.is_defence_stance = not attack
				u.sprioritized_healing_target = null
				if attack == true:
					u.set_free_move()
				var fx: float
				var fy: float
				if formation == true:
					var dx: float = -u.position.x + lead.position.x
					var dy: float = -u.position.y + lead.position.y
					fx = mouse_x - dx
					fy = mouse_y - dy
				else:
					fx = mouse_x - 15 + RWRandom.rand() * 30
					fy = mouse_y - 15 + RWRandom.rand() * 30
				if param2 == null:
					var p19 := Vector2(fx, fy)
					var j := 0
					while j < dests.size():
						var q: Vector2 = dests[j]
						if p19.distance_to(q) < 15:
							p19.x = p19.x - 30 + floorf(RWRandom.rand() * 60)
							p19.y = p19.y - 30 + floorf(RWRandom.rand() * 60)
						j += 1
					dests.append(p19)
					u.set_destination(p19, true)
					lead.archer_goto_target = false
					fx = p19.x
					fy = p19.y
				elif u.can_attack_enemy(param2) == true:
					u.set_target(param2)
					u.pursuit_target()
				if param2 == null:
					if lead.is_defence_stance == false:
						attack_flag = _flag_data(GroundFlagAttack)
						attack_flag.added_to_stage(fx, fy)
						flags.append(attack_flag)
					else:
						move_flag = _flag_data(GroundFlagMove)
						move_flag.added_to_stage(fx, fy)
						flags.append(move_flag)
				i += 1
			# sortOn("y")：升序；GDScript 排序不稳定，相等 y 的次序原版同样未定义
			flags.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.y < b.position.y)
			var k := 0
			while k < flags.size():
				var fl: Node2D = flags[k]
				if fl.get_parent() == effects_cont:
					effects_cont.move_child(fl, mini(k, effects_cont.get_child_count() - 1))
				k += 1
	elif param2 != null:
		a_selected_units.append(param2)
		param2.set_selected()
		ingame_ui.show_unit_panel()


func global_update() -> void:
	if is_controlled_pause == false:
		main_update_function()
		update_effects()
		if cur_speed == 2:
			main_update_function()
			update_effects()
	else:
		update_flag_effects()
		update_unit_hp_bars()
		if a_selected_units.size() > 0:
			ingame_ui.update_soldier_data()
		ingame_ui.update_data()


func update_unit_hp_bars() -> void:
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		u.update_health_bar()
		i += 1


func update_flag_effects() -> void:
	var i := 0
	while i < a_effects.size():
		var e: VisualsTemplate = a_effects[i]
		if e.is_map_flag:
			e.update()
		i += 1
	_flush_effects_to_delete()


func _flush_effects_to_delete() -> void:
	while a_effects_to_delete.size() > 0:
		var e: VisualsTemplate = a_effects_to_delete[0]
		var idx := a_effects.find(e)
		if idx >= 0:
			a_effects.remove_at(idx)
		a_effects_to_delete.remove_at(0)


# 反编译破损，按 P-code 重建
# 重建结论：先 ++globalCounter；若 curWaveInfo 非空，则按队首波次类型推进计时/触发事件（聊天、箭雨、召唤、
# 全局波、敌人/友军生成），为空则 checkEnd；随后 levelCustomActions、统计敌人数并逐个 update 单位、
# 更新 massCenter、排序、处理等待死亡单位、刷新 UI、清理 untouchable（每帧最多一个）、每 30 帧更新一次提示。
func main_update_function() -> void:
	global_counter += 1
	var wave_count: int = cur_wave_info.size()
	if wave_count > 0:
		var head: Dictionary = cur_wave_info[0][0]
		time = 30 * int(head.get("time", 0))
		var wtype: String = str(head.get("type", ""))
		var no_enemies: int = int(head.get("no_enemies", 0))
		if cur_time >= time:
			if wtype == LevelTemplate.GAME_CHAT:
				ChatFrameController.init_chat(cur_wave_info[0][1], level_info.get_chat_bounds())
				cur_wave_info.remove_at(0)
				cur_time = 0
			elif wtype == LevelTemplate.ARROWS_SWARM:
				level_info.arrow_strike_called()
				cur_wave_info.remove_at(0)
				cur_time = 0
			elif wtype == LevelTemplate.SUMMON:
				var n: int = cur_wave_info[0][1].size()
				var k := 0
				while k < n:
					var o: Dictionary = cur_wave_info[0][1][0]
					var kind: int = int(o.get("kind", 0))
					var lvl: int = int(o.get("level", 0))
					var route: int = int(o.get("route", 0))
					call_summoned_enemy(kind, lvl, route)
					cur_wave_info[0][1].remove_at(0)
					k += 1
				cur_wave_info.remove_at(0)
				cur_time = 0
			elif wtype == LevelTemplate.GLOBAL_WAVE:
				if is_shown_red_button == false:
					if check_enemies_existence() == false:
						ingame_ui.show_red_button()
						is_shown_red_button = true
						global_wave_counter = 45 * 30
				else:
					global_wave_counter -= 1
					ingame_ui.update_red_button(global_wave_counter)
					if global_wave_counter <= 0:
						ingame_ui.hide_red_button()
						is_shown_red_button = false
						cur_wave_info.remove_at(0)
						cur_time = 0
						_chat_message("New enemies approaching.")
						Sounds.inst.play(s_lib.get_sound(s_lib.NEW_WAVE), false, 0, 0.4, 350)
			else:
				var o2: Dictionary = cur_wave_info[0][1][0]
				var spawn_side := 0  # _loc11_：ENEMY_SPAWN=0，FRIEND_SPAWN=1，其他类型保持初值 0
				if wtype == LevelTemplate.ENEMY_SPAWN:
					spawn_side = 0
				elif wtype == LevelTemplate.FRIEND_SPAWN:
					spawn_side = 1
				var sp: Variant = o2.get("spawnProb", null)  # Number(undefined) = NaN：rand > NaN 恒为 false
				var spawn_prob: float = NAN
				if sp is String:
					spawn_prob = RWXml.as_number(sp)
				elif sp != null:
					spawn_prob = float(sp)
				if RWRandom.rand() > spawn_prob:
					var number: int = int(o2.get("number", 0))
					if number > 0:
						var kind2: int = int(o2.get("kind", 0))
						var lvl2: int = int(o2.get("level", 0))
						if dif_num == 2:
							if lvl2 < 3:
								lvl2 += 1
						if dif_num == 3:
							lvl2 = 3
						var route2: int = int(o2.get("route", 0))
						if spawn_side == 0:
							load_enemy(kind2, lvl2, route2)
						else:
							add_soldier(kind2, null, lvl2, true)
						number -= 1
						if number > 0:
							o2["number"] = number
						else:
							cur_wave_info[0][1].remove_at(0)
							if cur_wave_info[0][1].size() == 0:
								cur_wave_info.remove_at(0)
								cur_time = 0
								if wtype == LevelTemplate.ENEMY_SPAWN:
									cur_wave += 1
									ingame_ui.draw_current_wave(cur_wave, total_waves)
		elif wtype != LevelTemplate.ENEMY_SPAWN:
			if no_enemies == 0:
				cur_time += 1
			elif check_enemies_existence() == false:
				cur_time += 1
		elif check_enemies_existence() == false:
			cur_time += 1
	else:
		check_end()
	level_info.level_custom_actions()
	cur_num_enemies = 0
	var sum_x: float = 0
	var sum_y: float = 0
	var friends := 0
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.friendly == false:
			cur_num_enemies += 1
		else:
			sum_x += u.position.x
			sum_y += u.position.y
			friends += 1
		u.update()
		i += 1
	if friends > 0:
		var mc: Vector2 = LivingObject.mass_center
		mc.x = sum_x / friends
		mc.y = sum_y / friends
		LivingObject.mass_center = mc
	_set_z_index()
	var w := 0
	while w < a_waiting_death.size():
		var d: LivingObject = a_waiting_death[w]
		var idx := a_all_units.find(d)
		if idx >= 0:
			if d.can_remove_from_units_array == true:
				a_all_units.remove_at(idx)
		if d.get_death_time + LivingObject.C_DEATH_TIME_AVALIABLE < global_counter:
			d.set_self_destruct()
			if d.real_friendly == true and d.is_npc == false:
				minus_health()
				level_info.friendly_unit_dead()
		d.update_dead()
		w += 1
	if a_selected_units.size() > 0:
		ingame_ui.update_soldier_data()
	ingame_ui.update_data()
	if LivingObject.v_untouchable_time_mark.size() > 0:
		var mark: int = int(LivingObject.v_untouchable_time_mark[0])
		if mark + 75 < global_counter:
			LivingObject.v_untouchable_time_mark.pop_front()
			LivingObject.v_untouchable_units.pop_front()
	hints_update_counter += 1
	if hints_update_counter > 30:
		hints_update_counter = 0
		HintsManager.update()


func update_effects() -> void:
	var i := 0
	while i < a_effects.size():
		var e: VisualsTemplate = a_effects[i]
		e.update()
		i += 1
	var j := 0
	while j < a_fireballs.size():
		var f: SmallFireballEx = a_fireballs[j]
		f.smoke_generator()
		j += 1
	_flush_effects_to_delete()


## Array.sort(Utility.randomSort)：每次比较消耗一次 rand。Flash 的排序算法与比较次数未公开，
## 这里用插入排序，结果同为均匀随机排列的近似，但 RNG 消耗次数与原版不保证逐次一致。
static func _random_sort(arr: Array) -> void:
	for i in range(1, arr.size()):
		var item: Variant = arr[i]
		var j := i - 1
		while j >= 0 and RWRandom.random_sort(arr[j], item) > 0:
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = item


func call_summoned_enemy(param1: int, param2: int, param3: int) -> void:
	var enemies: Array = get_all_enemies(false)
	if enemies.size() > 0:
		_random_sort(enemies)
		var target: LivingObject = enemies[0]
		var sx: int = int(target.position.x - 60 + 120 * RWRandom.rand())
		var sy: int = int(target.position.y - 60 + 120 * RWRandom.rand())
		var lvl: int = param2
		if dif_num == 2:
			if lvl < 3:
				lvl += 1
		if dif_num == 3:
			lvl = 3
		var e: LivingObject = GameUniverse.inst.load_enemy(param1, lvl, param3, Vector2(sx, sy))
		e.modify_first_point()
		if e.get_kind != LivingObject.UNDEAD_VAMPIRE_KING:
			e.stunned(90)
			var v: Node2D = _flag_data(SummonSingleVisual)
			v.added_to_stage(sx, sy, Callable(e, "set_visible_"), null, true)
		else:
			e.stunned(15)
			var v2: Node2D = _flag_data(SummonKingVisual)
			v2.added_to_stage(sx, sy, Callable(e, "set_visible_"), null, true)
		e.visible = false
		Sounds.inst.play(s_lib.get_sound(s_lib.SUMMON), false, 0, 0.4, e.position.x, s_lib.SUMMON)


func check_end() -> void:
	if check_enemies_existence() == false:
		if def_panel.on_stage == false:
			if ChatFrameController.on_stage == false:
				end_game(VICTORY)


func check_enemies_existence() -> bool:
	if cur_num_enemies > 0:
		return true
	return false


## param4 为 Point 或 null（Variant）。
func load_enemy(param1: int, param2: int, param3: int, param4: Variant = null) -> LivingObject:
	var u: LivingObject = _new_unit(param1)
	units_cont.add_child(u)
	u.uid = global_counter
	u.update_stats()
	u.add_to_game(0, 0)
	if param3 == 0:
		u.set_route(RWRandom.rand_range(1, 3), param4)
	else:
		u.set_route(param3, param4)
	if param2 > 1:
		u.upgrade(param2)
	a_all_units.append(u)
	a_display_objects_vector.append(u)
	_set_z_index()
	var idx := a_revealed_units.find(param1)
	if idx < 0:
		a_revealed_units.append(param1)
		update_revealed_units()
		HintsManager.need_to_show_units(param1)
	return u


# 原版私有方法 setZIndex；与 CanvasItem.set_z_index 同名冲突，故加下划线。
func _set_z_index() -> void:
	ArrayZSorter.sort_clips(a_display_objects_vector, units_cont)


## 原版 REMOVED_FROM_STAGE 的 removed()。
func _exit_tree() -> void:
	if level_info == null:
		return
	clear_data_before_remove()
	level_info.clear_data()
	_bg_click_enabled = false
	_update_enabled = false
	_sel_move_enabled = false
	_bg_down_enabled = false
	_stage_listeners = false
	LivingObject.a_friend_ranged = []
	LivingObject.a_friend_warriors = []


func get_elements_in_area(param1: Vector2, param2: float) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		var d: float = param1.distance_to(Vector2(u.position.x, u.position.y))
		if d <= param2:
			if u.cur_health > 0:
				u.temp_dist_to_attacker = d
				out.append(u)
		i += 1
	return out


func get_all_dead_units_in_area(param1: Vector2, param2: float, param3: bool) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.friendly == param3:
			if u.cur_health <= 0:
				var d: float = param1.distance_to(Vector2(u.position.x, u.position.y))
				if d <= param2:
					if u.get_death_time + 45 > GameUniverse.inst.global_counter:
						u.temp_dist_to_attacker = d
						out.append(u)
		i += 1
	return out


## 原版参数为 Boolean：返回 friendly !== param1 且仍存活的单位。
func get_all_enemies(param1: bool) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.friendly != param1:
			if u.cur_health > 0:
				out.append(u)
		i += 1
	return out


func get_all_friends_not_priests_in_area(param1: Vector2, param2: bool, param3: float) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.real_friendly == param2:
			if u.is_priest == false:
				var d: float = Vector2(u.position.x, u.position.y).distance_to(param1)
				if d <= param3:
					if u.cur_health > 0:
						out.append(u)
		i += 1
	return out


func get_all_friends_in_area(param1: Vector2, param2: bool, param3: float) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.real_friendly == param2:
			var d: float = Vector2(u.position.x, u.position.y).distance_to(param1)
			if d <= param3:
				if u.cur_health > 0:
					out.append(u)
		i += 1
	return out


func get_all_battle_points_in_area(param1: Vector2, param2: float, param3: LivingObject) -> Array:
	var out: Array = []  # Vector.<Point>
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.get_cur_battle != null and u != param3:
			if u.get_cur_battle.is_defender(u):
				var bp: Vector2 = u.battle_point
				var d: float = bp.distance_to(param1)
				if d <= param2:
					if u.cur_health > 0:
						out.append(bp)
		i += 1
	return out


func get_all_units_in_area(param1: Vector2, param2: float) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		var d: float = Vector2(u.position.x, u.position.y).distance_to(param1)
		if d <= param2:
			if u.cur_health > 0:
				out.append(u)
		i += 1
	return out


func get_num_friends_in_area(param1: Vector2, param2: bool, param3: float) -> int:
	var n := 0
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.friendly == param2:
			var d: float = Vector2(u.position.x, u.position.y).distance_to(param1)
			if d <= param3:
				if u.cur_health > 0:
					n += 1
		i += 1
	return n


func get_all_hided_enemies_in_area(param1: Vector2, param2: bool, param3: float) -> Array:
	var out: Array = []
	var i := 0
	while i < a_all_units.size():
		var u: LivingObject = a_all_units[i]
		if u.friendly == param2:
			var d: float = Vector2(u.position.x, u.position.y).distance_to(param1)
			if d <= param3:
				if u.cur_health > 0:
					if u.in_hide == true:
						out.append(u)
		i += 1
	return out


func get_money() -> int:
	return int(current_money)


func get_game_time() -> int:
	return global_counter


func next_wave_clicked() -> void:
	pass


func call_menu() -> void:
	add_child(pause_panel)
	pause_panel.init()


func clear_data_before_remove() -> void:
	a_display_objects_vector.clear()
	is_end_game = true
	while a_all_units.size() > 0:
		var u: LivingObject = a_all_units.pop_front()
		u.clear_data_after_game_end()
	while a_waiting_death.size() > 0:
		var d: LivingObject = a_waiting_death.pop_front()
		d.unit_remover()
	while a_effects.size() > 0:
		var e: VisualsTemplate = a_effects.pop_back()
		e.end_game_remover()
	while a_effects_to_delete.size() > 0:
		var e2: VisualsTemplate = a_effects_to_delete.pop_back()
		e2.end_game_remover()


func unselect_units() -> void:
	while a_selected_units.size() > 0:
		var u: LivingObject = a_selected_units.pop_front()
		u.unselect()


func select_unit(param1: LivingObject) -> void:
	a_selected_units.append(param1)
	param1.set_selected()
	ingame_ui.show_unit_panel()


func unselect_unit(param1: LivingObject) -> void:
	var idx := a_selected_units.find(param1)
	if idx >= 0:
		a_selected_units.remove_at(idx)
	param1.unselect()
	if a_selected_units.size() == 0:
		ingame_ui.hide_unit_panel()


# 反编译破损（while(true) 包裹），按 P-code 语义重建：对每个满足条件的祭司只执行一次三条语句。
func set_prioritized_healing_target(param1: LivingObject) -> void:
	var i := 0
	while i < a_selected_units.size():
		var u: LivingObject = a_selected_units[i]
		if u.is_priest:
			if u.get_stance != LivingObject.FIGHTING:
				u.sprioritized_healing_target = param1
				u.pursuit_target()
				u.is_defence_stance = false
		i += 1


func remove_from_selected_array(param1: LivingObject) -> void:
	var idx := a_selected_units.find(param1)
	if idx >= 0:
		a_selected_units.remove_at(idx)


func get_all_fighting_friends_in_area(param1: Vector2, _param2: bool, param3: float) -> Array:
	var out: Array = []
	var i := 0
	while i < LivingObject.a_friend_warriors.size():
		var u: LivingObject = LivingObject.a_friend_warriors[i]
		var d: float = Vector2(u.position.x, u.position.y).distance_to(param1)
		if d <= param3:
			if u.cur_health > 0:
				if u.get_cur_target != null:
					out.append(u)
		i += 1
	return out


func red_button_clicked() -> void:
	global_wave_counter = 0


func disable_hold_ground() -> void:
	var i := 0
	while i < a_selected_units.size():
		var u: LivingObject = a_selected_units[i]
		if u.friendly:
			u.set_free_move()
		i += 1


# 反编译破损（while(true) 包裹），按语义重建：对每个友军先 setDestination(当前位置) 再 setHoldGroundMove。
func enable_hold_ground() -> void:
	var i := 0
	while i < a_selected_units.size():
		var u: LivingObject = a_selected_units[i]
		if u.friendly:
			u.set_destination(Vector2(u.position.x, u.position.y), true)
			u.set_hold_ground_move()
		i += 1


func strike_arrows() -> void:
	level_info.b_archers_clicked()


func is_upgrade_allowed(param1: int) -> bool:
	return level_info.is_upgrade_allowed(param1)


func update_revealed_units() -> void:
	StoredData.save_data(StoredData.COM_SAVE_REVEALED_UNITS, {"units": a_revealed_units.duplicate()})


func _chat_message(text: String) -> void:
	if ChatController.inst != null:
		ChatController.inst.message(text)


# ---------------------------------------------------------------------------
# 输入路由：把 Godot 输入换算成原版的舞台事件（视口即 700x600 舞台）。
# ---------------------------------------------------------------------------
func _mouse_pos() -> Vector2:
	if mouse_override != null:
		return mouse_override
	if not is_inside_tree():
		return Vector2.ZERO
	return get_local_mouse_position()


## 按原显示列表从上到下查找命中的单位：units_cont 子节点逆序 + LivingObject.hit_test_sens。
func hit_test_unit(stage_point: Vector2) -> LivingObject:
	if units_cont == null:
		return null
	var i := units_cont.get_child_count() - 1
	while i >= 0:
		var c := units_cont.get_child(i)
		if c is LivingObject and c.hit_test_sens(stage_point):
			return c
		i -= 1
	return null


func _make_mouse_event(ev: InputEventMouse) -> RWMouseEvent:
	var p := _mouse_pos()
	# macOS 上 Ctrl+左键会被系统当作右键，故 Cmd 也按 ctrlKey 处理（与 Flash 里 Ctrl+点击的用法对应）
	return RWMouseEvent.new(p.x, p.y, ev.shift_pressed, ev.ctrl_pressed or ev.meta_pressed, ev.alt_pressed)


## 左键按下：命中单位则记录为点击目标；否则是 bg_mc 的 MOUSE_DOWN（开始选择框）。
func mouse_down(evt: RWMouseEvent) -> void:
	if not _stage_listeners:
		return
	var p := Vector2(evt.stage_x, evt.stage_y)
	var u := hit_test_unit(p)
	if u != null:
		_press_target = u
	else:
		_press_target = bg_mc
		if _bg_down_enabled:
			start_selection_box(evt)


## 左键抬起：先 stage MOUSE_UP（stopSelectionBox），再在按下/抬起目标相同时派发 CLICK。
func mouse_up(evt: RWMouseEvent) -> void:
	if not _stage_listeners:
		return
	stop_selection_box(evt)
	var p := Vector2(evt.stage_x, evt.stage_y)
	var u := hit_test_unit(p)
	var target: Variant = u if u != null else bg_mc
	if _press_target != null and is_same(_press_target, target):
		if u != null:
			u.clicked(evt)
		elif _bg_click_enabled:
			ground_clicked(evt)
	_press_target = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_down(_make_mouse_event(event))


func _input(event: InputEvent) -> void:
	if not _stage_listeners:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		mouse_up(_make_mouse_event(event))
	elif event is InputEventMouseMotion:
		if _sel_move_enabled:
			selection_box_move(_make_mouse_event(event))
	elif event is InputEventKey:
		var kc := to_as3_key_code(event.keycode)
		if kc == 0:
			return
		var ctrl: bool = event.ctrl_pressed or event.meta_pressed
		if event.pressed:
			key_pressed_down(kc, event.shift_pressed, ctrl)
		else:
			key_pressed(kc, event.shift_pressed, ctrl)


## Godot Key -> 原版 keyCode（字母 65-90、数字 48-57、Space 32 与 ASCII 相同；Shift 16、Ctrl 17、Esc 27）。
static func to_as3_key_code(k: int) -> int:
	if k == KEY_SHIFT:
		return 16
	if k == KEY_CTRL:
		return 17
	if k == KEY_ESCAPE:
		return 27
	if k > 0 and k < 256:
		return k
	return 0
