# 移植自 S/gameCore/specials/specParry.as
class_name SpecParry
extends SpecialTemplate

var a_probability: Array = []  # private（原版未使用）
var cur_probability: float = NAN  # private（原版未使用）
var crit_chance: float = NAN  # private

func _init(param1: bool) -> void:
	number_in_panel = 21
	special_description = "<p><font size='18' color='#F6F581'>Parry</font></p>" + "<p>Evade enemy damage and counterattack with a chance of a critical strike.</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_PARRY)
	a_time_until_update = [9, 7, 5]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	crit_chance = 0.2

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font> " + "Critical strike chance: <font color='#F6F581'>" + SpecFmt.n(crit_chance * 100) + "%</font> " + "Damage multiplier: <font color='#F6F581'>x3</font>"

# P-code 核实（specParry.pcode checkParry，约 ofs008e~ofs00b2）：伤害倍率先设 1.5，随后
#   getlex Utility.rand; getproperty critChance; ifngt -> 跳过；否则 pushbyte 3 -> 倍率 = 3
# 即 `if (Utility.rand > critChance) 倍率 = 3`。critChance = 0.2，所以 80% 概率三倍、20% 概率 1.5 倍，
# 与说明文字 "chance of a critical strike ... Critical strike chance: 20%" 相反。这是原版的真实行为，保持不变。
func check_parry(param1: LivingObject, _param2: int, param3: LivingObject) -> bool:
	if can_use_special():
		reset_counter()
		var loc4: SimpleCache = ParryVisual.cached_data
		var loc5: ParryVisual = loc4.get_data() as ParryVisual
		loc5.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
		loc5.scale.x = param3.get_view_direction * -1
		var loc6: float = param3.cur_armor
		var loc7: float = loc6 - param1.armor_piercing_melee
		if loc7 < 0:
			loc7 = 0
		var loc8: float = 1.5
		if RWRandom.rand() > crit_chance:
			loc8 = 3
		var loc9: float = param1.cur_damage * (1 - loc7) * loc8
		param3.bring_damage(int(loc9), param1, true)
		var loc10: SoundLibrary = SoundLibrary.inst
		Sounds.inst.play(loc10.get_sound(SoundLibrary.SWORDMASTER_PARRY), false, 0, 0.6, param1.position.x)
		loc4 = RoundAttackEffectVisual.cached_data
		var loc11: RoundAttackEffectVisual = loc4.get_data() as RoundAttackEffectVisual
		loc11.added_to_stage(param3.sens.position.x, param3.sens.position.y, Callable(), param3)
		return true
	return false
