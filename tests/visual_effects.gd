extends SceneTree
# P3-F：game/projectiles/ 特效类。逐个创建，核对符号、帧数/命令码、播放结束后回池。
var checks := 0
var failures: Array = []
var skipped: Array = []

# [类, Main.as 中的符号名]。arrow_ex / small_fireball_ex / visuals_template 不在本测试范围。
var classes: Array = [
	[BackstabVisual, "backstabAni"], [BetrayVisual, "betrayEffect"], [BlessVisual, "blessEffect"],
	[BlockedVisual, "blockMc"], [BloodEx, "blood"], [BrokenArrowVisual, "breakArrowAni"],
	[CallConfusionVisual, "callConfusionAni"], [CantMoveVisual, "cantWithdrawAni"], [CoinVisual, "rogueMoneyAni"],
	[CorpseExplosionVisual, "corpseExpEffect"], [CorruptVisual, "corruptAni"], [CritVisual, "critAni"],
	[CurseVisual, "curseEffect"], [EnchantVisual, "enchantWeaponEff"], [FbSmokeVisual, "fireballSmoke"],
	[FlashVisual, "flashAni"], [FreeMoveVisual, "freeMoveAni"], [GitGlowVisual, "hitGlowEffect"],
	[GroundFlagAttack, "gotoFlagPlaced"], [GroundFlagHeal, "healFlagPlaced"], [GroundFlagMove, "moveFlagPlaced"],
	[HarmResistVisual, "harmResistAni"], [HeadShotEffectVisual, "headShotEffect"], [HealEffectEx, "healEffect"],
	[HoldGroundVisual, "holdGroundAni"], [MissVisual, "missEffect"], [ParryVisual, "parryAni"],
	[PoisonEffectVisual, "poisonAni"], [RegenVisual, "trollRegenEffect"], [RessurectEffectVisual, "ressurectEffectVis"],
	[RockFallingVisual, "rockFalling"], [RoundAttackEffectVisual, "roundAttackedEffectVisual"],
	[RoundAttackVisual, "roundAttackAni"], [SilencedVisual, "silencedAni"], [SlowEffectVisual, "slowMc"],
	[StrongHealVisual, "strongHealAni"], [StunnedEffectVisual, "stunnedEffect"],
	[StunnedSmallWaveVisual, "stunWaveAni"], [StunnedWaveVisual, "shockWave"], [SummonKingVisual, "summinKingAni"],
	[SummonSingleVisual, "summonSingleAni"], [SummonVisual, "summonAni"], [SuppressVisual, "suppressedAni"],
	[TauntVisual, "tauntAni"], [TauntedVisual, "tauntedAni"], [UnitKilledVisual, "unitKilledAni"],
	[WeakSpotEffectVisual, "weakSpotAni"], [WeaknessVisual, "zombWeaknessEffect"],
	[GroundDefFlag, "defendFlagAni"], [IceVisual, "iceAni"],
]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content := root.get_node("Content")
	if not content.isolated_profile:
		quit(2)
		return
	var universe := GameUniverse.new()
	GameUniverse.inst = universe
	root.add_child(universe)
	for entry in classes:
		test_class(entry[0], entry[1])
	test_flee()
	GameUniverse.inst = null
	universe.queue_free()
	print(JSON.stringify({"checks": checks, "failures": failures, "skipped": skipped}))
	quit(0 if failures.is_empty() else 1)

func test_class(cls: Script, sym: String) -> void:
	var tag: String = str(cls.get_global_name())
	var symbols: Dictionary = root.get_node("Content").symbols
	check(symbols.has(sym), "%s: symbol %s exists" % [tag, sym])
	if not symbols.has(sym):
		return
	var expected := BmpFrames.from_symbol(sym)
	check(expected != null and expected.num_frames > 0, "%s: BmpFrames loads" % tag)
	if expected == null:
		return
	cls.init_resources()
	check(cls.bmp_data == expected, "%s: bmp_data is the symbol's BmpFrames (cached)" % tag)
	check(cls.bmp_data.frame_commands.size() == cls.bmp_data.num_frames, "%s: frame_commands size == frames" % tag)
	var rec: Variant = _commands().get(str(symbols[sym]))
	if rec is Dictionary:
		check(int(rec["frames"]) == cls.bmp_data.num_frames, "%s: frames match anim_commands.json" % tag)
		check(Array(cls.bmp_data.frame_commands) == rec["commands"], "%s: commands match anim_commands.json" % tag)
	var cache: SimpleCache = cls.cached_data
	var pool_before: int = cache._current_index
	var v: VisualsTemplate = cache.get_data()
	check(is_instance_of(v, cls) and v.bmp_list == expected, "%s: instance uses bmp_data" % tag)
	check(cache._current_index == pool_before - 1, "%s: get_data takes from pool" % tag)
	if cls == IceVisual:
		skipped.append("IceVisual: playback needs a LivingObject enemy; creation checked only")
		cache.set_data(v)
		return
	if cls == GroundDefFlag:
		skipped.append("GroundDefFlag: returns to pool via alpha tween after 60 frames of hold; creation checked only")
		cache.set_data(v)
		return
	v.added_to_stage(10, 20)
	check(v.position == Vector2(10, 20), "%s: positioned" % tag)
	if cls in [GroundFlagAttack, GroundFlagHeal, GroundFlagMove]:
		check(v.is_map_flag, "%s: is_map_flag" % tag)
		check(not v.visible and v.play_head_stance == VisualsTemplate.STOPPED, "%s: starts hidden/stopped" % tag)
	var limit := 2000
	while GameUniverse.inst.a_effects.has(v) and limit > 0:
		GameUniverse.inst.update_effects()
		limit -= 1
	check(limit > 0, "%s: finishes" % tag)
	check(cache._current_index == pool_before, "%s: back in pool after playback" % tag)

func test_flee() -> void:
	# 原版 fleeVisual 从未被 Main 加载，仅检查类存在且 init_resources 为空操作。
	FleeVisual.init_resources()
	check(FleeVisual.bmp_data == null, "FleeVisual: never loaded in original")

var _cmd: Dictionary
func _commands() -> Dictionary:
	if _cmd.is_empty():
		_cmd = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim_commands.json"))
	return _cmd
