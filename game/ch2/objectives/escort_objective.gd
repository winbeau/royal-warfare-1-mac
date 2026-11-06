## 护送目标：count 名 NPC 沿 path 锚点依次前进（作为一个编队，整体以最慢的成员为准推进锚点）。
## 前方 60 px 内有敌人就原地停住，清除后继续。生命归零时经 Ch2EscortNpc 转入倒地而不是死亡：
## downed_window_s 秒内任一玩家可控单位在 30 px 内连续停留 2 秒即可救起（恢复 30% 血量）；
## 超时则真正死亡。存活（含倒地）人数低于 min 时目标失败。到达各锚点时发出 "<id>.at_<idx>" 事件
## （idx 为 path 下标，0 为起点，不单独发事件），到达终点（含最低存活数）视为完成。
##
## JSON 字段：{id, type:"escort", optional, count, min, path:[[x,y],...], downed_window_s, kind(可选，
## 默认按 1/3/1 概率在 NPC_OLDMAN/NPC_MAN/NPC_WOMAN 间抽取，和 level_3.gd 的civilian抽取规则一致)}
class_name Ch2EscortObjective
extends Ch2ObjectiveBase

const ARRIVE_RADIUS := 16.0
const NEAR_ENEMY_RADIUS := 60.0
const RESCUE_RADIUS := 30.0
const RESCUE_HOLD_FRAMES := 60  # 2 秒 @30fps

var path: Array = []  # Array[Vector2]
var min_survivors: int = 1
var downed_window_frames: int = 600  # 20s 默认
var members: Array = []  # Array[Ch2EscortNpc]
var _group_index: int = 0  # 已到达的锚点下标（成员目标即 path[_group_index + 1]）
var _downed_timer: Dictionary = {}  # npc -> 剩余帧数
var _rescue_hold: Dictionary = {}  # npc -> 已连续停留帧数


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	super(data, p_director)
	for pt: Array in data.get("path", []):
		path.append(Vector2(float(pt[0]), float(pt[1])))
	min_survivors = int(data.get("min", 1))
	downed_window_frames = int(round(float(data.get("downed_window_s", 20.0)) * 30.0))
	var count: int = int(data.get("count", 1))
	for _i in count:
		members.append(_spawn_member())
	_group_index = 0


func _spawn_member() -> Ch2EscortNpc:
	var gu: GameUniverse = director.gu
	var npc := Ch2EscortNpc.new()
	gu.units_cont.add_child(npc)
	npc.init()
	npc.uid = gu.global_counter + RWRandom.rand_range(1, 20)
	gu.a_display_objects_vector.append(npc)
	npc.update_stats()
	var start: Vector2 = path[0] if path.size() > 0 else Vector2.ZERO
	npc.add_to_game(start.x, start.y, 1, true)
	gu.a_all_units.append(npc)
	return npc


func _alive_members() -> Array:
	return members.filter(func(m: Ch2EscortNpc) -> bool: return is_instance_valid(m) and m.cur_health > 0)


func update() -> void:
	if state != STATE_ACTIVE:
		return
	var alive: Array = _alive_members()
	if alive.size() < min_survivors:
		state = STATE_FAILED
		return
	var all_arrived := true
	for npc: Ch2EscortNpc in alive:
		if npc.is_downed:
			_update_downed(npc)
			all_arrived = false  # 倒地成员没有真的到位，队伍不能当作已经抵达下一锚点
			continue
		var target_idx: int = mini(_group_index + 1, path.size() - 1)
		var target: Vector2 = path[target_idx]
		var near_enemy := _enemy_near(npc.position)
		if near_enemy:
			all_arrived = false
			npc.set_ext_route([])  # 原地停住：清空路线，不滑向上一条还没走完的目标
			continue
		if npc.position.distance_to(target) > ARRIVE_RADIUS:
			all_arrived = false
			# NpcClass.set_destination(point, true) 会被它自己的重写直接吞掉（一代就是这样让 NPC
			# 不响应"点击移动"式指令），main_alg_destination_reached() 想用这条路给空路线的 NPC
			# 重新派路也会被吞掉——NPC 永远走不动。只有直接改 aSoldierMainRoute（set_ext_route /
			# set_new_route）才能真正驱动 NpcClass 的逐帧寻路，这里改走 set_ext_route。
			npc.set_ext_route([target])
	if all_arrived and _group_index < path.size() - 1:
		_group_index += 1
		director.set_flag("%s.at_%d" % [id, _group_index])
	if _group_index >= path.size() - 1:
		var all_safe := true
		for npc: Ch2EscortNpc in alive:
			if npc.is_downed or npc.position.distance_to(path[path.size() - 1]) > ARRIVE_RADIUS:
				all_safe = false
				break
		if all_safe and alive.size() >= min_survivors:
			state = STATE_COMPLETE


func _enemy_near(pos: Vector2) -> bool:
	for u: LivingObject in director.gu.a_all_units:
		if not u.friendly and u.cur_health > 0:
			if u.position.distance_to(pos) <= NEAR_ENEMY_RADIUS:
				return true
	return false


func _update_downed(npc: Ch2EscortNpc) -> void:
	if not _downed_timer.has(npc):
		_downed_timer[npc] = downed_window_frames
		_rescue_hold[npc] = 0
	var rescuer_near := false
	for u: LivingObject in director.gu.a_all_units:
		if u.friendly and u.cur_health > 0 and not u.is_npc and not u.ch2_uncontrollable:
			if u.position.distance_to(npc.position) <= RESCUE_RADIUS:
				rescuer_near = true
				break
	if rescuer_near:
		_rescue_hold[npc] = int(_rescue_hold[npc]) + 1
		if int(_rescue_hold[npc]) >= RESCUE_HOLD_FRAMES:
			npc.revive(0.3)
			_downed_timer.erase(npc)
			_rescue_hold.erase(npc)
			return
	else:
		_rescue_hold[npc] = 0
	_downed_timer[npc] = int(_downed_timer[npc]) - 1
	if int(_downed_timer[npc]) <= 0:
		npc.timeout_death()
		_downed_timer.erase(npc)
		_rescue_hold.erase(npc)


func hud_text() -> String:
	var n: int = _alive_members().size()
	var total: int = members.size()
	return Ch2Text.objective(director.level_number, id).format({"n": n, "min": min_survivors, "total": total})


func is_warning() -> bool:
	for npc: Ch2EscortNpc in members:
		if is_instance_valid(npc) and npc.is_downed:
			return true
	return false
