# 移植自 S/gameCore/levels/level2.as
class_name Level2
extends LevelTemplate

var game_uni: GameUniverse
var skip_button
var is_upgrade_hint_shown: bool
func _init() -> void:
	level_bg = "level9bg_swamp2"
	level_xml_path = "data/levels/level2.xml"
	level_caption = "Archers"
	level_description = "King Aldric departed. Taggart and his men went forth into the island. There were too many undead on our way, and it is a better option to kill them at a distance. We needed more ranged fighters, and soon we found them."
	game_uni = GameUniverse.inst

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_MAGES, LivingObject.BUTTON_THIEVES, LivingObject.BUTTON_PRIESTS, LivingObject.FR_KNIGHT, LivingObject.FR_CROSSBOW])

func loading_completed_handler() -> void:
	is_upgrade_hint_shown = false
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_SNIPER, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(389, 324))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 2, true)
	_loc1_.set_external_position(Vector2(362, 291))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 1, true)
	_loc1_.set_external_position(Vector2(-110, 375))
	_loc1_.set_ext_route([Vector2(153, 369)])
	_loc1_.zero_point = Vector2(153, 369)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLUEMAGE, null, 1, true)
	_loc1_.set_external_position(Vector2(-110, 355))
	_loc1_.set_ext_route([Vector2(143, 379)])
	_loc1_.zero_point = Vector2(143, 379)
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 2, true)
	_loc1_.set_external_position(Vector2(401, 253))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 2, true)
	_loc1_.set_external_position(Vector2(289, 290))
	_loc1_.set_view_direction = 1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 2, true)
	_loc1_.set_external_position(Vector2(508, 261))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_PRIEST, null, 2, true)
	_loc1_.set_external_position(Vector2(534, 416))
	_loc1_.set_ext_route([Vector2(425, 411)])
	_loc1_.zero_point = Vector2(425, 411)
	_loc1_.health = 14
	var _loc2_: LivingObject = _loc1_
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
	_loc1_.set_external_position(Vector2(253, 342))
	_loc1_.set_ext_route([Vector2(553, 294)])
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_GRAY_ZOMBIE, 1, 1)
	_loc1_.set_external_position(Vector2(209, 305))
	_loc1_.set_ext_route([Vector2(553, 294)])
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, 1)
	_loc1_.set_external_position(Vector2(223, 246))
	_loc1_.set_ext_route([Vector2(553, 294)])
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, 1)
	_loc1_.set_external_position(Vector2(540, 253))
	_loc1_.set_ext_route([Vector2(253, 342)])
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_GRAY_ZOMBIE, 1, 1)
	_loc1_.set_external_position(Vector2(553, 294))
	_loc1_.set_ext_route([Vector2(253, 342)])
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
	_loc1_.set_external_position(Vector2(578, 421))
	_loc1_.set_ext_route([Vector2(-50, 294)])
	_loc1_.set_target(_loc2_)
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, 1, 1)
	_loc1_.set_external_position(Vector2(640, 379))
	_loc1_.set_ext_route([Vector2(-50, 294)])
	_loc1_.set_target(_loc2_)
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON_ARCHER, 1, 1)
	_loc1_.set_external_position(Vector2(578, 330))
	_loc1_.set_ext_route([Vector2(-50, 294)])
	_loc1_.attacking_with_ranged_weapon = true
	_loc1_.set_target(_loc2_)
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(750)

func is_upgrade_allowed(param1: int) -> bool:
	if param1 == LivingObject.FR_BLUEMAGE:
		return false
	return true

func upgrade_sign_showed() -> void:
	if is_upgrade_hint_shown == false:
		is_upgrade_hint_shown = true
		MainGameUIEx.inst.select_next_unit_with_upgrade()
		# TweenMax.delayedCall；经节点路径取 RWTween 自动加载，使 --script/--check-only 模式下也能解析本文件。
		(Engine.get_main_loop() as SceneTree).root.get_node("RWTween").delayed_call(0.3, call_hint_upgrade)

func call_hint_upgrade() -> void:
	Main.inst.add_tutorial(6)

func level_custom_actions() -> void:
	if game_uni.global_counter == 16 * 30:
		HintsManager.need_to_show_hint(5)
	if game_uni.global_counter == 90 * 30:
		HintsManager.need_to_show_hint(7)
