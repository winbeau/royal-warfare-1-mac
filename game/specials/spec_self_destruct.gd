# 移植自 S/gameCore/specials/specSelfDestruct.as
class_name SpecSelfDestruct
extends SpecialTemplate

var me: LivingObject = null  # private（原版未使用）
var a_radius: Array = []  # private
var radius: int = 0  # private

# 注意：get_spec_level(param1, -1) 见 SpecRegen 的说明。
func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, -1)
	special_description = "<p>Kamikaze</p>" + "<p>Self-destruction</p>"
	number_in_panel = -1
	a_radius = [80, 100, 120, 140]
	radius = a_radius[cur_spec_level]

# 反编译破损，按 P-code 重建（specSelfDestruct.pcode selfDestruct）：
# 对范围内（除自己）每个单位：dmg = param2 * (radius - dist) / radius；先 bringDamage(dmg, param1)，
# 然后若该单位 friendly == false 且 dmg >= 它此时的 curHealth（已扣血后）则 oneshot 计数 +1（保留顺序）。
# 循环后 oneshot >= 10 写 a11，>= 15 写 a7；之后无论范围内有无单位，都播放爆炸音效和 corpseExplosionVisual。
func self_destruct(param1: LivingObject, param2: int) -> void:
	var loc3: int = 0
	var loc4: Array = GameUniverse.inst.get_all_units_in_area(Vector2(param1.position.x, param1.position.y), radius)
	if loc4.size() > 0:
		var loc8: int = 0
		while loc8 < loc4.size():
			var loc9: LivingObject = loc4[loc8]
			if loc9 != param1:
				var loc10: float = MiscUtils.get_distance(param1, loc9)
				var loc11: float = float(radius - loc10) / radius
				loc9.bring_damage(int(param2 * loc11), param1)
				if loc9.friendly == false:
					var loc12: float = param2 * loc11
					if loc12 >= loc9.cur_health:
						loc3 += 1
			loc8 += 1
		if loc3 >= 10:
			GlobalData.inst.a11_kill_with_bomberman = loc3
			if loc3 >= 15:
				GlobalData.inst.a7_kill_15oneshot = loc3
	var loc5: SoundLibrary = SoundLibrary.inst
	Sounds.inst.play(loc5.get_sound(SoundLibrary.KAMIKAZE), false, 0, 0.75, param1.position.x, SoundLibrary.KAMIKAZE)
	var loc6: SimpleCache = CorpseExplosionVisual.cached_data
	var loc7: CorpseExplosionVisual = loc6.get_data() as CorpseExplosionVisual
	loc7.added_to_stage(param1.position.x, param1.position.y)

func update() -> void:
	pass
