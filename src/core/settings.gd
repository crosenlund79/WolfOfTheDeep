class_name Settings
extends RefCounted
## Player settings, stored separately from campaigns (user://settings.cfg).
## Static so every module reads the same values without wiring.

const PATH := "user://settings.cfg"
const SCHEMES := ["standard", "low_light", "high_contrast"]
const SCHEME_NAMES := {"standard": "Standard", "low_light": "Monochrome / low light", "high_contrast": "High contrast"}

static var values := {
	"vol_master": 0.0,          # dB offsets
	"vol_music": 0.0,
	"vol_effects": 0.0,
	"vol_voices": 0.0,
	"vol_ambience": 0.0,
	"ui_scale": 1.0,
	"contact_scheme": "standard",
	"graphics": "high",          # high / performance
	"fullscreen": true,
	"mouse_sensitivity": 1.0,
	"autosave_minutes": 30,      # game minutes; 0 = off
	"subtitles": true,
	"developer": false,          # developer / cheat panel available (F10)
}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in values.keys():
		if cf.has_section_key("settings", k):
			values[k] = cf.get_value("settings", k)


static func save() -> void:
	var cf := ConfigFile.new()
	for k in values.keys():
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


static func get_v(key: String) -> Variant:
	ensure_loaded()
	return values.get(key)


static func set_v(key: String, v: Variant) -> void:
	ensure_loaded()
	values[key] = v
	save()


## Colours for contact affiliations / states under the chosen scheme.
## Shapes and text always carry the meaning too; colour only helps.
static func contact_color(kind: String) -> Color:
	ensure_loaded()
	var s := String(values["contact_scheme"])
	if s == "low_light":
		# One hue (red, preserves night vision); brightness separates states.
		var g := float({"hostile": 1.0, "suspect": 0.88, "unknown": 0.76, "neutral": 0.62, "friendly": 0.58, "lost": 0.38, "ice": 0.6}.get(kind, 0.6))
		return Color(1.0 * g, 0.3 * g, 0.24 * g, 1.0)
	if s == "high_contrast":
		match kind:
			"hostile":
				return Color(1.0, 0.25, 0.85)
			"suspect":
				return Color(1.0, 0.6, 0.0)
			"unknown":
				return Color(1.0, 1.0, 0.2)
			"neutral":
				return Color(0.3, 1.0, 0.3)
			"friendly":
				return Color(0.3, 0.75, 1.0)
			"lost":
				return Color(0.75, 0.75, 0.75)
			"ice":
				return Color(1.0, 1.0, 1.0)
	match kind:
		"hostile":
			return Color(1.0, 0.42, 0.36)
		"suspect":
			return Color(1.0, 0.66, 0.32)
		"unknown":
			return Color(1.0, 0.85, 0.45)
		"neutral":
			return Color(0.55, 0.92, 0.66)
		"friendly":
			return Color(0.45, 0.78, 1.0)
		"lost":
			return Color(0.6, 0.64, 0.68, 0.75)
		"ice":
			return Color(0.88, 0.94, 1.0)
	return Color(0.9, 0.9, 0.9)


## Base text colours of the interface under the chosen scheme.
static func ui_tint() -> Color:
	ensure_loaded()
	return Color(1.0, 0.55, 0.45) if String(values["contact_scheme"]) == "low_light" else Color(1, 1, 1)
