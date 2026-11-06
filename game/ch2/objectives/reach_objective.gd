## 到达目标：指定数量的玩家单位同时进入区域即完成。
## JSON 字段：{id, type:"reach", optional, at:[x,y], radius(默认 40), count}
class_name Ch2ReachObjective
extends Ch2ObjectiveBase

var at_pt: Vector2
var radius: float = 40.0
var count: int = 1


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	super(data, p_director)
	var at: Array = data.get("at", [0, 0])
	at_pt = Vector2(float(at[0]), float(at[1]))
	radius = float(data.get("radius", 40.0))
	count = int(data.get("count", 1))


func update() -> void:
	if state != STATE_ACTIVE:
		return
	var n := 0
	for u: LivingObject in director.gu.a_all_units:
		if u.friendly and u.cur_health > 0 and not u.is_npc and not u.ch2_uncontrollable:
			if u.position.distance_to(at_pt) <= radius:
				n += 1
	if n >= count:
		state = STATE_COMPLETE
		director.set_flag("%s.reached" % id)


func hud_text() -> String:
	return Ch2Text.objective(director.level_number, id)
