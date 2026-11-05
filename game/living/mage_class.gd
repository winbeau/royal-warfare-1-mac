# 移植自 S/gameCore/living/mageClass.as
# 法师基类：searchTarget 分两堆（kamikaze / 护盾 kamikaze / 幽灵 为优先堆）；throwRanged 与弓手相同的预判瞄准，发射 smallFireball_ex。
class_name MageClass
extends LivingObject

var cur_spell: int = -1

func _init() -> void:
	is_archer = true
	is_mage = true

func set_casting_stance() -> void:
	attacking_with_ranged_weapon = true
	battle_point = Vector2(position.x, position.y)
	if cur_target == null:
		cur_target = _instance
	set_stance_after_upgrade(CASTING)
	play_head_start_play()

func get_ranged_shoot_sound() -> void:
	pass

func on_play_head_stopped() -> void:
	if current_bm == bmp_casting:
		if cur_target == _instance:
			cur_target = null
		set_stance_after_upgrade(STAND)
		search_counter = 0
		attack_counter = 0

# 反编译破损，按 P-code 重建
# 结论：反编译里的 while(true){}、§§goto(addr0349)、continue 都是噪声；循环体是普通 for：满足
# friendly == !friendly && curHealth > 0 && !inHide && inField(目标) && inField(自身) 的单位记距离，
# 距离 <= searchRadius*mod-0.5 后置 flag（此后的单位才可入堆）；<= searchRadius*mod 且 flag 时，kamikaze / 护盾 kamikaze / 幽灵进第二堆，其余进第一堆。
# 第二堆非空：按距离升序取 [0]。否则第一堆：按距离升序取 [0]；若其距离 > searchRadius 且其目标不是弓手
# （原版写成 while，实为 if）：rand <= 0.7 则 randomSort 取 [0]，否则按 curArmor 降序取 [0]。
func search_target(param1: bool = false) -> void:
	search_counter += 1
	if search_counter >= GLOBAL_SEARCH_COUNTER:
		var loc2: bool = false
		if param1 == true:
			loc2 = true
		elif is_defence_stance == true:
			if cur_stanse == STAND:
				loc2 = true
		elif cur_stanse != RANGED_SHOOT and cur_stanse != FIGHTING and cur_stanse != CASTING:
			loc2 = true
		search_counter = 0
		if loc2 == false:
			return
		if cur_target == null:
			var loc3: Array = []
			var loc4: Array = []
			var loc5: bool = false
			var loc6: Array = GameUniverse.inst.a_all_units.duplicate()
			var loc7: int = 0
			while loc7 < loc6.size():
				var loc8: LivingObject = loc6[loc7]
				if loc8.friendly == (not friendly) and loc8.cur_health > 0 and loc8.in_hide == false:
					if in_field(loc8) and in_field(_instance):
						var loc9: float = AS3.get_distance(_instance, loc8)
						loc8.temp_dist_to_attacker = loc9
						if loc9 <= search_radius * search_radius_ranged_modifier - 0.5:
							loc5 = true
						if loc9 <= search_radius * search_radius_ranged_modifier and loc5 == true:
							if loc8.get_kind == LivingObject.MONSTER_KAMIKAZE or loc8.get_kind == LivingObject.MONSTER_KAMI_SHIELD or loc8.get_kind == LivingObject.UNDEAD_GHOST:
								loc4.append(loc8)
							else:
								loc3.append(loc8)
				loc7 += 1
			var loc10: LivingObject = null
			if loc4.size() > 0:
				MeleeFighter.sort_on(loc4, "temp_dist_to_attacker")
				loc10 = loc4[0] as LivingObject
				attacking_with_ranged_weapon = true
				set_target(loc10)
			elif loc3.size() > 0:
				MeleeFighter.sort_on(loc3, "temp_dist_to_attacker")
				loc10 = loc3[0] as LivingObject
				var loc11: bool = false
				if loc10.get_cur_target != null:
					if loc10.get_cur_target.is_archer == true:
						loc11 = true
				if loc10.temp_dist_to_attacker > search_radius and loc11 == false:
					if RWRandom.rand() <= 0.7:
						MeleeFighter.random_sort_array(loc3)
						loc10 = loc3[0] as LivingObject
					else:
						MeleeFighter.sort_on(loc3, "cur_armor", true)
						loc10 = loc3[0] as LivingObject
				attacking_with_ranged_weapon = true
				set_target(loc10)

# 预判瞄准同弓手，但火球速度 600：dist/600*30 帧；发射点 (x + 12*sprite.scaleX, y - sens.height - 4)；目标点再上移 5。
func throw_ranged(_e: Variant = null) -> void:
	if cur_target != null:
		if cur_target.cur_health > 0:
			var loc2: float = 12 * sprite.scale.x
			var loc3: Vector2 = Vector2(position.x + loc2, position.y - sens_height - 4)
			var loc4: Vector2
			if cur_target.get_stance == WALKING:
				var loc7: Vector2 = Vector2(cur_target.position.x, cur_target.position.y)
				var loc8: float = loc3.distance_to(loc7)
				var loc9: float = loc8 / 600.0
				var loc10: float = loc9 * 30.0
				var loc11: Vector2 = cur_target.get_cur_destination()
				var loc12: float = loc7.distance_to(loc11)
				var loc13: float = cur_target.get_walk_speed
				var loc14: float = loc13 * loc10
				var loc15: float = 1.0 - loc14 / loc12
				if not (loc15 >= 0.0):
					loc15 = 0.0
				loc4 = AS3.point_interpolate(loc7, loc11, loc15)
			else:
				loc4 = Vector2(cur_target.position.x, cur_target.position.y - 3)
			loc4.y -= 5
			var loc6: bool = false
			if RWRandom.rand() <= shoot_accuracy:
				loc6 = true
			if loc6 == false:
				var nx: float = loc4.x - 15 + 30 * RWRandom.rand()
				var ny: float = loc4.y - 15 + 30 * RWRandom.rand()
				loc4 = Vector2(nx, ny)
			var loc5: SmallFireballEx = SmallFireballEx.cached_data.get_data() as SmallFireballEx
			GameUniverse.inst.add_small_fireball(loc5)
			loc5.init(cur_target, loc3, loc4, missile_hit_handler, loc6)
			get_ranged_shoot_sound()
		else:
			set_target(null)
			search_counter = 100
			search_target()
			if cur_target != null:
				throw_ranged(null)
	else:
		search_counter = 100
		search_target(true)
		if cur_target != null:
			throw_ranged(null)

func on_play_head_action() -> void:
	if friendly:
		if RWRandom.rand() > 0.9:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_VOICE), false, 0, 0.6, position.x, SoundLibrary.HEAVY_SWORD)
		else:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.HEAVY_SWORD), false, 0, 0.6, position.x, SoundLibrary.HEAVY_SWORD)
	else:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.HEAVY_SWORD), false, 0, 0.6, position.x, SoundLibrary.HEAVY_SWORD)

func missile_hit_handler(param1: LivingObject) -> void:
	if param1 != null:
		if param1.cur_health <= 0:
			search_counter = 100
		else:
			before_damaging_enemy(param1)
			var loc2: float = param1.cur_magic_resist
			var loc3: float = loc2 - magic_piercing
			if loc3 < 0:
				loc3 = 0
			var loc4: int = int(cur_ranged_damage * (1 - loc3))
			got_experience(1)
			param1.bring_damage(loc4, _instance)

func before_damaging_enemy(_param1: LivingObject) -> void:
	pass
