## WP-D1：火铳卫（制式火铳 / 五雷神机 / 重管火铳）。对应一代弩手（crossbowman），同样靠经验自动
## 升级（头衔沿用一代），基础武器（制式火铳）封顶 2 级，练满经验后才能换高级武器；换上即为 3 级。
## 见 docs/ch2-spotlight-spec.md D1.3/D1.4/D1.5 与用户 2026-11-06 追加的熟练度规则。
class_name Ch2Musketeer
extends RangedFighter

static var cached_unit_data: SimpleCache

static func cache(n: int = 0) -> void:
	cached_unit_data = SimpleCache.new(Ch2Musketeer, n, true)

static func init_resources() -> void:
	cache(20)

var weapon_id: String = "matchlock"
var weapon: Dictionary = {}
var is_advanced_weapon: bool = false
var exp_levels: Array = [20, 25, 30]

## 弹匣状态（D1.5）：五雷剩余 1..5，其余武器恒为 1；弹匣剩余数供 D2 单位面板显示。
var ch2_clip_remaining: int = 1
var ch2_in_reload: bool = false

## 装填动画（用户 2026-11-06 容器截图自查后追加）：射击动画播完（on_play_head_stopped）后切到
## reload 动作循环播放，直到下一发真正开火（special_play_head_start_playing_handler）切回瞄准/
## 射击动作。bmp_reload 为 null（没有这个动作）时整段退化成一代原版的"停在最后一帧"，不报错。
var bmp_reload: Ch2BmpFrames = null
var _is_reloading: bool = false

var still_counter: int = 0
var queued_special: String = ""
var special_slots: Dictionary = {}  # skill_id -> Ch2SpecialAmmo

func init() -> void:
	kind = Ch2Kinds.CH2_MUSKETEER
	class_kind = CLASS_ARCHER
	friendly = true
	sens_class = ""
	super.init()
	Ch2Paperdoll.setup_sens(self, 18, 36)
	Ch2Paperdoll.add_shadow(self, 22, 7)
	weapon = Ch2WeaponDef.weapon(weapon_id)
	_apply_paperdoll(weapon)
	_rebuild_specials({})

func update_stats() -> void:
	var cls: Dictionary = Ch2WeaponDef.unit_class("musketeer")
	money_cost = int(cls.get("unit_cost", 340))
	upgr_cost = int(cls.get("upgrade_cost", 300))
	var lvls: Array = cls.get("exp_levels", [20, 25, 30])
	exp_levels = lvls.duplicate()

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

## 二章单位不走一代的招募计数/好感度分支（friendly_kinds 不含 kind>=100），这里补上必要的那部分：
## 把本单位算进 a_friend_ranged（供 MeleeFighter/RangedFighter 搜索对方近战索敌用）与友方统计。
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
	if LivingObject.a_friend_ranged.find(_instance) < 0:
		LivingObject.a_friend_ranged.push_back(_instance)
	if param4 == false:
		Sounds.inst.play(s.get_sound(SoundLibrary.HIRE), false, 0, 0.4)
		if param5 == false:
			GameUniverse.inst.set_money(-1 * money_cost)

## 初始武器等级套用（一代 add_to_game 末尾调用；add_to_game 自己已把各数值重置为占位 1，
## 这里按当前 weapon_id 套用真实数值）。直接招募高级武器时，调用方应在本函数之后再调一次
## set_weapon(advanced_id, true) 切到高级武器（见 docs/ch2-spotlight-spec.md D1.3 熟练度规则）。
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

## 基础武器封顶 2 级：满级后不再 upgrade_clicked()（一代同名流程只对 basic_unit 3 级做这件事，
## 这里按规格把“封顶”提前到 2 级，不改 living_object.gd）。
func got_experience(_param1: float) -> void:
	cur_experience += 1
	if cur_experience < exp_to_next_level:
		return
	if is_advanced_weapon:
		return  # 高级武器固定 3 级，经验满只代表“精英”头衔，无需进一步处理
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

## 2 级经验练满、尚未换过高级武器时才允许 set_weapon 到高级武器（force=true 的直接招募除外）。
func can_upgrade_weapon() -> bool:
	if is_advanced_weapon:
		return false
	return cur_level >= 2 and cur_experience >= exp_to_next_level

func is_elite() -> bool:
	return cur_level >= 3 and cur_experience >= exp_to_next_level

## 换装：原地换动画集/贴图、换两个技能实例（冷却进度按百分比继承），数值按新武器等级重算，血量保持比例。
## force=true 供直接招募高级武器单位使用（从 3 级起步，跳过“基础武器练满经验”的前置检查）。
func set_weapon(id: String, force: bool = false) -> void:
	var def: Dictionary = Ch2WeaponDef.weapon(id)
	if def.is_empty():
		push_error("Ch2Musketeer.set_weapon: unknown weapon %s" % id)
		return
	var new_is_adv: bool = int(def.get("level_tag", 1)) == 3
	if new_is_adv and not is_advanced_weapon and not force and not can_upgrade_weapon():
		push_error("Ch2Musketeer.set_weapon: base weapon exp not capped yet")
		return
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
	armor_piercing_ranged = float(stats.get("armor_pierce_ranged", 0.0))
	max_armor_piercing_ranged = armor_piercing_ranged
	var reload: int = int(stats.get("reload_frames", stats.get("ranged_attack_interval", 85)))
	ranged_attack_interval = reload
	max_ranged_attack_interval = reload
	shoot_accuracy_max = float(stats.get("accuracy", 0.85))
	ranged_damage = int(stats.get("ranged_damage", 1))
	max_ranged_damage = ranged_damage
	max_walk_speed = float(stats.get("walk_speed", 1.0))
	search_radius = 70.0 * float(weapon.get("search_radius_mult", 4.9))
	ch2_clip_remaining = int(weapon.get("clip_size", 1))
	ch2_in_reload = false

func _apply_paperdoll(def: Dictionary) -> void:
	var body_id: String = str(def.get("body", "musketeer_gun"))
	bmp_stay = Ch2BmpFrames.from_body(body_id, "idle")
	bmp_walk = Ch2BmpFrames.from_body(body_id, "walk")
	bmp_ranged = Ch2BmpFrames.from_body(body_id, "attack")
	bmp_attack = bmp_ranged
	bmp_dead = Ch2BmpFrames.from_body(body_id, "death")
	bmp_reload = Ch2BmpFrames.from_body(body_id, "reload")
	_is_reloading = false
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
	sprite.set_meta("ch2_offhand", null)
	if current_bm != null:
		current_bm.apply_frame(sprite, cur_frame)

func _cooldown_ratios() -> Dictionary:
	var r: Dictionary = {}
	for id in special_slots:
		var spec: Ch2SpecialAmmo = special_slots[id]
		r[id] = clampf(float(spec.get_cur_counter) / maxf(float(spec.time_until_update), 1.0), 0.0, 1.0)
	return r

func _rebuild_specials(old_ratios: Dictionary) -> void:
	special_slots = {}
	var ids: Array = weapon.get("skills", [])
	for id: String in ids:
		var spec := Ch2SpecialAmmo.new(id)
		spec.refresh_cooldown(old_ratios.get(id, 1.0))
		special_slots[id] = spec
	special_one = special_slots.get(ids[0]) if ids.size() > 0 else null
	special_two = special_slots.get(ids[1]) if ids.size() > 1 else null
	queued_special = ""

func before_updating_active_unit() -> void:
	if cur_stanse == WALKING:
		still_counter = 0
	else:
		still_counter += 1

func hit_test_sens(stage_point: Vector2) -> bool:
	return Ch2Paperdoll.hit_test_bbox(self, stage_point)

## 出手时机：射击动画 DONE 帧，沿用一代（on_play_head_done -> throw_ranged）。
func throw_ranged(_e: Variant = null) -> void:
	if cur_target == null or cur_target.cur_health <= 0:
		search_counter = 100
		search_target(true)
		if cur_target != null:
			throw_ranged(null)
		else:
			set_target(null)
		return
	var muzzle_local: Vector2 = sprite.get_meta("ch2_muzzle", Vector2.ZERO)
	var muzzle_world: Vector2 = sprite.to_global(muzzle_local)
	var aim := Vector2(cur_target.position.x, cur_target.position.y - 3)
	# RWRandom 调用顺序沿用一代 RangedFighter.throw_ranged：先判命中，未命中再先后取 x、y 偏移。
	# steady_aim/heartpiercer（⊇steady_aim）排队时必中，但仍先消耗一次 rand() 保持调用序列一致。
	var natural_hit: bool = RWRandom.rand() <= shoot_accuracy
	var is_hit: bool = true if queued_special in ["steady_aim", "heartpiercer"] else natural_hit
	if not is_hit:
		var nx: float = aim.x - 15 + 30 * RWRandom.rand()
		var ny: float = aim.y - 15 + 30 * RWRandom.rand()
		aim = Vector2(nx, ny)
	# 枪口火光按该帧杆的真实角度（武器朝向）旋转，不用"枪口到落点"近似（落点在目标身上，
	# 目标在侧后方时和枪口朝向对不上）；本地方向向量经 sprite 的全局变换（含朝向翻转）转到世界方向。
	var muzzle_dir_local: Vector2 = sprite.get_meta("ch2_muzzle_dir", Vector2.RIGHT)
	var muzzle_dir_world: Vector2 = sprite.get_global_transform().basis_xform(muzzle_dir_local)
	if muzzle_dir_world.length() < 0.01:
		muzzle_dir_world = aim - muzzle_world
	Ch2Vfx.spawn("muzzle_flash", muzzle_world, muzzle_dir_world.angle())
	for _i in 2:
		var smoke := Ch2Vfx.spawn("powder_smoke", muzzle_world)
		var drift: float = 8.0 + randf() * 6.0
		var tw := create_tween()
		tw.tween_property(smoke, "position:y", muzzle_world.y - drift, 0.4)
		tw.parallel().tween_property(smoke.sprite_bm, "modulate:a", 0.0, 0.4)
	var special_id: String = queued_special
	queued_special = ""
	var shooter_ref: LivingObject = _instance
	var dmg: int = cur_ranged_damage
	var pierce: float = armor_piercing_ranged
	Ch2Bullet.fire(muzzle_world, aim, is_hit, cur_target, func(did_hit: bool, tgt: Variant, land: Vector2) -> void:
		Ch2MusketSpecials.resolve(special_id, shooter_ref, tgt, land, did_hit, dmg, pierce)
	)
	get_ranged_shoot_sound()

## 装填节奏（D1.5）：五雷弹匣 5 发每发间隔 9 帧，打空后装填 150 帧；其余武器单发，周期即 reload_frames。
## 本函数只在 play_head_start_play() 触发时调用（manage_attack 的 attack_counter 到点才会走到这里），
## 而 manage_attack 本身只在“已就位不需要再走位”时才被调用——移动去追目标的帧数不会被这里消耗，
## 天然满足“装填中移动会暂停进度”。
##
## 真正开火（而不是连射中途的下一发）时才把 current_bm 切回 bmp_ranged 重播射击动画：
## current_bm 不等于 bmp_ranged，说明上一刻在播 reload（装填结束）或 bmp_walk（移动打断后复位），
## 需要重新从头播一次射击动作；仍是 bmp_ranged 时（五雷连射的第 2～5 发）不去打断它——
## 那一发的动画还没播完就会被打断，命中帧（DONE）反而可能永远到不了。
func special_play_head_start_playing_handler() -> void:
	if current_bm != bmp_ranged:
		_is_reloading = false
		current_bm = bmp_ranged
		cur_frame = 0
	_maybe_queue_special()
	var clip_size: int = int(weapon.get("clip_size", 1))
	if clip_size <= 1:
		return
	if ch2_in_reload:
		ch2_in_reload = false
		ch2_clip_remaining = clip_size
	ch2_clip_remaining -= 1
	if ch2_clip_remaining <= 0:
		ranged_attack_interval = int(weapon.get("reload_frames", 150))
		ch2_in_reload = true
	else:
		ranged_attack_interval = int(weapon.get("clip_interval", 9))

## 射击动画播完（STOPPED，一代原版行为是直接冻结在最后一帧）：改成切到 reload 动作循环播放，
## 直到下一发真正开火才切回。五雷连射中途（弹匣未打空）不播——此时 on_play_head_stopped 大多数情况下
## 根本不会被触发到（见上面的函数头注释：动画没播完就被下一发重新触发），但仍按 ch2_in_reload 兜底过滤，
## 防止极端帧对齐下误触发。
func on_play_head_stopped() -> void:
	if bmp_reload == null or current_bm != bmp_ranged:
		return
	var clip_size: int = int(weapon.get("clip_size", 1))
	if clip_size > 1 and not ch2_in_reload:
		return
	_is_reloading = true
	current_bm = bmp_reload
	cur_frame = 0
	play_head_stance = PLAYING

## 装填中被打断去走路、回来后要恢复装填动画而不是重放一遍射击动画——一代 set_stance(RANGED_SHOOT) 的
## 默认实现只认 bmp_ranged，会把 cur_frame 清零重播，从而在 attack_counter 还没到点时提前又触发一次
## DONE 帧（等于白给一发）。只在"确实在装填中"时拦一下，其余情况照一代原样处理。
func set_stance(param1: int) -> void:
	if param1 == RANGED_SHOOT and _is_reloading and cur_stanse != DEAD and bmp_reload != null:
		cur_stanse = RANGED_SHOOT
		if current_bm != bmp_reload:
			current_bm = bmp_reload
			cur_frame = 0
		play_head_stance = PLAYING
		sens_mouse_enabled = true
		return
	super.set_stance(param1)

func _maybe_queue_special() -> void:
	if queued_special != "":
		return
	for id: String in weapon.get("skills", []):
		var spec: Ch2SpecialAmmo = special_slots.get(id)
		if spec == null or not spec.can_use_special():
			continue
		if _special_ready(id):
			queued_special = id
			spec.reset_counter()
			return

func _special_ready(id: String) -> bool:
	match id:
		"steady_aim", "heartpiercer":
			return still_counter >= int(Ch2WeaponDef.skill(id).get("still_frames", 60))
		"scattershot":
			return _count_enemies_within(float(Ch2WeaponDef.skill("scattershot").get("radius_px", 120))) >= int(Ch2WeaponDef.skill("scattershot").get("min_targets", 3))
		_:
			return true

func _count_enemies_within(radius: float) -> int:
	var count := 0
	for u: LivingObject in GameUniverse.inst.a_all_units:
		if u.friendly != friendly and u.cur_health > 0:
			if Vector2(u.position).distance_to(Vector2(position)) <= radius:
				count += 1
	return count
