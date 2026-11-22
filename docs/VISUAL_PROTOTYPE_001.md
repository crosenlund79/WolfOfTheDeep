# Silent Sea — Visual Prototype 001

> Superseded for play by **Prototype 002 — First Contact** (`docs/PROTOTYPE_002.md`), which adds the torpedo engagement and changes a few keys: Space fires in the periscope view, Enter marks a bearing, N starts a new target, and the periscope trains by dragging or with Q / E.

A look-and-feel experiment for a modern submarine simulator. **Everything is staged or cosmetic:** there is no sonar physics, weapons, AI, campaign or simulation behind what you see. Built with Godot 4.7.x; every model, texture and sound is generated procedurally at startup, so the package contains no art or audio files.

## Run it (Windows x64)

1. Download the `SilentSea-VisualPrototype001-windows-x64` artifact from the latest **Silent Sea · Windows x64 build** run in GitHub Actions and unzip it anywhere.
2. Run `SilentSea.exe`. It opens fullscreen with a short title sequence. Press any key to take the conn.

It needs a Vulkan-capable GPU (most GPUs from 2016 onward) and Windows 10 or 11. The first launch compiles shaders, so expect a short pause.

## Controls

| | |
|---|---|
| **1** | Cinematic director (automatic camera; Space = next shot) |
| **2** | Exterior orbit (drag mouse to orbit, wheel to zoom) |
| **3** | Optronic mast / periscope (mouse to train, wheel to zoom, **T** sensor TV / low-light / thermal, **Space** mark) |
| **4** | Control room (move the mouse to look around, click a lit screen to go to that station, **R** rig for red) |
| **5** | Sonar / tactical console (**Q / E** select contact) |
| **Tab** | Cycle views |
| **W / S** | Engine telegraph up / down |
| **A / D** | Rudder |
| **Z / X** | Dive one step / rise one step (surfaced → periscope depth → 40 m → 120 m) |
| **M** | Raise / house masts |
| **B** | Emergency blow (when submerged at 40 m or deeper): a bow-first breach |
| **F1–F5** | Weather: Atlantic dawn · Clear midday · Golden hour · North Atlantic gale · Moonlit night (**N** = next) |
| **H** | Controls help · **U** hide interface · **F9** performance mode (for weaker GPUs) · **F11** fullscreen · **Esc** pause / quit |

## Things to try

- Dive from the surface (**Z**) in the exterior view, then follow the boat below the surface: sunbeams, drifting particles, caustics on the hull, the surface seen from below.
- Dive twice (**Z**, **Z**) to 40 m, wait for the boat to settle, then press **B** for an emergency blow.
- Open the mast view (**3**) while deep: the boat comes to periscope depth and the camera breaks the surface with water running off the lens. Switch to thermal (**T**) to pick out ships.
- Switch to the gale (**F4**) or the moonlit night (**F5**) and watch the weather blend.
- Visit the control room (**4**) at night: it rigs for red, and its screens show the live mast feed and sonar.

All vessels, names and numbers are fictional.
