extends SceneTree
# 运行时基础层（game/rw/）单元测试：RWRandom、AS3、RWXml、BmpFrames、RWTween、ArrayZSorter
var checks := 0
var failures: Array = []
var tw: Node
var calls: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func near(a: float, b: float, eps: float = 1e-4) -> bool:
	return absf(a - b) <= eps

func _initialize() -> void: call_deferred("run")

func note(tag: String) -> void: calls.append(tag)

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile: quit(2); return
	tw = RWTween.inst_()
	tw.manual_clock = true
	test_random()
	test_as3()
	test_xml()
	test_bmp_frames()
	test_z_sorter()
	test_ease()
	test_tween_basic()
	test_tween_pause_kill()
	test_tween_overwrite()
	test_tween_bezier()
	test_tween_color()
	test_tween_realtime_and_pause()
	RWTween.reset()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

# 参考值由 scratchpad/rw_random_ref.py（AS3 uint xorshift32 的独立 Python 实现）生成
func test_random() -> void:
	var states_12345 := [2072466910, 1555319093, 540721443, 1237846391, 3609038281, 1549400944, 1967031806, 3920888145, 1703843531, 474416434, 2033827028, 52838318, 1804959211, 244774710, 2694755536, 3776661226, 2261962055, 2495470111, 382760092, 3395148543]
	var values_12345 := [0.48253380471899493, 0.3621259455946567, 0.12589652164045176, 0.28820857202825334, 0.8402947061323316, 0.3607480191534264, 0.4579852815852466, 0.9129029107077287, 0.39670698610057753, 0.11045868371391172, 0.4735372561201307, 0.012302379592392216, 0.4202498149639577, 0.05699105329275854, 0.6274216660827915, 0.8793224643169256, 0.5266540813089009, 0.5810219122984032, 0.08911827860612383, 0.790494620751239]
	RWRandom.set_seed(12345)
	for i in 20:
		var v := RWRandom.rand()
		check(RWRandom.get_state() == states_12345[i], "RWRandom seed 12345 state %d" % i)
		check(near(v, values_12345[i], 1e-15), "RWRandom seed 12345 value %d" % i)
	var states_1 := [40108049, 75792675, 1803092343, 2676503753, 1638799184]
	RWRandom.set_seed(1)
	for i in states_1.size():
		RWRandom.rand()
		check(RWRandom.get_state() == states_1[i], "RWRandom seed 1 state %d" % i)
	var states_dead := [828676626, 2839583824, 1436578426, 2189148005, 1393311769]
	RWRandom.set_seed(0xDEADBEEF)
	for i in states_dead.size():
		RWRandom.rand()
		check(RWRandom.get_state() == states_dead[i], "RWRandom seed 0xDEADBEEF state %d" % i)
	var range_a := [10, 8, 3, 6, 17, 8, 10, 19, 8, 3, 10, 1, 9, 2, 13, 18, 11, 12, 2, 16]
	RWRandom.set_seed(12345)
	for i in 20:
		check(RWRandom.rand_range(1, 20) == range_a[i], "rand_range(1,20) #%d" % i)
	var range_b := [86, -174, -149, 11, -87, -91, 8, 80, -41, -156, 49, 108, 171, 121, 28, 83, 140, 54, 119, 90]
	RWRandom.set_seed(777)
	for i in 20:
		check(RWRandom.rand_range(-180, 180) == range_b[i], "rand_range(-180,180) #%d" % i)
	RWRandom.set_seed(99)
	var in_bounds := true
	for i in 2000:
		var r := RWRandom.rand_range(3, 7)
		if r < 3 or r > 7: in_bounds = false
	check(in_bounds, "rand_range(3,7) stays within bounds")
	RWRandom.set_seed(5)
	RWRandom.random_sort(0, 1)
	var after_sort := RWRandom.get_state()
	RWRandom.set_seed(5)
	RWRandom.rand()
	check(after_sort == RWRandom.get_state(), "random_sort consumes exactly one rand")
	RWRandom.set_seed(0)
	check(RWRandom.rand() == 0.0 and RWRandom.get_state() == 0, "seed 0 is a fixed point (as in the original)")

func test_as3() -> void:
	check(AS3.round(-2.5) == -2, "AS3.round(-2.5) == -2")
	check(AS3.round(2.5) == 3, "AS3.round(2.5) == 3")
	check(AS3.round(-0.5) == 0, "AS3.round(-0.5) == 0")
	check(AS3.round(-2.6) == -3, "AS3.round(-2.6) == -3")
	check(AS3.uint(-1) == 4294967295, "AS3.uint(-1)")
	check(AS3.uint(3.9) == 3, "AS3.uint(3.9)")
	var a := Vector2(10, 20)
	var b := Vector2(30, 60)
	check(AS3.point_interpolate(a, b, 1.0) == a and AS3.point_interpolate(a, b, 0.0) == b, "Point.interpolate endpoints")
	check(AS3.point_interpolate(a, b, 0.5) == Vector2(20, 40), "Point.interpolate midpoint")
	check(AS3.point_interpolate(a, b, 0.25) == Vector2(25, 50), "Point.interpolate f=0.25 weights p2")
	var v := AS3.get_vector(-5.0, PI / 2.0)
	check(near(v.x, 0.0) and near(v.y, 5.0), "get_vector uses |len|")

func test_xml() -> void:
	var units := RWXml.load_file("res://data/xml/6611_extDataManager_units.xml")
	check(units != null and units.name() == "data", "units.xml root parsed")
	check(units.child("archer").text("className") == "Archer" and is_nan(units.child("archer").to_number("className")), "className text")
	check(units.child("archer").child("Health").to_int("one") == 35, "archer Health.one == 35")
	check(units.child("archer").child("Experience").child("two").to_number() == 20.0, "archer Experience.two == 20")
	check(near(units.child("archer").child("armorPierceRanged").to_number("two"), 0.1), "archer armorPierceRanged.two == 0.1")
	var missing := units.child("archer").child("nope").child("one")
	check(missing.length() == 0 and missing.text() == "" and missing.to_number() == 0.0 and missing.to_int() == 0, "missing child behaves like empty XMLList")
	check(units.length() == 1 and units.children().size() > 5, "children() lists elements")
	check(RWXml.as_number("abc") != RWXml.as_number("abc") and RWXml.as_number("") == 0.0 and RWXml.as_number(" 12 ") == 12.0, "Number() conversion")
	var small := RWXml.parse('<r a="1"><!-- c --><k x="y">  5 </k><k>6</k><e/></r>')
	check(small.attr("a") == "1" and small.attr("zz") == "" and small.child_count() == 3, "attr and element-only children")
	check(small.child_list("k").size() == 2 and small.child("k").attr("x") == "y" and small.child("k").to_int() == 5, "child_list and first-match")
	# 全部数据文件都能解析（含第 24 关等做过注释规范化的文件）
	var parsed := 0
	for f in DirAccess.get_files_at("res://data/xml"):
		if f.ends_with(".xml"):
			var n := RWXml.load_file("res://data/xml/" + f)
			check(n != null and n.child_count() > 0, "xml parses: " + f)
			parsed += 1
	check(parsed == 26, "26 xml files present (got %d)" % parsed)
	var l1 := RWXml.load_file("res://data/xml/6619_extDataManager_extlvl1.xml")
	var wave: RWXml = l1.children()[0]
	check(wave.text("type") == "ENEMY_SPAWN" and wave.child("data").child_list("unit").size() > 1, "level wave structure")
	check(wave.child("data").children()[0].text("kind") == "UNDEAD_ZOMBIE" and near(wave.child("data").children()[0].to_number("spawnProb"), 0.97), "level unit fields")

func test_bmp_frames() -> void:
	var f := BmpFrames.from_symbol("warriorAttackAni")
	check(f != null and f.id == 3392, "warriorAttackAni loads")
	if f == null: return
	check(f.num_frames == 20 and f.frame_commands.size() == 20, "warriorAttackAni has 20 frames")
	check(BmpFrames.from_id(3392) == f, "BmpFrames cache returns same instance")
	var content := root.get_node("Content")
	var b: Array = content.bounds["3392"]
	check(f.offset == Vector2(float(b[0]), float(b[1])), "offset equals bounds origin")
	var sprite := Sprite2D.new()
	f.apply_frame(sprite, 5)
	check(not sprite.centered and sprite.offset == f.offset and sprite.texture == f.get_frame_texture(5), "apply_frame sets texture/offset, centered=false")
	check(sprite.texture is AtlasTexture and sprite.texture.region.size == Vector2(56, 49), "frame texture is an atlas region")
	var path := "res://data/anim_commands.json"
	if FileAccess.file_exists(path):
		var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)).get("3392")
		if rec is Dictionary:
			var same := true
			for i in 20:
				if f.frame_commands[i] != int(rec.commands[i]): same = false
			check(same, "frame_commands match anim_commands.json")
	check(BmpFrames.NOTHING == 0 and BmpFrames.STOP == 1 and BmpFrames.DONE == 2 and BmpFrames.ACTION == 3, "command constants")
	var plain := BmpFrames.from_symbol("warriorAttackAni")
	check(plain.get_command(0) in [0, 1, 2, 3], "get_command in range")
	sprite.free()

func test_z_sorter() -> void:
	var holder := Node2D.new()
	var units: Array = []
	var unit_script := GDScript.new()
	unit_script.source_code = "extends Node2D\nvar uid := 0\n"
	unit_script.reload()
	var ys := [30.0, 10.0, 20.0, 20.0, 5.0]
	for i in ys.size():
		var u := Node2D.new()
		u.set_script(unit_script)
		u.position.y = ys[i]
		u.uid = 100 - i  # 同 y 时 uid 小的在前
		holder.add_child(u)
		units.append(u)
	ArrayZSorter.sort_clips(units, holder)
	var order: Array = []
	for c in holder.get_children(): order.append(c.uid)
	# y: 5(uid96) 10(uid99) 20(uid97 < 98 -> uid 97 is index3) ...
	check(order == [96, 99, 97, 98, 100], "z sort by y then uid, got %s" % str(order))
	holder.free()

func test_ease() -> void:
	check(near(RWEase.default_ease_out(0.5, 0, 1, 1), 0.75), "default ease is 1-(1-t)^2")
	check(near(RWEase.cubic_ease_out(0.5, 0, 1, 1), 0.875), "Cubic.easeOut(0.5)")
	check(near(RWEase.cubic_ease_in(0.5, 0, 1, 1), 0.125), "Cubic.easeIn(0.5)")
	check(near(RWEase.linear_ease_none(0.3, 0, 1, 1), 0.3), "Linear")
	check(RWEase.elastic_ease_out(1.0, 0, 1, 1) == 1.0 and RWEase.elastic_ease_out(0.0, 0, 1, 1) == 0.0, "Elastic.easeOut endpoints")
	check(near(RWEase.elastic_ease_out(0.5, 0, 1, 1), 1.0 + pow(2.0, -5.0) * sin((0.5 - 0.075) * TAU / 0.3)), "Elastic.easeOut formula")
	check(RWEase.elastic_ease_in_out(0.0, 0, 1, 1) == 0.0 and RWEase.elastic_ease_in_out(1.0, 0, 1, 1) == 1.0, "Elastic.easeInOut endpoints")

func make_node() -> Node2D:
	var n := Node2D.new()
	return n

func test_tween_basic() -> void:
	RWTween.reset()
	check(tw.process_mode == Node.PROCESS_MODE_ALWAYS, "RWTween ignores SceneTree.paused")
	var n := make_node()
	RWTween.to(n, 1.0, {"x": 100.0})
	RWTween.step(0.5)
	check(near(n.position.x, 75.0), "to: default Quad-out at half time = 75 (got %f)" % n.position.x)
	RWTween.step(0.5)
	check(near(n.position.x, 100.0), "to: reaches target")
	# linear + onComplete timing + params
	calls.clear()
	n.position.x = 0
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["done"]})
	RWTween.step(0.99)
	check(calls.is_empty() and near(n.position.x, 99.0), "onComplete not before the end")
	RWTween.step(0.02)
	check(calls == ["done"] and near(n.position.x, 100.0), "onComplete once at the end with params")
	RWTween.step(1.0)
	check(calls.size() == 1, "onComplete not repeated")
	# delay: start is measured from the last rendered root time
	RWTween.reset()
	n.position.x = 0
	RWTween.to(n, 1.0, {"x": 100.0, "delay": 0.5, "ease": RWEase.linear_ease_none})
	RWTween.step(0.25)
	check(n.position.x == 0.0, "delay: untouched before start")
	RWTween.step(0.5)
	check(near(n.position.x, 25.0), "delay: 0.25s into the tween")
	# from: immediate assign, even with delay, then tween back to the original value
	RWTween.reset()
	n.position.x = 50
	RWTween.from(n, 1.0, {"x": 150.0, "delay": 1.0, "ease": RWEase.linear_ease_none})
	check(n.position.x == 150.0, "from: immediate assignment")
	RWTween.step(1.0)
	check(n.position.x == 150.0, "from: held through the delay")
	RWTween.step(0.5)
	check(near(n.position.x, 100.0), "from: halfway back")
	RWTween.step(0.6)
	check(near(n.position.x, 50.0), "from: ends at the original value")
	# relative string values
	RWTween.reset()
	n.position.y = 10
	RWTween.from(n, 0.4, {"y": "-100", "ease": RWEase.linear_ease_none})
	check(near(n.position.y, -90.0), "from: relative string value starts at cur-100")
	RWTween.step(0.4)
	check(near(n.position.y, 10.0), "from: relative string ends at cur")
	# rotation / scale / alpha mapping
	RWTween.reset()
	n.rotation_degrees = 0
	RWTween.to(n, 1.0, {"rotation": 90.0, "scaleX": 2.0, "alpha": 0.5, "ease": RWEase.linear_ease_none})
	RWTween.step(1.0)
	check(near(n.rotation_degrees, 90.0) and near(n.scale.x, 2.0) and near(n.modulate.a, 0.5), "rotation/scaleX/alpha mapping")
	# autoAlpha hides at 0
	RWTween.reset()
	n.modulate.a = 1.0
	n.visible = true
	RWTween.to(n, 0.5, {"autoAlpha": 0.0, "ease": RWEase.linear_ease_none})
	RWTween.step(0.25)
	check(n.visible and near(n.modulate.a, 0.5), "autoAlpha: visible while fading")
	RWTween.step(0.3)
	check(not n.visible and n.modulate.a == 0.0, "autoAlpha: hidden at alpha 0")
	# zero-duration tween applies immediately and completes
	RWTween.reset()
	calls.clear()
	RWTween.to(n, 0.0, {"x": 7.0, "onComplete": note, "onCompleteParams": ["z"]})
	check(n.position.x == 7.0 and calls == ["z"], "zero-duration to renders and completes immediately")
	# allTo stagger + allFrom
	RWTween.reset()
	var a := make_node(); var b := make_node(); var c := make_node()
	RWTween.all_to([a, b, c], 0.2, {"x": 10.0, "ease": RWEase.linear_ease_none}, 0.1, note, ["all"])
	calls.clear()
	RWTween.step(0.2)
	check(near(a.position.x, 10.0) and near(b.position.x, 5.0) and c.position.x == 0.0, "allTo stagger")
	RWTween.step(0.1)
	check(calls.is_empty(), "allTo onCompleteAll waits for last target")
	RWTween.step(0.1)
	check(calls == ["all"] and near(c.position.x, 10.0), "allTo onCompleteAll fires with last target")
	RWTween.reset()
	RWTween.all_from([a, b], 0.2, {"y": "42"}, 0.1)
	check(near(a.position.y, 42.0) and near(b.position.y, 42.0), "allFrom assigns immediately")
	a.free(); b.free(); c.free(); n.free()

func test_tween_pause_kill() -> void:
	RWTween.reset()
	var n := make_node()
	calls.clear()
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["tw"]})
	RWTween.delayed_call(0.6, note, ["dc"])
	RWTween.step(0.5)
	RWTween.pause_all()
	RWTween.step(5.0)
	check(near(n.position.x, 50.0) and calls.is_empty(), "pause_all freezes tweens and delayed calls")
	RWTween.resume_all()
	RWTween.step(0.4)
	check(near(n.position.x, 90.0) and calls == ["dc"], "after resume_all time continues (delayed call at 0.6 fired, tween not yet)")
	RWTween.step(0.11)
	check(calls == ["dc", "tw"], "tween completes after resume")
	# pause_all(tweens only)
	RWTween.reset(); calls.clear()
	n.position.x = 0
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none})
	RWTween.delayed_call(0.5, note, ["dc"])
	RWTween.pause_all(true, false)
	RWTween.step(0.6)
	check(n.position.x == 0.0 and calls == ["dc"], "pause_all(tweens=true, delayedCalls=false) leaves delayed calls running")
	# TweenMax.pauseAll()/resumeAll() 对照 editable/scripts/com/greensock/TweenMax.as 的 changePause()：
	# 只对调用那一刻 getAllTweens() 里已经存在的 tween 做一次性的 `.paused = x` 赋值，没有任何全局标志，
	# 所以暂停期间新建的 tween（原版等价于关卡对话框弹出/游戏失焦自动暂停期间，HUD 代码仍可能新建补间，
	# 例如 showRedButton 的淡出动画）不受影响，照常从 0 开始播放，直到自己调用处理完才算数；
	# resumeAll() 之后，之前被冻结的那些旧 tween 要能从冻结时的进度继续推进，不是从头重放。
	RWTween.reset(); calls.clear()
	var n2 := make_node()
	n.position.x = 0
	n2.position.x = 0
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none})
	RWTween.step(0.3)
	RWTween.pause_all()
	# 暂停期间新建的 tween（等价于暂停中仍会跑的 HUD 代码新开的补间）：不应该被这次 pause_all 影响。
	RWTween.to(n2, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none})
	RWTween.step(0.5)
	check(near(n.position.x, 30.0), "pause_all 期间旧 tween 保持冻结在暂停时的进度")
	check(near(n2.position.x, 50.0), "pause_all 期间新建的 tween 不受影响，照常从 0 开始播放")
	RWTween.resume_all()
	RWTween.step(0.2)
	check(near(n.position.x, 50.0), "resume_all 后旧 tween 从冻结时的进度（0.3）继续，不是从头重放")
	check(near(n2.position.x, 70.0), "resume_all 不影响本来就没被暂停过的新 tween")
	RWTween.step(0.5)
	check(near(n.position.x, 100.0) and near(n2.position.x, 100.0), "两者最终都能播完")
	n2.free()
	# kill_all
	RWTween.reset(); calls.clear()
	RWTween.to(n, 1.0, {"x": 100.0, "onComplete": note, "onCompleteParams": ["k"]})
	RWTween.delayed_call(0.2, note, ["kd"])
	RWTween.kill_all()
	RWTween.step(2.0)
	check(calls.is_empty() and RWTween.get_all_tweens().is_empty(), "kill_all clears everything without callbacks")
	# kill_all(false, false, true) kills only delayed calls (Main.as screen switch)
	RWTween.reset(); calls.clear()
	n.position.x = 0
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["t"]})
	RWTween.delayed_call(0.2, note, ["d"])
	RWTween.kill_all(false, false, true)
	RWTween.step(1.1)
	check(calls == ["t"], "kill_all(false,false,true) kills delayed calls only")
	# killTweensOf and kill_delayed_calls_to
	RWTween.reset(); calls.clear()
	var h: Callable = note.bind("cb")
	RWTween.delayed_call(0.1, h)
	RWTween.kill_delayed_calls_to(h)
	RWTween.to(n, 1.0, {"x": 5.0, "onComplete": note, "onCompleteParams": ["no"]})
	RWTween.kill_tweens_of(n)
	RWTween.step(2.0)
	check(calls.is_empty(), "killTweensOf / killDelayedCallsTo")
	# handle.kill
	RWTween.reset(); calls.clear()
	var hd = RWTween.to(n, 1.0, {"x": 5.0, "onComplete": note, "onCompleteParams": ["no"]})
	hd.kill()
	RWTween.step(2.0)
	check(calls.is_empty(), "handle.kill")
	# delayed call fires once at its time
	RWTween.reset(); calls.clear()
	RWTween.delayed_call(0.3, note, ["a"])
	RWTween.step(0.2)
	check(calls.is_empty(), "delayed_call not early")
	RWTween.step(0.2)
	check(calls == ["a"], "delayed_call fires")
	RWTween.step(1.0)
	check(calls == ["a"], "delayed_call fires once")
	n.free()

func test_tween_overwrite() -> void:
	RWTween.reset(); calls.clear()
	var n := make_node()
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["first"]})
	RWTween.step(0.5)
	# AUTO: a new tween on the same property kills the running one (no onComplete)
	RWTween.to(n, 1.0, {"x": 0.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["second"]})
	RWTween.step(0.5)
	check(near(n.position.x, 25.0), "AUTO overwrite: second tween drives x (got %f)" % n.position.x)
	RWTween.step(0.6)
	check(calls == ["second"] and near(n.position.x, 0.0), "AUTO overwrite: killed tween never calls onComplete")
	# other properties are untouched
	RWTween.reset(); calls.clear()
	n.position = Vector2.ZERO
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["x"]})
	RWTween.step(0.2)
	RWTween.to(n, 1.0, {"y": 100.0, "ease": RWEase.linear_ease_none})
	RWTween.step(0.9)
	check(calls == ["x"] and near(n.position.x, 100.0) and near(n.position.y, 90.0), "AUTO overwrite keeps non-overlapping properties")
	# delayed calls are never overwritten (overwrite 0)
	RWTween.reset(); calls.clear()
	var cb: Callable = note.bind("dc")
	RWTween.delayed_call(0.5, cb)
	RWTween.delayed_call(0.5, cb)
	RWTween.step(0.6)
	check(calls == ["dc", "dc"], "delayed calls with the same callable both fire")
	# a pending (delayed) tween that is later overwritten at init
	RWTween.reset(); calls.clear()
	n.position = Vector2.ZERO
	RWTween.to(n, 1.0, {"x": 100.0, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["A"]})
	RWTween.to(n, 0.5, {"x": -50.0, "delay": 0.5, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["B"]})
	RWTween.step(0.5)
	check(near(n.position.x, 50.0), "pending tween does not touch the target before its delay")
	RWTween.step(0.25)
	# B initialises at t=0.5+: A (start 0, end 1) overlaps B.start -> A loses x
	check(near(n.position.x, 50.0 + (-50.0 - 50.0) * 0.5), "B takes over x at its init (got %f)" % n.position.x)
	RWTween.step(0.5)
	check(calls == ["B"], "overwritten A never completes")
	n.free()

func test_tween_bezier() -> void:
	RWTween.reset()
	var n := make_node()
	var p0 := Vector2(0, 0)
	var pm := Vector2(50, -30)
	var pe := Vector2(100, 0)
	calls.clear()
	var h = RWTween.to(n, 1.0, {
		"bezierThrough": [{"x": pm.x, "y": pm.y}, {"x": pe.x, "y": pe.y}],
		"orientToBezier": true, "ease": RWEase.linear_ease_none, "onComplete": note, "onCompleteParams": ["b"]})
	RWTween.step(0.0001)
	check(near(n.position.x, 0.0, 0.01), "bezier starts at the current position")
	RWTween.step(0.2499)
	# segment 0 control: (P1 - (P2-P0)/4) = (25, -30); t=0.5 -> (25, -22.5)
	check(near(n.position.x, 25.0, 0.01) and near(n.position.y, -22.5, 0.01), "bezier quarter point (got %s)" % str(n.position))
	check(n.rotation_degrees < 0.0, "orientToBezier: rising path has negative (y-down) rotation")
	RWTween.step(0.25)
	check(near(n.position.x, 50.0, 0.01) and near(n.position.y, -30.0, 0.01), "bezier passes through the control point at 0.5")
	RWTween.step(0.6)
	check(near(n.position.x, 100.0) and near(n.position.y, 0.0) and calls == ["b"], "bezier ends at the final point")
	check(n.rotation_degrees > 0.0, "orientToBezier: descending end has positive rotation")
	# parse_beziers: 4-point through gives 3 segments with reflected controls
	var bezier_cls = RWTween.BezierPlugin
	var segs: Dictionary = bezier_cls.parse_beziers({"x": [0.0, 10.0, 20.0, 40.0]}, true)
	check(segs["x"].size() == 3 and near(segs["x"][0][1], 10.0 - (20.0 - 0.0) / 4.0) and near(segs["x"][1][1], 10.0 + (10.0 - segs["x"][0][1])), "parseBeziers through branch")
	n.free()

func test_tween_color() -> void:
	RWTween.reset()
	var n := Node2D.new()
	root.add_child(n)
	RWTween.to(n, 0.3, {"colorTransform": {"brightness": 1.3}, "ease": RWEase.linear_ease_none})
	RWTween.step(0.3)
	var ct: Array = n.get_meta("rw_ct")
	check(near(ct[0], 0.7) and near(ct[3], 76.5), "colorTransform brightness 1.3 -> mul 0.7, offset 76.5")
	check(n.material is ShaderMaterial and n.material.get_shader_parameter("ct_add").is_equal_approx(Vector3(0.3, 0.3, 0.3)), "colorTransform reaches the shader (add 0.3)")
	RWTween.to(n, 0.2, {"colorTransform": {"brightness": 1.0}, "ease": RWEase.linear_ease_none})
	RWTween.step(0.2)
	ct = n.get_meta("rw_ct")
	check(near(ct[0], 1.0) and near(ct[3], 0.0), "colorTransform brightness back to 1")
	# fromTo colorMatrixFilter brightness 1.5 -> 1 (offset 50 -> 0)
	RWTween.reset()
	RWTween.from_to(n, 0.4, {"colorMatrixFilter": {"brightness": 1.5}}, {"colorMatrixFilter": {"brightness": 1.0}, "ease": RWEase.linear_ease_none})
	RWTween.step(0.0001)
	var cm: Array = n.get_meta("rw_cm")
	check(near(cm[4], 50.0, 0.1) and near(cm[0], 1.0), "colorMatrixFilter fromTo starts at brightness offset 50")
	RWTween.step(0.2)
	cm = n.get_meta("rw_cm")
	check(near(cm[4], 25.0, 0.5), "colorMatrixFilter halfway offset 25")
	RWTween.step(0.3)
	cm = n.get_meta("rw_cm")
	check(near(cm[4], 0.0, 0.01), "colorMatrixFilter ends at identity")
	# contrast/saturation/brightness combo (AS3 applyMatrix int truncation of the offset column)
	var m: Array = RWTweenUtil.set_brightness(RWTweenUtil._ID_MATRIX.duplicate(), 0.5)
	check(near(m[4], -50.0) and near(m[0], 1.0), "setBrightness(0.5) offset -50")
	m = RWTweenUtil.set_contrast(m, 0.5)
	check(near(m[0], 0.51) and near(m[4], 0.51 * -50.0 + int(128.0 * (1.0 - 0.51))), "setContrast composes on the brightness matrix")
	# glowFilter is accepted (approximation: no visual)
	RWTween.reset(); calls.clear()
	RWTween.to(n, 0.1, {"glowFilter": {"color": 0xFFFFFF, "alpha": 1}, "onComplete": note, "onCompleteParams": ["g"]})
	RWTween.step(0.2)
	check(calls == ["g"], "glowFilter tween completes on time")
	n.free()

func test_tween_realtime_and_pause() -> void:
	RWTween.reset()
	tw.manual_clock = false
	calls.clear()
	paused = true  # SceneTree.paused 不影响 RWTween
	RWTween.delayed_call(0.05, note, ["rt"])
	var waited := 0
	while waited < 60 and calls.is_empty():
		await process_frame
		OS.delay_msec(10)
		waited += 1
	paused = false
	check(calls == ["rt"], "wall-clock delayed_call fires while SceneTree.paused")
	tw.manual_clock = true
	RWTween.reset()
