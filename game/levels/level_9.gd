# 移植自 S/gameCore/levels/level9.as
class_name Level9
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_grass_hills"
	level_caption = "Black mage's tomb"
	level_description = "It looked like there was a battle here just a few hours ago. We saw dozens of undead bodies, then noticed two survivors near a tombstone."
	level_xml_path = "data/levels/level9.xml"
	game_uni = GameUniverse.inst

func level_custom_actions() -> void:
	pass

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_ARCHERS, LivingObject.BUTTON_MAGES, LivingObject.BUTTON_THIEVES, LivingObject.BUTTON_PRIESTS, LivingObject.BUTTON_WARRIORS])

func loading_completed_handler() -> void:
	var _loc1_: LivingObject = null
	GameUniverse.inst.set_lives(12)
	GameUniverse.inst.reset_money(200)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLACKMAGE, null, 2, true)
	_loc1_.set_external_position(Vector2(436, 401))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLACKMAGE, null, 2, true)
	_loc1_.set_external_position(Vector2(382, 408))
	_loc1_.set_view_direction = -1
	_loc1_.unlock_abils_set_max_level()
