# 移植自 S/gameCore/specials/specRegen.as
class_name SpecRegen
extends SpecialTemplate

var cur_ratio: float = 0.0  # private
var a_ratio: Array = []  # private

# 注意：原版 getSpecLevel(param1, -1)；param1 为 true 时 AS3 的 array[-1] 为 undefined（等级 0，视为锁定），
# 而 GDScript 的 array[-1] 取末元素。只有怪物使用此技能（param1 恒为 false，直接返回 2），不受影响。
func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, -1)
	special_description = "<p>Regeneration</p>" + "<p>Regenerates health over time</p>"
	number_in_panel = 35
	a_ratio = [23, 23, 23]
	cur_ratio = a_ratio[cur_spec_level]
	time_until_update = 5 * 30

func check_regen(param1: LivingObject) -> bool:
	if can_use_special():
		if param1.cur_health < param1.health:
			reset_counter()
			param1.bring_damage(int(-cur_ratio), param1, false, false)
			var loc2: SimpleCache = RegenVisual.cached_data
			var loc3: RegenVisual = loc2.get_data() as RegenVisual
			loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			return true
		return false
	return false
