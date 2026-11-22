# Replacing sounds

Every sound in the game has a short **name**. To replace one, put your own file with that name in the `custom/audio/` folder. No code changes and no rebuild are needed; restart the game to hear it.

## Where the folder is

| Running | Folder |
|---|---|
| Windows build | `custom/audio/` **next to `SilentSea.exe`** (it ships empty) |
| Godot editor | `custom/audio/` in the project folder |

## Rules

1. If `custom/audio/<name>.ogg`, `.wav` or `.mp3` exists and plays, the game uses it (checked in that order).
2. Otherwise it plays its built-in template sound.
3. If neither works it continues silently. A broken custom file is skipped with a warning; it never crashes the game.

Sounds are loaded once at startup, so **restart the game after changing files**. Mono or stereo, any sample rate. Names ending in `_ambience` and `torpedo_running` loop automatically, so make them loop cleanly.

## Recognised names

| Name | When it plays |
|---|---|
| `submarine_dive` | Vents open when diving from the surface |
| `submarine_surface` | High-pressure air blow when surfacing |
| `periscope_raise` | Periscope going up |
| `periscope_lower` | Periscope going down |
| `torpedo_launch` | Torpedo leaves the tube |
| `torpedo_running` | Torpedo motor (loops, follows the torpedo) |
| `torpedo_impact` | Warhead detonation (heard after a travel delay) |
| `ship_sinking` | Groaning hull and inrushing water of a sinking ship |
| `underwater_ambience` | Camera below the surface (loop) |
| `submarine_ambience` | Inside the boat: control room and sonar views (loop) |
| `sea_ambience` | Waves on the surface (loop) |
| `wind_ambience` | Wind (loop) |
| `rain_ambience` | Rain in the gale (loop) |
| `thunder` | Thunder after lightning |
| `hull_creak` | Occasional hull creaks inside or below the surface |
| `sonar_ping` | Distant active sonar heard through the hull |
| `breach_splash` | Emergency-blow breach |
| `ui_click` | Conn buttons and orders |

Example: to replace the launch, save your file as `custom/audio/torpedo_launch.ogg` (or `.wav`, `.mp3`) and restart.

The built-in templates live in `assets/audio/template_<name>.ogg`. They are original sounds synthesised for this prototype.
