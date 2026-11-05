# 移植自 S/gameCore/levels/level5.as
class_name Level5
extends LevelTemplate

var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_shore"
	level_caption = "Thieves"
	level_description = "We reached the beach and marched towards the harbor. There we met our sworn enemies - assasins and thieves from the Rogue league. We needed some fast and deadly units, so we united. For now…"
	level_xml_path = "data/levels/level5.xml"
	game_uni = GameUniverse.inst

func loading_completed_handler() -> void:
	game_uni.set_lives(20)
	game_uni.reset_money(500)
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_ASSASIN, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(331, 242))
	var _loc2_: LivingObject = _loc1_
	_loc1_ = game_uni.load_enemy(LivingObject.UNDEAD_SKELETON, 1, RWRandom.rand_range(1, 4), Vector2(361, 264))
	_loc1_.modify_first_point()
	_loc1_.set_view_direction = -1
	_loc1_.set_target(_loc2_)
	_loc1_ = game_uni.load_enemy(LivingObject.UNDEAD_SKELETON_ARM, 1, RWRandom.rand_range(1, 4), Vector2(361, 242))
	_loc1_.modify_first_point()
	_loc1_.set_view_direction = -1
	_loc1_.set_target(_loc2_)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ROGUE, null, 1, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(342, 300))
	_loc2_ = _loc1_
	_loc1_ = game_uni.load_enemy(LivingObject.UNDEAD_SKELETON_ARM, 1, RWRandom.rand_range(1, 4), Vector2(361, 300))
	_loc1_.modify_first_point()
	_loc1_.set_view_direction = -1
	_loc1_.set_target(_loc2_)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ROGUE, null, 1, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(362, 200))
	_loc2_ = _loc1_
	_loc1_ = game_uni.load_enemy(LivingObject.UNDEAD_SKELETON_ARM, 1, RWRandom.rand_range(1, 4), Vector2(382, 200))
	_loc1_.modify_first_point()
	_loc1_.set_view_direction = -1
	_loc1_.set_target(_loc2_)

func level_custom_actions() -> void:
	var _loc1_: LivingObject = null
	if game_uni.global_counter == 400:
		HintsManager.need_to_show_hint(11)
	if game_uni.global_counter == 650:
		_loc1_ = game_uni.add_soldier(LivingObject.FR_ROGUE, null, 3, true)
		_loc1_.unlock_abils_set_max_level()
		_loc1_.set_external_position(Vector2(341, 800))
		_loc1_.set_destination(Vector2(348, 500))
		_loc1_ = game_uni.add_soldier(LivingObject.FR_ROGUE, null, 1, true)
		_loc1_.unlock_abils_set_max_level()
		_loc1_.set_external_position(Vector2(321, 800))
		_loc1_.set_destination(Vector2(325, 550))

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_WARRIORS, LivingObject.BUTTON_ARCHERS, LivingObject.BUTTON_MAGES, LivingObject.BUTTON_THIEVES, LivingObject.BUTTON_PRIESTS, LivingObject.FR_CROSSBOW, LivingObject.FR_BLESSER, LivingObject.FR_BLACKMAGE, LivingObject.FR_SABOTEUR, LivingObject.FR_KNIGHT])
