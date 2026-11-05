# 移植自 S/gameCore/ifaces/vinDefPanelAchivesController.as
# 胜利/失败面板里"本局新获得的成就"：每页最多 5 个图标（eIconsAchives 的第 n+1 帧），超过 5 个时 bLeft/bRight 翻页，
# 悬停图标在 eHint 里显示成就描述。
#
# 反编译破损：init 里分页的 for 循环（do { ... continue loop1 } while(aPages.push(...), false)）按语义重建：
#   每收满 5 个且不是最后一个元素时，把当前页入 aPages 并 totalNumOfPages++，循环结束后再把余下的一页入 aPages 并 totalNumOfPages++。
#   所以 totalNumOfPages 始终比实际页数大 1（原版如此，没有修正）。
# 原版疑点（照搬）：bLeft 在第 1 页点击时 curpage 变成 totalNumOfPages，showPage 访问 aPages[totalNumOfPages-1]
#   越界，原版此处抛 TypeError（事件回调里被吞掉），此时容器已被清空。这里同样清空后直接返回，不报错。
# 偏离：Sprite 无鼠标事件，sprite1..5 用 Control 包住 eIconsAchives，ROLL_OVER/OUT 对应 mouse_entered/mouse_exited；
#   图标描述来自 achivesScreen_ex.aAchivesDescription（由界面移植的其他部分负责，按 class_name 动态取）。
class_name VinDefPanelAchivesController
extends RefCounted

## 原版的 Sprite：位置（Flash 坐标）保存在 flash_x，Control 自身的位置放在包围盒左上角，便于悬停。
class AchiveSprite extends Control:
	var flash_x: float = 0.0
	var icon: FlashClip
	var rover_cb: Callable
	var rout_cb: Callable

	func width() -> float:
		return size.x * scale.x

static var panel: FlashClip
static var a_numbers: Array = []
static var e_no_new_achives: FlashClip
static var b_left: FlashClip
static var b_right: FlashClip
static var e_cont: FlashClip
static var total_num_of_pages: int = 0
static var curpage: float = 0
static var a_pages: Array = []
static var a1: Array = []  # sprite1..5
static var a2: Array = []  # 其中的 eIconsAchives
static var s1descr: String = ""
static var s2descr: String = ""
static var s3descr: String = ""
static var s4descr: String = ""
static var s5descr: String = ""
static var e_hint: FlashClip  # hintAchivesStats
static var start_hint_text_coords_3line: Vector2
static var start_hint_text_coords_2line: Vector2
static var start_hint_text_coords_1line: Vector2

const ICONS_SCENE := "res://scenes/clips/eIconsAchives.tscn"

static func init_once() -> void:
	a1 = []
	a2 = []
	for i in 5:
		var sprite := AchiveSprite.new()
		sprite.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := (load(ICONS_SCENE) as PackedScene).instantiate() as FlashClip
		icon.stop()
		icon.mouse_enabled = false
		icon.mouse_children = false
		sprite.add_child(icon)
		sprite.icon = icon
		sprite.scale = Vector2(0.8, 0.8)
		a1.append(sprite)
		a2.append(icon)
	start_hint_text_coords_3line = Vector2(-21, 21)
	start_hint_text_coords_2line = Vector2(-21, 28)
	start_hint_text_coords_1line = Vector2(-21, 32)

static func init(param1: FlashClip, param2: Array, param3: FlashClip, param4: FlashClip, param5: FlashClip, param6: FlashClip, param7: FlashClip) -> void:
	if a1.is_empty() or not is_instance_valid(a1[0]):
		init_once()  # 原版由 Main 在装载阶段调用 vinDefPanelAchivesController.initOnce()
	var _loc8_: int
	e_hint = param7
	e_cont = param6
	b_right = param5
	b_left = param4
	e_no_new_achives = param3
	a_numbers = param2
	panel = param1
	param4.visible = false
	param5.visible = false
	total_num_of_pages = 1
	param7.visible = false
	param7.mouse_children = false
	param7.mouse_enabled = false
	(param7.get_node("tText") as FlashText).auto_size = "center"
	if param2.size() > 5:
		param4.visible = true
		param5.visible = true
		ButtonClass.add_brightness(param4, button_clicked)
		ButtonClass.add_brightness(param5, button_clicked)
	var _loc9_ := 0
	a_pages = []
	var _loc10_: Array = []
	var _loc11_ := 0
	while _loc11_ < param2.size():
		_loc8_ = int(param2[_loc11_])
		_loc10_.append(_loc8_)
		_loc9_ += 1
		if _loc9_ == 5 and _loc11_ < param2.size() - 1:
			a_pages.append(_loc10_)
			total_num_of_pages += 1
			_loc10_ = []
			_loc9_ = 0
		_loc11_ += 1
	a_pages.append(_loc10_)
	total_num_of_pages += 1
	param3.visible = param2.size() == 0
	for sp: AchiveSprite in a1:
		sp.rover_cb = rover.bind(sp)
		sp.rout_cb = rout
		# addEventListener 对同一函数重复挂接只算一次
		if not sp.mouse_entered.is_connected(sp.rover_cb):
			sp.mouse_entered.connect(sp.rover_cb)
		if not sp.mouse_exited.is_connected(sp.rout_cb):
			sp.mouse_exited.connect(sp.rout_cb)
	curpage = 1
	show_page(curpage)

static func rout() -> void:
	e_hint.visible = false

static func rover(param2: AchiveSprite) -> void:
	var _loc3_: String
	e_hint.visible = true
	var idx := a1.find(param2)
	_loc3_ = [s1descr, s2descr, s3descr, s4descr, s5descr][idx]
	var t_text: FlashText = e_hint.get_node("tText")
	t_text.text = _loc3_
	match IfaceUtil.num_lines(t_text):
		3:
			t_text.position.y = start_hint_text_coords_3line.y
		2:
			t_text.position.y = start_hint_text_coords_2line.y
		1:
			t_text.position.y = start_hint_text_coords_1line.y
	e_hint.position.x = e_cont.position.x + param2.flash_x + param2.width() / 2

static func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var _loc2_: FlashClip = param1.target
	if _loc2_ == b_left:
		curpage -= 1
		if curpage <= 0:
			curpage = total_num_of_pages
	elif _loc2_ == b_right:
		curpage += 1
		if curpage >= total_num_of_pages:
			curpage = 1
	show_page(curpage)

static func remove_events() -> void:
	if is_instance_valid(b_left):  # 静态引用可能指向已释放的旧面板
		ButtonClass.remove_brightnes(b_left, button_clicked)
	if is_instance_valid(b_right):
		ButtonClass.remove_brightnes(b_right, button_clicked)
	for sp: AchiveSprite in a1:
		# Flash 里 Sprite 由 GC 管理；Godot 中随面板释放会连带释放，所以离开舞台时先摘下
		if sp.get_parent() != null:
			sp.get_parent().remove_child(sp)
		if sp.mouse_entered.is_connected(sp.rover_cb):
			sp.mouse_entered.disconnect(sp.rover_cb)
		if sp.mouse_exited.is_connected(sp.rout_cb):
			sp.mouse_exited.disconnect(sp.rout_cb)

static func _descr(achive: Variant) -> String:
	var screen := IfaceUtil.global_script("AchivesScreenEx")
	if screen == null or achive == null:
		return ""
	var descr: Array = screen.get("a_achives_description")
	return str(descr[achive]) if descr != null and int(achive) < descr.size() else ""

## eCont.width：当前所有精灵包围盒的并集宽度（可排除一个正在摆放的精灵）。
static func _cont_width(exclude: AchiveSprite = null) -> float:
	var lo := INF
	var hi := -INF
	for c in e_cont.get_children():
		if c is AchiveSprite and c != exclude:
			var r := Rect2(c.position, c.size * c.scale)
			lo = minf(lo, r.position.x)
			hi = maxf(hi, r.end.x)
	return 0.0 if lo == INF else (hi - lo)

static func show_page(param1: float) -> void:
	var _loc4_: int
	var _loc5_: AchiveSprite
	var _loc6_: FlashClip
	for c in e_cont.get_children():
		if c is AchiveSprite:  # while(numChildren > 0) removeChildAt(0)
			e_cont.remove_child(c)
	var page_index := int(param1 - 1)
	if page_index < 0 or page_index >= a_pages.size():
		return  # 原版此处 aPages[...] 为 undefined，下一行抛 TypeError
	var _loc2_: Array = a_pages[page_index]
	s1descr = _descr(_loc2_[0] if _loc2_.size() > 0 else null)
	s2descr = _descr(_loc2_[1] if _loc2_.size() > 1 else null)
	s3descr = _descr(_loc2_[2] if _loc2_.size() > 2 else null)
	s4descr = _descr(_loc2_[3] if _loc2_.size() > 3 else null)
	s5descr = _descr(_loc2_[4] if _loc2_.size() > 4 else null)
	var _loc3_ := 0
	while _loc3_ < _loc2_.size():
		_loc4_ = int(_loc2_[_loc3_])
		_loc5_ = a1[_loc3_]
		_loc6_ = a2[_loc3_]
		# 先入树使图标就绪，再换帧、量尺寸（原版先换帧后 addChild，结果相同）。
		# sprite1..5 是静态复用的：Flash 的 addChild 会自动从旧父节点摘下，Godot 需要手动摘。
		if _loc5_.get_parent() != null:
			_loc5_.get_parent().remove_child(_loc5_)
		e_cont.add_child(_loc5_)
		_loc6_.goto_and_stop(_loc4_ + 1)
		var b := IfaceUtil.clip_bounds(_loc6_)
		_loc5_.size = b.size
		_loc6_.position = -b.position
		var left_edge := b.position.x * 0.8
		if _loc3_ != 0:
			_loc5_.flash_x = _cont_width(_loc5_) + 15
		else:
			_loc5_.flash_x = 0
		_loc5_.position = Vector2(_loc5_.flash_x + left_edge, b.position.y * 0.8)
		_loc3_ += 1
	e_cont.position.x = -1 * (_cont_width() / 2)
	RWTween.from_to(e_cont, 0.4, {"colorMatrixFilter": {"brightness": 2}}, {"colorMatrixFilter": {"brightness": 1}})
