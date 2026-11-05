# 移植自 S/gameCore/levels/level13.as
class_name Level13
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level9bg_elki"
	level_caption = "Seven Heroes"
	level_description = "While our main forces prepared for departure, a large group of undead struck a surprise attack on our scouts."
	level_xml_path = "data/levels/level13.xml"

func loading_completed_handler() -> void:
	GameUniverse.inst.set_lives(10)
	GameUniverse.inst.reset_money(200)
	game_uni = GameUniverse.inst
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 2, true)
	_loc1_.set_external_position(Vector2(331, 278))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLESSER, null, 2, true)
	_loc1_.set_external_position(Vector2(342, 232))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SNIPER, null, 2, true)
	_loc1_.set_external_position(Vector2(380, 254))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLACKMAGE, null, 2, true)
	_loc1_.set_external_position(Vector2(380, 307))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_CROSSBOW, null, 2, true)
	_loc1_.set_external_position(Vector2(383, 345))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_KNIGHT, null, 2, true)
	_loc1_.set_external_position(Vector2(328, 446))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ASSASIN, null, 2, true)
	_loc1_.set_external_position(Vector2(354, 414))

func level_custom_actions() -> void:
	pass
