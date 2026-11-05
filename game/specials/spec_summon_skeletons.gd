# 移植自 S/gameCore/specials/specSummonSkeletons.as
class_name SpecSummonSkeletons
extends SpecialTemplate

var me = null  # private，mageClass（untyped）

func _init() -> void:
	cur_spec_level = get_spec_level(false, 1)
	number_in_panel = 40
	a_time_until_update = [12]
	time_until_update = a_time_until_update[0] * 30
	special_description = "<p>Summon</p>" + "<p>Summons a pack of skeletons</p>"

# 注意：原版每次施法 timeUntilUpdate += 60（即冷却每次增加 2 秒），保留。
# param1 为 mageClass（untyped）
func check_summon(param1) -> bool:
	if can_use_special():
		reset_counter()
		time_until_update += 60
		me = param1
		var loc2: SimpleCache = SummonVisual.cached_data
		var loc3: SummonVisual = loc2.get_data() as SummonVisual
		loc3.added_to_stage(param1.position.x, param1.position.y, summoned, null, true)
		loc3.scale.x = param1.get_view_direction
		param1.set_casting_stance()
		return true
	return false

# 原版展开成两组各 5 段重复代码（视向 > 0 与否），这里用偏移表表示；每个骷髅的调用顺序不变：
# loadEnemy -> modifyFirstPoint -> setViewDirection -> (有目标则 setTarget) -> stunned(randRange(1, 16))。
func summoned() -> void:
	var loc2: SoundLibrary = SoundLibrary.inst
	Sounds.inst.play(loc2.get_sound(SoundLibrary.SUMMON), false, 0, 0.4, me.position.x, SoundLibrary.SUMMON)
	var offsets: Array
	if me.get_view_direction > 0:
		offsets = [
			Vector2(-20 - 6, 13 - 4),
			Vector2(22 - 6, 13 - 4),
			Vector2(26 - 6, -7 - 4),
			Vector2(-29 - 6, -9 - 4),
			Vector2(-2 - 6, -17 - 4),
		]
	else:
		offsets = [
			Vector2(20 + 6, 13 - 3),
			Vector2(-22 + 6, 13 - 3),
			Vector2(-26 + 6, -7 - 3),
			Vector2(29 + 6, -9 - 3),
			Vector2(2 + 6, -17 - 3),
		]
	for off in offsets:
		var loc1: LivingObject = GameUniverse.inst.load_enemy(LivingObject.UNDEAD_SKELETON, me.get_level, me.get_route_number(), Vector2(me.position.x + off.x, me.position.y + off.y))
		loc1.modify_first_point()
		loc1.set_view_direction = int(me.get_view_direction)
		if me.get_cur_target != null:
			loc1.set_target(me.get_cur_target)
		loc1.stunned(RWRandom.rand_range(1, 16))
