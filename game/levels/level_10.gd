# 移植自 S/gameCore/levels/level10.as
class_name Level10
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_castle"
	level_caption = "In the castle"
	level_description = "We fought our way to the castle, where we joined the rest of our squad. Here we found a group of Monks, who tried to secure some ancient relics. Without our help their efforts were totally in vain."
	level_xml_path = "data/levels/level10.xml"
	game_uni = GameUniverse.inst

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	var _loc1_: LivingObject = null
	GameUniverse.inst.set_lives(16)
	GameUniverse.inst.reset_money(1200)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLESSER, null, 3, true)
	_loc1_.set_external_position(Vector2(140, 290))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLESSER, null, 3, true)
	_loc1_.set_external_position(Vector2(125, 270))
	_loc1_.set_view_direction = -1
	_loc1_.unlock_abils_set_max_level()

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.FR_SABOTEUR])
