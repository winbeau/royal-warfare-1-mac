# 移植自 S/gameCore/living/priestClass.as
# 牧师基类：索敌周期固定 30（不用 GLOBAL_SEARCH_COUNTER）；目标选自半径 searchRadius*searchRadiusRangedModifier 内的受伤友军，
# 按 curHealth 升序取最伤者（sprioritizedHealingTarget 优先）；复活者另收集 aWaitingDeath 中己方、半径 searchRadius*3 内的尸体。
class_name PriestClass
extends LivingObject

var last_target: LivingObject = null
var is_resurrecter: bool = false
var a_friends: Array = []
var a_dead_units: Array = []

func _init() -> void:
	is_archer = true
	is_priest = true
	is_resurrecter = false
	search_radius_ranged_modifier = 2.1

func set_casting_stance() -> void:
	attacking_with_ranged_weapon = true
	set_battle(null)
	battle_point = Vector2(position.x, position.y)
	cur_target = _instance
	set_stance_after_upgrade(CASTING)
	play_head_start_play()

func on_play_head_action() -> void:
	if friendly:
		if RWRandom.rand() > 0.9:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_VOICE), false, 0, 0.5, position.x, SoundLibrary.SWORD_SWOOSH)
		else:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.6, position.x, SoundLibrary.SWORD_SWOOSH)
	else:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.6, position.x, SoundLibrary.SWORD_SWOOSH)

# 反编译破损，按 P-code 重建
# 结论：反编译中的 if(false){§§goto} 是死代码。canUseSpecial == false 时：
#   sprioritizedHealingTarget 非空：已死或满血则清空（本轮不再选别人）；否则 RANGED_SHOOT 阶段只改 curTarget，其余阶段 setTarget；
#   为空且 aFriends 非空：按 curHealth 升序取 [0]，attackingWithRangedWeapon = true、setBattle(null)，同样区分 RANGED_SHOOT；
#   之后（无论走哪条）curTarget 非空则 lastTarget = curTarget。canUseSpecial == true 时直接返回（lastTarget 不更新）。
func search_target(param1: bool = false) -> void:
	var external: bool = param1  # 原版仅赋值，未使用
	search_counter += 1
	if search_counter >= 30:
		search_counter = 0
		if cur_stanse == STAND or (is_defence_stance == false and cur_stanse == WALKING):
			a_friends = []
			var my_coords: Vector2 = Vector2(_x, _y)
			var close_flag: bool = false
			var a_warriors: Array = GameUniverse.inst.get_all_friends_in_area(my_coords, friendly, search_radius * search_radius_ranged_modifier)
			var a_du: Array = GameUniverse.inst.a_waiting_death.duplicate()
			a_dead_units = []
			if is_resurrecter == true:
				var j: int = 0
				while j < a_du.size():
					var dead_unit: LivingObject = a_du[j]
					if dead_unit.real_friendly == friendly:
						var dist: float = my_coords.distance_to(Vector2(dead_unit._x, dead_unit._y))
						if dist <= search_radius * 3:
							a_dead_units.append(dead_unit)
					j += 1
			var i: int = 0
			while i < a_warriors.size():
				var warrior: LivingObject = a_warriors[i]
				if warrior.cur_health < warrior.health:
					a_friends.append(warrior)
				i += 1
			var can_use_special: bool = false
			can_use_special = check_abilities_priest_class()
			if can_use_special == false:
				if sprioritized_healing_target != null:
					if sprioritized_healing_target.cur_health <= 0 or sprioritized_healing_target.cur_health >= sprioritized_healing_target.health:
						sprioritized_healing_target = null
					elif cur_stanse != RANGED_SHOOT:
						set_target(sprioritized_healing_target)
					else:
						cur_target = sprioritized_healing_target
				elif a_friends.size() > 0:
					# compare: curHealth 差（升序）。Flash 的排序对平局的次序未公开，这里用稳定排序。
					MeleeFighter.sort_on(a_friends, "cur_health")
					var selected_friend: LivingObject = a_friends[0] as LivingObject
					attacking_with_ranged_weapon = true
					set_battle(null)
					if cur_stanse != RANGED_SHOOT:
						set_target(selected_friend)
					else:
						cur_target = selected_friend
				if cur_target != null:
					last_target = cur_target

func check_abilities_priest_class() -> bool:
	return false

func throw_ranged(_e: Variant = null) -> void:
	if cur_target != null:
		if cur_target.cur_health > 0:
			var loc2: int = -1 * cur_ranged_damage
			got_experience(1)
			cur_target.bring_damage(loc2, _instance)
			cur_target.healed_effect()
		else:
			set_target(null)

func start_ranged_attack() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.HEAL_CAST), false, 0, 0.2, position.x, SoundLibrary.HEAL_CAST)

func on_play_head_stopped() -> void:
	if current_bm == bmp_ranged or current_bm == bmp_casting:
		if sprioritized_healing_target != null:
			if sprioritized_healing_target != cur_target:
				cur_target = null
		else:
			cur_target = null
		set_stance_after_upgrade(STAND)
