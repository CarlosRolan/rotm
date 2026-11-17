extends Node3D
## Race-selection screen: pick one of the three Kaurka subraces, see it standing in its own
## setting, turn it around, read its lore and enter the test level with it.
##
## Drag with the mouse to turn the model (160 degrees) and tilt the camera (15 degrees up
## or down). Esc goes back to the title screen.
##
## Debug: `-- --race=<id> --shot-yaw=<deg> --shot-pitch=<deg> --anim=<name|pose> --no-ui` set
## the starting view (for screenshots with tools/scene_shot.gd).

const MAX_PITCH_DEG := 15.0
const DRAG_SPEED := 0.006  ## radians per pixel
const FOV := 38.0
const LEFT_PANEL := Rect2(32, -170, 300, 340)
const RIGHT_PANEL_WIDTH := 430.0
const MARGIN := 32.0
const NOTICE_COLOUR := Color(1.0, 0.72, 0.38)

var _races: Array[RaceData] = []
var _race: RaceData
var _shown: RaceData
var _pitch_target := 0.0
var _focus_height := 1.1
var _distance := 4.6
var _dragging := false
var _switching := false
var _snap_camera := true

var _race_buttons: Array[Button] = []
var _name_label: Label
var _epithet_label: Label
var _lore_text: RichTextLabel
var _height_label: Label
var _strength_label: Label
var _notice_label: Label
var _anim_box: HBoxContainer
var _fade: ColorRect
var _ui_layer: CanvasLayer

@onready var _background_slot: Node3D = $Background
@onready var _preview: ModelPreview = $Preview
@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_camera.fov = FOV
	_races = RaceCatalog.all()
	_build_ui()
	_preview.animations_changed.connect(_on_animations_changed)

	var args := _user_args()
	var first: RaceData = RaceCatalog.find(args.get("race", "")) if args.has("race") else null
	_select(first if first else _races[0])
	if args.has("shot-yaw"):
		_preview.set_yaw(deg_to_rad(float(args["shot-yaw"])))
	if args.has("shot-pitch"):
		_pitch_target = deg_to_rad(clampf(float(args["shot-pitch"]), -MAX_PITCH_DEG, MAX_PITCH_DEG))
	if args.has("no-ui"):
		_ui_layer.visible = false
	if args.has("anim"):
		_preview.play("" if args["anim"] == "pose" else args["anim"])


func _process(delta: float) -> void:
	var k := 1.0 if _snap_camera else 1.0 - exp(-6.0 * delta)
	_snap_camera = false
	_pivot.position.y = lerpf(_pivot.position.y, _focus_height, k)
	_camera.position.z = lerpf(_camera.position.z, _distance, k)
	_pivot.rotation.x = lerpf(_pivot.rotation.x, _pitch_target, 1.0 - exp(-10.0 * delta))
	# Centre the model in the space left between the side panels.
	var size := get_viewport().get_visible_rect().size
	var free_centre := (LEFT_PANEL.end.x + size.x - RIGHT_PANEL_WIDTH - MARGIN) * 0.5
	var half_width := _camera.position.z * tan(deg_to_rad(FOV * 0.5)) * size.x / size.y
	_camera.h_offset = (size.x * 0.5 - free_centre) / (size.x * 0.5) * half_width


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
	elif event.is_action_pressed("ui_cancel"):
		_back()


# Motion and release are read here, so a drag that started on the backdrop keeps going
# when the pointer passes over a panel.
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
	elif event is InputEventMouseMotion:
		_preview.turn(event.relative.x * DRAG_SPEED)
		var limit := deg_to_rad(MAX_PITCH_DEG)
		_pitch_target = clampf(_pitch_target - event.relative.y * DRAG_SPEED, -limit, limit)


## Picks a race; the backdrop and model swap behind a short fade to black.
func _select(race: RaceData) -> void:
	_race = race
	for i in _races.size():
		_race_buttons[i].set_pressed_no_signal(_races[i] == race)
	if _switching:
		return  # the running swap picks up the latest choice
	_switching = true
	if _shown:
		await create_tween().tween_property(_fade, "color:a", 1.0, 0.15).finished
	while _shown != _race:
		_show_race(_race)
		await get_tree().process_frame
	await create_tween().tween_property(_fade, "color:a", 0.0, 0.35).finished
	_switching = false


func _show_race(race: RaceData) -> void:
	_shown = race
	for child in _background_slot.get_children():
		child.free()
	if race.background:
		_background_slot.add_child(race.background.instantiate())
	_preview.set_yaw(deg_to_rad(ModelPreview.START_YAW_DEG))
	_preview.show_model(RaceCatalog.preview_model(race), race.height_m)
	_focus_height = race.height_m * 0.55
	_distance = race.height_m * 2.25 + 0.3
	_snap_camera = true

	_name_label.text = race.display_name
	_name_label.add_theme_color_override("font_color", race.accent)
	_epithet_label.text = race.epithet
	_lore_text.text = race.lore
	_lore_text.scroll_to_line(0)
	_height_label.text = race.height_text
	_strength_label.text = race.strength
	_notice_label.text = RaceCatalog.notice(race)
	_notice_label.visible = _notice_label.text != ""


func _enter() -> void:
	Session.choose_race(_race)
	get_tree().change_scene_to_file(ScenePaths.TEST_LEVEL)


func _back() -> void:
	get_tree().change_scene_to_file(ScenePaths.START_MENU)


func _on_animations_changed(names: PackedStringArray) -> void:
	for child in _anim_box.get_children():
		child.queue_free()
	if names.is_empty():
		_anim_box.add_child(MenuTheme.label("Sin animaciones: pose por defecto", 15, MenuTheme.MUTED))
		return
	_anim_box.add_child(MenuTheme.label("Animación:", 15, MenuTheme.MUTED))
	var group := ButtonGroup.new()
	for anim_name in names:
		_anim_box.add_child(_anim_button(anim_name, anim_name, group))
	_anim_box.add_child(_anim_button("Pose por defecto", "", group))


func _anim_button(text: String, anim_name: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = anim_name == _preview.current_animation
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_preview.play.bind(anim_name))
	return button


# --- Interface -----------------------------------------------------------------------

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var root := Control.new()
	root.theme = MenuTheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(root)

	var title := MenuTheme.label("ELIGE TU RAZA", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock(title, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 18, 300, 64))
	root.add_child(title)

	# Left: the three subraces.
	var left := PanelContainer.new()
	_dock(left, Vector4(0, 0.5, 0, 0.5), Vector4(LEFT_PANEL.position.x, LEFT_PANEL.position.y, LEFT_PANEL.end.x, LEFT_PANEL.end.y))
	root.add_child(left)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	left.add_child(list)
	list.add_child(MenuTheme.label("KAURKAS", 16, MenuTheme.BORDER))
	var group := ButtonGroup.new()
	for race in _races:
		var button := _race_button(race, group)
		_race_buttons.append(button)
		list.add_child(button)

	# Right: lore of the selected race.
	var right := PanelContainer.new()
	_dock(right, Vector4(1, 0, 1, 1), Vector4(-RIGHT_PANEL_WIDTH - MARGIN, 78, -MARGIN, -112))
	root.add_child(right)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	right.add_child(info)
	_name_label = MenuTheme.label("", 36)
	info.add_child(_name_label)
	_epithet_label = MenuTheme.label("", 18, MenuTheme.MUTED)
	info.add_child(_epithet_label)
	info.add_child(HSeparator.new())
	_lore_text = RichTextLabel.new()
	_lore_text.bbcode_enabled = true
	_lore_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_text.add_theme_font_size_override("normal_font_size", 16)
	_lore_text.add_theme_font_size_override("bold_font_size", 16)
	info.add_child(_lore_text)
	info.add_child(HSeparator.new())
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 16)
	info.add_child(stats)
	stats.add_child(MenuTheme.label("Altura", 16, MenuTheme.MUTED))
	_height_label = MenuTheme.label("", 16)
	stats.add_child(_height_label)
	stats.add_child(MenuTheme.label("Destaca en", 16, MenuTheme.MUTED))
	_strength_label = MenuTheme.label("", 16)
	stats.add_child(_strength_label)
	_notice_label = MenuTheme.label("", 14, NOTICE_COLOUR)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_notice_label)

	# Bottom: animations and how to turn the model.
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock(bottom, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -110, 300, -24))
	root.add_child(bottom)
	_anim_box = HBoxContainer.new()
	_anim_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_anim_box.add_theme_constant_override("separation", 8)
	bottom.add_child(_anim_box)
	var hint := MenuTheme.label("Arrastra con el ratón para girar el modelo", 14, MenuTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)

	var back := Button.new()
	back.text = "Volver"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_back)
	_dock(back, Vector4(0, 1, 0, 1), Vector4(MARGIN, -84, MARGIN + 180, -30))
	root.add_child(back)

	var enter := Button.new()
	enter.text = "Entrar"
	enter.add_theme_font_size_override("font_size", 28)
	enter.pressed.connect(_enter)
	_dock(enter, Vector4(1, 1, 1, 1), Vector4(-MARGIN - 300, -96, -MARGIN, -30))
	root.add_child(enter)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 2
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)


## Toggle button with the race's name and epithet, outlined in its colour when chosen.
func _race_button(race: RaceData, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(0, 74)
	var chosen := MenuTheme.box(MenuTheme.BUTTON_PRESSED, race.accent, 2, 10)
	chosen.border_width_left = 6
	button.add_theme_stylebox_override("pressed", chosen)
	button.add_theme_stylebox_override("hover_pressed", chosen)
	button.pressed.connect(_select.bind(race))
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.set_anchors_preset(Control.PRESET_FULL_RECT)
	texts.offset_left = 16
	button.add_child(texts)
	var name_label := MenuTheme.label(race.display_name, 22)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var epithet := MenuTheme.label(race.epithet, 14, MenuTheme.MUTED)
	epithet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(epithet)
	return button


## Anchors (left, top, right, bottom) and pixel offsets for a control.
static func _dock(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH


func _user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args
