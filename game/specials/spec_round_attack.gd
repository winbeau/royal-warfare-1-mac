# 移植自 S/gameCore/specials/specRoundAttack.as
class_name SpecRoundAttack
extends SpecialTemplate

var a_stun_time: Array = []  # private（原版未使用）
var max_stun_time: int = 0  # private（原版未使用）
var throwing_wave: bool = false  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Circle strike</font></p>" + "<p>Round attack damages all enemies in range</p>"
	number_in_panel = 24
	throwing_wave = false
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_ROUNDATTACK)
	a_time_until_update = [20, 16, 12]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, damage multiplier: <font color='#F6F581'>x1.2</font>"

func check_round_attack(_param1: LivingObject, param2: LivingObject) -> bool:
	if can_use_special():
		var loc3: Battle = param2.get_cur_battle
		if loc3 == null:
			return false
		if loc3.is_defender(param2):  # 原版 while(...){...return true} 只执行一次
			if loc3.get_num_attackers <= 1:
				return false
			throwing_wave = false
			reset_counter()
			var loc11: Vector2 = Vector2(param2.position.x, param2.position.y)
			var loc12: int = 0
			while loc12 < loc3.a_melee_attackers.size():
				var loc6: LivingObject = loc3.a_melee_attackers[loc12]
				var loc4: float = loc11.distance_to(Vector2(loc6.position.x, loc6.position.y))
				if loc4 < 55:
					if loc6.cur_health > 0:
						var loc9: float = loc6.cur_armor
						var loc14: float = loc9 - param2.armor_piercing_melee
						if loc14 < 0:
							loc14 = 0
						var loc10: float = param2.cur_damage * (1 - loc14) * 1.2
						loc6.bring_damage(int(loc10), param2, true)
						var loc8: SimpleCache = RoundAttackEffectVisual.cached_data
						var loc5: RoundAttackEffectVisual = loc8.get_data() as RoundAttackEffectVisual
						loc5.added_to_stage(loc6.sens.position.x, loc6.sens.position.y, Callable(), loc6)
				loc12 += 1
			var loc13: SoundLibrary = SoundLibrary.inst
			Sounds.inst.play(loc13.get_sound(SoundLibrary.SWORDMASTER_CIRCLE), false, 0, 0.6, param2.position.x)
			return true
		return false
	return false

func check_wave(param1: LivingObject) -> void:
	if can_use_special():
		var loc2: Battle = param1.get_cur_battle
		if throwing_wave == false:
			if loc2.is_defender(param1):
				if loc2.get_num_attackers > 1:
					throwing_wave = true
					var loc3: SimpleCache = RoundAttackVisual.cached_data
					var loc4: RoundAttackVisual = loc3.get_data() as RoundAttackVisual
					loc4.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
