extends Control
## Title screen. Start goes to the race selection; Debug drops straight into the test level
## with the model already in use there (picked with Tab inside the level).


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	theme = MenuTheme.build()

	var backdrop := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.13, 0.06, 0.12), Color(0.02, 0.02, 0.03)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.35)
	texture.fill_to = Vector2(1.1, 1.1)
	backdrop.texture = texture
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := MenuTheme.label("ROTM", 96)
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := MenuTheme.label("Los Kaurkas", 26, MenuTheme.BORDER)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36
	box.add_child(spacer)

	var start := _button("Start", _on_start)
	box.add_child(start)
	box.add_child(_button("Debug", _on_debug))
	box.add_child(_button("Salir", get_tree().quit))
	start.grab_focus.call_deferred()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 54)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	return button


func _on_start() -> void:
	Session.clear()
	get_tree().change_scene_to_file(ScenePaths.RACE_SELECT)


func _on_debug() -> void:
	Session.clear()
	get_tree().change_scene_to_file(ScenePaths.TEST_LEVEL)
