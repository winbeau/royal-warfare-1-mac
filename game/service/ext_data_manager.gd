# 移植自 S/gameCore/serviceUtils/extDataManager.as
# 原版把 24 关 + 教学关 + 兵种参数的 XML 嵌入 SWF；这里读取 data/xml/*_extDataManager_<名>.xml（按需解析并缓存）。
class_name ExtDataManager
extends RefCounted

const XML_DIR := "res://data/xml/"

static var inst: ExtDataManager

var _cache: Dictionary = {}  # 名字 -> RWXml
var _files: Dictionary = {}  # 名字 -> 路径

func _init() -> void:
	inst = self

func init() -> void:
	inst = self
	_files = {}
	for f in DirAccess.get_files_at(XML_DIR):
		var m := f.get_basename()
		var k := m.find("_extDataManager_")
		if k >= 0:
			_files[m.substr(k + "_extDataManager_".length())] = XML_DIR + f
	# 原版 init 一次载入全部；这里在首次使用时才解析，结果相同
	_cache = {}

func _get_xml(key: String) -> RWXml:
	if _files.is_empty():
		init()
	if not _cache.has(key):
		if not _files.has(key):
			push_error("ExtDataManager: no xml for %s" % key)
			return null
		_cache[key] = RWXml.load_file(_files[key])
	return _cache[key]

## getLevelXML(n)：n == -2 取教学关（aLevels[24]），否则取第 n 关（0 起）。
func get_level_xml(param1: int) -> RWXml:
	if param1 != -2:
		return _get_xml("extlvl%d" % (param1 + 1))
	return _get_xml("extlvlIntro")

func get_units_xml() -> RWXml:
	return _get_xml("units")
