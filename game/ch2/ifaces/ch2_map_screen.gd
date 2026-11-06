# 二次开发：第二章「东渡」地图。没有对应的原版符号，和 popup_mission_ex.gd 一样直接用代码拼出
# 子节点，尽量复用一代已有的剪辑（旗帜 flagMap、红圈 redRotatingCircle、升级/主菜单按钮）与字体。
#
# 偏离/缺陷：
# - assets/ch2/map/landmarks.png 在江乡粮道一带（watermill-2 附近，约逻辑坐标 345,316）已经画出了
#   静态水车图案，data/ch2/map_watermills.json 又在几乎同一批位置放置可动的 AnimatedSprite2D 水车，
#   会出现"底图水车 + 动画水车"的双重水车。已按规格要求如实报告，不自行改图或改坐标。
class_name Ch2MapScreen
extends Control

const WIDTH := 700
const HEIGHT := 600
const LANDMARKS_PATH := "res://assets/ch2/map/landmarks.png"
const WATERMILL_ATLAS_PATH := "res://assets/ch2/map/watermill_atlas.png"
const WATERMILL_DATA_PATH := "res://data/ch2/map_watermills.json"
const CAMPAIGN_PATH := "res://data/ch2/campaign.json"
const FONT_PATH := "res://assets/library/font/5596_Minion Pro.ttf"
const NUM_LEVELS := 36

const WM_FRAME_SIZE := 64
const WM_COLS := 10
const WM_TOTAL_FRAMES := 80
const WM_FPS := 15.0
const WM_FOOT_ORIGIN := Vector2(32, 48)

static var _wm_frames: SpriteFrames = null
static var _campaign: Dictionary = {}

var a_markers: Array = []  # FlashClip（flagMap 实例），下标 0 基，与一代 a_markers 对应
var next_unvisited: int = 0
var pop: PopupMissionEx
var red_circle: FlashClip
var back_ship: Ch2ShipButton
var t_chapter: FlashText
var t_section: FlashText

var _attached: bool = false


static func create() -> Ch2MapScreen:
	_init_once()
	var n := Ch2MapScreen.new()
	n._construct()
	return n


## 只建一次共享数据：水车帧集合与战役地理 JSON。
static func _init_once() -> void:
	if _wm_frames != null:
		return
	var atlas: Texture2D = load(WATERMILL_ATLAS_PATH)
	_wm_frames = SpriteFrames.new()
	_wm_frames.add_animation("spin")
	_wm_frames.set_animation_speed("spin", WM_FPS)
	_wm_frames.set_animation_loop("spin", true)
	for i in WM_TOTAL_FRAMES:
		var col := i % WM_COLS
		var row := i / WM_COLS
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = Rect2(col * WM_FRAME_SIZE, row * WM_FRAME_SIZE, WM_FRAME_SIZE, WM_FRAME_SIZE)
		_wm_frames.add_frame("spin", at)
	var f := FileAccess.open(CAMPAIGN_PATH, FileAccess.READ)
	_campaign = JSON.parse_string(f.get_as_text()) if f != null else {}


func _construct() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_background()
	_build_watermills()
	_build_flags()
	_build_title()
	_build_buttons()
	pop = PopupMissionEx.new()
	red_circle = (load("res://scenes/clips/redRotatingCircle.tscn") as PackedScene).instantiate()
	IfaceUtil.when_ready(red_circle, func() -> void:
		(red_circle.get_node("eAnim") as FlashClip).stop())


func _build_background() -> void:
	var tex: Texture2D = load(LANDMARKS_PATH)
	var bg := TextureRect.new()
	bg.name = "bg"
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 底图是 2 倍原图（1400x1200），不设这个会按贴图原尺寸
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(WIDTH, HEIGHT)
	add_child(bg)


func _build_watermills() -> void:
	var f := FileAccess.open(WATERMILL_DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	for w: Dictionary in (parsed as Dictionary).get("watermills", []):
		var foot: Array = w.get("foot_px", [0, 0])
		var scale: float = float(w.get("scale", 1.0))
		var spr := AnimatedSprite2D.new()
		spr.name = str(w.get("id", "watermill"))
		spr.sprite_frames = _wm_frames
		spr.animation = "spin"
		spr.offset = -WM_FOOT_ORIGIN
		spr.scale = Vector2(scale, scale)
		spr.position = Vector2(float(foot[0]), float(foot[1]))
		spr.frame = int(w.get("phase_frame", 0)) % WM_TOTAL_FRAMES
		add_child(spr)
		spr.play("spin")


## 照抄 game_map_object.gd 的 _build_flags：按存档星数（三个难度取最大）决定旗帜状态与红圈位置，
## 只是坐标来自 campaign.json 的 stages[].map_position_px，而不是一代固定摆好的 markers 子节点。
func _build_flags() -> void:
	var stages: Array = _campaign.get("stages", [])
	a_markers = []
	var found_unvisited := false
	for i in NUM_LEVELS:
		var level_n := i + 1
		var stage: Dictionary = stages[i] if i < stages.size() else {}
		var pos: Array = stage.get("map_position_px", [0, 0])
		var flag := (load("res://scenes/clips/flagMap.tscn") as PackedScene).instantiate() as FlashClip
		flag.name = "f%d" % level_n
		flag.position = Vector2(float(pos[0]), float(pos[1]))
		add_child(flag)
		a_markers.append(flag)
		var s1 := StoredData.ch2_stars(level_n, 1)
		var s2 := StoredData.ch2_stars(level_n, 2)
		var s3 := StoredData.ch2_stars(level_n, 3)
		var stars: int = maxi(s1, maxi(s2, s3))
		var is_next := false
		if stars == 0 and not found_unvisited:
			found_unvisited = true
			next_unvisited = i
			is_next = true
		IfaceUtil.when_ready(flag, _setup_flag.bind(flag, level_n, stars, s1, s2, s3, is_next))


## 拆成单独方法：flag 的子节点要等自己 _ready() 跑完才真正建好（与 popup_mission_ex 对 popup 的处理一致）。
func _setup_flag(flag: FlashClip, level_n: int, stars: int, s1: int, s2: int, s3: int, is_next: bool) -> void:
	var e_visited: FlashClip = flag.get_node("eVisited")
	var e_unvisited: FlashClip = flag.get_node("eUnvisited")
	var t_level_name: FlashText = flag.get_node("tLevelName")
	e_visited.visible = true
	e_unvisited.visible = true
	flag.visible = true
	e_visited.scale.x = 1.0
	e_unvisited.scale.x = 1.2
	t_level_name.modulate.a = 0.0
	t_level_name.text = "Level %d" % level_n
	if stars == 0:
		if is_next:
			e_visited.visible = false
			# _setup_flag 本身是在 flag 的 _ready() 信号里触发的（flag 首次随 Ch2MapScreen 一起真正进入
			# 场景树时），这正发生在引擎递归处理这一整棵子树 ENTER_TREE/READY 通知的过程中；这时
			# flag.get_parent()（即 Ch2MapScreen 自己）还"正在设置子节点"，此时再 add_child/move_child
			# 会被引擎拒绝（"Parent node is busy setting up children"）。按引擎报错提示的办法，把这部分
			# 结构性操作放到 call_deferred 里，等这一轮 READY 通知跑完再执行。
			var place_circle := func() -> void:
				var parent: Node = flag.get_parent()
				if parent != null:
					if red_circle.get_parent() != null:
						red_circle.get_parent().remove_child(red_circle)
					parent.add_child(red_circle)
					parent.move_child(red_circle, flag.get_index())
				red_circle.scale = Vector2.ONE
				red_circle.position = Vector2(flag.position.x, flag.position.y + 12)
				RWTween.from(red_circle, 1.2, {"scaleX": 1.5})
				(red_circle.get_node("eAnim") as FlashClip).play()
			place_circle.call_deferred()
			RWTween.from(flag, 2, {"scaleX": 3.5, "scaleY": 3.5, "y": "-20", "ease": RWEase.elastic_ease_out})
		elif StoredData.dev:
			pass  # dev 版：任意关卡的旗帜都显示、都可点（ch2_level_unlocked 在 dev 下恒真）
		else:
			flag.visible = false
	else:
		e_unvisited.visible = false
		var e_star: FlashClip = e_visited.get_node("eStar")
		e_star.visible = true
		e_star.goto_and_stop(stars)
		if stars > s2 and stars > s3:
			e_visited.goto_and_stop(1)
		elif stars == s2 and stars > s3:
			e_visited.goto_and_stop(2)
		elif stars == s3:
			e_visited.goto_and_stop(3)
	if flag.visible:
		ButtonClass.add_button_full(flag.get_node("sens"), _banner_rover, _banner_rout, _banner_clicked)


func _build_title() -> void:
	var chapter_dict: Dictionary = Ch2Text.glossary().get("chapter", {})
	var chapter_en := ""
	for v: String in chapter_dict.values():
		if v.begins_with("Chapter"):
			chapter_en = v
			break
	var font: FontFile = load(FONT_PATH)
	t_chapter = FlashText.new()
	t_chapter.name = "tChapter"
	t_chapter.font = font
	t_chapter.font_size = 26
	t_chapter.color = Color(1, 1, 1, 1)
	t_chapter.shadow_color = Color(0, 0, 0, 1)
	t_chapter.shadow_offset = Vector2(2, 2)
	t_chapter.align = "center"
	t_chapter.box = Rect2(0, 10, WIDTH, 36)
	t_chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_chapter.text = chapter_en
	add_child(t_chapter)

	var section_n := 1
	var stages: Array = _campaign.get("stages", [])
	if next_unvisited < stages.size():
		section_n = int((stages[next_unvisited] as Dictionary).get("section", 1))
	t_section = FlashText.new()
	t_section.name = "tSection"
	t_section.font = font
	t_section.font_size = 16
	t_section.color = Color(1, 1, 0.85, 1)
	t_section.shadow_color = Color(0, 0, 0, 1)
	t_section.shadow_offset = Vector2(1, 1)
	t_section.align = "center"
	t_section.box = Rect2(0, 44, WIDTH, 24)
	t_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_section.text = Ch2Text.section_name(section_n)
	add_child(t_section)


## bUpgrades / bMenu 直接是一代地图 allMarkers.tscn 里同名节点的同一套剪辑（upgButtonClass__f1 /
## Symbol_5679__f1），坐标、缩放照抄那边的值（217.95,567 / 350.2,567，scale 1.47247），不再另外放大，
## 避免两个按钮的声明包围盒互相重叠抢点击。
func _build_buttons() -> void:
	back_ship = Ch2ShipButton.create(Vector2(60, 560), &"load_ch1_map", true)
	add_child(back_ship)
	var upgrades := (load("res://scenes/clips/upgButtonClass__f1.tscn") as PackedScene).instantiate() as FlashClip
	upgrades.name = "bUpgrades"
	upgrades.position = Vector2(217.95, 567)
	upgrades.scale = Vector2(1.47247, 1.47247)
	add_child(upgrades)
	IfaceUtil.when_ready(upgrades, func() -> void:
		upgrades.stop()
		ButtonClass.add_button_on_frames_rd(upgrades, _button_clicked)
		_update_free_star_badge(upgrades))
	var menu := (load("res://scenes/clips/Symbol_5679__f1.tscn") as PackedScene).instantiate() as FlashClip
	menu.name = "bMenu"
	menu.position = Vector2(350.2, 567)
	menu.scale = Vector2(1.47247, 1.47247)
	add_child(menu)
	IfaceUtil.when_ready(menu, func() -> void:
		menu.stop()
		ButtonClass.add_button_on_frames_rd(menu, _button_clicked))


## 升级按钮上的 "+N" 角标：显示二章的空闲星，同一代 game_map_object.gd 的 eGotFree 规则，0 星时隐藏。
func _update_free_star_badge(upgrades: FlashClip) -> void:
	var e_got_free: FlashClip = upgrades.get_node("eGotFree")
	var num_free := StoredData.ch2_stars_free()
	if num_free > 0:
		e_got_free.visible = true
		(e_got_free.get_node("tMore") as FlashText).text = "+%d" % num_free
	else:
		e_got_free.visible = false


func _enter_tree() -> void:
	if not _attached:
		IfaceUtil.when_ready(self, _added)


func _exit_tree() -> void:
	if _attached:
		_removed()


func _added() -> void:
	_attached = true


func _removed() -> void:
	_attached = false
	(red_circle.get_node("eAnim") as FlashClip).stop()
	if red_circle.get_parent() != null:
		red_circle.get_parent().remove_child(red_circle)
	if pop.get_parent() == self:
		remove_child(pop)
	for flag: FlashClip in a_markers:
		if flag.get_node_or_null("sens") != null:
			ButtonClass.remove_button_full(flag.get_node("sens"), _banner_rover, _banner_rout, _banner_clicked)


func _banner_rover(e: ButtonClass.ButtonEvent) -> void:
	var s := SoundLibrary.inst
	if Sounds.inst != null and s != null:
		Sounds.inst.play(s.get_sound(s.MAP_FLAG_ROVER), false, 0, 0.4)
	var sens: FlashClip = e.target
	var flag: FlashClip = sens.get_parent()
	var e_unvisited: FlashClip = flag.get_node("eUnvisited")
	var e_visited: FlashClip = flag.get_node("eVisited")
	if e_unvisited.visible:
		RWTween.to(e_unvisited, 0.1, {"scaleX": 1.5, "scaleY": 1.5})
	else:
		RWTween.to(e_visited, 0.1, {"scaleX": 1.4, "scaleY": 1.4})
	RWTween.to(flag.get_node("tLevelName"), 0.1, {"alpha": 1})
	var parent: Node = flag.get_parent()
	if parent != null:
		parent.move_child(flag, parent.get_child_count() - 1)


func _banner_rout(e: ButtonClass.ButtonEvent) -> void:
	var sens: FlashClip = e.target
	var flag: FlashClip = sens.get_parent()
	var e_unvisited: FlashClip = flag.get_node("eUnvisited")
	var e_visited: FlashClip = flag.get_node("eVisited")
	if e_unvisited.visible:
		RWTween.to(e_unvisited, 0.1, {"scaleX": 1.2, "scaleY": 1.2})
	else:
		RWTween.to(e_visited, 0.1, {"scaleX": 1, "scaleY": 1})
	RWTween.to(flag.get_node("tLevelName"), 0.1, {"alpha": 0})


## 点击旗帜：解锁的开二章模式任务弹窗，未解锁的不处理（未解锁的旗帜本来也不显示/不接按钮）。
func _banner_clicked(e: ButtonClass.ButtonEvent) -> void:
	var sens: FlashClip = e.target
	var flag: FlashClip = sens.get_parent()
	var idx := a_markers.find(flag)
	if idx < 0:
		return
	var level_n := idx + 1
	if not StoredData.ch2_level_unlocked(level_n):
		return
	var s := SoundLibrary.inst
	if Sounds.inst != null and s != null:
		Sounds.inst.play(s.get_sound(s.MAP_FLAG_CLICK), false, 0, 0.4)
	pop.init_ch2(level_n)
	add_child(pop)


func _button_clicked(e: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = e.target
	var m: Variant = IfaceUtil.main()
	if target.name == "bUpgrades":
		if m != null:
			m.load_upgrade_panel()
	elif target.name == "bMenu":
		if m != null:
			m.load_main_menu()
