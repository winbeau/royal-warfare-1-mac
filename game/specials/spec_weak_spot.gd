# 移植自 S/gameCore/specials/specWeakSpot.as
class_name SpecWeakSpot
extends SpecialTemplate

var cur_weak_modifier: float = 0.0  # private
var a_weak_modifier: Array = []  # private
var a_time_to_weak_spot: Array = []  # private
var cur_time_to_weak: float = 0.0  # private

func _init(param1: bool) -> void:
	number_in_panel = 16
	special_description = "<p><font size='18' color='#F6F581'>Weak spot</font></p>" + "<p>Target that was hit in the weakspot suffers extra damage from attacks</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_WEAKSPOT)
	a_time_until_update = [24, 20, 16]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	a_weak_modifier = [1.6, 1.8, 2]
	cur_weak_modifier = a_weak_modifier[cur_spec_level]
	a_time_to_weak_spot = [8, 9, 10]
	cur_time_to_weak = a_time_to_weak_spot[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "damage multiplier: <font color='#F6F581'>x" + SpecFmt.n(cur_weak_modifier) + "</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(cur_time_to_weak / 30.0) + "s</font>"

func check_weak_spot(param1: LivingObject) -> bool:
	if can_use_special():
		if param1 != null:
			if param1.has_weak_spot == false:
				reset_counter()
				param1.weak_spotted(cur_weak_modifier, cur_time_to_weak)
				var loc2: SoundLibrary = SoundLibrary.inst
				Sounds.inst.play(loc2.get_sound(SoundLibrary.WEAKSPOT), false, 0, 0.6, param1.position.x)
				var loc3: SimpleCache = WeakSpotEffectVisual.cached_data
				var loc4: WeakSpotEffectVisual = loc3.get_data() as WeakSpotEffectVisual
				loc4.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
				return true
			return false
		return false
	return false
