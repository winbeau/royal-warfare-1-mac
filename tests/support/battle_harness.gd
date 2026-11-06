extends RefCounted
# 战斗端到端测试的公共部分：按原版 Main.loadGame -> gameUniverse.init 的流程初始化指定关卡，
# 逐帧调用与 _physics_process 相同的入口（global_update），并计数运行期脚本错误。
# 界面类使用 GameUniverse 自己创建的实例（HUD 子代理移植中的类）；不可用时由调用方在 start 前注入替身。

## 捕获引擎日志中的脚本错误（SCRIPT ERROR / push_error）。警告不计。
class ErrorCatcher extends Logger:
	var errors: Array = []
	## 界面层错误不再放过，全部计入 errors；ui_errors 仅为兼容旧输出，恒为空。
	var ui_errors: Dictionary = {}
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var msg := "%s:%d %s %s %s" % [file, line, function, code, rationale]
		errors.append(msg)

var catcher := ErrorCatcher.new()
var tree: SceneTree
var gu: GameUniverse = null

func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	OS.add_logger(catcher)

func shutdown() -> void:
	stop_level()
	OS.remove_logger(catcher)

## 全新安装的默认存档（隔离模式只写内存），ExtDataManager 与静态单例就绪。
func boot() -> void:
	StoredData.test_wipe()
	StoredData.init()
	# Main.loadResources case 76：soundLibrary.init、new Sounds().initSoundsFirst（Sounds 为 autoload 节点 SoundSystem）
	if SoundLibrary.inst == null:
		SoundLibrary.new().init()
	if Sounds.inst == null:
		tree.root.get_node("SoundSystem").init_sounds_first(StoredData.main_params)
	if ExtDataManager.inst == null:
		ExtDataManager.new().init()
	if GameUniverse.selection_ramka == null:
		GameUniverse.init_once()
	if Main.inst == null:
		Main.new()  # 原版 Main.self（关卡钩子 Main.inst.addTutorial 等）
	var tw := RWTween.inst_()
	tw.manual_clock = true
	RWTween.reset()

func stop_level() -> void:
	if gu != null and is_instance_valid(gu):
		RWTween.kill_all(false)
		if gu.get_parent() != null:
			gu.get_parent().remove_child(gu)
		gu.free()
	gu = null

## 丢弃所有兵种的对象池（Main.loadResources 的 cache(n) 在新进程里重建），使每次试验从相同的池状态开始。
func reset_unit_pools() -> void:
	for cls in GameUniverse.A_LIVING_CLASSES:
		var scr := GameUniverse._living_script(cls)
		if scr == null:
			continue
		var old: Variant = scr.get("cached_unit_data")
		if old is SimpleCache:
			for inst in old._instances:
				if is_instance_valid(inst) and inst.get_parent() == null:
					var hb: Variant = inst.get("ui_health_bar")
					if hb is Node and is_instance_valid(hb) and hb.get_parent() == null:
						hb.free()
					inst.free()
		scr.set("cached_unit_data", null)

## 与 reset_unit_pools 同类问题，但对象是 VisualsTemplate 的特效/投射物静态对象池（SimpleCache），
## 例如 GroundDefFlag：battle_all_levels 在同一进程里连续跑 24 关，stop_level() 的 gu.free() 会把当时
## 仍挂在场景树上（尚未经 alpha_and_remove/set_data 正式"归还"）的池化实例一并递归释放掉，但它们在各自
## 类的静态 SimpleCache._instances 里仍有引用——下次 get_data() 翻到那个槽位就会命中已释放实例
## （"Trying to return a previously freed instance"）。每局开始前把这些类的池清空重建，和 reset_unit_pools
## 对单位池的处理一致。
const A_EFFECT_CLASSES: Array[String] = [
	"ArrowEx", "BackstabVisual", "BetrayVisual", "BlessVisual", "BlockedVisual", "BloodEx",
	"BrokenArrowVisual", "CallConfusionVisual", "CantMoveVisual", "CoinVisual", "CorpseExplosionVisual",
	"CorruptVisual", "CritVisual", "CurseVisual", "EnchantVisual", "FbSmokeVisual", "FlashVisual",
	"FleeVisual", "FreeMoveVisual", "GitGlowVisual", "GroundDefFlag", "GroundFlagAttack",
	"GroundFlagHeal", "GroundFlagMove", "HarmResistVisual", "HeadShotEffectVisual", "HealEffectEx",
	"HoldGroundVisual", "IceVisual", "MissVisual", "ParryVisual", "PoisonEffectVisual", "RegenVisual",
	"RessurectEffectVisual", "RockFallingVisual", "RoundAttackEffectVisual", "RoundAttackVisual",
	"SilencedVisual", "SlowEffectVisual", "SmallFireballEx", "StrongHealVisual", "StunnedEffectVisual",
	"StunnedSmallWaveVisual", "StunnedWaveVisual", "SummonKingVisual", "SummonSingleVisual",
	"SummonVisual", "SuppressVisual", "TauntedVisual", "TauntVisual", "UnitKilledVisual",
	"WeaknessVisual", "WeakSpotEffectVisual",
]

func reset_effect_pools() -> void:
	for cls_name in A_EFFECT_CLASSES:
		var scr: Script = null
		for d in ProjectSettings.get_global_class_list():
			if d["class"] == cls_name:
				scr = load(d["path"])
				break
		if scr == null:
			continue
		var old: Variant = scr.get("_cached_data")
		if old is SimpleCache:
			for inst in (old as SimpleCache)._instances:
				if is_instance_valid(inst) and inst.get_parent() == null:
					inst.free()
		scr.set("_cached_data", null)

## 对应 Main.loadGame(level) -> fadeClearLoadUnfade：killAll、加入舞台、gameUni.init(level)。level 为 0 基下标（第 1 关 = 0）。
## chapter：二次开发参数（WP-B 用），GameUniverse.chapter 必须在 init() 之前写入才会走 LevelCh2 分支；默认 1，一代测试不受影响。
func start_level(level: int, rng_seed: int, difficulty: int = 1, fresh_pools: bool = true, chapter: int = 1) -> GameUniverse:
	stop_level()
	RWTween.reset()
	StoredData.local_game_data[StoredData.NUMPAN_DIFFICULTY] = difficulty
	if fresh_pools:
		reset_unit_pools()
		reset_effect_pools()
	RWRandom.set_seed(rng_seed)
	LivingObject.unit_num_warriors = 0
	gu = GameUniverse.new()
	gu.chapter = chapter
	tree.root.add_child(gu)
	gu.init(level)
	return gu

## 一个逻辑帧：_physics_process 的入口（global_update），随后 RWTween 墙钟推进 1/30 秒（TweenMax 不受 2x 速度影响）。
## 返回 global_update 前后单位生命值变化的拆分由调用方自行快照；这里把两个阶段分开暴露。
func logic_phase() -> void:
	gu._physics_process(1.0 / 30.0)
	# 引擎在 gu 之后按树序对其子节点调用 _physics_process。小火球是原版自播放的 MovieClip（第 13 帧派发 done），
	# 靠自己的 _physics_process 推进；这里照引擎行为补上（界面剪辑不在核心测试范围）。
	for f in gu.a_fireballs.duplicate():
		if is_instance_valid(f) and f.is_inside_tree():
			f._physics_process(1.0 / 30.0)

func tween_phase() -> void:
	RWTween.step(1.0 / 30.0)

## 关卡对话框打开时原版 pause()（移除 ENTER_FRAME 监听）并等待玩家点击翻页，最后一句点完 unpause()。
## 测试里等价于玩家立刻点完：复位 on_stage 并 unpause()。
func dismiss_chat() -> void:
	if gu.is_paused and not gu.is_end_game:
		ChatFrameController.on_stage = false
		gu.unpause()

func ended() -> bool:
	return gu.is_end_game and not gu._update_enabled

func frame() -> void:
	dismiss_chat()
	logic_phase()
	tween_phase()

func set_speed(speed: int) -> void:
	gu.cur_speed = speed

## 友军招募：复刻 mainGameUI_ex.selectedTierOne 的费用检查（costMultiplier * 已有数量 * 单价）后调用 addSoldier。
## 返回新单位，钱不够返回 null。
func recruit(kind: int) -> LivingObject:
	var cost := recruit_cost(kind)
	if cost < 0 or int(gu.current_money) < cost:
		return null
	return gu.add_soldier(kind)

func recruit_cost(kind: int) -> float:
	var mult: float = MainGameUIEx.inst.cost_multiplier
	match kind:
		LivingObject.FR_WARRIOR:
			return floorf(FriendWarrior.unit_cost + mult * LivingObject.unit_num_warriors * FriendWarrior.unit_cost)
		LivingObject.FR_ARCHER:
			return floorf(FriendArcher.unit_cost + mult * LivingObject.unit_num_archers * FriendArcher.unit_cost)
		LivingObject.FR_BLUEMAGE:
			return floorf(FriendBlueMage.unit_cost + mult * LivingObject.unit_num_mages * FriendBlueMage.unit_cost)
		LivingObject.FR_PRIEST:
			return floorf(FriendPriest.unit_cost + mult * LivingObject.unit_num_priests * FriendPriest.unit_cost)
		LivingObject.FR_ROGUE:
			return floorf(FriendScoutRogue.unit_cost + mult * LivingObject.unit_num_rogues * FriendScoutRogue.unit_cost)
	return -1.0

## 选中给定单位并发出命令：target 非 null 为对敌人下令（pursuit），否则移动/攻击移动到 pos。attack 对应“攻击”按钮。
func order(units: Array, pos: Vector2, target: LivingObject = null, attack: bool = true) -> void:
	for u in gu.a_selected_units:
		if is_instance_valid(u):
			u.unselect()
	gu.a_selected_units = []
	for u in units:
		if u.cur_health > 0:
			gu.a_selected_units.append(u)
			u.set_selected()
	if gu.a_selected_units.is_empty():
		return
	MainGameUIEx.is_attack_button_clicked = attack
	MainGameUIEx.is_formation_clicked = false
	gu.mouse_override = pos
	gu.ground_clicked(RWMouseEvent.new(pos.x, pos.y), target)
	gu.mouse_override = null
	MainGameUIEx.is_attack_button_clicked = false

func friends() -> Array:
	var out: Array = []
	for u in gu.a_all_units:
		if u.friendly and u.cur_health > 0 and not u.is_npc:
			out.append(u)
	return out

func enemies() -> Array:
	var out: Array = []
	for u in gu.a_all_units:
		if not u.friendly and u.cur_health > 0:
			out.append(u)
	return out

func nearest(from: LivingObject, list: Array) -> LivingObject:
	var best: LivingObject = null
	var bd := INF
	for u in list:
		var d: float = from.position.distance_to(u.position)
		if d < bd:
			bd = d
			best = u
	return best

## 简单自动招募：每 30 帧尝试招募一名战士，其次弓手/牧师等（受原版费用公式限制）。
func auto_recruit(kinds: Array) -> void:
	for k in kinds:
		var u := recruit(k)
		if u != null:
			return

## 每 15 帧：全体（国王除外）攻击最近的敌人，没有敌人则待在原地。
func auto_orders() -> void:
	var fr := friends()
	var fighters: Array = []
	for u in fr:
		if u.kind != LivingObject.FR_KING:
			fighters.append(u)
	if fighters.is_empty():
		return
	var en := enemies()
	if en.is_empty():
		return
	var lead: LivingObject = fighters[0]
	var tgt := nearest(lead, en)
	if tgt != null:
		order(fighters, tgt.position, tgt, true)
