# 移植自 S/gameCore/levels/level23.as
class_name Level23
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_montTwo"
	level_caption = "Mountain pass"
	level_description = "We'd almost done it. We had only to pass over this mountains to to reach to the plains. From there, we could rush into the Undead King's castle."
	level_xml_path = "data/levels/level23.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(800)
