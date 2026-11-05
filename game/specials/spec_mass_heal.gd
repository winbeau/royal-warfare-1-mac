# 移植自 S/gameCore/specials/specMassHeal.as
class_name SpecMassHeal
extends SpecialTemplate

func _init(param1: bool) -> void:
	number_in_panel = 18
	special_description = "<p><font size='18' color='#F6F581'>Mass heal</font></p>" + "<p>Heals all friends in an area</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_MASSHEAL)
	a_time_until_update = [18, 14, 10]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>"

# 反编译破损，按 P-code 重建（editable/pcode/gameCore/specials/specMassHeal.pcode）：
# 入口条件为 canUseSpecial() && param1.length > 1（反编译源码丢失了 length > 1，P-code 中 ofs0033 处可见）；
# 循环中 curHealth === health 的单位跳过，其余 healed = true、bringDamage(-param3)、healedEffect；
# 循环结束后 healed == true 才播放音效、resetCounter、setCastingStance、turnToUnit(最后一个遍历到的单位)。
# param2 为 priestClass（untyped，避免对 C 的 priest_class 产生编译期依赖）。
func check_mass_heal(param1: Array, param2, param3: int) -> bool:
	if can_use_special() and param1.size() > 1:
		var loc4: bool = false
		var loc5: int = 0
		var loc6: LivingObject = null
		while loc5 < param1.size():
			loc6 = param1[loc5] as LivingObject
			if loc6.cur_health != loc6.health:
				loc4 = true
				var loc7: int = -1 * param3
				loc6.bring_damage(loc7, param2)
				loc6.healed_effect()
			loc5 += 1
		if loc4 == true:
			var loc8: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc8.get_sound(SoundLibrary.STRONG_HEAL), false, 0, 0.36)
			reset_counter()
			param2.set_casting_stance()
			param2.turn_to_unit(loc6)
			return true
		return false
	return false
