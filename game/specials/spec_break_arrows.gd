# 移植自 S/gameCore/specials/specBreakArrows.as
class_name SpecBreakArrows
extends SpecialTemplate

var a_area: Array = []  # private
var area: int = 0  # private
var a_action_time: Array = []  # private
var action_time: int = 0  # private
var kd_counter: int = 0  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Diversion</font></p>" + "<p>Disables enemy archers' and mages' ability to shoot for some time.</p>"
	number_in_panel = 7
	kd_counter = 0
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_BREAKARROW)
	a_time_until_update = [18, 16, 14]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	a_area = [100, 110, 120]
	area = a_area[cur_spec_level]
	a_action_time = [7, 9, 11]
	action_time = a_action_time[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>, " + "time: <font color='#F6F581'>" + SpecFmt.n(action_time / 30.0) + "s</font>"

func check_break_arrows(param1: LivingObject) -> bool:
	if can_use_special():
		if kd_counter == 30:
			kd_counter = 0
			var loc2: Array = GameUniverse.inst.get_all_friends_in_area(Vector2(param1.position.x, param1.position.y), not param1.friendly, area)
			if loc2.size() > 0:
				var loc3: int = 0
				var loc5: bool = false
				while loc3 < loc2.size():
					var loc4: LivingObject = loc2[loc3] as LivingObject
					# 原版：loc5 在每次迭代开头重置，最终只反映最后一个单位（保留）
					loc5 = false
					if loc4.is_archer == true:
						if loc4.is_broken_arrows == false:
							loc5 = true
							loc4.broken_arrows(action_time)
							if loc4.get_cur_battle == null:
								loc4.set_target(null)
							loc4.stunned(1 * 30)
							var loc6: SimpleCache = BrokenArrowVisual.cached_data
							var loc7: BrokenArrowVisual = loc6.get_data() as BrokenArrowVisual
							loc7.added_to_stage(loc4.sens.position.x, loc4.sens.position.y, Callable(), loc4)
					loc3 += 1
				if loc5 == true:
					reset_counter()
					var loc6b: SimpleCache = CallConfusionVisual.cached_data
					var loc8: CallConfusionVisual = loc6b.get_data() as CallConfusionVisual
					loc8.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
					var loc9: SoundLibrary = SoundLibrary.inst
					Sounds.inst.play(loc9.get_sound(SoundLibrary.MAGE_CAST_NEW1), false, 0, 0.4, param1.position.x)
					return true
				return false
			return false
		kd_counter += 1
		return false
	return false
