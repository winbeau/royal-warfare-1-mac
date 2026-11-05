# 移植自 S/gameCore/specials/specOgreStun.as
class_name SpecOgreStun
extends SpecialTemplate

var a_stun_time: Array = []  # private
var max_stun_time: int = 0  # private

func _init(_param1: bool) -> void:
	cur_spec_level = 0
	number_in_panel = 19
	a_stun_time = [1, 1, 1]
	max_stun_time = a_stun_time[cur_spec_level] * 30
	special_description = "<p>Mass stun</p>" + "<p>Stuns all enemies in an area</p>"

func check_stun(param1: LivingObject, param2: LivingObject) -> bool:
	var loc3: Battle = param2.get_cur_battle
	var loc4: SoundLibrary = SoundLibrary.inst
	if loc3 != null:
		var loc7: Vector2 = Vector2(param2.position.x, param2.position.y)
		if loc3.is_defender(param2):
			var loc8: int = 0
			while loc8 < loc3.a_melee_attackers.size():
				var loc6: LivingObject = loc3.a_melee_attackers[loc8]
				var loc5: float = loc7.distance_to(Vector2(loc6.position.x, loc6.position.y))
				if loc5 < 55:
					loc6.stunned(max_stun_time)
					var loc9: SimpleCache = StunnedEffectVisual.cached_data
					var loc10: StunnedEffectVisual = loc9.get_data() as StunnedEffectVisual
					loc10.added_to_stage(loc6.sens.position.x, loc6.sens.position.y, Callable(), loc6)
				loc8 += 1
			Sounds.inst.play(loc4.get_sound(SoundLibrary.STUNNED), false, 0, 0.6, param1.position.x, SoundLibrary.STUNNED)
			return true
		var loc6b: LivingObject = param1
		var loc5b: float = loc7.distance_to(Vector2(loc6b.position.x, loc6b.position.y))
		if loc5b < 55:
			loc6b.stunned(max_stun_time)
			var loc9b: SimpleCache = StunnedEffectVisual.cached_data
			var loc10b: StunnedEffectVisual = loc9b.get_data() as StunnedEffectVisual
			loc10b.added_to_stage(loc6b.sens.position.x, loc6b.sens.position.y, Callable(), loc6b)
		Sounds.inst.play(loc4.get_sound(SoundLibrary.STUNNED), false, 0, 0.6, param1.position.x, SoundLibrary.STUNNED)
		return true
	return false
