# 移植自 S/gameCore/specials/specSuppress.as
class_name SpecSuppress
extends SpecialTemplate

var a_time_to_suppress: Array = []  # private
var cur_timeto_suppress: int = 0  # private
var a_suppress_ratio: Array = []  # private
var cur_suppress_ratio: float = 0.0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Suppress</font></p>" + "<p>Reduces target's attack speed</p>"
	number_in_panel = 29
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_SUPPRESS)
	a_time_to_suppress = [5, 6, 7]
	a_suppress_ratio = [1.5, 2, 2.5]
	cur_suppress_ratio = a_suppress_ratio[cur_spec_level]
	cur_timeto_suppress = a_time_to_suppress[cur_spec_level] * 30
	a_time_until_update = [20, 16, 12]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "suppress ratio: <font color='#F6F581'>x" + SpecFmt.n(cur_suppress_ratio) + "</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(cur_timeto_suppress / 30.0) + "s</font>"

func check_suppress(param1: LivingObject) -> void:
	if can_use_special():
		if param1.is_suppressed == false:
			if param1.get_cur_target != null:
				reset_counter()
				param1.suppressed(cur_timeto_suppress, cur_suppress_ratio)
				var loc2: SimpleCache = SuppressVisual.cached_data
				var loc3: SuppressVisual = loc2.get_data() as SuppressVisual
				loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
				var loc4: SoundLibrary = SoundLibrary.inst
				Sounds.inst.play(loc4.get_sound(SoundLibrary.SUPPRESS), false, 0, 0.3)
