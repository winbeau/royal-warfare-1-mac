# 移植自 S/gameCore/levels/level19.as
class_name Level19
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_montGrassRocks"
	level_caption = "Troll's path"
	level_description = "The way to the north passed through the Trolls path. Those big green creatures were extremely dangerous because of their ability to regenerate their wounds. But we had no choice."
	level_xml_path = "data/levels/level19.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(4000)
