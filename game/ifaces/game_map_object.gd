# 移植自 S/gameCore/ifaces/gameMapObject.as
# 世界地图：静态共享的地图位图（mapBitmap）+ 动画元素（anims）+ 24 个 flagMap 旗帜与路线
# （markers，character 5700）。旗帜按存档星级显示已访问/未访问/星数，未访问的第一关用 redRotatingCircle
# 红圈标出；bNext/bUpgrades/bMore/bMenu/bAchives/bReset 等按钮，F+Shift+Alt+Ctrl 赞助商解锁秘籍。
#
# 偏离/缺陷：
# - gameMapObject 本身在原版没有对应的 fla 符号（直接继承 MovieClip，构造函数/init() 里用代码把
#   mapBitmap、anims、markers 加到显示列表），所以 scenes/ifaces/game_map_object.tscn 同 popup_mission_ex
#   一样不走"继承符号场景"的套路。
# - gameMapAnimatedElems（character 5565）已由 pipeline 导出：8 个未命名子剪辑（character 5564）在导出时按显示列表
#   顺序命名为 e0..e7。符号 5564 自身只有 1 帧，里面嵌套的 5563（160 帧）自行循环，导出时 5564 展开为 160 帧
#   循环。因此原版 randRange(1, totalFrames) 的 totalFrames 恒为 1（结果恒为 1），这里仍按原版调用 8 次
#   RWRandom.rand_range(1, 1)，保持 RNG 序列一致，然后从第 1 帧开始播放（嵌套动画在原版里也都是同步的）。
# - popupReset_ex / popupSaveLoad_ex / popupStorageFailure_ex 由 S1 负责，移植完成前通过
#   IfaceUtil.global_script() 动态获取；没有就绪时相关按钮静默跳过（不报错，记入汇报）。
# - Main.isArmor（静态布尔，是否 Armor Games 站点）、Main.inst.check_armor_quests() 当前 Main 没有提供，
#   这里通过动态属性/方法探测，缺失时按 Main.isArmor == false 处理（不显示 bOnline，不检测任务）。
class_name GameMapObject
extends FlashClip

const SCENE := "res://scenes/ifaces/game_map_object.tscn"

static var map_bitmap: FlashClip
static var anims: FlashClip  # gameMapAnimatedElems
static var markers: FlashClip  # allMarkers
static var _inited_once: bool = false

var a_markers: Array = []
var next_unvisited: int = 0
var a_routes: Array = []
var pop: PopupMissionEx
var reset_pop: Variant  # PopupResetEx（S1）
var red_circle: FlashClip  # redRotatingCircle
var a_acts: Array = []
var a_flags_before_act_scrolls: Array = []
var s: SoundLibrary
var armor_save_pop: Variant  # PopupSaveLoadEx（S1）
var storage_popup: Variant  # PopupStorageFailureEx（S1）

var _attached: bool = false


func _init() -> void:
	if IfaceUtil.instantiating:
		return
	init_once()
	_construct()


static func create() -> GameMapObject:
	init_once()
	var n := IfaceUtil.instantiate(SCENE) as GameMapObject
	n._construct()
	return n


## 原版静态 initOnce()：只建一次共享的地图位图/动画层/旗帜标记层。
static func init_once() -> void:
	if _inited_once:
		return
	_inited_once = true
	map_bitmap = (load("res://scenes/clips/gameMap.tscn") as PackedScene).instantiate()
	anims = (load("res://scenes/clips/gameMapAnimatedElems.tscn") as PackedScene).instantiate()
	markers = (load("res://scenes/clips/allMarkers.tscn") as PackedScene).instantiate()
	IfaceUtil.when_ready(markers, func() -> void:
		(markers.get_node("bNext") as FlashClip).stop()
		(markers.get_node("bAchives") as FlashClip).stop()
		(markers.get_node("bUpgrades") as FlashClip).stop()
		(markers.get_node("bMore") as FlashClip).stop()
		(markers.get_node("bMenu") as FlashClip).stop())


## 原版构造函数：建三个弹窗、给 anims 的每个子剪辑随机起始帧，建红圈，
## 从 markers 收集 aActs/aFlagsBeforeActScrolls/aMarkers/aRoutes。
func _construct() -> void:
	pop = PopupMissionEx.new()
	reset_pop = _make_popup("PopupResetEx")
	armor_save_pop = _make_popup("PopupSaveLoadEx")
	storage_popup = _make_popup("PopupStorageFailureEx")
	for i in anims.get_child_count():
		var elem := anims.get_child(i) as FlashClip
		# 原版 gotoAndPlay(Utility.randRange(1, totalFrames))；符号 5564 的原始 totalFrames 为 1，见文件头注释
		RWRandom.rand_range(1, 1)
		elem.goto_and_play(1)
	red_circle = (load("res://scenes/clips/redRotatingCircle.tscn") as PackedScene).instantiate()
	IfaceUtil.when_ready(red_circle, func() -> void:
		(red_circle.get_node("eAnim") as FlashClip).stop())
	IfaceUtil.when_ready(markers, _collect_markers)


func _collect_markers() -> void:
	a_acts = []
	for n in ["a1", "a2", "a3", "a4", "a5", "a6"]:
		a_acts.append(markers.get_node(n))
	a_flags_before_act_scrolls = []
	for n in ["f1", "f7", "f13", "f19", "f22"]:
		a_flags_before_act_scrolls.append(markers.get_node(n))
	a_markers = []
	a_routes = []
	for i in range(1, 25):
		a_markers.append(markers.get_node("f%d" % i))
		a_routes.append(markers.get_node("r%d" % i))


func _make_popup(cls: String) -> Variant:
	var scr := IfaceUtil.global_script(cls)
	if scr == null:
		return null
	return scr.new()


func _enter_tree() -> void:
	if not _attached:
		IfaceUtil.when_ready(self, _added)


func _exit_tree() -> void:
	if _attached:
		_removed()


func _added() -> void:
	if _attached:
		return
	_attached = true
	s = SoundLibrary.inst
	add_child(map_bitmap)
	add_child(anims)
	add_child(markers)
	# 偏离/缺陷：原版 markers（MovieClip）构造完成即可同步改子节点属性；这里 markers 是 FlashClip，
	# 要等它随 add_child 真正进入场景树、_ready() 按符号帧 1 的默认状态重设过一遍子节点可见性之后，
	# 再改 bOnline/eStorageFailure 才不会被覆盖（IfaceUtil.when_ready 等就绪后再读写，同文件开头
	# init_once() 对 bNext 等按钮 stop() 的处理一致）。原版这两段逻辑在 addChild(markers) 之前，这里
	# 调整到 add_child(markers) 之后 + when_ready，只是时序上的适配，不改变最终显示结果。
	IfaceUtil.when_ready(markers, func() -> void:
		var main: Variant = IfaceUtil.main()
		var is_armor: bool = bool(main.get("is_armor")) if main != null and main.get("is_armor") != null else false
		var b_online: FlashClip = markers.get_node("bOnline")
		if is_armor:
			b_online.visible = true
			ButtonClass.add_button_scale(b_online, button_clicked)
			if RWRandom.rand() > 0.8 and main != null and main.has_method("check_armor_quests"):
				main.check_armor_quests()
		else:
			b_online.visible = false
		var e_storage_failure: FlashClip = markers.get_node("eStorageFailure")
		if not StoredData.is_save_ok:
			StoredData.save_data(StoredData.COM_SAVE_DATA_TO_SHARED, null)
			if not StoredData.is_save_ok:
				e_storage_failure.visible = true
				ButtonClass.add_button_scale(e_storage_failure, button_clicked)
			else:
				e_storage_failure.visible = false
		else:
			e_storage_failure.visible = false)
	var e_logo: FlashClip = markers.get_node("eLogo")
	RWTween.from(e_logo, 0.5, {"y": "-100", "delay": 0.1, "ease": RWEase.cubic_ease_out})
	ButtonClass.add_button_scale(markers.get_node("bReset"), button_clicked)
	ButtonClass.add_button_on_frames_rd(markers.get_node("bNext"), button_clicked)
	ButtonClass.add_button_on_frames_rd(markers.get_node("bUpgrades"), button_clicked)
	ButtonClass.add_button_on_frames_rd(markers.get_node("bMore"), button_clicked)
	ButtonClass.add_button_on_frames_rd(markers.get_node("bMenu"), button_clicked)
	ButtonClass.add_button_on_frames_rd(markers.get_node("bAchives"), button_clicked)
	_build_flags()
	_build_acts()
	var num_gained: int = StoredData.get_num_gained_stars()
	(markers.get_node("eStarPlask").get_node("tFreeStars") as FlashText).text = "%d/120" % num_gained
	var num_free: int = StoredData.get_num_free_stars()
	var e_got_free: FlashClip = markers.get_node("bUpgrades").get_node("eGotFree")
	if num_free > 0:
		e_got_free.visible = true
		(e_got_free.get_node("tMore") as FlashText).text = "+%d" % num_free
	else:
		e_got_free.visible = false
	# F+Shift+Alt+Ctrl 赞助商解锁秘籍：原版监听 stage 的 KEY_UP；这里改在根节点上处理 _unhandled_key_input。
	set_process_unhandled_key_input(true)


## 原版 init() 里按存档 NUMPAN_LEVELS / NUMPAN_LEVELS_MIDDIF / NUMPAN_LEVELS_HIGHDIF 逐关设置旗帜状态。
func _build_flags() -> void:
	var levels: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS].duplicate()
	var mid: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS_MIDDIF].duplicate()
	var high: Array = StoredData.local_game_data[StoredData.NUMPAN_LEVELS_HIGHDIF].duplicate()
	var last_stars: int = int(levels[levels.size() - 1]) if levels.size() > 0 else 0
	var found_unvisited := false
	var i := 0
	while levels.size() > 0:
		var stars := int(levels[0])
		var mid_stars := int(mid.pop_front()) if mid.size() > 0 else 0
		var high_stars := int(high.pop_front()) if high.size() > 0 else 0
		var flag: FlashClip = a_markers[i]
		var e_visited: FlashClip = flag.get_node("eVisited")
		var e_unvisited: FlashClip = flag.get_node("eUnvisited")
		var t_level_name: FlashText = flag.get_node("tLevelName")
		e_visited.visible = true
		e_unvisited.visible = true
		flag.visible = true
		e_visited.scale.x = 1.0
		e_unvisited.scale.x = 1.2
		t_level_name.modulate.a = 0.0
		t_level_name.text = "Level %d" % (i + 1)
		var route: FlashClip = a_routes[i]
		route.visible = false
		if stars == 0:
			if not found_unvisited:
				found_unvisited = true
				e_visited.visible = false
				next_unvisited = i
				var parent: Node = flag.get_parent()
				if parent != null:
					if red_circle.get_parent() != null:
						red_circle.get_parent().remove_child(red_circle)
					var flag_index: int = flag.get_index()
					parent.add_child(red_circle)
					parent.move_child(red_circle, flag_index)
				red_circle.scale = Vector2.ONE
				red_circle.position = Vector2(flag.position.x, flag.position.y + 12)
				RWTween.from(red_circle, 1.2, {"scaleX": 1.5, "scaleY": 1.5})
				(red_circle.get_node("eAnim") as FlashClip).play()
				RWTween.from(flag, 2, {"scaleX": 3.5, "scaleY": 3.5, "y": "-20", "ease": RWEase.elastic_ease_out})
			else:
				flag.visible = false
		else:
			route.visible = true
			e_unvisited.visible = false
			var e_star: FlashClip = e_visited.get_node("eStar")
			e_star.visible = true
			e_star.goto_and_stop(stars)
			if stars > mid_stars and stars > high_stars:
				e_visited.goto_and_stop(1)
			elif stars == mid_stars and stars > high_stars:
				e_visited.goto_and_stop(2)
			elif stars == high_stars:
				e_visited.goto_and_stop(3)
		if flag.visible:
			ButtonClass.add_button_full(flag.get_node("sens"), banner_rover, banner_rout, banner_clicked)
		i += 1
		levels.pop_front()
	# 最后一关（Final）的 act 滚动按钮：last_stars 取自循环开始前最后一关的星数（原版如此）。
	for j in a_flags_before_act_scrolls.size():
		var f: FlashClip = a_flags_before_act_scrolls[j]
		a_acts[j].visible = f.visible
	a_acts[a_acts.size() - 1].visible = last_stars > 0


func _build_acts() -> void:
	for act: FlashClip in a_acts:
		if act.visible:
			ButtonClass.add_button_full(act, rover_scroll, rout_scroll, scroll_clicked)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_released() and event.physical_keycode == KEY_F \
			and event.shift_pressed and event.alt_pressed and event.ctrl_pressed:
		StoredData.sponsor_unlock()
		_main_call(&"load_map")


func rout_scroll(param1: ButtonClass.ButtonEvent) -> void:
	RWTween.to(param1.target, 0.1, {"scaleX": 1, "scaleY": 1})


func rover_scroll(param1: ButtonClass.ButtonEvent) -> void:
	RWTween.to(param1.target, 0.1, {"scaleX": 1.2, "scaleY": 1.2})
	if Sounds.inst != null and s != null:
		Sounds.inst.play(s.get_sound(s.MAP_FLAG_ROVER), false, 0, 0.4)


func scroll_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	if target == a_acts[0]:
		_main_call(&"load_intro")
	elif target == a_acts[1]:
		_main_call(&"load_act_two")
	elif target == a_acts[2]:
		_main_call(&"load_act_three")
	elif target == a_acts[3]:
		_main_call(&"load_act_four")
	elif target == a_acts[4]:
		_main_call(&"load_act_five")
	elif target == a_acts[5]:
		_main_call(&"load_final")


func button_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	if target == markers.get_node("bOnline"):
		if armor_save_pop != null:
			armor_save_pop.init()
			add_child(armor_save_pop)
	elif target == markers.get_node("eStorageFailure"):
		if storage_popup != null:
			storage_popup.init()
			add_child(storage_popup)
	elif target == markers.get_node("bReset"):
		if reset_pop != null:
			reset_pop.init()
			add_child(reset_pop)
	elif target == markers.get_node("bAchives"):
		_main_call(&"load_achievements", [true])
	elif target == markers.get_node("bMenu"):
		_main_call(&"load_main_menu")
	elif target == markers.get_node("bMore"):
		_main_call(&"load_more_games")
	elif target == markers.get_node("bNext"):
		pop.init(next_unvisited)
		add_child(pop)
	elif target == markers.get_node("bUpgrades"):
		_main_call(&"load_upgrade_panel")


func banner_clicked(param1: ButtonClass.ButtonEvent) -> void:
	var target: FlashClip = param1.target
	var idx := a_markers.find(target.get_parent())
	if Sounds.inst != null and s != null:
		Sounds.inst.play(s.get_sound(s.MAP_FLAG_CLICK), false, 0, 0.4)
	pop.init(idx)
	add_child(pop)


func banner_rout(param1: ButtonClass.ButtonEvent) -> void:
	var sens: FlashClip = param1.target
	var flag: FlashClip = sens.get_parent()
	var e_unvisited: FlashClip = flag.get_node("eUnvisited")
	var e_visited: FlashClip = flag.get_node("eVisited")
	if e_unvisited.visible:
		RWTween.to(e_unvisited, 0.1, {"scaleX": 1.2, "scaleY": 1.2})
	else:
		RWTween.to(e_visited, 0.1, {"scaleX": 1, "scaleY": 1})
	RWTween.to(flag.get_node("tLevelName"), 0.1, {"alpha": 0})


func banner_rover(param1: ButtonClass.ButtonEvent) -> void:
	if Sounds.inst != null and s != null:
		Sounds.inst.play(s.get_sound(s.MAP_FLAG_ROVER), false, 0, 0.4)
	var sens: FlashClip = param1.target
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


func _removed() -> void:
	_attached = false
	var e_storage_failure: FlashClip = markers.get_node("eStorageFailure")
	var b_online: FlashClip = markers.get_node("bOnline")
	ButtonClass.remove_button_scale(e_storage_failure, button_clicked)
	ButtonClass.remove_button_scale(b_online, button_clicked)
	set_process_unhandled_key_input(false)
	for act: FlashClip in a_acts:
		ButtonClass.remove_button_full(act, rover_scroll, rout_scroll, scroll_clicked)
	(red_circle.get_node("eAnim") as FlashClip).stop()
	if red_circle.get_parent() != null:
		red_circle.get_parent().remove_child(red_circle)
	if map_bitmap.get_parent() == self:
		remove_child(map_bitmap)
	if anims.get_parent() == self:
		remove_child(anims)
	if markers.get_parent() == self:
		remove_child(markers)
	for flag: FlashClip in a_markers:
		ButtonClass.remove_button_full(flag.get_node("sens"), banner_rover, banner_rout, banner_clicked)
	ButtonClass.remove_button_scale(markers.get_node("bReset"), button_clicked)
	ButtonClass.remove_button_on_frames(markers.get_node("bNext"), button_clicked)
	ButtonClass.remove_button_on_frames(markers.get_node("bUpgrades"), button_clicked)
	ButtonClass.remove_button_on_frames(markers.get_node("bMore"), button_clicked)
	ButtonClass.remove_button_on_frames(markers.get_node("bMenu"), button_clicked)


func _main_call(method: StringName, args: Array = []) -> void:
	var m: Variant = IfaceUtil.main()
	if m != null and m.has_method(method):
		m.callv(method, args)
