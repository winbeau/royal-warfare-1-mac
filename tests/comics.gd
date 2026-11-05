extends SceneTree
# S3：六段章节漫画（IntroComicsEx、ComixTwoEx、ComixThreeEx、ComixFourEx、ComixFiveEx、ComixFinalEx）。
# 运行：Godot --headless --path . --script tests/comics.gd -- --isolated-profile
# 覆盖：实例化（scene 与 new() 两条路径）、页数与原版 aPages 一致、翻页显隐、bSkip / 播完回调 Main.loadMap、
# 回调前已移出舞台、已看标志写入 NUMPAN_COMIX、重新入树再次初始化、监听器不重复。
var checks := 0
var failures: Array = []

const STUB_SRC := """
extends Main
var load_map_calls := 0
func load_map() -> void:
	load_map_calls += 1
"""

# [类, 原版页数, 存档键, 编号]
var specs: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame

func click(clip: FlashClip) -> void:
	var hub: Object = clip.get_meta(ButtonClass.HUB_META)
	hub.dispatch(ButtonClass.CLICK)

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	StoredData.test_wipe()
	StoredData.init()
	if SoundLibrary.inst == null:
		SoundLibrary.new().init()
	if Sounds.inst == null:
		root.get_node("SoundSystem").init_sounds_first(StoredData.main_params)
	var tw := RWTween.inst_()
	tw.manual_clock = true
	RWTween.reset()
	var stub_script := GDScript.new()
	stub_script.source_code = STUB_SRC
	stub_script.reload()
	var main_stub: Main = stub_script.new()
	check(Main.inst == main_stub, "Main stub installed")

	specs = [
		[IntroComicsEx, 5, "comix_intro", 1], [ComixTwoEx, 2, "comix_two", 2], [ComixThreeEx, 2, "comix_three", 3],
		[ComixFourEx, 2, "comix_four", 4], [ComixFiveEx, 1, "comix_five", 5], [ComixFinalEx, 2, "comix_end", 6]]
	for sp in specs:
		await test_comic(main_stub, sp[0], sp[1], sp[2], sp[3])
	await test_new_path(main_stub)

	print("comics: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)

func flag(key: String) -> int:
	return int(StoredData.local_game_data[StoredData.NUMPAN_COMIX][key])

func visible_pages(c: Variant) -> int:
	var n := 0
	for p: FlashClip in c.a_pages:
		if p.visible:
			n += 1
	return n

func test_comic(m: Variant, cls: GDScript, pages: int, key: String, number: int) -> void:
	var tag := "%s" % cls.get_global_name()
	# 把该段标志重置为“未看”（-1），观察 added() 写入 1
	var obj: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	obj[key] = -1
	var c: Variant = cls.create()
	check(c != null, tag + ": scene instantiates")
	c.init()
	check(c.a_pages.size() == pages, "%s: %d pages (got %d)" % [tag, pages, c.a_pages.size()])
	root.add_child(c)
	await settle()
	check(flag(key) == 1, tag + ": COMIX_WATCHED written (" + key + ")")
	check(c.page_counter == 0 and visible_pages(c) == 1 and c.a_pages[0].visible, tag + ": first page shown on enter")
	# 翻入动画结束后位置回到原坐标
	RWTween.inst_().i_step(1.0)
	check(c.a_pages[0].position.is_equal_approx(c.a_pages_coords[0]) and absf(c.a_pages[0].rotation_degrees) < 0.01, tag + ": page 1 settled at its coords")
	var hub_r: Object = c.b_right.get_meta(ButtonClass.HUB_META)
	check((hub_r.listeners[ButtonClass.CLICK] as Array).count(c.button_clicked) == 1, tag + ": one button_clicked listener on bRight")

	# 翻页：每点一次多显示一页，最后一页再点一次结束
	var calls0: int = m.load_map_calls
	for i in range(1, pages):
		click(c.b_right)
		check(c.page_counter == i and c.a_pages[i].visible, "%s: page %d shown" % [tag, i + 1])
		check(c.is_inside_tree() and m.load_map_calls == calls0, tag + ": still open before the last page")
	click(c.b_right)
	check(not c.is_inside_tree() and m.load_map_calls == calls0 + 1, tag + ": clicking past the last page removes it and calls loadMap")
	check(not (c.b_right.get_meta(ButtonClass.HUB_META).listeners[ButtonClass.CLICK] as Array).has(c.button_clicked), tag + ": listeners removed on removal")

	# 重新入树：added() 再执行，页面复位
	root.add_child(c)
	await settle(1)
	check(c.page_counter == 0 and visible_pages(c) == 1, tag + ": re-added resets to page 1")
	check((c.b_right.get_meta(ButtonClass.HUB_META).listeners[ButtonClass.CLICK] as Array).count(c.button_clicked) == 1, tag + ": re-added: no duplicate listeners")

	# 跳过
	obj = StoredData.local_game_data[StoredData.NUMPAN_COMIX]
	calls0 = m.load_map_calls
	if pages > 1:
		click(c.b_right)
	click(c.b_skip)
	check(not c.is_inside_tree() and m.load_map_calls == calls0 + 1, tag + ": bSkip removes it and calls loadMap")
	c.free()
	await settle(1)

func test_new_path(m: Variant) -> void:
	# 核心若写 `new comixTwo_ex()`，走 IfaceUtil.adopt
	var c := ComixTwoEx.new()
	c.init()
	root.add_child(c)
	await settle()
	check(c.a_pages.size() == 2 and c.a_pages[0].visible, "ComixTwoEx.new(): works")
	var calls0: int = m.load_map_calls
	click(c.b_skip)
	check(m.load_map_calls == calls0 + 1, "ComixTwoEx.new(): skip calls loadMap")
	c.free()
