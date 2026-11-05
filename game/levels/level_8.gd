# 移植自 S/gameCore/levels/level8.as
class_name Level8
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_steppes"
	level_caption = "Swamp"
	level_description = "Despite the fact that the royal forces had left the mainland, there were still many small groups of soldiers. Locals from a small village told us that a group of crossbowmen marched into the swamps a few hours ago. We went after them."
	level_xml_path = "data/levels/level8.xml"
	game_uni = GameUniverse.inst

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	var _loc1_: LivingObject = null
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(800)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 1, true)
	_loc1_.set_external_position(Vector2(405, 250))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 2, true)
	_loc1_.set_external_position(Vector2(440, 260))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_CROSSBOW, null, 3, true)
	_loc1_.set_external_position(Vector2(460, 280))
	_loc1_.set_view_direction = -1
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_CROSSBOW, null, 3, true)
	_loc1_.set_external_position(Vector2(455, 350))
	_loc1_.set_view_direction = -1
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_CROSSBOW, null, 3, true)
	_loc1_.set_external_position(Vector2(465, 330))
	_loc1_.set_view_direction = -1
	_loc1_.unlock_abils_set_max_level()

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.FR_BLESSER, LivingObject.FR_BLACKMAGE, LivingObject.FR_SABOTEUR])
