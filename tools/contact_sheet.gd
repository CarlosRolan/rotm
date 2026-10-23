extends SceneTree
## Joins a burst of numbered screenshots (prefix_00.png, prefix_01.png...) into one grid.
## Usage: Godot_console.exe --headless -s res://tools/contact_sheet.gd -- <prefix> <count> <out.png> [crop_w crop_h]
func _init():
	var a := OS.get_cmdline_user_args()
	var prefix := a[0]; var count := int(a[1]); var out := a[2]
	var cw := int(a[3]) if a.size() > 3 else 420
	var ch := int(a[4]) if a.size() > 4 else 400
	var cols := 3
	var rows := int(ceil(count / float(cols)))
	var sheet := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	for i in count:
		var img := Image.load_from_file("%s_%02d.png" % [prefix, i])
		img.convert(Image.FORMAT_RGBA8)
		var src := Rect2i((img.get_width() - cw) / 2, (img.get_height() - ch) / 2 + 40, cw, ch)
		sheet.blit_rect(img, src, Vector2i((i % cols) * cw, (i / cols) * ch))
	sheet.save_png(out)
	quit()
