# 移植自 S/gameCore/living/npcClass.as
class_name NpcClass
extends LivingObject

func _init() -> void:
	is_npc = true

func move_finished() -> void:
	if remove_after_move == true:
		GameUniverse.inst.make_unit_dead(_instance)
		if cur_battle != null:
			cur_battle.set_unit_dead(_instance)
		set_stance(DEAD)
		ui_health_bar.update(0, cur_level)
		sprite.modulate.a = 0.05  # sprite.alpha = 0.05

func set_destination(param1: Vector2, param2: bool = false) -> void:
	if param2 == true:
		return
	super.set_destination(param1, param2)
