## WP-D1：镇戍卫（刀盾 / 陌刀 / 斩马刀）。对应一代骑士（knight），同样靠经验自动升级（头衔沿用一代），
## 基础武器（刀盾）封顶 2 级，练满经验后才能换高级武器；换上即为 3 级。
## 陌刀克骑兵（一击必杀骑乘单位）、斩马刀令骑手下马，见 docs/ch2-spotlight-spec.md D1.4/D1.6/D1.7
## 与用户 2026-11-06 两次追加（熟练度规则、陌刀/斩马刀设计）。
class_name Ch2Warden
extends MeleeFighter

static var cached_unit_data: SimpleCache

static func cache(n: int = 0) -> void:
	cached_unit_data = SimpleCache.new(Ch2Warden, n, true)

static func init_resources() -> void:
	cache(20)

var weapon_id: String = "dao_shield"
var weapon: Dictionary = {}
var is_advanced_weapon: bool = false
var exp_levels: Array = [35, 40, 45]

var special_slots: Dictionary = {}  # skill_id -> Ch2SpecMeleeAuto

## 拒马斩（horsebreaker）支势状态；_update_brace 维护，Ch2DarthLancer.CHARGE 读取 brace_active/朝向判定。
var brace_active: bool = false
var brace_frames_left: int = 0

func init() -> void:
	kind = Ch2Kinds.CH2_WARDEN
	class_kind = CLASS_WARRIOR
	friendly = true
	sens_class = ""
	super.init()
	Ch2Paperdoll.setup_sens(self, 18, 36)
	Ch2Paperdoll.add_shadow(self, 22, 7)
	weapon = Ch2WeaponDef.weapon(weapon_id)
	_apply_paperdoll(weapon)
	_rebuild_specials({})

func update_stats() -> void:
	var cls: Dictionary = Ch2WeaponDef.unit_class("warden")
	money_cost = int(cls.get("unit_cost", 320))
	upgr_cost = int(cls.get("upgrade_cost", 600))
	var lvls: Array = cls.get("exp_levels", [35, 40, 45])
	exp_levels = lvls.duplicate()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

## 二章单位不在一代的 friendly_kinds 表里（kind>=100），add_to_game 会把 friendly 判成 false；
## 这里在 super.add_to_game 之后按一代"战士系"友军的套路补回来：好感度统计、血条归属、雇佣音效/扣钱。
func add_to_game(param1: float, param2: float, param3: int = 1, param4: bool = false, param5: bool = false) -> void:
	super.add_to_game(param1, param2, param3, param4, param5)
	friendly = true
	real_friendly = true
	is_defence_stance = true
	if ui_health_bar.get_parent() != null:
		ui_health_bar.get_parent().remove_child(ui_health_bar)
	GameUniverse.inst.healt_bar_cont.add_child(ui_health_bar)
	ui_health_bar.top.goto_and_stop(1)
	ui_health_bar.friendly = true
	ui_health_bar.reset_level_bar()
	if LivingObject.a_friend_warriors.find(_instance) < 0:
		LivingObject.a_friend_warriors.push_back(_instance)
	if param4 == false:
		Sounds.inst.play(s.get_sound(SoundLibrary.HIRE), false, 0, 0.4)
		if param5 == false:
			GameUniverse.inst.set_money(-1 * money_cost)

func upgrade(param1: int = -1) -> void:
	var lvl: int = param1 if param1 != -1 else 1
	if is_advanced_weapon:
		lvl = 3
	cur_level = lvl
	cur_experience = 0
	exp_to_next_level = int(exp_levels[clampi(cur_level - 1, 0, exp_levels.size() - 1)])
	_apply_weapon_level_stats(cur_level)
	cur_health = health
	ui_health_bar.reset_health(cur_health, health)

func got_experience(_param1: float) -> void:
	cur_experience += 1
	if cur_experience < exp_to_next_level:
		return
	if is_advanced_weapon:
		return
	if cur_level >= 2:
		if can_upgrade_is_shown == false:
			can_upgrade_is_shown = true
			var marker := CanUpgradeEx.new()
			add_child(marker)
			marker.position.x = sens.position.x
			marker.position.y = sens.position.y - sens_height / 2 - 12
			MainGameUIEx.inst.show_has_upgrade_button(_instance)
			Sounds.inst.play(s.get_sound(SoundLibrary.HAS_UPGRADE), false, 0, 0.5, position.x)
		return
	cur_level = 2
	cur_experience = 0
	exp_to_next_level = int(exp_levels[1])
	_apply_weapon_level_stats(2)
	ui_health_bar.reset_health(cur_health, health)

func can_upgrade_weapon() -> bool:
	if is_advanced_weapon:
		return false
	return cur_level >= 2 and cur_experience >= exp_to_next_level

func is_elite() -> bool:
	return cur_level >= 3 and cur_experience >= exp_to_next_level

func set_weapon(id: String, force: bool = false) -> void:
	var def: Dictionary = Ch2WeaponDef.weapon(id)
	if def.is_empty():
		push_error("Ch2Warden.set_weapon: unknown weapon %s" % id)
		return
	var new_is_adv: bool = int(def.get("level_tag", 1)) == 3
	if new_is_adv and not is_advanced_weapon and not force and not can_upgrade_weapon():
		push_error("Ch2Warden.set_weapon: base weapon exp not capped yet")
		return
	if brace_active:
		_end_brace()
	var old_cur_health: int = cur_health
	var old_health: int = maxi(health, 1)
	var old_ratios: Dictionary = _cooldown_ratios()
	weapon_id = id
	weapon = def
	is_advanced_weapon = new_is_adv
	_apply_paperdoll(def)
	if new_is_adv:
		cur_level = 3
		cur_experience = 0
		exp_to_next_level = int(exp_levels[2])
		can_upgrade_is_shown = false
	_apply_weapon_level_stats(cur_level)
	var ratio: float = float(old_cur_health) / float(old_health)
	cur_health = clampi(int(round(health * ratio)), 1, health)
	ui_health_bar.reset_health(cur_health, health)
	if selected:
		MainGameUIEx.inst.show_unit_panel()
	_rebuild_specials(old_ratios)

func _apply_weapon_level_stats(level: int) -> void:
	var stats: Dictionary = weapon
	if not is_advanced_weapon:
		stats = weapon.get("levels", {}).get(str(level), weapon)
	health = int(stats.get("health", 1))
	armor = float(stats.get("armor", 0.0))
	max_magic_resist = float(stats.get("resist", 0.0))
	armor_piercing_melee = float(stats.get("armor_pierce_melee", 0.0))
	max_armor_piercing_melee = armor_piercing_melee
	var interval: int = int(stats.get("attack_interval", 60))
	attack_interval = interval
	max_attack_interval = interval
	damage = int(stats.get("damage", 1))
	max_damage = damage
	max_walk_speed = float(stats.get("walk_speed", 0.8))

func _apply_paperdoll(def: Dictionary) -> void:
	var body_id: String = str(def.get("body", "warden_sword_shield"))
	bmp_stay = Ch2BmpFrames.from_body(body_id, "idle")
	bmp_walk = Ch2BmpFrames.from_body(body_id, "walk")
	bmp_attack = Ch2BmpFrames.from_body(body_id, "attack")
	bmp_dead = Ch2BmpFrames.from_body(body_id, "death")
	var art_id: Variant = def.get("weapon_art")
	var tex: Texture2D = Ch2WeaponDef.weapon_texture(art_id)
	if tex != null:
		var art_meta: Dictionary = Ch2WeaponDef.weapon_art_meta(str(art_id))
		var butt_arr: Array = art_meta.get("butt", [0, 0])
		var tip_arr: Array = art_meta.get("tip", butt_arr)
		sprite.set_meta("ch2_weapon", {
			"texture": tex,
			"butt": Vector2(float(butt_arr[0]), float(butt_arr[1])),
			"tip": Vector2(float(tip_arr[0]), float(tip_arr[1])),
			"anchor_along": def.get("anchor_along", {}),
		})
	else:
		sprite.set_meta("ch2_weapon", null)
	var offhand_id: Variant = def.get("offhand_art")
	var o_tex: Texture2D = Ch2WeaponDef.weapon_texture(offhand_id)
	if o_tex != null:
		var o_meta: Dictionary = Ch2WeaponDef.weapon_art_meta(str(offhand_id))
		var o_center: Array = o_meta.get("center", [0, 0])
		sprite.set_meta("ch2_offhand", {"texture": o_tex, "center": Vector2(float(o_center[0]), float(o_center[1]))})
	else:
		sprite.set_meta("ch2_offhand", null)
	if current_bm != null:
		current_bm.apply_frame(sprite, cur_frame)

func _cooldown_ratios() -> Dictionary:
	var r: Dictionary = {}
	for id in special_slots:
		var spec: Ch2SpecMeleeAuto = special_slots[id]
		r[id] = clampf(float(spec.get_cur_counter) / maxf(float(spec.time_until_update), 1.0), 0.0, 1.0)
	return r

func _rebuild_specials(old_ratios: Dictionary) -> void:
	special_slots = {}
	var ids: Array = weapon.get("skills", [])
	for id: String in ids:
		var spec := Ch2SpecMeleeAuto.new(id)
		spec.refresh_cooldown(old_ratios.get(id, 1.0))
		special_slots[id] = spec
	special_one = special_slots.get(ids[0]) if ids.size() > 0 else null
	special_two = special_slots.get(ids[1]) if ids.size() > 1 else null

func hit_test_sens(stage_point: Vector2) -> bool:
	return Ch2Paperdoll.hit_test_bbox(self, stage_point)

func before_updating_active_unit() -> void:
	_update_brace()

func set_destination(param1: Vector2, param2: bool = false) -> void:
	if brace_active:
		_end_brace()
	super.set_destination(param1, param2)

## ---- 陌刀拒马斩：支势判定（生效/击杀在 Ch2DarthLancer.CHARGE 里完成，见该文件注释） ----

func _update_brace() -> void:
	if weapon_id != "great_glaive":
		return
	if brace_active:
		brace_frames_left -= 1
		if brace_frames_left <= 0 or cur_stanse == WALKING:
			_end_brace()
		return
	if cur_stanse == WALKING:
		return
	var spec: Ch2SpecMeleeAuto = special_slots.get("horsebreaker")
	if spec == null or not spec.can_use_special():
		return
	var cfg: Dictionary = Ch2WeaponDef.skill("horsebreaker")
	var lancer: Ch2DarthLancer = _find_chargeable_lancer(float(cfg.get("brace_range_px", 220)), float(cfg.get("brace_corridor_px", 40)))
	if lancer == null:
		return
	spec.reset_counter()
	brace_active = true
	brace_frames_left = int(cfg.get("brace_max_frames", 90))
	turn_to_unit(lancer)
	_enter_brace_pose(3)

func _find_chargeable_lancer(range_px: float, corridor: float) -> Ch2DarthLancer:
	for u: LivingObject in GameUniverse.inst.a_all_units:
		if not (u is Ch2DarthLancer):
			continue
		var lancer: Ch2DarthLancer = u
		if not lancer.is_charging_or_committing():
			continue
		if Vector2(lancer.position).distance_to(Vector2(position)) > range_px:
			continue
		if lancer.distance_to_charge_line(Vector2(position)) <= corridor:
			return lancer
	return null

func _enter_brace_pose(frame_idx: int) -> void:
	if bmp_brace == null:
		return
	current_bm = bmp_brace
	cur_frame = clampi(frame_idx, 0, bmp_brace.num_frames - 1)
	play_head_stance = STOPPED
	_show_frame(cur_frame)

## 供 Ch2DarthLancer.CHARGE 命中支势中的陌刀时调用：正面迎上即判定拒马生效。
func resolve_horsebreaker_hit() -> void:
	_enter_brace_pose((bmp_brace.num_frames - 1) if bmp_brace != null else 0)
	Ch2Vfx.spawn("brace_clash", Vector2(position.x, position.y - sens_height / 2.0))
	brace_frames_left = 20  # 停留展示 clash 姿势一小段时间后恢复

func _end_brace() -> void:
	brace_active = false
	brace_frames_left = 0
	set_stance(STAND)

var bmp_brace: Ch2BmpFrames = null

## ---- 普攻：陌刀顺带命中次目标；陌刀/斩马刀对骑乘单位的特殊结算 ----

func attack_done(_e: Variant = null) -> void:
	if cur_target == null or cur_target.cur_health <= 0:
		return
	var target: LivingObject = cur_target
	_melee_hit(target, cur_damage, armor_piercing_melee)
	if weapon_id == "great_glaive":
		var secondary: LivingObject = _find_cleave_secondary(target)
		if secondary != null:
			_melee_hit(secondary, int(cur_damage * float(weapon.get("cleave_ratio", 0.6))), armor_piercing_melee)
	enemy_hit_sound()

func _melee_hit(target: LivingObject, dmg: int, pierce: float) -> void:
	if target == null or target.cur_health <= 0:
		return
	if bool(weapon.get("kills_mounted", false)) and target is Ch2DarthLancer:
		_kill_mounted(target)
		return
	if bool(weapon.get("dismounts_riders", false)) and target is Ch2DarthLancer:
		_dismount(target)
		return
	var eff_armor: float = maxf(target.cur_armor - pierce, 0.0)
	var applied: int = int(dmg * (1.0 - eff_armor))
	got_experience(1)
	target.bring_damage(applied, _instance, true)

## 陌刀命中骑乘单位（含横扫/拒马拦下的重骑）：人马俱碎（一击必杀，走正常 bring_damage 死亡流程，计入击杀与经验）。
func _kill_mounted(target: Ch2DarthLancer) -> void:
	Ch2Vfx.spawn("brace_clash", Vector2(target.position.x, target.position.y - target.sens_height / 3.0))
	got_experience(1)
	target.bring_damage(target.health + 9999, _instance, true)

## 斩马刀命中骑乘单位：斩倒战马，骑手被迫下马（静默移除重骑对象，原地生成一代达思骑士）。
func _dismount(target: Ch2DarthLancer) -> void:
	Ch2Vfx.spawn("brace_clash", Vector2(target.position.x, target.position.y - target.sens_height / 3.0))
	target.dismount()

func _find_cleave_secondary(primary: LivingObject) -> LivingObject:
	var range_px: float = float(weapon.get("cleave_range", 26))
	var best: LivingObject = null
	var best_d: float = range_px + 1.0
	for u: LivingObject in GameUniverse.inst.a_all_units:
		if u == primary or u.friendly == friendly or u.cur_health <= 0:
			continue
		if absf(u.position.y - primary.position.y) > 20:
			continue
		var d: float = absf(u.position.x - primary.position.x)
		if d <= range_px and d < best_d:
			best = u
			best_d = d
	return best

## ---- 被攻击：hold_fast/horsebreaker 减伤窗口；intercept/follow_through 反制 ----
## 用户 2026-11-06 重定技能结构：四个技能按 skill_id 是否在 special_slots 里分发，而不是按 weapon_id
## 判断——hold_fast/intercept 可能来自刀盾或斩马刀，horsebreaker/follow_through 各自只属于一把武器，
## 但同样走这一套分发，不必逐武器写死。

func special_being_hit_melee_handler(param1: int, param2: LivingObject) -> int:
	var result := param1
	for id in ["hold_fast", "horsebreaker"]:
		var spec: Ch2SpecMeleeAuto = special_slots.get(id)
		if spec != null:
			result = _apply_damage_reduction_window(spec, id, result)
	if param2 != null:
		var intercept: Ch2SpecMeleeAuto = special_slots.get("intercept")
		if intercept != null:
			_apply_intercept(intercept, "intercept", param2)
		var ft: Ch2SpecMeleeAuto = special_slots.get("follow_through")
		if ft != null:
			_apply_follow_through(ft, param2)
	return result

## Hold Fast 基础效果，horsebreaker 复用同一套（⊇hold_fast）：被 >=2 名近战攻击时开窗 6 秒，
## 窗口内正面近战伤害按 damage_mult 减免；“效果 +15%”对减伤而言是让减免幅度更强，故对 (1-damage_mult) 这部分升级。
func _apply_damage_reduction_window(spec: Ch2SpecMeleeAuto, skill_id: String, incoming: int) -> int:
	var cfg: Dictionary = Ch2WeaponDef.skill(skill_id)
	if spec.window_counter <= 0 and spec.can_use_special() and cur_battle != null and cur_battle.is_defender(self) \
			and cur_battle.a_melee_attackers.size() >= int(cfg.get("melee_threshold", 2)):
		spec.reset_counter()
		spec.window_counter = int(cfg.get("window_frames", 180))
	if spec.window_counter <= 0:
		return incoming
	var reduction: float = 1.0 - float(cfg.get("damage_mult", 0.5))
	reduction = Ch2SkillLevels.effect_mult(skill_id, reduction)
	var mult: float = clampf(1.0 - reduction, 0.0, 1.0)
	return int(incoming * mult)

## Intercept 基础效果，follow_through 的“轻型目标眩晕+推开”部分复用同一套（⊇intercept）。
func _apply_intercept(spec: Ch2SpecMeleeAuto, skill_id: String, attacker: LivingObject) -> void:
	if not spec.can_use_special() or not Ch2MusketSpecials.is_light_enemy(attacker):
		return
	spec.reset_counter()
	var cfg: Dictionary = Ch2WeaponDef.skill(skill_id)
	attacker.stunned(int(Ch2SkillLevels.effect_mult(skill_id, float(cfg.get("stun_frames", 45)))))
	var push: float = Ch2SkillLevels.effect_mult(skill_id, float(cfg.get("push_px", 15)))
	var dir: Vector2 = Vector2(attacker.position) - Vector2(position)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(1, 0)
	attacker.set_coordinates(attacker.position.x + dir.x * push, attacker.position.y + dir.y * push)

## Follow-Through（斩马刀）⊇ Intercept：轻型目标眩晕+推开（与 Intercept 同一条件），
## 随后对任意目标（含重型，如达思系）追加一次 2 倍伤害的斩击——这部分不看轻型/重型，独立于上面的判定。
func _apply_follow_through(spec: Ch2SpecMeleeAuto, attacker: LivingObject) -> void:
	if not spec.can_use_special():
		return
	spec.reset_counter()
	if Ch2MusketSpecials.is_light_enemy(attacker):
		var cfg: Dictionary = Ch2WeaponDef.skill("follow_through")
		attacker.stunned(int(Ch2SkillLevels.effect_mult("follow_through", float(cfg.get("stun_frames", 45)))))
		var push: float = Ch2SkillLevels.effect_mult("follow_through", float(cfg.get("push_px", 15)))
		var dir: Vector2 = Vector2(attacker.position) - Vector2(position)
		dir = dir.normalized() if dir.length() > 0.01 else Vector2(1, 0)
		attacker.set_coordinates(attacker.position.x + dir.x * push, attacker.position.y + dir.y * push)
	if attacker.cur_health <= 0:
		return
	var cfg2: Dictionary = Ch2WeaponDef.skill("follow_through")
	var mult: float = Ch2SkillLevels.effect_mult("follow_through", float(cfg2.get("damage_mult", 2.0)))
	var eff_armor: float = maxf(attacker.cur_armor - armor_piercing_melee, 0.0)
	var extra: int = int(cur_damage * mult * (1.0 - eff_armor))
	got_experience(1)
	attacker.bring_damage(extra, _instance, true)
