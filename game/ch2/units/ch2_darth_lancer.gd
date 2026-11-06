## WP-D1 D1.6：达思重骑（敌方）。马+骑手合成：马身是 Ch2BmpFrames 纸娃娃（iron_skeleton_horse，
## 资源未就位前退到 outrider_saber 占位，动作名按占位体系映射），骑手直接复用一代原版
## undeadDarthKnight{Stay,Walk,Attack}Ani 的帧，按 assets/ch2/units/darth_rider/rider.json 的 cut_y
## 只截取上半身贴在马的 hip 接点上（见 docs/ch2-spotlight-spec.md D1.6 与用户 2026-11-06 的美术改动）。
## 状态机 ENTERING -> FORM -> COMMIT -> CHARGE -> IMPACT -> MELEE：manage_walk_normal() 在 cur_target
## 为 null 时每帧调用（search_target 在非 MELEE 阶段不设目标，天然保持 cur_target == null），借用这个
## 钩子推进前五个阶段，不需要改 living_object.gd。MELEE 阶段把 search_target 交还给 MeleeFighter。
## ENTERING：出生点在画面外（一代 set_route 的惯例），沿自己的路线正常走路（交还 MeleeFighter 继承的
## manage_walk_normal），直到走到路线上第一个落在画面内的点再切到 FORM（规格 D1.6 用户 2026-11-06 追加）。
class_name Ch2DarthLancer
extends MeleeFighter

enum State { ENTERING, FORM, COMMIT, CHARGE, IMPACT, MELEE }

static var cached_unit_data: SimpleCache

static func cache(n: int = 0) -> void:
	cached_unit_data = SimpleCache.new(Ch2DarthLancer, n, true)

static func init_resources() -> void:
	cache(20)

var lancer_cfg: Dictionary = {}
var state: int = State.ENTERING
var is_mounted: bool = true

var form_counter: int = 0
var charge_start_point: Vector2 = Vector2.ZERO
var charge_dir: Vector2 = Vector2.RIGHT
var dust_counter: int = 0
var impact_counter: int = 0
var has_charged: bool = false

## 冲锋目标锚点：没有可见玩家团块时退回这个点。用户 2026-11-06 追加：取关卡 protect 目标的中心
## （第 23 关是港门），由 Ch2Director._advance_spawn_jobs 在 load_enemy 之后注入；默认屏幕中心兜底。
var charge_target_anchor: Vector2 = Vector2(350, 300)

var bmp_form: Ch2BmpFrames = null
var bmp_charge: Ch2BmpFrames = null
var _horse_body_id_cache: String = ""
var _horse_is_placeholder: bool = false

const PLACEHOLDER_ACTION_MAP := {"form": "idle", "walk": "walk", "charge": "run", "fight": "attack", "death": "death"}

func init() -> void:
	kind = Ch2Kinds.CH2_DARTH_LANCER
	class_kind = CLASS_WARRIOR
	sens_class = ""
	lancer_cfg = Ch2WeaponDef.weapon("darth_lancer")
	super.init()
	var sens_size: Array = lancer_cfg.get("sens_size", [34, 40])
	Ch2Paperdoll.setup_sens(self, float(sens_size[0]), float(sens_size[1]))
	var shadow_size: Array = lancer_cfg.get("shadow_size", [34, 9])
	Ch2Paperdoll.add_shadow(self, float(shadow_size[0]), float(shadow_size[1]))
	_apply_horse_paperdoll()

func update_stats() -> void:
	money_cost = 0

func return_to_cache() -> void:
	cached_unit_data.set_data(_instance)

func after_adding_new_unit_handler() -> void:
	state = State.ENTERING
	form_counter = 0
	has_charged = false
	is_mounted = true

## 达思重骑的等级固定在出生时由 upgrade(level) 套用，不靠战斗经验自动升级——必须整份重写：
## 一代默认 got_experience() 在 exp_to_next_level 为 0（本类从不设置这个字段）时，任何一次伤害都会
## 立即判定"经验满"，继而 upgrade_clicked() -> upgrade()（本类重写的版本）把 health/cur_health 整个
## 重置回满血，等于白给无敌。必须整份重写为空操作，不能只调 super（那正是触发 bug 的那份默认实现）。
func got_experience(_param1: float) -> void:
	pass

func upgrade(param1: int = -1) -> void:
	var lvl: int = clampi(param1 if param1 != -1 else 1, 1, 3)
	cur_level = lvl
	var idx: int = lvl - 1
	health = int((lancer_cfg.get("health", [220, 230, 240]) as Array)[idx])
	armor = float((lancer_cfg.get("armor", [0.6, 0.7, 0.8]) as Array)[idx])
	max_magic_resist = float((lancer_cfg.get("resist", [0.2, 0.2, 0.2]) as Array)[idx])
	armor_piercing_melee = float((lancer_cfg.get("armor_pierce_melee", [0.2, 0.2, 0.3]) as Array)[idx])
	max_armor_piercing_melee = armor_piercing_melee
	var interval: int = int((lancer_cfg.get("attack_interval", [60, 60, 60]) as Array)[idx])
	attack_interval = interval
	max_attack_interval = interval
	damage = int((lancer_cfg.get("damage", [12, 13, 14]) as Array)[idx])
	max_damage = damage
	max_walk_speed = float(lancer_cfg.get("walk_speed", 1.3))
	cur_health = health
	ui_health_bar.reset_health(cur_health, health)

func hit_test_sens(stage_point: Vector2) -> bool:
	return Ch2Paperdoll.hit_test_bbox(self, stage_point)

## 非 MELEE 阶段不主动索敌（保持 cur_target == null，让 update() 一直落到 manage_walk_normal 分支）。
func search_target(param1: bool = false) -> void:
	if state == State.MELEE:
		super.search_target(param1)

## ENTERING/FORM/COMMIT/CHARGE/IMPACT 五个阶段都在这里推进（cur_target 为 null 时 update() 每帧调用本函数）。
func manage_walk_normal() -> void:
	match state:
		State.ENTERING:
			_tick_entering()
		State.FORM:
			_tick_form()
		State.COMMIT:
			_tick_commit()
		State.CHARGE:
			_tick_charge()
		State.IMPACT:
			_tick_impact()
		_:
			super.manage_walk_normal()

## 出生在画面外，交还 MeleeFighter 继承的路点行走；一旦走到画面内（5<x<695、5<y<595，与
## LivingObject.set_destination 的边界一致）就清空剩余路点，切到 FORM，整队点就是这里。
func _tick_entering() -> void:
	super.manage_walk_normal()
	if _in_screen(Vector2(position)):
		a_soldier_main_route = []
		state = State.FORM
		form_counter = 0

func _in_screen(p: Vector2) -> bool:
	return p.x > 5.0 and p.x < 695.0 and p.y > 5.0 and p.y < 595.0

func is_charging_or_committing() -> bool:
	return state == State.COMMIT or state == State.CHARGE

## 供 Ch2Warden 判断拒马走廊是否接触到自己：point 到冲锋直线的垂距；非冲锋状态返回 INF（恒不命中）。
func distance_to_charge_line(point: Vector2) -> float:
	if state != State.CHARGE:
		return INF
	var to_point: Vector2 = point - charge_start_point
	var along: float = to_point.dot(charge_dir)
	if along < 0.0:
		return point.distance_to(charge_start_point)
	var perp: Vector2 = to_point - charge_dir * along
	return perp.length()

# ---- FORM ----

func _tick_form() -> void:
	_set_pose_loop(bmp_form)
	form_counter += 1
	if form_counter >= int(lancer_cfg.get("form_wait_frames", 60)):
		state = State.COMMIT

# ---- COMMIT：同帧确定方向后立即进入 CHARGE，全程不再转向 ----

func _tick_commit() -> void:
	charge_start_point = Vector2(position)
	var target_point: Vector2 = _find_commit_target()
	var delta: Vector2 = target_point - charge_start_point
	charge_dir = delta.normalized() if delta.length() > 0.01 else Vector2(0, 1)
	sprite.scale.x = -1 if charge_dir.x < 0 else 1
	state = State.CHARGE

## 方向锥 ±25° 内最近的玩家团块中心（起测简化为最近的可控友军单位）；没有则用关卡给的 charge_target 锚点。
func _find_commit_target() -> Vector2:
	var best: LivingObject = null
	var best_d: float = INF
	for u: LivingObject in GameUniverse.inst.a_all_units:
		if not u.friendly or u.cur_health <= 0 or u.ch2_uncontrollable or u.is_npc:
			continue
		var d: float = Vector2(u.position).distance_to(Vector2(position))
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		return Vector2(best.position)
	return charge_target_anchor

# ---- CHARGE：沿直线推进，碰撞判定，拒马判定 ----

func _tick_charge() -> void:
	_set_pose_loop(bmp_charge)
	dust_counter += 1
	if dust_counter >= 4:
		dust_counter = 0
		Ch2Vfx.spawn("hoof_dust", Vector2(position) - charge_dir * 10.0, charge_dir.angle() + PI)
	var speed: float = float(lancer_cfg.get("charge_speed", 4.0))
	var next_pos: Vector2 = Vector2(position) + charge_dir * speed
	if next_pos.x < -50 or next_pos.x > 750 or next_pos.y < -50 or next_pos.y > 650:
		_enter_impact()
		return
	var path_bd: RWBitmapData = GameUniverse.inst.path_bd
	if path_bd != null and path_bd.get_pixel(int(next_pos.x), int(next_pos.y)) != 0:
		_enter_impact()
		return
	var hit_unit: LivingObject = _find_corridor_hit(next_pos)
	if hit_unit != null:
		_resolve_charge_hit(hit_unit)
		return
	set_coordinates(next_pos.x, next_pos.y)

## 走廊宽 14px，只看马头前方一小段（沿冲锋方向投影 -10..24px 内）。
func _find_corridor_hit(next_pos: Vector2) -> LivingObject:
	var corridor_half: float = 7.0
	var nearest: LivingObject = null
	var nearest_along: float = INF
	for u: LivingObject in GameUniverse.inst.a_all_units:
		if not u.friendly or u.cur_health <= 0 or u == _instance or u.ch2_uncontrollable or u.is_npc:
			continue
		var to_u: Vector2 = Vector2(u.position) - next_pos
		var along: float = to_u.dot(charge_dir)
		if along < -10.0 or along > 24.0:
			continue
		var perp: Vector2 = to_u - charge_dir * along
		if perp.length() <= corridor_half and along < nearest_along:
			nearest = u
			nearest_along = along
	return nearest

func _resolve_charge_hit(unit: LivingObject) -> void:
	if unit is Ch2Warden:
		var warden: Ch2Warden = unit
		if warden.brace_active:
			var warden_facing := Vector2(warden.sprite.scale.x, 0.0)
			var ang_deg: float = rad_to_deg(absf(charge_dir.angle_to(warden_facing)))
			if ang_deg > 120.0:
				warden.resolve_horsebreaker_hit()
				has_charged = true
				is_mounted = false
				bring_damage(health + 9999, unit, true)
				return
	_impact_unit(unit)

func _impact_unit(unit: LivingObject) -> void:
	has_charged = true
	var eff_armor: float = maxf(unit.cur_armor - armor_piercing_melee, 0.0)
	var dmg: int = int(float(lancer_cfg.get("charge_impact_damage", 45)) * (1.0 - eff_armor))
	got_experience(1)
	unit.bring_damage(dmg, _instance, true)
	if unit.cur_health > 0:
		unit.stunned(int(lancer_cfg.get("charge_impact_stun", 30)))
		var perp: Vector2 = Vector2(-charge_dir.y, charge_dir.x) * 20.0
		var dest: Vector2 = Vector2(unit.position) + perp
		var path_bd: RWBitmapData = GameUniverse.inst.path_bd
		if path_bd == null or path_bd.get_pixel(int(dest.x), int(dest.y)) == 0:
			unit.set_coordinates(dest.x, dest.y)
	_enter_impact()

# ---- IMPACT ----

func _enter_impact() -> void:
	state = State.IMPACT
	impact_counter = 0
	_set_pose_stop(bmp_form, 0)

func _tick_impact() -> void:
	impact_counter += 1
	if impact_counter >= int(lancer_cfg.get("impact_wait_frames", 45)):
		state = State.MELEE

# ---- 马+骑手纸娃娃 ----

func _horse_body_id() -> String:
	if _horse_body_id_cache != "":
		return _horse_body_id_cache
	var real_id: String = str(lancer_cfg.get("horse_body", "iron_skeleton_horse"))
	if FileAccess.file_exists("res://assets/ch2/units/%s/body.json" % real_id):
		_horse_body_id_cache = real_id
		_horse_is_placeholder = false
	else:
		_horse_body_id_cache = str(lancer_cfg.get("placeholder_horse_body", "outrider_saber"))
		_horse_is_placeholder = true
	return _horse_body_id_cache

func _horse_action(semantic: String) -> String:
	_horse_body_id()  # 确保 _horse_is_placeholder 已就绪
	if _horse_is_placeholder:
		return str(PLACEHOLDER_ACTION_MAP.get(semantic, semantic))
	return semantic

func _apply_horse_paperdoll() -> void:
	var body_id: String = _horse_body_id()
	bmp_form = Ch2BmpFrames.from_body(body_id, _horse_action("form"))
	bmp_charge = Ch2BmpFrames.from_body(body_id, _horse_action("charge"))
	bmp_walk = Ch2BmpFrames.from_body(body_id, _horse_action("walk"))
	bmp_attack = Ch2BmpFrames.from_body(body_id, _horse_action("fight"))
	bmp_stay = bmp_form
	bmp_dead = Ch2BmpFrames.from_body(body_id, _horse_action("death"))
	sprite.set_meta("ch2_weapon", null)
	sprite.set_meta("ch2_offhand", null)

## 绕开 set_stance：FORM/COMMIT/IMPACT 恢复姿势用的循环帧（没有 STOPPED 语义，手动钉在第 i 帧）。
func _set_pose_stop(bm: Ch2BmpFrames, frame_idx: int) -> void:
	if bm == null:
		return
	current_bm = bm
	cur_frame = clampi(frame_idx, 0, bm.num_frames - 1)
	play_head_stance = STOPPED
	_show_frame(cur_frame)

## CHARGE 用：循环播放（frame_commands 全 0），让 main_alg_update_sprite 自己逐帧推进。
func _set_pose_loop(bm: Ch2BmpFrames) -> void:
	if bm == null:
		return
	if current_bm != bm:
		current_bm = bm
		cur_frame = 0
		play_head_stance = PLAYING

## 一代原版符号 id：undeadDarthKnightStayAni=821、WalkAni=3382、AttackAni=2311（与 rider.json 的顶层键一致）。
const RIDER_SYMBOL_STAY := "821"
const RIDER_SYMBOL_WALK := "3382"
const RIDER_SYMBOL_ATTACK := "2311"

## 骑手贴图叠在马身 ch2_body 之上（同一个 sprite 下新增一个子节点，画在 ch2_body 之后、因此在马之上）。
## 每帧按 rider.json 给出的该帧 cut_y 只截取上半身，再把骑手自己这一帧的 hip 对准马当前帧的 hip（已经
## 是 sprite 本地坐标，马是 2x 图缩放 0.5 显示，骑手直接用一代原版帧按 1 倍显示，两者在同一个本地坐标系里）。
func _show_frame(i: int) -> void:
	super._show_frame(i)
	_update_rider_overlay()

func _update_rider_overlay() -> void:
	if not is_mounted:
		var old: Node = sprite.get_node_or_null("ch2_rider")
		if old != null:
			old.visible = false
		return
	var rider := sprite.get_node_or_null("ch2_rider") as Sprite2D
	if rider == null:
		rider = Sprite2D.new()
		rider.name = "ch2_rider"
		rider.centered = false
		sprite.add_child(rider)
	var symbol_id: String = _rider_symbol_for_state()
	var rider_bm: BmpFrames = BmpFrames.from_symbol(_rider_symbol_name(symbol_id))
	if rider_bm == null:
		rider.visible = false
		return
	var frame_i: int = _rider_frame_for_state(rider_bm)
	rider_bm.apply_frame(rider, frame_i)
	var cut: Dictionary = _rider_cut(symbol_id, frame_i)
	var cut_y: float = float(cut.get("cut_y", 999.0))
	var hip_arr: Array = cut.get("hip", [0.0, 0.0])
	var rider_hip := Vector2(float(hip_arr[0]), float(hip_arr[1]))
	rider.region_enabled = true
	rider.region_rect = Rect2(0, 0, rider.texture.get_width() if rider.texture != null else 1, cut_y)
	# apply_frame 已把 rider.offset 设成该符号的包围盒偏移（使包围盒左上角落在节点本地原点）；
	# 再减去骑手自己这一帧的 hip，使 hip 点本身落在节点本地原点，才能直接用 position 对齐马的 hip。
	rider.offset -= rider_hip
	var horse_hip: Vector2 = sprite.get_meta("ch2_hip", Vector2.ZERO)
	rider.position = horse_hip
	rider.visible = true

func _rider_symbol_for_state() -> String:
	match state:
		State.MELEE:
			return RIDER_SYMBOL_ATTACK
		State.CHARGE:
			return RIDER_SYMBOL_STAY
		_:
			return RIDER_SYMBOL_WALK

func _rider_symbol_name(symbol_id: String) -> String:
	match symbol_id:
		RIDER_SYMBOL_STAY:
			return str(lancer_cfg.get("rider_stay_symbol", "undeadDarthKnightStayAni"))
		RIDER_SYMBOL_ATTACK:
			return str(lancer_cfg.get("rider_attack_symbol", "undeadDarthKnightAttackAni"))
		_:
			return str(lancer_cfg.get("rider_walk_symbol", "undeadDarthKnightWalkAni"))

## MELEE 阶段伤害结算以马身 fight 行的 DONE 帧为准（_show_frame 由 main_alg_update_sprite 按 current_bm=
## bmp_attack 驱动，二者共用同一个 cur_frame 计数，这里骑手攻击帧直接跟着 cur_frame 走，不单独计数）；
## 其余阶段骑手用循环动画的第一帧（待机/行走姿势，不逐帧精确同步马的步频，起测简化）。
func _rider_frame_for_state(rider_bm: BmpFrames) -> int:
	if state == State.MELEE:
		return clampi(cur_frame, 0, rider_bm.num_frames - 1)
	return 0

static var _rider_cut_json_cache: Dictionary = {}
static var _rider_cut_loaded: bool = false

## rider.json：{"821":[{cut_y,hip:[x,y]}, ...], "3382":[...], "2311":[...]}，键是一代符号 id，
## 数组下标是该符号的帧号（与 BmpFrames.num_frames 对应）。
func _rider_cut(symbol_id: String, frame_i: int) -> Dictionary:
	if not _rider_cut_loaded:
		_rider_cut_loaded = true
		var path: String = str(lancer_cfg.get("rider_cut_json", "res://assets/ch2/units/darth_rider/rider.json"))
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_rider_cut_json_cache = parsed
	var frames: Array = _rider_cut_json_cache.get(symbol_id, [])
	if frame_i >= 0 and frame_i < frames.size():
		return frames[frame_i]
	return {"cut_y": 999.0, "hip": [0.0, 0.0]}

# ---- 普攻：MELEE 阶段伤害结算以骑手攻击帧的 DONE 为准（on_play_head_done -> attack_done，沿用一代） ----
# （attack_done 不重写：普通伤害沿用 MeleeFighter/LivingObject 默认流程即可，这里只需要动画叠加。）

# ---- 死亡 / 下马两种“人马分离”收尾 ----

## 人马俱碎（陌刀普攻、拒马斩命中）：bring_damage 的正常死亡流程会调用到这里，补一对纯视觉效果。
func after_health_below_zero_handler() -> void:
	is_mounted = false
	var pos := Vector2(position)
	var flip: bool = sprite.scale.x < 0
	Ch2OneShotBmp.spawn(Ch2BmpFrames.from_body(_horse_body_id(), _horse_action("death")), pos, flip)
	Ch2OneShotBmp.spawn(BmpFrames.from_symbol(str(lancer_cfg.get("rider_dead_symbol", "undeadDarthKnightDeadAni"))), pos + Vector2(sprite.scale.x, 0.0) * 14.0, flip)
	super.after_health_below_zero_handler()

## 斩马刀命中：斩倒战马，骑手被迫下马。原重骑对象静默移除（不算击杀、不给经验），原地生成一代
## UNDEAD_DARTH_KNIGHT 步兵，继承等级/血量比例/目标，刚下马眩晕 45 帧；马身播一次 death 行作纯特效。
func dismount() -> void:
	if not is_mounted:
		return
	is_mounted = false
	var ratio: float = float(cur_health) / float(maxi(health, 1))
	var spawn_pos := Vector2(position)
	var lvl: int = cur_level
	var tgt: LivingObject = cur_target
	var route_num: int = cur_route_number
	var flip: bool = sprite.scale.x < 0
	_silent_remove()
	Ch2OneShotBmp.spawn(Ch2BmpFrames.from_body(_horse_body_id(), _horse_action("death")), spawn_pos, flip)
	var rider: LivingObject = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_DARTH_KNIGHT, lvl, route_num, spawn_pos)
	rider.cur_health = maxi(1, int(rider.health * ratio))
	if tgt != null and tgt.cur_health > 0:
		rider.set_target(tgt, false)
	rider.stunned(45)

## 静默移除：复用一代 bring_damage 死亡分支的收尾（make_unit_dead/set_unit_dead/minus_units），
## 但不经过 bring_damage 本身，所以不触发 give_frag/calculate_death_cost/got_experience——
## 这正是“不算击杀、不给经验”的要求。
func _silent_remove() -> void:
	cur_health = 0
	remove_distant_attacker()
	GameUniverse.inst.make_unit_dead(_instance)
	if cur_battle != null:
		cur_battle.set_unit_dead(_instance)
	minus_units()
	ui_health_bar.update(0, cur_level)
	cur_stanse = DEAD
	sens_mouse_enabled = false
	visible = false
