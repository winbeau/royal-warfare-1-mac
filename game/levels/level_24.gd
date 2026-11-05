# 移植自 S/gameCore/levels/level24.as
class_name Level24
extends LevelTemplate

static var support_counter: int
var game_uni: GameUniverse
func _init() -> void:
	level_bg = "level_final"
	level_caption = "Undead King's chambers"
	level_description = "We joined King Aldric, who laid siege to the undead stronghold. While most troops fought on the walls, a small team of heroes fought its way into the Undead King's chambers. King Aldric was with them. " + "\n" + "King Aldric must survive the battle."
	level_xml_path = "data/levels/level24.xml"

func level_custom_actions() -> void:
	pass

func loading_completed_handler() -> void:
	var _loc1_: LivingObject = null
	game_uni = GameUniverse.inst
	support_counter = 0
	GameUniverse.inst.set_lives(10)
	GameUniverse.inst.reset_money(100)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 3, true)
	_loc1_.set_external_position(Vector2(453, 253))
	_loc1_.set_view_direction = 1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 3, true)
	_loc1_.set_external_position(Vector2(418, 298))
	_loc1_.set_view_direction = 1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_KING, null, 3, true)
	_loc1_.set_external_position(Vector2(393, 209))
	_loc1_.set_view_direction = 1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SNIPER, null, 3, true)
	_loc1_.set_external_position(Vector2(363, 260))
	_loc1_.set_view_direction = -1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_CROSSBOW, null, 3, true)
	_loc1_.set_external_position(Vector2(327, 299))
	_loc1_.set_view_direction = -1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SABOTEUR, null, 3, true)
	_loc1_.set_external_position(Vector2(337, 209))
	_loc1_.set_view_direction = -1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ASSASIN, null, 3, true)
	_loc1_.set_external_position(Vector2(274, 278))
	_loc1_.set_view_direction = -1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLESSER, null, 3, true)
	_loc1_.set_external_position(Vector2(398, 252))
	_loc1_.set_view_direction = 1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_REDMAGE, null, 3, true)
	_loc1_.set_external_position(Vector2(280, 225))
	_loc1_.set_view_direction = -1
	_loc1_ = game_uni.add_soldier(LivingObject.FR_HEALER, null, 3, true)
	_loc1_.set_external_position(Vector2(311, 249))
	_loc1_.set_view_direction = -1
