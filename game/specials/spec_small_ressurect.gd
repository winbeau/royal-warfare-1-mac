# 移植自 S/gameCore/specials/specSmallRessurect.as
class_name SpecSmallRessurect
extends SpecialTemplate

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Resurrect</font></p>" + "<p>Resurrects one fallen ally in close area</p>"
	number_in_panel = 23
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_RESURRECT)
	time_until_update = 25 * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>"

# 反编译破损，按 P-code 重建（specSmallRessurect.pcode checkRessurect）：
# 入口条件为 canUseSpecial() && param1.length > 0（反编译源码丢失了 length > 0）。
# 只复活第一个满足条件的尸体：未复活过、getDeathTime + 90 < globalCounter、不是施法者、inField(自身) == true。
# 音效在循环结束后、resetCounter 之前播放。
# param2 为 priestClass（untyped）
func check_ressurect(param1: Array, param2) -> bool:
	if can_use_special() and param1.size() > 0:
		var loc3: bool = false
		var loc4: int = 0
		while loc4 < param1.size():
			if loc3 == false:
				var loc5: LivingObject = param1[loc4]
				if loc5.get_death_time + 90 < GameUniverse.inst.global_counter:
					if loc5 != param2:
						if loc5.in_field(loc5) == true:
							loc5.reanimate_dead()
							loc3 = true
							var loc6: SimpleCache = RessurectEffectVisual.cached_data
							var loc7: RessurectEffectVisual = loc6.get_data() as RessurectEffectVisual
							loc7.added_to_stage(loc5.sens.position.x, loc5.sens.position.y + 10, Callable(), loc5)
							param2.set_casting_stance()
							param2.turn_to_unit(loc5)
			loc4 += 1
		if loc3 == true:
			var loc8: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc8.get_sound(SoundLibrary.RESSURECT), false, 0, 0.4, param2.position.x)
			reset_counter()
			return true
		return false
	return false
