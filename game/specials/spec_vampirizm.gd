# 移植自 S/gameCore/specials/specVampirizm.as
class_name SpecVampirizm
extends SpecialTemplate

var cur_ratio: float = 0.0  # private
var a_ratio: Array = []  # private

# 注意：get_spec_level(param1, -1) 见 SpecRegen 的说明。
func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, -1)
	special_description = "<p>Vampirism</p>" + "<p>Recovers some health after any attack</p>"
	number_in_panel = 31
	a_ratio = [1, 1, 1]
	cur_ratio = a_ratio[cur_spec_level]

func update() -> void:
	pass

func check_vampirizm(param1: LivingObject, param2: LivingObject) -> bool:
	if param1.cur_health > 0:
		var loc3: SimpleCache = StrongHealVisual.cached_data
		var loc4: StrongHealVisual = loc3.get_data() as StrongHealVisual
		loc4.added_to_stage(param2.sens.position.x, param2.sens.position.y, Callable(), param2)
		param2.bring_damage(-AS3.round(param2.cur_damage * cur_ratio), param2, false, false)
		return true
	return false
