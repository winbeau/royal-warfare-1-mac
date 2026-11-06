## 二次开发（第二章）：关卡基类。所有二章关卡共用这一个类，内容来自 data/ch2/levels/%02d.json，
## 文本经 Ch2Text 取英文。战斗流程（阶段、出兵、目标、胜负）交给 Ch2Director，本类只负责
## 关卡加载时的一次性布置（开局兵力、盟军、目标对象、导演）和把 LevelTemplate 的各个钩子转发出去。
class_name LevelCh2
extends LevelTemplate

var level_number: int
var data: Dictionary = {}
var map_id: String = ""  # data/ch2/maps/<map_id>.json、data/ch2/masks/<map_id>.png 共用的 id
var friendly_route: Array = []  # 关卡 JSON 的 friendly_route（可选，PathParser.parse_ch2 用）

var director: Ch2Director
var hud: Ch2ObjectiveHud
var gu: GameUniverse


func _init(n: int) -> void:
	level_number = n
	gu = GameUniverse.inst
	data = _load_level_data(n)
	var background: String = str(data.get("background", ""))
	map_id = background
	level_bg = "ch2/" + background
	var text: Dictionary = Ch2Text.level(n)
	level_caption = str(text.get("name", data.get("name", "")))
	level_description = str(text.get("briefing", ""))
	for pt: Array in data.get("friendly_route", []):
		friendly_route.append([float(pt[0]), float(pt[1])])


static func _load_level_data(n: int) -> Dictionary:
	var path := "res://data/ch2/levels/%02d.json" % n
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelCh2: missing level data %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## 对应 LevelTemplate.load_xml_data：二章不读 XML 波次，aWaves 留空，由导演驱动战斗节奏。
func load_xml_data() -> void:
	a_waves = []
	GameUniverse.inst.continue_loading_level_data()


func get_locked_units() -> void:
	var names: Array = data.get("locked", [])
	var consts: Array = []
	for n: String in names:
		var c := Ch2Kinds.resolve_lock(n)
		if c == -1:
			push_error("LevelCh2: unknown locked name %s" % n)
		else:
			consts.append(c)
	GameUniverse.inst.ingame_ui.lock_units(consts)


func loading_completed_handler() -> void:
	Sounds.ch2_sfx_muted = true  # WP-D1 D1.8：二章战斗角色/战斗音效全部静音，音乐不受影响
	gu.reset_money(float(data.get("start", {}).get("money", 0)))
	_place_start_units()
	_place_allies()
	director = Ch2Director.new(gu, level_number, data)
	if gu.ingame_ui.e_hp != null:
		gu.ingame_ui.e_hp.visible = false
	hud = Ch2ObjectiveHud.new(director)
	gu.add_child(hud)
	gu.move_child(hud, gu.get_child_count() - 1)


## WP-D3 补缺：关卡 JSON 的 "weapon" 字段（如 "great_glaive"）直接给镇戍卫/火铳卫换上开局高级武器，
## 不受“2 级经验满才能换”的限制（force=true，等同招募面板直接招高级武器的流程），单位就是 3 级。
## 没有写 weapon 字段时保留 add_to_game/upgrade() 已经套用的职业基础武器，不调用 set_weapon。
func _apply_start_weapon(unit: LivingObject, u: Dictionary) -> void:
	var weapon_name: Variant = u.get("weapon", null)
	if weapon_name == null:
		return
	if unit.has_method("set_weapon"):
		unit.set_weapon(str(weapon_name), true)
	else:
		push_error("LevelCh2: unit kind %s has no set_weapon, ignoring weapon field %s" % [u.get("kind", ""), weapon_name])


func _place_start_units() -> void:
	for u: Dictionary in data.get("start", {}).get("units", []):
		var kind := Ch2Kinds.resolve(str(u.get("kind", "")))
		if kind == -1:
			push_error("LevelCh2: unknown start unit kind %s" % u.get("kind", ""))
			continue
		var unit: LivingObject = gu.add_soldier(kind, null, int(u.get("level", 1)), true)
		var at: Array = u.get("at", [0, 0])
		unit.set_external_position(Vector2(float(at[0]), float(at[1])))
		_apply_start_weapon(unit, u)
		unit.unlock_abils_set_max_level()


func _place_allies() -> void:
	for a: Dictionary in data.get("start", {}).get("allies", []):
		var kind := Ch2Kinds.resolve(str(a.get("kind", "")))
		if kind == -1:
			push_error("LevelCh2: unknown ally kind %s" % a.get("kind", ""))
			continue
		var hold: Array = a.get("hold", [0, 0])
		var controllable: bool = bool(a.get("controllable", false))
		var count: int = int(a.get("count", 1))
		for _i in count:
			var unit: LivingObject = gu.add_soldier(kind, null, int(a.get("level", 1)), true)
			unit.set_external_position(Vector2(float(hold[0]), float(hold[1])))
			_apply_start_weapon(unit, a)
			unit.unlock_abils_set_max_level()
			unit.ch2_uncontrollable = not controllable
			unit.zero_point = unit.position  # 驻守锚点：main_alg_destination_reached 离开 zero_point 太远会自动归位


func level_custom_actions() -> void:
	if director != null:
		director.update()
	if hud != null:
		hud.refresh()


func got_text(param1: String) -> void:
	pass  # 对白内容本身不驱动导演；窗口关闭由 chat_closed / 队列轮询处理


func chat_closed() -> void:
	if director != null:
		director.on_chat_closed()


func allows_default_end() -> bool:
	return false


func uses_lives() -> bool:
	return false


func clear_data() -> void:
	Sounds.ch2_sfx_muted = false  # WP-D1 D1.8
	if hud != null and hud.get_parent() != null:
		hud.get_parent().remove_child(hud)
		hud.queue_free()
	hud = null
	if gu != null and gu.ingame_ui != null and gu.ingame_ui.e_hp != null:
		gu.ingame_ui.e_hp.visible = true


## 1 星（胜利）、2 星（达到 stars.2 的 losses_max）、3 星（再达到 stars.3 的 losses_max 与可选目标）。
## losses_max：本关死亡的己方可控单位数不超过该值；optional：该 id 对应的可选目标已完成。
func compute_stars() -> int:
	var stars := 1
	var tiers: Dictionary = data.get("stars", {})
	if _meets_star(tiers.get("2", null)):
		stars = 2
		if _meets_star(tiers.get("3", null)):
			stars = 3
	return stars


func _meets_star(tier: Variant) -> bool:
	if tier == null or director == null:
		return false
	var t: Dictionary = tier
	if t.has("losses_max") and director.losses > int(t["losses_max"]):
		return false
	if t.has("optional"):
		var obj: Ch2ObjectiveBase = director.objectives_by_id.get(str(t["optional"]), null)
		if obj == null or not obj.is_complete():
			return false
	return true
