# 移植自 S/gameCore/specials/specialTemplate.as
# 原版的 internal 成员（timeUntilUpdate、aTimeUntilUpdate、resetCounter、setParams）在 GDScript 中同样公开。
class_name SpecialTemplate
extends RefCounted

var counter: int = -1  # private
var time_until_update: int = 0
var a_time_until_update: Array = []
var cur_spec_level: int = 0
var is_active: bool = true  # private
var externally_unlocked: bool = false  # private
var special_description: String = ""
var number_in_panel: int = 1
var is_locked: bool = false

func reset_counter() -> void:
	counter = 0

func get_spec_level(param1: bool, param2: int) -> int:
	if param1 == false:
		is_locked = false
		is_active = true
		return 2
	var loc3: Array = (StoredData.local_game_data[StoredData.NUMPAN_ABILS] as Array).duplicate()
	# AS3 越界/负下标读到 undefined，int(undefined) == 0；GDScript 负下标会读到末尾元素，越界则报错，故显式处理。
	var loc4: int = 0
	if param2 >= 0 and param2 < loc3.size():
		loc4 = int(loc3[param2])
	if externally_unlocked == true:
		loc4 = 3
	if loc4 == 0:
		is_active = false
		is_locked = true
		return 0
	is_active = true
	is_locked = false
	return loc4 - 1

func set_params(_param1: bool = true) -> void:
	pass

func can_use_special() -> bool:
	if not is_locked:
		if counter >= time_until_update:
			return true
		return false
	return false

func update() -> void:
	counter += 1

func lock_special() -> void:
	is_active = false

func unlock_special() -> void:
	is_active = true
	is_locked = false

func cur_level_params() -> String:
	return ""

func unlock_abil_set_max_level() -> void:
	externally_unlocked = true
	set_params(true)

func set_random_time() -> void:
	counter = RWRandom.rand_range(1, time_until_update)

var get_cur_counter: int:
	get:
		return counter

var get_count_percent: int:
	get:
		if counter >= time_until_update:
			return 100
		if counter == -1:
			return 100
		return AS3.round(float(counter) / time_until_update * 100)
