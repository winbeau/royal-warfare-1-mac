# 移植自 S/gameCore/ifaces/mainGameUI_ex.as（战斗主界面：顶栏、左侧兵种栏、单位面板、右下按钮等）
#
# 与原版的对应方式：
# - 原版 `mainGameUI_ex extends mainGameUI`，符号类 mainGameUI 的实例字段（eUnitPanel、e1…）在这里是 BIND 出来的
#   成员变量（snake_case）。核心有 `new MainGameUIEx()` 的调用，因此 `_init` 走 IfaceUtil.adopt（等价于符号类构造函数
#   建出子对象）；从继承场景 scenes/ifaces/main_game_ui_ex.tscn 实例化时，子节点已存在，由 SCENE_INSTANTIATED 通知绑定。
# - 原版构造函数 + ADDED_TO_STAGE 的 added()：构造部分与 added() 部分都在 FlashClip._ready 之后执行（FlashClip._ready 会按
#   时间轴第 1 帧重置子节点的位置/可见性，所以不能更早）；之后每次重新挂回场景树（_enter_tree）重新执行 added()，
#   离开场景树（_exit_tree）执行 removed()。
# - Event.DEACTIVATE 对应 NOTIFICATION_APPLICATION_FOCUS_OUT。
# - TweenMax 全部对应 RWTween（pauseAll/resumeAll 同理）。
# - 能力图标：原版用 BmpFrames 把 eAbility 逐帧烘成位图再挂 Bitmap；这里直接让 eAbility 停在对应帧（等价画面）。
# - cacheAsBitmap（Rasterizer.rasterize）、GlowFilter（glowingSwordFilter 在原版里创建后从未使用）不移植。
# - 站点相关（Main.self.loadMoreGames 的外链、hintsManager 等其他类）通过 IfaceUtil.main()/动态调用，缺失时跳过。
class_name MainGameUIEx
extends FlashClip

const SCENE := "res://scenes/ifaces/main_game_ui_ex.tscn"

# ---- 静态成员 ----
static var is_attack_button_clicked: bool = false   # 原版 _isAttackButtonClicked（getter/setter 包装）
static var is_formation_clicked: bool = false       # 原版 _isFormationClicked
static var inst: MainGameUIEx                       # 原版 instance

# ---- 公有字段 ----
var b_archers_cooldown: bool = false
var cost_multiplier: float = 0.5

# ---- 符号类 mainGameUI 的实例字段 ----
var arrow_target_circle: FlashClip
var e_unit_panel: FlashClip
var e_money: FlashClip
var e_hp: FlashClip
var e_wave: FlashClip
var e_next_wave_pad: FlashClip
var small_vert: FlashClip
var small_horiz: FlashClip
var e_game_paused_message: FlashClip
var e_sens_archers: FlashClip
var e_menu: FlashClip
var e_help: FlashClip
var e_pause: FlashClip
var e_speed_up: FlashClip
var e_new_hint: FlashClip
var e_new_enemy: FlashClip
var e_left_panel: FlashClip
var e1: FlashClip
var e4: FlashClip
var e2: FlashClip
var e3: FlashClip
var e5: FlashClip
var e_sub_down: FlashClip
var e_sub_one: FlashClip
var e_sub_two: FlashClip
var e_sub_three: FlashClip
var e_got_upgrade: FlashClip
var e_horiz: FlashClip
var e_vert: FlashClip
var e_formation: FlashClip
var e_attack_def: FlashClip
var e_defend: FlashClip
var e_chat: FlashClip
var b_archers: FlashClip
var e_max_games: FlashClip
## GameUniverse 在界面进入场景树之前就会访问它；未绑定子节点时（极端情形）用占位 Control 兜底。
var e_fader: Control = Control.new()
var t_chat_box: FlashClip
var t_pause_message: FlashClip
var e_focus: FlashClip
var e_hint: FlashClip
var e_small_hint: FlashClip

# ---- 私有字段（原名 snake_case）----
var unit_panel_y: float = 0.0
var dest_money: int = 0
var cur_money: int = 0
var a_buttons: Array = []
var scale_: float = 1.0   # 原 `scale`，与 Control.scale 冲突故改名
var warrior_cool_down_status: int = 0
var archer_cool_down_status: int = 0
var mage_cool_down_status: int = 0
var priest_cool_down_status: int = 0
var rogue_cool_down_status: int = 0
var warrior_last_built_time: int = 0
var archer_last_built_time: int = 0
var mage_last_built_time: int = 0
var priest_last_built_time: int = 0
var rogue_last_built_time: int = 0
var unit_select_panel_coords: Vector2 = Vector2.ZERO
var e_upgrade_panel_coords: Vector2 = Vector2.ZERO
var last_unit: LivingObject = null
var right_button_hided_coord_y: float = 567.0
var right_button_showed_coord_y: float = 546.0
var chat_controll: ChatController
var sub_units_panel_y: float = 0.0
var a_sub_units_panel: Array = []
var sub_units_panel_down_y: float = 0.0
var last_clicked_unit_number: int = 0
var e_upgrade_down_coord: float = -62.0
var num_units_waiting_upgrade: int = 0
var a_units_waiting_upgrade: Array = []
var cur_unit_with_upgrade_index: int = 0
var a_locked_units_and_buttons: Array = []
var red_button_shown: bool = false
var a_disabled_buttons: Array = []
var archers_clicked: bool = false
var level_class_name_coord: float = 0.0
var s: SoundLibrary
const BOTTOM_LEFT_PANEL_COORDS := Vector2(540, 584)
var game_uni: GameUniverse
var e_game_paused_message_coords: Vector2 = Vector2.ZERO

# ---- Godot 适配状态（原版没有）----
var _bound: bool = false
var _attached: bool = false     # added() 已执行且尚未 removed()
var _first_ready_done: bool = false
var _pending_ops: Array = []   # 界面尚未 ready 时收到的 lock/unlock 请求（见 _apply_pending_locks）


static func create() -> MainGameUIEx:
	return IfaceUtil.instantiate(SCENE) as MainGameUIEx


func _init() -> void:
	inst = self
	if IfaceUtil.instantiating:
		return
	IfaceUtil.adopt(self, "mainGameUI")
	_bind()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_bind()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# 原版 stage.addEventListener(Event.DEACTIVATE, flashDeactive)：仅在 added() 与 removed() 之间有效
		if _attached:
			flash_deactive()
	elif what == NOTIFICATION_PREDELETE:
		if e_fader != null and is_instance_valid(e_fader) and e_fader.get_parent() == null:
			e_fader.free()
		if inst == self:
			inst = null


func _c(path: String) -> FlashClip:
	return get_node_or_null(NodePath(path)) as FlashClip


func _bind() -> void:
	if _bound:
		return
	arrow_target_circle = _c("arrowTargetCircle")
	e_unit_panel = _c("eUnitPanel")
	e_money = _c("eMoney")
	e_hp = _c("eHp")
	e_wave = _c("eWave")
	e_next_wave_pad = _c("eNextWavePad")
	small_vert = _c("smallVert")
	small_horiz = _c("smallHoriz")
	e_game_paused_message = _c("eGamePausedMessage")
	e_sens_archers = _c("eSensArchers")
	e_menu = _c("eMenu")
	e_help = _c("eHelp")
	e_pause = _c("ePause")
	e_speed_up = _c("eSpeedUp")
	e_new_hint = _c("eNewHint")
	e_new_enemy = _c("eNewEnemy")
	e_left_panel = _c("eLeftPanel")
	e1 = _c("e1")
	e4 = _c("e4")
	e2 = _c("e2")
	e3 = _c("e3")
	e5 = _c("e5")
	e_sub_down = _c("eSubDown")
	e_sub_one = _c("eSubOne")
	e_sub_two = _c("eSubTwo")
	e_sub_three = _c("eSubThree")
	e_got_upgrade = _c("eGotUpgrade")
	e_horiz = _c("eHoriz")
	e_vert = _c("eVert")
	e_formation = _c("eFormation")
	e_attack_def = _c("eAttackDef")
	e_defend = _c("eDefend")
	e_chat = _c("eChat")
	b_archers = _c("bArchers")
	e_max_games = _c("eMaxGames")
	var fader := _c("eFader")
	if fader != null:
		if e_fader != null and is_instance_valid(e_fader) and e_fader.get_parent() == null:
			e_fader.free()
		e_fader = fader
	t_chat_box = _c("tChatBox")
	t_pause_message = _c("tPauseMessage")
	e_focus = _c("eFocus")
	e_hint = _c("eHint")
	e_small_hint = _c("eSmallHint")
	_bound = e_unit_panel != null


# ================================================================ 构造函数 + added()

func _ready() -> void:
	super._ready()
	if data == null or not _bound:
		return
	_construct()
	_first_ready_done = true
	_added()


func _enter_tree() -> void:
	# 首次进入时 _ready 尚未执行（FlashClip 还没建好图层），由 _ready 调用 _added()
	if _first_ready_done and not _attached:
		_added()


func _exit_tree() -> void:
	if _attached:
		_removed()


## 原版构造函数 mainGameUI_ex()。
func _construct() -> void:
	HintsManager.init(e_new_enemy, e_new_hint)
	mouse_enabled = false
	t_pause_message.mouse_children = false
	t_pause_message.mouse_enabled = false
	t_pause_message.visible = false
	e_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e_fader.visible = false
	level_class_name_coord = (e_unit_panel.get_node("tLevelClass") as FlashText).position.y
	(e_unit_panel.get_node("tLevelClass") as FlashText).auto_size = "center"
	is_attack_button_clicked = false
	is_formation_clicked = false
	unit_select_panel_coords = _unit_select().position
	_set_ability_pic(1, 0)
	_set_ability_pic(2, 0)
	chat_controll = ChatController.new()
	chat_controll.init(e_chat)
	unit_panel_y = e_unit_panel.position.y
	sub_units_panel_y = e_sub_down.position.y
	a_sub_units_panel = [e_sub_down, e_sub_one, e_sub_two, e_sub_three]
	sub_units_panel_down_y = sub_units_panel_y + IfaceUtil.clip_width(e_sub_down) + 10
	var pad: FlashClip = e_next_wave_pad.get_node("eAutostartPad")
	pad.mouse_enabled = false
	pad.mouse_children = false
	e_focus.stop()
	e_focus.visible = false
	e_focus.mouse_children = false
	e_focus.mouse_enabled = false
	ChatFrameController.init(t_chat_box, e_fader)
	e_sens_archers.visible = false
	arrow_target_circle.visible = false
	arrow_target_circle.mouse_enabled = false
	arrow_target_circle.mouse_children = false
	_cool_down_clip(b_archers).goto_and_stop(1)
	e_game_paused_message.mouse_children = false
	e_game_paused_message.mouse_enabled = false
	e_game_paused_message.visible = false
	e_game_paused_message_coords = e_game_paused_message.position


## 原版 added()（ADDED_TO_STAGE）。
func _added() -> void:
	_attached = true
	game_uni = GameUniverse.inst
	e_speed_up.get_node("eSpeedIco").goto_and_stop(1)
	HintsManager.game_started()
	s = SoundLibrary.inst
	b_archers_cooldown = true
	_set_alpha(b_archers.get_node("eIco"), 0.0)
	archers_clicked = false
	_cool_down_clip(b_archers).goto_and_stop(1)
	a_disabled_buttons = []
	_set_alpha(e_defend.get_node("eIco"), 0.0)
	ButtonClass.add_button_full(e_max_games, _rover_simple_hover, _rout_simple_hover, _more_games_clicked)
	reset_attack_def_button()
	reset_formation_button()
	a_units_waiting_upgrade = []
	num_units_waiting_upgrade = 0
	cur_unit_with_upgrade_index = 0
	inst = self
	a_buttons = [e1, e4, e3, e2, e5]
	for mc: FlashClip in a_buttons:
		ButtonClass.add_button_full(mc, _rover, _rout, _clicked)
		scale_ = mc.scale.x
		_cool_down_clip(mc).goto_and_stop(_cool_down_clip(mc).total_frames)
	ButtonClass.add_button_on_frames_rd(e_next_wave_pad.get_node("bStart"), _clicked_start_wave)
	ButtonClass.add_button_on_frames_rd(b_archers, click_archers)
	b_archers.visible = false
	e_sens_archers.visible = false
	ButtonClass.add_event_listener(e_sens_archers, ButtonClass.CLICK, _sens_archers_clicked)
	RWTween.all_from(a_buttons, 0.4, {"y": "42"}, 0.1)
	warrior_cool_down_status = 100
	archer_cool_down_status = 100
	mage_cool_down_status = 100
	priest_cool_down_status = 100
	rogue_cool_down_status = 100
	var eback: FlashClip = e_hint.get_node("eBack")
	eback.goto_and_stop(1)
	e_hint.visible = false
	e_hint.mouse_children = false
	e_hint.mouse_enabled = false
	e_unit_panel.position.y = unit_panel_y + _height_of(e_unit_panel)
	e_unit_panel.visible = false
	var up: FlashClip = e_unit_panel.get_node("eUpgrade")
	ButtonClass.add_button_lite(up, _upgrade_clicked)
	up.position.y = -89
	e_upgrade_panel_coords = up.position
	up.position.y = e_upgrade_down_coord
	_set_ability_pic(1, 0)
	e_unit_panel.get_node("eOne/eCoolDown").goto_and_stop(100)
	_set_ability_pic(2, 0)
	e_unit_panel.get_node("eTwo/eCoolDown").goto_and_stop(100)
	ButtonClass.add_button_lite(e_unit_panel.get_node("eUnitSelect/bClose"), _close_upgrade_panel)
	_manage_small_hint()
	ButtonClass.add_button_full(small_vert, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.add_button_full(small_horiz, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.add_button_full(e_vert, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.add_button_full(e_horiz, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.add_button_full(e_got_upgrade, _rover_simple_hover, _rout_simple_hover, _has_upgrade_clicked)
	ButtonClass.add_button_full(e_formation, _rover_simple_hover, _rout_simple_hover, _formation_clicked)
	ButtonClass.add_button_full(e_defend, _rover_simple_hover, _rout_simple_hover, defend_button_clicked)
	ButtonClass.add_button_full(e_attack_def, _rover_simple_hover, _rout_simple_hover, _set_attack_def_stance)
	ButtonClass.add_button_full(e_speed_up, _rover_simple_hover, _rout_simple_hover, _call_speed_up)
	ButtonClass.add_button_full(e_menu, _rover_simple_hover, _rout_simple_hover, _call_menu)
	ButtonClass.add_button_full(e_help, _rover_simple_hover, _rout_simple_hover, _call_help)
	ButtonClass.add_button_full(e_pause, _rover_simple_hover, _rout_simple_hover, call_controlled_pause)
	_rout_button(e_attack_def)
	_rout_button(e_vert)
	_rout_button(e_speed_up)
	_rout_button(e_menu)
	_rout_button(e_help)
	_rout_button(e_horiz)
	_rout_button(e_got_upgrade)
	_rout_button(e_formation)
	_rout_button(e_defend)
	_hide_right_button(e_vert)
	_hide_right_button(e_horiz)
	_hide_right_button(e_got_upgrade)
	_hide_right_button(e_formation)
	_hide_right_button(e_attack_def)
	_hide_right_button(e_defend)
	_rout_button(small_horiz)
	_rout_button(small_vert)
	_hide_right_button(small_horiz)
	_hide_right_button(small_vert)
	_unit_select().get_node("eSelector").stop()
	# 原版此处是 `eUnitSelect.y = this.unitSelectPanelCoords + 220`：Point + 数字得到字符串，
	# 对 y 赋 NaN（AS3 中对 DisplayObject.x/y 赋 NaN 被忽略），因此该语句实际上不改变位置（P-code 同）。
	# 面板随 eUnitPanel 整体隐藏，首次 showUnitPanel 调 closeUpgradePanel 才把它收到 +220。
	ButtonClass.add_button_full(_unit_select().get_node("bTop"), _rover, _rout, _basic_to_pro_clicked)
	ButtonClass.add_button_full(_unit_select().get_node("bDown"), _rover, _rout, _basic_to_pro_clicked)
	e_unit_panel.get_node("eIco").stop()
	e_money.mouse_enabled = false
	e_money.mouse_children = false
	e_hp.mouse_enabled = false
	e_hp.mouse_children = false
	e_wave.mouse_enabled = false
	e_wave.mouse_children = false
	for mc: FlashClip in a_sub_units_panel:
		mc.position.y = sub_units_panel_down_y
		mc.visible = false
		ButtonClass.add_button_full(mc, _rover, _rout, _clicked)
	_apply_pending_locks()


## 原版 removed()（REMOVED_FROM_STAGE）。原版把 added 监听重新挂回；这里由 _enter_tree 代替。
func _removed() -> void:
	_attached = false
	HintsManager.removed()
	ButtonClass.remove_button_full(e_max_games, _rover_simple_hover, _rout_simple_hover, _more_games_clicked)
	disable_menu()
	ButtonClass.remove_button_full(e_speed_up, _rover_simple_hover, _rout_simple_hover, _call_speed_up)
	ButtonClass.remove_event_listener(t_pause_message, ButtonClass.CLICK, _set_unpause)
	ButtonClass.remove_button_full(e_pause, _rover_simple_hover, _rout_simple_hover, call_controlled_pause)
	ButtonClass.remove_button_full(e_help, _rover_simple_hover, _rout_simple_hover, _call_help)
	ButtonClass.remove_button_on_frames(e_next_wave_pad.get_node("bStart"), _clicked_start_wave)
	ButtonClass.remove_button_on_frames(b_archers, click_archers)
	for mc: FlashClip in [e_unit_panel.get_node("eOne"), e_unit_panel.get_node("eTwo"), small_horiz, small_vert]:
		ButtonClass.remove_event_listener(mc, ButtonClass.ROLL_OVER, _small_hint_rovered)
	ButtonClass.remove_event_listener(e_unit_panel.get_node("eOne"), ButtonClass.ROLL_OUT, _small_hint_routed)
	ButtonClass.remove_event_listener(e_unit_panel.get_node("eTwo"), ButtonClass.ROLL_OUT, _small_hint_routed)
	ButtonClass.remove_button_full(small_vert, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.remove_button_full(small_horiz, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.remove_event_listener(small_horiz, ButtonClass.ROLL_OUT, _small_hint_routed)
	ButtonClass.remove_event_listener(small_vert, ButtonClass.ROLL_OUT, _small_hint_routed)
	var sens: FlashClip = e_unit_panel.get_node("sSensPanel")
	for nm in ["sArmor", "sArmorPierce", "sDmg", "sDmgSpeed", "sExp", "sHealth", "sMagicPierce", "sResist"]:
		ButtonClass.remove_event_listener(sens.get_node(nm), ButtonClass.ROLL_OVER, _small_hint_rovered)
		ButtonClass.remove_event_listener(sens.get_node(nm), ButtonClass.ROLL_OUT, _small_hint_routed)
	for mc: FlashClip in [e_defend, e_attack_def, e_horiz, e_vert, e_got_upgrade, e_formation]:
		ButtonClass.remove_event_listener(mc, ButtonClass.ROLL_OVER, _small_hint_rovered)
		ButtonClass.remove_event_listener(mc, ButtonClass.ROLL_OUT, _small_hint_routed)
	for mc: FlashClip in a_sub_units_panel:
		ButtonClass.remove_button_full(mc, _rover, _rout, _clicked)
	for mc: FlashClip in a_buttons:
		ButtonClass.remove_button_full(mc, _rover, _rout, _clicked)
	ButtonClass.remove_button_lite(e_unit_panel.get_node("eUpgrade"), _upgrade_clicked)
	ButtonClass.remove_button_lite(e_unit_panel.get_node("eUnitSelect/bClose"), _close_upgrade_panel)
	ButtonClass.remove_button_full(e_vert, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.remove_button_full(e_horiz, _rover_simple_hover, _rout_simple_hover, _stroy_clicked)
	ButtonClass.remove_button_full(e_got_upgrade, _rover_simple_hover, _rout_simple_hover, _has_upgrade_clicked)
	# 原版此处写的是 eFormation 配 hasUpgradeClicked（处理函数不匹配，实际移除不到 formationClicked 监听）。
	ButtonClass.remove_button_full(e_formation, _rover_simple_hover, _rout_simple_hover, _has_upgrade_clicked)
	ButtonClass.remove_button_full(e_defend, _rover_simple_hover, _rout_simple_hover, defend_button_clicked)
	ButtonClass.remove_button_full(_unit_select().get_node("bTop"), _rover, _rout, _basic_to_pro_clicked)
	ButtonClass.remove_button_full(_unit_select().get_node("bDown"), _rover, _rout, _basic_to_pro_clicked)


# ================================================================ 小工具（Godot 适配）

func _unit_select() -> FlashClip:
	return e_unit_panel.get_node("eUnitSelect")


func _txt(parent: Node, path: String) -> FlashText:
	return parent.get_node(path) as FlashText


## DisplayObject.height / width（按当前帧可见内容 * scale）。
func _height_of(clip: FlashClip) -> float:
	return IfaceUtil.clip_bounds(clip).size.y * absf(clip.scale.y)


func _set_alpha(node: Control, a: float) -> void:
	node.modulate.a = a


func _as3_num(v: float) -> String:
	var t := String.num(v)
	if t.ends_with(".0"):
		t = t.substr(0, t.length() - 2)
	return t


## 冷却盘子剪辑 eCoolDown。原版 PlaceObject 里 eCoolDown 初始 visible=false（导出数据如此），而原版代码从不置 visible，
## 这里与能力图标一致地保证其可见（冷却盘 100 帧是空帧）——见汇报「剪辑场景缺陷」。
func _cool_down_clip(owner_clip: FlashClip) -> FlashClip:
	var cd: FlashClip = owner_clip.get_node("eCoolDown")
	cd.visible = true
	return cd


## 原版 setAbilityPic：BmpFrames.frames[i] 对应 eAbility 的第 i+1 帧。
func _set_ability_pic(slot: int, index: int) -> void:
	var holder: FlashClip = e_unit_panel.get_node("eOne" if slot == 1 else "eTwo")
	var ab: FlashClip = holder.get_node("eAbility")
	ab.visible = true
	ab.mouse_enabled = false
	ab.mouse_children = false
	ab.goto_and_stop(index + 1)


func _play_sound(sound: String, volume: float) -> void:
	if Sounds.inst != null and s != null:
		Sounds.inst.play(s.get_sound(sound), false, 0, volume)


func _chat_message(text: String) -> void:
	if ChatController.inst != null:
		ChatController.inst.message(text)


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)


func _hints_on() -> bool:
	var mp: Variant = StoredData.main_params
	return mp != null and mp.get("hints", false) == true


func _ok() -> bool:
	return _bound and _first_ready_done


# ================================================================ 焦点 / 暂停

func show_focus(param1: Vector2, param2: float, param3: float = 0) -> void:
	e_focus.visible = true
	e_focus.position.x = param1.x
	e_focus.position.y = param1.y
	# DisplayObject.width = w：scaleX = w / 自然宽度；随后 scaleY = scaleX
	var nat := IfaceUtil.clip_bounds(e_focus).size.x
	if nat > 0.0 and absf(e_focus.scale.x) > 0.0:
		e_focus.scale.x = param2 / nat
	e_focus.scale.y = e_focus.scale.x
	e_focus.goto_and_play(1)
	e_focus.rotation = deg_to_rad(param3)


func hide_focus() -> void:
	e_focus.visible = false
	e_focus.stop()


func flash_deactive() -> void:
	var mp: Variant = StoredData.main_params
	if mp != null and mp.get("autop", false) == true:
		call_pause()


func call_controlled_pause(_param1: RWMouseEvent = null) -> void:
	if game_uni.is_controlled_pause == false:
		(e_pause.get_node("eIcon") as FlashClip).goto_and_stop(2)
		game_uni.is_controlled_pause = true
		RWTween.pause_all()
		RWTween.to(e_game_paused_message, 0.3, {"autoAlpha": 1})
		e_game_paused_message.position = e_game_paused_message_coords
		if red_button_shown:
			e_game_paused_message.position.y = 115
	else:
		(e_pause.get_node("eIcon") as FlashClip).goto_and_stop(1)
		game_uni.is_controlled_pause = false
		RWTween.resume_all()
		RWTween.to(e_game_paused_message, 0.3, {"autoAlpha": 0})


func call_pause(_param1: RWMouseEvent = null) -> void:
	if game_uni.is_paused == false and game_uni.is_end_game == false:
		game_uni.pause()
		t_pause_message.mouse_enabled = true
		t_pause_message.visible = true
		ButtonClass.add_event_listener(t_pause_message, ButtonClass.CLICK, _set_unpause)
		_main_call(&"pause_music", ["gameplay"])


func _set_unpause(_param1: RWMouseEvent = null) -> void:
	game_uni.unpause()
	t_pause_message.mouse_enabled = false
	t_pause_message.visible = false
	ButtonClass.remove_event_listener(t_pause_message, ButtonClass.CLICK, _set_unpause)
	_main_call(&"unpause_music", ["gameplay"])


# ================================================================ 编队 / 攻防

func _formation_clicked(_param1: RWMouseEvent = null) -> void:
	var idx := a_disabled_buttons.find(e_formation)
	if idx < 0:
		if is_formation_clicked == true:
			reset_formation_button()
		else:
			enable_formation_button()
		_click_button(e_formation)
		_play_sound(s.CLICK1, 0.35)
	else:
		_play_sound(s.BTN_DENY, 0.35)


func _set_attack_def_stance(_param1: RWMouseEvent = null) -> void:
	var idx := a_disabled_buttons.find(e_attack_def)
	if idx < 0:
		if is_attack_button_clicked == true:
			reset_attack_def_button()
		else:
			enable_attack_def_button()
		_click_button(e_attack_def)
		_play_sound(s.CLICK1, 0.35)
	else:
		_play_sound(s.BTN_DENY, 0.35)


# ================================================================ 弓箭雨

func _sens_archers_clicked(_param1: RWMouseEvent = null) -> void:
	game_uni.strike_arrows()
	RWTween.to(arrow_target_circle, 0.3, {"autoAlpha": 0, "scaleX": 1.2, "scaleY": 1.2})
	e_sens_archers.visible = false
	archers_clicked = false
	arrow_target_circle.visible = false
	arrow_target_circle.position.x = 1000
	arrow_target_circle.position.y = 0
	b_archers_cooldown = true
	_cool_down_clip(b_archers).goto_and_stop(1)
	RWTween.to(b_archers.get_node("eIco"), 0.3, {"alpha": 0})


func update_b_archers_cooldown(param1: int) -> void:
	if b_archers_cooldown == true:
		_cool_down_clip(b_archers).goto_and_stop(param1)
		if param1 >= 100:
			b_archers_cooldown = false
			_cool_down_clip(b_archers).goto_and_stop(100)
			RWTween.from_to(b_archers, 0.5, {"colorMatrixFilter": {"contrast": 1.5, "saturation": 1.5, "brightness": 1.5}},
				{"colorMatrixFilter": {"contrast": 1, "saturation": 1, "brightness": 1}})


func enable_archers_button() -> void:
	b_archers.visible = true


func click_archers(_param1: RWMouseEvent = null) -> void:
	if b_archers.visible == true:
		if archers_clicked == false:
			if b_archers_cooldown == false:
				archers_clicked = true
				arrow_target_circle.visible = true
				var mp := get_local_mouse_position()
				arrow_target_circle.position.x = mp.x
				arrow_target_circle.position.y = mp.y
				_set_alpha(arrow_target_circle, 1.0)
				arrow_target_circle.scale = Vector2(1, 1)
				RWTween.from(arrow_target_circle, 0.3, {"alpha": 1, "scaleX": 1.2, "scaleY": 1.2})
				e_sens_archers.visible = true
				RWTween.to(b_archers.get_node("eIco"), 0.3, {"alpha": 1})
		else:
			archers_clicked = false
			arrow_target_circle.visible = false
			arrow_target_circle.position.x = 1000
			arrow_target_circle.position.y = 0
			e_sens_archers.visible = false
			RWTween.to(b_archers.get_node("eIco"), 0.3, {"alpha": 0})


# ================================================================ 其它顶层按钮

func _clicked_start_wave(_param1: RWMouseEvent = null) -> void:
	game_uni.red_button_clicked()


func _call_help(_param1: RWMouseEvent = null) -> void:
	_main_call(&"load_how_to_ingame")


func _more_games_clicked(_param1: RWMouseEvent = null) -> void:
	_main_call(&"load_more_games")


func _call_menu(_param1: RWMouseEvent = null) -> void:
	game_uni.call_menu()
	_play_sound(s.CLICK1, 0.35)


func _call_speed_up(_param1: RWMouseEvent = null) -> void:
	if game_uni.cur_speed == 1:
		game_uni.cur_speed = 2
	else:
		game_uni.cur_speed = 1
	(e_speed_up.get_node("eSpeedIco") as FlashClip).goto_and_stop(game_uni.cur_speed)
	_play_sound(s.CLICK1, 0.35)


# 反编译破损，按 P-code 重建：
#   idx = aDisabledButtons.indexOf(eDefend)
#   idx < 0：取 getCurSelected；非空时 standStill==true -> disableDefendButtonAnimation()，否则 enableDefendButtonAnimation()；
#            然后（无论是否有选中单位）播放 CLICK1(0.35)。
#   idx >= 0：播放 BTN_DENY(0.35)。
# 反编译源码只在 standStill==false 分支播放点击音，P-code 里两个分支和 null 情形都会播放。
func defend_button_clicked(_param1: RWMouseEvent = null) -> void:
	var idx := a_disabled_buttons.find(e_defend)
	if idx < 0:
		var sel: LivingObject = game_uni.get_cur_selected
		if sel != null:
			if sel.stand_still == true:
				disable_defend_button_animation()
			else:
				enable_defend_button_animation()
		_play_sound(s.CLICK1, 0.35)
	else:
		_play_sound(s.BTN_DENY, 0.35)


# ================================================================ 悬停提示 eSmallHint

func _manage_small_hint() -> void:
	e_small_hint.visible = false
	e_small_hint.mouse_children = false
	e_small_hint.mouse_enabled = false
	(e_small_hint.get_node("tText") as FlashText).auto_size = "center"
	var e_one: FlashClip = e_unit_panel.get_node("eOne")
	var e_two: FlashClip = e_unit_panel.get_node("eTwo")
	var sens: FlashClip = e_unit_panel.get_node("sSensPanel")
	ButtonClass.add_event_listener(e_one, ButtonClass.ROLL_OVER, _small_hint_rovered)
	ButtonClass.add_event_listener(e_two, ButtonClass.ROLL_OVER, _small_hint_rovered)
	ButtonClass.add_event_listener(e_one, ButtonClass.ROLL_OUT, _small_hint_routed)
	ButtonClass.add_event_listener(e_two, ButtonClass.ROLL_OUT, _small_hint_routed)
	for nm in ["sArmor", "sArmorPierce", "sDmg", "sDmgSpeed", "sExp", "sHealth", "sMagicPierce", "sResist"]:
		ButtonClass.add_event_listener(sens.get_node(nm), ButtonClass.ROLL_OVER, _small_hint_rovered)
	for nm in ["sArmor", "sArmorPierce", "sDmg", "sDmgSpeed", "sExp", "sHealth", "sMagicPierce", "sResist"]:
		ButtonClass.add_event_listener(sens.get_node(nm), ButtonClass.ROLL_OUT, _small_hint_routed)
	for mc: FlashClip in [e_defend, e_attack_def, e_horiz, e_vert, small_horiz, small_vert, e_got_upgrade, e_formation]:
		ButtonClass.add_event_listener(mc, ButtonClass.ROLL_OVER, _small_hint_rovered)
	for mc: FlashClip in [small_horiz, small_vert, e_defend, e_attack_def, e_horiz, e_vert, e_got_upgrade, e_formation]:
		ButtonClass.add_event_listener(mc, ButtonClass.ROLL_OUT, _small_hint_routed)


func _small_hint_routed(_param1: RWMouseEvent = null) -> void:
	e_small_hint.visible = false
	e_small_hint.position.x = 1000
	e_small_hint.position.y = 1000


func _small_hint_rovered(param1: Variant) -> void:
	var play_rover := false
	var tgt: FlashClip = IfaceUtil.target_of(param1)
	e_small_hint.visible = _hints_on()
	var html := ""
	var is_panel_hint := false   # 原 _loc5_
	var sens: FlashClip = e_unit_panel.get_node("sSensPanel")
	var gold := "<font size='18' color='#F6F581'>"
	if tgt == e_got_upgrade:
		play_rover = true
		html = "<p>Select next elite unit that can be upgraded</p>" + "<p>" + gold + "Hotkey: </font>N</p>"
	elif tgt == e_formation:
		play_rover = true
		html = "<p>Soldiers will move and maintain their current formation</p>" + "<p>" + gold + "Alternate:</font> hold SHIFT key and click ground</p>"
	elif tgt == small_vert:
		play_rover = true
		html = "<p>From a vertical line</p>" + "<p>" + gold + "Hotkey: </font>C</p>"
	elif tgt == small_horiz:
		play_rover = true
		html = "<p>Form a horizontal line</p>" + "<p>" + gold + "Hotkey: </font>X</p>"
	elif tgt == e_vert:
		play_rover = true
		html = "<p>From a vertical line</p>" + "<p>" + gold + "Hotkey: </font>C</p>"
	elif tgt == e_horiz:
		play_rover = true
		html = "<p>Form a horizontal line</p>" + "<p>" + gold + "Hotkey: </font>X</p>"
	elif tgt == e_attack_def:
		play_rover = true
		html = "<p>Attack stance</p>" + "<p>" + gold + "Alternate:</font> hold A key and click ground</p>"
	elif tgt == e_defend:
		play_rover = true
		html = "<p>Hold ground</p>" + "<p>" + gold + "Hotkey: </font>S</p>"
	elif tgt == sens.get_node("sResist"):
		is_panel_hint = true
		html = "<p>" + gold + "Magic resistance</font></p>" + "<p>Ability to block some magic damage</p>"
	elif tgt == sens.get_node("sMagicPierce"):
		is_panel_hint = true
		html = "<p>" + gold + "Magic piercing</font></p>" + "<p>Ability to bypass some magic defence</p>"
	elif tgt == sens.get_node("sHealth"):
		is_panel_hint = true
		html = "<p>" + gold + "Health</font></p>" + "<p>Current and maximum HP.</p>"
	elif tgt == sens.get_node("sExp"):
		is_panel_hint = true
		html = "<p>" + gold + "Experience</font></p>" + "<p>Experienced soldiers fight better. Tier 1 elite units with maximum EXP can be upgraded to the second tier</p>"
	elif tgt == sens.get_node("sDmgSpeed"):
		is_panel_hint = true
		html = "<p>" + gold + "Attack speed</font></p>" + "<p>Interval between each attack</p>"
	elif tgt == sens.get_node("sDmg"):
		is_panel_hint = true
		html = "<p>" + gold + "Damage</font></p>" + "<p>Amount of damage with every hit or healing power for priests</p>"
	elif tgt == sens.get_node("sArmorPierce"):
		is_panel_hint = true
		html = "<p>" + gold + "Armor piercing</font></p>" + "<p>Ability to ignore target's armor</p>"
	elif tgt == sens.get_node("sArmor"):
		is_panel_hint = true
		html = "<p>" + gold + "Armor</font></p>" + "<p>Armor deflects some damage</p>"
	elif tgt == e_unit_panel.get_node("eOne"):
		is_panel_hint = true
		if last_unit.special_one != null:
			if last_unit.special_one.is_locked == false:
				html = last_unit.special_one.special_description
			else:
				html = "<p>Ability locked</p>"
		else:
			html = "<p>Ability locked</p>"
	elif tgt == e_unit_panel.get_node("eTwo"):
		is_panel_hint = true
		if last_unit.special_two != null:
			if last_unit.special_two.is_locked == false:
				html = last_unit.special_two.special_description
			else:
				html = "<p>Ability locked</p>"
		else:
			html = "<p>Ability locked</p>"
	if e_small_hint.visible == true:
		var ttext: FlashText = e_small_hint.get_node("tText")
		ttext.html_text = html
		var eback: FlashClip = e_small_hint.get_node("eBack")
		# TextField.height（autoSize）= 文本高度 + 4 的内边距
		_set_height(eback, ttext.get_text_height() + 4.0 + 10)
		var ebottom: FlashClip = e_small_hint.get_node("eBottom")
		ebottom.position.y = _height_of_natural(eback) + eback.position.y - 1
		var hint_h := _height_of(e_small_hint)
		if is_panel_hint == false:
			e_small_hint.position.x = tgt.position.x
			if tgt == small_horiz or tgt == small_vert:
				e_small_hint.position.y = tgt.position.y - hint_h + 20
			else:
				e_small_hint.position.y = tgt.position.y - hint_h + 5
		else:
			e_small_hint.position.y = 566 - hint_h + 40
			if tgt == e_unit_panel.get_node("eOne") or tgt == e_unit_panel.get_node("eTwo"):
				if tgt == e_unit_panel.get_node("eOne"):
					e_small_hint.position.x = 108
				else:
					e_small_hint.position.x = 156
			else:
				e_small_hint.position.x = 229 + tgt.position.x
	if play_rover:
		if Sounds.inst != null and s != null:
			Sounds.inst.play_rover(s.get_sound(s.ROVER), 0, 0.25, tgt)


## DisplayObject.height = h：scaleY = h / 自然高度（自然高度取 scaleY=1 时当前帧的包围盒高度）。
func _set_height(clip: FlashClip, h: float) -> void:
	var old_scale := clip.scale.y
	clip.scale.y = 1.0
	var nat := IfaceUtil.clip_bounds(clip).size.y
	if nat > 0.0:
		clip.scale.y = h / nat
	else:
		clip.scale.y = old_scale


func _height_of_natural(clip: FlashClip) -> float:
	return _height_of(clip)


# ================================================================ 升级单位

func _has_upgrade_clicked(param1: Variant) -> void:
	var mc: FlashClip = IfaceUtil.target_of(param1)
	var idx := a_disabled_buttons.find(mc)
	if idx < 0:
		select_next_unit_with_upgrade()
		_click_button(mc)
		_play_sound(s.CLICK1, 0.38)
	else:
		_play_sound(s.BTN_DENY, 0.38)


func select_next_unit_with_upgrade() -> void:
	cur_unit_with_upgrade_index += 1
	if a_units_waiting_upgrade.size() > 0:
		if cur_unit_with_upgrade_index >= a_units_waiting_upgrade.size():
			cur_unit_with_upgrade_index = 0
		var u: LivingObject = a_units_waiting_upgrade[cur_unit_with_upgrade_index]
		game_uni.unselect_units()
		game_uni.select_unit(u)


func _close_upgrade_panel(_param1: RWMouseEvent = null) -> void:
	RWTween.to(_unit_select(), 0.2, {"y": unit_select_panel_coords.y + 220})


func _rout_simple_hover(param1: Variant) -> void:
	_rout_button(IfaceUtil.target_of(param1))


func _rover_simple_hover(param1: Variant) -> void:
	_rover_button(IfaceUtil.target_of(param1))


func _rout(param1: Variant) -> void:
	var mc: FlashClip = IfaceUtil.target_of(param1)
	if a_buttons.find(mc) >= 0 or a_sub_units_panel.find(mc) >= 0:
		_rout_button(mc)
	e_hint.visible = false
	e_hint.position.x = -100
	e_hint.position.y = -100


func _rover(param1: Variant) -> void:
	var mc: FlashClip = IfaceUtil.target_of(param1)
	if a_buttons.find(mc) >= 0 or a_sub_units_panel.find(mc) >= 0:
		_rover_button(mc)
	e_hint.visible = _hints_on()
	var coins: FlashClip = e_hint.get_node("eCoins")
	var tname: FlashText = e_hint.get_node("tName")
	var tcost: FlashText = e_hint.get_node("tCost")
	var eback: FlashClip = e_hint.get_node("eBack")
	coins.visible = true
	tname.position.y = -15
	eback.goto_and_stop(1)
	var sel_frame := (_unit_select().get_node("eSelector") as FlashClip).current_frame
	if mc == e1:
		tname.text = "Warriors"
		_set_no_price()
	elif mc == e2:
		tname.text = "Mages"
		_set_no_price()
	elif mc == e3:
		tname.text = "Priests"
		_set_no_price()
	elif mc == e4:
		tname.text = "Archers"
		_set_no_price()
	elif mc == e5:
		tname.text = "Rogues"
		_set_no_price()
	elif mc == e_sub_down:
		tname.text = "Close"
		_set_no_price()
	elif mc == e_sub_one:
		e_hint.visible = true
		var n := last_clicked_unit_number
		if n >= 1 and n <= 5:
			var row: Array = tier_one()[n]
			tname.text = row[0]
			var uc: float = row[2].get("unit_cost")
			tcost.text = _as3_num(floorf(uc + cost_multiplier * _unit_num(n) * uc))
			_hint_update_width()
	elif mc == e_sub_two:
		e_hint.visible = true
		if last_clicked_unit_number >= 1 and last_clicked_unit_number <= 5:
			var row2: Array = tier_two()[last_clicked_unit_number]
			tname.text = row2[0]
			tcost.text = _as3_num(float(row2[2].get("unit_cost")))
			_hint_update_width()
	elif mc == e_sub_three:
		e_hint.visible = true
		if last_clicked_unit_number >= 1 and last_clicked_unit_number <= 5:
			var row3: Array = tier_three()[last_clicked_unit_number]
			tname.text = row3[0]
			tcost.text = _as3_num(float(row3[2].get("unit_cost")))
			_hint_update_width()
	elif mc == _unit_select().get_node("bTop"):
		e_hint.visible = true
		eback.goto_and_stop(2)
		if sel_frame >= 1 and sel_frame <= 5:
			var rowt: Array = upgrade_top()[sel_frame]
			tname.text = rowt[0]
			tcost.text = _as3_num(float(rowt[1].get("upgrade_cost")))
			_hint_update_width()
	elif mc == _unit_select().get_node("bDown"):
		e_hint.visible = true
		eback.goto_and_stop(2)
		if sel_frame >= 1 and sel_frame <= 5:
			var rowd: Array = upgrade_down()[sel_frame]
			tname.text = rowd[0]
			tcost.text = _as3_num(float(rowd[1].get("upgrade_cost")))
			_hint_update_width()
	_set_hint_pos(mc)


# 兵种表（函数而非静态变量：避免脚本加载期与各 Friend* 类互相引用）。键 = lastClickedUnitNumber：
# 1 战士(e1)、2 弓手(e4)、3 法师(e2)、4 牧师(e3)、5 盗贼(e5)。每行：[提示名, 单位 kind, 单位类, 锁定提示用的复数名]
static func tier_one() -> Dictionary:
	return {
		1: ["Swordsman", LivingObject.FR_WARRIOR, FriendWarrior, "Warriors"],
		2: ["Archer", LivingObject.FR_ARCHER, FriendArcher, "Archers"],
		3: ["Blue Wizard", LivingObject.FR_BLUEMAGE, FriendBlueMage, "Blue mages"],
		4: ["Priest", LivingObject.FR_PRIEST, FriendPriest, "Priests"],
		5: ["Rogue", LivingObject.FR_ROGUE, FriendScoutRogue, "Rogues"],
	}


static func tier_two() -> Dictionary:
	return {
		1: ["Swordmaster", LivingObject.FR_SWORDMASTER, FriendSwordMaster, "Swordmasters"],
		2: ["Sniper", LivingObject.FR_SNIPER, FriendSniper, "Snipers"],
		3: ["Red Wizard", LivingObject.FR_REDMAGE, FriendRedMage, "Red mages"],
		4: ["Cleric", LivingObject.FR_HEALER, FriendHealer, "Healers"],
		5: ["Assassin", LivingObject.FR_ASSASIN, FriendScoutAssasin, "Assassins"],
	}


static func tier_three() -> Dictionary:
	return {
		1: ["Knight", LivingObject.FR_KNIGHT, FriendKnight, "Knights"],
		2: ["Crossbowman", LivingObject.FR_CROSSBOW, FriendCrossBowMan, "Crossbowmen"],
		3: ["Black Wizard", LivingObject.FR_BLACKMAGE, FriendBlackMage, "Black mages"],
		4: ["Monk", LivingObject.FR_BLESSER, FriendBlesser, "Monks"],
		5: ["Spy", LivingObject.FR_SABOTEUR, FriendScoutSaboteur, "Spies"],
	}


# bTop / bDown 的升级提示：键 = eSelector.currentFrame。每行：[提示名, 单位类]
static func upgrade_top() -> Dictionary:
	return {
		1: ["Knight", FriendKnight],
		2: ["Crossbowman", FriendCrossBowMan],
		3: ["Cleric", FriendHealer],
		4: ["Red Mage", FriendRedMage],
		5: ["Assassin", FriendScoutAssasin],
	}


static func upgrade_down() -> Dictionary:
	return {
		1: ["Swordmaster", FriendSwordMaster],
		2: ["Sniper", FriendSniper],
		3: ["Monk", FriendBlesser],
		4: ["Black Mage", FriendBlackMage],
		5: ["Spy", FriendScoutSaboteur],
	}


func _unit_num(n: int) -> int:
	match n:
		1: return LivingObject.unit_num_warriors
		2: return LivingObject.unit_num_archers
		3: return LivingObject.unit_num_mages
		4: return LivingObject.unit_num_priests
		5: return LivingObject.unit_num_rogues
	return 0


func _set_no_price() -> void:
	(e_hint.get_node("tCost") as FlashText).text = ""
	_hint_update_width()
	(e_hint.get_node("eCoins") as FlashClip).visible = false
	(e_hint.get_node("tName") as FlashText).position.y = -8


func _rover_button(param1: FlashClip) -> void:
	RWTween.to(param1, 0.3, {"colorTransform": {"brightness": 1.3}})
	if Sounds.inst != null and s != null:
		Sounds.inst.play_rover(s.get_sound(s.ROVER), 0, 0.25, param1)


func _rout_button(param1: FlashClip) -> void:
	RWTween.to(param1, 0.2, {"colorTransform": {"brightness": 1}})


func _hint_update_width() -> void:
	pass   # 原版为空函数


func _rout_tween_max_brightness(param1: FlashClip) -> void:
	RWTween.to(param1, 0.3, {"colorTransform": {"brightness": 1}})


func _rover_tween_max_brightness(param1: FlashClip) -> void:
	RWTween.to(param1, 0.3, {"colorTransform": {"brightness": 1.3}})


## 基础兵 -> 精英进阶。上排 bTop，下排 bDown；eSelector 帧 1..5 = 战士/弓手/牧师/蓝法/盗贼。
func _basic_to_pro_clicked(param1: Variant) -> void:
	var mc: FlashClip = IfaceUtil.target_of(param1)
	var sel_frame := (_unit_select().get_node("eSelector") as FlashClip).current_frame
	var cur: LivingObject = game_uni.get_cur_selected
	if mc == _unit_select().get_node("bTop"):
		match sel_frame:
			1: _try_pro(FriendKnight, LivingObject.FR_KNIGHT, cur)
			2: _try_pro(FriendCrossBowMan, LivingObject.FR_CROSSBOW, cur)
			3: _try_pro(FriendHealer, LivingObject.FR_HEALER, cur)
			4: _try_pro(FriendRedMage, LivingObject.FR_REDMAGE, cur)
			5: _try_pro(FriendScoutAssasin, LivingObject.FR_ASSASIN, cur)
	else:
		match sel_frame:
			1: _try_pro(FriendSwordMaster, LivingObject.FR_SWORDMASTER, cur)
			2: _try_pro(FriendSniper, LivingObject.FR_SNIPER, cur)
			3: _try_pro(FriendBlesser, LivingObject.FR_BLESSER, cur)
			4: _try_pro(FriendBlackMage, LivingObject.FR_BLACKMAGE, cur)
			5: _try_pro(FriendScoutSaboteur, LivingObject.FR_SABOTEUR, cur)
	RWTween.to(e_unit_panel.get_node("eUpgrade"), 0.2, {"y": e_upgrade_down_coord})
	_close_upgrade_panel()


func _try_pro(cls: GDScript, kind: int, unit: LivingObject) -> void:
	if dest_money >= int(cls.get("upgrade_cost")):
		game_uni.add_pro_unit(kind, unit)
	else:
		_not_enough_money()


func _stroy_clicked(param1: Variant) -> void:
	var mc: FlashClip = IfaceUtil.target_of(param1)
	var idx := a_disabled_buttons.find(mc)
	if idx < 0:
		if mc == e_horiz or mc == small_horiz:
			game_uni.stroy_clicked(0, param1)
		else:
			game_uni.stroy_clicked(1, param1)
		_click_button(mc)
	else:
		_play_sound(s.BTN_DENY, 0.35)


func _upgrade_clicked(_param1: RWMouseEvent = null) -> void:
	var up: FlashClip = e_unit_panel.get_node("eUpgrade")
	if up.position.y != e_upgrade_down_coord:
		var u: LivingObject = game_uni.get_cur_selected
		if u.basic_unit == true:
			if u.get_level == 3:
				var us := _unit_select()
				RWTween.to(us, 0.3, {"y": unit_select_panel_coords.y})
				(us.get_node("eUpgradeNotAllowedTop") as FlashClip).visible = false
				(us.get_node("eUpgradeNotAllowedBottom") as FlashClip).visible = false
				_play_sound(s.CLICK1, 0.38)
				var sel: FlashClip = us.get_node("eSelector")
				match u.get_kind:
					LivingObject.FR_ARCHER:
						sel.goto_and_stop(2)
						if a_locked_units_and_buttons.find(LivingObject.FR_CROSSBOW) >= 0:
							(us.get_node("eUpgradeNotAllowedTop") as FlashClip).visible = true
					LivingObject.FR_WARRIOR:
						sel.goto_and_stop(1)
						if a_locked_units_and_buttons.find(LivingObject.FR_KNIGHT) >= 0:
							(us.get_node("eUpgradeNotAllowedTop") as FlashClip).visible = true
					LivingObject.FR_PRIEST:
						sel.goto_and_stop(3)
						if a_locked_units_and_buttons.find(LivingObject.FR_BLESSER) >= 0:
							(us.get_node("eUpgradeNotAllowedBottom") as FlashClip).visible = true
					LivingObject.FR_BLUEMAGE:
						sel.goto_and_stop(4)
						if a_locked_units_and_buttons.find(LivingObject.FR_BLACKMAGE) >= 0:
							(us.get_node("eUpgradeNotAllowedBottom") as FlashClip).visible = true
					LivingObject.FR_ROGUE:
						sel.goto_and_stop(5)
						if a_locked_units_and_buttons.find(LivingObject.FR_SABOTEUR) >= 0:
							(us.get_node("eUpgradeNotAllowedBottom") as FlashClip).visible = true
			else:
				u.upgrade_clicked()
		else:
			u.upgrade_clicked()


# ================================================================ 单位面板

func show_unit_panel() -> void:
	if not _ok():
		return
	RWTween.to(e_unit_panel, 0.3, {"autoAlpha": 1, "y": unit_panel_y})
	reset_attack_def_button()
	reset_formation_button()
	if game_uni.get_cur_selected.stand_still:
		_start_defend_button_anim()
	else:
		_stop_defend_button_anim()
	_close_upgrade_panel()
	if red_button_shown == false:
		if game_uni.get_num_selected_units > 1:
			_show_right_button(e_vert)
			_show_right_button(e_horiz)
			_show_right_button(e_formation)
		else:
			_hide_right_button(e_vert)
			_hide_right_button(e_horiz)
			_hide_right_button(e_formation)
	elif game_uni.get_num_selected_units > 1:
		_show_right_button(small_horiz)
		_show_right_button(small_vert)
	else:
		_hide_right_button(small_horiz)
		_hide_right_button(small_vert)
	_show_right_button(e_attack_def)
	_show_right_button(e_defend)


# 反编译破损（while(true)/§§goto），按 P-code 重建。控制流：选中为空 -> hideUnitPanel 后结束；
# 否则依次更新图标、两个技能的冷却盘、各项文字，最后处理进阶按钮；射速文字的比较见下（反编译漏了 `< 55`）。
func update_soldier_data() -> void:
	if not _ok():
		return
	var u: LivingObject = game_uni.get_cur_selected
	if u == null:
		hide_unit_panel()
		return
	last_unit = u
	var kind: int = u.get_kind
	(e_unit_panel.get_node("eIco") as FlashClip).goto_and_stop(kind + 1)
	var class_name_: String = u.get_class_name
	var level: int = u.get_level
	var cur_hp: int = u.cur_health
	var max_hp: int = u.health
	var xp: int = u.get_xp
	var xp_until: int = u.get_xp_until_upgrade
	_update_ability_slot(1, u.special_one)
	_update_ability_slot(2, u.special_two)
	if xp > xp_until:
		xp = xp_until
	var panel := e_unit_panel
	_txt(panel, "tMagicPiercing").text = _as3_num(u.magic_piercing * 100) + "%"
	var damage: float
	var speed: int
	if u.is_archer == false:
		damage = u.cur_damage
		speed = u.get_attack_speed
		_txt(panel, "tArmorPiercing").text = _as3_num(u.armor_piercing_melee * 100) + "%"
	else:
		_txt(panel, "tArmorPiercing").text = _as3_num(u.armor_piercing_ranged * 100) + "%"
		damage = u.cur_ranged_damage
		speed = u.get_ranged_attack_speed
	if speed < 35:
		_txt(panel, "tSpeed").text = "Fast"
	elif speed > 35 and speed < 55:
		_txt(panel, "tSpeed").text = "Med"
	else:
		_txt(panel, "tSpeed").text = "Slow"
	_txt(panel, "tResist").text = _as3_num(u.cur_magic_resist * 100) + "%"
	# Math.round(x * 100)：负数 .5 的取整方向与 GDScript round 不同（AS3 向 +inf）
	_txt(panel, "tArmor").text = _as3_num(floorf(u.cur_armor * 100 + 0.5)) + "%"
	var prefix := ""
	if level == 2:
		prefix = "Hardened  " + "\n"
	elif level == 3:
		prefix = "Veteran " + "\n"
		if xp == xp_until:
			prefix = "Elite " + "\n"
	var tlc := _txt(panel, "tLevelClass")
	tlc.text = prefix + class_name_
	match IfaceUtil.num_lines(tlc):
		1: tlc.position.y = -20
		2: tlc.position.y = -25
		3: tlc.position.y = -29
		_: tlc.position.y = -29
	_txt(panel, "tHp").html_text = str(cur_hp) + "/" + str(max_hp)
	if level == 3 and u.basic_unit == false:
		_txt(panel, "tXp").text = "Max"
	else:
		_txt(panel, "tXp").text = str(xp) + "/" + str(xp_until)
	_txt(panel, "tAttack").text = _as3_num(damage)
	var atype: FlashClip = panel.get_node("eAttackType")
	if u.is_archer == true:
		if u.is_priest or u.is_mage:
			atype.goto_and_stop(3)
		else:
			atype.goto_and_stop(2)
	else:
		atype.goto_and_stop(1)
	var up: FlashClip = panel.get_node("eUpgrade")
	if u.friendly == true:
		if xp >= xp_until:
			if level == 3 and u.basic_unit == true:
				if game_uni.is_upgrade_allowed(u.get_kind):
					if up.position.y != e_upgrade_panel_coords.y:
						RWTween.to(up, 0.2, {"y": e_upgrade_panel_coords.y})
					up.mouse_enabled = true
					up.play()
		elif up.position.y != e_upgrade_down_coord:
			RWTween.to(up, 0.2, {"y": e_upgrade_down_coord})
	elif up.position.y != e_upgrade_down_coord:
		RWTween.to(up, 0.2, {"y": e_upgrade_down_coord})


## 技能槽 1/2：图标 + 冷却盘。冷却盘第 N 帧 = getCountPercent（gotoAndStop(getCountPercent)）。
func _update_ability_slot(slot: int, sp: SpecialTemplate) -> void:
	var holder: FlashClip = e_unit_panel.get_node("eOne" if slot == 1 else "eTwo")
	var cd := _cool_down_clip(holder)
	if sp != null:
		if sp.is_locked == false:
			_set_ability_pic(slot, sp.number_in_panel - 1)
			cd.goto_and_stop(sp.get_count_percent)
			var counter: int = sp.get_cur_counter
			if counter == 1:
				_set_alpha(cd, 1.0)
				RWTween.from(cd, 0.3, {"alpha": 0})
		else:
			_set_ability_pic(slot, 0)
			cd.goto_and_stop(100)
	else:
		_set_ability_pic(slot, 0)
		cd.goto_and_stop(100)


func hide_unit_panel() -> void:
	if not _ok():
		return
	reset_attack_def_button()
	reset_formation_button()
	last_unit = null
	RWTween.to(e_unit_panel, 0.2, {"autoAlpha": 0, "y": unit_panel_y + _height_of(e_unit_panel)})
	if red_button_shown == false:
		_hide_right_button(e_horiz)
		_hide_right_button(e_vert)
	else:
		_hide_right_button(small_horiz)
		_hide_right_button(small_vert)
	_hide_right_button(e_formation)
	_hide_right_button(e_attack_def)
	_hide_right_button(e_defend)


func unit_dead(_param1: LivingObject) -> void:
	update_soldier_data()


# ================================================================ 每帧刷新 / 金钱 / 生命 / 波数

func update_data() -> void:
	if not _ok():
		return
	if cur_money != dest_money:
		# `_loc6_:int = Math.round(dest - cur) / 5`：先四舍五入再除 5，赋给 int 时截断
		var step := int(floorf(float(dest_money - cur_money) + 0.5) / 5.0)
		if step != 0:
			cur_money += step
		else:
			cur_money = dest_money
		(e_money.get_node("tMoney") as FlashText).text = str(cur_money)
	if archers_clicked == true:
		var mp := get_local_mouse_position()
		arrow_target_circle.position.x = mp.x
		arrow_target_circle.position.y = mp.y
	var now: int = game_uni.get_game_time()
	if warrior_cool_down_status != 100:
		warrior_cool_down_status = _step_cool_down(now, warrior_last_built_time, LivingObject.unit_num_warriors, LivingObject.A_WARRIOR_COOLDOWN_TAB)
		_cool_down_clip(e1).goto_and_stop(warrior_cool_down_status)
	if mage_cool_down_status != 100:
		mage_cool_down_status = _step_cool_down(now, mage_last_built_time, LivingObject.unit_num_mages, LivingObject.A_MAGE_COOLDOWN_TAB)
		_cool_down_clip(e2).goto_and_stop(mage_cool_down_status)
	if archer_cool_down_status != 100:
		archer_cool_down_status = _step_cool_down(now, archer_last_built_time, LivingObject.unit_num_archers, LivingObject.A_ARCHER_COOLDOWN_TAB)
		_cool_down_clip(e4).goto_and_stop(archer_cool_down_status)
	if priest_cool_down_status != 100:
		priest_cool_down_status = _step_cool_down(now, priest_last_built_time, LivingObject.unit_num_priests, LivingObject.A_PRIEST_COOLDOWN_TAB)
		_cool_down_clip(e3).goto_and_stop(priest_cool_down_status)
	if rogue_cool_down_status != 100:
		rogue_cool_down_status = _step_cool_down(now, rogue_last_built_time, LivingObject.unit_num_rogues, LivingObject.A_ROGUE_COOLDOWN_TAB)
		_cool_down_clip(e5).goto_and_stop(rogue_cool_down_status)
	if chat_controll != null:
		chat_controll.update()


## 招募冷却盘：status = int(elapsed / (tab[num-1] * 30) * 100)，elapsed >= 总帧数 -> 100。
## 表索引越界时 AS3 得 undefined*30 = NaN -> int 0，除零后 elapsed >= 0 恒成立，结果 100。
func _step_cool_down(now: int, last_built: int, num: int, tab: Array) -> int:
	var total := 0
	if num - 1 >= 0 and num - 1 < tab.size():
		total = int(tab[num - 1]) * 30
	var elapsed := now - last_built
	var status := 0
	if total != 0:
		status = int(float(elapsed) / total * 100)
	if elapsed >= total:
		status = 100
	return status


func _set_hint_pos(param1: FlashClip) -> void:
	var eback: FlashClip = e_hint.get_node("eBack")
	if eback.current_frame == 1:
		e_hint.position.x = param1.position.x
		e_hint.position.y = 537
	elif param1 == _unit_select().get_node("bTop"):
		e_hint.position.x = 134
		e_hint.position.y = 419
	else:
		e_hint.position.x = 134
		e_hint.position.y = 470


func set_money() -> void:
	dest_money = GameUniverse.inst.get_money()


func hide_has_upgrade_button(param1: LivingObject) -> void:
	if not _ok():
		return
	var idx := a_units_waiting_upgrade.find(param1)
	if idx >= 0:
		num_units_waiting_upgrade -= 1
		a_units_waiting_upgrade.remove_at(idx)
	if num_units_waiting_upgrade <= 0:
		num_units_waiting_upgrade = 0
		_hide_right_button(e_got_upgrade)


func show_has_upgrade_button(param1: LivingObject) -> void:
	if not _ok():
		return
	game_uni.level_info.upgrade_sign_showed()
	var idx := a_units_waiting_upgrade.find(param1)
	if idx < 0:
		num_units_waiting_upgrade += 1
		a_units_waiting_upgrade.append(param1)
	_show_right_button(e_got_upgrade)


func show_next_wave_button() -> void:
	pass   # 原版为空函数


func hide_next_wave_button() -> void:
	pass   # 原版为空函数


func draw_lives(param1: float) -> void:
	if not _ok():
		return
	(e_hp.get_node("tText") as FlashText).text = str(int(param1))


func draw_current_wave(param1: float, param2: int) -> void:
	if not _ok():
		return
	(e_wave.get_node("tText") as FlashText).text = "" + str(int(param1)) + "/" + str(param2)


func reset_attack_def_button() -> void:
	if not _ok():
		return
	RWTween.to(e_attack_def.get_node("eIco"), 0.3, {"alpha": 0})
	is_attack_button_clicked = false


func disable_menu() -> void:
	if not _ok():
		return
	ButtonClass.remove_button_full(e_menu, _rover_simple_hover, _rout_simple_hover, _call_menu)


# ================================================================ 兵种按钮锁定

func unlock_units() -> void:
	a_locked_units_and_buttons = []
	if not _ok():
		_pending_ops.append(["unlock"])
		return
	_do_unlock_units()


func lock_units(param1: Array) -> void:
	a_locked_units_and_buttons = param1.duplicate()
	if not _ok():
		_pending_ops.append(["lock", param1.duplicate()])
		return
	_do_lock_units(param1)


## 界面尚未 ready 时（核心在 add_child 之前调用 unlockUnits）暂存，ready 后按原顺序补做；
## FlashClip._ready 会按时间轴重置子节点的可见性，所以不能直接写。
func _apply_pending_locks() -> void:
	var ops := _pending_ops
	_pending_ops = []
	for op: Array in ops:
		if op[0] == "unlock":
			_do_unlock_units()
		else:
			_do_lock_units(op[1])


func _lock_pairs() -> Array:
	return [[e1, LivingObject.BUTTON_WARRIORS], [e4, LivingObject.BUTTON_ARCHERS], [e2, LivingObject.BUTTON_MAGES],
		[e3, LivingObject.BUTTON_PRIESTS], [e5, LivingObject.BUTTON_THIEVES]]


func _do_unlock_units() -> void:
	for p in _lock_pairs():
		var mc: FlashClip = p[0]
		(mc.get_node("eLocked") as FlashClip).visible = false
		(mc.get_node("eIco") as FlashClip).visible = true


func _do_lock_units(param1: Array) -> void:
	for v in param1:
		var code := int(v)
		for p in _lock_pairs():
			if p[1] == code:
				var mc: FlashClip = p[0]
				(mc.get_node("eLocked") as FlashClip).visible = true
				(mc.get_node("eIco") as FlashClip).visible = false


func _hide_right_button(param1: FlashClip) -> void:
	RWTween.to(param1, 0.2, {"colorMatrixFilter": {"amount": 1, "contrast": 1, "brightness": 0.8, "saturation": 0}})
	var idx := a_disabled_buttons.find(param1)
	if idx < 0:
		a_disabled_buttons.append(param1)
	if param1 == e_defend:
		_set_alpha(e_defend.get_node("eIco"), 0.0)


func _show_right_button(param1: FlashClip) -> void:
	RWTween.to(param1, 0.2, {"colorMatrixFilter": {"amount": 1, "contrast": 1, "brightness": 1, "saturation": 1}})
	var idx := a_disabled_buttons.find(param1)
	if idx >= 0:
		a_disabled_buttons.remove_at(idx)


# ================================================================ 兵种购买

func _clicked(param1: Variant) -> void:
	var mc: FlashClip = IfaceUtil.target_of(param1)
	_click_button(mc)
	if mc == e1:
		last_clicked_unit_number = 1
		_try_open_sub_panel(e1, warrior_cool_down_status, "Warriors")
	elif mc == e2:
		last_clicked_unit_number = 3
		_try_open_sub_panel(e2, mage_cool_down_status, "Mages")
	elif mc == e3:
		last_clicked_unit_number = 4
		_try_open_sub_panel(e3, priest_cool_down_status, "Priests")
	elif mc == e4:
		last_clicked_unit_number = 2
		_try_open_sub_panel(e4, archer_cool_down_status, "Archers")
	elif mc == e5:
		last_clicked_unit_number = 5
		_try_open_sub_panel(e5, rogue_cool_down_status, "Thieves")
	elif mc == e_sub_down:
		hide_sub_panel()
	elif mc == e_sub_one:
		_selected_tier(tier_one(), true)
	elif mc == e_sub_two:
		_selected_tier(tier_two(), false)
	elif mc == e_sub_three:
		_selected_tier(tier_three(), false)


func _try_open_sub_panel(button: FlashClip, cool_status: int, group: String) -> void:
	if (button.get_node("eLocked") as FlashClip).visible == false:
		if cool_status == 100:
			_show_sub_panel()
		else:
			_not_ready_yet()
	else:
		_chat_message(group + " are not avaliable for this mission")


## selectedTierOne/Two/Three 的共同实现。三个原函数逐 case 重复同一模式，差异全部在 tier 表里：
##  - tier 1 的费用 = floor(unitCost + costMultiplier * unitNum * unitCost)；tier 2/3 = unitCost
##  - 原版三处笔误保留：牧师类（case 4：Priest / Healer / Blesser）成功招募后的淡入写在 e1.eCoolDown 上、
##    时长 0.3（其余 0.2 且写在各自按钮上）；e3.eCoolDown.alpha 仍被置 1。
func _selected_tier(table: Dictionary, tier_one: bool) -> void:
	var n := last_clicked_unit_number
	if not table.has(n):
		return
	var row: Array = table[n]
	var kind: int = row[1]
	var cls: GDScript = row[2]
	if a_locked_units_and_buttons.find(kind) < 0:
		var unit_cost: float = cls.get("unit_cost")
		var cost: float = unit_cost
		if tier_one:
			cost = floorf(unit_cost + cost_multiplier * _unit_num(n) * unit_cost)
		if dest_money >= cost:
			game_uni.add_soldier(kind)
			var now: int = game_uni.get_game_time()
			var btn: FlashClip
			match n:
				1:
					warrior_cool_down_status = 0
					warrior_last_built_time = now
					btn = e1
				2:
					archer_cool_down_status = 0
					archer_last_built_time = now
					btn = e4
				3:
					mage_cool_down_status = 0
					mage_last_built_time = now
					btn = e2
				4:
					priest_cool_down_status = 0
					priest_last_built_time = now
					btn = e3
				5:
					rogue_cool_down_status = 0
					rogue_last_built_time = now
					btn = e5
			_set_alpha(_cool_down_clip(btn), 1.0)
			if n == 4:
				RWTween.from(_cool_down_clip(e1), 0.3, {"alpha": 0})   # 原版笔误：用的是 e1
			else:
				RWTween.from(_cool_down_clip(btn), 0.2, {"alpha": 0})
			hide_sub_panel()
		else:
			_not_enough_money()
	else:
		_chat_message(row[3] + " are not avaliable for this mission")


func _show_sub_panel() -> void:
	_play_sound(s.CLICK1, 0.35)
	for mc: FlashClip in a_sub_units_panel:
		(mc.get_node("eIco") as FlashClip).goto_and_stop(last_clicked_unit_number)
		mc.visible = true
		mc.position.y = sub_units_panel_down_y
	var n := last_clicked_unit_number
	if tier_one().has(n):
		var locked_ones := [tier_one()[n][1], tier_two()[n][1], tier_three()[n][1]]
		var panels := [e_sub_one, e_sub_two, e_sub_three]
		for i in 3:
			if a_locked_units_and_buttons.find(locked_ones[i]) >= 0:
				(panels[i].get_node("eIco") as FlashClip).goto_and_stop(6)
	RWTween.all_to(a_sub_units_panel, 0.15, {"y": sub_units_panel_y})


func hide_sub_panel() -> void:
	RWTween.all_to(a_sub_units_panel, 0.2, {"y": sub_units_panel_down_y, "ease": RWEase.linear_ease_in}, 0.0, _sub_panel_invis)


func reset_cool_down() -> void:
	warrior_last_built_time = 0


# ================================================================ 红色“下一波”按钮

func show_red_button() -> void:
	if not _ok() or a_buttons.is_empty():
		return
	for mc: FlashClip in a_buttons:
		mc.mouse_enabled = true
	var bstart: FlashClip = e_next_wave_pad.get_node("bStart")
	var pad: FlashClip = e_next_wave_pad.get_node("eAutostartPad")
	bstart.mouse_enabled = true
	e_next_wave_pad.mouse_enabled = true
	RWTween.to(e_next_wave_pad, 0.4, {"y": 32})
	RWTween.to(pad, 0.3, {"alpha": 1, "delay": 0.5})
	var vert_y := e_vert.position.y
	RWTween.all_to([e_got_upgrade, e_vert, e_horiz, e_formation, e_attack_def, e_defend], 0.3, {"y": "42"}, 0.1,
		_reset_pos, [vert_y])
	RWTween.all_to([small_horiz, small_vert], 0.2, {"y": 542}, 0.1)
	# 原版取 bottomLeftPanelCoords.y（584）而非 .x，hideRedButton 才用 .x（540）
	RWTween.to(e_left_panel, 0.3, {"x": BOTTOM_LEFT_PANEL_COORDS.y})
	small_horiz.mouse_enabled = true
	small_vert.mouse_enabled = true
	if game_uni.get_num_selected_units > 1:
		_show_right_button(small_horiz)
		_show_right_button(small_vert)
	else:
		_hide_right_button(small_horiz)
		_hide_right_button(small_vert)
	red_button_shown = true


func _reset_pos(param1: float) -> void:
	for mc: FlashClip in [e_vert, e_horiz, e_got_upgrade, e_formation, e_attack_def, e_defend]:
		mc.visible = false
		mc.position.y = param1


func hide_red_button() -> void:
	if not _ok() or a_buttons.is_empty():
		return
	RWTween.to(e_left_panel, 0.3, {"x": BOTTOM_LEFT_PANEL_COORDS.x})
	RWTween.all_to([small_horiz, small_vert], 0.2, {"y": 564}, 0.1)
	small_horiz.mouse_enabled = false
	small_vert.mouse_enabled = false
	for mc: FlashClip in a_buttons:
		mc.mouse_enabled = false
	for mc: FlashClip in [e_vert, e_horiz, e_got_upgrade, e_formation, e_attack_def, e_defend]:
		mc.visible = true
	RWTween.all_from([e_vert, e_got_upgrade, e_horiz, e_formation, e_attack_def, e_defend], 0.3, {"y": "42"}, 0.1)
	var bstart: FlashClip = e_next_wave_pad.get_node("bStart")
	var pad: FlashClip = e_next_wave_pad.get_node("eAutostartPad")
	bstart.mouse_enabled = false
	e_next_wave_pad.mouse_enabled = false
	red_button_shown = false
	RWTween.to(pad, 0.3, {"alpha": 0})
	RWTween.to(e_next_wave_pad, 0.4, {"y": -11, "delay": 0.4})
	if game_uni.get_num_selected_units > 1:
		_show_right_button(e_horiz)
		_show_right_button(e_vert)
		_show_right_button(e_formation)
	else:
		_hide_right_button(e_formation)
		_hide_right_button(e_horiz)
		_hide_right_button(e_vert)


## 倒计时秒数 = floor(帧计数 / 30)，小于 0 取 0。
func update_red_button(param1: int) -> void:
	if not _ok():
		return
	var secs := floorf(float(param1) / 30.0)
	if secs < 0:
		secs = 0
	(e_next_wave_pad.get_node("eAutostartPad/tCounter") as FlashText).text = _as3_num(secs)


func disable_defend_button_animation() -> void:
	if not _ok():
		return
	_stop_defend_button_anim()
	game_uni.disable_hold_ground()


func _stop_defend_button_anim() -> void:
	RWTween.to(e_defend.get_node("eIco"), 0.3, {"alpha": 0})


func enable_defend_button_animation() -> void:
	_start_defend_button_anim()
	game_uni.enable_hold_ground()


func enable_attack_def_button() -> void:
	if not _ok():
		return
	if is_attack_button_clicked == false:
		RWTween.to(e_attack_def.get_node("eIco"), 0.3, {"alpha": 1})
		is_attack_button_clicked = true


func enable_formation_button() -> void:
	if not _ok():
		return
	if is_formation_clicked == false:
		RWTween.to(e_formation.get_node("eIco"), 0.3, {"alpha": 1})
		is_formation_clicked = true


func reset_formation_button() -> void:
	if not _ok():
		return
	RWTween.to(e_formation.get_node("eIco"), 0.3, {"alpha": 0})
	is_formation_clicked = false


func _start_defend_button_anim() -> void:
	RWTween.to(e_defend.get_node("eIco"), 0.3, {"alpha": 1})


func _sub_panel_invis() -> void:
	for mc: FlashClip in a_sub_units_panel:
		mc.visible = false


func _not_ready_yet() -> void:
	_chat_message("Can't hire unit, not ready yet.")
	_play_sound(s.BTN_DENY, 0.38)


func _click_button(_param1: FlashClip) -> void:
	pass   # 原版为空函数


func _not_enough_money() -> void:
	_chat_message("Can't hire unit. Not enough gold.")
	_play_sound(s.BTN_DENY, 0.38)
