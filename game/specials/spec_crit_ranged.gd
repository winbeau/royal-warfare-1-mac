# 移植自 S/gameCore/specials/specCritRanged.as
class_name SpecCritRanged
extends SpecialTemplate

var a_probability: Array = []  # private
var ver: float = 0.0  # private
var cur_crit_mod: int = 0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Critical hit</font></p>" + "<p>Gives a chance to cause additional damage</p>"
	number_in_panel = 10
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_CRITRANGED)
	a_probability = [0.2, 0.22, 0.25]
	ver = a_probability[cur_spec_level]
	var loc2: Array = [3, 4, 5]
	cur_crit_mod = loc2[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "<font color='#F6F581'>Passive</font>," + " chance to strike: <font color='#F6F581'>" + SpecFmt.n(ver * 100) + "%</font>," + " damage multiplier: <font color='#F6F581'>x" + SpecFmt.n(cur_crit_mod) + "</font>"

# 注意：原版乘数固定为 3，cur_crit_mod 只用于描述文本（保留）。
func check_crit(param1: LivingObject, param2: int, param3: LivingObject) -> bool:
	var loc4: bool = false
	if can_use_special():
		if RWRandom.rand() < ver:
			var loc5: float = param1.cur_armor
			var loc6: float = loc5 - param3.armor_piercing_melee
			if loc6 < 0:
				loc6 = 0
			var loc7: int = int(param2 * (1 - loc6))
			param1.bring_damage(loc7 * 3, param3)
			var loc8: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc8.get_sound(SoundLibrary.CRITICAL), false, 0, 0.5, param3.position.x, SoundLibrary.CRITICAL)
			var loc9: SimpleCache = CritVisual.cached_data
			var loc10: CritVisual = loc9.get_data() as CritVisual
			loc10.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
			loc4 = true
	return loc4
