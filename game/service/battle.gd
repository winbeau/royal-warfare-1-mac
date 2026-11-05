# 移植自 S/gameCore/serviceUtils/battle.as
# 一个防守者 + 最多 6 个近战攻击槽（lm/lt/ld/rm/rt/rd）+ 等待队列，无单位推挤。
class_name Battle
extends RefCounted

var _instance: Battle
var a_melee_attackers: Array = []  # Array[LivingObject]
var p_battle_point: Vector2 = Vector2.ZERO
var defender: LivingObject
var lt: LivingObject = null
var lm: LivingObject = null
var ld: LivingObject = null
var rt: LivingObject = null
var rm: LivingObject = null
var rd: LivingObject = null
var v_distant_attackers: Array = []  # Array[LivingObject]

# 反编译破损，按 P-code 重建
# 重建结论：battlePoint 先设为防守者位置；对附近每个已有战斗点，p7 从 p4 起沿远离该点的方向
# 以 Point.interpolate(p6, p7, -0.11) 迭代，距离 >= 60 或迭代超过 15 次即停；
# lFound(原 _loc11_) 一旦为 true 就不再复位，所以只有第一个战斗点会产生候选（原版如此，照旧）。
func init(param1: LivingObject, param2: LivingObject) -> void:
	_instance = self
	a_melee_attackers = []
	v_distant_attackers = []
	defender = param2
	defender.set_battle(_instance)
	defender.set_target(param1)
	if defender.attacking_with_ranged_weapon == true:
		defender.set_battle_stance(1)
		defender.attacking_with_ranged_weapon = false
	defender.is_defence_stance = false
	var p4 := Vector2(defender.position.x, defender.position.y)
	defender.battle_point = p4
	var p5: Array = GameUniverse.inst.get_all_battle_points_in_area(p4, 60, defender)
	var p9: Array = []
	var p10: float = 30 * 2
	var p11 := false
	if p5.size() > 0:
		var i := 0
		while i < p5.size():
			var p6: Vector2 = p5[i]
			var p7: Vector2 = p4
			var p3 := 0
			while p11 == false:
				p3 += 1
				p7 = AS3.point_interpolate(p6, p7, -0.11)
				var p8: float = p6.distance_to(p7)
				if p8 >= p10 or p3 > 15:
					p11 = true
					p9.append(p7)
			i += 1
		if p9.size() > 1:
			var sum := Vector2(0, 0)
			var j := 0
			while j < p9.size():
				sum.x += p9[j].x
				sum.y += p9[j].y
				j += 1
			sum.x /= p9.size()
			sum.y /= p9.size()
			defender.battle_point = sum
		else:
			defender.battle_point = p9[0]
	if defender.is_point_obstacle(defender.battle_point) == true:
		defender.battle_point = p4
	var bp: Vector2 = defender.battle_point
	if bp.x < 35:
		bp.x = 35
	if bp.x > 665:
		bp.x = 665
	if bp.y < 35:
		bp.y = 35
	if bp.y > 580:
		bp.y = 580
	defender.battle_point = bp
	add_melee_attacker(param1)

func check_enemy_existence() -> void:
	if defender != null:
		if defender.cur_health <= 0:
			defender.nullify_target()
			while a_melee_attackers.size() > 0:
				var atk: LivingObject = a_melee_attackers[0]
				if atk.get_cur_battle == _instance:
					atk.set_battle(null)
				if atk.get_cur_target == defender:
					atk.nullify_target()
				a_melee_attackers.remove_at(0)
			defender = null
			v_distant_attackers = []
			GameUniverse.inst.remove_battle(_instance)
			return
		if a_melee_attackers.size() > 0:
			var dead: Array = []
			var k := 0
			while k < a_melee_attackers.size():
				var m: LivingObject = a_melee_attackers[k]
				if m.cur_health <= 0:
					dead.append(m)
				k += 1
			if dead.size() > 0:
				while dead.size() > 0:
					var idx := a_melee_attackers.find(dead[0])
					_splice_remove(a_melee_attackers, idx)
					idx = v_distant_attackers.find(dead[0])
					if idx >= 0:
						v_distant_attackers.remove_at(idx)
					dead.remove_at(0)
		if a_melee_attackers.size() > 0:
			var idx2 := a_melee_attackers.find(defender.get_cur_target)
			if idx2 < 0:
				var pos := Vector2(defender.position.x, defender.position.y)
				var n := 0
				while n < a_melee_attackers.size():
					var a: LivingObject = a_melee_attackers[n]
					a.temp_dist_to_attacker = pos.distance_to(Vector2(a.position.x, a.position.y))
					n += 1
				# sortOn("tempDistToAttacker", Array.NUMERIC)；排序结果在距离相等时次序原版未定义
				a_melee_attackers.sort_custom(func(x: LivingObject, y: LivingObject) -> bool: return x.temp_dist_to_attacker < y.temp_dist_to_attacker)
				defender.set_target(a_melee_attackers[0])
		else:
			v_distant_attackers = []
			defender.set_battle(null, _instance)
			GameUniverse.inst.remove_battle(_instance)
	else:
		while a_melee_attackers.size() > 0:
			var atk2: LivingObject = a_melee_attackers[0]
			atk2.set_battle(null, _instance)
			a_melee_attackers.remove_at(0)
		v_distant_attackers = []
		GameUniverse.inst.remove_battle(_instance)

## AS3 splice(idx, 1)：idx 为 -1 时删除最后一个元素（原版 indexOf 未命中时的行为，照旧）。
static func _splice_remove(arr: Array, idx: int) -> void:
	if idx < 0:
		idx = arr.size() + idx
	if idx >= 0 and idx < arr.size():
		arr.remove_at(idx)

# 反编译破损（while(true) 包裹），按 P-code 重建：条件顺序 healthy > 0、defender 非空、攻击者少于 6 个。
func add_melee_attacker(param1: LivingObject) -> void:
	if param1 != null:
		if param1.cur_health > 0:
			if defender != null:
				if a_melee_attackers.size() < 6:
					param1.set_battle(_instance)
					param1.set_target(defender)
					param1.attacking_with_ranged_weapon = false
					var idx := v_distant_attackers.find(param1)
					if idx < 0:
						v_distant_attackers.append(param1)
					idx = a_melee_attackers.find(param1)
					if idx >= 0:
						return
					a_melee_attackers.append(param1)
					if a_melee_attackers.size() == 1:
						p_battle_point = defender.battle_point
						defender.set_battle_destination(p_battle_point)
						if param1.position.x < defender.position.x:
							lm = param1
							param1.set_battle_destination(Vector2(p_battle_point.x - 30, p_battle_point.y))
						else:
							rm = param1
							param1.set_battle_destination(Vector2(p_battle_point.x + 30, p_battle_point.y))
					elif lm != null:
						if lt == null:
							lt = param1
							param1.set_battle_destination(Vector2(p_battle_point.x - 26, p_battle_point.y - 8))
						elif ld == null:
							ld = param1
							param1.set_battle_destination(Vector2(p_battle_point.x - 26, p_battle_point.y + 8))
						elif rm == null:
							rm = param1
							param1.set_battle_destination(Vector2(p_battle_point.x + 30, p_battle_point.y))
						elif rt == null:
							rt = param1
							param1.set_battle_destination(Vector2(p_battle_point.x + 26, p_battle_point.y + 8))
						elif rd == null:
							rd = param1
							param1.set_battle_destination(Vector2(p_battle_point.x + 26, p_battle_point.y - 8))
					elif rt == null:
						rt = param1
						param1.set_battle_destination(Vector2(p_battle_point.x + 26, p_battle_point.y + 8))
					elif rd == null:
						rd = param1
						param1.set_battle_destination(Vector2(p_battle_point.x + 26, p_battle_point.y - 8))
					elif lt == null:
						lt = param1
						param1.set_battle_destination(Vector2(p_battle_point.x - 26, p_battle_point.y - 8))
					elif lm == null:
						lm = param1
						param1.set_battle_destination(Vector2(p_battle_point.x - 30, p_battle_point.y))
					elif ld == null:
						ld = param1
						param1.set_battle_destination(Vector2(p_battle_point.x - 26, p_battle_point.y + 8))

func is_defender(param1: LivingObject) -> bool:
	if param1 == defender:
		return true
	return false

func set_unit_dead(param1: LivingObject) -> void:
	if param1 == defender:
		defender = null
		check_enemy_existence()
	else:
		remove_from_battle(param1)

func unit_after_upgrade(param1: LivingObject, param2: LivingObject) -> void:
	if defender == param2:
		defender = param1
	else:
		var idx := a_melee_attackers.find(param2)
		if idx >= 0:
			a_melee_attackers[idx] = param1
		idx = v_distant_attackers.find(param2)
		if idx >= 0:
			v_distant_attackers[idx] = param1
		if lm == param2:
			lm = param1
		if rm == param2:
			rm = param1
		if lt == param2:
			lt = param1
		if ld == param2:
			ld = param1
		if rt == param2:
			rt = param1
		if rd == param2:
			rd = param1
	param1.set_battle_destination(param2.battle_point)

func switch_defender_and_attacker() -> void:
	if get_num_attackers == 1:
		var l1: LivingObject = a_melee_attackers[0]
		var l2: LivingObject = defender
		v_distant_attackers = []
		v_distant_attackers.append(l2)
		a_melee_attackers.append(l2)
		defender = l1
		a_melee_attackers.remove_at(0)
		# 以下六个 if 按原顺序依次执行（左右槽互换），不改成 elif
		if lm == l1:
			rm = l2
			lm = null
		if rm == l1:
			lm = l2
			rm = null
		if lt == l1:
			rt = l2
			lt = null
		if ld == l1:
			rd = l2
			ld = null
		if rt == l1:
			lt = l2
			rt = null
		if rd == l1:
			ld = l2
			rd = null
		p_battle_point = defender.battle_point
		defender.set_battle_destination(p_battle_point)
		if defender.get_stance != LivingObject.FIGHTING:
			defender.set_battle_stance(1)
		update_defender_coordinates()

func update_defender_coordinates() -> void:
	if lm != null:
		lm.set_battle_destination(Vector2(p_battle_point.x - 30, p_battle_point.y))
	if rm != null:
		rm.set_battle_destination(Vector2(p_battle_point.x + 30, p_battle_point.y))
	if lt != null:
		lt.set_battle_destination(Vector2(p_battle_point.x - 26, p_battle_point.y - 8))
	if ld != null:
		ld.set_battle_destination(Vector2(p_battle_point.x - 26, p_battle_point.y + 8))
	if rt != null:
		rt.set_battle_destination(Vector2(p_battle_point.x + 26, p_battle_point.y + 8))
	if rd != null:
		rd.set_battle_destination(Vector2(p_battle_point.x + 26, p_battle_point.y - 8))

func remove_from_battle(param1: LivingObject) -> void:
	if param1 != null:
		param1.set_battle(null)
		if param1 == lt:
			lt = null
		if param1 == lm:
			lm = null
		if param1 == ld:
			ld = null
		if param1 == rt:
			rt = null
		if param1 == rd:
			rd = null
		if param1 == rm:
			rm = null
		var idx := a_melee_attackers.find(param1)
		if idx >= 0:
			a_melee_attackers.remove_at(idx)
		idx = v_distant_attackers.find(param1)
		if idx >= 0:
			v_distant_attackers.remove_at(idx)
		if param1 == defender:
			defender = null
		check_enemy_existence()

func is_distant_attacker(param1: LivingObject) -> bool:
	if v_distant_attackers.find(param1) < 0:
		return false
	return true

func remove_distant_attacker(param1: LivingObject) -> void:
	var idx := v_distant_attackers.find(param1)
	if idx >= 0:
		v_distant_attackers.remove_at(idx)

func add_distant_attacker(param1: LivingObject) -> void:
	var idx := v_distant_attackers.find(param1)
	if idx < 0:
		if is_defender(param1) == false:
			v_distant_attackers.append(param1)

func clear_all_distant_attackers() -> void:
	v_distant_attackers = []

var get_num_distant_walkers: int:
	get:
		return v_distant_attackers.size()

var get_num_attackers: int:
	get:
		return a_melee_attackers.size()
