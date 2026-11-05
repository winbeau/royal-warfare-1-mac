# 移植自 S/gameCore/specials/specSlow.as
class_name SpecSlow
extends SpecialTemplate

var a_time_to_slow: Array = []  # private
var cur_timeto_slow: float = 0.0  # private
var a_area: Array = []  # private
var area: float = 0.0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Slow</font></p>" + "<p>Reduces all enemies' movement speed in small AOE</p>"
	number_in_panel = 27
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_SLOW)
	a_time_to_slow = [4, 5, 6]
	a_area = [40, 50, 60]
	area = a_area[cur_spec_level]
	cur_timeto_slow = a_time_to_slow[cur_spec_level] * 30
	a_time_until_update = [22, 20, 18]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>"

func check_slow(param1: LivingObject) -> bool:
	if can_use_special():
		var loc2: Array = GameUniverse.inst.get_all_friends_in_area(Vector2(param1.position.x, param1.position.y), param1.friendly, area)
		var loc3: bool = false
		var loc4: int = 0
		while loc4 < loc2.size():
			var loc5: LivingObject = loc2[loc4]
			if loc5.is_slowed == false:
				loc3 = true
				loc5.slowed(int(cur_timeto_slow))
				var loc6: SimpleCache = SlowEffectVisual.cached_data
				var loc7: SlowEffectVisual = loc6.get_data() as SlowEffectVisual
				loc7.added_to_stage(loc5.sens.position.x, loc5.sens.position.y, Callable(), loc5, false, true)
			loc4 += 1
		if loc3 == true:
			var loc8: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc8.get_sound(SoundLibrary.SLOW), false, 0, 0.6)
			reset_counter()
			return true
		return false
	return false
