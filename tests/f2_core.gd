extends SceneTree
# F2：核心/服务/存档/关卡/技能模块与原版 AS3 逐条核对后修复项的确定性测试。
# 覆盖：GameUniverse.aSpecials（initOnce）、loadLevel 的开场关卡路径、specBackStab.checkWave 的 sens.height/2 偏移、
# specSummonSkeletons.summoned 的 RNG 调用顺序（每次施法恰好 5 次 randRange(1,16)）、callSummonedEnemy 的随机数顺序与难度修正、
# bonusCalculator 数据表抽样、extDataManager 的 26 份 XML、Array.sort(randomSort) 近似的消耗约定。
var checks := 0
var failures: Array = []
var fx_log: Array = []  # [类名, x, y]
var snd: FakeSounds = null


## 单位桩：记录 stunned / 目标设置，不依赖真实的战斗逻辑。
class Unit extends LivingObject:
	var calls: Array = []

	func _init() -> void:
		sprite = Sprite2D.new()
		sens = Sprite2D.new()
		sens_height = 40.0
		_health = 100
		_cur_health = 100

	func stunned(param1: int) -> void:
		calls.append(["stunned", param1])

	func modify_first_point() -> void:
		calls.append(["modify_first_point"])

	func set_target(param1: LivingObject, _param2: bool = true) -> void:
		calls.append(["set_target", param1])


## 施法者桩（SpecSummonSkeletons.me 是无类型的 mageClass）。
class FakeMage extends Node2D:
	var get_view_direction: float = 1.0
	var get_level: int = 2
	var get_cur_target: LivingObject = null

	func get_route_number() -> int:
		return 3


class FakeSounds extends Sounds:
	func play(_param1: AudioStream, _param2: bool = false, _param3: float = 0, _param4: float = 1, _param5: float = 350, _param6: String = "") -> Sounds.Channel:
		return null


class FakeUni extends GameUniverse:
	var loaded: Array = []  # [kind, level, route, point, unit]

	func load_enemy(param1: int, param2: int, param3: int, param4: Variant = null) -> LivingObject:
		var u := Unit.new()
		loaded.append([param1, param2, param3, param4, u])
		u.kind = param1
		return u


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
	setup()
	test_a_specials()
	test_level_template_paths()
	test_back_stab_wave()
	test_summon_skeletons()
	test_call_summoned_enemy()
	test_random_sort_contract()
	test_bonus_calculator()
	test_ext_data_manager()
	GameUniverse.free_statics()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func setup() -> void:
	StoredData.test_wipe()
	StoredData.init()
	SoundLibrary.new().init()
	snd = FakeSounds.new()
	Sounds.inst = snd
	GlobalData.new()
	Engine.set_meta("f2_fx_log", fx_log)
	for v in ["StunnedSmallWaveVisual", "SummonSingleVisual", "SummonKingVisual"]:
		var s := GDScript.new()
		s.source_code = "extends %s\nfunc added_to_stage(param1: float, param2: float, _param3: Callable = Callable(), _param4: Variant = null, _param5: bool = false, _param6: bool = false) -> void:\n\tEngine.get_meta(\"f2_fx_log\").append([\"%s\", param1, param2])\n" % [v, v]
		check(s.reload() == OK, "fake visual script for %s compiles" % v)
		var cls: GDScript = ProjectSettings.get_global_class_list().filter(func(d): return d["class"] == v).map(func(d): return load(d["path"]))[0]
		cls.set("cached_data", SimpleCache.new(s, 8))


## 固定种子后连续取 n 个 rand，再恢复同一种子，供断言“原版公式下的结果”。
func draws(seed_value: int, n: int) -> Array:
	RWRandom.set_seed(seed_value)
	var out: Array = []
	for i in n:
		out.append(RWRandom.rand())
	RWRandom.set_seed(seed_value)
	return out


# ---------------------------------------------------------------- gameUniverse.initOnce / aSpecials

func test_a_specials() -> void:
	GameUniverse.init_once()
	var a: Array = GameUniverse.a_specials
	check(a.size() == 36, "aSpecials has 36 entries (got %d)" % a.size())
	check(a[StoredData.A_WEAKNESS] == null, "aSpecials[A_WEAKNESS] is null (original literal has null at 33)")
	var expect := {
		StoredData.A_BACKSTAB: SpecBackStab, StoredData.A_BETRAY: SpecBetray, StoredData.A_BLOCK: SpecBlock,
		StoredData.A_CURSE_BLACK: SpecCurse, StoredData.A_BREAKARROW: SpecBreakArrows,
		StoredData.A_COLLECTMONEY: SpecCollectMoney, StoredData.A_CORRUPT: SpecCorrupt, StoredData.A_CRIT: SpecCrit,
		StoredData.A_CRITRANGED: SpecCritRanged, StoredData.A_CURSEBLESS: SpecCurseBless,
		StoredData.A_FIREHITSPLASH: SpecFireHitSplash, StoredData.A_FLASH: SpecFlash, StoredData.A_FLEE: SpecFlee,
		StoredData.A_HARMRESIST: SpecHarmResist, StoredData.A_HEADSHOT: SpecHeadShot, StoredData.A_HIDE: SpecHide,
		StoredData.A_ICE: SpecIce, StoredData.A_MASSHEAL: SpecMassHeal, StoredData.A_MASSSTUN: SpecMassStun,
		StoredData.A_METHEOR: SpecMetheor, StoredData.A_PARRY: SpecParry, StoredData.A_WEAKSPOT: SpecWeakSpot,
		StoredData.A_RESURRECT: SpecRessurect, StoredData.A_ROUNDATTACK: SpecRoundAttack,
		StoredData.A_ENCHANT: SpecEnchantWeapon, StoredData.A_SILENCE: SpecSilence, StoredData.A_SLOW: SpecSlow,
		StoredData.A_STRONGHEAL: SpecStrongHeal, StoredData.A_STUN: SpecStun, StoredData.A_SUPPRESS: SpecSuppress,
		StoredData.A_TAUNT: SpecTaunt, StoredData.A_VAMPIRIZM: SpecVampirizm, StoredData.A_SELFDESTRUCT: SpecSelfDestruct,
		StoredData.A_POISON_THIEF: SpecPoisonRogue, StoredData.A_MISS_ASSASIN: SpecMissAssasin,
	}
	for idx: int in expect:
		var spec: Variant = a[idx]
		check(spec != null and spec.get_script() == expect[idx], "aSpecials[%d] is %s" % [idx, expect[idx].get_global_name()])
	# 只读说明原型：new specX(true) 读存档等级，cur_level_params 可直接用于升级面板。
	check((a[StoredData.A_BACKSTAB] as SpecialTemplate).cur_level_params().begins_with("Ability locked"), "fresh save -> backstab prototype is locked")


# ---------------------------------------------------------------- gameUniverse.loadLevel

func test_level_template_paths() -> void:
	check(GameUniverse._new_level_template(-2) is LevelIntro, "loadLevel(-2) creates levelIntro")
	check(GameUniverse._new_level_template(0) is Level1, "loadLevel(0) creates level1")
	check(GameUniverse._new_level_template(23) is Level24, "loadLevel(23) creates level24")
	check(GameUniverse._new_level_template(-2).level_xml_path == "data/levels/levelIntro.xml", "levelIntro xml path")


# ---------------------------------------------------------------- specBackStab.checkWave

func test_back_stab_wave() -> void:
	fx_log.clear()
	var bs := SpecBackStab.new(false)
	bs.reset_counter()
	for i in bs.time_until_update:
		bs.update()
	var u := Unit.new()
	u.position = Vector2(50, 50)
	u.sens.position = Vector2(3, -20)
	bs.check_wave(u)
	check(fx_log.size() == 1 and fx_log[0][0] == "StunnedSmallWaveVisual", "backstab checkWave spawns a small wave")
	# 原版：addedToStage(sens.x, sens.y + sens.height / 2, ...)
	check(fx_log[0][1] == 3.0 and fx_log[0][2] == -20.0 + 40.0 / 2.0, "backstab wave at sens.y + sens.height/2 (got %s)" % [fx_log[0]])


# ---------------------------------------------------------------- specSummonSkeletons.summoned

func test_summon_skeletons() -> void:
	var uni := FakeUni.new()
	uni.s_lib = SoundLibrary.inst
	var sk := SpecSummonSkeletons.new()
	for facing: float in [1.0, -1.0]:
		uni.loaded.clear()
		var me := FakeMage.new()
		me.position = Vector2(200, 300)
		me.get_view_direction = facing
		var target := Unit.new()
		me.get_cur_target = target
		sk.me = me
		var want := draws(777, 5)
		RWRandom.set_seed(777)
		sk.summoned()
		check(uni.loaded.size() == 5, "summoned spawns 5 skeletons (facing %s)" % facing)
		# 原版两组各 5 段重复代码，只会执行其中一组：恰好 5 次 randRange(1,16)，按生成顺序依次消耗。
		var after := RWRandom.get_state()
		RWRandom.set_seed(777)
		for i in 5:
			RWRandom.rand()
		check(RWRandom.get_state() == after, "summoned consumes exactly 5 rand (facing %s)" % facing)
		var offsets: Array
		if facing > 0:
			offsets = [Vector2(-26, 9), Vector2(16, 9), Vector2(20, -11), Vector2(-35, -13), Vector2(-8, -21)]
		else:
			offsets = [Vector2(26, 10), Vector2(-16, 10), Vector2(-20, -10), Vector2(35, -12), Vector2(8, -20)]
		for i in 5:
			var row: Array = uni.loaded[i]
			var unit: Unit = row[4]
			check(row[0] == LivingObject.UNDEAD_SKELETON and row[1] == 2 and row[2] == 3, "skeleton %d kind/level/route" % i)
			check(row[3] == Vector2(200, 300) + offsets[i], "skeleton %d spawn point %s (got %s)" % [i, Vector2(200, 300) + offsets[i], row[3]])
			var names: Array = unit.calls.map(func(c): return c[0])
			check(names == ["modify_first_point", "set_target", "stunned"], "skeleton %d call order %s" % [i, names])
			var stun: int = unit.calls[2][1]
			check(stun == int(floor(want[i] * 16)) + 1, "skeleton %d stunned(randRange(1,16)) = %d (got %d)" % [i, int(floor(want[i] * 16)) + 1, stun])
			check(unit.sprite.scale.x == int(facing), "skeleton %d inherits view direction" % i)
		me.free()
		target.free()
	sk = null
	uni.free()


# ---------------------------------------------------------------- gameUniverse.callSummonedEnemy

func test_call_summoned_enemy() -> void:
	var uni := FakeUni.new()
	uni.s_lib = SoundLibrary.inst
	var victim := Unit.new()
	victim.friendly = true
	victim.position = Vector2(300, 200)
	uni.a_all_units = [victim]
	# 难度修正：普通不变；中等（2）且 <3 时 +1；高（3）固定 3。
	for case in [[1, 1, 1], [2, 1, 2], [2, 3, 3], [3, 1, 3], [3, 2, 3]]:
		uni.dif_num = case[0]
		uni.loaded.clear()
		fx_log.clear()
		var want := draws(4242, 2)
		RWRandom.set_seed(4242)
		uni.call_summoned_enemy(LivingObject.UNDEAD_ZOMBIE, case[1], 2)
		var sx := int(300 - 60 + 120 * want[0])
		var sy := int(200 - 60 + 120 * want[1])
		check(uni.loaded.size() == 1, "callSummonedEnemy loads one unit (dif %d)" % case[0])
		var row: Array = uni.loaded[0]
		check(row[1] == case[2], "dif %d level %d -> %d (got %d)" % [case[0], case[1], case[2], row[1]])
		check(row[2] == 2 and row[3] == Vector2(sx, sy), "route 2, spawn point rand(x) then rand(y): %s (got %s)" % [Vector2(sx, sy), row[3]])
		var calls: Array = (row[4] as Unit).calls
		check(calls[0][0] == "modify_first_point" and calls[1] == ["stunned", 90], "ordinary summon: modifyFirstPoint then stunned(90)")
		check(fx_log.size() == 1 and fx_log[0][0] == "SummonSingleVisual" and fx_log[0][1] == float(sx), "single summon visual at the spawn point")
		check(not (row[4] as Unit).visible, "summoned unit hidden until the visual fires")
	# 吸血鬼王：stunned(15) + summonKingVisual
	uni.dif_num = 1
	uni.loaded.clear()
	fx_log.clear()
	RWRandom.set_seed(9)
	uni.call_summoned_enemy(LivingObject.UNDEAD_VAMPIRE_KING, 3, 1)
	var king: Unit = uni.loaded[0][4]
	check(king.calls[1] == ["stunned", 15] and fx_log[0][0] == "SummonKingVisual", "vampire king: stunned(15) with king visual")
	# 没有敌人（这里指玩家方单位）时什么都不做，也不消耗随机数
	uni.a_all_units = []
	uni.loaded.clear()
	RWRandom.set_seed(5)
	uni.call_summoned_enemy(LivingObject.UNDEAD_ZOMBIE, 1, 1)
	check(uni.loaded.is_empty() and RWRandom.get_state() == 5, "no targets -> no spawn, no rand consumed")
	uni.a_all_units = []
	victim.free()
	uni.free()


# ---------------------------------------------------------------- Array.sort(Utility.randomSort)

# 已知近似（docs/verification.md）：Flash 的排序算法调用比较函数的次数无法复现，这里是插入排序。
# 约定：n 个元素最少 n-1 次比较；每次比较恰好消耗一次 rand；rand < 0.5 返回 -1（不交换），否则 1（交换）。
func test_random_sort_contract() -> void:
	var one := [1]
	RWRandom.set_seed(11)
	GameUniverse._random_sort(one)
	check(RWRandom.get_state() == 11 and one == [1], "sort of a single element consumes no rand")
	for seed_value in [3, 12345, 99991]:
		var r: float = draws(seed_value, 1)[0]
		var two := ["a", "b"]
		GameUniverse._random_sort(two)
		check(two == (["b", "a"] if r >= 0.5 else ["a", "b"]), "2-element randomSort follows the first rand (seed %d, r=%f)" % [seed_value, r])
		var after := RWRandom.get_state()
		RWRandom.set_seed(seed_value)
		RWRandom.rand()
		check(RWRandom.get_state() == after, "2-element randomSort consumes exactly one rand")


# ---------------------------------------------------------------- bonusCalculator

func test_bonus_calculator() -> void:
	var bonus: Array = StoredData.local_game_data[StoredData.NUMPAN_UNIT_BONUSES]
	# 骑士：伤害槽 3 级 -> 伤害 4、穿甲 0.15；生命槽 3 级 -> 生命 40、护甲 0.15（原版 case FR_KNIGHT）
	bonus[0] = 3
	bonus[1] = 3
	var k := BonusCalculator.calculate_bonus(LivingObject.FR_KNIGHT)
	check(k["bonus_damage"] == 4.0 and k["bonus_armor_pierce"] == 0.15 and k["bonus_hp"] == 40.0 and k["bonus_armor"] == 0.15, "knight level 3/3 bonus %s" % [k])
	# 战士 2 级：伤害 1 + 穿甲 0.1；生命 2 级：生命 10 + 护甲 0.1
	bonus[0] = 2
	bonus[1] = 2
	var w := BonusCalculator.calculate_bonus(LivingObject.FR_WARRIOR)
	check(w["bonus_damage"] == 1.0 and w["bonus_armor_pierce"] == 0.1 and w["bonus_hp"] == 10.0 and w["bonus_armor"] == 0.1, "warrior level 2/2 bonus %s" % [w])
	# 刺客 3 级生命：20 + 移速 0.15（原版 while(_loc12_ == 3) 与 if 等价）
	bonus[6] = 0
	bonus[7] = 3
	var a := BonusCalculator.calculate_bonus(LivingObject.FR_ASSASIN)
	check(a["bonus_damage"] == 0.0 and a["bonus_hp"] == 20.0 and a["bonus_move_speed"] == 0.15, "assassin hp level 3 bonus %s" % [a])
	# 弩手 3 级伤害：4、穿甲 0.2（原版独有的 0.2）
	bonus[2] = 3
	bonus[3] = 0
	var c := BonusCalculator.calculate_bonus(LivingObject.FR_CROSSBOW)
	check(c["bonus_damage"] == 4.0 and c["bonus_armor_pierce"] == 0.2, "crossbow damage level 3 bonus %s" % [c])
	# 不在表内的兵种全部为 0
	var n := BonusCalculator.calculate_bonus(LivingObject.FR_KING)
	check(n["bonus_damage"] == 0.0 and n["bonus_hp"] == 0.0, "king has no bonus")
	bonus.fill(0)


# ---------------------------------------------------------------- extDataManager.init

func test_ext_data_manager() -> void:
	var m := ExtDataManager.new()
	m.init()
	for i in range(-2, 24):
		if i == -1:
			continue
		check(m.get_level_xml(i) != null, "extDataManager level xml for %d" % i)
	check(m.get_units_xml() != null, "extDataManager units xml")
