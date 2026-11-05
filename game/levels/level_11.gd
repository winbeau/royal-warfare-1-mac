# 移植自 S/gameCore/levels/level11.as
class_name Level11
extends LevelTemplate

var game_uni: GameUniverse
var need_to_show_tutorial: bool
var tutorial_time: int
func _init() -> void:
	level_bg = "level_river_bridge"
	level_caption = "Spies"
	level_description = "Marcus had met his friends - spies from the Guild. They told us that on the other bank of the river hordes of the undead are marching, and we need to hold the bridge long enough to let our caravan pass to the shore."
	level_xml_path = "data/levels/level11.xml"

func level_custom_actions() -> void:
	if need_to_show_tutorial:
		need_to_show_tutorial = false
		HintsManager.need_to_show_hint(12)

func loading_completed_handler() -> void:
	GameUniverse.inst.set_lives(10)
	GameUniverse.inst.reset_money(100)
	game_uni = GameUniverse.inst
	need_to_show_tutorial = false
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_SABOTEUR, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(230, 185))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SABOTEUR, null, 3, true)
	_loc1_.set_external_position(Vector2(196, 327))
	_loc1_.unlock_abils_set_max_level()

func got_text(param1: String) -> void:
	if param1 == "Puntis: I need some time to hide in shadows. Next, help me to get as close as possible to the archers and casters: I'll disable them for a few minutes.":
		need_to_show_tutorial = true
		tutorial_time = game_uni.global_counter
