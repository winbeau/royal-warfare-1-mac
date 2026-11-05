extends SceneTree
# 真实输入端到端测试的第二条路径：(e) 全新存档，从开场漫画首次进入地图，悬停/点击关卡旗帜。
# 必须是独立脚本进程，不能并到 tests/input_e2e.gd 里顺带跑第二遍：GameMapObject 的 map_bitmap/anims/
# markers 是进程级单例（init_once() 只建一次），第一个 Main 实例 queue_free() 时这些节点会跟着被自由，
# 再在同一进程里 new 第二个 Main 走 GameMapObject.create() 就会踩到已释放的静态引用而崩溃——这不是
# 待修的 bug，是单例设计本身的前提（真实游戏一个进程只会有一个 Main），所以这条路径用单独进程验证。
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
		print("FAIL: ", message, "  hovered=", _describe_hover())

func _describe_hover() -> String:
	var h := root.gui_get_hovered_control()
	if h == null:
		return "null"
	return "%s (mouse_filter=%d visible=%s)" % [str(h.get_path()), h.mouse_filter, h.visible]

func _initialize() -> void:
	call_deferred("run")

func click_at(pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	root.push_input(mm)
	await process_frame
	var down := InputEventMouseButton.new()
	down.position = pos
	down.global_position = pos
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = pos
	up.global_position = pos
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up)
	await process_frame
	await process_frame

func move_to(pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	root.push_input(mm)
	await process_frame
	await process_frame

func click_center(c: Control) -> void:
	await click_at(visual_center_global(c))

func visual_center_global(c: Control) -> Vector2:
	if c is FlashClip:
		var b: Rect2 = IfaceUtil.clip_bounds(c as FlashClip)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			return c.get_global_transform() * b.get_center()
	return c.get_global_rect().get_center()

func wait_until(cond: Callable, max_frames: int, label: String) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1
	var ok: bool = cond.call()
	check(ok, "%s（等待 %d 帧未满足）" % [label, n])
	return ok


func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	root.size = Vector2i(700, 600)
	StoredData.test_wipe()

	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait_until(func() -> bool: return main.resources_loaded, 600, "(e) 资源加载完成")
	await process_frame
	await process_frame
	await process_frame
	StoredData.main_params["hints"] = false
	await wait_until(func() -> bool: return main.start_game_button != null, 120, "(e) 预载 Start 按钮出现")
	await click_center(main.start_game_button)
	await wait_until(func() -> bool: return main.main_menu != null and main.main_menu.get_parent() != null and main.main_menu.visible, 3000, "(e) 点击预载 Start 按钮后主菜单出现")
	var b_play: Control = main.main_menu.get_node_or_null("bPlay")
	if b_play != null:
		await click_center(b_play)
	# 全新存档：comix_intro 标志是 0，点 Play 后先进开场漫画，不是直接进地图（原版 main.load_map() 的
	# 判断链）。
	await wait_until(func() -> bool: return main.comix_intro != null and main.comix_intro.get_parent() != null, 300, "(e) 全新存档点 Play 后进入开场漫画")
	var intro: IntroComicsEx = main.comix_intro
	await process_frame
	await process_frame
	if intro != null and intro.b_skip != null:
		await click_center(intro.b_skip)
	await wait_until(func() -> bool: return main.g_map != null and main.g_map.get_parent() != null, 300, "(e) 跳过开场漫画后首次进入地图")
	await process_frame
	await process_frame
	var g_map: GameMapObject = main.g_map
	check(g_map.a_markers.size() > 0, "(e) 首次进入地图后旗帜列表非空")
	if g_map.a_markers.size() > 0:
		var flag: FlashClip = g_map.a_markers[0]
		var vis: FlashClip = flag.get_node("eVisited") if flag.get_node("eVisited").visible else flag.get_node("eUnvisited")
		var pos: Vector2 = visual_center_global(vis)
		var scale_before: Vector2 = vis.scale
		await move_to(pos)
		check(root.gui_get_hovered_control() == flag.get_node("sens"), "(e) 首次进入地图后悬停旗帜图案中心命中 sens（实际命中 %s）" % _describe_hover())
		await wait_until(func() -> bool: return vis.scale != scale_before, 60, "(e) 首次进入地图后悬停旗帜触发 rollover")
		await click_at(pos)
		await wait_until(func() -> bool: return g_map.pop != null and g_map.pop.get_parent() != null, 180, "(e) 首次进入地图后点击旗帜弹出弹窗")

	main.queue_free()
	await process_frame

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
