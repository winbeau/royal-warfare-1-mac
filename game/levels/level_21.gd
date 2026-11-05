# 移植自 S/gameCore/levels/level21.as
class_name Level21
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level7bg_sandy_rocky2"
	level_caption = "Portal"
	level_description = "We came to this sandy and rocky land to find the Darth portal. There was no time to search it with our whole squad, so we split into small groups."
	level_xml_path = "data/levels/level21.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	GameUniverse.inst.set_lives(16)
	GameUniverse.inst.reset_money(2000)
