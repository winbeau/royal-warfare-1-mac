# 移植自 S/gameCore/ifaces/popupMission_ex.as
# 关卡简介弹窗：半透明背景遮罩（bigShadow）+ popupMission 剪辑（标题、滚动说明文字、小地图缩略图、
# 难度 1/2/3 选择、开始/关闭按钮）。gameMapObject 只创建一个实例并反复 init(pos) 后 addChild。
#
# 偏离/缺陷：
# - popupMission_ex 本身在原版没有对应的 fla 符号（直接继承 MovieClip，自己用代码拼出 bigShadow/popup），
#   所以 scenes/ifaces/popup_mission_ex.tscn 不走"继承 scenes/clips/<符号>.tscn"的一般套路，而是手工
#   拼出同样的子节点（见该场景文件的注释）。
# - bigShadow 使用真实符号 mapBlack（character 5978，scenes/clips/mapBlack.tscn）。
# - DropShadowFilter（popup 外阴影）、.mask 遮罩（eMapSymbol.eCont 的遮罩、tMissionDesc 的文字遮罩）
#   FlashClip 没有对应机制，不移植，记入汇报（与 upgr_panel_ex.gd 对同类问题的处理一致）。
# - gameUniverse.aLevelsBackGroundsSmallImages（预渲染的关卡缩略图）没有被移植（只有
#   a_levels_back_grounds 存背景类名字符串），这里改为直接按背景名加载 assets/backgrounds/<名>.png，
#   效果等价（同一张背景图，只是没有预先栅格化成固定尺寸的小图）。
class_name PopupMissionEx
extends FlashClip

const SCENE := "res://scenes/ifaces/popup_mission_ex.tscn"
const SCROLL_STEP := 1.0 / 30.0  # 原版按 ENTER_FRAME（舞台 30fps）驱动滚动，这里用累加器近似

var pos: int = 0
var popup: FlashClip  # popupMission
var big_shadow: FlashClip  # mapBlack (character 5978)
var text_start_coords: float = 0.0
var text_start_scroll_counter: int = 0
var s: SoundLibrary
var e_hint: FlashClip  # hintAchivesStats

var b_playbtn: FlashClip
var b_closebtn: FlashClip
var d1: FlashClip
var d2: FlashClip
var d3: FlashClip
var t_mission_name: FlashText
var t_mission_desc: FlashText
var e_text_mask: Control
var e_map_symbol: FlashClip
var e_cont: FlashClip

var _attached: bool = false
var _scrolling: bool = false
var _scroll_acc: float = 0.0


func _init() -> void:
	if IfaceUtil.instantiating:
		return
	# 原版没有对应符号，构造函数直接 new mapBlack()/new popupMission() 并 addChild；这里等价地
	# 手工建出同样的子节点（docs/port-plan.md 第 2 节 adopt() 套路的对应，只是没有符号可 adopt）。
	var shadow := (load("res://scenes/clips/mapBlack.tscn") as PackedScene).instantiate() as FlashClip
	shadow.name = "bigShadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)
	var p := (load("res://scenes/clips/popupMission.tscn") as PackedScene).instantiate()
	p.name = "popup"
	add_child(p)
	popup = p
	big_shadow = shadow
	_construct()


static func create() -> PopupMissionEx:
	var n := IfaceUtil.instantiate(SCENE) as PopupMissionEx
	n.popup = n.get_node("popup")
	n.big_shadow = n.get_node("bigShadow")
	n._construct()
	return n


## 原版构造函数：建 eHint、停帧 bPlaybtn/bClosebtn、记录说明文字初始 y。
func _construct() -> void:
	b_playbtn = popup.get_node("bPlaybtn")
	b_closebtn = popup.get_node("bClosebtn")
	d1 = popup.get_node("d1")
	d2 = popup.get_node("d2")
	d3 = popup.get_node("d3")
	t_mission_name = popup.get_node("tMissionName")
	t_mission_desc = popup.get_node("tMissionDesc")
	e_text_mask = popup.get_node("eTextMask")
	e_map_symbol = popup.get_node("eMapSymbol")
	e_cont = e_map_symbol.get_node("eCont")
	# .mask = eTextMask / eMapSymbol.eCont.mask = eMapSymbol.eMask：按 FlashClip.set_mask 接上
	# （见该方法注释）。e_cont 原本在 e_map_symbol 下与 e_mask 平级，裁切后改挂到 e_mask 下面。
	var e_mask: Control = e_map_symbol.get_node("eMask")
	FlashClip.set_mask(t_mission_desc, e_text_mask)
	FlashClip.set_mask(e_cont, e_mask)
	big_shadow.modulate.a = 0.35
	IfaceUtil.goto_and_stop(b_playbtn, 1)
	IfaceUtil.goto_and_stop(b_closebtn, 1)
	text_start_coords = t_mission_desc.position.y
	e_hint = (load("res://scenes/clips/hintAchivesStats.tscn") as PackedScene).instantiate()
	popup.add_child(e_hint)
	e_hint.mouse_children = false
	e_hint.mouse_enabled = false
	(e_hint.get_node("tText") as FlashText).auto_size = "center"
	e_hint.visible = false


## 原版 init(pos)：记下关卡下标，等 ADDED_TO_STAGE 后执行 added()。原版每次展示前都会重新调用
## init()（gameMapObject 复用同一个 pop 实例），所以这里只靠 when_ready 触发 _added()，不用
## _enter_tree：首次整棵子树（popup/eMapSymbol/eCont 等）要等自己的 _ready() 跑完才真正建好内部图层，
## 提前在 _enter_tree 里跑 _added() 会在它们就绪前改动子节点，顺序反了（已验证会导致 eCont 的位图
## 被 FlashClip 自己随后创建的 _back/_front 盖住）。
func init(param1: int) -> void:
	pos = param1
	IfaceUtil.when_ready(self, _added)


func _exit_tree() -> void:
	if _attached:
		_removed()


func _added() -> void:
	if _attached:
		return
	_attached = true
	s = SoundLibrary.inst
	IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0, 0.25)
	big_shadow.modulate.a = 0.6
	popup.modulate.a = 1.0
	RWTween.from(big_shadow, 0.9, {"alpha": 0})
	text_start_scroll_counter = 90
	popup.position = Vector2(350, 300)
	RWTween.from(popup, 0.3, {"y": "-300", "alpha": 0})
	ButtonClass.add_button_scale(b_playbtn, button_clicked)
	ButtonClass.add_button_scale(b_closebtn, button_clicked)
	ButtonClass.add_button_full(d1, roverdif, routdif, button_clicked)
	ButtonClass.add_button_full(d2, roverdif, routdif, button_clicked)
	ButtonClass.add_button_full(d3, roverdif, routdif, button_clicked)
	var dif := int(StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY])
	match dif:
		1:
			select_dif(d1)
			deselect_dif(d2)
			deselect_dif(d3)
		2:
			deselect_dif(d1)
			select_dif(d2)
			deselect_dif(d3)
		3:
			deselect_dif(d1)
			deselect_dif(d2)
			select_dif(d3)
	var tmpl: LevelTemplate = GameUniverse.a_levels_templates_inited[pos]
	t_mission_name.text = tmpl.level_caption
	t_mission_desc.text = tmpl.level_description
	# .mask = eTextMask：FlashClip 无遮罩机制，不移植（见文件头注释）
	# 原版这里是 `while(eCont.numChildren) eCont.removeChildAt(0)`：AS3 的 eCont 除了上一次 init()
	# 加进去的背景位图以外没有别的子节点，清空重来是安全的。移植后 e_cont 本身是 FlashClip（Symbol_67，
	# 一个空符号），FlashClip._ready() 会给自己建 _back/_front 两个栅格图层 Sprite2D 作为"自己的子节点"
	# ——这两个图层和 AS3 没有对应物，纯粹是这边渲染管线的实现细节。如果照抄原版"清空所有子节点"，
	# 会把 e_cont 自己的 _back/_front 也一并 queue_free 掉：第一次 init() 就会发生（这两个图层在
	# _ready() 时已经存在），之后任何读 e_map_symbol 包围盒的地方（IfaceUtil.clip_bounds，这里
	# clip_width 用来算背景图缩放比例）再碰到 e_cont 就会踩到已经被释放的节点而报错，长期也会让
	# e_cont 自己的渲染层永久消失。只清掉我们自己动态加的那张背景位图（按名字认，不碰 _back/_front），
	# 效果和原版一致又不会误删 FlashClip 自身的图层。
	for c in e_cont.get_children():
		if c.name == "_back" or c.name == "_front":
			continue
		e_cont.remove_child(c)
		c.queue_free()
	t_mission_desc.position.y = text_start_coords
	t_mission_desc.modulate.a = 1.0
	t_mission_desc.auto_size = "center"
	_scrolling = t_mission_desc.box.size.y > e_text_mask.size.y
	_scroll_acc = 0.0
	set_process(_scrolling)
	var bg_name: String = GameUniverse.a_levels_back_grounds[pos]
	var bg_path := "res://assets/backgrounds/%s.png" % bg_name
	var tex: Texture2D = load(bg_path) if ResourceLoader.exists(bg_path) else null
	if tex != null:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = tex
		var target_width: float = IfaceUtil.clip_width(e_map_symbol)
		var sc: float = target_width / tex.get_width() if tex.get_width() > 0 else 1.0
		spr.scale = Vector2(sc, sc)
		e_cont.add_child(spr)


func routdif(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	e_hint.visible = false
	RWTween.to(target, 0.1, {"scaleX": 1, "scaleY": 1})


func roverdif(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	if Sounds.inst != null and s != null:
		Sounds.inst.play_rover(s.get_sound(s.ROVER), 0, 0.3, target)
	RWTween.to(target, 0.1, {"scaleX": 1.1, "scaleY": 1.1})
	e_hint.visible = true
	var txt := ""
	var t_text: FlashText = e_hint.get_node("tText")
	if target == d1:
		txt = "Difficulty: NORMAL"
		t_text.position.y = 28
	elif target == d2:
		txt = "Difficulty: HARD"
		t_text.position.y = 35
	elif target == d3:
		txt = "Difficulty: NIGHTMARE"
		t_text.position.y = 28
	t_text.text = txt
	e_hint.position.x = target.position.x
	e_hint.position.y = 70


func select_dif(d: FlashClip) -> void:
	var n := 0
	if d == d1:
		n = 1
	elif d == d2:
		n = 2
	elif d == d3:
		n = 3
	RWTween.to(d, 0.1, {"colorMatrixFilter": {"amount": 1, "contrast": 1, "brightness": 1, "saturation": 1}})
	StoredData.save_data(StoredData.COM_CHANGE_DIF, {"dif": n})


func deselect_dif(d: FlashClip) -> void:
	RWTween.to(d, 0.1, {"colorMatrixFilter": {"amount": 1, "contrast": 0.5, "brightness": 0.6, "saturation": 0}})


func _process(delta: float) -> void:
	if not _scrolling:
		set_process(false)
		return
	_scroll_acc += delta
	while _scroll_acc >= SCROLL_STEP:
		_scroll_acc -= SCROLL_STEP
		_scroll_tick()


## 原版 update()（ENTER_FRAME）。
func _scroll_tick() -> void:
	if text_start_scroll_counter > 0:
		text_start_scroll_counter -= 1
	else:
		t_mission_desc.position.y -= 0.25
		var over: float = t_mission_desc.box.size.y - e_text_mask.size.y
		if t_mission_desc.position.y < text_start_coords - over - 30.0:
			text_start_scroll_counter = 120
			RWTween.to(t_mission_desc, 0.5, {"alpha": 0, "onComplete": _appear})


func _appear() -> void:
	RWTween.to(t_mission_desc, 0.5, {"alpha": 1})
	t_mission_desc.position.y = text_start_coords


func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	IfaceUtil.play_sound(SoundLibrary.CLICK1, 0, 0.4)
	if target == d1:
		select_dif(d1)
		deselect_dif(d2)
		deselect_dif(d3)
	elif target == d2:
		select_dif(d2)
		deselect_dif(d1)
		deselect_dif(d3)
	elif target == d3:
		select_dif(d3)
		deselect_dif(d2)
		deselect_dif(d1)
	elif target == b_playbtn:
		IfaceUtil.play_sound(SoundLibrary.GAME_START, 0, 0.4)
		destroy()
		_main_call(&"load_game", [pos])
	elif target == b_closebtn:
		IfaceUtil.play_sound(SoundLibrary.IFACE_WINDOW, 0, 0.25)
		RWTween.to(popup, 0.3, {"y": "-500", "alpha": 0, "onComplete": destroy})
		RWTween.to(big_shadow, 0.3, {"alpha": 0})


func destroy() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)


func _removed() -> void:
	_attached = false
	set_process(false)
	ButtonClass.remove_button_scale(b_playbtn, button_clicked)
	ButtonClass.remove_button_scale(b_closebtn, button_clicked)
	ButtonClass.remove_button_full(d1, roverdif, routdif, button_clicked)
	ButtonClass.remove_button_full(d2, roverdif, routdif, button_clicked)
	ButtonClass.remove_button_full(d3, roverdif, routdif, button_clicked)


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)
