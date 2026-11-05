# 移植自 S/gameCore/specials/specFlee.as
class_name SpecFlee
extends SpecialTemplate

func _init(param1: bool) -> void:
	cur_spec_level = get_spec_level(param1, StoredData.A_FLEE)
	number_in_panel = 14
	a_time_until_update = [60, 50, 40, 30]
	time_until_update = a_time_until_update[cur_spec_level] * 30
	special_description = "<p>Flee</p>" + "<p>Save unit's life hiding in shadows when suffering damage</p>"

func check_flee(param1: LivingObject) -> void:
	if can_use_special():
		if float(param1.cur_health) / param1.health < 0.2:
			if param1.get_cur_battle != null:
				param1.get_cur_battle.remove_from_battle(param1)
				param1.set_target(null)
				param1.is_defence_stance = true
				param1.in_hide = true
				param1.modulate.a = 0.5  # 原版 param1.alpha = 0.5
				var loc_x: int = RWRandom.rand_range(30, 650)
				var loc_y: int = RWRandom.rand_range(30, 570)
				param1.set_destination(Vector2(loc_x, loc_y), true)
				var loc2: SimpleCache = FleeVisual.cached_data
				var loc3: FleeVisual = loc2.get_data() as FleeVisual
				loc3.added_to_stage(param1.sens.position.x, param1.sens.position.y, Callable(), param1)
