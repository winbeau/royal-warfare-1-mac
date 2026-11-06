# 二次开发：升级面板第二页（第二章的武器解锁、技能加点、职业加成），由 upgr_panel_ex.gd 的几处薄钩子驱动。
#
# 用户 2026-11-06 两次追加明确要求：不自己搭格子，直接复用一代第一页"战士组"（镇戍卫）、"弓手组"（火铳卫）
# 两组的真实节点——同一批 u_war_*/u_arch_*/u_warriors_*/u_archers_* FlashClip，第一页什么都不隐藏、不挪动，
# 只在它们上面叠一层我们自己的图标与点击热区（页 2 可见、页 1 隐藏），星级/解锁格直接驱动这些节点自带的
# eLock 子剪辑（2 帧=职业/武器解锁角标，5 帧=技能等级角标，同一代 unlock_ability/unlock_unit 的用法）。
# 法师、盗贼、牧师三组本阶段不开放，什么都不做，就是第一页本来的样子（含它们自己的 zanaves 幕布）。
#
# 坐标来源：不抄写任何写死的像素表。每一步都从真实节点现场取 position/scale 和自身烘焙图层的包围盒
# （Ch2UiData.backdrop_bounds，只看 _back/_front，不下探子剪辑），这样才不会把 FlashClip 的注册点当成
# 左上角、也不会把 eLock 星级角标算进"图标区域"（见 _icon_box）。
#
# 调查结论（找不到可单独隐藏的"图标子剪辑"）：uWarSwordA 等格子在 scenes/clips/Symbol_307.tscn 这一级
# 只有一个 eLock 子节点；图标本身和蓝底金框是同一张烘焙位图（assets/clips/307/b0.png），管线把矢量图形
# 栅格化时没有把"图标"和"边框"拆成两层。因此做不到"隐藏图标、保留边框"，退而求其次：把我们的图标
# 收在 _icon_box 算出的中心区域（已经排开 eLock 的位置），四周留边，蓝底金框的边缘仍然露在外面。
class_name Ch2UpgradePage
extends Control

const GOLD := Color(0.96, 0.82, 0.45, 1.0)
const DIM := Color(0.45, 0.45, 0.45, 1.0)
const FONT_PATH := "res://assets/library/font/5596_Minion Pro.ttf"
## 每个职业对应一代哪一组的哪些真实节点（UpgrPanelEx 的公开字段名）。
## base_icon：无锁的职业头像格；base_ab：该组的两个基础技能格（都带 5 帧 eLock）；
## adv_unit[0]/adv_ab[0] 对应高级武器 A，[1] 对应 B——按该组三个"解锁格"自身的 x 坐标从左到右排，
## 和基础格左右相邻（战士组：sword 在左、knight 在右；弓手组：sniper 在左、crossb 在右，用户 2026-11-06
## 实测给出）。bonus：两个加成格（都带 5 帧 eLock）。
const NODE_MAP := {
	"warden": {
		"base_icon": "u_warrior_icon", "base_ab": ["u_war_warrior_a", "u_war_warrior_b"],
		"adv_unit": ["u_war_sword_unit", "u_war_knight_unit"],
		"adv_ab": [["u_war_sword_a", "u_war_sword_b"], ["u_war_knight_a", "u_war_knight_b"]],
		"bonus": ["u_warriors_attack", "u_warriors_defend"],
	},
	"musketeer": {
		"base_icon": "u_archer_icon", "base_ab": ["u_arch_archer_a", "u_arch_archer_b"],
		"adv_unit": ["u_arch_sniper_unit", "u_arch_crossb_unit"],
		"adv_ab": [["u_arch_sniper_a", "u_arch_sniper_b"], ["u_arch_crossb_a", "u_arch_crossb_b"]],
		"bonus": ["u_archers_attack", "u_archers_defend"],
	},
}
## 未开放三职业：法师组→Elementalist、盗贼组→Outrider、牧师组→Exorcist（用户 2026-11-06 给定）。
## 幕布字段名 -> 显示用的 ch2 职业 id；一代自己的幕布节点完全不碰，这里各建一份独立副本盖住对应区域。
const CLOSED_CURTAIN := {"zanaves_mages": "elementalist", "zanaves_thieves": "outrider", "zanaves_priests": "exorcist"}

var panel: UpgrPanelEx
var page: int = 1
var pager: Ch2Pager
var overlay: Control    # 页 2 的全部叠加内容，页 1 时整体隐藏；真实节点自己什么都不改
var _font: Font
var _skill_pads: Dictionary = {}    # skill_id -> {"hit": Control}（基础技能 + 高级武器的升级技能）
var _weapon_pads: Dictionary = {}   # weapon_id -> {"hit": Control, "real": FlashClip}
var _bonus_pads: Dictionary = {}    # "prof:slot" -> {"real": FlashClip}
var _skill_real: Dictionary = {}    # skill_id -> 挂着的真实节点（驱动 eLock 用）


## 在升级面板上挂第二页。default_page 为 2 时（从二章地图或二章胜利面板进入）直接显示第二页。
static func attach(p: UpgrPanelEx, default_page: int) -> Ch2UpgradePage:
	var n := Ch2UpgradePage.new()
	n.panel = p
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.size = Vector2(700, 600)
	if ResourceLoader.exists(FONT_PATH):
		n._font = load(FONT_PATH)
	p.add_child(n)  # 加在最后：z 序盖过第一页所有节点，点击优先落在我们叠的热区上
	n._build()
	n.show_page(default_page)
	return n


## 翻页按钮只在二章可达（一代通关 / 调试参数 / dev 版 / 已在二章）时出现。
static func should_offer(chapter: int) -> bool:
	return chapter == 2 or StoredData.dev or StoredData.ch2_available()


func _build() -> void:
	pager = Ch2Pager.create(Vector2(70, 18))
	pager.position = Vector2(14, 10)
	pager.flipped.connect(func(_d: int) -> void: show_page(2 if page == 1 else 1))
	add_child(pager)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = size
	add_child(overlay)
	# "Chapter II" 放在翻页器 "2/2" 右侧同一行，不盖任何格子（翻页器已经在左上角，见上面几行）。
	_label(overlay, "Chapter II", pager.position + Vector2(pager.size.x + 8, -2), 160, 13, GOLD)
	for prof: String in NODE_MAP:
		_build_open_column(prof)
	for field: String in CLOSED_CURTAIN:
		_build_closed_curtain(field, CLOSED_CURTAIN[field])
	overlay.visible = false


func _label(parent: Control, text: String, pos: Vector2, w: float, fs: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.position = pos
	l.size = Vector2(w, fs + 8)
	l.horizontal_alignment = align as HorizontalAlignment
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	parent.add_child(l)
	return l


## real 节点在 panel 坐标系下的完整包围盒（position 是注册点，真正左上角要加 data.rect.position）。
func _full_box(real: FlashClip) -> Rect2:
	var local := Ch2UiData.backdrop_bounds(real)
	return Rect2(real.position + local.position * real.scale, local.size * real.scale)


## real 节点"深蓝图标区"在 panel 坐标系下的矩形：按 Ch2UiData.pad_icon_local_rect 给出的局部矩形
## （用户 2026-11-06 实测的比例，已经天然避开格子底部的星级角标），换算到 real 的父级坐标。
func _icon_box(real: FlashClip, is_unit_pad: bool) -> Rect2:
	var local := Ch2UiData.pad_icon_local_rect(real, is_unit_pad)
	return Rect2(real.position + local.position * real.scale, local.size * real.scale)


## 一代格子是整张烘焙位图，图标和蓝底金框一体，没法只隐藏图标；因此叠加层先铺一块不透明的深蓝底图
## （assets/ch2/ui/pad_bg.png，按配色取自一代格子）盖满整个图标区，再在上面居中画二章图标（等比缩放，
## 最长边占图标区 92%），这样一代原图标完全看不见，二者不会叠在一起。dim=true 用于灰色继承副本。
func _icon_overlay(box: Rect2, tex: Texture2D, dim: bool = false) -> void:
	var bg := TextureRect.new()
	bg.texture = Ch2UiData.pad_bg_tex()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = box.position
	bg.size = box.size
	if dim:
		bg.modulate = DIM
	overlay.add_child(bg)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = box.size * 0.92
	icon.position = box.position + (box.size - icon.size) * 0.5
	icon.texture = tex
	if dim:
		icon.modulate = DIM
	overlay.add_child(icon)


## 热区：STOP 过滤，叠在 real 节点之上，拦下点击不让它传到一代自己的监听（见文件头）。
func _hit_box(box: Rect2, on_click: Callable, hover_text: String) -> Control:
	var hit := Control.new()
	hit.position = box.position
	hit.size = box.size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(hit)
	if on_click.is_valid():
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				on_click.call((e as InputEventMouseButton).shift_pressed))
	hit.mouse_entered.connect(func() -> void:
		IfaceUtil.play_sound(SoundLibrary.ROVER, 0, 0.2, 350, SoundLibrary.ROVER)
		panel.t_hint_text.text = hover_text)
	hit.mouse_exited.connect(func() -> void: panel.t_hint_text.text = panel.default_text)
	return hit


func _build_open_column(prof: String) -> void:
	var nm: Dictionary = NODE_MAP[prof]
	var base_skills: Array = Ch2UiData.BASE_SKILLS[prof]
	var adv: Array = Ch2UiData.PROFESSIONS[prof]["adv"]  # [A, B]

	# 基础列第 1 格：职业头像，没有锁（一直开放）。
	var base_icon: FlashClip = panel.get(nm["base_icon"])
	_icon_overlay(_icon_box(base_icon, true), Ch2UiData.portrait_tex(prof))
	_hit_box(_full_box(base_icon), Callable(), "%s is open from the start." % Ch2UiData.profession_name(prof))

	# 基础列第 2、3 格：两个基础技能。
	var base_nodes: Array = nm["base_ab"]
	for i in 2:
		_wire_skill(panel.get(base_nodes[i]), base_skills[i])

	# 高级 A / B 列：第 1 格武器解锁，第 2、3 格按继承关系放升级技能 + 灰色继承副本。
	for slot in 2:
		var w: String = adv[slot]
		var unit_node: FlashClip = panel.get((nm["adv_unit"] as Array)[slot])
		_wire_weapon(unit_node, w, true)
		var ab_nodes: Array = (nm["adv_ab"] as Array)[slot]
		var upgrade_sid: String = str(Ch2UiData.ADV_UPGRADE_SKILL.get(w, ""))
		var inherited: String = str(Ch2UiData.SKILL_INHERITS_FROM.get(upgrade_sid, ""))
		var inherited_row: int = base_skills.find(inherited)
		for row in 2:
			var node: FlashClip = panel.get(ab_nodes[row])
			if row == inherited_row:
				_wire_skill(node, upgrade_sid)
			else:
				# 用户 2026-11-06 修正：灰色副本 = 基础列同一行原样保留的那个基础技能（base_skills[row]），
				# 不是被超集替换掉的那个（inherited）——例如陌刀列第 3 行是 Intercept，不是 Hold Fast。
				var kept_sid: String = base_skills[row]
				_icon_overlay(_icon_box(node, false), Ch2UiData.skill_tex(kept_sid), true)
				_hit_box(_icon_box(node, false), Callable(), "Inherited: %s" % Ch2UiData.skill_name(kept_sid))
				var ghost_lock := node.child_clip("eLock")
				if ghost_lock != null:
					ghost_lock.goto_and_stop(1)  # 灰色禁用帧：不随 ch2 存档变化，始终显示"未加点"的样子

	# 两个加成格：保留一代原图标（攻击/防御的通用图样），只接我们的点击与 ch2 等级。
	var bonus_nodes: Array = nm["bonus"]
	for slot in 2:
		_wire_bonus(panel.get(bonus_nodes[slot]), prof, slot)


func _wire_skill(real: FlashClip, sid: String) -> void:
	var box := _icon_box(real, false)
	_icon_overlay(box, Ch2UiData.skill_tex(sid))
	var hit := _hit_box(box, func(shift: bool) -> void: _on_skill(sid, shift), "")
	_skill_pads[sid] = {"hit": hit}
	_skill_real[sid] = real


func _wire_weapon(real: FlashClip, w: String, is_unit_pad: bool) -> void:
	_icon_overlay(_icon_box(real, is_unit_pad), Ch2UiData.weapon_tex(w))
	var hit := _hit_box(_full_box(real), func(shift: bool) -> void: _on_weapon(w, shift), "")
	_weapon_pads[w] = {"hit": hit, "real": real}


func _wire_bonus(real: FlashClip, prof: String, slot: int) -> void:
	var hit := _hit_box(_full_box(real), func(shift: bool) -> void: _on_bonus(prof, slot, shift), "")
	_bonus_pads["%s:%d" % [prof, slot]] = {"real": real, "hit": hit}


## 未开放三职业：在叠加层里各建一份一代幕布（zanavesUpgr）的独立副本，位置/缩放照搬对应一代节点，
## 停在"幕布落下"的默认姿态（zanavesUpgr 只有 1 帧，揭示动画移动的是子剪辑 e0 的 y：0=落下盖住、
## -height=升起，见 check_zanaves_and_tier_three；新建的副本不跑那段揭示逻辑，e0.y 天生就是 0，
## 不需要额外设置）。接遮罩的做法和 init_once() 一样（getChildAt(0).mask = msk）。
## 一代自己的 zanaves_mages/thieves/priests 节点完全不碰，不受本页翻页影响。
func _build_closed_curtain(field: String, ch2_prof: String) -> void:
	var real: FlashClip = panel.get(field)
	var copy := (load("res://scenes/clips/zanavesUpgr.tscn") as PackedScene).instantiate() as FlashClip
	copy.position = real.position
	copy.scale = real.scale
	overlay.add_child(copy)
	IfaceUtil.when_ready(copy, func() -> void:
		var zc := UpgrPanelEx.zanaves_child(copy)
		var msk := copy.get_node_or_null("msk") as Control
		if zc != null and msk != null:
			FlashClip.set_mask(zc, msk)
		var box := Rect2(Vector2.ZERO, real.size)  # zanavesUpgr 与一代节点同一份 data，尺寸一致
		_label(copy, Ch2UiData.profession_name(ch2_prof), Vector2(0, box.size.y * 0.42), box.size.x, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_label(copy, "Not available yet", Vector2(0, box.size.y * 0.42 + 22), box.size.x, 14, Color(0.9, 0.86, 0.7), HORIZONTAL_ALIGNMENT_CENTER))


# ================================================================ 翻页

func show_page(p: int) -> void:
	page = p
	pager.set_page(p)
	if p == 2:
		overlay.visible = true
		refresh()
	else:
		overlay.visible = false
		panel.t_free_stars.text = str(panel.num_free_stars)
		panel.t_hint_text.text = panel.default_text


func free_stars() -> int:
	return StoredData.ch2_stars_free()


## 按存档重画：星数、武器解锁格、技能等级、职业加成，全部直接驱动真实节点自带的 eLock。
func refresh() -> void:
	panel.t_free_stars.text = str(free_stars())
	for w: String in _weapon_pads:
		var lock := (_weapon_pads[w]["real"] as FlashClip).child_clip("eLock")
		if lock != null:
			lock.goto_and_stop(2 if Ch2UiData.weapon_usable(w) else 1)
	for sid: String in _skill_real:
		var lock2 := (_skill_real[sid] as FlashClip).child_clip("eLock")
		if lock2 == null:
			continue
		var w2 := _skill_owner_weapon(sid)
		var usable := Ch2UiData.weapon_usable(w2)
		lock2.goto_and_stop(StoredData.ch2_skill_level(sid) + 2 if usable else 1)
	for key: String in _bonus_pads:
		var parts := key.split(":")
		var lvl := StoredData.ch2_bonus_level(parts[0], int(parts[1]))
		var lock3 := (_bonus_pads[key]["real"] as FlashClip).child_clip("eLock")
		if lock3 != null:
			lock3.goto_and_stop(lvl + 2 if lvl > 0 else 1)


## 技能所属的武器（基础技能属于该职业的基础武器；升级技能属于拥有它的那把高级武器）。
func _skill_owner_weapon(sid: String) -> String:
	for prof: String in Ch2UiData.PROFESSIONS:
		if Ch2UiData.BASE_SKILLS.get(prof, []).has(sid):
			return str(Ch2UiData.PROFESSIONS[prof]["base"])
	for w: String in Ch2UiData.ADV_UPGRADE_SKILL:
		if Ch2UiData.ADV_UPGRADE_SKILL[w] == sid:
			return w
	return ""


# ================================================================ 点击

func _deny(text: String) -> void:
	IfaceUtil.play_sound(SoundLibrary.BTN_DENY, 0, 0.4)
	panel.t_hint_text.text = text


func _on_weapon(w: String, _shift: bool) -> void:
	if not Ch2UiData.AVAILABLE_WEAPONS.has(w):
		_deny("%s is not available yet." % Ch2UiData.weapon_name(w))
		return
	if StoredData.ch2_weapon_unlocked(w):
		return
	if free_stars() < 1:
		_deny("Can't unlock the weapon. You need more stars. Get more by passing chapter II levels with better results.")
		return
	StoredData.ch2_unlock_weapon(w)
	StoredData.save_shared_data()
	IfaceUtil.play_sound(SoundLibrary.UPG_CLICK1, 0, 0.25)
	refresh()
	panel.t_hint_text.text = "%s unlocked." % Ch2UiData.weapon_name(w)


## 技能加点：+1 级花 1 星；shift 为 -1 级退 1 星。武器未解锁时不能加点。
func _on_skill(sid: String, shift: bool) -> void:
	var w := _skill_owner_weapon(sid)
	var lv := StoredData.ch2_skill_level(sid)
	if not Ch2UiData.weapon_usable(w):
		_deny("This weapon is not avaliable right now")
		return
	if shift:
		if lv <= 1:
			_deny("Can't downgrade the ability. It is already at the first level.")
			return
		StoredData.ch2_set_skill_level(sid, lv - 1)
		IfaceUtil.play_sound(SoundLibrary.UPG_CLICK3 if lv == 3 else SoundLibrary.UPG_CLICK2, 0, 0.25)
	else:
		if lv >= 3:
			_deny("Can't upgrade the ability. It is already at maximum.")
			return
		if free_stars() < 1:
			_deny("Can't upgrade ability. You need more stars. Get more by passing chapter II levels with better results.")
			return
		StoredData.ch2_set_skill_level(sid, lv + 1)
		IfaceUtil.play_sound(SoundLibrary.UPG_CLICK3 if lv == 2 else SoundLibrary.UPG_CLICK2, 0, 0.25)
	StoredData.save_shared_data()
	refresh()
	panel.t_hint_text.text = "%s (Lv %d/3)\n%s" % [Ch2UiData.skill_name(sid), StoredData.ch2_skill_level(sid), Ch2UiData.skill_description(sid)]


## 职业加成加点：规则、花费与一代 ability_clicked 对加成格的处理相同（0..3 级，每级 1 星）。
func _on_bonus(prof: String, slot: int, shift: bool) -> void:
	var lv := StoredData.ch2_bonus_level(prof, slot)
	if shift:
		if lv <= 0:
			_deny("Can't downgrade the ability. It is already disabled.")
			return
		StoredData.ch2_set_bonus_level(prof, slot, lv - 1)
		IfaceUtil.play_sound(SoundLibrary.UPG_CLICK3 if lv == 3 else SoundLibrary.UPG_CLICK2, 0, 0.25)
	else:
		if lv >= 3:
			_deny("Can't upgrade the ability. It is already at maximum.")
			return
		if free_stars() < 1:
			_deny("Can't upgrade ability. You need more stars. Get more by passing chapter II levels with better results.")
			return
		StoredData.ch2_set_bonus_level(prof, slot, lv + 1)
		IfaceUtil.play_sound(SoundLibrary.UPG_CLICK3 if lv == 2 else SoundLibrary.UPG_CLICK2, 0, 0.25)
	StoredData.save_shared_data()
	refresh()
	panel.t_hint_text.text = _bonus_hover_text(prof, slot)


func _bonus_hover_text(prof: String, slot: int) -> String:
	var label_ := "Attack" if slot == 0 else "Defend"
	return "%s %s  (Lv %d/3)" % [Ch2UiData.profession_name(prof), label_, StoredData.ch2_bonus_level(prof, slot)]


## Reset 按钮在第二页：退还二章的全部加点（技能、职业加成、付费解锁的武器）。
func reset_upgrades() -> void:
	StoredData.ch2_reset_upgrades()
	StoredData.save_shared_data()
	refresh()
	panel.t_hint_text.text = panel.default_text


## 面板离开舞台时：第一页从未被改过，这里只需要把我们叠的内容整体摘掉。
func detach() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
