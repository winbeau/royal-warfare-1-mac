extends SceneTree
var failures: Array = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile: quit(2); return
	var lib := SoundLibrary.new()
	lib.init()
	check(SoundLibrary.inst == lib, "init() registers SoundLibrary.inst")

	# 1. 映射：symbols.json 中的 soundLibrary_ 壳类全部可解析为存在的 mp3
	var f := FileAccess.open(SoundLibrary.SYMBOLS_PATH, FileAccess.READ)
	var symbols: Dictionary = JSON.parse_string(f.get_as_text())
	var shells := 0
	for k in symbols:
		if str(k).begins_with(SoundLibrary.SYMBOL_PREFIX):
			shells += 1
			var p := SoundLibrary.mp3_path(str(k).trim_prefix(SoundLibrary.SYMBOL_PREFIX))
			check(p != "", "path resolved for %s" % k)
			check(ResourceLoader.exists(p), "mp3 exists for %s" % k)
	check(shells == 142, "142 soundLibrary shell classes in symbols.json (got %d)" % shells)
	var missing := 0
	for key in SoundLibrary.LIB_CLASSES:
		if lib.get_sound(key) == null: missing += 1
	check(missing == 0, "all %d lib keys load a stream (missing %d)" % [SoundLibrary.LIB_CLASSES.size(), missing])
	check(lib.get_sound(SoundLibrary.MAGE_BLACK_STRIKE3) != null, "original quirk: MAGE_BLACK_STRIKE3 maps to sMageBlackStrike2")
	check(SoundLibrary.LIB_CLASSES[SoundLibrary.MAGE_BLACK_STRIKE3] == "sMageBlackStrike2", "MAGE_BLACK_STRIKE3 uses sMageBlackStrike2")

	# 2. 分组随机选择可复现，且与 RWRandom 调用序列一致
	var groups := ["swordSwoosh", "arrowGround", "manVoice", "monsters", "block"]
	RWRandom.set_seed(12345)
	var first: Array = []
	for i in 40: first.append(lib.get_sound_from_stack(groups[i % groups.size()]))
	RWRandom.set_seed(12345)
	var second: Array = []
	for i in 40: second.append(lib.get_sound_from_stack(groups[i % groups.size()]))
	check(first == second, "get_sound_from_stack reproducible under fixed seed")
	RWRandom.set_seed(777)
	var ok := true
	var names := {"swordSwoosh": "SWORD_SWOOSH"}
	var cands: Array = SoundLibrary.SOUND_OBJ[names["swordSwoosh"]]
	var seq: Array = []
	for i in 12: seq.append(RWRandom.rand_range(0, cands.size() - 1))
	RWRandom.set_seed(777)
	for i in 12:
		if lib.get_sound_from_stack("swordSwoosh") != lib.get_sound(cands[seq[i]]): ok = false
	check(ok, "get_sound_from_stack consumes exactly one rand_range(0,n-1) per call")
	check(not SoundLibrary.SOUND_OBJ["ARROW_GROUND"].has(SoundLibrary.ARROW_GROUND4), "original quirk: ARROW_GROUND list omits 4")

	# 3. Sounds 节点
	var snd := Sounds.new()
	root.add_child(snd)
	snd.init_sounds_first({"music": true, "sound": true})
	check(Sounds.inst == snd, "init_sounds_first registers Sounds.inst")
	var s := lib.get_sound(SoundLibrary.SWORD_SWOOSH1)
	var chans: Array = []
	for i in 6: chans.append(snd.play(s, false, 0, 1, 350, SoundLibrary.SWORD_SWOOSH))
	var played := 0
	for c in chans: if c != null: played += 1
	check(played == 4, "SWORD_SWOOSH concurrency capped at 4 (got %d)" % played)
	check(snd.o_types[SoundLibrary.SWORD_SWOOSH] == 4, "type counter at max")
	snd.sound_completed(chans[0])
	check(snd.o_types[SoundLibrary.SWORD_SWOOSH] == 3, "SOUND_COMPLETE frees one slot")
	check(snd.play(s, false, 0, 1, 350, SoundLibrary.SWORD_SWOOSH) != null, "slot reusable after completion")
	check(snd.play(s, false, 0, 1, 350, SoundLibrary.SWORD_SWOOSH) == null, "capped again")
	check(snd.o_types_max[SoundLibrary.WIN_MUSIC] == 1 and snd.o_types_max[SoundLibrary.ARCHER_PULL] == 2 and snd.o_types_max[SoundLibrary.AXE] == 3, "oTypesMax table")
	for c in chans: if c != null and snd.d_channels.has(c): snd.sound_completed(c)

	# 4. 声像与音量
	var cl := snd.play(s, false, 0, 0.5, 0)
	check(is_equal_approx(cl.pan, -0.5) and is_equal_approx(snd.pan, -0.5), "pan at x=0 is -0.5")
	check(is_equal_approx(cl.volume, 0.5) and is_equal_approx(cl.player.volume_db, linear_to_db(0.5)), "volume 0.5 -> linear_to_db")
	var cm := snd.play(s, false, 0, 1, 350)
	check(is_equal_approx(cm.pan, 0.0), "pan at x=350 is 0")
	var cr := snd.play(s, false, 0, 1, 700)
	check(is_equal_approx(cr.pan, 0.5) and is_equal_approx(cr.panner.pan, 0.5), "pan at x=700 is 0.5, panner effect updated")
	check(is_equal_approx((175.0 / 350 - 1) * 0.5, -0.25), "pan formula (x/350-1)*0.5")

	# 5. 总开关
	snd.on(false)
	check(snd.play(s) == null and AudioServer.is_bus_mute(0), "sound off: no playback, mixer muted")
	snd.on(true)
	check(not AudioServer.is_bus_mute(0), "sound on restores mixer")

	# 6. 音乐
	var mm := lib.get_sound(SoundLibrary.MENU_MUSIC)
	snd.play_music(mm, true, 0, 0.25, 0, true)
	check(snd.current_music == mm and snd.music_channel != null and snd.music_channel.volume == 0.0, "music starts at volume 0 before fade-in")
	await create_timer(0.7).timeout
	check(is_equal_approx(snd.music_channel.volume, 0.25), "music faded in to 0.25 (got %f)" % snd.music_channel.volume)
	var mc: Sounds.Channel = snd.music_channel
	snd.play_music(mm, true, 0, 0.25)
	check(snd.music_channel == mc, "same music is not restarted")
	snd.pause_music()
	check(snd.current_music == null, "pause_music clears current music")
	await create_timer(0.7).timeout
	check(mc.stopped, "stop_music fades out then stops channel")
	snd.music_on = false
	snd.play_music(lib.get_sound(SoundLibrary.BATTLE_MUSIC))
	check(snd.current_music == null, "music_on=false suppresses music")
	snd.queue_free()
	await process_frame
	print("sounds_runtime: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)
