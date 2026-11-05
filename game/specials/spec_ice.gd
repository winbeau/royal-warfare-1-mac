# 移植自 S/gameCore/specials/specIce.as
class_name SpecIce
extends SpecialTemplate

var damage: int = 0  # private
var cur_freeze_time: int = 0  # private
var a_freeze_time: Array = []  # private
var enemy: LivingObject = null  # private
var stop_while_cast: bool = false  # private（原版未使用）
var friendly: bool = false  # private

func _init(param1: bool) -> void:
	special_description = "<p><font size='18' color='#F6F581'>Ice</font></p>" + "<p>Traps enemy in ice</p>"
	number_in_panel = 17
	set_params(param1)

func set_params(param1: bool = true) -> void:
	friendly = param1
	cur_spec_level = get_spec_level(param1, StoredData.A_ICE)
	var loc2: Array = [1, 2, 2]
	damage = loc2[cur_spec_level]
	a_time_until_update = [34, 28, 23]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	a_freeze_time = [4, 7, 10]
	cur_freeze_time = a_freeze_time[cur_spec_level] * 30

func cur_level_params() -> String:
	set_params()
	if is_locked == true:
		return "Ability locked. Spend a star to unlock."
	return "Cooldown: <font color='#F6F581'>" + SpecFmt.n(time_until_update / 30.0) + "s</font>, " + "damage: <font color='#F6F581'>" + SpecFmt.n(damage) + "HP/s</font>, " + "time <font color='#F6F581'>" + SpecFmt.n(cur_freeze_time / 30.0) + "s</font>"

func set_ice() -> void:
	if enemy.is_trapped_in_ice == false and enemy.cur_health > 0:
		var loc1: SimpleCache = IceVisual.cached_data
		var loc2: IceVisual = loc1.get_data() as IceVisual
		loc2.set_counter(cur_freeze_time, enemy)
		loc2.added_to_stage(enemy.sens.position.x, enemy.sens.position.y, Callable(), enemy)
		enemy.trapped_in_ice(cur_freeze_time, damage)
		if friendly == true:
			GlobalData.inst.a10_frozen += 1
		reset_counter()

# param1 为 mageClass（untyped）
func check_ice(param1, param2: LivingObject) -> bool:
	enemy = param2
	if can_use_special():
		if param2.is_trapped_in_ice == false and param2.cur_health > 0:
			param1.set_casting_stance()
			return true
		return false
	return false
