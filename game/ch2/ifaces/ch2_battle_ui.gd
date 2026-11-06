# 二次开发：第二章战斗界面（MainGameUIEx）的三格扩展，由 main_game_ui_ex.gd 里几处薄钩子调用。
# - 招募子面板第二页：职业头像 / 高级武器 A / 高级武器 B，直接招募该武器的单位；
# - 单位面板：一代进阶用的 eUpgrade -> eUnitSelect（bTop / bDown）改成换武器，技能槽显示二章技能图标，火铳卫弹匣格；
# - 一代第一页与一代单位的行为一概不动：所有钩子在非二章战斗或非二章单位时直接回到原路径。
# 二章单位类（Ch2Warden 等）由 D1 提供，这里只用鸭子类型：set_weapon(id)、weapon、弹匣剩余数字段。
class_name Ch2BattleUi
extends RefCounted

const CELL_BOX := Vector2(30, 32)
const SKILL_BOX := Vector2(42, 42)
const BTN_BOX := Vector2(34, 30)
const AMMO_ORIGIN := Vector2(82, -60)
const AMMO_STEP := 11.0
const AMMO_SIZE := 9.0
const FONT_PATH := "res://assets/library/font/5596_Minion Pro.ttf"
const GOLD := Color(0.96, 0.82, 0.45, 1.0)

var ui: MainGameUIEx
var page: int = 1
var pager: Ch2Pager
## 测试可替换：招募一个 kind 的单位并返回它，默认走 GameUniverse.add_soldier。
var hire_fn: Callable = Callable()

var _cell_icons: Array = []        # 招募子面板 3 格各一个 TextureRect
var _skill_icons: Array = []       # 单位面板 2 个技能槽各一个 TextureRect
var _portrait: TextureRect
var _ammo_cells: Array = []        # ColorRect
var _btn_icons: Array = []         # [bTop 图标, bDown 图标]
var _btn_fees: Array = []          # [bTop 费用, bDown 费用]
var _btn_frames: Array = []        # [bTop 选中框, bDown 选中框]
var _unit_mode_ch2: bool = false   # 单位面板当前是否处于二章显示
var _shown_weapon: String = ""
var _shown_can_upgrade: bool = false
var _font: Font


func _init(p_ui: MainGameUIEx) -> void:
	ui = p_ui
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)


func is_ch2_battle() -> bool:
	return ui.game_uni != null and ui.game_uni.chapter == 2


func is_ch2_unit(u: LivingObject) -> bool:
	return u != null and u.friendly and Ch2UiData.is_ch2_friend(u)


# ================================================================ 招募子面板第二页

func _ensure_cell_widgets() -> void:
	if not _cell_icons.is_empty():
		return
	for cell: FlashClip in [ui.e_sub_one, ui.e_sub_two, ui.e_sub_three]:
		var r := Ch2UiData.make_icon(cell, CELL_BOX, Vector2.ZERO)
		r.visible = false
		_cell_icons.append(r)
	pager = Ch2Pager.create()
	pager.visible = false
	pager.flipped.connect(_on_flipped)
	ui.add_child(pager)


func can_page_two() -> bool:
	if not is_ch2_battle():
		return false
	var prof := Ch2UiData.profession_of_n(ui.last_clicked_unit_number)
	return prof != "" and StoredData.ch2_class_open(prof)


## _show_sub_panel 末尾调用：每次打开都回到第一页；二章且本职业有二章新职业时露出翻页器。
func on_sub_panel_shown() -> void:
	_ensure_cell_widgets()
	page = 1
	_apply_page()
	pager.visible = can_page_two()
	if pager.visible:
		pager.set_page(1)
		pager.position = Vector2(ui.e_sub_two.position.x - pager.size.x * 0.5, ui.sub_units_panel_y - 46.0)


func on_sub_panel_hide() -> void:
	if pager != null:
		pager.visible = false


func _on_flipped(_delta: int) -> void:
	page = 2 if page == 1 else 1
	pager.set_page(page)
	ui._play_sound(ui.s.CLICK1, 0.3)
	_apply_page()


func _cells() -> Array:
	return [ui.e_sub_one, ui.e_sub_two, ui.e_sub_three]


func _apply_page() -> void:
	var prof := Ch2UiData.profession_of_n(ui.last_clicked_unit_number)
	var cells := _cells()
	for i in 3:
		var ico: FlashClip = (cells[i] as FlashClip).get_node("eIco")
		var ov: TextureRect = _cell_icons[i]
		if page == 2 and prof != "":
			var w := Ch2UiData.slot_weapon(prof, i)
			if Ch2UiData.weapon_usable(w):
				ico.visible = false
				ov.texture = Ch2UiData.portrait_tex(prof) if i == 0 else Ch2UiData.weapon_tex(w)
				ov.visible = true
			else:
				ov.visible = false
				ico.visible = true
				ico.goto_and_stop(6)  # 一代的锁定帧
		else:
			ov.visible = false
			ico.visible = true
			_restore_page_one_frame(i, ico)


## 回到第一页：重现 _show_sub_panel 里的帧（职业图标，被关卡锁的兵种为锁定帧）。
func _restore_page_one_frame(i: int, ico: FlashClip) -> void:
	var n := ui.last_clicked_unit_number
	ico.goto_and_stop(n)
	if MainGameUIEx.tier_one().has(n):
		var kinds := [MainGameUIEx.tier_one()[n][1], MainGameUIEx.tier_two()[n][1], MainGameUIEx.tier_three()[n][1]]
		if ui.a_locked_units_and_buttons.find(kinds[i]) >= 0:
			ico.goto_and_stop(6)


## 点第二页的某一格（slot 0..2）。返回 true 表示已处理（第二页）。
func cell_clicked(slot: int) -> bool:
	if page != 2:
		return false
	var prof := Ch2UiData.profession_of_n(ui.last_clicked_unit_number)
	if prof == "":
		return true
	var w := Ch2UiData.slot_weapon(prof, slot)
	if not Ch2UiData.weapon_usable(w):
		if Ch2UiData.AVAILABLE_WEAPONS.has(w):
			ui._chat_message(Ch2UiData.weapon_name(w) + " is locked. Unlock it in the upgrade panel.")
		else:
			ui._chat_message(Ch2UiData.weapon_name(w) + " is not avaliable for this mission")
		ui._play_sound(ui.s.BTN_DENY, 0.38)
		return true
	var fee := 0 if slot == 0 else Ch2UiData.upgrade_fee(prof)
	var cost := Ch2UiData.unit_cost(prof) + fee
	if ui.dest_money < cost:
		ui._not_enough_money()
		return true
	var kind := int(Ch2UiData.PROFESSIONS[prof]["kind"])
	var u: Variant = hire_fn.call(kind) if hire_fn.is_valid() else ui.game_uni.add_soldier(kind)
	if u == null:
		ui._chat_message(Ch2UiData.profession_name(prof) + " is not avaliable for this mission")
		return true
	if slot > 0:
		if u.has_method("set_weapon"):
			u.call("set_weapon", w, true)  # force：直接招来的高级武器单位从 3 级起步，不走熟练度门槛
		ui.game_uni.set_money(-fee)
	_start_class_cool_down(ui.last_clicked_unit_number)
	ui.hide_sub_panel()
	return true


## 与一代 _selected_tier 成功招募后相同：对应职业按钮进入招募冷却。
func _start_class_cool_down(n: int) -> void:
	var now: int = ui.game_uni.get_game_time()
	var btn: FlashClip
	match n:
		1:
			ui.warrior_cool_down_status = 0
			ui.warrior_last_built_time = now
			btn = ui.e1
		2:
			ui.archer_cool_down_status = 0
			ui.archer_last_built_time = now
			btn = ui.e4
		_:
			return
	ui._set_alpha(ui._cool_down_clip(btn), 1.0)
	RWTween.from(ui._cool_down_clip(btn), 0.2, {"alpha": 0})


## 悬停提示。返回 true 表示已填好提示文字（调用方只需更新宽度与位置）。
func rover(mc: FlashClip, tname: FlashText, tcost: FlashText, eback: FlashClip) -> bool:
	var cells := _cells()
	var slot := cells.find(mc)
	if page == 2 and slot >= 0:
		var prof := Ch2UiData.profession_of_n(ui.last_clicked_unit_number)
		if prof == "":
			return false
		var w := Ch2UiData.slot_weapon(prof, slot)
		ui.e_hint.visible = true
		tname.text = Ch2UiData.profession_name(prof) if slot == 0 else Ch2UiData.weapon_name(w)
		var cost := Ch2UiData.unit_cost(prof) + (0 if slot == 0 else Ch2UiData.upgrade_fee(prof))
		tcost.text = str(cost)
		return true
	var cur := _cur_unit()
	if is_ch2_unit(cur):
		var us := ui._unit_select()
		var idx := -1
		if mc == us.get_node("bTop"):
			idx = 0
		elif mc == us.get_node("bDown"):
			idx = 1
		if idx >= 0:
			var prof2 := Ch2UiData.unit_profession(cur)
			var w2 := Ch2UiData.slot_weapon(prof2, idx + 1)
			var from := Ch2UiData.unit_weapon_id(cur)
			ui.e_hint.visible = true
			eback.goto_and_stop(2)
			if w2 == from:
				ui._set_no_price()
				tname.text = Ch2UiData.weapon_name(w2)
			else:
				tname.text = Ch2UiData.weapon_name(w2)
				tcost.text = str(Ch2UiData.change_fee(prof2, from, w2))
			return true
	return false


## 单位是否满足“基础武器换高级武器”的条件（2 级经验练满）；D1 提供 can_upgrade_weapon()，缺失按 false。
func can_upgrade(u: Object) -> bool:
	return u != null and u.has_method("can_upgrade_weapon") and bool(u.call("can_upgrade_weapon"))


## 换武器按钮对该单位是否可点：已持高级武器时随时可互换；基础武器要先 can_upgrade_weapon()。
func _swap_allowed(u: Object, prof: String) -> bool:
	if Ch2UiData.unit_weapon_id(u) != str(Ch2UiData.PROFESSIONS[prof]["base"]):
		return true
	return can_upgrade(u)


## 单位面板的职业名（取自 Ch2Text），沿用一代 tLevelClass 的“头衔 + 换行 + 职业名”写法。
func class_name_for(u: LivingObject) -> String:
	if is_ch2_unit(u):
		return Ch2UiData.profession_name(Ch2UiData.unit_profession(u))
	return u.get_class_name


func _cur_unit() -> LivingObject:
	return ui.game_uni.get_cur_selected if ui.game_uni != null else null


# ================================================================ 单位面板：换武器

func _ensure_unit_widgets() -> void:
	if _portrait != null:
		return
	var panel := ui.e_unit_panel
	# 立绘：盖在 eIco（一代按 kind 帧显示）的位置
	_portrait = Ch2UiData.make_icon(panel, Vector2(62, 64), Vector2(33, -47))
	_portrait.visible = false
	# 技能图标：夹在 eAbility 与冷却盘之间，冷却盘照常盖在上面
	for name_ in ["eOne", "eTwo"]:
		var holder: FlashClip = panel.get_node(name_)
		var r := Ch2UiData.make_icon(holder, SKILL_BOX, Vector2.ZERO)
		holder.move_child(r, (holder.get_node("eAbility") as Node).get_index() + 1)
		r.visible = false
		_skill_icons.append(r)
	# 弹匣格：技能槽上方的空白处
	for i in 5:
		var c := ColorRect.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size = Vector2(AMMO_SIZE, AMMO_SIZE)
		c.position = AMMO_ORIGIN + Vector2(AMMO_STEP * i, 0)
		c.visible = false
		panel.add_child(c)
		_ammo_cells.append(c)
	# 换武器的两个按钮：图标 + 费用 + 当前武器选中框
	var us := ui._unit_select()
	for name_ in ["bTop", "bDown"]:
		var btn: FlashClip = us.get_node(name_)
		var icon := Ch2UiData.make_icon(btn, BTN_BOX, Vector2.ZERO)
		icon.visible = false
		_btn_icons.append(icon)
		var frame := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(2)
		sb.border_color = GOLD
		sb.set_corner_radius_all(3)
		frame.add_theme_stylebox_override("panel", sb)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.size = Vector2(46, 38)
		frame.position = Vector2(-23, -19)
		frame.visible = false
		btn.add_child(frame)
		_btn_frames.append(frame)
		var fee := Label.new()
		fee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fee.size = Vector2(46, 14)
		fee.position = Vector2(-23, 6)
		fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if _font != null:
			fee.add_theme_font_override("font", _font)
		fee.add_theme_font_size_override("font_size", 11)
		fee.add_theme_color_override("font_color", Color.WHITE)
		fee.add_theme_color_override("font_outline_color", Color.BLACK)
		fee.add_theme_constant_override("outline_size", 3)
		fee.visible = false
		btn.add_child(fee)
		_btn_fees.append(fee)


## update_soldier_data 中调用：选中单位的二章显示（立绘、技能图标、弹匣、换武器按钮）；非二章单位时还原。
func refresh_unit_panel(u: LivingObject) -> void:
	var is2 := is_ch2_unit(u)
	if not is2 and not _unit_mode_ch2:
		return
	_ensure_unit_widgets()
	var panel := ui.e_unit_panel
	var eico: FlashClip = panel.get_node("eIco")
	if not is2:
		_unit_mode_ch2 = false
		_shown_weapon = ""
		_portrait.visible = false
		eico.visible = true
		for i in 2:
			var holder: FlashClip = panel.get_node("eOne" if i == 0 else "eTwo")
			(holder.get_node("eAbility") as FlashClip).visible = true
			(_skill_icons[i] as TextureRect).visible = false
		for c: ColorRect in _ammo_cells:
			c.visible = false
		for i in 2:
			(_btn_icons[i] as TextureRect).visible = false
			(_btn_frames[i] as Panel).visible = false
			(_btn_fees[i] as Label).visible = false
		return
	_unit_mode_ch2 = true
	var prof := Ch2UiData.unit_profession(u)
	var wid := Ch2UiData.unit_weapon_id(u)
	eico.visible = false
	_portrait.texture = Ch2UiData.portrait_tex(prof)
	_portrait.visible = true
	for i in 2:
		var holder2: FlashClip = panel.get_node("eOne" if i == 0 else "eTwo")
		(holder2.get_node("eAbility") as FlashClip).visible = false
		var icon: TextureRect = _skill_icons[i]
		icon.texture = Ch2UiData.skill_tex(Ch2UiData.skill_id(wid, i))
		icon.visible = icon.texture != null
	# 弹匣格：五雷 5 格，其他火铳 1 格；打出去的格子变暗
	var cap := Ch2UiData.ammo_capacity(wid) if prof == "musketeer" else 0
	var left := Ch2UiData.unit_ammo(u, cap) if cap > 0 else 0
	for i in 5:
		var c: ColorRect = _ammo_cells[i]
		c.visible = i < cap
		c.color = GOLD if i < left else Color(0.25, 0.2, 0.12, 0.85)
	# 换武器按钮
	var can := _swap_allowed(u, prof)
	if wid != _shown_weapon or can != _shown_can_upgrade:
		_shown_weapon = wid
		_shown_can_upgrade = can
		_refresh_weapon_buttons(prof, wid, can)


func _refresh_weapon_buttons(prof: String, wid: String, allowed: bool) -> void:
	var us := ui._unit_select()
	for i in 2:
		var target := Ch2UiData.slot_weapon(prof, i + 1)
		var icon: TextureRect = _btn_icons[i]
		icon.texture = Ch2UiData.weapon_tex(target)
		icon.visible = icon.texture != null
		icon.modulate = Color.WHITE if (Ch2UiData.weapon_usable(target) and allowed) else Color(0.45, 0.45, 0.45, 1)
		(_btn_frames[i] as Panel).visible = target == wid
		var fee: Label = _btn_fees[i]
		fee.visible = target != wid
		fee.text = str(Ch2UiData.change_fee(prof, wid, target))
	(us.get_node("eUpgradeNotAllowedTop") as FlashClip).visible = not Ch2UiData.weapon_usable(Ch2UiData.slot_weapon(prof, 1))
	(us.get_node("eUpgradeNotAllowedBottom") as FlashClip).visible = not Ch2UiData.weapon_usable(Ch2UiData.slot_weapon(prof, 2))


## 二章单位：基础武器练满 2 级经验（can_upgrade_weapon）后，或已持高级武器时，露出 eUpgrade，点它打开换武器面板。
func update_upgrade_entry(up: FlashClip, u: LivingObject) -> void:
	if _swap_allowed(u, Ch2UiData.unit_profession(u)):
		if up.position.y != ui.e_upgrade_panel_coords.y:
			RWTween.to(up, 0.2, {"y": ui.e_upgrade_panel_coords.y})
		up.mouse_enabled = true
		up.play()
	elif up.position.y != ui.e_upgrade_down_coord:
		RWTween.to(up, 0.2, {"y": ui.e_upgrade_down_coord})


## eUpgrade 被点：打开 eUnitSelect（bTop / bDown 已显示武器图标）。
func open_weapon_select() -> void:
	var u := _cur_unit()
	var prof := Ch2UiData.unit_profession(u)
	var us := ui._unit_select()
	_ensure_unit_widgets()
	_shown_weapon = ""   # 强制下一帧刷新按钮
	_refresh_weapon_buttons(prof, Ch2UiData.unit_weapon_id(u), _swap_allowed(u, prof))
	RWTween.to(us, 0.3, {"y": ui.unit_select_panel_coords.y})
	ui._play_sound(ui.s.CLICK1, 0.38)
	(us.get_node("eSelector") as FlashClip).goto_and_stop(int(Ch2UiData.PROFESSIONS[prof]["selector"]))


## bTop / bDown 被点（is_top：上方按钮 = 高级 A）。返回 true 表示已处理。
func weapon_button_clicked(is_top: bool) -> bool:
	var u := _cur_unit()
	if not is_ch2_unit(u):
		return false
	var prof := Ch2UiData.unit_profession(u)
	var to := Ch2UiData.slot_weapon(prof, 1 if is_top else 2)
	var from := Ch2UiData.unit_weapon_id(u)
	if to == from:
		return true
	if not _swap_allowed(u, prof):
		ui._chat_message("Not enough experience to take up a new weapon.")
		ui._play_sound(ui.s.BTN_DENY, 0.38)
		return true
	if not Ch2UiData.weapon_usable(to):
		if Ch2UiData.AVAILABLE_WEAPONS.has(to):
			ui._chat_message(Ch2UiData.weapon_name(to) + " is locked. Unlock it in the upgrade panel.")
		else:
			ui._chat_message(Ch2UiData.weapon_name(to) + " is not avaliable for this mission")
		ui._play_sound(ui.s.BTN_DENY, 0.38)
		return true
	var fee := Ch2UiData.change_fee(prof, from, to)
	if ui.dest_money < fee:
		ui._chat_message("Can't change weapon. Not enough gold.")
		ui._play_sound(ui.s.BTN_DENY, 0.38)
		return true
	if u.has_method("set_weapon"):
		u.call("set_weapon", to)
	ui.game_uni.set_money(-fee)
	ui.hide_has_upgrade_button(u)  # 一代 add_pro_unit 同样先撤掉“可升级”提示
	_play_changed_effect(u)
	ui._chat_message(Ch2UiData.profession_name(prof) + " takes up the " + Ch2UiData.weapon_name(to))
	RWTween.to(ui.e_unit_panel.get_node("eUpgrade"), 0.2, {"y": ui.e_upgrade_down_coord})
	ui._close_upgrade_panel()
	_shown_weapon = ""
	return true


## 一代升级完成特效（UpgradeCompleted），挂在单位头顶，同 LivingObject.upgrade_clicked。
func _play_changed_effect(u: LivingObject) -> void:
	var done := UpgradeCompleted.new(u.get_level)
	u.add_child(done)
	done.position.x = u.sens.position.x
	done.position.y = u.sens.position.y - u.sens_height / 2 - 12
