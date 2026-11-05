# 移植自 S/gameCore/levels/level15.as
class_name Level15
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
func _init() -> void:
	level_bg = "level_island"
	level_caption = "Island defence"
	level_description = "Fortius's last known location was here, in Millbrick. We landed and fought our way to his house, but he wasn't there. Priests examined papers, and decided, that Fortius had departed some time ago, and now might be hiding somewhere on the southern islands. On the way back we were blocked on the island by an undead counterattack."
	level_xml_path = "data/levels/level15.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	GameUniverse.inst.set_lives(8)
	GameUniverse.inst.reset_money(900)
	game_uni = GameUniverse.inst
	ar_swarm = ArrowSwarm.inst
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_BLUEMAGE, null, 1, true)
	_loc1_.set_external_position(Vector2(445, 268))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_PRIEST, null, 1, true)
	_loc1_.set_external_position(Vector2(400, 282))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 1, true)
	_loc1_.set_external_position(Vector2(395, 238))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WARRIOR, null, 1, true)
	_loc1_.set_external_position(Vector2(408, 352))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 1, true)
	_loc1_.set_external_position(Vector2(466, 159))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 1, true)
	_loc1_.set_external_position(Vector2(454, 196))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 1, true)
	_loc1_.set_external_position(Vector2(476, 353))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ARCHER, null, 1, true)
	_loc1_.set_external_position(Vector2(500, 400))
