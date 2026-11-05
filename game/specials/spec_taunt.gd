# 移植自 S/gameCore/specials/specTaunt.as
class_name SpecTaunt
extends SpecialTemplate

var current_taunted_number: int = 0  # private
var a_area: Array = []  # private
var a_num_to_call: Array = []  # private
var area: int = 0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Taunt</font></p>" + "<p>Causes closest enemies to forget current targets and attack a knight</p>"
	number_in_panel = 30
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_TAUNT)
	a_num_to_call = [3, 4, 5]
	current_taunted_number = a_num_to_call[cur_spec_level]
	a_area = [100, 110, 120]
	area = a_area[cur_spec_level]
	a_time_until_update = [30, 25, 20]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>, maximum taunted: <font color='#F6F581'>" + SpecFmt.n(current_taunted_number) + " targets</font>"

# 反编译破损，按 P-code 重建（specTaunt.pcode checkTaunt）：
# 被嘲讽单位若在战斗中，先 removeFromBattle，若处于 FIGHTING 再 resetCurrentFrame，然后 setTarget(施法者)，
# 最后生成 tauntedVisual（反编译里的 while(true) 是 if，已确认）。
# 开头：施法者是防守者且攻击槽已满 6 个时直接返回 false。
func check_taunt(param1: LivingObject) -> bool:
	var loc2: bool = false
	if can_use_special():
		var loc3: Battle = param1.get_cur_battle
		if loc3 != null:
			if loc3.is_defender(param1) == true:
				if loc3.get_num_attackers == 6:
					return false
		var loc4: float = float(param1.cur_health) / param1.health
		if loc4 > 0.3:
			var loc5: int = current_taunted_number
			var loc6: Array = GameUniverse.inst.get_all_friends_in_area(Vector2(param1.position.x, param1.position.y), not param1.friendly, area)
			GameUniverse._random_sort(loc6)  # Array.sort(Utility.randomSort)
			if loc6.size() > 0:
				var loc7: bool = false
				while loc5 > 0:
					var loc8: LivingObject = loc6[0] as LivingObject
					if loc8.get_cur_target != param1:
						if loc8.can_attack_enemy(param1):
							loc7 = true
							loc5 -= 1
							if loc8.get_cur_battle != null:
								loc8.get_cur_battle.remove_from_battle(loc8)
								if loc8.get_stance == LivingObject.FIGHTING:
									loc8.reset_current_frame()
							loc8.set_target(param1)
							var loc11: SimpleCache = TauntedVisual.cached_data
							var loc9: TauntedVisual = loc11.get_data() as TauntedVisual
							loc9.added_to_stage(loc8.sens.position.x, loc8.sens.position.y, Callable(), loc8)
					loc6.remove_at(0)
					if loc6.size() == 0:
						loc5 = -1
				if loc7 == true:
					var loc10: SoundLibrary = SoundLibrary.inst
					Sounds.inst.play(loc10.get_sound(SoundLibrary.TAUNT), false, 0, 0.44, param1.position.x)
					reset_counter()
					var loc11b: SimpleCache = TauntVisual.cached_data
					var loc12: TauntVisual = loc11b.get_data() as TauntVisual
					loc12.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
					return true
				return false
			return false
		return false
	return loc2
