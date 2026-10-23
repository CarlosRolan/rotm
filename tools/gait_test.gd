extends SceneTree
## Gait stress test: drives the player through abrupt manoeuvres (sprints, 180 turns,
## zigzags, stops, rocks, stepping stones, ramps) and prints foot metrics per segment.
## Run: Godot_console.exe --headless --path . -s res://tools/gait_test.gd
var level: Node
var player: CharacterBody3D
var rig: Node3D
var t := 0.0
var seg := -1
# [name, duration, heading_deg (or "zig"), speed, start_pos or null]
var segments := [
	["walk flat", 1.5, 0.0, 2.0, Vector3(0, 0, 4)],
	["run flat", 2.0, 0.0, 4.5, null],
	["sprint flat", 1.5, 0.0, 7.0, Vector3(40, 0, 30)],
	["sprint 180 turn", 1.5, 180.0, 7.0, null],
	["sprint zigzag", 2.5, "zig", 7.0, null],
	["run zigzag", 2.5, "zig", 4.5, null],
	["stop", 1.0, 0.0, 0.0, null],
	["sprint from stop", 1.5, 90.0, 7.0, null],
	["run rocks", 3.0, 0.0, 4.5, Vector3(0, 0, -15)],
	["sprint rocks", 2.0, 0.0, 7.0, Vector3(-6, 0, -16)],
	["run stones high", 3.0, 0.0, 4.5, Vector3(-18, 0, 1)],
	["run ramp 30 up", 2.0, 0.0, 4.5, Vector3(19, 0, 1)],
	["run ramp 20 down", 2.0, 180.0, 4.5, Vector3(14.5, 2.2, -9.5)],
]
var stats := {}

func _initialize():
	level = load("res://scenes/test_level.tscn").instantiate()
	root.add_child(level)
	player = level.get_node("Player")
	rig = player.get_node("SaurusRig")
	physics_frame.connect(_tick)

func _start(i: int):
	seg = i
	t = 0.0
	var s: Array = segments[i]
	if s[4] != null:
		player.global_position = s[4]
		player.velocity = Vector3.ZERO
		rig.reset_feet()
	stats = {"max_dist": 0.0, "max_planted": 0.0, "emergency": 0, "frames": 0, "speed": 0.0, "air": 0, "air_frames": 0, "last_mode": 0, "steep": 0.0, "tilt": 0.0}

func _tick():
	if seg < 0:
		_start(0)
	var s: Array = segments[seg]
	var dt := 1.0 / Engine.physics_ticks_per_second
	t += dt
	var heading: float
	if s[2] is String:
		heading = 45.0 if int(t / 0.4) % 2 == 0 else -45.0
	else:
		heading = s[2]
	var h := deg_to_rad(heading)
	if s[3] > 0.0:
		player.debug_move = Vector3(-sin(h), 0, -cos(h))
		player.debug_speed = s[3]
	else:
		player.debug_move = Vector3.ZERO
	# metrics (skip the first 0.3 s of each segment)
	if rig.mode == 1:
		stats.air_frames += 1
		if stats.last_mode != 1: stats.air += 1
	stats.last_mode = rig.mode
	if t > 0.3 and rig.mode == 0:
		var spd := Vector2(player.velocity.x, player.velocity.z).length()
		stats.speed += spd
		stats.frames += 1
		for f in rig.feet:
			if not f.swinging:
				var rest: Vector3 = rig._rest_point(f)
				var d := Vector2(f.plant.x - rest.x, f.plant.z - rest.z).length()
				stats.max_dist = maxf(stats.max_dist, d)
				stats.steep = maxf(stats.steep, rad_to_deg(Vector3.UP.angle_to(f.plant_normal)))
				stats.tilt = maxf(stats.tilt, rad_to_deg(Vector3.UP.angle_to(rig.foot_up(f))))
				if d > rig.MAX_FOOT_REACH:
					stats.emergency += 1
				if spd > 1.0:
					f.set_meta("planted", f.get_meta("planted", 0.0) + dt)
					stats.max_planted = maxf(stats.max_planted, f.get_meta("planted"))
			else:
				f.set_meta("planted", 0.0)
	if t >= s[1]:
		print("%-18s avg %.1f m/s | foot max dist from hip %.2f m | longest stance while moving %.2f s | out-of-reach %d | foothold max %.0f° foot tilt max %.0f°" % [
			s[0], stats.speed / maxf(stats.frames, 1), stats.max_dist, stats.max_planted, stats.emergency, stats.steep, stats.tilt])
		if seg + 1 >= segments.size():
			quit()
		else:
			_start(seg + 1)
