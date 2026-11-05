# 移植自 S/gameCore/specials/specWeakness.as
class_name SpecWeakness
extends SpecialTemplate

var a_weak_time: Array = []  # private
var cur_weak_time: float = 0.0  # private

func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_WEAKNESS)
	special_description = "<p>Weakness</p>" + "<p>Weakens enemy and lowers its attack speed</p>"
	number_in_panel = 34
	a_time_until_update = [5, 5, 5, 5]
	a_weak_time = [5, 7, 10, 13]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	cur_weak_time = a_weak_time[cur_spec_level] * 30

func check_weak(param1: LivingObject) -> bool:
	if can_use_special():
		if param1.is_weakened == false:
			reset_counter()
			param1.weakened(int(cur_weak_time))
			var loc2: SimpleCache = WeaknessVisual.cached_data
			var loc3: WeaknessVisual = loc2.get_data() as WeaknessVisual
			loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			var loc4: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc4.get_sound(SoundLibrary.ZOMBIE_WEAKNESS), false, 0, 0.35, param1.position.x, SoundLibrary.ZOMBIE_WEAKNESS)
			return true
		return false
	return false
