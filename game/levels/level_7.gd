# 移植自 S/gameCore/levels/level7.as
class_name Level7
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_montBridge"
	level_caption = "Mountain bridge"
	level_description = "Marching in the mountains is not an easy task. Cold wind, heavy backpacks, dangerous animals - and the undead! They had finally surrounded us on a mountain bridge, and there was no way to maneuver, so we started the fight."
	level_xml_path = "data/levels/level7.xml"
	game_uni = GameUniverse.inst

func loading_completed_handler() -> void:
	game_uni.set_lives(15)
	game_uni.reset_money(250)
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_KNIGHT, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(340, 304))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 2, true)
	_loc1_.set_external_position(Vector2(345, 329))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 2, true)
	_loc1_.set_external_position(Vector2(336, 277))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 2, true)
	_loc1_.set_external_position(Vector2(332, 245))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 2, true)
	_loc1_.set_external_position(Vector2(345, 361))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLUEMAGE, null, 2, true)
	_loc1_.set_external_position(Vector2(369, 253))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLUEMAGE, null, 2, true)
	_loc1_.set_external_position(Vector2(375, 337))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_REDMAGE, null, 2, true)
	_loc1_.set_external_position(Vector2(361, 300))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_HEALER, null, 1, true)
	_loc1_.set_external_position(Vector2(288, 290))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ASSASIN, null, 2, true)
	_loc1_.set_external_position(Vector2(283, 220))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ASSASIN, null, 2, true)
	_loc1_.set_external_position(Vector2(290, 394))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SNIPER, null, 1, true)
	_loc1_.set_external_position(Vector2(365, 214))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SNIPER, null, 2, true)
	_loc1_.set_external_position(Vector2(386, 201))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 1, true)
	_loc1_.set_external_position(Vector2(412, 387))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 2, true)
	_loc1_.set_external_position(Vector2(390, 384))

func level_custom_actions() -> void:
	pass

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_WARRIORS, LivingObject.BUTTON_ARCHERS, LivingObject.BUTTON_MAGES, LivingObject.BUTTON_THIEVES, LivingObject.BUTTON_PRIESTS, LivingObject.FR_CROSSBOW, LivingObject.FR_BLESSER, LivingObject.FR_BLACKMAGE, LivingObject.FR_SABOTEUR])
