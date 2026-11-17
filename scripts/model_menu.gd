class_name ModelMenu
extends CanvasLayer
## Test-level menu for picking which character model the player uses, and for going back
## to the title screen. Opens with Tab; the game pauses while it is open. The model choice
## is remembered between runs.

const TOGGLE_KEY := KEY_TAB

var rig: SaurusRig

var _panel: PanelContainer
var _list: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == TOGGLE_KEY:
		close() if _panel.visible else open()
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	for child in _list.get_children():
		child.queue_free()
	var first: Button = null
	for m in ModelCatalog.scan():
		var button := Button.new()
		button.text = m.name
		button.toggle_mode = true
		button.button_pressed = m.path == rig.model_path
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_pick.bind(m.path))
		_list.add_child(button)
		if first == null or button.button_pressed:
			first = button
	if first == null:
		var empty := Label.new()
		empty.text = "No hay modelos con esqueleto en imported_models/"
		_list.add_child(empty)
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if first:
		first.grab_focus.call_deferred()


func close() -> void:
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ScenePaths.START_MENU)


func _pick(path: String) -> void:
	if path != rig.model_path and rig.load_model(path):
		rig.reset_feet()
		ModelCatalog.remember(path)
	close()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.09, 0.92)
	style.border_color = Color(0.36, 0.30, 0.52)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 320
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Modelo de prueba"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	_list = VBoxContainer.new()
	box.add_child(_list)

	var main_menu := Button.new()
	main_menu.text = "Menú principal"
	main_menu.pressed.connect(_to_main_menu)
	box.add_child(main_menu)

	var hint := Label.new()
	hint.text = "Tab: abrir / cerrar este menú"
	hint.modulate = Color(1, 1, 1, 0.55)
	box.add_child(hint)
