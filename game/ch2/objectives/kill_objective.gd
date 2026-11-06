## 击杀目标：累计击杀（含被斩下马、静默移除的达思重骑——二者都会经由 GameUniverse.make_unit_dead
## 进入 a_waiting_death，和 Ch2Director._track_losses 用同一套去重扫描方式）指定 kind 达到 count 次即完成。
## JSON 字段：{id, type:"kill", optional, kind:"CH2_DARTH_LANCER", count}
class_name Ch2KillObjective
extends Ch2ObjectiveBase

var target_kind: int = -1
var count: int = 1
var killed: int = 0
var _counted: Array = []


func _init(data: Dictionary, p_director: Ch2Director) -> void:
	super(data, p_director)
	target_kind = Ch2Kinds.resolve(str(data.get("kind", "")))
	count = int(data.get("count", 1))


func update() -> void:
	if state != STATE_ACTIVE:
		return
	for u: LivingObject in director.gu.a_waiting_death:
		if u.get_kind == target_kind and _counted.find(u) < 0:
			_counted.append(u)
			killed += 1
	if killed >= count:
		state = STATE_COMPLETE


func hud_text() -> String:
	return Ch2Text.objective(director.level_number, id).format({"n": mini(killed, count), "min": count, "total": count})
