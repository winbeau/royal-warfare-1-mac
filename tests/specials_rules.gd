extends SceneTree
# P3-E：技能类（game/specials/）的规则测试。
# 覆盖：冷却帧数与等级参数表、玩家读存档/敌方恒 2 级、锁定与外部解锁、can_use_special 的帧数边界、
# 若干技能的触发效果（固定 RWRandom 种子）、箭雨的冷却与投放。
# 视觉特效、音效、单位与 GameUniverse 都用最小桩替换，不依赖尚未完成的类。
var checks := 0
var failures: Array = []
var fx_log: Array = []  # [类名, x, y, 目标]
var uni: GameUniverse = null
var snd: FakeSounds = null


## 单位桩：只记录技能施加的 buff/penalty 与伤害。
class Unit extends LivingObject:
	var calls: Array = []
	var casting := 0
	var turned_to: LivingObject = null

	func _init() -> void:
		sprite = Sprite2D.new()
		sens = Sprite2D.new()
		sens_height = 40.0
		_health = 100
		_cur_health = 100
		real_friendly = false

	func stunned(param1: int) -> void:
		calls.append(["stunned", param1])

	func slowed(param1: int) -> void:
		calls.append(["slowed", param1])

	func poisoned(param1: int, param2: int) -> void:
		calls.append(["poisoned", param1, param2])
		_is_poisoned = true

	func cursed(param1: int, param2: float) -> void:
		calls.append(["cursed", param1, param2])
		is_cursed = true

	func trapped_in_ice(param1: int, param2: int) -> void:
		calls.append(["trapped_in_ice", param1, param2])
		is_trapped_in_ice = true

	func blessed(param1: int, param2: float) -> void:
		calls.append(["blessed", param1, param2])

	func weak_spotted(param1: float, param2: float) -> void:
		calls.append(["weak_spotted", param1, param2])
		has_weak_spot = true

	func healed_effect() -> void:
		calls.append(["healed_effect"])

	func bring_damage(param1: int, param2: LivingObject, param3: bool = false, param4: bool = true) -> void:
		calls.append(["bring_damage", param1, param2, param3, param4])
		_cur_health -= param1

	func set_casting_stance() -> void:
		casting += 1

	func turn_to_unit(param1: LivingObject) -> void:
		turned_to = param1


class FakeSounds extends Sounds:
	var played: Array = []

	func play(param1: AudioStream, _param2: bool = false, _param3: float = 0, param4: float = 1, _param5: float = 350, param6: String = "") -> Sounds.Channel:
		played.append([param1, param4, param6])
		return null


class FakeUni extends GameUniverse:
	var arrows: Array = []

	func add_arrow(param1: ArrowEx) -> void:
		arrows.append(param1)


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
	test_tables()
	test_level_rules()
	test_cooldown_frames()
	test_triggers()
	test_arrow_swarm()
	GameUniverse.free_statics()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func setup() -> void:
	StoredData.test_wipe()
	var abils: Array = []
	abils.resize(36)
	abils.fill(0)
	StoredData.local_game_data = [[], [], abils]
	var lib := SoundLibrary.new()
	lib.init()
	snd = FakeSounds.new()
	Sounds.inst = snd
	uni = FakeUni.new()
	GlobalData.new()
	# 把所有用到的视觉特效的对象池换成记录用的桩（added_to_stage 只记录，不触碰 GameUniverse）
	var visuals := ["StunnedEffectVisual", "StunnedSmallWaveVisual", "StunnedWaveVisual", "BlockedVisual", "ParryVisual",
		"RoundAttackEffectVisual", "CurseVisual", "IceVisual", "PoisonEffectVisual", "BackstabVisual", "HealEffectEx",
		"WeakSpotEffectVisual", "StrongHealVisual", "GitGlowVisual", "FlashVisual", "BlessVisual", "HarmResistVisual",
		"MissVisual", "CritVisual", "HeadShotEffectVisual", "CorruptVisual", "TauntedVisual", "TauntVisual"]
	Engine.set_meta("fx_log", fx_log)
	for v in visuals:
		var s := GDScript.new()
		s.source_code = "extends %s\nfunc added_to_stage(param1: float, param2: float, param3: Callable = Callable(), param4: Variant = null, param5: bool = false, param6: bool = false) -> void:\n\tEngine.get_meta(\"fx_log\").append([\"%s\", param1, param2, param4])\nfunc set_counter(_a, _b) -> void:\n\tpass\n" % [v, v]
		var err := s.reload()
		check(err == OK, "fake visual script for %s compiles" % v)
		if err == OK:
			var cls: GDScript = ProjectSettings.get_global_class_list().filter(func(d): return d["class"] == v).map(func(d): return load(d["path"]))[0]
			cls.set("cached_data", SimpleCache.new(s, 4))


func make_unit(x: float = 100, y: float = 100, friendly: bool = false) -> Unit:
	var u := Unit.new()
	u.position = Vector2(x, y)
	u.friendly = friendly
	u.real_friendly = friendly
	return u


func set_save(index: int, value: int) -> void:
	(StoredData.local_game_data[StoredData.NUMPAN_ABILS] as Array)[index] = value


func clear_save() -> void:
	var a: Array = StoredData.local_game_data[StoredData.NUMPAN_ABILS]
	a.fill(0)


## 冷却秒数与参数表：[脚本, 存档下标, 冷却秒[3], {属性名: [3 个等级的期望值]}]
func test_tables() -> void:
	var rows := [
		[SpecStun, StoredData.A_STUN, [24, 19, 14], {"max_stun_time": [60, 90, 120]}],
		[SpecBlock, StoredData.A_BLOCK, [8, 6, 4], {}],
		[SpecParry, StoredData.A_PARRY, [9, 7, 5], {"crit_chance": [0.2, 0.2, 0.2]}],
		[SpecMassHeal, StoredData.A_MASSHEAL, [18, 14, 10], {}],
		[SpecCurse, StoredData.A_CURSE_BLACK, [28, 24, 20], {"area": [60, 75, 90], "max_curse_time": [180, 240, 300], "cur_curse_bless_power": [0.25, 0.35, 0.45]}],
		[SpecIce, StoredData.A_ICE, [34, 28, 23], {"damage": [1, 2, 2], "cur_freeze_time": [120, 210, 300]}],
		[SpecPoisonRogue, StoredData.A_POISON_THIEF, [26, 22, 18], {"cur_poison_strength": [3, 5, 8], "cur_timeto_poison": [300, 300, 300]}],
		[SpecBackStab, StoredData.A_BACKSTAB, [20, 17, 15], {"cur_damag_modificator": [3, 5, 7]}],
		[SpecBetray, StoredData.A_BETRAY, [70, 65, 60], {"cur_time_to_possess": [360, 600, 780]}],
		[SpecBreakArrows, StoredData.A_BREAKARROW, [18, 16, 14], {"area": [100, 110, 120], "action_time": [210, 270, 330]}],
		[SpecCorrupt, StoredData.A_CORRUPT, [24, 20, 16], {"current_corrupt": [0.3, 0.5, 0.7]}],
		[SpecCurseBless, StoredData.A_CURSEBLESS, [40, 35, 30], {"area": [100, 120, 140], "max_bless_time": [300, 360, 420]}],
		[SpecEnchantWeapon, StoredData.A_ENCHANT, [30, 26, 22], {"bonus_ap": [2.0, 2.3, 2.5]}],
		[SpecFlash, StoredData.A_FLASH, [46, 43, 40], {"damage": [70, 80, 90], "num_flash": [1, 2, 3]}],
		[SpecHarmResist, StoredData.A_HARMRESIST, [40, 33, 25], {"max_harm_resist_time": [180, 240, 300]}],
		[SpecHeadShot, StoredData.A_HEADSHOT, [24, 19, 14], {"cur_damag_modificator": [4, 5, 6]}],
		[SpecMassStun, StoredData.A_MASSSTUN, [22, 17, 12], {"max_stun_time": [60, 90, 120]}],
		[SpecMetheor, StoredData.A_METHEOR, [40, 35, 30], {"cur_damage": [100, 130, 160], "area": [60, 65, 70]}],
		[SpecRessurect, StoredData.A_RESURRECT, [140, 120, 100], {}],
		[SpecRoundAttack, StoredData.A_ROUNDATTACK, [20, 16, 12], {}],
		[SpecSlow, StoredData.A_SLOW, [22, 20, 18], {"area": [40, 50, 60], "cur_timeto_slow": [120, 150, 180]}],
		[SpecStrongHeal, StoredData.A_STRONGHEAL, [35, 30, 25], {"heal": [6, 7, 8]}],
		[SpecSuppress, StoredData.A_SUPPRESS, [20, 16, 12], {"cur_suppress_ratio": [1.5, 2.0, 2.5]}],
		[SpecTaunt, StoredData.A_TAUNT, [30, 25, 20], {"current_taunted_number": [3, 4, 5], "area": [100, 110, 120]}],
		[SpecWeakSpot, StoredData.A_WEAKSPOT, [24, 20, 16], {"cur_weak_modifier": [1.6, 1.8, 2.0], "cur_time_to_weak": [240, 270, 300]}],
	]
	for row in rows:
		var cls: GDScript = row[0]
		var idx: int = row[1]
		var cds: Array = row[2]
		for lvl in 3:
			clear_save()
			set_save(idx, lvl + 1)  # 存档值 1..3 -> 等级 0..2
			var spec: SpecialTemplate = cls.new(true)
			check(spec.cur_spec_level == lvl, "%s player save %d -> level %d (got %d)" % [cls.get_global_name(), lvl + 1, lvl, spec.cur_spec_level])
			check(spec.time_until_update == cds[lvl] * 30, "%s level %d cooldown %d frames (got %d)" % [cls.get_global_name(), lvl, cds[lvl] * 30, spec.time_until_update])
			for prop: String in row[3]:
				var want: float = float(row[3][prop][lvl])
				check(is_equal_approx(float(spec.get(prop)), want), "%s level %d %s = %s (got %s)" % [cls.get_global_name(), lvl, prop, want, spec.get(prop)])
		# 敌方恒为 2 级，无视存档
		clear_save()
		var enemy: SpecialTemplate = cls.new(false)
		check(enemy.cur_spec_level == 2 and enemy.is_locked == false, "%s enemy is level 2 regardless of save" % cls.get_global_name())
		check(enemy.time_until_update == cds[2] * 30, "%s enemy cooldown %d frames" % [cls.get_global_name(), cds[2] * 30])
	# 无 setParams 的固定参数技能
	check(SpecPoison.new(true).time_until_update == 25 * 30, "SpecPoison cooldown 750 frames at level 0")
	check(SpecHide.new(false, make_unit()).time_until_update == 8 * 30, "SpecHide for non-player uses level 1 (8s)")
	check(SpecFlee.new(false).time_until_update == 40 * 30, "SpecFlee enemy level 2 cooldown 40s")
	check(SpecSilence.new(false).time_until_update == 43 * 30, "SpecSilence enemy level 2 cooldown 43s")
	check(SpecWeakness.new(false).time_until_update == 5 * 30 and SpecWeakness.new(false).cur_weak_time == 10 * 30, "SpecWeakness enemy level 2 10s")
	check(SpecSummonSkeletons.new().time_until_update == 12 * 30, "SpecSummonSkeletons 360 frames")
	check(SpecRegen.new(false).time_until_update == 150 and SpecRegen.new(false).cur_ratio == 23, "SpecRegen 150 frames, 23 per tick")
	check(SpecSmallRessurect.new(false).time_until_update == 750, "SpecSmallRessurect 750 frames")
	check(SpecOgreStun.new(false).max_stun_time == 30, "SpecOgreStun 30 frames")
	check(SpecBlock.new(false).number_in_panel == 5 and SpecStun.new(false).number_in_panel == 28, "panel numbers kept")
	# 文本
	clear_save()
	# 注意：cur_level_params 内部调用 set_params()（默认 param1 = true），即读存档；这里先设存档为 3（等级 2）
	set_save(StoredData.A_STUN, 3)
	set_save(StoredData.A_PARRY, 3)
	var st := SpecStun.new(false)
	check(st.cur_level_params() == "Cooldown: <font color='#F6F581'>14s</font>, stun time: <font color='#F6F581'>4s</font>", "SpecStun curLevelParams text")
	check(SpecParry.new(false).cur_level_params().contains("Critical strike chance: <font color='#F6F581'>20%</font>"), "SpecParry text shows 20%")
	clear_save()
	check(SpecMissGhost.new(false).cur_level_params().contains("NaN%"), "SpecMissGhost keeps the original NaN% text")


func test_level_rules() -> void:
	clear_save()
	var locked := SpecStun.new(true)  # 存档 0 -> 锁定
	check(locked.is_locked and locked.cur_spec_level == 0, "player save 0 -> locked, level 0")
	check(locked.cur_level_params() == "Ability locked. Spend a star to unlock.", "locked text")
	check(not locked.can_use_special(), "locked spec cannot be used")
	locked.unlock_abil_set_max_level()
	check(not locked.is_locked and locked.cur_spec_level == 2, "unlock_abil_set_max_level -> level 2")
	set_save(StoredData.A_BLOCK, 2)
	check(SpecBlock.new(true).cur_spec_level == 1, "player save 2 -> level 1")
	set_save(StoredData.A_BLOCK, 0)
	check(SpecBlock.new(false).cur_spec_level == 2, "enemy ignores locked save")
	# 玩家读存档在等级改变后 cur_level_params 重新读取
	var spec := SpecIce.new(true)
	set_save(StoredData.A_ICE, 3)
	spec.cur_level_params()
	check(spec.cur_spec_level == 2 and spec.time_until_update == 23 * 30, "cur_level_params re-reads the save")
	clear_save()


func test_cooldown_frames() -> void:
	clear_save()
	var spec := SpecStun.new(false)  # level 2：14s = 420 帧
	check(spec.get_cur_counter == -1 and spec.get_count_percent == 100, "fresh spec counter -1, percent 100")
	check(not spec.can_use_special(), "counter -1 < 420 -> not usable")
	spec.reset_counter()
	check(spec.get_cur_counter == 0, "reset_counter -> 0")
	for i in 419:
		spec.update()
	check(not spec.can_use_special() and spec.get_cur_counter == 419, "419 updates: not usable")
	check(spec.get_count_percent == AS3.round(419.0 / 420 * 100), "percent at 419/420")
	spec.update()
	check(spec.can_use_special() and spec.get_count_percent == 100, "420 updates: usable")
	# set_random_time 消耗恰好一次 rand
	RWRandom.set_seed(98765)
	var want := RWRandom.rand_range(1, 420)
	RWRandom.set_seed(98765)
	spec.set_random_time()
	check(spec.get_cur_counter == want, "set_random_time = rand_range(1, tuu)")
	# 被动技能（冷却 -10）：初始即可用
	var passive := SpecFireHitSplash.new(false)
	check(passive.can_use_special(), "passive (cooldown -10) usable at counter -1")
	passive.update()
	check(passive.get_cur_counter == -1, "SpecFireHitSplash.update does nothing")
	# 召唤骷髅：每次施法冷却 +60
	var summon := SpecSummonSkeletons.new()
	summon.reset_counter()
	for i in 360:
		summon.update()
	check(summon.can_use_special(), "summon usable after 360 frames")


func test_triggers() -> void:
	clear_save()
	var lib := SoundLibrary.inst
	var me := make_unit(100, 100, true)
	var target := make_unit(120, 100, false)
	# --- 眩晕 ---
	var stun := SpecStun.new(true)  # 存档全 0 -> 锁定；改为外部解锁到 2 级
	stun.unlock_abil_set_max_level()
	stun.reset_counter()
	for i in stun.time_until_update:
		stun.update()
	var gd := GlobalData.inst
	var before := gd.a41_stun_enemies
	fx_log.clear()
	snd.played.clear()
	stun.check_stun(target)
	check(target.calls == [["stunned", 120]], "stun applies 120 frames at level 2")
	check(stun.get_cur_counter == 0, "stun resets the counter")
	check(gd.a41_stun_enemies == before + 1, "friendly stun counts achievement")
	check(fx_log.size() == 1 and fx_log[0][0] == "StunnedEffectVisual" and fx_log[0][3] == target, "stun effect spawned on target")
	check(snd.played.size() == 1 and snd.played[0][0] == lib.get_sound(SoundLibrary.STUNNED) and snd.played[0][1] == 0.5, "stun sound STUNNED at volume 0.5")
	stun.check_stun(target)
	check(target.calls.size() == 1, "stun on cooldown does nothing")
	# --- 格挡 ---
	var block := SpecBlock.new(false)
	block.reset_counter()
	check(not block.is_blocked(target), "block not ready")
	for i in block.time_until_update:
		block.update()
	check(block.is_blocked(target) and not block.is_blocked(target), "block succeeds once then is on cooldown")
	# --- 招架：暴击判定为 rand > crit_chance 才三倍，其余 1.5 倍；伤害用攻击者的穿甲 ---
	var parry := SpecParry.new(false)
	parry.reset_counter()
	for i in parry.time_until_update:
		parry.update()
	var attacker := make_unit(110, 100, false)
	attacker._cur_damage = 20
	attacker._armor_piercing_melee = 0.1
	me._cur_armor = 0.3
	RWRandom.set_seed(4242)
	var mult := 3.0 if RWRandom.rand() > 0.2 else 1.5
	RWRandom.set_seed(4242)
	var ok := parry.check_parry(attacker, 20, me)
	var call: Array = me.calls[0]
	check(ok and call[0] == "bring_damage" and call[2] == attacker and call[3] == true, "parry counterattacks melee")
	# param3.curArmor 是被反击者（me）的护甲 0.3，穿甲取 param1（attacker）的 0.1 -> 0.2
	check(call[1] == int(20 * (1 - 0.2) * mult), "parry damage = curDamage*(1-(armor-piercing))*%s (got %s)" % [mult, call[1]])
	# --- 背刺：低血直接 600；否则 curDamage*(1-armor)*系数 ---
	var bs := SpecBackStab.new(false)
	bs.reset_counter()
	for i in bs.time_until_update:
		bs.update()
	var stabbed := make_unit(110, 100, false)
	stabbed._cur_health = 30  # 30/100 < 0.36
	me._armor_piercing_melee = 0.0
	check(bs.check_back_stab(stabbed, 20, me), "backstab in range succeeds")
	check(stabbed.calls[0][0] == "bring_damage" and stabbed.calls[0][1] == 600, "backstab below 36% hp kills (600)")
	for i in bs.time_until_update:
		bs.update()
	var healthy := make_unit(110, 100, false)
	healthy._armor_piercing_melee = 0.0
	healthy._cur_armor = 0.5
	check(bs.check_back_stab(healthy, 20, me), "backstab 2")
	check(healthy.calls[0][1] == int(20 * (1 - 0.5) * 7), "backstab damage x7 at level 2 (got %s)" % healthy.calls[0][1])
	for i in bs.time_until_update:
		bs.update()
	var far := make_unit(300, 100, false)
	check(not bs.check_back_stab(far, 20, me), "backstab beyond 65 px fails and does not consume the cooldown")
	check(bs.can_use_special(), "cooldown kept after failed backstab")
	# --- 毒 ---
	var pr := SpecPoisonRogue.new(false)
	pr.reset_counter()
	for i in pr.time_until_update:
		pr.update()
	var ghost := make_unit()
	ghost.kind = LivingObject.UNDEAD_GHOST
	check(not pr.check_poison(ghost), "rogue poison skips ghosts (P-code condition)")
	check(pr.can_use_special() and ghost.calls.is_empty(), "ghost not poisoned, cooldown kept")
	var victim := make_unit()
	var a9 := gd.a9_poisoned
	check(pr.check_poison(victim), "rogue poison applied")
	check(victim.calls == [["poisoned", 300, 8]], "rogue poison 10s at 8 HP/s on level 2")
	check(gd.a9_poisoned == a9 + 1 and pr.get_cur_counter == 0, "a9 counted, cooldown reset")
	check(not pr.check_poison(victim), "poisoned unit is not poisoned again")
	var p0 := SpecPoison.new(false)
	p0.reset_counter()
	for i in p0.time_until_update:
		p0.update()
	var v2 := make_unit()
	check(p0.check_poison(v2) and v2.calls == [["poisoned", 240, 3]], "SpecPoison level 0: 8s, 3 HP/s")
	# --- 冰（需要法师桩的 set_casting_stance） ---
	var ice := SpecIce.new(true)
	ice.unlock_abil_set_max_level()
	ice.reset_counter()
	for i in ice.time_until_update:
		ice.update()
	var mage := make_unit(100, 100, true)
	var frozen := make_unit()
	check(ice.check_ice(mage, frozen) and mage.casting == 1, "ice check enters casting stance")
	var a10 := gd.a10_frozen
	ice.set_ice()
	check(frozen.calls == [["trapped_in_ice", 300, 2]], "ice 10s, 2 HP/s at level 2")
	check(gd.a10_frozen == a10 + 1 and ice.get_cur_counter == 0, "ice counts a10 and resets")
	check(not ice.check_ice(mage, frozen), "ice on cooldown")
	# --- 群体治疗：施放条件需要列表 length > 1（P-code 重建） ---
	var mh := SpecMassHeal.new(false)
	mh.reset_counter()
	for i in mh.time_until_update:
		mh.update()
	var priest := make_unit(100, 100, true)
	var hurt := make_unit(105, 100, true)
	hurt._cur_health = 40
	check(not mh.check_mass_heal([hurt], priest, 12), "mass heal with a single unit does nothing")
	check(mh.can_use_special() and hurt.calls.is_empty(), "single unit: cooldown kept and no heal")
	var full := make_unit(110, 100, true)
	check(mh.check_mass_heal([hurt, full], priest, 12), "mass heal with 2 units and one hurt succeeds")
	check(hurt.calls[0][1] == -12 and hurt.calls[1][0] == "healed_effect" and full.calls.is_empty(), "heal only damaged units, negative damage")
	check(priest.casting == 1 and priest.turned_to == full and mh.get_cur_counter == 0, "casting stance, turn to last unit, counter reset")
	mh.reset_counter()
	for i in mh.time_until_update:
		mh.update()
	full._cur_health = 100
	hurt._cur_health = 100
	check(not mh.check_mass_heal([hurt, full], priest, 12) and mh.can_use_special(), "nobody hurt: no cast, cooldown kept")
	# --- 诅咒：范围内敌人 > 1 才施放，kdCounter 到 90 才触发 ---
	var curse := SpecCurse.new(false)
	curse.reset_counter()
	for i in curse.time_until_update:
		curse.update()
	var caster := make_unit(100, 100, false)
	caster.real_friendly = false
	var f1 := make_unit(105, 100, true)
	var f2 := make_unit(110, 100, true)
	uni.a_all_units = [f1, f2, caster]
	var fired := -1
	for i in 100:
		if curse.check_curse_bless(caster, f1):
			fired = i
			break
	check(fired == 90, "curse waits 90 checks before casting (fired at %d)" % fired)
	check(caster.casting == 1, "curse enters casting stance")
	var a45 := gd.a45_curse_enemies
	curse.set_curse(caster)
	check(f1.calls.size() == 1 and f2.calls.size() == 1 and f1.calls[0] == ["cursed", 300, 0.45], "curse 10s, 45% on level 2")
	check(curse.get_cur_counter == 0, "curse resets counter")
	check(gd.a45_curse_enemies == a45 + 2, "a45_curseEnemies is counted per cursed unit regardless of side (original quirk)")
	# --- 敌方技能: 眩晕不计成就 ---
	var estun := SpecStun.new(false)
	estun.reset_counter()
	for i in estun.time_until_update:
		estun.update()
	var a41 := gd.a41_stun_enemies
	estun.check_stun(make_unit())
	check(gd.a41_stun_enemies == a41, "enemy stun is not an achievement")
	# --- 弱点：目标已有弱点则不施放 ---
	var ws := SpecWeakSpot.new(false)
	ws.reset_counter()
	for i in ws.time_until_update:
		ws.update()
	var wv := make_unit()
	check(ws.check_weak_spot(wv) and wv.calls == [["weak_spotted", 2.0, 300.0]], "weak spot x2 for 10s at level 2")
	check(not ws.check_weak_spot(wv), "weak spot not stacked")


func test_arrow_swarm() -> void:
	# ArrowEx 池换成桩，记录 init 参数并代替飞行
	var s := GDScript.new()
	s.source_code = "extends ArrowEx\nvar init_args: Array = []\nvar hit := false\nvar missed := false\nfunc init(param1: LivingObject, param2: Vector2, param3: Vector2, param4: Callable, param5: bool, param6: bool, param7: bool = false) -> void:\n\tinit_args = [param1, param2, param3, param4, param5, param6, param7]\nfunc set_hit() -> void:\n\thit = true\nfunc set_missed() -> void:\n\tmissed = true\n"
	check(s.reload() == OK, "fake arrow compiles")
	ArrowEx.cached_data = SimpleCache.new(s, 8)
	var swarm := ArrowSwarm.new()
	check(ArrowSwarm.inst == swarm, "ArrowSwarm.inst set by constructor")
	swarm.reset()
	# 冷却：set_cool_down(3) -> 90 帧；未开火时每次调用 counter+1，返回百分比（int 截断）
	swarm.set_cool_down(3)
	check(swarm.cool_down_counter == 90, "set_cool_down(3) -> 90 frames")
	check(swarm.update_arrow_swarm() == 1, "first update returns 1 (1/90*100 truncated)")
	var last := 0
	for i in 44:
		last = swarm.update_arrow_swarm()
	check(last == 50, "45th update returns 50 (got %d)" % last)
	for i in 45:
		last = swarm.update_arrow_swarm()
	check(last == 100, "90th update returns 100 (got %d)" % last)
	check(swarm.update_arrow_swarm() == 100, "stays at 100 after the cooldown")
	# 投放：probability 参数是 int，0.88 被截断成 0 -> 每次调用都放一支（rand > 0）
	var fu: FakeUni = uni
	fu.arrows.clear()
	snd.played.clear()
	swarm.add_swarm(swarm.LEFT, 3, 0.88, 7, 10, 350, 300, 150, 150)
	check(swarm.swarm_cont["probability"] == 0, "probability 0.88 truncated to int 0 (original quirk)")
	check(snd.played.size() == 1 and snd.played[0][1] == 0.45, "add_swarm plays ARROW_SWARM at 0.45")
	check(swarm.counter == 0, "add_swarm restarts the cooldown counter at 0")
	RWRandom.set_seed(31337)
	var expected: Array = []
	for i in 3:
		RWRandom.rand()  # probability 判定
		var sy: float = 200 + floor(300 * RWRandom.rand())
		var gx: float = 350 - 150 / 2.0 + floor(150 * RWRandom.rand())
		var gy: float = 300 - 150 / 2.0 + floor(150 * RWRandom.rand())
		expected.append([Vector2(-50, sy), Vector2(gx, gy)])
	RWRandom.set_seed(31337)
	for i in 3:
		swarm.update_arrow_swarm()
	check(fu.arrows.size() == 3, "3 arrows dropped for amount 3 (got %d)" % fu.arrows.size())
	if fu.arrows.size() == 3:
		for i in 3:
			var a: Array = fu.arrows[i].init_args
			check(a[0] == null and a[1] == expected[i][0] and a[2] == expected[i][1], "arrow %d start/target match the RNG sequence (%s vs %s)" % [i, [a[1], a[2]], expected[i]])
			check(a[4] == true and a[5] == false and a[6] == true, "arrow %d init flags (isHit, not crossbow, external)" % i)
	check(swarm.swarm_cont["amount"] == 0 and swarm.got_swarm, "amount exhausted but swarm still flagged")
	swarm.update_arrow_swarm()
	check(not swarm.got_swarm, "next update ends the swarm without dropping")
	check(fu.arrows.size() == 3, "no extra arrow after exhaustion")
	# 方向 RIGHT 起点 x = 800
	swarm.add_swarm(swarm.RIGHT, 1, 0, 7, 10, 350, 300, 150, 150)
	swarm.update_arrow_swarm()
	check(fu.arrows.size() == 4 and fu.arrows[3].init_args[1].x == 800, "RIGHT swarm starts at x=800")
	# 落点结算：范围内单位按 floor(damage*(1-armor)) 受伤；范围内无单位则 miss
	var arrow: Node2D = fu.arrows[0]
	var u1 := make_unit(200, 200, true)
	u1._cur_armor = 0.5
	var u2 := make_unit(500, 500, true)
	uni.a_all_units = [u1, u2]
	arrow.position = Vector2(200, 212)  # 落点 y - 12 = 200
	swarm.missile_hit_handler(arrow, null)
	check(u1.calls.size() == 1 and u1.calls[0][1] == int(floor(7 * (1 - 0.5))), "splash damage floor(7*(1-0.5)) = 3 (got %s)" % [u1.calls])
	check(u2.calls.is_empty() and arrow.hit and not arrow.missed, "unit outside splash untouched, arrow set_hit")
	var arrow2: Node2D = fu.arrows[1]
	arrow2.position = Vector2(50, 50)
	swarm.missile_hit_handler(arrow2, null)
	check(arrow2.missed and not arrow2.hit, "no units in splash -> set_missed")
