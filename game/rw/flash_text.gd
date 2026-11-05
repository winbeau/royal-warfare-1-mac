class_name FlashText
extends Control
## Runtime counterpart of a Flash DefineEditText (TextField). Position/scale come from the node transform;
## the text box is `box` (the SWF bounds, relative to the node origin).

const GUTTER := 2.0
const FONT_MAP_PATH := "res://assets/clips/fonts.json"
static var _font_map: Dictionary = {}
static var _font_cache: Dictionary = {}

@export var box := Rect2(0, 0, 100, 20)
@export var font_id := -1
@export var font: Font
@export var font_face := ""
@export var font_size := 12.0
@export var color := Color.BLACK
@export_enum("left", "right", "center", "justify") var align := "left"
@export var leading := 0.0
@export var left_margin := 0.0
@export var right_margin := 0.0
@export var multiline := false
@export var word_wrap := false
@export var is_html := false
@export var border := false
## "none" | "left" | "center" | "right" (AS3 TextFieldAutoSize)
@export var auto_size := "none":
	set(value):
		auto_size = value
		_relayout()
@export var shadow_color := Color(0, 0, 0, 0)
@export var shadow_offset := Vector2.ZERO
@export var initial_text := ""

var text: String:
	get:
		return _plain
	set(value):
		_plain = value
		_html = false
		_source = value
		_refresh()
var html_text: String:
	get:
		return _source if _html else _plain
	set(value):
		_html = true
		_source = value
		_plain = _strip_tags(value)
		_refresh()

var _plain := ""
var _source := ""
var _html := false
var _rtl: RichTextLabel
var _box_now := Rect2()
var _ready_done := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_rtl = RichTextLabel.new()
	_rtl.name = "_text"
	_rtl.bbcode_enabled = true
	_rtl.scroll_active = false
	_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rtl.focus_mode = Control.FOCUS_NONE
	_rtl.clip_contents = false
	_rtl.fit_content = false
	_rtl.add_theme_constant_override(&"line_separation", int(round(leading)))
	_rtl.add_theme_color_override(&"default_color", Color(color.r, color.g, color.b, 1.0))
	_rtl.modulate.a = color.a
	if shadow_color.a > 0.0:
		_rtl.add_theme_color_override(&"font_shadow_color", shadow_color)
		_rtl.add_theme_constant_override(&"shadow_offset_x", int(round(shadow_offset.x)))
		_rtl.add_theme_constant_override(&"shadow_offset_y", int(round(shadow_offset.y)))
	var f := get_font()
	if f:
		for key in [&"normal_font", &"bold_font", &"italics_font", &"bold_italics_font", &"mono_font"]:
			_rtl.add_theme_font_override(key, f)
	_rtl.add_theme_font_size_override(&"normal_font_size", int(round(font_size)))
	_rtl.add_theme_font_size_override(&"bold_font_size", int(round(font_size)))
	_rtl.add_theme_font_size_override(&"italics_font_size", int(round(font_size)))
	_rtl.add_theme_font_size_override(&"bold_italics_font_size", int(round(font_size)))
	add_child(_rtl, false, Node.INTERNAL_MODE_FRONT)
	_ready_done = true
	_box_now = box
	if _source == "" and initial_text != "":
		if is_html:
			html_text = initial_text
		else:
			text = initial_text
	else:
		_refresh()

func get_font() -> Font:
	return font

## Resolves a Flash face name (as used in <font face="...">) to a ttf in assets/library/font.
static func font_for_face(face: String) -> Font:
	if _font_map.is_empty() and FileAccess.file_exists(FONT_MAP_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONT_MAP_PATH))
		if parsed is Dictionary:
			_font_map = parsed.get("faces", {})
	var key := face.to_lower().strip_edges()
	if _font_map.has(key):
		return _load_font(str(_font_map[key]))
	return null

static func _load_font(path: String) -> Font:
	if not _font_cache.has(path):
		_font_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _font_cache[path]

func get_text_width() -> float:
	return _rtl.get_content_width() if _rtl else 0.0

func get_text_height() -> float:
	return _rtl.get_content_height() if _rtl else 0.0

func _refresh() -> void:
	if not _ready_done:
		return
	if _html:
		_rtl.text = html_to_bbcode(_source, font_face)
	else:
		_rtl.text = _escape(_source)
	_relayout()

func _relayout() -> void:
	if not _ready_done:
		return
	var inner := Rect2(box.position + Vector2(GUTTER + left_margin, GUTTER), box.size - Vector2(GUTTER * 2.0 + left_margin + right_margin, GUTTER * 2.0))
	_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if word_wrap else TextServer.AUTOWRAP_OFF
	match align:
		"center": _rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"right": _rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"justify": _rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
		_: _rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if auto_size != "none" and not word_wrap:
		# shrink-wrap the box around the text, keeping the left edge / centre / right edge fixed
		_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_rtl.fit_content = true
		_rtl.size = Vector2(1, 1)
		var w := _rtl.get_content_width()
		var h := _rtl.get_content_height()
		var origin := box.position.x + GUTTER + left_margin
		match auto_size:
			"center": origin += (inner.size.x - w) * 0.5
			"right": origin += inner.size.x - w
		_rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_rtl.position = Vector2(origin, inner.position.y)
		_rtl.size = Vector2(w + 1.0, h)
	else:
		_rtl.fit_content = false
		_rtl.position = inner.position
		_rtl.size = inner.size
	queue_redraw()

func _draw() -> void:
	if border:
		draw_rect(box, Color.BLACK, false)

static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")

static func _strip_tags(s: String) -> String:
	var rx := RegEx.create_from_string("<[^>]*>")
	return _unentity(rx.sub(s.replace("<br>", "\n").replace("<br/>", "\n"), "", true))

static func _unentity(s: String) -> String:
	return s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&nbsp;", " ").replace("&amp;", "&")

## Converts the Flash TextField HTML subset (font size/color/face, p align, br, b, i, u, a) to BBCode.
static func html_to_bbcode(html: String, base_face := "") -> String:
	var out := ""
	var stack: Array = []   # entries: [tag, closing bbcode]
	var tag_rx := RegEx.create_from_string("<(/?)([a-zA-Z]+)([^>]*)>")
	var attr_rx := RegEx.create_from_string("([a-zA-Z]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')")
	var pos := 0
	for m in tag_rx.search_all(html):
		out += _escape(_unentity(html.substr(pos, m.get_start() - pos)))
		pos = m.get_end()
		var closing := m.get_string(1) == "/"
		var tag := m.get_string(2).to_lower()
		if closing:
			for i in range(stack.size() - 1, -1, -1):
				if stack[i][0] == tag:
					out += stack[i][1]
					stack.remove_at(i)
					break
			continue
		var attrs := {}
		for a in attr_rx.search_all(m.get_string(3)):
			attrs[a.get_string(1).to_lower()] = a.get_string(2) if a.get_string(2) != "" else a.get_string(3)
		match tag:
			"br":
				out += "\n"
			"b":
				out += "[b]"
				stack.append(["b", "[/b]"])
			"i":
				out += "[i]"
				stack.append(["i", "[/i]"])
			"u":
				out += "[u]"
				stack.append(["u", "[/u]"])
			"a":
				out += "[url=%s]" % attrs.get("href", "")
				stack.append(["a", "[/url]"])
			"p":
				var al: String = str(attrs.get("align", "")).to_lower()
				var open := ""
				var close := ""
				match al:
					"center": open = "[center]"; close = "[/center]"
					"right": open = "[right]"; close = "[/right]"
					"justify": open = "[fill]"; close = "[/fill]"
				out += open
				stack.append(["p", close + "\n"])
			"font":
				var open2 := ""
				var close2 := ""
				if attrs.has("color"):
					open2 += "[color=%s]" % attrs.color
					close2 = "[/color]" + close2
				if attrs.has("size"):
					open2 += "[font_size=%d]" % int(round(float(str(attrs.size).lstrip("+-"))))
					close2 = "[/font_size]" + close2
				if attrs.has("face") and str(attrs.face).to_lower() != base_face.to_lower():
					var f := font_for_face(str(attrs.face))
					if f != null:
						open2 += "[font=%s]" % f.resource_path
						close2 = "[/font]" + close2
				out += open2
				stack.append(["font", close2])
	out += _escape(_unentity(html.substr(pos)))
	for i in range(stack.size() - 1, -1, -1):
		out += stack[i][1]
	return out
