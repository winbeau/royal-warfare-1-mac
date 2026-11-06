extends SceneTree
## 视觉工作台：在真实渲染下打开指定界面并截图，供 Claude 用 Read 检查实际效果。
## 由 dev/screens/shot.sh 启动（非 headless、窗口放在屏幕外、后台启动不抢焦点）。不要直接在前台运行。
## 用户参数（-- 之后）：
##   --isolated-profile        必带，不读写玩家存档
##   --ch2-dev                 用 dev 存档（一代 120 星、二章全开）
##   --shots=a,b,c             截图清单，见 _goto()
##   --out=build/screens       输出目录（相对工程根）
## 截图名：menu / map1 / ch2_map / upgrade1 / upgrade2 / battle_<章>_<关>_<秒>（如 battle_2_23_20）
## 全部完成后写 <out>/done.txt，然后退出。

var out_dir := "build/screens"
var shots: PackedStringArray = []
var main: Node = null
var _battle_captured := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8).split(",", false)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	call_deferred("run")


func _wait_sec(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(sec * 1000.0):
		await process_frame


func _wait_until(cond: Callable, timeout_sec: float) -> bool:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > int(timeout_sec * 1000.0):
			return false
		await process_frame
	return true


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := _out_abs()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name + ".png")
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


func _out_abs() -> String:
	return out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path("res://" + out_dir)


func run() -> void:
	var dir := _out_abs()
	DirAccess.make_dir_recursive_absolute(dir)
	if FileAccess.file_exists(dir.path_join("done.txt")):
		DirAccess.remove_absolute(dir.path_join("done.txt"))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait_until(func() -> bool: return main.resources_loaded, 30.0)
	await _wait_until(func() -> bool: return main.warmup_done, 60.0)
	StoredData.main_params["hints"] = false
	var report: PackedStringArray = []
	for s in shots:
		_battle_captured = false
		var ok: bool = await _goto(s)
		if ok and not _battle_captured:
			await _capture(s)
		report.append(("ok " if ok else "FAILED ") + s)
	var f := FileAccess.open(dir.path_join("done.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit(0)


## 导航到指定界面；返回是否成功。切屏有 0.7 秒黑幕淡入淡出，统一多等一会儿。
func _goto(s: String) -> bool:
	if s == "menu":
		main.load_main_menu()
	elif s == "map1":
		main.current_chapter = 1
		if "dev_ch1_visit" in main:
			main.dev_ch1_visit = true  # dev 存档下 Play 默认进二章，这里显式去一代地图
		main.load_map()
	elif s == "ch2_map":
		main.load_ch2_map()
	elif s == "upgrade1":
		main.current_chapter = 1
		main.load_upgrade_panel()
	elif s == "upgrade2":
		main.current_chapter = 2
		main.load_upgrade_panel()
	elif s.begins_with("battle_"):
		# battle_<章>_<关>_<秒>[-<秒>...]：进关一次，按给定的游戏秒数依次截图（文件名 battle_<章>_<关>_<秒>.png）。
		# 战斗中自动点掉对白、跳过红按钮倒计时，以便看到交战画面。
		var p := s.split("_")
		if p.size() < 4:
			return false
		main.current_chapter = int(p[1])
		main.load_game(int(p[2]) - 1)
		await _wait_sec(2.5)
		var gu: Node = main.game_uni
		if gu == null:
			return false
		var times: PackedStringArray = p[3].split("-", false)
		var start := int(gu.get_game_time())
		for t in times:
			var target := start + int(float(t) * 30.0)
			Engine.time_scale = 4.0
			var guard := Time.get_ticks_msec()
			while int(gu.get_game_time()) < target and Time.get_ticks_msec() - guard < 180000:
				if ChatFrameController.on_stage:
					ChatFrameController.close_chat()
				if gu.is_shown_red_button:
					gu.red_button_clicked()
				await process_frame
			Engine.time_scale = 1.0
			await _wait_sec(0.3)
			await _capture("battle_%s_%s_%s" % [p[1], p[2], t])
		_battle_captured = true
		return true
	else:
		return false
	await _wait_sec(1.6)
	return true
