# 移植自 S/gameCore/levels/level4.as
class_name Level4
extends LevelTemplate

var game_uni: GameUniverse
var ar_swarm: ArrowSwarm
var cd_status: int
func _init() -> void:
	level_bg = "level8bg_swamp1"
	level_caption = "Wizards"
	level_description = "To survive in war every squad needs weapons of mass destruction. Battle mages are a good option. While we marched forward, scouts had noticed lightning strikes at the river bank. Taggart sent a few warriors to check it out."
	level_xml_path = "data/levels/level4.xml"

func b_archers_clicked() -> void:
	ar_swarm.add_swarm(ar_swarm.RIGHT, 50, 0.88, 18, 18, game_uni.mouse_x, game_uni.mouse_y, 155, 155)

func loading_completed_handler() -> void:
	game_uni = GameUniverse.inst
	ar_swarm = ArrowSwarm.inst
	ar_swarm.set_cool_down(20)
	GameUniverse.inst.set_lives(20)
	GameUniverse.inst.reset_money(1100)
	game_uni.ingame_ui.enable_archers_button()
	var _loc1_: LivingObject = game_uni.add_soldier(LivingObject.FR_REDMAGE, null, 3, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(420, 320))
	_loc1_.set_destination(Vector2(600, 258))
	_loc1_ = game_uni.add_soldier(LivingObject.FR_BLUEMAGE, null, 1, true)
	_loc1_.unlock_abils_set_max_level()
	_loc1_.set_external_position(Vector2(430, 290))
	_loc1_.set_destination(Vector2(610, 250))
	_loc1_.is_defence_stance = true
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, RWRandom.rand_range(3, 4), Vector2(142, 422))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_GRAY_ZOMBIE, 1, RWRandom.rand_range(3, 4), Vector2(155, 420))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, RWRandom.rand_range(3, 4), Vector2(150, 236))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, RWRandom.rand_range(1, 2), Vector2(132, 95))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, RWRandom.rand_range(1, 2), Vector2(132, 95))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_GRAY_ZOMBIE, 1, RWRandom.rand_range(1, 2), Vector2(139, 105))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, RWRandom.rand_range(1, 2), Vector2(157, 72))
	_loc1_.modify_first_point()
	_loc1_ = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_ZOMBIE, 1, RWRandom.rand_range(1, 2), Vector2(157, 88))
	_loc1_.modify_first_point()

func get_locked_units() -> void:
	GameUniverse.inst.ingame_ui.lock_units([LivingObject.BUTTON_THIEVES, LivingObject.FR_KNIGHT, LivingObject.FR_CROSSBOW, LivingObject.FR_BLESSER, LivingObject.FR_HEALER, LivingObject.FR_BLACKMAGE])

func level_custom_actions() -> void:
	if game_uni.global_counter == 300:
		HintsManager.need_to_show_hint(9)
		HintsManager.need_to_show_hint(10)
	cd_status = ar_swarm.update_arrow_swarm()
	game_uni.ingame_ui.update_b_archers_cooldown(cd_status)
