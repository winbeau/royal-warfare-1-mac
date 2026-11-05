# 移植自 S/gameCore/specials/specSilence.as
class_name SpecSilence
extends SpecialTemplate

var a_area: Array = []  # private
var area: int = 0  # private
var a_action_time: Array = []  # private
var action_time: int = 0  # private
var radius: int = 0  # private（原版未使用）
var a_damage: Array = []  # private（原版未使用）
var cur_damage: int = 0  # private（原版未使用）

func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_SILENCE)
	number_in_panel = 26
	special_description = "<p>Confusion</p>" + "<p>Saboteur spreads special gas in an area. Confused enemies are forced to attack each other.</p>"
	a_time_until_update = [50, 46, 43, 40]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	a_area = [80, 90, 100, 110]
	area = a_area[cur_spec_level]
	a_action_time = [8, 9, 10, 11]
	action_time = a_action_time[cur_spec_level] * 30

# 反编译破损，按 P-code 重建（specSilence.pcode checkSilence）：
# 单位条件为 isConfused == false && (specialOne !== null || specialTwo !== null)
# （反编译源码丢失了 specialTwo 这一项）；loc5 在每次迭代开头重置为 false，
# 因此 resetCounter + parryVisual 只取决于最后一个单位（保留原版行为）；
# 范围内只要有单位（length > 0）就返回 true，即使一个都没被迷惑。
func check_silence(param1: LivingObject) -> bool:
	if can_use_special():
		var loc2: Array = GameUniverse.inst.get_all_friends_in_area(Vector2(param1.position.x, param1.position.y), not param1.friendly, area)
		if loc2.size() > 0:
			var loc3: int = 0
			var loc5: bool = false
			while loc3 < loc2.size():
				var loc4: LivingObject = loc2[loc3] as LivingObject
				loc5 = false
				if loc4.is_confused == false:
					if loc4.special_one != null or loc4.special_two != null:
						loc5 = true
						loc4.confuse(action_time)
						var loc6: SimpleCache = SilencedVisual.cached_data
						var loc7: SilencedVisual = loc6.get_data() as SilencedVisual
						loc7.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
				loc3 += 1
			if loc5 == true:
				reset_counter()
				var loc6b: SimpleCache = ParryVisual.cached_data
				var loc8: ParryVisual = loc6b.get_data() as ParryVisual
				loc8.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			return true
		return false
	return false
