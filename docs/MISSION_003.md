# Wolf of the Deep: Patrol One

*Development Mission 003, "A Living Submarine". A playtest build, not a finished game.*

You command **Varg**, a small conventional AIP submarine, on a covert three-day patrol north of the island of Ravnøya, toward the Arctic ice edge. The sea, the ice, the weather and the other ships go about their business whether you are watching or not. Your crew run the boat, talk among themselves, eat, sleep, play cards, and do what you tell them.

## Launching (Windows)

1. Unzip the folder anywhere.
2. Run **`WolfOfTheDeep.exe`**. No installer is needed.
3. The game starts fullscreen. Press **F11** to toggle windowed mode, and **F9** if it runs slowly (performance mode).

Sounds can be replaced by dropping files into the `custom/audio/` folder next to the `.exe`. See `AUDIO_LIBRARY.md`.

The crew's sweets, relationships and memories are kept between sessions in your user folder (`%APPDATA%\Godot\app_userdata\Wolf of the Deep\wolf_crew.json`). Delete that file to reset them. The patrol itself always starts fresh.

## First steps

1. Press any key after the title. Miller has the boat surfaced, heading for the patrol sector.
2. Press **5** for the chart. Click to steer for a point; Shift+click adds waypoints. Or press **Tab** and order *Navigator: lay a course to Sector KESTREL*.
3. Press **+** to compress time. It drops back to ×1 when something happens.
4. Dive with **Z**. Come to periscope depth with **P**, then raise the masts with **M**. Signals from Northern Command, including your orders, only arrive with a mast above the water.
5. Press **L** for objectives, messages and the patrol log.
6. When you are tired of it, go to your cabin (**7**), click the bunk and let Miller take the watch.

## Controls

| Keys | Action |
|---|---|
| **1 – 0** | Views: 1 control room · 2 periscope · 3 exterior · 4 sonar · 5 chart · 6 mess · 7 cabin · 8 engine room · 9 torpedo cam · 0 cinematic |
| **A / D** | Ordered course −10° / +10° (hold Shift for 1°) |
| **W / S** | Telegraph up / down (all stop to flank) |
| **O / P / Z / X** | Surface / periscope depth / deeper / shallower (test depth 200 m) |
| **M** | Raise or lower the masts (periscope, radio, AIS, snorkel) |
| **B** | Emergency blow (from 40 m or deeper) |
| **Tab** | Orders to the crew: silent running, snorkel, position fix, sonar report, routes, radio, battle stations, the conn, rest, cards |
| **L** | Patrol log, objectives, messages, Miller's watch report |
| **+ / −** | Time compression ×1 to ×50 (×2 at most at action stations) |
| **Space** | Fire, from the periscope view. The XO asks you to confirm, and you have to press it again. |
| **H** | Help |
| **U** | Hide the interface |
| **Esc** | Pause, close a panel, or leave the card table |

**Chart:** click to steer · Shift+click to add a waypoint · right-drag to pan · wheel to zoom · **C** to centre · **Backspace** to clear the route.

**Periscope:** drag or **Q / E** to train · wheel to zoom · **T** to change sensor (day / low light / thermal) · **Enter** to mark a bearing.

**Rooms:** move the mouse to look around. Click a person to talk to them. Click things: the coffee, the card table, your bunk, the logbook.

**Control room:** click the screens (periscope feed, sonar, ship control). **R** toggles red lighting.

**Card table:** **Space** shows the next player's action · **F** fold · **C** check / call · **R** raise · **P** bet the pot · **A** all in · **Esc** leave.

## Things worth knowing

**Information is imperfect.**

- Sonar gives a bearing long before it gives a range.
- The chart shows a contact as a bearing line until the range firms up, which happens faster when you manoeuvre. Then it shows an uncertainty ellipse.
- Lookouts and the periscope depend on light, fog, snow and the island in the way.
- Your own position drifts while submerged until you take a fix with a mast up.

**Being heard is the risk.** Speed, cavitation, the diesels and transmissions make you louder. A thermal layer at about 55 m helps you hide. Other ships may become curious.

**The crew live their own day.**

- Watches, meals at 07:00, 12:00 and 18:00, sleep, and off-duty time in the mess.
- Who answers depends on who is on duty. If the sonar officer is asleep, the watch operator covers, a little less sharply.
- They talk rarely; silence is normal.
- Basse cooks and swears in Danish.

**Rest.**

- Miller takes the watch with your standing orders, which you can choose in the rest panel.
- Time runs fast while you sleep.
- You are woken for anything important. Afterwards the log has his report.

**Cards.**

- Texas Hold'em for sweets, in the mess, with whoever is off duty and awake.
- Everyone plays in character.
- Wins and losses are kept.
- Emergencies end the game at once, and everyone gets their stake back.

**Weapons are real, and so are the consequences.** This is peacetime.

## Known limitations (playtest)

**Simplified simulation.**

- Sonar is a simplified sonar equation.
- There is no manual target motion analysis.
- Fire control is the simple Prototype 002 solution.
- Other ships have simple behaviours.

**Placeholder presentation.**

- The crew are simple procedural figures that stand or sit at their stations. They don't walk between rooms; they appear where their routine puts them.
- Only some lines are voiced (the recordings provided). Everything else is subtitled.
- Basse's singing needs song recordings, which are not included yet. Until they arrive he hums, shown as a subtitle. See `AUDIO_LIBRARY.md` for how to add songs.

**Not implemented yet.**

- Crew injury or loss: the systems are built around roles to allow it later.
- Saving and resuming a patrol mid-way.
- Ice canopy navigation beyond the edge. The pack ice is scenery that you should not go under.

**Card table.** A complete Hold'em game, with side pots and showdowns. It has no bet-sizing slider (the options are minimum raise, pot or all-in), no tournament structure and no "tells" animation.

**Testing.** Windows gameplay and audio have **not** been played on Windows by the developer.

- The Windows build is produced by GitHub Actions.
- Testing was done on Linux: headless checks, a 62-hour simulated patrol, and software-rendered screenshots.
