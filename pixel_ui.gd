extends RefCounted

# Jeremy's UI uses one embedded pixel font so speech, menus, and visual gags
# share the same chunky look. The font is Silkscreen (SIL OFL 1.1); the license
# lives beside the font files in res://assets/fonts/OFL.txt.

const REGULAR_FONT_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"
const BOLD_FONT_PATH := "res://assets/fonts/Silkscreen-Bold.ttf"

static var _regular_font: FontFile
static var _bold_font: FontFile


static func get_font(bold: bool = false) -> FontFile:
	if bold:
		if _bold_font == null:
			_bold_font = _load_font(BOLD_FONT_PATH)
		return _bold_font

	if _regular_font == null:
		_regular_font = _load_font(REGULAR_FONT_PATH)
	return _regular_font


static func apply(control: Control, size: int, bold: bool = false) -> void:
	var font := get_font(bold)

	if font != null:
		control.add_theme_font_override("font", font)

	control.add_theme_font_size_override("font_size", size)


static func _load_font(path: String) -> FontFile:
	var font := load(path) as FontFile

	if font == null:
		push_warning("jeremy could not load pixel font: " + path)
		return null

	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.keep_rounding_remainders = true
	font.generate_mipmaps = false
	font.multichannel_signed_distance_field = false
	font.clear_cache()
	return font
