# Audio library

How the game's sounds are organised, where they come from, when they play, and how to replace them.

## Sources

**The creator's recordings** live in `assets/audio/_inbox/` and are an **immutable archive**. The game never renames, edits, deletes or overwrites them. A `.gdignore` file in that folder stops Godot from importing the archive; the recordings themselves are untouched.

**Working copies** live in `assets/audio/library/{ambience,sfx,music,voice}/`. They were made from the archive with ffmpeg:

- converted to Ogg Vorbis;
- loudness-normalised per category;
- loops given a short crossfade so they repeat cleanly;
- each original file becomes one *variant* of a sound group.

**The registry**, `assets/audio/audio_registry.json`, maps each group to its category, its loop flag, its working files, and the archive files they came from.

**Synthesised `template_*.ogg` sounds** from Prototype 002 remain as the fallback where no recording exists.

## How a sound is chosen

| Order | Source | Notes |
|---|---|---|
| 1 | `custom/audio/<group>.ogg / .wav / .mp3` | Replaces the whole group. |
| 2 | `custom/audio/<group>_<n>.ogg / .wav / .mp3` | Replaces variant *n* only (1-based). |
| 3 | Working copies from the registry | Variants rotate without immediate repeats. |
| 4 | `template_<group>.ogg` | Only for template names. |
| 5 | Nothing | Silence. Never a crash. |

The `custom/audio/` folder is the one **next to `WolfOfTheDeep.exe`** in the Windows build, or `custom/audio/` in the project folder in the editor. Files are read once at startup, so restart the game after changing them.

## Mixing

| Topic | Behaviour |
|---|---|
| Buses | World, Ambience, Near, Muffled, Far, Voice and Music. |
| Compartments | The boat has four: cabin, control room, mess, engine room. A sound made where the captain is plays clearly. One compartment away it is muffled; further away it is distant. |
| Outside world | Sounds from outside (sea, ice, whales, pings) are low-passed when heard from inside the hull. |
| Ambience beds | Sea, blizzard, birds near land, interior hum, ventilation, exterior and underwater beds crossfade with location, weather and depth. |
| Engine | Low, medium and high crossfade with speed. The diesels use the high bed. |
| Voice priority | Spoken lines duck music and ambience. Reports interrupt chatter. |
| Music | The main theme plays under the title and fades out when the patrol begins. |

## Groups and when they play

### Ambience and engine (looping beds)

| Group | Variants | Plays |
|---|---|---|
| `amb_sea_waves` | 4 | Outside on the surface; faintly inside when surfaced |
| `amb_blizzard` | 4 | Outside in snow or gale |
| `amb_birds` | 4 | Outside near Ravnøya in daylight |
| `amb_sub_interior` | 1 | Inside the boat |
| `amb_ventilation` | 3 | Inside (quieter when running silent) |
| `amb_sub_exterior` | 1 | Camera below the surface |
| `eng_low` / `eng_medium` / `eng_high` | 4 each | Inside, by speed (loudest in the engine room) |

### Effects

| Group | Variants | Plays |
|---|---|---|
| `sfx_ballast_flooding` | 4 | Vents opening on a dive |
| `sfx_hatch_close` | 4 | Diving from the surface |
| `sfx_hull_creak` | 4 | Occasionally when deeper than 70 m |
| `sfx_hull_creak_deep` | 4 | Occasionally when deeper than 140 m |
| `sfx_alarm` | 4 | Collision, emergency blow, battle stations, urgent wake-up |
| `sfx_ice_scrape` | 4 | Scraping or striking ice |
| `sfx_structural_failure` | 4 | Heavy collision damage |
| `sfx_ice_calving` | 4 | A berg calving within about 9 km |
| `sfx_ice_turning_large` / `_small` | 3 / 4 | Ice groaning within about 700 m |
| `sfx_whale_song` / `sfx_killer_whales` | 4 / 2 | Occasional biologics while submerged |
| `sfx_ship_propeller_pass` | 4 | A ship passing close while submerged |
| `sfx_sonar_ping` | 3 | Another ship's active sonar heard through the hull |
| `sfx_sonar_inactive_ping` | 2 | New-contact notification |
| `sfx_encrypted_message` | 3 | A signal copied, or a transmission sent |
| `sfx_waves_splash_hull` | 4 | Inside, surfaced, in a seaway |

### Music

| Group | Plays |
|---|---|
| `mus_main_theme` | Title sequence |

### Voice (Miller and Basse)

Subtitles always show the words.

| Group | Plays |
|---|---|
| `vo_miller_greeting_1` / `_2` | Start of a session (undamaged boat) |
| `vo_miller_assumes_command` | The captain turns in; Miller takes the watch |
| `vo_miller_welcome_back` | Waking in the morning after a quiet watch |
| `vo_miller_new_contact_085` | A new sonar contact that really is at about 085° relative, not yet classified |
| `vo_miller_patrol_contact_085` | As above, when the contact is a substantial surface merchant |
| `vo_miller_approaching_pd` / `vo_miller_pd_reached` | Coming to periscope depth |
| `vo_miller_contact_lost` | Losing an uncertain or military contact |
| `vo_miller_torpedo_away` / `vo_miller_torpedo_impact` | Weapon launch and detonation |
| `vo_basse_dinner_ready` | The 18:00 dinner call |
| `vo_basse_mutter_danish` | Overheard from the galley after Miller's greeting |

The two "085" lines are only used when the bearing in the recording matches the actual contact.

### Template sounds still in use

`submarine_surface`, `periscope_raise`, `periscope_lower`, `torpedo_launch`, `torpedo_running`, `torpedo_impact`, `ship_sinking`, `thunder`, `breach_splash`, `ui_click`.

The other `template_*` files from Prototype 002 are no longer triggered:

- the old ambience beds (`sea_`, `wind_`, `rain_`, `underwater_` and `submarine_ambience`);
- `sonar_ping`, `hull_creak` and `submarine_dive`.

The recordings above replace them.

## Basse's singing

**No song recordings were found in the archive.** Until there are some, Basse occasionally hums: it is shown as a subtitle when the captain is in the mess, and no sound plays.

To add songs, drop files named `basse_song*.ogg`, `.wav` or `.mp3` into `custom/audio/`, for example `basse_song_1.ogg` and `basse_song_sailor.mp3`. Every matching file is a separate song.

How the songs play:

- **Fragments only, never a whole song.** A fragment is a few words (3–6 s), half a verse (7–12 s), a verse (14–21 s) or, rarely, a verse and a half (22–32 s).
- **Varied starts.** Each fragment starts at a random point in the song, with soft fades in and out.
- **Infrequent.** Every few minutes at most.
- **Muffled.** Overheard from the mess, according to where the captain is.
- **He stops** when he is busy, asleep or out of the mess, during silent running, at alert, or when someone speaks.

## Replacing a sound: quick reference

```
WolfOfTheDeep.exe
custom/
  audio/
    sfx_alarm.ogg            <- replaces all four alarm variants
    amb_sea_waves_2.wav      <- replaces only the second wave loop
    vo_miller_pd_reached.mp3 <- your own recording of the line
    basse_song_1.ogg         <- a song for Basse (fragments only)
```
