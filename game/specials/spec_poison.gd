# 移植自 S/gameCore/specials/specPoison.as
class_name SpecPoison
extends SpecialTemplate

var a_time_to_poison: Array = []  # private
var cur_timeto_poison: float = 0.0  # private
var a_poison_strength: Array = []  # private
var cur_poison_strength: int = 0  # private

func _init(_param1: bool) -> void:
	cur_spec_level = 0
	number_in_panel = 22
	a_time_to_poison = [8, 12, 14]
	cur_timeto_poison = a_time_to_poison[cur_spec_level] * 30
	a_poison_strength = [3, 3, 4]
	cur_poison_strength = a_poison_strength[cur_spec_level]
	special_description = "<p>Poison</p>" + "<p>Poisoned enemy looses health over time</p>"
	a_time_until_update = [25, 25, 25]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func check_poison(param1: LivingObject) -> bool:
	if can_use_special():
		if param1 != null:
			if param1.is_poisoned == false:
				reset_counter()
				param1.poisoned(int(cur_timeto_poison), cur_poison_strength)
				var loc2: SimpleCache = PoisonEffectVisual.cached_data
				var loc3: PoisonEffectVisual = loc2.get_data() as PoisonEffectVisual
				loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
				var loc4: SoundLibrary = SoundLibrary.inst
				Sounds.inst.play(loc4.get_sound(SoundLibrary.POISON), false, 0, 0.3)
				return true
			return false
		return false
	return false
