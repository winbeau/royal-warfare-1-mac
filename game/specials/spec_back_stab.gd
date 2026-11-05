# 移植自 S/gameCore/specials/specBackStab.as
class_name SpecBackStab
extends SpecialTemplate

var cur_damag_modificator: int = 0  # private

func _init(param1: bool) -> void:
	number_in_panel = 3
	special_description = "<p><font size='18' color='#F6F581'>Backstab</font></p>" + "<p>Backstabs enemy. If target is fighting with allied soldier, can perform an instant kill.</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_BACKSTAB)
	var loc2: Array = [3, 5, 7]
	cur_damag_modificator = loc2[cur_spec_level]
	a_time_until_update = [20, 17, 15]
	time_until_update = a_time_until_update[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>. " + "Damage multiplier: <font color='#F6F581'>x" + SpecFmt.n(cur_damag_modificator) + "</font>. " + "Kills backstabbed target with health below <font color='#F6F581'>36%</font>"

# 原版 checkBackStab 内的闭包 standartDamage
func _standart_damage(enemy: LivingObject, cur_damage: int, me: LivingObject) -> void:
	var loc1: float = enemy.cur_armor
	var loc2: float = loc1 - me.armor_piercing_melee
	if loc2 < 0:
		loc2 = 0
	var loc3: int = int(cur_damage * (1 - loc2) * cur_damag_modificator)
	enemy.bring_damage(loc3, me)

func check_back_stab(param1: LivingObject, param2: int, param3: LivingObject, param4: bool = false) -> bool:
	var enemy: LivingObject = param1
	var cur_damage: int = param2
	var me: LivingObject = param3
	var is_at_new_battle: bool = param4
	if can_use_special():
		if enemy != null:
			var dist: float = MiscUtils.get_distance(me, enemy)
			if dist < 65:
				reset_counter()
				if enemy.get_cur_target != me or is_at_new_battle == true:
					if float(enemy.cur_health) / enemy.health < 0.36:
						enemy.bring_damage(600, me)
					else:
						_standart_damage(enemy, cur_damage, me)
				else:
					_standart_damage(enemy, cur_damage, me)
				var s: SoundLibrary = SoundLibrary.inst
				Sounds.inst.play(s.get_sound(SoundLibrary.BACKSTAB), false, 0, 0.45, me.position.x)
				var unit_cache: SimpleCache = BackstabVisual.cached_data
				var eff: BackstabVisual = unit_cache.get_data() as BackstabVisual
				eff.added_to_stage(enemy.sens.position.x, enemy.sens.position.y, Callable(), enemy)
				return true
			return false
		return false
	return false

func check_wave(param1: LivingObject) -> void:
	if can_use_special():
		var loc2: SimpleCache = StunnedSmallWaveVisual.cached_data
		var loc3: StunnedSmallWaveVisual = loc2.get_data() as StunnedSmallWaveVisual
		# 原版 addedToStage(sens.x, sens.y + sens.height / 2, null, param1)，与 specStun.checkWave 相同
		loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y + param1.sens_height / 2, Callable(), param1)
		loc3.scale.x = param1.get_view_direction
