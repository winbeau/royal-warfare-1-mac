# STUB: 待移植（P3/P5）
# 移植自 S/gameCore/ifaces/mainGameUI_ex.as；只声明 GameUniverse 调用到的成员，方法体为空。
class_name MainGameUIEx
extends Node2D

static var inst: MainGameUIEx
static var is_attack_button_clicked: bool = false
static var is_formation_clicked: bool = false

var e_fader: Control = Control.new()

func _init() -> void:
	inst = self

func unlock_units() -> void:
	pass

func set_money() -> void:
	pass

func show_unit_panel() -> void:
	pass

func hide_unit_panel() -> void:
	pass

func draw_lives(_lives: float) -> void:
	pass

func unit_dead(_unit: LivingObject) -> void:
	pass

func disable_menu() -> void:
	pass

func reset_attack_def_button() -> void:
	pass

func reset_formation_button() -> void:
	pass

func hide_has_upgrade_button(_unit: LivingObject) -> void:
	pass

func draw_current_wave(_cur_wave: int, _total_waves: int) -> void:
	pass

func hide_red_button() -> void:
	pass

func show_red_button() -> void:
	pass

func update_red_button(_counter: int) -> void:
	pass

func update_soldier_data() -> void:
	pass

func update_data() -> void:
	pass

func enable_attack_def_button() -> void:
	pass

func enable_formation_button() -> void:
	pass

func click_archers() -> void:
	pass

func defend_button_clicked() -> void:
	pass

func select_next_unit_with_upgrade() -> void:
	pass

func call_controlled_pause() -> void:
	pass

func disable_defend_button_animation() -> void:
	pass

# 以下成员由 P2-B（LivingObject）追加
var cost_multiplier: float = 0.5

func show_has_upgrade_button(_unit: LivingObject) -> void:
	pass

# --- 由 P2-A2 追加（关卡类用到的成员） ---
func lock_units(_units: Array) -> void:
	pass

func enable_archers_button() -> void:
	pass

func update_b_archers_cooldown(_status: int) -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if e_fader != null and is_instance_valid(e_fader) and e_fader.get_parent() == null:
			e_fader.free()
		if inst == self:
			inst = null
