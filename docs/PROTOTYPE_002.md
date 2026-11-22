# Prototype 002 — First Contact

A small first engagement built on the Visual Prototype 001 scene: dive, raise the periscope, find a passing merchant ship, fire a torpedo and watch her sink. Only the engagement is simulated, and simply: there is no sonar model, fire-control computer, enemy AI or campaign.

## Run it (Windows x64)

Download the newest **Silent Sea · Windows x64 build** artifact from GitHub Actions, unzip it anywhere and run `SilentSea.exe`. To replace sounds, see `SOUNDS.md` (also inside the download); the `custom/audio/` folder sits next to the exe.

## The attack

1. Press any key after the title. You start surfaced; a merchant ship crosses ahead, about 1.7 km away on your port bow.
2. **P**: dive to periscope depth. Watch from outside (**2**) as the boat slips under; the sea stays where it is.
3. **M**: raise the periscope, then **3** for the periscope view.
4. Find the merchant: drag the mouse (or hold **Q / E**) to train, mouse wheel to zoom.
5. Hold the crosshair on her. The **solution** builds to 100 % in about three seconds and the tracking box turns red.
6. **Space**: fire. "TORPEDO AWAY", the launch, then the running torpedo marked on the bearing tape.
7. **6**: follow the torpedo, and **+** to speed up time (up to ×8). On a hit the camera pulls back to watch the explosion, the list, a secondary blast and the slow plunge.
8. **N**: a new contact for another try.

Without a solution the torpedo runs straight down the periscope bearing and usually passes astern of a moving ship. It can miss.

## Controls

| | |
|---|---|
| **P / O / Z / X** | Periscope depth / surface / dive one step deeper / rise one step |
| **M** | Raise / lower the periscope (it only shows anything above water when raised at periscope depth or surfaced) |
| **Space** | Fire (periscope view) · next shot (cinematic view) |
| **Drag or Q / E**, **wheel** | Train and zoom the periscope · **T** sensor · **Enter** mark a bearing |
| **6** | Torpedo camera (follows the torpedo, then watches the target) |
| **+ / −** | Time ×1 / ×2 / ×4 / ×8 |
| **N** | New target (replay) |
| **1–5** | Cinematic · exterior · periscope · control room · sonar |
| **W / S, A / D** | Telegraph, rudder |
| **B** | Emergency blow from 40 m or deeper |
| **F1–F5** | Weather · **H** all controls · **F9** performance mode · **Esc** pause / quit |

The conn panel (bottom right) shows depth, periscope, tubes and the running torpedo, and its buttons do the same as the keys.
