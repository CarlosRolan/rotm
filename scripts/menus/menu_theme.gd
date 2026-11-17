class_name MenuTheme
## Shared look of the menus: dark translucent panels with a bone-coloured border,
## parchment text with a dark outline so it reads over the 3D backdrops.

const PANEL := Color(0.05, 0.04, 0.05, 0.84)
const BORDER := Color(0.62, 0.52, 0.36)
const TEXT := Color(0.93, 0.87, 0.75)
const MUTED := Color(0.72, 0.66, 0.57)
const BUTTON := Color(0.13, 0.11, 0.10, 0.92)
const BUTTON_HOVER := Color(0.22, 0.17, 0.13, 0.95)
const BUTTON_PRESSED := Color(0.36, 0.14, 0.09, 0.95)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 2, 18))
	theme.set_stylebox("panel", "Panel", box(PANEL, BORDER, 2, 18))

	theme.set_stylebox("normal", "Button", box(BUTTON, Color(0.36, 0.30, 0.24), 1, 10))
	theme.set_stylebox("hover", "Button", box(BUTTON_HOVER, BORDER, 1, 10))
	theme.set_stylebox("pressed", "Button", box(BUTTON_PRESSED, BORDER, 2, 10))
	theme.set_stylebox("hover_pressed", "Button", box(BUTTON_PRESSED.lightened(0.1), BORDER, 2, 10))
	theme.set_stylebox("disabled", "Button", box(Color(0.08, 0.07, 0.07, 0.8), Color(0.2, 0.18, 0.16), 1, 10))
	var focus := box(Color(0, 0, 0, 0), TEXT, 1, 10)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.4))
	theme.set_color("font_outline_color", "Button", Color.BLACK)
	theme.set_constant("outline_size", "Button", 4)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	theme.set_constant("outline_size", "Label", 5)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("font_outline_color", "RichTextLabel", Color.BLACK)
	theme.set_constant("outline_size", "RichTextLabel", 3)
	theme.set_constant("line_separation", "RichTextLabel", 3)
	return theme


## Label with this font size and colour.
static func label(text: String, size := 18, colour := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


## Flat panel style with a border, used by the theme and for per-race highlights.
static func box(bg: Color, border: Color, border_width: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(margin)
	return style
