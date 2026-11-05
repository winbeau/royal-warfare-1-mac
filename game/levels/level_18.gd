# 移植自 S/gameCore/levels/level18.as
class_name Level18
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_graves"
	level_caption = "Cemetery"
	level_description = "Wiseman Fortius led us to an old temple, where in an ancient library could be found any answers to any question. The temple was situated in the center of an ancient cemetery. It wasn't the safest place in the world."
	level_xml_path = "data/levels/level18.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(3000)
