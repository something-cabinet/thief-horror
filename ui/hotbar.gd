extends Control
class_name HotbarUI

const SLOT_COUNT := 5

var slot_panels: Array[PanelContainer] = []
var slot_icons: Array[TextureRect] = []
var prompt_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func update_slots(items: Array[Dictionary], selected_index: int) -> void:
	if slot_panels.is_empty():
		return
	for index in SLOT_COUNT:
		var item: Dictionary = items[index] if index < items.size() else {}
		slot_icons[index].texture = item.get("icon") as Texture2D
		slot_icons[index].visible = not item.is_empty()
		slot_panels[index].z_index = 1 if index == selected_index else 0
		slot_panels[index].add_theme_stylebox_override(
			"panel",
			_make_slot_style(index == selected_index)
		)


func set_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text


func _build_ui() -> void:
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-260, -116)
	prompt_label.size = Vector2(520, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.74))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	prompt_label.add_theme_constant_override("outline_size", 5)
	add_child(prompt_label)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-190, -76)
	bar.size = Vector2(380, 76)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	# Adjacent borders overlap into a single seam. The selected panel's higher
	# z-index keeps its gold outline intact across those shared edges.
	bar.add_theme_constant_override("separation", -2)
	add_child(bar)

	for index in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(76, 76)
		panel.z_index = 1 if index == 0 else 0
		panel.add_theme_stylebox_override("panel", _make_slot_style(index == 0))
		bar.add_child(panel)
		slot_panels.append(panel)

		var content := Control.new()
		content.custom_minimum_size = Vector2(64, 64)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(content)

		var number := Label.new()
		number.text = str(index + 1)
		number.position = Vector2(4, 2)
		number.size = Vector2(20, 18)
		number.add_theme_font_size_override("font_size", 12)
		number.add_theme_color_override("font_color", Color(0.78, 0.78, 0.75))
		content.add_child(number)

		var icon := TextureRect.new()
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -27
		icon.offset_top = -27
		icon.offset_right = 27
		icon.offset_bottom = 27
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		content.add_child(icon)
		slot_icons.append(icon)


func _make_slot_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.07, 0.9)
	style.border_color = Color(0.95, 0.84, 0.48, 1.0) if selected else Color(0.28, 0.3, 0.32, 0.95)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
