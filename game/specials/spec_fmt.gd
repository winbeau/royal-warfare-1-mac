# 非原版类：AS3 中 "字符串" + Number 的隐式转换（整数值不带小数点，NaN 写 "NaN"）。
# 仅供 curLevelParams 的 HTML 文本使用；原版没有对应的类。
class_name SpecFmt
extends RefCounted

static func n(v: float) -> String:
	if is_nan(v):
		return "NaN"
	if is_inf(v):
		return "Infinity" if v > 0 else "-Infinity"
	if v == floorf(v) and absf(v) < 1.0e15:
		return str(int(v))
	return str(v)
