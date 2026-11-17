extends SceneTree
## Opens a scene, waits some frames and saves a screenshot, for checking menus by eye.
## Run: Godot_console.exe --path . -s res://tools/scene_shot.gd -- <scene.tscn> <out.png> [frames] [--scene-args...]
## Arguments starting with "--" are left for the scene to read (e.g. the race selection's
## --race=<id>).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := int(args[2]) if args.size() > 2 and args[2].is_valid_int() else 60
	change_scene_to_file(args[0])
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
