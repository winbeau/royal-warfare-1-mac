# 移植自 S/gameCore/levels/levelTemplate.as
# 关卡基类：aWaves 的生成（xml_loaded）与各关卡钩子。
# levelBg 原为背景符号类，这里存背景类名字符串，供 A1 加载背景和布局。
# Main.debugMode 分支（从 levelXMLPath 读文件）不移植：始终经 ExtDataManager.inst.get_level_xml 取 RWXml。
class_name LevelTemplate
extends RefCounted

const GAME_CHAT := "gameChat"
const FRIEND_SPAWN := "friendSpawn"
const ENEMY_SPAWN := "enemySpawn"
const GLOBAL_WAVE := "globalWave"
const ARROWS_SWARM := "arrowsSwarm"
const SUMMON := "summon"

var level_bg: String = ""
var a_waves: Array = []
var level_caption: String = ""
var level_description: String = ""
var level_xml_path: String = ""


func level_custom_actions() -> void:
	pass


## 二次开发钩子（默认值等于一代行为）：为 false 时 GameUniverse.check_end 不做"波次出完即胜利"的默认判定。
func allows_default_end() -> bool:
	return true


## 二次开发钩子：为 false 时 GameUniverse.minus_health 不扣生命、不因生命归零判负。
func uses_lives() -> bool:
	return true


## 未匹配时原版返回 null；GDScript 的 String 不能为 null，返回 ""。
func parse_wave_type(param1: String) -> String:
	var _loc2_: String = ""
	match param1:
		"GLOBAL_WAVE": _loc2_ = GLOBAL_WAVE
		"FRIEND_SPAWN": _loc2_ = FRIEND_SPAWN
		"GAME_CHAT": _loc2_ = GAME_CHAT
		"ENEMY_SPAWN": _loc2_ = ENEMY_SPAWN
		"ARROWS_SWARM": _loc2_ = ARROWS_SWARM
		"SUMMON": _loc2_ = SUMMON
	return _loc2_


func load_xml_data() -> void:
	xml_loaded(ExtDataManager.inst.get_level_xml(GameUniverse.inst.cur_level_num))


## 未匹配的字符串返回 0（原版 int 默认值，恰为 UNDEAD_DARTH_KNIGHT），照搬。
func parse_unit_type(param1: String) -> int:
	var _loc2_: int = 0
	match param1:
		"FR_WISEMAN": _loc2_ = LivingObject.FR_WISEMAN
		"NPC_OLDMAN": _loc2_ = LivingObject.NPC_OLDMAN
		"NPC_MAN": _loc2_ = LivingObject.NPC_MAN
		"NPC_WOMAN": _loc2_ = LivingObject.NPC_WOMAN
		"FR_WARRIOR": _loc2_ = LivingObject.FR_WARRIOR
		"FR_ARCHER": _loc2_ = LivingObject.FR_ARCHER
		"FR_PRIEST": _loc2_ = LivingObject.FR_PRIEST
		"FR_BLUEMAGE": _loc2_ = LivingObject.FR_BLUEMAGE
		"FR_SWORDMASTER": _loc2_ = LivingObject.FR_SWORDMASTER
		"FR_REDMAGE": _loc2_ = LivingObject.FR_REDMAGE
		"FR_BLACKMAGE": _loc2_ = LivingObject.FR_BLACKMAGE
		"FR_HEALER": _loc2_ = LivingObject.FR_HEALER
		"FR_BLESSER": _loc2_ = LivingObject.FR_BLESSER
		"FR_SNIPER": _loc2_ = LivingObject.FR_SNIPER
		"FR_KNIGHT": _loc2_ = LivingObject.FR_KNIGHT
		"FR_KING": _loc2_ = LivingObject.FR_KING
		"FR_CROSSBOW": _loc2_ = LivingObject.FR_CROSSBOW
		"FR_ROGUE": _loc2_ = LivingObject.FR_ROGUE
		"FR_ASSASIN": _loc2_ = LivingObject.FR_ASSASIN
		"FR_SABOTEUR": _loc2_ = LivingObject.FR_SABOTEUR
		"UNDEAD_ZOMBIE": _loc2_ = LivingObject.UNDEAD_ZOMBIE
		"UNDEAD_GRAY_ZOMBIE": _loc2_ = LivingObject.UNDEAD_GRAY_ZOMBIE
		"UNDEAD_PLAGUE_ZOMBIE": _loc2_ = LivingObject.UNDEAD_PLAGUE_ZOMBIE
		"UNDEAD_SKELETON": _loc2_ = LivingObject.UNDEAD_SKELETON
		"UNDEAD_SKELETON_ARCHER": _loc2_ = LivingObject.UNDEAD_SKELETON_ARCHER
		"UNDEAD_SKELETON_CAPITAN": _loc2_ = LivingObject.UNDEAD_SKELETON_CAPITAN
		"UNDEAD_SKELETON_ARM": _loc2_ = LivingObject.UNDEAD_SKELETON_ARM
		"UNDEAD_SEEKER": _loc2_ = LivingObject.UNDEAD_SEEKER
		"UNDEAD_RANGER": _loc2_ = LivingObject.UNDEAD_RANGER
		"UNDEAD_STORMARCHER": _loc2_ = LivingObject.UNDEAD_STORMARCHER
		"UNDEAD_STORMTROOPER": _loc2_ = LivingObject.UNDEAD_STORMTROOPER
		"UNDEAD_STORMGUARDIAN": _loc2_ = LivingObject.UNDEAD_STORMGUARDIAN
		"UNDEAD_DARTH_KNIGHT": _loc2_ = LivingObject.UNDEAD_DARTH_KNIGHT
		"MONSTER_GREEN_HOUND": _loc2_ = LivingObject.MONSTER_GREEN_HOUND
		"MONSTER_HOUND": _loc2_ = LivingObject.MONSTER_HOUND
		"UNDEAD_SHAMAN": _loc2_ = LivingObject.UNDEAD_SHAMAN
		"MONSTER_KAMIKAZE": _loc2_ = LivingObject.MONSTER_KAMIKAZE
		"UNDEAD_WITCH": _loc2_ = LivingObject.UNDEAD_WITCH
		"MONSTER_OGRE": _loc2_ = LivingObject.MONSTER_OGRE
		"MONSTER_TROLL": _loc2_ = LivingObject.MONSTER_TROLL
		"UNDEAD_VAMPIRE": _loc2_ = LivingObject.UNDEAD_VAMPIRE
		"UNDEAD_VAMPIRE_LORD": _loc2_ = LivingObject.UNDEAD_VAMPIRE_LORD
		"UNDEAD_VAMPIRE_KING": _loc2_ = LivingObject.UNDEAD_VAMPIRE_KING
		"UNDEAD_SUMMONER": _loc2_ = LivingObject.UNDEAD_SUMMONER
		"UNDEAD_GHOST": _loc2_ = LivingObject.UNDEAD_GHOST
		"MONSTER_KAMI_SHIELD": _loc2_ = LivingObject.MONSTER_KAMI_SHIELD
	return _loc2_


func get_locked_units() -> void:
	pass


func loading_completed_handler() -> void:
	pass


func got_text(param1: String) -> void:
	pass


func clear_data() -> void:
	pass


func chat_closed() -> void:
	pass


func next_wave_showed() -> void:
	pass


func upgrade_sign_showed() -> void:
	pass


func friendly_unit_dead() -> void:
	pass


func arrow_strike_called() -> void:
	pass


func b_archers_clicked() -> void:
	pass


func external_check() -> bool:
	return true


func external_data_inserted() -> void:
	pass


func get_chat_bounds() -> bool:
	return false


func is_upgrade_allowed(param1: int) -> bool:
	return true


func unit_dead(param1: int) -> void:
	pass


func clicked_hint() -> void:
	pass


## 辅助（非原版成员）：Vector.sort(Utility.randomSort) 的近似。Flash 的排序算法调用比较函数的次数无法复现，
## 这里用插入排序，每次比较调用一次 RWRandom.random_sort；仅保证结果是随机排列。
static func random_sort_array(arr: Array) -> void:
	for i in range(1, arr.size()):
		var item = arr[i]
		var j := i - 1
		while j >= 0 and RWRandom.random_sort(arr[j], item) > 0.0:
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = item


## 从 <unit> 列表读取 {kind, level, route, number, spawnProb}（FRIEND_SPAWN / ENEMY_SPAWN）。
func _read_units(data_node: RWXml) -> Array:
	var units: Array = []
	for u: RWXml in data_node.children():
		units.push_back({
			"kind": parse_unit_type(u.text("kind").strip_edges()),
			"level": u.to_int("level"),
			"route": u.to_int("route"),
			"number": u.to_int("number"),
			"spawnProb": u.to_number("spawnProb"),
		})
	return units


## 反编译破损的只有外围 switch 的 §§goto（落到 break），逻辑清晰，按反编译结果移植。
## 注意：<data> 缺失时原版 _loc4_.data[0] 为 undefined，children() 会抛错；这里把缺失当作空节点。
func xml_loaded(param1: RWXml) -> void:
	a_waves = build_waves(param1)
	GameUniverse.inst.continue_loading_level_data()


## 辅助（非原版成员）：xmlLoaded 中生成 aWaves 的部分，便于不依赖 GameUniverse 测试。
func build_waves(param1: RWXml) -> Array:
	var a_waves: Array = []
	for wave: RWXml in param1.children():
		var _loc5_: Array = []
		match wave.text("type").strip_edges():
			"FRIEND_SPAWN":
				var units := _read_units(wave.child("data"))
				_loc5_ = [{"time": wave.to_int("time"), "no_enemies": wave.to_int("no_enemies"), "type": FRIEND_SPAWN}, units]
			"GAME_CHAT":
				var lines: Array = []
				for say: RWXml in wave.child("data").children():
					lines.push_back({
						"unitNumberInPanel": parse_unit_type(say.text("who").strip_edges()),
						"txt": say.text("text").strip_edges(),  # ignoreWhitespace 会去掉文本节点首尾空白
					})
				_loc5_ = [{"time": wave.to_int("time"), "no_enemies": wave.to_int("no_enemies"), "type": GAME_CHAT}, lines]
			"GLOBAL_WAVE":
				_loc5_ = [{"time": wave.to_int("time"), "type": GLOBAL_WAVE, "no_enemies": wave.to_int("no_enemies")}]
			"ARROWS_SWARM":
				_loc5_ = [{"time": wave.to_int("time"), "type": ARROWS_SWARM, "no_enemies": wave.to_int("no_enemies")}]
			"ENEMY_SPAWN":
				var units := _read_units(wave.child("data"))
				_loc5_ = [{"time": wave.to_int("time"), "no_enemies": wave.to_int("no_enemies"), "type": ENEMY_SPAWN}, units]
			"SUMMON":
				var summon_units: Array = []
				for u: RWXml in wave.child("data").children():
					summon_units.push_back({
						"kind": parse_unit_type(u.text("kind").strip_edges()),
						"level": u.to_int("level"),
						"route": u.to_int("route"),
					})
				_loc5_ = [{"time": wave.to_int("time"), "no_enemies": wave.to_int("no_enemies"), "type": SUMMON}, summon_units]
		a_waves.push_back(_loc5_)
	return a_waves
