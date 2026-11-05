# 移植自 S/utils/Sounds.as
# 声像：每个池内 AudioStreamPlayer 绑定一条专属总线（挂 AudioEffectPanner），pan 即 SoundTransform.pan。
# 音量：SoundTransform.volume 为线性 0..1，经 linear_to_db 写入 AudioStreamPlayer.volume_db。
# 总开关：SoundMixer.soundTransform -> Master 总线音量。
# 并发：AudioStreamPlayer 池（SFX 上限 MAX_SFX_CHANNELS，对应 Flash 的 32 声道），分类上限沿用 oTypesMax。
class_name Sounds
extends Node

static var inst: Sounds

const MAX_SFX_CHANNELS := 32


## 对应 flash.media.SoundChannel：包装一个池内播放器。volume/pan 可被 Tween 驱动。
class Channel extends RefCounted:
	signal sound_complete(channel: Channel)
	var player: AudioStreamPlayer
	var bus_index := -1
	var bus_name := ""
	var panner: AudioEffectPanner
	var looping := false
	var stopped := false
	var is_music := false
	var type_key := ""
	var _volume := 1.0
	var _pan := 0.0

	var volume: float:
		get: return _volume
		set(v):
			_volume = clampf(v, 0.0, 1.0)
			if player != null:
				player.volume_db = linear_to_db(_volume) if _volume > 0.0 else -80.0

	var pan: float:
		get: return _pan
		set(v):
			_pan = clampf(v, -1.0, 1.0)
			if panner != null:
				panner.pan = _pan

	## 毫秒，对应 SoundChannel.position。
	var position: float:
		get: return player.get_playback_position() * 1000.0 if player != null else 0.0

	func stop() -> void:
		stopped = true
		if player != null and player.playing:
			player.stop()

	func _on_finished() -> void:
		if stopped:
			return
		if looping:
			player.play(0.0)  # int.MAX_VALUE 次循环
			return
		stopped = true
		sound_complete.emit(self)


var sounds: Dictionary = {}  # Sound -> SoundChannel
var muted: Dictionary = {}
var sound_transforms: Dictionary = {}
var sound_on := true
var music_on := true
var music_channel: Channel = null
var current_music: AudioStream = null
var d_channels: Dictionary = {}  # Channel -> type 字符串
var o_types: Dictionary = {}
var o_types_max: Dictionary = {}
var a_cur_buttons_rover: Array = []
var a_cur_channels_rover: Array = []
var pan := 0.0
var res: Channel = null
var st = null
var ch: Channel = null
var menu_music_position := 0.0
var map_music_position := 0.0
var battle_music_position := 0.0
var cur_soundclass: AudioStream = null

var _idle: Array = []  # 空闲 Channel（保留其播放器与总线）
var _all_channels: Array = []
var _music_tween: Tween = null
var _stop_tweens: Dictionary = {}


func _init() -> void:
	pass


func _exit_tree() -> void:
	for c in _all_channels:
		var idx := AudioServer.get_bus_index(c.bus_name)
		if idx >= 0: AudioServer.remove_bus(idx)
	_all_channels.clear()
	_idle.clear()
	if inst == self: inst = null


# 取一个池内声道（新建或复用）。
func _acquire(music: bool) -> Channel:
	var c: Channel
	if not _idle.is_empty():
		c = _idle.pop_back()
	else:
		if not music and _sfx_busy_count() >= MAX_SFX_CHANNELS:
			return null
		c = Channel.new()
		c.player = AudioStreamPlayer.new()
		add_child(c.player)
		var bus_name := "RWSound_%d_%d" % [get_instance_id(), _all_channels.size()]
		AudioServer.add_bus()
		c.bus_index = AudioServer.bus_count - 1
		c.bus_name = bus_name
		AudioServer.set_bus_name(c.bus_index, bus_name)
		AudioServer.set_bus_send(c.bus_index, "Master")
		c.panner = AudioEffectPanner.new()
		AudioServer.add_bus_effect(c.bus_index, c.panner)
		c.player.bus = bus_name
		c.player.finished.connect(c._on_finished)
		_all_channels.append(c)
	if _stop_tweens.has(c) and is_instance_valid(_stop_tweens[c]):
		_stop_tweens[c].kill()
	_stop_tweens.erase(c)
	c.stopped = false
	c.looping = false
	c.is_music = music
	c.type_key = ""
	for conn in c.sound_complete.get_connections():
		c.sound_complete.disconnect(conn.callable)
	return c


func _sfx_busy_count() -> int:
	var n := 0
	for c in _all_channels:
		if not c.is_music and not _idle.has(c):
			n += 1
	return n


func _release(c: Channel) -> void:
	if c != null and not _idle.has(c):
		c.stop()
		_idle.append(c)


# 对应 Sound.play(startTimeMs, loops, SoundTransform)。start_ms 毫秒。
func _start(stream: AudioStream, start_ms: float, loop: bool, volume: float, pan_: float, music: bool) -> Channel:
	var c := _acquire(music)
	if c == null:
		return null
	c.is_music = music
	c.looping = loop
	c.volume = volume
	c.pan = pan_
	c.player.stream = stream
	c.player.play(start_ms / 1000.0)
	return c


func init_sounds() -> void:
	menu_music_position = 0
	map_music_position = 0
	battle_music_position = 0
	d_channels = {}
	var _loc1_ = SoundLibrary.inst
	a_cur_buttons_rover = []
	a_cur_channels_rover = []
	o_types = {}
	o_types_max = {}
	for pair in [
		[_loc1_.ARCHER_PULL, 2], [_loc1_.ARCHER_SHOOT, 4], [_loc1_.SWORD_SWOOSH, 4],
		[_loc1_.HEAVY_SWORD, 4], [_loc1_.AXE, 3], [_loc1_.MAGE_STRIKE, 4],
		[_loc1_.IMPACT, 4], [_loc1_.ARROW_IMPACT, 3], [_loc1_.ROVER, 2],
		[_loc1_.CREATURE_ATTACK, 2], [_loc1_.HEAL_CAST, 2], [_loc1_.KAMIKAZE, 3],
		[_loc1_.CRITICAL, 2], [_loc1_.STUNNED, 2], [_loc1_.BLOCK, 2],
		[_loc1_.WIN_MUSIC, 1], [_loc1_.BIG_CREATURE_ATTACK, 2], [_loc1_.ARROW_GROUND, 2],
		[_loc1_.SUMMON, 1], [_loc1_.HEAL_CAST_FRIENDS, 2], [_loc1_.MONSTERS, 1],
		[_loc1_.SELECTION, 2], [_loc1_.ZOMBIE_WEAKNESS, 1], [_loc1_.BONEBREAK, 1],
		[_loc1_.BTN_DENY, 1],
	]:
		o_types[pair[0]] = 0
		o_types_max[pair[0]] = pair[1]


# play(param1 声音, param2 循环, param3 起点秒, param4 音量, param5 单位 x, param6 分类)
func play(param1: AudioStream, param2: bool = false, param3: float = 0, param4: float = 1, param5: float = 350, param6: String = "") -> Channel:
	pan = (param5 / 350.0 - 1) * 0.5
	res = null
	if sound_on:
		if param6 != "":
			# 原版 oTypes[未登记键] 为 undefined，比较为 false，会继续并写入 NaN；这里按未登记即无上限处理。
			if o_types.has(param6) and o_types[param6] >= o_types_max[param6]:
				return null
			if o_types.has(param6):
				o_types[param6] += 1
		param3 *= 1000
		st = [param4, pan]  # SoundTransform(volume, pan)
		ch = _start(param1, param3, param2, param4, pan, false)
		if ch != null:
			sounds[param1] = ch
			res = ch
			ch.type_key = param6
			d_channels[ch] = param6
			ch.sound_complete.connect(sound_completed)
		# 原版行为：声道耗尽时 Sound.play 返回 null，分类计数已先加 1 且不回退（计数泄漏，该类可能因此永久静音）。
		# 此处不回退，忠实保持。
	return res


# 对应 SOUND_COMPLETE 回收。
func sound_completed(param1: Channel) -> void:
	param1.sound_complete.disconnect(sound_completed)
	var _loc3_: String = d_channels.get(param1, "")
	if o_types.has(_loc3_):
		o_types[_loc3_] -= 1
	d_channels.erase(param1)
	_release(param1)


func play_music(param1: AudioStream, param2: bool = false, param3: float = 0, param4: float = 1, param5: float = 0, param6: bool = false) -> void:
	if music_channel != null and music_channel.sound_complete.is_connected(music_completed):
		music_channel.sound_complete.disconnect(music_completed)
	while music_on:
		if current_music == param1:
			break
		current_music = param1
		param3 *= 1000
		if not param6:
			music_channel = _start(param1, param3, param2, 0.0, param5, true)
		else:
			music_channel = _start(param1, param3, false, 0.0, param5, true)
			cur_soundclass = param1
			music_channel.sound_complete.connect(music_completed)
		sounds[param1] = music_channel
		_tween_volume(music_channel, param4, 0.5, Callable())
		break


func music_completed(_channel: Channel = null) -> void:
	current_music = null
	play_music(cur_soundclass, true, 0, 0.24)
	if music_channel != null and music_channel.sound_complete.is_connected(music_completed):
		music_channel.sound_complete.disconnect(music_completed)


# TweenLite.to(channel, 0.5, {volume: v, onComplete: ...})
func _tween_volume(channel: Channel, target: float, duration: float, on_complete: Callable) -> void:
	if channel == null:
		return
	if _stop_tweens.has(channel) and is_instance_valid(_stop_tweens[channel]):
		_stop_tweens[channel].kill()
	var tw := create_tween()
	_stop_tweens[channel] = tw
	tw.tween_property(channel, "volume", target, duration)
	if on_complete.is_valid():
		tw.tween_callback(on_complete)


func unpause_music(param1: AudioStream) -> void:
	var _loc2_ := 0.25
	var _loc3_ := 0.0
	var lib := SoundLibrary.inst
	if param1 == lib.get_sound(lib.MENU_MUSIC):
		_loc3_ = menu_music_position / 1000.0
	elif param1 == lib.get_sound(lib.BATTLE_MUSIC):
		_loc3_ = battle_music_position / 1000.0
		_loc2_ = 0.23
	else:
		_loc3_ = map_music_position / 1000.0
	play_music(param1, true, _loc3_, _loc2_, 0, true)


func pause_music() -> void:
	map_music_position = 0
	battle_music_position = 0
	menu_music_position = 0
	if current_music != null:
		var _loc1_: Channel = sounds.get(current_music)
		if _loc1_ != null:
			var lib := SoundLibrary.inst
			if current_music == lib.get_sound(lib.MENU_MUSIC):
				menu_music_position = _loc1_.position + 500
			elif current_music == lib.get_sound(lib.BATTLE_MUSIC):
				battle_music_position = _loc1_.position + 500
			else:
				map_music_position = _loc1_.position + 500
		stop_music(current_music)


func stop_channel(param1: Channel) -> void:
	param1.stop()
	_stop_tweens.erase(param1)
	_release(param1)


func stop_music(param1: AudioStream) -> void:
	if current_music == param1:
		var _loc2_: Channel = sounds.get(current_music)
		if _loc2_ != null:
			_tween_volume(_loc2_, 0.0, 0.5, stop_channel.bind(_loc2_))
	current_music = null


# 原版 mute(Class, Boolean)：param1 为声音键（此处为 AudioStream）。
func mute(param1: AudioStream, param2: bool = false) -> void:
	var _loc3_: Channel = sounds.get(param1)
	if _loc3_ == null:
		return
	if param2:
		sound_transforms[param1] = _loc3_.volume
		muted[param1] = true
		_loc3_.volume = 0.0
	else:
		muted.erase(param1)
		_loc3_.volume = sound_transforms.get(param1, 1.0)


# SoundMixer.soundTransform = new SoundTransform(on ? 1 : 0)
func on(param1: bool) -> void:
	sound_on = param1
	AudioServer.set_bus_mute(0, not param1)
	AudioServer.set_bus_volume_db(0, 0.0)


func play_rover(param1: AudioStream, param2: float, param3: float, param4: Object) -> Channel:
	var _loc5_: Channel = null
	if sound_on:
		var _loc6_ := a_cur_buttons_rover.find(param4)
		if _loc6_ < 0:
			param2 *= 1000
			var _loc8_ := _start(param1, param2, false, param3, 0.0, false)
			if _loc8_ != null:
				sounds[param1] = _loc8_
				_loc5_ = _loc8_
				a_cur_buttons_rover.append(param4)
				a_cur_channels_rover.append(_loc8_)
				_loc8_.sound_complete.connect(sound_completed_rover)
	return _loc5_


# 原版先读 storedData.mainParams；此处由调用者传入 {music, sound}（storedData 尚未移植）。
func init_sounds_first(main_params: Dictionary = {}) -> void:
	inst = self
	music_on = main_params.get("music", true)
	sound_on = main_params.get("sound", true)
	init_sounds()


func sound_completed_rover(param1: Channel) -> void:
	var _loc3_ := a_cur_channels_rover.find(param1)
	if _loc3_ >= 0:
		a_cur_channels_rover.remove_at(_loc3_)
		a_cur_buttons_rover.remove_at(_loc3_)
	param1.sound_complete.disconnect(sound_completed_rover)
	_release(param1)
