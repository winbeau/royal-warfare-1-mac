# 移植自 S/gameCore/specials/specMissSkeleton.as
class_name SpecMissSkeleton
extends SpecialTemplate

var a_probability: Array = []  # private（原版未使用）
var cur_probability: float = 0.0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Bones</font></p>" + "<p>Gives a 15% chance of evading arrows</p>"
	number_in_panel = 43
	time_until_update = -10
	set_params(param1)

func set_params(_param1: bool = true) -> void:
	cur_probability = 0.15

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "<font color='#F6F581'>Passive</font>, " + "chance: <font color='#F6F581'>" + SpecFmt.n(cur_probability * 100) + "%</font>"

func update() -> void:
	pass

func is_missed(param1: LivingObject) -> bool:
	var loc2: bool = false
	if can_use_special():
		if RWRandom.rand() < cur_probability:
			var loc3: SimpleCache = MissVisual.cached_data
			var loc4: MissVisual = loc3.get_data() as MissVisual
			loc4.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			loc2 = true
	return loc2
