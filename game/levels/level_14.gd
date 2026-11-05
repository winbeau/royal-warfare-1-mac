# 移植自 S/gameCore/levels/level14.as
class_name Level14
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_street"
	level_caption = "On the streets"
	level_description = "Who said that Tardoc is a nice place to stay? The local undead weren't too happy to see us. Well, we had no choice - our supplies were too low, and it was the only place to resupply."
	level_xml_path = "data/levels/level14.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(1560)
	game_uni = GameUniverse.inst
