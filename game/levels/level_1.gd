# 移植自 S/gameCore/levels/level1.as
class_name Level1
extends LevelTemplate

var game_uni: GameUniverse
var need_to_show_tutor: int
var need_to_show_focus_on_warriors: bool
var need_to_show_focus_on_next_wave: bool = true
var need_to_show_focus_on_upgrade: bool
var is_upgrade_text_not_shown: bool
var need_to_show_tutorial_two: bool
var tutorial_two_time: int
var caption_added: bool
func _init() -> void:
	need_to_show_focus_on_warriors = false
	need_to_show_focus_on_next_wave = true
	need_to_show_focus_on_upgrade = false
	is_upgrade_text_not_shown = true
	need_to_show_tutorial_two = false
	level_bg = "level_field_road"
	level_xml_path = "data/levels/level1.xml"
	level_caption = "The journey begins"
	level_description = "King Aldric, Taggart, and a few warriors waited for the rest of our troops. At first we were happy to see movement on the road. But... Gods! Those were not our men. A large group of undead marched towards us. " + "\n" + "King Aldric must survive the battle."
	game_uni = GameUniverse.inst
	tutorial_two_time = 0
	need_to_show_tutor = 0

func chat_closed() -> void:
	if need_to_show_focus_on_warriors:
		need_to_show_focus_on_warriors = false
		HintsManager.need_to_show_hint(4)

func is_upgrade_allowed(param1: int) -> bool:
	return false

func clicked_upgrade_itself(param1) -> void:
	pass

func clicked_got_upgrade(param1) -> void:
	pass

func show_upgrading_focus() -> void:
	pass

func upgrade_sign_showed() -> void:
	pass

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_ARCHERS, LivingObject.BUTTON_MAGES, LivingObject.BUTTON_THIEVES, LivingObject.BUTTON_PRIESTS, LivingObject.FR_KNIGHT])

func clear_data() -> void:
	pass

func loading_completed_handler() -> void:
	caption_added = false
	LevelIntro.is_shown = false
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(254, 279))
	_loc1_.set_view_direction = -1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 2, true)
	_loc1_.set_external_position(Vector2(275, 402))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_KING, null, 3, true)
	_loc1_.set_external_position(Vector2(275, 341))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 3, true)
	_loc1_.set_external_position(Vector2(314, 294))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 3, true)
	_loc1_.set_external_position(Vector2(331, 389))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLUEMAGE, null, 3, true)
	_loc1_.set_external_position(Vector2(323, 339))
	_loc1_.unlock_abils_set_max_level()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_PRIEST, null, 2, true)
	_loc1_.set_external_position(Vector2(226, 384))
	_loc1_.unlock_abils_set_max_level()
	GameUniverse.inst.set_lives(14)
	GameUniverse.inst.reset_money(250)

func got_text(param1: String) -> void:
	if param1 == "Taggart: We need more footmen! Hire three Swordsmen or a Swordmaster!":
		need_to_show_focus_on_warriors = true

func clicked_hint() -> void:
	if caption_added:
		caption_added = false
		remove_click_hint_caption()

func level_custom_actions() -> void:
	if game_uni.global_counter == 60:
		Main.inst.add_tutorial(1)
	if game_uni.global_counter == 14 * 30:
		HintsManager.need_to_show_hint(2)
		add_click_hint_caption()
	if game_uni.global_counter == 120 * 30:
		HintsManager.need_to_show_hint(3)

func remove_click_hint_caption() -> void:
	HintsManager.hide_temp_hint()

func add_click_hint_caption() -> void:
	caption_added = true
	HintsManager.show_temp_hint()
