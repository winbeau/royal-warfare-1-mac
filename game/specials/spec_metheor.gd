# 移植自 S/gameCore/specials/specMetheor.as
class_name SpecMetheor
extends SpecialTemplate

var a_damage: Array = []  # private
var cur_damage: int = 0  # private
var hit_coords: Vector2 = Vector2.ZERO  # private
var area: float = 0.0  # private
var friendly: bool = false  # private
var me = null  # private，mageClass（untyped）

func _init(param1: bool) -> void:
	number_in_panel = 20
	special_description = "<p><font size='18' color='#F6F581'>Meteor</font></p>" + "<p>Falling rock damages area and causes immense damage</p>"
	set_params(param1)

func set_params(param1: bool = true) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_METHEOR)
	a_damage = [100, 130, 160]
	a_time_until_update = [40, 35, 30]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	cur_damage = a_damage[cur_spec_level]
	var loc2: Array = [60, 65, 70]
	area = loc2[cur_spec_level]

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "AOE: <font color='#F6F581'>" + SpecFmt.n(area) + "</font>, " + "damage: <font color='#F6F581'>" + SpecFmt.n(cur_damage) + "</font>"

# param1 为 mageClass（untyped）
func check_metheor(param1, param2: LivingObject) -> bool:
	me = param1
	if can_use_special():  # 原版 while(...){...return true} 只执行一次
		reset_counter()
		friendly = param1.friendly
		var loc3: SimpleCache = RockFallingVisual.cached_data
		var loc4: RockFallingVisual = loc3.get_data() as RockFallingVisual
		loc4.added_to_stage(param2.position.x, param2.position.y, hit_ground_handler)
		hit_coords = Vector2(param2.position.x, param2.position.y)
		param1.set_casting_stance()
		return true
	return false

func hit_ground_handler() -> void:
	var loc1: Array = GameUniverse.inst.get_all_friends_in_area(hit_coords, not me.friendly, area)
	var loc2: SoundLibrary = SoundLibrary.inst
	Sounds.inst.play(loc2.get_sound(SoundLibrary.METHEOR_FALLS), false, 0, 0.75, me.position.x)
	var loc3: int = 0
	while loc1.size() > 0:
		var loc4: LivingObject = loc1.pop_back()
		var loc5: float = Vector2(loc4.position.x, loc4.position.y).distance_to(Vector2(hit_coords.x, hit_coords.y))
		var loc6: float = (area - loc5) / area
		var loc7: float = cur_damage * loc6
		if loc7 > loc4.cur_health:
			GlobalData.inst.a15_kill_by_metheor += 1
			loc3 += 1
		loc4.bring_damage(int(cur_damage * loc6), me)
	if loc3 >= 15:
		GlobalData.inst.a7_kill_15oneshot = loc3
