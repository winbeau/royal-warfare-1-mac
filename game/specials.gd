extends RefCounted
## Skill parameters are recovered from the first game's classes, in seconds.
var battle: Node2D
var parameters: Dictionary

func _init(owner_battle: Node2D) -> void:
	battle = owner_battle
	parameters = Content.read_json("data/special_parameters.json")

func rank(unit: RoyalUnit, skill: String) -> int:
	var key := str(parameters.get(skill, {}).get("key", ""))
	if not unit.friendly or unit.all_abilities or key.is_empty(): return 2
	return Content.ability_level(key) - 1

func value(unit: RoyalUnit, skill: String, field: String, fallback: float) -> float:
	var list: Array = parameters.get(skill, {}).get("tables", {}).get(field, [])
	if list.is_empty(): return fallback
	return float(list[clampi(rank(unit, skill), 0, list.size()-1)])

func ready(unit: RoyalUnit, skill: String) -> bool:
	if not unit.special_timers.has(skill) or rank(unit, skill) < 0 or unit.statuses.has("silence"): return false
	var seconds := value(unit, skill, "aTimeUntilUpdate", float(parameters[skill].cooldown))
	return float(unit.special_timers[skill]) >= seconds

func consume(unit: RoyalUnit, skill: String, visual: String = "") -> void:
	unit.special_timers[skill] = 0
	var keys := {"specBetray":"a13_mindControl","specIce":"a10_frozen","specPoison":"a9_poisoned","specPoisonRogue":"a9_poisoned","specRessurect":"a37_ressurect","specSmallRessurect":"a37_ressurect","specHarmResist":"a38_protection","specBreakArrows":"a38_protection","specStun":"a41_stunEnemies","specMassStun":"a41_stunEnemies","specCurse":"a45_curseEnemies","specCorrupt":"a46_breakArmor"}
	if unit.friendly and keys.has(skill): battle.achievements.add(keys[skill])
	if not visual.is_empty(): battle.effect(visual, unit.position)

func area(unit: RoyalUnit, friend: bool, radius: float) -> Array:
	var result: Array = []
	for other in battle.army:
		if other.dead or other.escaped or other.friendly != (unit.friendly if friend else not unit.friendly): continue
		if other.position.distance_to(unit.position) <= radius: result.append(other)
	return result

func update(unit: RoyalUnit, _delta: float) -> void:
	for skill in unit.record.specials:
		if not ready(unit, skill): continue
		var target: RoyalUnit = unit.target
		var foes := area(unit, false, value(unit, skill, "aArea", 120))
		var allies := area(unit, true, value(unit, skill, "aArea", 120))
		match skill:
			"specRegen":
				if unit.hp < unit.max_hp:
					unit.heal(unit.max_hp / value(unit, skill, "aRatio", 23))
					consume(unit, skill, "trollRegenEffect")
			"specHide":
				if not is_instance_valid(target) and not unit.statuses.has("hide"): unit.apply_status("hide", 100000); consume(unit, skill)
			"specMassHeal":
				var used := false
				for other in allies:
					if other.hp < other.max_hp: other.heal(unit.stat("damageRanged", 4) * 3); used = true
				if used: consume(unit, skill, "healEffect")
			"specRessurect", "specSmallRessurect":
				var count := 0
				for other in battle.army:
					if other.dead and not other.escaped and other.friendly == unit.friendly and other.death_time >= 3 and other.position.distance_to(unit.position) < 266:
						other.revive()
						count += 1
						battle.effect("ressurectEffectVis",other.position)
						if skill=="specSmallRessurect": break
				if count>0:
					consume(unit, skill)
					if unit.friendly and count>1: battle.achievements.add("a37_ressurect",count-1)
			"specSummonSkeletons":
				if not foes.is_empty():
					for i in range(3):
						var summoned: RoyalUnit = battle.spawn("UNDEAD_SKELETON", unit.friendly, unit.position + Vector2(i*18-18,20),1)
						summoned.target = unit.target
					consume(unit, skill, "summonAni")
			"specMetheor", "specFlash":
				if is_instance_valid(target):
					var radius := value(unit,skill,"_loc2_",65) if skill == "specMetheor" else 35.0
					var damage := value(unit,skill,"aDamage",70)
					var remaining := int(value(unit,skill,"aNumFlash",1))
					var killed := 0
					for other in battle.army:
						if other.dead or other.escaped or other.friendly==unit.friendly: continue
						if (skill=="specMetheor" and other.position.distance_to(target.position)<radius) or (skill=="specFlash" and remaining>0 and other.position.distance_to(unit.position)<266):
							other.hurt(damage,unit)
							remaining-=1
							if other.dead: killed+=1
					if unit.friendly:
						battle.achievements.add("a15_killByMetheor" if skill=="specMetheor" else "a16_killFlash",killed)
						if killed>=15: battle.achievements.award(6)
					battle.effect("rockFalling" if skill == "specMetheor" else "flashAni",target.position)
					consume(unit,skill)
			"specIce":
				if is_instance_valid(target):
					target.apply_status("ice",value(unit,skill,"aFreezeTime",4),value(unit,skill,"_loc2_",1),unit)
					consume(unit,skill,"iceAni")
			"specBetray":
				if is_instance_valid(target) and target.kind not in ["FR_KING","UNDEAD_VAMPIRE_KING","UNDEAD_SEEKER","UNDEAD_SUMMONER"]:
					target.friendly = unit.friendly
					target.target = null
					target.apply_status("betray",value(unit,skill,"aTimeToPossess",12))
					consume(unit,skill,"betrayEffect")
			"specCurse":
				if not foes.is_empty():
					for other in foes: other.apply_status("curse",value(unit,skill,"aCurseTime",6),value(unit,skill,"aCurseBlessPower",0.25))
					consume(unit,skill,"curseEffect")
			"specCurseBless", "specHarmResist", "specBreakArrows", "specEnchantWeapon":
				if not foes.is_empty() and not allies.is_empty():
					var key: String = {"specCurseBless":"bless","specHarmResist":"harm_resist","specBreakArrows":"break_arrows","specEnchantWeapon":"enchant"}[skill]
					var duration := value(unit,skill,"aBlessTime",value(unit,skill,"aActionTime",value(unit,skill,"aHarmResistTime",6)))
					for other in allies: other.apply_status(key,duration,value(unit,skill,"aCurseBlessPower",value(unit,skill,"aBonusAP",1)))
					consume(unit,skill,{"specCurseBless":"blessEffect","specHarmResist":"harmResistAni","specBreakArrows":"breakArrowAni","specEnchantWeapon":"enchantWeaponEff"}[skill])
			"specSilence", "specSlow", "specMassStun", "specTaunt":
				if not foes.is_empty():
					var key: String = {"specSilence":"silence","specSlow":"slow","specMassStun":"stun","specTaunt":"taunt"}[skill]
					var duration := value(unit,skill,"aActionTime",value(unit,skill,"aTimeToSlow",value(unit,skill,"aStunTime",3)))
					for other in foes:
						other.apply_status(key,duration)
						if key == "taunt": other.target = unit
					consume(unit,skill,{"specSilence":"silencedAni","specSlow":"slowMc","specMassStun":"stunWaveAni","specTaunt":"tauntAni"}[skill])
			"specFlee":
				if unit.hp < unit.max_hp * 0.2:
					unit.move_to(Vector2(randf_range(30,650),randf_range(30,570)))
					unit.hold=true
					unit.apply_status("hide",8)
					unit.apply_status("flee",8)
					consume(unit,skill,"freeMoveAni")
			"specSelfDestruct":
				if is_instance_valid(target) and target.position.distance_to(unit.position) < 40:
					var killed := 0
					var radius := value(unit,skill,"aRadius",120)
					for other in battle.army:
						if other==unit or other.dead or other.escaped: continue
						var distance: float=other.position.distance_to(unit.position)
						if distance<radius:
							other.hurt(unit.stat("damageMelee",100)*(radius-distance)/radius,unit)
							if other.dead and not other.friendly: killed+=1
					if killed>=10: battle.achievements.award(10)
					if killed>=15: battle.achievements.award(6)
					consume(unit,skill,"corpseExpEffect")
					unit.hurt(unit.max_hp*2,unit,true)

func support(unit: RoyalUnit, target: RoyalUnit) -> void:
	if ready(unit,"specStrongHeal"):
		target.heal(unit.stat("damageRanged",4)*value(unit,"specStrongHeal","_loc2_",6))
		consume(unit,"specStrongHeal","strongHealAni")

func defend(unit: RoyalUnit, attacker: RoyalUnit, ranged: bool) -> bool:
	if ranged and unit.statuses.has("break_arrows"): return true
	for skill in unit.record.specials:
		if not ready(unit,skill): continue
		match skill:
			"specBlock", "specParry":
				if not ranged: consume(unit,skill,"blockMc" if skill=="specBlock" else "parryAni"); return true
			"specMissAssasin":
				if randf() < value(unit,skill,"aProbability",0.2): return true
			"specMissSkeleton":
				if ranged and not attacker.magic() and randf() < 0.15: return true
			"specMissGhost":
				if not attacker.magic(): return true
	return false

func strike(unit: RoyalUnit, victim: RoyalUnit, amount: float, ranged: bool) -> float:
	for skill in unit.record.specials:
		if not ready(unit,skill): continue
		match skill:
			"specCrit", "specCritRanged":
				if ranged == (skill == "specCritRanged") and randf() < value(unit,skill,"aProbability",0.15):
					amount *= 3 if skill == "specCrit" else value(unit,skill,"_loc2_",3)
					battle.effect("critAni",victim.position)
			"specHeadShot":
				amount = 600 if victim.hp/victim.max_hp < 0.36 else amount * value(unit,skill,"_loc2_",4)
				consume(unit,skill,"headShotEffect")
			"specBackStab":
				if not is_instance_valid(victim.target) or victim.target != unit: amount *= value(unit,skill,"_loc2_",3); consume(unit,skill,"backstabAni")
			"specStun", "specOgreStun":
				if skill=="specOgreStun":
					for other in area(unit,false,45): other.apply_status("stun",1)
				else: victim.apply_status("stun",value(unit,skill,"aStunTime",1))
				consume(unit,skill,"stunnedEffect")
			"specCorrupt":
				victim.armor_damage = maxf(victim.armor_damage,value(unit,skill,"aCorruptRatio",0.3))
				victim.apply_status("corrupt",value(unit,skill,"aTimeToCorrupt",6))
				consume(unit,skill,"corruptAni")
			"specWeakSpot":
				victim.apply_status("weak_spot",value(unit,skill,"aTimeToWeakSpot",8),value(unit,skill,"aWeakModifier",1.6)); consume(unit,skill,"weakSpotAni")
			"specPoison", "specPoisonRogue":
				victim.apply_status("poison",value(unit,skill,"aTimeToPoison",10),value(unit,skill,"aPoisonStrength",3),unit); consume(unit,skill,"poisonAni")
			"specWeakness":
				victim.apply_status("weakness",value(unit,skill,"aWeakTime",5)); consume(unit,skill,"zombWeaknessEffect")
			"specSuppress":
				victim.apply_status("suppress",value(unit,skill,"aTimeToSuppress",5),value(unit,skill,"aSuppressRatio",1.5)); consume(unit,skill,"suppressedAni")
			"specRoundAttack", "specFireHitSplash":
				var radius := value(unit,skill,"aArea",65)
				for other in battle.army:
					if other != victim and not other.dead and other.friendly != unit.friendly and other.position.distance_to(victim.position) < radius: other.hurt(amount,unit)
				consume(unit,skill,"roundAttackAni" if skill=="specRoundAttack" else "fireballSmoke")
			"specVampirizm": unit.heal(roundf(unit.stat("damageMelee")*value(unit,skill,"aRatio",1)))
			"specCollectMoney":
				if unit.friendly:
					var stolen := value(unit,skill,"aMoneyProp",3)
					battle.gold += stolen
					battle.gold_gained += stolen
					battle.achievements.add("a40_stealGold",stolen)
	unit.statuses.erase("hide")
	return amount
