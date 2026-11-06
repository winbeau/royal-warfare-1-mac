## 拾取目标（可选）：任一玩家可控单位进入圆形区域即完成，发放 reward_money 金币。
## JSON 字段：{id, type:"pickup", optional:true, at:[x,y], radius(默认 30), reward_money}
class_name Ch2PickupObjective
extends Ch2ObjectiveBase

var at_pt: Vector2
var radius: float = 30.0
var reward_money: float = 0.0


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	super(data, p_director)
	var at: Array = data.get("at", [0, 0])
	at_pt = Vector2(float(at[0]), float(at[1]))
	radius = float(data.get("radius", 30.0))
	reward_money = float(data.get("reward_money", 0.0))


func update() -> void:
	if state != STATE_ACTIVE:
		return
	for u: LivingObject in director.gu.a_all_units:
		if u.friendly and u.cur_health > 0 and not u.is_npc and not u.ch2_uncontrollable:
			if u.position.distance_to(at_pt) <= radius:
				director.gu.set_money(reward_money)
				state = STATE_COMPLETE
				director.set_flag("%s.taken" % id)
				return


func hud_text() -> String:
	return Ch2Text.objective(director.level_number, id)
