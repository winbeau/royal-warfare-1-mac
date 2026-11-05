extends Control
signal activated(symbol: int, instance: String)
@export var symbol_id := 0
var labels: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		var key := str(child.get_meta("original_instance", ""))
		if key.begins_with("eAchievement") or key in ["eHint", "eUnitUnlockedBar", "eStorageFailure", "eFader", "eFocus", "eNewEnemy", "eSmallHint", "eGotUpgrade", "eGamePausedMessage", "eNewHint", "eSubDown"]:
			child.hide()
		if child is TextureButton:
			child.pressed.connect(func(): activated.emit(symbol_id, key))
			if child.texture_normal:
				var mask := BitMap.new()
				mask.create_from_image_alpha(child.texture_normal.get_image(), 0.05)
				child.texture_click_mask = mask

func element(key: String) -> Control:
	return get_node_or_null(NodePath(key))

func conceal(keys: Array) -> void:
	for key in keys:
		var node := element(str(key))
		if node: node.hide()

func set_text(key: String, value: String, font_size: int = 0) -> Label:
	var old := element(key)
	if not old: return null
	var label: Label = labels.get(key)
	if label == null:
		label = Label.new()
		label.name = "Text_" + key
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = old.position
		label.size = old.size
		for el in Content.scene_data[str(symbol_id)].elements:
			if el.name != key or not el.has("text"): continue
			var info: Dictionary = el.text
			var mat: Dictionary = info.matrix
			var a := float(mat.get("a", 1))
			var d := float(mat.get("d", 1))
			label.position = Vector2(float(mat.get("tx", 0)), float(mat.get("ty", 0)))
			label.size = Vector2(float(info.width) * a, float(info.height) * d)
			label.add_theme_font_size_override("font_size", int(float(info.attributes.get("size", 18)) * d))
			label.add_theme_color_override("font_color", Color(info.attributes.get("fillColor", "#ffffff")))
			if info.attributes.get("alignment", "left") == "center": label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			for record in Content.resources.values():
				if record.type != "font": continue
				for path in record.paths:
					if str(path).ends_with("_" + str(info.attributes.get("face", "")) + ".ttf"):
							label.add_theme_font_override("font", load("res://" + path))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if float(info.height) > 60 else TextServer.AUTOWRAP_OFF
		add_child(label)
		labels[key] = label
	old.hide()
	label.text = value
	if font_size > 0: label.add_theme_font_size_override("font_size", font_size)
	return label
