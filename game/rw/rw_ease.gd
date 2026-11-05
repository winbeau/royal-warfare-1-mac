# 移植自 S/com/greensock/easing/{Linear,Cubic,Elastic}.as 与 TweenLite.easeOut（默认缓动）
# 所有函数签名为 (t, b, c, d)：TweenLite 恒以 (time, 0, 1, duration) 调用。
class_name RWEase
extends RefCounted

const _2PI := PI * 2.0

## TweenLite.defaultEase = TweenLite.easeOut：1 - (1 - t/d)^2（即 Quad.easeOut 的形状）
static func default_ease_out(t: float, _b: float, _c: float, d: float) -> float:
	t = 1.0 - t / d
	return 1.0 - t * t

static func linear_ease_none(t: float, b: float, c: float, d: float) -> float:
	return c * t / d + b

static func linear_ease_in(t: float, b: float, c: float, d: float) -> float:
	return c * t / d + b

static func linear_ease_out(t: float, b: float, c: float, d: float) -> float:
	return c * t / d + b

static func linear_ease_in_out(t: float, b: float, c: float, d: float) -> float:
	return c * t / d + b

static func cubic_ease_in(t: float, b: float, c: float, d: float) -> float:
	t = t / d
	return c * t * t * t + b

static func cubic_ease_out(t: float, b: float, c: float, d: float) -> float:
	t = t / d - 1.0
	return c * (t * t * t + 1.0) + b

static func cubic_ease_in_out(t: float, b: float, c: float, d: float) -> float:
	t = t / (d * 0.5)
	if t < 1.0:
		return c * 0.5 * t * t * t + b
	t = t - 2.0
	return c * 0.5 * (t * t * t + 2.0) + b

# Elastic 的 a（振幅）与 p（周期）默认 0，走原版的默认分支。
static func _elastic_s(c: float, d: float, a: float, p: float, p_default_mul: float) -> Array:
	if p == 0.0:
		p = d * p_default_mul
	var s: float
	if a == 0.0 or (c > 0.0 and a < c) or (c < 0.0 and a < -c):
		a = c
		s = p / 4.0
	else:
		s = p / _2PI * asin(c / a)
	return [a, p, s]

static func elastic_ease_in(t: float, b: float, c: float, d: float, a: float = 0.0, p: float = 0.0) -> float:
	if t == 0.0:
		return b
	t = t / d
	if t == 1.0:
		return b + c
	var aps := _elastic_s(c, d, a, p, 0.3)
	a = aps[0]; p = aps[1]
	var s: float = aps[2]
	t = t - 1.0
	return -(a * pow(2.0, 10.0 * t) * sin((t * d - s) * _2PI / p)) + b

static func elastic_ease_out(t: float, b: float, c: float, d: float, a: float = 0.0, p: float = 0.0) -> float:
	if t == 0.0:
		return b
	t = t / d
	if t == 1.0:
		return b + c
	var aps := _elastic_s(c, d, a, p, 0.3)
	a = aps[0]; p = aps[1]
	var s: float = aps[2]
	return a * pow(2.0, -10.0 * t) * sin((t * d - s) * _2PI / p) + c + b

static func elastic_ease_in_out(t: float, b: float, c: float, d: float, a: float = 0.0, p: float = 0.0) -> float:
	if t == 0.0:
		return b
	t = t / (d * 0.5)
	if t == 2.0:
		return b + c
	var aps := _elastic_s(c, d, a, p, 0.3 * 1.5)
	a = aps[0]; p = aps[1]
	var s: float = aps[2]
	if t < 1.0:
		t = t - 1.0
		return -0.5 * (a * pow(2.0, 10.0 * t) * sin((t * d - s) * _2PI / p)) + b
	t = t - 1.0
	return a * pow(2.0, -10.0 * t) * sin((t * d - s) * _2PI / p) * 0.5 + c + b
