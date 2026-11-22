# Control room: visual quality pilot

*Mission 004C, an experimental build. Only the control room is new; everything else is the preserved baseline.*

## What it is

Press **1** to enter the reworked control room: a single, carefully built room seen from fixed viewpoints, with smooth transitions between them. It replaces the earlier free-look 3D control room only. The mess, cabin and engine room are unchanged from the baseline.

## Technique: hybrid (path-traced plates with live layers)

1. **Path-traced plates.** The room was modelled at real scale in Blender:
   - a pressure hull about 6.6 m in diameter, with a deckhead at 2.35 m;
   - consoles, seats, pipework, cable trays, the periscope stand, a ladder trunk and doors.

   It was path-traced in Cycles from four camera positions, with two lighting states each: normal and red (night / action). Path tracing gives the soft shadows, bounce light and believable materials that the earlier realtime rooms lacked.
2. **Live layers on top, in the game.**
   - **Displays:** the working displays are warped onto their screens with perspective-correct grids, and masked so anything in front of a screen stays in front:
     - the periscope / optronic mast video on the overhead monitor, rendered live from the 3D exterior;
     - the sonar waterfall and plot;
     - the navigation plot on the table;
     - the ship control readouts.
   - **Indicator lamps:** they blink and breathe.
   - **Lighting:** red lighting fades in at night, in action, or with **R**.
   - **Presence:** a gentle head movement follows the mouse, with the boat's roll and a slow breathing drift, so the room feels occupied rather than like a photograph.
3. **Crew.** The watch is staged with three figures built on realistic CC0 base meshes, posed at their stations and dressed in working coveralls: the officer of the watch beside the periscope, a helmsman at the yoke and a sonar operator under a headset. They are seen from behind or in profile. Named characters are present through voice, as before. The figures are left out of viewpoints where they would block a station.

## Controls

| Input | Action |
|---|---|
| **1** | Control room (command position) |
| **Q / E** | Previous / next viewpoint: command, sonar console, navigation table, overview |
| Bottom bar | The same viewpoints, plus **Periscope ›** and **Exterior ›** |
| **Click a station** | Sonar console → sonar viewpoint, then the full sonar display. Navigation table → navigation viewpoint, then the full chart. Periscope → periscope view. Ship control / ballast → orders. |
| **Right-click / Backspace** | Back to the command position (from there: the overview) |
| **R** | Red lighting on / off (it also comes on by itself at night and at action stations) |
| **2 / 3 / 4 / 5** | Periscope, exterior, sonar, chart, as before |
| **Esc** | Pause menu, as before |

## Known limitations

- **Fixed viewpoints:** there is no free look, and the head movement is only a slight parallax sway.
- **Static crew:** the staged watch does not follow the daily routines, so the same watchstanders are always on duty.
- **Only this room:** the other rooms are still the baseline's 3D rooms, so moving between them shows the contrast.
- **Fixed lighting states:** the plates are pre-rendered, so lighting changes are limited to normal and red. Moving lights and objects would need re-rendering.
- **Generic static displays:** screens that are not live show static, plausible content.
- **Made for 16:9:** on other window shapes the edges of the room are cropped.
- **Static figures:** the staged crew are posed, not animated, and have no facial detail; they are meant to be seen from behind or at a distance.
- **Not played on Windows:** testing was done on Linux, with headless checks and software-rendered screenshots.

## Asset sources and licences

| Asset | Source | Licence | Use |
|---|---|---|---|
| `metal_plate` (normal and roughness maps) | Poly Haven, polyhaven.com/a/metal_plate | CC0 | Periscope stand tread plate |
| `Rubber004` | ambientCG, ambientcg.com/view?id=Rubber004 | CC0 | Deck covering |
| `Leather037` (normal and roughness maps) | ambientCG, ambientcg.com/view?id=Leather037 | CC0 | Seat vinyl |
| Human Base Meshes (realistic male and female bodies, Dan Ulrich) | Blender Foundation / Blender Studio, download.blender.org/demo/asset-bundles/human-base-meshes/ | CC0 | Crew figures (posed and dressed in `tools/interior/crew.py`) |
| DejaVu Sans / Sans Mono | Bundled with the OS | Bitstream Vera / DejaVu licence | Label text and display images baked into the plates |
| Room model, materials, display images | Made for this project (`tools/interior/`) | Project-owned | Everything else |

No paid, Unreal or Fab assets were used. To regenerate the plates, see `tools/interior/README.md`. Blender is used only to make the images; you do not need it to run the game.
