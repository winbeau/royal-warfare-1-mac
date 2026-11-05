extends RefCounted
var counters: Dictionary = {}
var one_shot := 0
func add(key: String, amount: float = 1) -> void:
	counters[key] = float(counters.get(key,0)) + amount

func award(index: int) -> void:
	Content.profile.slots[4][index] = 1

func killed(victim: RoyalUnit, attacker: RoyalUnit) -> void:
	var kind := victim.kind
	var keys := {"UNDEAD_DARTH_KNIGHT":"a1_darkKnitedKilled","UNDEAD_WITCH":"a3_witchesKilled","MONSTER_OGRE":"a4_ogresKilled"}
	if keys.has(kind): add(keys[kind])
	if kind=="MONSTER_OGRE" and victim.successful_hits==0: award(13)
	if "VAMPIRE" in kind: add("a2_vampiresKilled")
	if kind in ["UNDEAD_SKELETON_ARCHER","UNDEAD_STORMARCHER","UNDEAD_RANGER"]: add("a5_archersKilled")
	if "SKELETON" in kind: add("a6_skeletonsKilled")
	if "ZOMBIE" in kind: add("a12_zombieKilled")
	if attacker and attacker.record.base == "meleeRogue": add("a8_killedByRogues")

func finish(battle: Node2D, won: bool) -> void:
	add("a18_makeDamage",battle.damage_dealt)
	add("a19_healDamage",battle.healed)
	add("a20_tankDamage",battle.damage_received)
	add("a25_28_totalKilled",battle.kills)
	add("a35_36_lostSoldiers",battle.lost)
	add("a39_farmGold",battle.gold_gained)
	add("a43_tier2upgrade",battle.upgraded)
	add("a44_hireUnits",battle.hired)
	var stored: Dictionary = Content.profile.slots[5]
	for key in counters: stored[key] = float(stored.get(key,0)) + float(counters[key])
	for rule in Content.read_json("data/achievement_rules.json"):
		if float(stored.get(rule.counter,0)) >= float(rule.threshold): award(int(rule.achievement))
	var stars_levels := 0
	for stars in Content.profile.slots[0]:
		if int(stars)==3: stars_levels += 1
	for pair in [[6,20],[12,21],[18,22],[24,23]]:
		if stars_levels >= pair[0]: award(pair[1])
	if won:
		for pair in [[1,28],[12,29],[21,30],[24,31]]:
			if int(battle.mission.number)==pair[0]: award(pair[1])
		if int(battle.mission.number)==24 and battle.lost==0: award(46)
	else: award(33)
	var total := 0
	for stars in Content.profile.slots[0]: total += int(stars)
	for stars in Content.profile.slots[4]: total += int(stars)
	if total >=119: award(32)
	Content.save_profile()
