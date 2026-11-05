# 移植自 S/gameCore/levels/level12.as
class_name Level12
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_shore_two"
	level_caption = "King's Camp"
	level_description = "We had finally left the lands of the undead. The King's camp was surely somewhere on this island. In an attempt to find it we sent scouts in all directions."
	level_xml_path = "data/levels/level12.xml"

func loading_completed_handler() -> void:
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(1000)
	game_uni = GameUniverse.inst
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 1, true)
	_loc1_.set_external_position(Vector2(406, 219))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 1, true)
	_loc1_.set_external_position(Vector2(395, 263))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 1, true)
	_loc1_.set_external_position(Vector2(413, 303))

func level_custom_actions() -> void:
	pass
