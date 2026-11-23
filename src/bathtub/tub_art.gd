class_name TubArt
extends RefCounted
## The Bathtub Edition's art and type, resolved in one place (assets/README.md):
##   1. user override   <override root>/graphics/bathtub/<name>.png
##   2. packaged template  res://assets/graphics/bathtub/template_<name>.svg
## Resolved once and cached; overrides apply after a restart. The override
## root is the same one the audio uses (custom/ next to the game).

const TEMPLATE_DIR := "res://assets/graphics/bathtub/"
static var _cache := {}
static var _source := {}
static var _fonts := {}
static var override_root := ""


static func root() -> String:
	if override_root == "":
		override_root = AudioLibrary.default_override_root()
	return override_root


static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var tex: Texture2D = null
	var custom := root().path_join("graphics/bathtub/%s.png" % name)
	if FileAccess.file_exists(custom):
		var img := Image.load_from_file(custom)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
			_source[name] = "custom"
		else:
			push_warning("Bathtub art override %s could not be read; using the template." % custom)
	if tex == null:
		var path := TEMPLATE_DIR + "template_%s.svg" % name
		if ResourceLoader.exists(path):
			tex = load(path)
			_source[name] = "template"
		else:
			_source[name] = "missing"
	_cache[name] = tex
	return tex


static func source_of(name: String) -> String:
	texture(name)
	return String(_source.get(name, "missing"))


static func clear_cache() -> void:
	_cache.clear()
	_source.clear()


## Fredoka (SIL Open Font License), bundled; falls back to the system font.
static func font(bold: bool = true) -> Font:
	var key := "b" if bold else "r"
	if _fonts.has(key):
		return _fonts[key]
	var path := "res://assets/fonts/fredoka-%s.woff2" % ("700" if bold else "600")
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_fonts[key] = f
	return f
