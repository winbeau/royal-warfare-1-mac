extends SceneTree
## Run: Godot --headless --path . --script tests/clips_runtime.gd -- --isolated-profile
var failures: Array = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func shown(clip: FlashClip, frame: int) -> Texture2D:
	var d := clip.data
	if d.reuse_frames != null:
		return d.reuse_frames.get_frame_texture(&"default", frame - 1)
	var k := d.back_index[frame - 1]
	return d.back_textures[k] if k >= 0 else null

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	# 1. original instance paths from mainGameUI_ex.as
	var ui: FlashClip = load("res://scenes/clips/mainGameUI.tscn").instantiate()
	root.add_child(ui)
	check(ui.character_id == 5384, "mainGameUI is symbol 5384")
	for path in ["eUnitPanel/sSensPanel/sArmor", "eUnitPanel/sSensPanel/sResist", "eUnitPanel/eOne/eAbility", "eUnitPanel/eOne/eCoolDown",
			"eUnitPanel/eUnitSelect/eBg", "eUnitPanel/tLevelClass", "bArchers/eCoolDown", "ePause/eIcon", "eSpeedUp/eSpeedIco", "eHint/eBack", "eMoney", "eFader"]:
		check(ui.get_node_or_null(NodePath(path)) != null, "instance path " + path)
	var armor := ui.get_node_or_null("eUnitPanel/sSensPanel/sArmor")
	check(armor is FlashClip, "sArmor is a FlashClip")
	check(ui.get_node_or_null("eUnitPanel/tLevelClass") is FlashText, "tLevelClass is a FlashText")

	# 2. multi-frame icons: goto_and_stop
	var icons: Array = []
	for path in ["ePause/eIcon", "eSpeedUp/eSpeedIco", "bArchers/eCoolDown"]:
		icons.append(ui.get_node(path))
	for clip: FlashClip in icons:
		check(clip.total_frames >= 2, "%s has %d frames" % [clip.name, clip.total_frames])
		var last := clip.total_frames
		for f in [last, 2, 1]:
			clip.goto_and_stop(f)
			check(clip.current_frame == f, "%s current_frame %d" % [clip.name, f])
			check(not clip.playing, "%s stopped after goto_and_stop" % clip.name)
			var want := shown(clip, f)
			var got := clip.back_texture()
			if want == null:
				check(got == null, "%s frame %d shows nothing" % [clip.name, f])
			else:
				check(got == want, "%s frame %d shows its own texture" % [clip.name, f])
	# eCoolDown (100 frames) reuses the shared 1x atlas
	var cd: FlashClip = ui.get_node("bArchers/eCoolDown")
	check(cd.data.reuse_frames != null and cd.total_frames == 100, "eCoolDown reuses frames.tres (100 frames)")
	cd.goto_and_stop(cd.total_frames)
	check(cd.current_frame == 100, "eCoolDown last frame")
	cd.goto_and_stop(150)
	check(cd.current_frame == 100, "goto_and_stop clamps to total_frames")
	# a state change on a child (timeline tween) is visible through the node
	check(ui.get_node("eUnitPanel").position.y > 500, "eUnitPanel starts below the screen")

	# 3. a clip with a "done" frame script emits the signal when played
	var fx: FlashClip = load("res://scenes/clips/upgradeCompleted_mc.tscn").instantiate()
	root.add_child(fx)
	check(fx.total_frames == 26 and fx.data.scripts.has(26), "upgradeCompleted_mc: 26 frames with a frame-26 script")
	var fired := [0]
	fx.done.connect(func(): fired[0] += 1)
	fx.goto_and_play(1)
	check(fx.playing, "goto_and_play starts playing")
	for i in range(25):
		fx._process(1.0 / 30.0)
	check(fx.current_frame == 26, "after 25 stage frames the clip is at frame 26 (got %d)" % fx.current_frame)
	check(fired[0] == 1, "done emitted once at frame 26 (got %d)" % fired[0])
	# a clip with stop() on frame 1 never advances
	var si: FlashClip = load("res://scenes/clips/unitIcons.tscn").instantiate() if ResourceLoader.exists("res://scenes/clips/unitIcons.tscn") else null
	if si:
		root.add_child(si)
		check(not si.playing and si.current_frame == 1, "unitIcons stops on frame 1")
		si._process(1.0)
		check(si.current_frame == 1, "stopped clip does not advance")
	# loop clip: gotoAndPlay(1) at frame 6 (smallFireball) and done at 13
	var sf: FlashClip = load("res://scenes/clips/smallFireball.tscn").instantiate()
	root.add_child(sf)
	check(sf.data.scripts.get(6, []) == [["goto_play", 1]], "smallFireball frame 6 script is gotoAndPlay(1)")
	sf.goto_and_stop(6)
	check(sf.current_frame == 1 and sf.playing, "frame script gotoAndPlay(1) jumps back and plays")

	# 4. mouse flags
	ui.mouse_children = false
	check(ui.get_node("eUnitPanel").mouse_filter == Control.MOUSE_FILTER_IGNORE, "mouse_children=false -> children ignore")
	ui.mouse_children = true
	check(ui.get_node("eUnitPanel").mouse_filter == Control.MOUSE_FILTER_PASS, "mouse_children=true restores PASS")
	ui.mouse_enabled = false
	check(ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "mouse_enabled=false -> IGNORE")
	check(load("res://scenes/clips/eIconsAchives.tscn").instantiate().mouse_filter == Control.MOUSE_FILTER_PASS, "containers default to PASS")

	# 5. FlashText
	var t: FlashText = ui.get_node("eUnitPanel/tLevelClass")
	t.html_text = '<p align="center"><font size="14" color="#ff0000" face="Minion Pro">Lvl <b>5</b>&amp;[x]<br>line2</font></p>'
	check(t.text.begins_with("Lvl 5&[x]"), "html_text strips tags: '%s'" % t.text)
	await process_frame
	t.text = "plain [text]"
	check(t.html_text == "plain [text]", "text round trip")
	var bb := FlashText.html_to_bbcode('<font size="20" color="#00ff00">a<br>b</font><i>c</i>')
	check(bb == "[color=#00ff00][font_size=20]a\nb[/font_size][/color][i]c[/i]" or bb.contains("[font_size=20]"), "bbcode: " + bb)
	t.auto_size = "center"
	t.text = "x"
	# 6. 嵌入字体子集：tMissionDesc 的 fontId 6028 只嵌入初始文字用到的 27 个字形（无 w、f），
	#    运行时文字缺的字形必须取自同名完整字体（268），而不是系统回退字体
	var popup := (load("res://scenes/clips/popupMission.tscn") as PackedScene).instantiate()
	root.add_child(popup)
	await process_frame
	var desc: FlashText = popup.get_node("tMissionDesc")
	check(not desc.font.has_char(119) and desc.font.has_char(87), "6028 子集有 W 无 w")
	var mf := desc.get_font()
	check(mf.has_char(119) and mf.has_char(102), "get_font() 对缺的字形回退到同名完整字体")
	check(mf.get_string_size("w", 0, -1, 23).x < mf.get_string_size("W", 0, -1, 23).x - 3.0, "小写 w 比大写 W 窄（不是 W 的形状）")
	check(mf.get_string_size("We", 0, -1, 23).x == desc.font.get_string_size("We", 0, -1, 23).x, "子集已有的字形仍取自 fontId 指定的字体")
	popup.queue_free()

	# 7. WRAP_MASK_IDS：eCoolDown/eAbility/eNotAllowedBottom|Top 以前被父剪辑的 clip-shape 遮罩静态烘焙
	# 进 back/front 光栅（永远显示固定一帧，典型症状是招募按钮上一块烘死的灰色冷却覆板），现在保持
	# 活节点，遮罩用 clip_contents + content_shift 在运行时实现（见 flash_clip.gd / ClipExporter.java）。
	var e1: FlashClip = ui.get_node("e1")
	var e1cd: FlashClip = e1.get_node("eCoolDown")
	check(e1cd.clip_contents and e1cd.size != Vector2.ZERO, "e1/eCoolDown 的遮罩换成了运行时 clip_contents")
	var e1_back := e1.back_texture()
	var e1_front := e1.front_texture()
	e1cd.visible = true
	e1cd.goto_and_stop(50)
	check(e1.back_texture() == e1_back and e1.front_texture() == e1_front,
			"冷却进行到一半不会改动 e1 自己的 back/front 光栅（以前这里会烘出一块固定的灰板）")
	e1cd.goto_and_stop(e1cd.total_frames)
	check(e1.back_texture() == e1_back and e1.front_texture() == e1_front,
			"冷却结束（total_frames 帧）同样不改动 e1 自己的 back/front 光栅")

	var ba_cd: FlashClip = ui.get_node("bArchers/eCoolDown")
	check(ba_cd.clip_contents and ba_cd.size != Vector2.ZERO, "bArchers/eCoolDown 的遮罩同样换成了运行时 clip_contents")

	var holder_one: FlashClip = ui.get_node("eUnitPanel/eOne")
	var ab: FlashClip = holder_one.get_node("eAbility")
	check(ab.clip_contents and ab.size != Vector2.ZERO, "eUnitPanel/eOne/eAbility 的遮罩换成了运行时 clip_contents")
	# setAbilityPic 以前因为 eAbility 被遮罩强制隐藏/烘成固定帧而失效：确认它现在是真正能换帧的活节点。
	ab.visible = true
	ab.goto_and_stop(5)
	check(ab.current_frame == 5, "eAbility 现在是活节点，goto_and_stop 真的生效")

	var nab := (load("res://scenes/clips/Symbol_4841.tscn") as PackedScene).instantiate()
	root.add_child(nab)
	var not_allowed: FlashClip = nab.get_node("eNotAllowedBottom")
	check(not_allowed.clip_contents and not_allowed.size != Vector2.ZERO, "Symbol_4841/eNotAllowedBottom 的遮罩换成了运行时 clip_contents")
	check(not_allowed.visible, "eNotAllowedBottom 保留 Flash 原始可见状态，不再被遮罩逻辑强制隐藏")
	nab.queue_free()

	ui.queue_free()
	await process_frame
	print("clips_runtime: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() else 0)
