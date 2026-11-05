# 移植自 S/gameCore/specials/specCrit.as
class_name SpecCrit
extends SpecialTemplate

var a_probability: Array = []  # private

func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_CRIT)
	number_in_panel = 2
	special_description = "<p>Critical hit</p>" + "<p>Gives a chance to cause additional damage</p>"
	a_probability = [0.15, 0.175, 0.2, 0.225]

func check_crit(param1: LivingObject, param2: int, param3: LivingObject) -> bool:
	var loc4: float = float(a_probability[cur_spec_level])
	var loc5: bool = false
	if RWRandom.rand() < loc4:
		var loc6: float = param1.cur_armor
		var loc7: float = loc6 - param3.armor_piercing_melee
		if loc7 < 0:
			loc7 = 0
		var loc8: int = int(param2 * (1 - loc7))
		param1.bring_damage(loc8 * 3, param3)
		var loc9: SimpleCache = RoundAttackEffectVisual.cached_data
		var loc10: RoundAttackEffectVisual = loc9.get_data() as RoundAttackEffectVisual
		loc10.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		var loc11: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc11.get_sound(SoundLibrary.CRITICAL), false, 0, 0.5, param3.position.x, SoundLibrary.CRITICAL)
		loc9 = CritVisual.cached_data
		var loc12: CritVisual = loc9.get_data() as CritVisual
		loc12.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		loc5 = true
	return loc5
