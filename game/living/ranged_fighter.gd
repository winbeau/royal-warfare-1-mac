# 移植自 S/gameCore/living/rangedFighter.as
# 远程兵种基类：searchTarget 把可见敌人分成 kamikaze / 弓手 / 其他 三堆；throwRanged 做预判瞄准并发射 arrow_ex。
# sens.height 对应 sens_height（LivingObject 中由 data/bounds.json 给出）。
class_name RangedFighter
extends LivingObject

var is_cross_bow_man: bool = false

func _init() -> void:
	is_archer = true

# 反编译破损，按 P-code 重建
# 结论：循环尾部的 while(true){ i++; if(false) continue; break; } 即普通 i++；末尾的 §§goto(addr0287) 与 if(false) 是死代码。
# 第三堆：先 sortOn(tempDistToAttacker)，取 [0]；若其 tempDistToAttacker > searchRadius 且它的目标不是弓手，
# 则按 armorPiercingMelee > 0 ? (rand > 0.5 ? 按 curArmor 降序 : 按距离升序) : (rand > 0.5 ? randomSort : 按距离升序) 重排；
# 最后 attackingWithRangedWeapon = true; setTarget(第三堆[0])。
func search_target(param1: bool = false) -> void:
	search_counter += 1
	if search_counter >= GLOBAL_SEARCH_COUNTER:
		var loc2: bool = false
		if param1 == true:
			loc2 = true
		elif is_defence_stance == true:
			if cur_stanse == STAND:
				loc2 = true
		elif cur_stanse != RANGED_SHOOT and cur_stanse != FIGHTING:
			loc2 = true
		search_counter = 0
		if loc2 == false:
			return
		if cur_target == null:
			var loc3: Array = []
			var loc4: Array = []
			var loc5: Array = []
			var loc6: bool = false
			var loc7: Array = GameUniverse.inst.a_all_units.duplicate()
			var loc8: int = 0
			while loc8 < loc7.size():
				var loc9: LivingObject = loc7[loc8]
				if loc9.friendly == (not friendly) and loc9.cur_health > 0 and loc9.in_hide == false:
					if in_field(loc9) and in_field(_instance):
						var loc10: float = AS3.get_distance(_instance, loc9)
						loc9.temp_dist_to_attacker = loc10
						if loc10 <= search_radius * search_radius_ranged_modifier - 0.5:
							loc6 = true
						if loc10 <= search_radius * search_radius_ranged_modifier and loc6 == true:
							if loc9.get_kind == LivingObject.MONSTER_KAMIKAZE or loc9.get_kind == LivingObject.MONSTER_KAMI_SHIELD:
								loc5.append(loc9)
							elif loc9.is_archer == true:
								loc4.append(loc9)
							else:
								loc3.append(loc9)
				loc8 += 1
			if loc5.size() > 0:
				if RWRandom.rand() > 0.3:
					MeleeFighter.random_sort_array(loc5)
				else:
					MeleeFighter.sort_on(loc5, "cur_health")
				attacking_with_ranged_weapon = true
				set_target(loc5[0] as LivingObject)
			elif loc4.size() > 0:
				if RWRandom.rand() > 0.3:
					MeleeFighter.random_sort_array(loc4)
				else:
					MeleeFighter.sort_on(loc4, "cur_health")
				attacking_with_ranged_weapon = true
				set_target(loc4[0] as LivingObject)
			elif loc3.size() > 0:
				MeleeFighter.sort_on(loc3, "temp_dist_to_attacker")
				var loc11: LivingObject = loc3[0] as LivingObject
				var loc12: bool = false
				if loc11.get_cur_target != null:
					if loc11.get_cur_target.is_archer == true:
						loc12 = true
				if loc11.temp_dist_to_attacker > search_radius and loc12 == false:
					if armor_piercing_melee > 0:
						if RWRandom.rand() > 0.5:
							MeleeFighter.sort_on(loc3, "cur_armor", true)
						else:
							MeleeFighter.sort_on(loc3, "temp_dist_to_attacker")
					elif RWRandom.rand() > 0.5:
						MeleeFighter.random_sort_array(loc3)
					else:
						MeleeFighter.sort_on(loc3, "temp_dist_to_attacker")
				attacking_with_ranged_weapon = true
				set_target(loc3[0] as LivingObject)

# 预判瞄准：飞行时间 dist/400 秒，折算 *30 帧，乘以目标移动速度，沿目标 get_cur_destination() 方向取点。
func throw_ranged(_e: Variant = null) -> void:
	if cur_target != null:
		if cur_target.cur_health > 0:
			var loc2: Vector2 = Vector2(position.x, position.y - sens_height / 2)
			var loc3: Vector2
			if cur_target.get_stance == WALKING:
				var loc6: Vector2 = Vector2(cur_target.position.x, cur_target.position.y)
				var loc7: float = loc2.distance_to(loc6)
				var loc8: float = loc7 / 400.0
				var loc9: float = loc8 * 30.0
				var loc10: Vector2 = cur_target.get_cur_destination()
				var loc11: float = loc6.distance_to(loc10)
				var loc12: float = cur_target.get_walk_speed
				var loc13: float = loc12 * loc9
				var loc14: float = 1.0 - loc13 / loc11  # loc11 为 0 时得 NaN/-inf，与 AS3 一样落入下面的 clamp
				if not (loc14 >= 0.0):
					loc14 = 0.0
				loc3 = AS3.point_interpolate(loc6, loc10, loc14)
			else:
				loc3 = Vector2(cur_target.position.x, cur_target.position.y - 3)
			var loc5: bool = false
			if RWRandom.rand() <= shoot_accuracy:
				loc5 = true
			if loc5 == false:
				# 参数求值顺序与 new Point(x - 15 + 30*rand, y - 15 + 30*rand) 相同：先 x 后 y
				var nx: float = loc3.x - 15 + 30 * RWRandom.rand()
				var ny: float = loc3.y - 15 + 30 * RWRandom.rand()
				loc3 = Vector2(nx, ny)
			var loc4: ArrowEx = ArrowEx.cached_data.get_data() as ArrowEx
			GameUniverse.inst.add_arrow(loc4)
			loc4.init(cur_target, loc2, loc3, missile_hit_handler, loc5, is_cross_bow_man)
			get_ranged_shoot_sound()
		else:
			set_target(null)
			search_counter = 100
			search_target(true)
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
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.MAN_VOICE), false, 0, 0.5, position.x, SoundLibrary.SWORD_SWOOSH)
		elif RWRandom.rand() > 0.5:
			Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.6, position.x, SoundLibrary.SWORD_SWOOSH)
	elif RWRandom.rand() > 0.5:
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.SWORD_SWOOSH), false, 0, 0.6, position.x, SoundLibrary.SWORD_SWOOSH)

func start_ranged_attack() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.ARCHER_PULL), false, 0, 0.16, position.x, SoundLibrary.ARCHER_PULL)

func get_ranged_shoot_sound() -> void:
	Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.ARCHER_SHOOT), false, 0, 0.45, position.x, SoundLibrary.ARCHER_SHOOT)

func special_missile_hit_target(_param1: LivingObject) -> void:
	pass

func missile_hit_handler(_param1: ArrowEx = null, param2: LivingObject = null) -> void:
	if param2 != null:
		special_missile_hit_target(param2)
		Sounds.inst.play(s.get_sound_from_stack(SoundLibrary.ARROW_IMPACT), false, 0, 0.28, position.x, SoundLibrary.ARROW_IMPACT)
		if param2.cur_health > 0:
			var loc3: float = param2.cur_armor
			var loc4: float = loc3 - armor_piercing_ranged
			if loc4 < 0:
				loc4 = 0
			var loc5: int = int(cur_ranged_damage * (1 - loc4))
			got_experience(1)
			param2.bring_damage(loc5, _instance)
		else:
			search_counter = 100
