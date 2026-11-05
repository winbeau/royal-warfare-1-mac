# 移植自 S/utils/Utility.as（xorshift32，状态为 AS3 uint）
class_name RWRandom
extends RefCounted

const MAX_RATIO := 1.0 / 4294967295.0  # 1 / uint.MAX_VALUE
const MASK := 0xFFFFFFFF

# 原版：private static var r:uint = Math.random() * uint.MAX_VALUE
static var r: int = int(randf() * 4294967295.0)

## AS3 的 `get rand`：r ^= r << 21; r ^= r >>> 35; r ^= r << 4; return r * MAX_RATIO
## `>>> 35` 的移位数按 mod 32 计算，即 `>>> 3`。返回值范围 [0, 1]（含 1）。
static func rand() -> float:
	r = (r ^ (r << 21)) & MASK
	r = (r ^ (r >> (35 & 31))) & MASK
	r = (r ^ (r << 4)) & MASK
	return r * MAX_RATIO

## randRange(a, b)：floor(rand * (b - a + 1)) + a。rand 恰为 1 时可得 b + 1（原版行为，保留）。
static func rand_range(a: int, b: int) -> int:
	return int(floor(rand() * (b - a + 1))) + a

## randomSort：供 Array.sort 使用的随机比较函数，消耗一次 rand。
static func random_sort(_a: Variant, _b: Variant) -> float:
	if rand() < 0.5:
		return -1.0
	return 1.0

## 测试和对拍用。种子 0 会令 xorshift 永远停在 0（与原版一致）。
static func set_seed(v: int) -> void:
	r = v & MASK

static func get_state() -> int:
	return r
