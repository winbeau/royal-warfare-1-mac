# 移植自 S/gameCore/specials/specCorrupt.as
class_name SpecCorrupt
extends SpecialTemplate

var a_time_to_corrupt: Array = []  # private
var cur_time_to_corrupt: int = 0  # private
var a_corrupt_ratio: Array = []  # private
var current_corrupt: float = 0.0  # private
var friendly: bool = false  # private

func _init(param1: bool) -> void:
	number_in_panel = 9
	special_description = "<p><font size='18' color='#F6F581'>Break armor</font></p>" + "<p>Mighty shot breaks target's armor</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	friendly = param1
	cur_spec_level = get_spec_level(param1, StoredData.A_CORRUPT)
	a_time_to_corrupt = [6, 7, 8]
	cur_time_to_corrupt = a_time_to_corrupt[cur_spec_level] * 30
	a_corrupt_ratio = [0.3, 0.5, 0.7]
	current_corrupt = a_corrupt_ratio[cur_spec_level]
	a_time_until_update = [24, 20, 16]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "armor penalty: <font color='#F6F581'>-" + SpecFmt.n(current_corrupt) + " ARM</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(cur_time_to_corrupt / 30.0) + "s</font>"

func check_corrupt(param1: LivingObject) -> bool:
	if can_use_special():
		if param1.is_corrupted == false:
			reset_counter()
			if friendly:
				GlobalData.inst.a46_break_armor += 1
			param1.armor_corrupted(cur_time_to_corrupt, current_corrupt)
			var loc2: SimpleCache = CorruptVisual.cached_data
			var loc3: CorruptVisual = loc2.get_data() as CorruptVisual
			loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			var loc4: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc4.get_sound(SoundLibrary.BREAK_ARMOR), false, 0, 0.4, param1.position.x)
			return true
		return false
	return false
