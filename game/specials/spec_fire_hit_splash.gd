# 移植自 S/gameCore/specials/specFireHitSplash.as
class_name SpecFireHitSplash
extends SpecialTemplate

var a_area: Array = []  # private
var area: float = 0.0  # private
var a_damage_modif: Array = []  # private（原版未使用）
var damage_modif: float = 0.0  # private（原版未使用）

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Splash attack</font></p>" + "<p>Damages all enemies in small AOE with main target</p>"
	number_in_panel = 12
	set_params(param1)
	time_until_update = -10

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_FIREHITSPLASH)
	a_area = [70, 80, 90]
	area = a_area[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "<font color='#F6F581'>Passive</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>"

func update() -> void:
	pass

# 反编译源码含 while(true){...break;}，按 P-code 重建：
# 对范围内（除主目标 param3）每个单位，伤害 = round(param4 * (area - dist) / area * (1 - curMagicResist) / 1.6)，
# 伤害 > 0 才 bringDamage(param2)；bringDamage 之后若伤害 > 该单位 curHealth，则 oneshot 计数 +1（保留顺序）。
# gitGlowVisual 无论伤害是否 > 0 都会生成。
func check_fire_splash(param1: Vector2, param2: LivingObject, param3: LivingObject, param4: float) -> bool:
	if can_use_special():
		var loc7: Array = GameUniverse.inst.get_all_friends_in_area(param1, param3.friendly, area)
		var loc8: int = 0
		var loc9: int = 0
		while loc9 < loc7.size():
			var loc10: LivingObject = loc7[loc9]
			if loc10 != param3:
				var loc11: float = Vector2(loc10.position.x, loc10.position.y).distance_to(Vector2(param1.x, param1.y))
				var loc12: float = (area - loc11) / area
				var loc13: float = loc10.cur_magic_resist
				var loc14: float = AS3.round(param4 * loc12 * (1 - loc13) / 1.6)
				if loc14 > 0:
					loc10.bring_damage(int(loc14), param2)
					if loc14 > loc10.cur_health:
						loc8 += 1
				var loc6: SimpleCache = GitGlowVisual.cached_data
				var loc5: GitGlowVisual = loc6.get_data() as GitGlowVisual
				loc5.added_to_stage(loc10.position.x, loc10.position.y)
			loc9 += 1
		if loc8 >= 15:
			GlobalData.inst.a7_kill_15oneshot = loc8
		return true
	return false
