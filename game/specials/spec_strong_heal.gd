# 移植自 S/gameCore/specials/specStrongHeal.as
class_name SpecStrongHeal
extends SpecialTemplate

var heal: float = 0.0  # private

func _init(param1: bool) -> void:
	number_in_panel = 32
	special_description = "<p><font size='18' color='#F6F581'>Blessed Healing</font></p>" + "<p>Heals huge amount of health</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_STRONGHEAL)
	a_time_until_update = [35, 30, 25]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	var loc2: Array = [6, 7, 8]
	heal = loc2[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "Heal multiplier: <font color='#F6F581'>x" + SpecFmt.n(heal) + "</font>"

# param2 为 priestClass（untyped）
func check_strong_heal(param1: LivingObject, param2, param3: int) -> bool:
	if can_use_special():
		if param1.cur_health != param1.health:
			var loc5: int = int(-1 * (param3 * heal))
			param1.bring_damage(loc5, param2)
			reset_counter()
			param2.set_casting_stance()
			param2.turn_to_unit(param1)
			var loc6: SimpleCache = StrongHealVisual.cached_data
			var loc7: StrongHealVisual = loc6.get_data() as StrongHealVisual
			loc7.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			var loc8: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc8.get_sound(SoundLibrary.STRONG_HEAL), false, 0, 0.33)
			return true
		return false
	return false
