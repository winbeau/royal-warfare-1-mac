# 移植自 S/gameCore/living/meleeFighter.as
# 近战兵种基类：索敌周期 GLOBAL_SEARCH_COUNTER，按"单挑 / 攻击方 / 防守方"三堆选目标。
# 与原版的差异（均不影响概率与调用顺序以外的行为）：
# - Array.sortOn / Array.sort(randomSort) 用 sort_on / random_sort_array 实现（稳定插入排序）。Flash 的排序算法未公开，
#   平局时的次序与 sort(randomSort) 消耗 RNG 的次数不保证与原版逐次一致（与 GameUniverse._random_sort 同一处理）。
# - checkEnemy 原为 searchTargetEnemy 里的闭包，读取外层变量 enemy；这里写成 check_enemy(enemy)。
class_name MeleeFighter
extends LivingObject

const MAX_BATTLEPOINT_DISTANCE := 150
const NUMERIC_DESCENDING := "numericDescending"
const NUMERIC := "numeric"

var a_battles_enemy_single_melee: Array = []
var a_battles_enemy_defender_melee: Array = []
var a_battles_enemy_attacker_melee: Array = []
var a_ranged: Array = []

## Array.sortOn(prop, Array.NUMERIC [| Array.DESCENDING])。prop 为 snake_case 属性名。
static func sort_on(arr: Array, prop: String, descending: bool = false) -> void:
	for i in range(1, arr.size()):
		var item: Variant = arr[i]
		var key: float = float(item.get(prop))
		var j := i - 1
		while j >= 0:
			var other: float = float(arr[j].get(prop))
			var swap: bool = other < key if descending else other > key
			if not swap:
				break
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = item

## Array.sort(Utility.randomSort)：每次比较消耗一次 rand（comparator 返回 -1 或 1）。
static func random_sort_array(arr: Array) -> void:
	for i in range(1, arr.size()):
		var item: Variant = arr[i]
		var j := i - 1
		while j >= 0 and RWRandom.random_sort(arr[j], item) > 0:
			arr[j + 1] = arr[j]
			j -= 1
		arr[j + 1] = item

func search_target(_param1: bool = false) -> void:
	if friendly == true:
		search_target_friendly()
	else:
		search_target_enemy()

func on_play_head_action() -> void:
	if friendly:
		if RWRandom.rand() > 0.91:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_VOICE), false, 0, 0.5, position.x, SoundLibrary.SWORD_SWOOSH)
		elif RWRandom.rand() > 0.5:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.5, position.x, SoundLibrary.SWORD_SWOOSH)
	elif RWRandom.rand() > 0.5:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.5, position.x, SoundLibrary.SWORD_SWOOSH)
	elif RWRandom.rand() > 0.9:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MONSTERS), false, 0, 0.4, position.x, SoundLibrary.MONSTERS)

## 原 searchTargetEnemy 内的闭包 checkEnemy（enemy 为外层循环变量）
func check_enemy(enemy: LivingObject) -> void:
	if enemy.cur_health > 0:
		var loc1: bool = true
		var key: String = LivingObject.pursue_key(enemy)
		var loc2: int = int(o_pursue_counter.get(key, 0))
		if loc2 >= MAX_TIME_PURSUE:
			var loc3: float = AS3.get_distance(enemy, _instance)
			if loc3 < MAX_DISTANCE_BEFORE_MAKING_BATTLE:
				o_pursue_counter[key] = 1
				loc1 = true
			else:
				loc1 = false
		if in_field(enemy) and enemy.in_hide == false and LivingObject.v_untouchable_units.find(enemy) < 0 and loc1 == true:
			var loc4: float = AS3.get_distance(_instance, enemy)
			enemy.temp_dist_to_attacker = loc4
			if loc4 <= search_radius * 2:
				if enemy.get_cur_battle == null:
					a_battles_enemy_single_melee.append(enemy)
				else:
					var loc5: Battle = enemy.get_cur_battle
					if loc5.is_defender(enemy):
						a_battles_enemy_defender_melee.append(enemy)
					else:
						a_battles_enemy_attacker_melee.append(enemy)

func search_target_enemy() -> void:
	var selected_single_enemy: LivingObject = null
	var search_for_armor: bool = false
	var is_attacking_archer: bool = false
	var dst_to_archer: float = NAN
	if cur_stanse != FIGHTING:
		search_counter += 1
		if search_counter >= GLOBAL_SEARCH_COUNTER:
			search_counter = 0
			is_attacking_archer = false
			if cur_target != null:
				if cur_target.is_archer == true:
					dst_to_archer = AS3.get_distance(_instance, cur_target)
					if dst_to_archer > search_radius:
						if RWRandom.rand() > 0.85:
							is_attacking_archer = true
			if cur_target == null or is_attacking_archer == true:
				a_battles_enemy_single_melee = []
				a_battles_enemy_defender_melee = []
				a_battles_enemy_attacker_melee = []
				a_ranged = []
				if in_field(_instance):
					var j: int = 0
					while j < LivingObject.a_friend_warriors.size():
						check_enemy(LivingObject.a_friend_warriors[j])
						j += 1
					if a_battles_enemy_single_melee.size() + a_battles_enemy_defender_melee.size() + a_battles_enemy_attacker_melee.size() == 0:
						var k: int = 0
						while k < LivingObject.a_friend_ranged.size():
							check_enemy(LivingObject.a_friend_ranged[k])
							k += 1
				var found: bool = false
				if a_battles_enemy_single_melee.size() != 0:
					search_for_armor = false
					if armor_piercing_melee >= 0.2:
						search_for_armor = true
					if RWRandom.rand() > 0.7:
						random_sort_array(a_battles_enemy_single_melee)
						selected_single_enemy = a_battles_enemy_single_melee[0]
					else:
						selected_single_enemy = select_enemy_from_array(a_battles_enemy_single_melee, search_for_armor, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(selected_single_enemy)
					set_pursue_counter(selected_single_enemy)
					found = true
				elif a_battles_enemy_attacker_melee.size() != 0:
					if RWRandom.rand() > 0.7:
						random_sort_array(a_battles_enemy_attacker_melee)
						selected_single_enemy = a_battles_enemy_attacker_melee[0]
					else:
						selected_single_enemy = select_enemy_from_array(a_battles_enemy_attacker_melee, search_for_armor, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(selected_single_enemy)
					set_pursue_counter(selected_single_enemy)
					found = true
				elif a_battles_enemy_defender_melee.size() != 0:
					# 原版此分支不置 found（保留）
					if RWRandom.rand() > 0.7:
						random_sort_array(a_battles_enemy_defender_melee)
						selected_single_enemy = a_battles_enemy_defender_melee[0]
					else:
						selected_single_enemy = select_enemy_from_array(a_battles_enemy_defender_melee, search_for_armor, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(selected_single_enemy)
					set_pursue_counter(selected_single_enemy)
				if found == false and is_attacking_archer == false:
					# 原版 checkEnemy 从不向 aRanged 添加，此分支实际不可达（保留）
					if a_ranged.size() > 0:
						if RWRandom.rand() > 0.7:
							random_sort_array(a_ranged)
							selected_single_enemy = a_ranged[0]
						else:
							selected_single_enemy = select_enemy_from_array(a_ranged, false, "", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(selected_single_enemy)
						set_pursue_counter(selected_single_enemy)

func set_pursue_counter(param1: LivingObject) -> void:
	var key: String = LivingObject.pursue_key(param1)
	if int(o_pursue_counter.get(key, 0)) == 0:
		o_pursue_counter[key] = 1

func select_enemy_from_array(param1: Array, param2: bool, param3: String, param4: String, param5: String, param6: String) -> LivingObject:
	if param2 == true:
		if param5 == NUMERIC_DESCENDING:
			sort_on(param1, param3, true)
		elif param5 == NUMERIC:
			sort_on(param1, param3, false)
	elif param6 == NUMERIC_DESCENDING:
		sort_on(param1, param4, true)
	elif param6 == NUMERIC:
		sort_on(param1, param4, false)
	return param1[0] as LivingObject

# 反编译破损，按 P-code 重建（仅 while(true)/if(false) 噪声，控制流经 P-code 核对与反编译一致）
# 结论：外层 while(true) 只执行一次；dist(自身, zeroPoint) > 110 时不选"单挑"堆（改选攻击方/防守方堆）。
func search_target_friendly() -> void:
	if cur_stanse != FIGHTING:
		if is_defence_stance or stand_still:
			return
		search_counter += 1
		if search_counter >= GLOBAL_SEARCH_COUNTER:
			search_counter = 0
			if cur_target == null:
				a_battles_enemy_single_melee = []
				a_battles_enemy_defender_melee = []
				a_battles_enemy_attacker_melee = []
				a_ranged = []
				var loc2: Array = GameUniverse.inst.get_all_enemies(friendly)
				if in_field(_instance):
					var loc6: int = 0
					while loc6 < loc2.size():
						var loc7: LivingObject = loc2[loc6]
						if loc7.in_hide == false:
							if in_field(loc7):
								var loc8: float = AS3.get_distance(_instance, loc7)
								loc7.temp_dist_to_attacker = loc8
								if loc8 <= search_radius * 2:
									if loc7.get_cur_battle == null:
										if loc7.is_kamikaze == false:
											a_battles_enemy_single_melee.append(loc7)
									if a_battles_enemy_single_melee.size() == 0:
										var loc9: Battle = loc7.get_cur_battle
										if loc9 != null:
											if loc9.is_defender(loc7):
												a_battles_enemy_defender_melee.append(loc7)
											else:
												a_battles_enemy_attacker_melee.append(loc7)
						loc6 += 1
				var loc3: bool = false
				var loc4: bool = false
				if armor_piercing_melee >= 0.2:
					loc4 = true
				var loc5: bool = false
				var loc10: LivingObject = null
				var dist_home: float = Vector2(position.x, position.y).distance_to(Vector2(zero_point))
				if dist_home > 110:
					loc5 = true
				if a_battles_enemy_single_melee.size() != 0:
					if loc5 == false:
						if RWRandom.rand() > 0.65:
							random_sort_array(a_battles_enemy_single_melee)
							loc10 = a_battles_enemy_single_melee[0]
						else:
							loc10 = select_enemy_from_array(a_battles_enemy_single_melee, loc4, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(loc10)
						loc3 = true
				if loc3 == false:
					if a_battles_enemy_attacker_melee.size() != 0:
						if RWRandom.rand() > 0.65:
							random_sort_array(a_battles_enemy_attacker_melee)
							loc10 = a_battles_enemy_attacker_melee[0]
						else:
							loc10 = select_enemy_from_array(a_battles_enemy_attacker_melee, loc4, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(loc10)
						loc3 = true
					elif a_battles_enemy_defender_melee.size() != 0:
						if RWRandom.rand() > 0.65:
							random_sort_array(a_battles_enemy_defender_melee)
							loc10 = a_battles_enemy_defender_melee[0]
						else:
							loc10 = select_enemy_from_array(a_battles_enemy_defender_melee, loc4, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(loc10)
