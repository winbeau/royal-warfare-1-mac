# 移植自 S/gameCore/specials/specMassStun.as
class_name SpecMassStun
extends SpecialTemplate

var a_stun_time: Array = []  # private
var max_stun_time: int = 0  # private
var friendly: bool = false  # private

func _init(param1: bool) -> void:
	friendly = param1
	special_description = "<p><font size='18' color='#F6F581'>Mass stun</font></p>" + "<p>Stuns all enemies in an area</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_MASSSTUN)
	number_in_panel = 19
	a_stun_time = [2, 3, 4]
	a_time_until_update = [22, 17, 12]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	max_stun_time = a_stun_time[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "stun time: <font color='#F6F581'>" + SpecFmt.n(max_stun_time / 30.0) + "s</font>"

func check_stun(param1: LivingObject, param2: LivingObject) -> bool:
	if can_use_special():
		var loc3: Battle = param2.get_cur_battle
		if loc3 == null:
			return false
		if loc3.is_defender(param2):  # 原版 while(...){...return} 只执行一次
			if not (loc3.get_num_attackers > 1 or param2.friendly == false):
				return false
			reset_counter()
			var loc6: Vector2 = Vector2(param2.position.x, param2.position.y)
			var loc7: int = 0
			while loc7 < loc3.a_melee_attackers.size():
				var loc5: LivingObject = loc3.a_melee_attackers[loc7]
				var loc4: float = loc6.distance_to(Vector2(loc5.position.x, loc5.position.y))
				if loc4 < 45:
					if friendly:
						GlobalData.inst.a41_stun_enemies += 1
					loc5.stunned(max_stun_time)
					var loc9: SimpleCache = StunnedEffectVisual.cached_data
					var loc10: StunnedEffectVisual = loc9.get_data() as StunnedEffectVisual
					loc10.added_to_stage(loc5.sens.position.x, loc5.sens.position.y, Callable(), loc5, false, true)
				loc7 += 1
			var loc8: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc8.get_sound(SoundLibrary.STUNNED), false, 0, 0.5, param1.position.x, SoundLibrary.STUNNED)
			return true
		return false
	return false

func check_wave(param1: LivingObject) -> void:
	if can_use_special():
		var loc2: Battle = param1.get_cur_battle
		if loc2.is_defender(param1):
			if loc2.get_num_attackers > 1 or param1.friendly == false:
				var loc3: SimpleCache = StunnedWaveVisual.cached_data
				var loc4: StunnedWaveVisual = loc3.get_data() as StunnedWaveVisual
				loc4.added_to_stage(param1.sens.position.x, param1.sens.position.y + param1.sens_height / 2, Callable(), param1)
