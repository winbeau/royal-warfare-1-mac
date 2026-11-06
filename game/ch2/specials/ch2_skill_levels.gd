## WP-D1 提供的读取口（见 docs/ch2-spotlight-spec.md D2.3）：二章技能等级 1..3。
## D1 的各 SpecialTemplate 子类只读 get()；写入（升级面板加点、存档）由 WP-D2 负责调用 set()。
## 默认全部 1 级，不影响 D1 自身的测试与数值表现。
class_name Ch2SkillLevels
extends RefCounted

static var _levels: Dictionary = {}  # skill_id -> 1..3

static func get_level(skill_id: String) -> int:
	return int(_levels.get(skill_id, 1))

static func set_level(skill_id: String, level: int) -> void:
	_levels[skill_id] = clampi(level, 1, 3)

## 每升 1 级冷却 -10%（起测值，规格 D2.3）。
static func cooldown_frames(skill_id: String, base_frames: int) -> int:
	var lvl: int = get_level(skill_id)
	return maxi(1, int(round(base_frames * (1.0 - 0.1 * (lvl - 1)))))

## 每升 1 级效果 +15%（起测值，规格 D2.3）。
static func effect_mult(skill_id: String, base_mult: float = 1.0) -> float:
	var lvl: int = get_level(skill_id)
	return base_mult * (1.0 + 0.15 * (lvl - 1))
