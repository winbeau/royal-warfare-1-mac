## 撤离目标：batches 批，每批 size 人，沿 path（或简单的 from -> to 直线）前进，到达终点即计数。
## 可以被杀死（不设倒地，直接用一代 NPC 死亡流程）。每批由导演 objective_state 动作放出
## （state == "release_batch"）。到达数不够 min_per_batch（按已放出的批次数折算最低线）时目标失败。
## JSON 字段：{id, type:"evac", optional, batches, size, min_per_batch,
##   要么 path:[[x,y],...]（第一个点是出发点，最后一个点是终点，中间点用来绕开地图障碍），
##   要么 from:[x,y] + to:[x,y]（直接一段直线，没有中间点）}
class_name Ch2EvacObjective
extends Ch2ObjectiveBase

const ARRIVE_RADIUS := 16.0

var batches: int = 1
var size: int = 1
var min_per_batch: int = 1
var from_pt: Vector2
var to_pt: Vector2
var route_points: Array = []  # Array[Vector2]，不含出发点，传给 set_ext_route
var _released_batches: int = 0
var _in_transit: Array = []  # Array[LivingObject]
var _arrived: int = 0


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	super(data, p_director)
	batches = int(data.get("batches", 1))
	size = int(data.get("size", 1))
	min_per_batch = int(data.get("min_per_batch", size))
	if data.has("path"):
		var path: Array = data["path"]
		for pt: Array in path:
			route_points.append(Vector2(float(pt[0]), float(pt[1])))
		from_pt = route_points[0]
		to_pt = route_points[route_points.size() - 1]
		route_points.remove_at(0)
	else:
		var f: Array = data.get("from", [0, 0])
		var t: Array = data.get("to", [0, 0])
		from_pt = Vector2(float(f[0]), float(f[1]))
		to_pt = Vector2(float(t[0]), float(t[1]))
		route_points = [to_pt]


func apply_state_action(action_state: String) -> void:
	if action_state == "release_batch":
		release_batch()


func release_batch() -> void:
	if _released_batches >= batches:
		return
	_released_batches += 1
	var gu: GameUniverse = director.gu
	for _i in size:
		var kind_roll: float = RWRandom.rand()  # 与 level_3.gd 抽取平民种类的比例一致
		var kind: int = LivingObject.NPC_WOMAN
		if kind_roll < 0.33:
			kind = LivingObject.NPC_OLDMAN
		elif kind_roll > 0.66:
			kind = LivingObject.NPC_MAN
		var npc: LivingObject = gu.add_soldier(kind, null, 1, true)
		npc.set_external_position(from_pt)
		npc.set_ext_route(route_points.duplicate())
		_in_transit.append(npc)
	director.set_flag("%s.batch_%d_released" % [id, _released_batches])


func update() -> void:
	if state != STATE_ACTIVE:
		return
	var still: Array = []
	for npc: LivingObject in _in_transit:
		if not is_instance_valid(npc) or npc.cur_health <= 0:
			continue  # 战损：不计入到达数
		if npc.position.distance_to(to_pt) <= ARRIVE_RADIUS:
			_arrived += 1
			npc.remove_after_move = true
			npc.set_external_position(npc.position)  # 停止原地，下一帧按一代 NPC 的 moveFinished 流程移除
		else:
			still.append(npc)
	_in_transit = still
	if _released_batches >= batches:
		var min_total: int = min_per_batch * batches
		if _arrived >= min_total:
			state = STATE_COMPLETE
		elif _in_transit.is_empty():
			# 已放完全部批次、没有还在路上的人，且总到达数不够：判失败
			state = STATE_FAILED


func hud_text() -> String:
	var total: int = size * batches
	return Ch2Text.objective(director.level_number, id).format({"n": _arrived, "min": min_per_batch * batches, "total": total})


func is_warning() -> bool:
	return _released_batches >= batches and _arrived < min_per_batch * batches
