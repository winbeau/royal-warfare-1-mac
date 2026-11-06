## WP-D1 D1.5/D1.7：火铳特殊弹的命中效果分发。弹丸飞行与命中判定在 Ch2Bullet/Ch2Musketeer 里，
## 这里只负责“命中那一刻按技能类型结算”，伤害公式统一沿用 RangedFighter.missile_hit_handler 的护甲减伤。
## 用户 2026-11-06 重定技能结构：steady_aim/rending_shot 为基础技能，scattershot（⊇rending_shot）、
## heartpiercer（⊇steady_aim）为高级武器的升级技能，Ch2Musketeer.throw_ranged 在排队 steady_aim/heartpiercer
## 时已强制命中，这里不再处理命中判定。
class_name Ch2MusketSpecials
extends RefCounted

## “轻型敌人”判定（达思系/食人魔/巨魔/骑乘单位都排除在外），供 Intercept/Follow-Through 共用。
static func is_light_enemy(u: LivingObject) -> bool:
	if u == null:
		return false
	var heavy: Array = [
		LivingObject.UNDEAD_DARTH_KNIGHT, LivingObject.UNDEAD_STORMGUARDIAN,
		LivingObject.UNDEAD_STORMARCHER, LivingObject.UNDEAD_STORMTROOPER,
		LivingObject.MONSTER_OGRE, LivingObject.MONSTER_TROLL,
	]
	if heavy.has(u.get_kind):
		return false
	return not (u is Ch2DarthLancer)

static func _plain_hit(shooter: LivingObject, target: LivingObject, damage: int, pierce: float) -> void:
	if target == null or not is_instance_valid(target) or target.cur_health <= 0:
		return
	var eff_armor: float = maxf(target.cur_armor - pierce, 0.0)
	var dmg: int = int(damage * (1.0 - eff_armor))
	shooter.got_experience(1)
	target.bring_damage(dmg, shooter, false)

static func _apply_rending(target: LivingObject, skill_id: String) -> void:
	if target == null or target.cur_health <= 0 or target.is_corrupted:
		return
	var cfg: Dictionary = Ch2WeaponDef.skill(skill_id)
	target.armor_corrupted(int(cfg.get("duration_frames", 180)), float(cfg.get("armor_penalty", 0.3)))

## did_hit=false 时 target 为 null（未命中只在落点播扬尘，不结算伤害）。
static func resolve(special_id: String, shooter: LivingObject, target: Variant, land: Vector2, did_hit: bool, base_damage: int, base_pierce: float) -> void:
	if not did_hit or target == null or not is_instance_valid(target):
		Ch2Vfx.spawn("ball_impact", land)
		return
	var t: LivingObject = target
	if t.cur_health <= 0:
		return
	match special_id:
		"steady_aim":
			var mult: float = Ch2SkillLevels.effect_mult("steady_aim", float(Ch2WeaponDef.skill("steady_aim").get("damage_mult", 1.6)))
			_plain_hit(shooter, t, int(base_damage * mult), base_pierce)
		"rending_shot":
			_plain_hit(shooter, t, base_damage, base_pierce)
			_apply_rending(t, "rending_shot")
		"scattershot":
			_scattershot(shooter, t, base_damage, base_pierce)
		"heartpiercer":
			_heartpiercer(shooter, t, base_damage, base_pierce)
		_:
			_plain_hit(shooter, t, base_damage, base_pierce)
	Ch2Vfx.spawn_partial("ball_impact", Vector2(t.position.x, t.position.y - t.sens_height / 2.0), 4)

static func _nearby_enemies(shooter: LivingObject, center: Vector2, radius: float, max_n: int, exclude: LivingObject) -> Array:
	var result: Array = []
	for u: LivingObject in GameUniverse.inst.a_all_units:
		if u == exclude or u.friendly == shooter.friendly or u.cur_health <= 0:
			continue
		if Vector2(u.position).distance_to(center) <= radius:
			result.append(u)
			if result.size() >= max_n:
				break
	return result

## Scattershot（五雷）⊇ Rending Shot：扇面散射，每个命中目标都附带破甲。
static func _scattershot(shooter: LivingObject, primary: LivingObject, base_damage: int, base_pierce: float) -> void:
	var cfg: Dictionary = Ch2WeaponDef.skill("scattershot")
	var mult: float = Ch2SkillLevels.effect_mult("scattershot", float(cfg.get("damage_mult", 0.8)))
	var max_n: int = int(cfg.get("max_targets", 6))
	var targets: Array = [primary]
	targets.append_array(_nearby_enemies(shooter, Vector2(primary.position), float(cfg.get("radius_px", 120)), max_n - 1, primary))
	for u: LivingObject in targets:
		_plain_hit(shooter, u, int(base_damage * mult), base_pierce)
		_apply_rending(u, "scattershot")
		Ch2Vfx.spawn("scattershot", Vector2(u.position.x, u.position.y - u.sens_height / 2.0))

## Heartpiercer（重管）⊇ Steady Aim：已在 throw_ranged 强制命中并算过 1.6x，这里只处理穿透命中第二个目标。
static func _heartpiercer(shooter: LivingObject, primary: LivingObject, base_damage: int, base_pierce: float) -> void:
	var cfg: Dictionary = Ch2WeaponDef.skill("heartpiercer")
	var mult: float = Ch2SkillLevels.effect_mult("heartpiercer", float(cfg.get("damage_mult", 1.6)))
	var bonus: float = float(cfg.get("armor_pierce_bonus", 0.5))
	_plain_hit(shooter, primary, int(base_damage * mult), base_pierce + bonus)
	var range_px: float = float(cfg.get("pierce_range_px", 60))
	var candidates: Array = _nearby_enemies(shooter, Vector2(primary.position), range_px, 999, primary)
	if candidates.is_empty():
		return
	var chosen: LivingObject = null
	for u: LivingObject in candidates:
		if u.cur_armor >= 0.5:
			chosen = u
			break
	if chosen == null:
		chosen = candidates[0]
	_plain_hit(shooter, chosen, int(base_damage * mult), base_pierce + bonus)
