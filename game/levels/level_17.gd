# 移植自 S/gameCore/levels/level17.as
class_name Level17
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
var cd_status: int
func _init() -> void:
	level_bg = "level_sands"
	level_caption = "Wiseman Fortuis"
	level_description = "Yes, we found him. The old man found a safe place on the Dead island. It is a real no man's land, but there were also no undead. Untill now. " + "\n" + "They traced us, and now it's time to deal with them." + "\n" + "Fortius must survive the battle."
	level_xml_path = "data/levels/level17.xml"

func b_archers_clicked() -> void:
	ar_swarm.add_swarm(ar_swarm.LEFT, 60, 0.88, 20, 18, game_uni.mouse_x, game_uni.mouse_y, 150, 150)

func level_custom_actions() -> void:
	cd_status = ar_swarm.update_arrow_swarm()
	game_uni.ingame_ui.update_b_archers_cooldown(cd_status)

func loading_completed_handler() -> void:
	var _loc1_: LivingObject = null
	game_uni = GameUniverse.inst
	ar_swarm = ArrowSwarm.inst
	ar_swarm.set_cool_down(30)
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(3200)
	game_uni.ingame_ui.enable_archers_button()
	_loc1_ = game_uni.add_soldier(LivingObject.FR_WISEMAN, null, 3, true)
	_loc1_.set_external_position(Vector2(421, 348))
	_loc1_.set_ext_route([Vector2(323, 355)])
	_loc1_.zero_point = Vector2(323, 355)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SWORDMASTER, null, 1, true)
	_loc1_.set_external_position(Vector2(151, 319))
	_loc1_.set_ext_route([Vector2(212, 320)])
	_loc1_.zero_point = Vector2(212, 320)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_SNIPER, null, 1, true)
	_loc1_.set_external_position(Vector2(126, 355))
	_loc1_.set_ext_route([Vector2(187, 355)])
	_loc1_.zero_point = Vector2(187, 355)
	_loc1_ = game_uni.add_soldier(LivingObject.FR_ASSASIN, null, 1, true)
	_loc1_.set_external_position(Vector2(159, 393))
	_loc1_.set_ext_route([Vector2(219, 402)])
	_loc1_.zero_point = Vector2(219, 402)
