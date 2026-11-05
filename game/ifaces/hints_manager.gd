# 移植自 S/gameCore/ifaces/hintsManager.as
# 右下角"新提示 / 新敌人"两个图标的弹出管理。update() 由 GameUniverse 每 30 帧（hintsUpdateCounter > 30）调一次，
# 图标在上次被点掉 5 秒（提示）/ 4 秒（敌人）之后才会再弹出。
# 偏离：hintTip 符号（6595）没有导出为 scenes/clips 场景，找不到时临时提示不显示（见汇报）。
class_name HintsManager
extends RefCounted

const HINT := "hint"
const ENEMY := "enemy"

static var e_new_enemy: FlashClip  # monsterMC
static var e_new_hint: FlashClip  # tipMC
static var top_position: Vector2
static var bottom_position: Vector2
static var hided_position: int = 0
static var new_hint_shown: bool = false
static var new_enemy_shown: bool = false
static var top_mc: FlashClip = null
static var a_hints_list: Array = []
static var when_removed_hint: int = 0
static var when_removed_units: int = 0
static var a_units_list: Array = []
static var hint: Node = null  # hintTip
static var temp_hint_added: bool = false
static var need_to_show_temp_hint: bool = false
static var o_hint_callback: Variant = null
static var on_enemy_call_back: Variant = null
static var cur_num: int = 0

const HINT_TIP_SCENE := "res://scenes/clips/hintTip.tscn"

static func init(param1: FlashClip, param2: FlashClip) -> void:
	temp_hint_added = false
	e_new_hint = param2
	e_new_enemy = param1
	IfaceUtil.goto_and_stop(param2, 1)
	IfaceUtil.goto_and_stop(param1, 1)
	top_position = Vector2(param1.position.x, param1.position.y)
	bottom_position = Vector2(param2.position.x, param2.position.y)
	hided_position = 757
	if ResourceLoader.exists(HINT_TIP_SCENE):
		hint = (load(HINT_TIP_SCENE) as PackedScene).instantiate()
		hint.mouse_children = false
		hint.mouse_enabled = false
	else:
		hint = null

static func update() -> void:
	var _loc1_: int
	if a_hints_list.size() > 0:
		if new_hint_shown == false:
			_loc1_ = GameUniverse.inst.get_game_time()
			if when_removed_hint + 5 * 30 < _loc1_:
				show_icon(e_new_hint)
				if need_to_show_temp_hint:
					need_to_show_temp_hint = false
					if hint != null:
						GameUniverse.inst.add_child(hint)
						hint.position.x = top_position.x
						hint.position.y = e_new_hint.position.y
						hint.modulate.a = 1.0
						RWTween.from(hint, 0.3, {"alpha": 0, "delay": 1})
					temp_hint_added = true
	if a_units_list.size() > 0:
		if new_enemy_shown == false:
			_loc1_ = GameUniverse.inst.get_game_time()
			if when_removed_units + 4 * 30 < _loc1_:
				show_icon(e_new_enemy)
	if cur_num >= 0:
		IfaceUtil.main().add_tutorial(cur_num)
		cur_num = -1

static func show_icon(param1: FlashClip) -> void:
	param1.play()
	if top_mc == null:
		top_mc = param1
		param1.position.y = top_position.y
	else:
		param1.position.y = bottom_position.y
	RWTween.to(param1, 0.6, {"x": top_position.x})
	if param1 == e_new_hint:
		new_hint_shown = true
	elif param1 == e_new_enemy:
		new_enemy_shown = true
	IfaceUtil.play_sound(SoundLibrary.FLAG_HEAL, 0, 0.35)

static func need_to_show_hint(param1: int) -> void:
	if StoredData.main_params.get("hints", false):
		a_hints_list.append(param1)

static func need_to_show_units(param1: int) -> void:
	if StoredData.main_params.get("hints", false):
		a_units_list.append(param1)

static func removed() -> void:
	if temp_hint_added:
		if hint != null and hint.get_parent() != null:
			GameUniverse.inst.remove_child(hint)
		temp_hint_added = false
	IfaceUtil.goto_and_stop(e_new_enemy, 1)
	IfaceUtil.goto_and_stop(e_new_hint, 1)
	ButtonClass.remove_button_scale(e_new_enemy, clicked)
	ButtonClass.remove_button_scale(e_new_hint, clicked)

static func game_started() -> void:
	o_hint_callback = null
	on_enemy_call_back = null
	need_to_show_temp_hint = false
	temp_hint_added = false
	e_new_enemy.position.x = hided_position
	e_new_hint.position.x = hided_position
	ButtonClass.add_button_scale(e_new_enemy, clicked)
	ButtonClass.add_button_scale(e_new_hint, clicked)
	new_hint_shown = false
	new_enemy_shown = false
	top_mc = null
	a_hints_list = []
	a_units_list = []
	when_removed_hint = 0
	when_removed_units = 0
	cur_num = -1

static func show_temp_hint() -> void:
	need_to_show_temp_hint = true

static func hide_temp_hint() -> void:
	if temp_hint_added == true:
		temp_hint_added = false
		if hint != null and hint.get_parent() != null:
			GameUniverse.inst.remove_child(hint)

static func call_back_button_clicked(param1: String, param2: Callable) -> void:
	if param1 == HINT:
		o_hint_callback = {"callback": param2}
	elif param1 == ENEMY:
		on_enemy_call_back = {"callback": param2}

static func call_back_button_removed(param1: String) -> void:
	if param1 == HINT:
		o_hint_callback = null
	elif param1 == ENEMY:
		on_enemy_call_back = null

static func clicked(param1: ButtonClass.ButtonEvent) -> void:
	var _loc2_: FlashClip = param1.target
	GameUniverse.inst.level_info.clicked_hint()
	hide_icon(_loc2_)
	IfaceUtil.play_sound(SoundLibrary.CLICK1, 0, 0.3)
	if _loc2_ == e_new_hint:
		if a_hints_list.size() > 0:
			if o_hint_callback != null:
				o_hint_callback.callback.call()
			cur_num = a_hints_list.pop_front()
			GameUniverse.inst.hints_update_counter = 40
	elif a_units_list.size() > 0:
		if on_enemy_call_back != null:
			on_enemy_call_back.callback.call()
		cur_num = a_units_list.pop_front()
		IfaceUtil.main().add_unit_hint(cur_num)
		cur_num = -1

static func hide_icon(param1: FlashClip) -> void:
	IfaceUtil.goto_and_stop(param1, 1)
	RWTween.to(param1, 0.6, {"x": hided_position})
	if param1 == e_new_hint:
		when_removed_hint = GameUniverse.inst.get_game_time()
		new_hint_shown = false
		if top_mc == e_new_hint:
			if new_enemy_shown == true:
				top_mc = e_new_enemy
				RWTween.to(top_mc, 0.5, {"x": top_position.x, "y": top_position.y})
			else:
				top_mc = null
	else:
		when_removed_units = GameUniverse.inst.get_game_time()
		new_enemy_shown = false
		if top_mc == e_new_enemy:
			if new_hint_shown == true:
				top_mc = e_new_hint
				RWTween.to(top_mc, 0.5, {"x": top_position.x, "y": top_position.y})
			else:
				top_mc = null
