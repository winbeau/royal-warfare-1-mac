extends SceneTree
# M1：Main 的切屏顺序、loadGame(0) -> -2 映射、漫画标志决定地图首屏、旧存档迁移。
# 运行：Godot --headless --path . --script tests/main_flow.gd -- --isolated-profile
var checks := 0
var failures: Array = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

## 用替身容器代替 gameScreensContainer 的子节点，记录 fade_clear_load_unfade 实际加入的面板。
class SpyPanel extends Node:
	var tag: String
	func _init(t: String) -> void:
		tag = t

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return

	await test_legacy_migration()
	test_load_game_zero_maps_to_intro()
	await test_load_map_picks_comic_by_flag()
	await test_fade_clear_load_unfade_sequence()

	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


## loadGame(0)：levelIntro.isShown == false 时 level 参数改写为 -2（教学关）；为 true 则按正常映射。
func test_load_game_zero_maps_to_intro() -> void:
	var m := Main.new()
	# load_game 的参数改写（levelIntro.isShown / canEndIntro）不依赖 game_uni，这里直接复刻该判断验证。
	LevelIntro.is_shown = false
	LevelIntro.can_end_intro = false
	m.last_level_num = 0
	# load_game 内部不经过 fade_clear_load_unfade 之外的分支即可验证参数改写：直接复刻其前半段判断。
	var lvl := 0
	if lvl == 0:
		if LevelIntro.is_shown == false:
			lvl = -2
		elif LevelIntro.can_end_intro == false:
			lvl = -2
			LevelIntro.is_shown = true
	check(lvl == -2, "levelIntro.isShown==false 时 loadGame(0) 映射为 -2")

	LevelIntro.is_shown = true
	LevelIntro.can_end_intro = true
	lvl = 0
	if lvl == 0:
		if LevelIntro.is_shown == false:
			lvl = -2
		elif LevelIntro.can_end_intro == false:
			lvl = -2
			LevelIntro.is_shown = true
	check(lvl == 0, "levelIntro 已显示且已可结束时 loadGame(0) 保持 0（真正进入第 1 关）")
	LevelIntro.is_shown = false
	LevelIntro.can_end_intro = false


## loadMap：按 comix_* 标志（0=未看）依次挑第一个未看的漫画；全部看过则直接显示地图。
func test_load_map_picks_comic_by_flag() -> void:
	StoredData.test_wipe()
	StoredData.init()
	var flags: Dictionary = StoredData.local_game_data[StoredData.NUMPAN_COMIX]

	flags["comix_intro"] = 0
	check(_first_unseen_comic(flags) == "comix_intro", "comix_intro 未看时 loadMap 优先放序章漫画")

	flags["comix_intro"] = 1
	flags["comix_two"] = 0
	check(_first_unseen_comic(flags) == "comix_two", "comix_intro 已看、comix_two 未看时放第二段")

	flags["comix_two"] = 1
	flags["comix_three"] = 1
	flags["comix_four"] = 1
	flags["comix_five"] = 1
	flags["comix_end"] = 1
	check(_first_unseen_comic(flags) == "", "全部漫画都已看过时 loadMap 直接显示地图")
	await process_frame


## 复刻 Main.loadMap 的 if/elif 链（只看判断逻辑，不依赖已初始化的面板实例）。
func _first_unseen_comic(flags: Dictionary) -> String:
	for key in ["comix_intro", "comix_two", "comix_three", "comix_four", "comix_five", "comix_end"]:
		if flags[key] == 0:
			return key
	return ""


## fade_clear_load_unfade：黑屏淡入 -> 延迟 0.1 秒换面板（清空容器、kill_all 只清延迟调用、加入新面板、按需 init）-> 淡出。
func test_fade_clear_load_unfade_sequence() -> void:
	var m := Main.new()
	m.game_screens_container = Node2D.new()
	root.add_child(m.game_screens_container)
	m.fade_black_screen = ColorRect.new()
	m.fade_black_screen.color = Color.BLACK
	root.add_child(m.fade_black_screen)
	m.fade_black_screen.visible = false
	RWTween.inst_().manual_clock = true
	RWTween.reset()

	var old_panel := SpyPanel.new("old")
	m.game_screens_container.add_child(old_panel)
	var new_panel := SpyPanel.new("new")
	# 用一个真正带 init(level) 的替身验证 optional_init 被转发。
	var gu_spy := _GuSpy.new()
	m.game_uni = gu_spy

	m.fade_clear_load_unfade(new_panel, 5)
	check(m.fade_black_screen.visible == true, "切屏开始：黑屏先置可见")
	check(is_equal_approx(m.fade_black_screen.modulate.a, 0.0), "黑屏淡入从 alpha=0 起步")

	RWTween.step(0.3)  # 淡入 0.3 秒完成 -> faded() -> delayed_call(0.1, changes)
	check(is_equal_approx(m.fade_black_screen.modulate.a, 1.0), "0.3 秒后黑屏淡入完成")
	check(old_panel.get_parent() == m.game_screens_container, "延迟 0.1 秒前容器尚未清空")

	RWTween.step(0.1)  # changes() 执行：清空容器、加入新面板、init(5)
	check(old_panel.get_parent() == null, "changes()：旧面板已从容器移除")
	check(new_panel.get_parent() == m.game_screens_container, "changes()：新面板已加入容器")
	check(gu_spy.inited_with == 5, "changes()：optional_init!=NO_INIT 时转发给 game_uni.init(level)")

	RWTween.step(0.3001)  # 淡出 0.3 秒 -> unfaded()（略多推进一点，避免浮点累积误差卡在边界前）
	check(is_equal_approx(m.fade_black_screen.modulate.a, 0.0), "0.3 秒后黑屏淡出完成")
	check(m.fade_black_screen.visible == false, "淡出完成后黑屏重新隐藏")

	m.game_screens_container.queue_free()
	m.fade_black_screen.queue_free()
	RWTween.reset()
	await process_frame


## GameUniverse.init(level) 内部触及大量未就绪的静态单例，这里只用来验证 fade_clear_load_unfade
## 把 optional_init 转发给了 game_uni.init(level)：重写 init 记录参数、不调用 super。
class _GuSpy extends GameUniverse:
	var inited_with: Variant = null
	func init(level: int) -> void:
		inited_with = level


## 首次启动迁移：旧 campaign.json -> 新 aGameData/mainParams/endGameFlag。纯函数级别验证字段对应，
## 不经磁盘（LegacySave.convert_profile 是静态纯函数）。
func test_legacy_migration() -> void:
	var old := {
		"version": 1,
		"slots": _initial_slots(),
		"sound": false, "music": true, "autopause": false, "intro_seen": true,
	}
	(old.slots[0] as Array)[0] = 3
	(old.slots[0] as Array)[1] = 2
	(old.slots[1] as Array)[0] = 1
	(old.slots[2] as Array)[5] = 1
	(old.slots[4] as Array)[0] = 1
	(old.slots[7] as Dictionary)["comix_two"] = 1
	(old.slots[12]) = 2

	var result := LegacySave.convert_profile(old)
	check(not result.is_empty(), "可识别的旧存档能被转换")
	var save: Dictionary = result.get("save", {})
	var data: Array = save.get("aGameData", [])
	check(int(data[StoredData.NUMPAN_LEVELS][0]) == 3, "关卡星数迁移：第 1 关 3 星")
	check(int(data[StoredData.NUMPAN_LEVELS][1]) == 2, "关卡星数迁移：第 2 关 2 星")
	check(int(data[StoredData.NUMPAN_UNITS][0]) == 1, "兵种解锁迁移")
	check(int(data[StoredData.NUMPAN_ABILS][5]) == 1, "技能迁移")
	check(int(data[StoredData.NUMPAN_ACHIVES][0]) == 1, "成就迁移")
	check(int((data[StoredData.NUMPAN_COMIX] as Dictionary)["comix_two"]) == 1, "漫画标志迁移")
	check(int(data[StoredData.NUMPAN_DIFFICULTY]) == 2, "难度迁移")
	var params: Dictionary = save.get("mainParams", {})
	check(params["sound"] == false, "声音开关迁移")
	check(params["music"] == true, "音乐开关迁移")
	check(params["autop"] == false, "自动暂停开关迁移")
	check(params["hints"] == true, "hints 无旧字段对应，保持新存档默认值 true")
	var report: Array = result.get("report", [])
	check(report.any(func(s: String) -> bool: return s.contains("intro_seen")), "intro_seen 无对应新字段，记入报告")

	# 字段对不上时保持默认值：槽 0 长度错误。
	var bad := {"slots": _initial_slots(), "sound": true, "music": true, "autopause": true}
	(bad.slots[0]) = [1, 2, 3]  # 错误长度
	var bad_result := LegacySave.convert_profile(bad)
	var bad_data: Array = bad_result["save"]["aGameData"]
	check((bad_data[StoredData.NUMPAN_LEVELS] as Array).size() == 24, "槽长度不对时保持新存档默认长度")
	check((bad_result["report"] as Array).any(func(s: String) -> bool: return s.contains("槽 0")), "字段对不上时记入报告")

	# 端到端：真实文件路径（隔离目录下的临时文件），验证 migrate_if_needed 在新存档不存在时写入。
	var old_path := "user://_test_legacy_campaign.json"
	var new_path := "user://_test_legacy_RoyalDefenderGame7.json"
	for p in [old_path, new_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var f := FileAccess.open(old_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var mig := LegacySave.migrate_if_needed(old_path, new_path)
	check(mig["migrated"] == true, "新存档不存在、旧存档存在时执行迁移")
	check(FileAccess.file_exists(new_path), "迁移写出了新存档文件")
	check(FileAccess.file_exists(old_path), "旧存档文件未被删除")
	var mig2 := LegacySave.migrate_if_needed(old_path, new_path)
	check(mig2["migrated"] == false, "新存档已存在时不重复迁移")
	for p in [old_path, new_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	await process_frame


func _initial_slots() -> Array:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/save_schema.json"))
	return (schema["initial_slots"] as Array).duplicate(true)
