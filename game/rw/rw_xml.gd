# 移植自 AS3 E4X 的只读子集（原版 XML/XMLList 访问：unitXML.warrior.Health.one、children()、length()、@attr、name()）
# 解析 data/xml/*.xml。注释、处理指令和纯空白文本被忽略（等同 ignoreComments / ignoreWhitespace 默认值）。
# 缺失的子节点返回空节点（E4X 的空 XMLList）：text() == ""，to_number() == 0，to_int() == 0，length() == 0。
class_name RWXml
extends RefCounted

static var EMPTY: RWXml = RWXml.new()

var _name := ""
var _text := ""
var _attrs: Dictionary = {}
var _children: Array = []
var _empty := true

## 从文件载入，返回根元素（E4X 中的 XML 根，其 children() 即第一层元素）。出错返回 null。
static func load_file(path: String) -> RWXml:
	if not FileAccess.file_exists(path):
		push_error("RWXml: missing file %s" % path)
		return null
	return parse(FileAccess.get_file_as_string(path))

static func parse(source: String) -> RWXml:
	var parser := XMLParser.new()
	if parser.open_buffer(source.to_utf8_buffer()) != OK:
		push_error("RWXml: cannot open buffer")
		return null
	var stack: Array = []
	var root: RWXml = null
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node := RWXml.new()
				node._empty = false
				node._name = parser.get_node_name()
				for i in parser.get_attribute_count():
					node._attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				if not stack.is_empty():
					stack.back()._children.append(node)
				elif root == null:
					root = node
				if not parser.is_empty():
					stack.append(node)
			XMLParser.NODE_ELEMENT_END:
				if not stack.is_empty():
					stack.pop_back()
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not stack.is_empty():
					var raw := parser.get_node_data()
					if raw.strip_edges() != "":
						stack.back()._text += raw
	if root == null:
		push_error("RWXml: no root element")
	return root

func name() -> String:
	return _name

## XMLList.length()：空节点为 0，其余为 1。
func length() -> int:
	return 0 if _empty else 1

func is_empty() -> bool:
	return _empty

## 第一个名为 name 的子元素（E4X 的 xml.name；多个同名时按 xml.name[0] 取）。缺失返回空节点。
func child(child_name: String) -> RWXml:
	for c: RWXml in _children:
		if c._name == child_name:
			return c
	return EMPTY

## 所有名为 name 的子元素（XMLList，可按下标 [i] 访问）。
func child_list(child_name: String) -> Array:
	var out: Array = []
	for c: RWXml in _children:
		if c._name == child_name:
			out.append(c)
	return out

## children()：全部子元素，文档顺序。
func children() -> Array:
	return _children

func child_count() -> int:
	return _children.size()

## @attr；缺失返回 ""。
func attr(attr_name: String) -> String:
	return _attrs.get(attr_name, "")

func has_attr(attr_name: String) -> bool:
	return _attrs.has(attr_name)

## toString()：简单内容（叶子）返回其文本，去掉首尾空白由调用方决定（E4X 保留原文本，这里与其一致）。
## 带 path 参数时等价于 child(path).text()，路径只支持单层。
func text(child_name: String = "") -> String:
	if child_name != "":
		return child(child_name).text()
	return _text

## Number(x)：空串得 0，非法得 NaN，支持 0x 十六进制。
func to_number(child_name: String = "") -> float:
	return RWXml.as_number(text(child_name))

## int(x)：Number 后向零截断；NaN 得 0。
func to_int(child_name: String = "") -> int:
	var n := to_number(child_name)
	if is_nan(n) or is_inf(n):
		return 0
	return int(n)

static func as_number(s: String) -> float:
	var t := s.strip_edges()
	if t == "":
		return 0.0
	if t.begins_with("0x") or t.begins_with("0X"):
		return float(t.hex_to_int()) if t.substr(2).is_valid_hex_number() else NAN
	if t == "Infinity" or t == "+Infinity":
		return INF
	if t == "-Infinity":
		return -INF
	if t.is_valid_float():
		return t.to_float()
	return NAN
