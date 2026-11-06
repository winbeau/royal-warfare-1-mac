## 二次开发（第二章）：任务导演。纯逻辑类，持有关卡 JSON 与 GameUniverse，
## 由 LevelCh2.level_custom_actions() 每个逻辑帧调用一次 update()。
##
## 阶段状态机 pending -> active -> done：
##   - when 条件为真时 pending 变 active，执行一次该阶段 do 列表里的全部动作；
##   - 本阶段所有 spawn 任务的出兵数都已调度完，且本阶段打开的招募窗口 / 对白 tag 都已关闭，才算 done。
##
## 招募窗口（recruit_window）和对白（dialogue）复用一代 GLOBAL_WAVE / GAME_CHAT 的现成处理：
## 导演只是把带 "ch2_tag" 的记录推进 GameUniverse.cur_wave_info，GameUniverse.main_update_function
## （未改动）按原逻辑打开红色按钮或聊天框、消耗完后把记录移出队列；导演轮询队列里是否还有该 tag
## 来判断窗口/对白是否已关闭，不必自己重实现 45 秒倒计时或翻页逻辑。
class_name Ch2Director
extends RefCounted

var gu: GameUniverse
var level_number: int
var data: Dictionary

var objectives: Array = []  # Array[Ch2ObjectiveBase]
var objectives_by_id: Dictionary = {}
var phases: Array = []  # Array[Dictionary]，见 _build_phase
var phases_by_id: Dictionary = {}
var flags: Dictionary = {}  # "<id>.<event>" -> true（一次置真后常驻）
var tags: Dictionary = {}  # recruit_window / dialogue 的 id -> "open" / "closed"

## 对白 tag 的关闭时机不能靠轮询 cur_wave_info：main_update_function 在"打开"聊天框的同一帧就
## remove_at(0) 了（GLOBAL_WAVE 则相反，是真正关闭时才出队），所以对白只能在 LevelCh2.chat_closed()
## 真正被调用（玩家点完最后一句、ChatFrameController.close_chat() 触发）时才知道关闭。按出队顺序
## FIFO：同一帧可能连续 push 多条对白，chat_closed() 每调用一次关掉队首那一条。
var _dialogue_tag_queue: Array = []
## recruit_window 的 id 列表：_poll_window_tags 只轮询这些 id（见上面的区分说明）。
var _window_tag_ids: Array = []

## 本关死亡的己方可控单位数（供 LevelCh2.compute_stars 用的 losses_max 条件）。
## 不用 LevelTemplate.friendly_unit_dead() 钩子（它不带参数，分不清是哪个单位死的，无法排除盟军/NPC）；
## 改为每帧扫 a_waiting_death，只统计 real_friendly 且非 NPC、非 ch2_uncontrollable 的单位，各自只计一次。
var losses := 0
var _counted_dead: Array = []

var _ended := false


func _init(p_gu: GameUniverse, p_level_number: int, p_data: Dictionary) -> void:
	gu = p_gu
	level_number = p_level_number
	data = p_data
	for o: Dictionary in data.get("objectives", []):
		var obj := _build_objective(o)
		if obj != null:
			objectives.append(obj)
			objectives_by_id[obj.id] = obj
	for p: Dictionary in data.get("phases", []):
		var ph := _build_phase(p)
		phases.append(ph)
		phases_by_id[str(ph["id"])] = ph


## 按 JSON 的 "type" 字段构造具体目标类型（见 game/ch2/objectives/*.gd 文件头的字段说明）。
func _build_objective(o: Dictionary) -> Ch2ObjectiveBase:
	match str(o.get("type", "")):
		"escort": return Ch2EscortObjective.new(o, self)
		"evac": return Ch2EvacObjective.new(o, self)
		"protect": return Ch2ProtectObjective.new(o, self)
		"pickup": return Ch2PickupObjective.new(o, self)
		"reach": return Ch2ReachObjective.new(o, self)
		"kill": return Ch2KillObjective.new(o, self)
		_:
			push_error("Ch2Director: unknown objective type %s" % o.get("type", ""))
			return null


func _build_phase(p: Dictionary) -> Dictionary:
	return {
		"id": str(p.get("id", "")),
		"when": p.get("when", {}),
		"do": p.get("do", []),
		"state": "pending",
		"activated_at": -1,
		"spawn_jobs": [],
		"opened_tags": [],
	}


func set_flag(name: String) -> void:
	flags[name] = true


## 由 LevelCh2.chat_closed() 转发：ChatFrameController.close_chat() 真正关闭对白框时调用。
func on_chat_closed() -> void:
	if not _dialogue_tag_queue.is_empty():
		var id: String = _dialogue_tag_queue.pop_front()
		tags[id] = "closed"


func enemies_alive() -> int:
	var n := 0
	for u: LivingObject in gu.a_all_units:
		if not u.friendly and u.cur_health > 0:
			n += 1
	return n


## 用户 2026-11-06 追加：重骑 COMMIT 阶段找不到玩家团块时，退回关卡 protect 目标的中心
## （第 23 关是港门）。没有 protect 目标时兜底屏幕中心，由 Ch2DarthLancer 的默认值承接。
func _protect_center() -> Vector2:
	for o: Ch2ObjectiveBase in objectives:
		if o is Ch2ProtectObjective:
			var p: Ch2ProtectObjective = o
			if is_instance_valid(p.facility):
				return Vector2(p.facility.position)
	return Vector2(350, 300)


func controllable_friends_alive() -> int:
	var n := 0
	for u: LivingObject in gu.a_all_units:
		if u.friendly and u.cur_health > 0 and not u.is_npc and not u.ch2_uncontrollable:
			n += 1
	return n


func cheapest_recruit_cost() -> float:
	# 与 MainGameUIEx 的招募公式一致：money_cost + costMultiplier * 已有数量 * money_cost，已有数量取 0（未锁定的最便宜兵种）。
	var best := INF
	for cls_name in ["friendWarrior", "friendArcher", "friendPriest"]:
		var scr := GameUniverse._living_script(cls_name)
		if scr != null:
			var cost: Variant = scr.get("unit_cost")
			if cost != null and float(cost) < best:
				best = float(cost)
	return best


## 每个逻辑帧调用一次：推进阶段状态机、更新全部目标对象、评估胜负。
func update() -> void:
	if _ended:
		return
	_track_losses()
	_poll_window_tags()
	for ph: Dictionary in phases:
		_update_phase(ph)
	for obj: Ch2ObjectiveBase in objectives:
		obj.update()
	if _eval_cond(data.get("failure", {})):
		_ended = true
		gu.end_game(GameUniverse.DEFEAT)
		return
	if _eval_cond(data.get("victory", {})):
		_ended = true
		gu.end_game(GameUniverse.VICTORY)


## recruit_window（GLOBAL_WAVE）只有真正关闭（45 秒倒计时跑完或 red_button_clicked()）才会被
## GameUniverse.main_update_function 从 cur_wave_info 移出队列（不像 GAME_CHAT 是一打开就出队），
## 所以这里可以直接轮询：open 的窗口 tag 一旦不再出现在队列里，就是关闭了。对白 tag 不在这里处理——
## 它一打开就已经不在队列里，必须靠 on_chat_closed() 的 FIFO 来判断真正关闭的时机。
func _poll_window_tags() -> void:
	for id in _window_tag_ids.duplicate():
		if str(tags.get(id, "")) == "open" and not _queue_has_tag(id):
			tags[id] = "closed"
			_window_tag_ids.erase(id)


func _queue_has_tag(id: String) -> bool:
	for w: Array in gu.cur_wave_info:
		if w[0] is Dictionary and str(w[0].get("ch2_tag", "")) == id:
			return true
	return false


func _track_losses() -> void:
	for u: LivingObject in gu.a_waiting_death:
		if u.real_friendly and not u.is_npc and not u.ch2_uncontrollable and _counted_dead.find(u) < 0:
			_counted_dead.append(u)
			losses += 1


func _update_phase(ph: Dictionary) -> void:
	match str(ph["state"]):
		"pending":
			if _eval_cond(ph["when"]):
				ph["state"] = "active"
				ph["activated_at"] = gu.global_counter
				for action: Dictionary in ph["do"]:
					_run_action(ph, action)
		"active":
			_advance_spawn_jobs(ph)
			if ph["spawn_jobs"].is_empty():
				var all_tags_closed := true
				for tag_id: String in ph["opened_tags"]:
					if str(tags.get(tag_id, "")) != "closed":
						all_tags_closed = false
						break
				if all_tags_closed:
					ph["state"] = "done"
		_:
			pass


func _advance_spawn_jobs(ph: Dictionary) -> void:
	var jobs: Array = ph["spawn_jobs"]
	var i := jobs.size() - 1
	while i >= 0:
		var job: Dictionary = jobs[i]
		if gu.global_counter >= int(job["ready_frame"]):
			if RWRandom.rand() > float(job["prob"]):
				var lvl: int = int(job["level"])
				if gu.dif_num == 2 and lvl < 3:
					lvl += 1
				elif gu.dif_num == 3:
					lvl = 3
				var e: LivingObject = gu.load_enemy(int(job["kind"]), lvl, int(job["route"]))
				if e is Ch2DarthLancer:
					(e as Ch2DarthLancer).charge_target_anchor = _protect_center()
				job["remaining"] = int(job["remaining"]) - 1
				if int(job["remaining"]) <= 0:
					jobs.remove_at(i)
		i -= 1


func _run_action(ph: Dictionary, action: Dictionary) -> void:
	if action.has("spawn"):
		var route: int = int(action.get("route", 1))
		var prob: float = float(action.get("prob", 0.97))
		var delay_frames: int = int(round(float(action.get("delay_s", 0.0)) * 30.0))
		for row: Array in action["spawn"]:
			ph["spawn_jobs"].append({
				"kind": Ch2Kinds.resolve(str(row[0])),
				"level": int(row[1]),
				"remaining": int(row[2]),
				"route": route,
				"prob": prob,
				"ready_frame": gu.global_counter + delay_frames,
			})
	elif action.has("recruit_window"):
		var win_id: String = str(action["recruit_window"])
		gu.cur_wave_info.append([{"type": LevelTemplate.GLOBAL_WAVE, "time": 0, "no_enemies": 0, "ch2_tag": win_id}])
		tags[win_id] = "open"
		ph["opened_tags"].append(win_id)
		_window_tag_ids.append(win_id)
	elif action.has("dialogue"):
		var ev_id: String = str(action["dialogue"])
		var lines: Array = []
		for line: Dictionary in Ch2Text.dialogue(ev_id):
			lines.append({
				"unitNumberInPanel": Ch2Kinds.resolve(_portrait_kind(str(line.get("speaker", "")))),
				"txt": "%s: %s" % [str(line.get("speaker", "")), str(line.get("en", ""))],
			})
		gu.cur_wave_info.append([{"type": LevelTemplate.GAME_CHAT, "time": 0, "no_enemies": 0, "ch2_tag": ev_id}, lines])
		tags[ev_id] = "open"
		ph["opened_tags"].append(ev_id)
		_dialogue_tag_queue.append(ev_id)
	elif action.has("warn"):
		_run_warn(action["warn"])
	elif action.has("objective_state"):
		var os: Dictionary = action["objective_state"]
		var obj: Ch2ObjectiveBase = objectives_by_id.get(str(os.get("id", "")), null)
		if obj != null:
			obj.apply_state_action(str(os.get("state", "")))


static var _portraits_cache: Dictionary = {}


static func _portrait_kind(speaker: String) -> String:
	if _portraits_cache.is_empty():
		var f := FileAccess.open("res://data/ch2/portraits.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_portraits_cache = parsed.get("speakers", {})
	return str(_portraits_cache.get(speaker, "FR_WARRIOR"))


func _run_warn(route_numb: int) -> void:
	var route: MapRoute = null
	for r: MapRoute in gu.a_path_map:
		if r.numb == route_numb:
			route = r
			break
	if route == null or route.a_points.is_empty():
		return
	var entry: Vector2 = route.a_points[0]
	var dir_word := "the area ahead"
	if entry.x >= 695:
		dir_word = "the east"
	elif entry.x <= 5:
		dir_word = "the west"
	elif entry.y <= 5:
		dir_word = "the north"
	elif entry.y >= 595:
		dir_word = "the south"
	gu._chat_message("Enemies approaching from %s." % dir_word)
	var marker: Node2D = gu._flag_data(GroundFlagMove)
	marker.added_to_stage(entry.x, entry.y)
	RWTween.delayed_call(3.0, func() -> void:
		if is_instance_valid(marker):
			marker.on_play_head_end())


## 条件求值：覆盖阶段触发（time_s/phase_done/cleared/flag/window_closed/dialogue_done）
## 与胜负判定（objective/phases_done/enemies_alive/objective_failed/no_combat_power），
## 外加结构性的 all/any 嵌套。两套词汇不会撞 key，这里合并成一个函数处理。
func _eval_cond(cond: Dictionary) -> bool:
	if cond.is_empty():
		return false
	if cond.has("all"):
		for c: Dictionary in cond["all"]:
			if not _eval_cond(c):
				return false
		return true
	if cond.has("any"):
		for c: Dictionary in cond["any"]:
			if _eval_cond(c):
				return true
		return false
	if cond.has("time_s"):
		# 全部阶段从关卡加载时就处于 pending（"等待开始"），time_s 因此总是相对关卡开始的 global_counter。
		return gu.global_counter >= int(round(float(cond["time_s"]) * 30.0))
	if cond.has("phase_done"):
		var p: Variant = phases_by_id.get(str(cond["phase_done"]), null)
		return p != null and str(p["state"]) == "done"
	if cond.has("cleared"):
		var p2: Variant = phases_by_id.get(str(cond["cleared"]), null)
		return p2 != null and str(p2["state"]) == "done" and enemies_alive() == 0
	if cond.has("flag"):
		return bool(flags.get(str(cond["flag"]), false))
	if cond.has("window_closed"):
		return str(tags.get(str(cond["window_closed"]), "")) == "closed"
	if cond.has("dialogue_done"):
		return str(tags.get(str(cond["dialogue_done"]), "")) == "closed"
	if cond.has("objective"):
		var o: Ch2ObjectiveBase = objectives_by_id.get(str(cond["objective"]), null)
		return o != null and o.is_complete()
	if cond.has("objective_failed"):
		var o2: Ch2ObjectiveBase = objectives_by_id.get(str(cond["objective_failed"]), null)
		return o2 != null and o2.is_failed()
	if cond.has("phases_done"):
		for p3: Dictionary in phases:
			if str(p3["state"]) != "done":
				return false
		return true
	if cond.has("enemies_alive"):
		return enemies_alive() == int(cond["enemies_alive"])
	if cond.has("no_combat_power"):
		return controllable_friends_alive() == 0 and float(gu.current_money) < cheapest_recruit_cost()
	return false
