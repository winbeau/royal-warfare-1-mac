# 移植自 S/gameCore/living/meleeRogue.as
# 盗贼基类：优先选"弓手 / 远程"堆（a_ranged），其次单挑、攻击方、防守方。
# MAX_BATTLEPOINT_DISTANCE 在原版 meleeRogue 里与 meleeFighter 重复声明（同为 150），此处沿用基类常量。
# meleeRogue 自带的 private selectEnemyFromArray 与 meleeFighter 的逐行相同，直接沿用基类实现。
class_name MeleeRogue
extends MeleeFighter

var rogue_attack_to_def_counter: int = 0  # private

func _init() -> void:
	is_rogue = true

func on_play_head_action() -> void:
	if friendly:
		if RWRandom.rand() > 0.9:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_VOICE), false, 0, 0.45, position.x, SoundLibrary.SWORD_SWOOSH)
		else:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.6, position.x, SoundLibrary.SWORD_SWOOSH)
	else:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.6, position.x, SoundLibrary.SWORD_SWOOSH)

# 反编译破损，按 P-code 重建
# 结论：分类（对 friendly == !friendly、活着、不隐身、双方在场内的单位，距离恒 <= int.MAX_VALUE）：
#   getCurBattle == null：弓手进 aRanged，否则进"单挑"堆；
#   getCurBattle != null：防守者 -> 弓手进 aRanged、否则进"防守方"堆；非防守者 -> 非弓手进"攻击方"堆、弓手进 aRanged。
# 选择顺序：aRanged > 单挑 > 攻击方 > 防守方；每堆 rand > 0.7 时 randomSort 取 [0]，否则 selectEnemyFromArray。
# aRanged 的 selectEnemyFromArray 用 (false, "", 距离)；其余用 (armorPiercingMelee >= 0.2, curArmor, 距离)。
func search_target_enemy() -> void:
	var loc3: LivingObject = null
	if cur_stanse != FIGHTING:
		if in_hide and is_defence_stance:
			return
		search_counter += 1
		if search_counter >= GLOBAL_SEARCH_COUNTER:
			search_counter = 0
			if cur_target == null:
				a_battles_enemy_single_melee = []
				a_battles_enemy_defender_melee = []
				a_battles_enemy_attacker_melee = []
				a_ranged = []
				var loc1: Array = GameUniverse.inst.a_all_units.duplicate()
				var loc2: int = 0
				while loc2 < loc1.size():
					var loc5: LivingObject = loc1[loc2]
					if loc5.friendly == (not friendly) and loc5.cur_health > 0 and loc5.in_hide == false:
						if in_field(loc5) and in_field(_instance):
							var loc6: float = AS3.get_distance(_instance, loc5)
							loc5.temp_dist_to_attacker = loc6
							if loc6 <= 2147483647:
								var loc7: bool = false
								if loc5.get_cur_battle == null:
									if loc5.is_archer == true:
										loc7 = true
										a_ranged.append(loc5)
									else:
										loc7 = true
										a_battles_enemy_single_melee.append(loc5)
								if loc7 == false:
									var loc8: Battle = loc5.get_cur_battle
									if loc8 != null:
										if loc8.is_defender(loc5):
											if loc5.is_archer == true:
												a_ranged.append(loc5)
											else:
												a_battles_enemy_defender_melee.append(loc5)
										elif loc5.is_archer != true:
											a_battles_enemy_attacker_melee.append(loc5)
										else:
											a_ranged.append(loc5)
									else:
										a_ranged.append(loc5)
					loc2 += 1
				var loc4: bool = false
				if armor_piercing_melee >= 0.2:
					loc4 = true
				if a_ranged.size() > 0:
					if RWRandom.rand() > 0.7:
						random_sort_array(a_ranged)
						loc3 = a_ranged[0]
					else:
						loc3 = select_enemy_from_array(a_ranged, false, "", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(loc3)
				elif a_battles_enemy_single_melee.size() != 0:
					if RWRandom.rand() > 0.7:
						random_sort_array(a_battles_enemy_single_melee)
						loc3 = a_battles_enemy_single_melee[0]
					else:
						loc3 = select_enemy_from_array(a_battles_enemy_single_melee, loc4, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(loc3)
				elif a_battles_enemy_attacker_melee.size() != 0:
					if RWRandom.rand() > 0.7:
						random_sort_array(a_battles_enemy_attacker_melee)
						loc3 = a_battles_enemy_attacker_melee[0]
					else:
						loc3 = select_enemy_from_array(a_battles_enemy_attacker_melee, loc4, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(loc3)
				elif a_battles_enemy_defender_melee.size() != 0:
					if RWRandom.rand() > 0.7:
						random_sort_array(a_battles_enemy_defender_melee)
						loc3 = a_battles_enemy_defender_melee[0]
					else:
						loc3 = select_enemy_from_array(a_battles_enemy_defender_melee, loc4, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
					set_target(loc3)

# 反编译破损，按 P-code 重建
# 结论：反编译里的 continue / do-while 逗号表达式是噪声。对 getAllEnemies 中不隐身、在场内的单位记距离；
# 距离 <= searchRadius*2 时：getCurBattle == null -> 弓手进 aRanged，否则进"单挑"堆（该堆在选择时并不使用）；
# 有战斗 -> 防守者进"防守方"堆，否则进"攻击方"堆。选择顺序 aRanged > 攻击方 > 防守方（rand > 0.7 随机，否则 selectEnemyFromArray，
# aRanged 也带 armorPiercing 标志）。
func search_target_friendly() -> void:
	var loc4: LivingObject = null
	if cur_stanse != FIGHTING:
		if is_defence_stance or stand_still:
			return
		search_counter += 1
		if search_counter >= GLOBAL_SEARCH_COUNTER:
			search_counter = 0
			if cur_target == null:
				if in_field(_instance):
					a_battles_enemy_single_melee = []
					a_battles_enemy_defender_melee = []
					a_battles_enemy_attacker_melee = []
					a_ranged = []
					var loc2: Array = GameUniverse.inst.get_all_enemies(friendly)
					var loc3: int = 0
					while loc3 < loc2.size():
						var loc6: LivingObject = loc2[loc3]
						if loc6.in_hide == false:
							if in_field(loc6):
								var loc7: float = AS3.get_distance(_instance, loc6)
								loc6.temp_dist_to_attacker = loc7
								if loc7 <= search_radius * 2:
									if loc6.get_cur_battle == null:
										if loc6.is_archer == true:
											a_ranged.append(loc6)
										else:
											a_battles_enemy_single_melee.append(loc6)
									else:
										var loc8: Battle = loc6.get_cur_battle
										if loc8 != null:
											if loc8.is_defender(loc6):
												a_battles_enemy_defender_melee.append(loc6)
											else:
												a_battles_enemy_attacker_melee.append(loc6)
						loc3 += 1
					var loc5: bool = false
					if armor_piercing_melee >= 0.2:
						loc5 = true
					if a_ranged.size() != 0:
						if RWRandom.rand() > 0.7:
							random_sort_array(a_ranged)
							loc4 = a_ranged[0]
						else:
							loc4 = select_enemy_from_array(a_ranged, loc5, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(loc4)
					elif a_battles_enemy_attacker_melee.size() != 0:
						if RWRandom.rand() > 0.7:
							random_sort_array(a_battles_enemy_attacker_melee)
							loc4 = a_battles_enemy_attacker_melee[0]
						else:
							loc4 = select_enemy_from_array(a_battles_enemy_attacker_melee, loc5, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(loc4)
					elif a_battles_enemy_defender_melee.size() != 0:
						if RWRandom.rand() > 0.7:
							random_sort_array(a_battles_enemy_defender_melee)
							loc4 = a_battles_enemy_defender_melee[0]
						else:
							loc4 = select_enemy_from_array(a_battles_enemy_defender_melee, loc5, "cur_armor", "temp_dist_to_attacker", NUMERIC_DESCENDING, NUMERIC)
						set_target(loc4)

func set_defence_stance_when_stay() -> bool:
	if is_defence_stance == true:
		return true
	return false

func before_updating_active_unit() -> void:
	if is_defence_stance == false:
		if in_hide == true:
			if cur_stanse == STAND:
				rogue_attack_to_def_counter += 1
				if rogue_attack_to_def_counter > 6 * 30:
					is_defence_stance = true
		else:
			rogue_attack_to_def_counter = 0

func uncover_hidden_rogue() -> void:
	var loc1: SpecHide = special_zero as SpecHide
	loc1.disable_hide()

func special_before_damaging_enemy_handler() -> void:
	if special_zero != null:
		var loc1: SpecHide = special_zero as SpecHide
		loc1.disable_hide()
