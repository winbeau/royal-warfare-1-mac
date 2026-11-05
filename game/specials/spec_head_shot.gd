# 移植自 S/gameCore/specials/specHeadShot.as
class_name SpecHeadShot
extends SpecialTemplate

var cur_damag_modificator: int = 0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Headshot</font></p>" + "<p>Kills weak unit or causes immense damage</p>"
	number_in_panel = 41
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_HEADSHOT)
	a_time_until_update = [24, 19, 14]
	var loc2: Array = [4, 5, 6]
	cur_damag_modificator = loc2[cur_spec_level]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, damage multiplier: <font color='#F6F581'>x" + SpecFmt.n(cur_damag_modificator) + "</font>, kills target with health below <font color='#F6F581'>36%</font>"

func check_head_shot(param1: LivingObject, param2: int, param3: LivingObject) -> bool:
	if can_use_special():
		reset_counter()
		if float(param1.cur_health) / param1.health < 0.36:
			param1.bring_damage(600, param3)
		else:
			var loc7: float = param1.cur_armor
			var loc8: float = loc7 - param3.armor_piercing_melee
			if loc8 < 0:
				loc8 = 0
			var loc9: int = int(param2 * (1 - loc8))
			param1.bring_damage(loc9 * cur_damag_modificator, param3)
		var loc4: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc4.get_sound(SoundLibrary.CRITICAL), false, 0, 0.45, param3.position.x, SoundLibrary.CRITICAL)
		var loc5: SimpleCache = HeadShotEffectVisual.cached_data
		var loc6: HeadShotEffectVisual = loc5.get_data() as HeadShotEffectVisual
		loc6.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		return true
	return false
