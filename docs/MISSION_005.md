# Wolf of the Deep: The Living Arctic

*Development Mission 005, "The Living Arctic". A playtest build, not a finished game. This file describes the build at the latest checkpoint and grows as later checkpoints land.*

You command **Varg**, a small conventional AIP submarine, in a 600 × 600 km stretch of the Arctic around the island of Ravnøya and the ice edge.

- **The region:** coasts, islands, banks, troughs, a ridge, icebergs and the pack, all charted.
- **The patrol:** your orders cover the sector north of Ravnøya, but nothing stops you going anywhere else on the chart.
- **The world:** the sea, the ice, the weather and the other ships go about their business whether you are watching or not.

## Launching (Windows)

1. Unzip the folder anywhere.
2. Run **`WolfOfTheDeep.exe`**. No installer is needed.
3. The main menu appears over the live sea. Press **F11** to toggle windowed mode, and **F9** if it runs slowly (performance mode).

Sounds can be replaced by dropping files into the `custom/audio/` folder next to the `.exe`. See `AUDIO_LIBRARY.md`.

**Your files** live under `%APPDATA%\Godot\app_userdata\Wolf of the Deep\`:

| File | Contents |
|---|---|
| `saves\` | Campaigns |
| `settings.cfg` | Settings (kept separate from campaigns) |

## Main menu, saves and settings

- **Continue** resumes the most recent save. **New Campaign** starts the patrol from the beginning. **Load Game** lists every save with its time, place and situation.
- **Saving:**
  - Save from the in-game menu (**Esc**) into one of eight slots, or press **F5** to quick-save.
  - The game also autosaves at a set interval of game time (30 minutes by default; change it in Settings) and before risky moments.
- **What a save holds:** the whole campaign, including:
  - the boat, her damage, equipment and fatigue;
  - time, route, contacts and what is known about them;
  - the crew and their relationships;
  - the world, the ice and the Captain's Log.
- **How saves are written:** to a temporary file, checked, then swapped in. The previous version is kept as a backup.
- **Settings:** volumes, contact colour schemes, graphics, window, interface scale, mouse sensitivity, autosave interval and subtitles.
  - The colour schemes include a monochrome low-light scheme for a darkened room.
  - Settings never change a campaign.
- **Developer / Cheats** is off by default. Switch it on in Settings, then press **F10** in play for depth, speed, position, time, repairs, crew, invulnerability, unlimited weapons, test contacts, weather, hazards and every station. Developer tools never reveal what the crew could not know.

## First steps

1. Choose **New Campaign**. Miller has the boat surfaced, heading for the patrol sector.
2. Press **5** for the chart.
   - **Click** a point, a contact or a waypoint to see its distance, bearing and time to go.
   - **Shift+click** to lay waypoints. The panel shows each leg and the total, with the time and day of arrival at your planned speed.
3. Press **Steer the route**, or **N** to run to the next waypoint at high time compression. It stops for anything that matters.
4. Dive with **Z**. Come to periscope depth with **P**, then raise the masts with **M**. Signals from Northern Command, including ice reports, only arrive with a mast above the water.
5. Press **L** for the Captain's Log and **K** for the contact list.
6. When you are tired of it, go to your cabin (**7**), click the bunk and let Miller take the watch.

## Controls

| Keys | Action |
|---|---|
| **1 – 0** | Views: 1 control room · 2 periscope · 3 exterior · 4 sonar · 5 chart · 6 mess · 7 cabin · 8 engine room · 9 torpedo cam · 0 cinematic |
| **A / D** | Ordered course −10° / +10° (hold Shift for 1°) |
| **W / S** | Telegraph up / down (all stop to flank) |
| **O / P / Z / X** | Surface / periscope depth / deeper / shallower |
| **M** | Raise or lower the masts (periscope, radio, AIS, snorkel) |
| **B** | Emergency blow (from 40 m or deeper) |
| **Tab** | Orders to the crew |
| **K** | Contact list |
| **I** | Naval intelligence: units, commanders, class library, reports, your reputation |
| **L** | Captain's Log, orders, signals, watch report |
| **N** | Fast to the next waypoint |
| **+ / −** | Time compression (×1, ×2, ×5, ×10, ×25, ×50, ×100, ×250), also on the command bar |
| **V** | Exterior view: take the camera above or below the surface |
| **F5** | Quick save |
| **F10** | Developer panel (only when enabled in Settings) |
| **Space** | Fire, from the periscope view. The XO asks you to confirm, and you have to press it again. |
| **H** | Help |
| **U** | Hide the interface |
| **Esc** | Game menu, or close the open panel |

**Command bar.** Along the bottom of the screen at all times:

- the stations, with the active one lit;
- heading, speed, depth, keel clearance, battery and hull;
- time and compression;
- quick buttons for orders, contacts, the log and the menu;
- the current view's own shortcuts.

**Chart.**

| Action | How |
|---|---|
| Select | Click |
| Steer for the selection | Double-click or **Enter** |
| Add a waypoint | **Shift+click** |
| Remove the last waypoint | **Backspace** |
| Zoom | Wheel or **PgUp / PgDn** |
| Pan | Right-drag |
| Centre on the boat | **C** |
| Fast to the next waypoint | **N** |

**Periscope:**
- **Train:** drag or **Q / E**. It turns freely through north in either direction.
- **Zoom:** wheel.
- **Change sensor:** **T** (day / low light / thermal).
- **Mark a bearing:** **Enter**.

**Control room:** **Q / E** change viewpoint, click a station to use it, **R** toggles red lighting.

**Card table:**

| Key | Action |
|---|---|
| **Space** | Show the next player's action |
| **F** | Fold |
| **C** | Check / call |
| **R** | Raise |
| **P** | Bet the pot |
| **A** | All in |
| **Esc** | Leave |

The table keeps the keyboard while it is open.

## The chart and the sea floor

**The chart and the sea floor are the same thing.** The chart is drawn from the seabed the boat sails over, so what it shows is what is there:

- depth tints and contours (10, 20, 30, 50, 100, 200, 500, 1000 and 2000 m);
- coastlines and named features;
- the charted rocks, wrecks and shoals;
- the limit of the pack ice.

**Soundings are historical.**

- They sit where survey ships once measured: dense along coasts and old survey lines, sparse in remote deep water.
- They are always the same numbers in the same places.
- As you zoom out, the shoalest are kept.

**The boat can run aground.**

- The navigator warns of shoaling water ahead and drops time compression.
- If you press on, grounding at speed does serious damage.
- Gentle contact scrapes the hull.

**The chart only shows what you know.** That covers contacts with their uncertainty, your own track, your route, and icebergs from the latest ice report. Reported bergs are drawn with a growing circle of doubt because they drift after the report.

**Positions** are given in latitude and longitude, and distances in nautical miles.

## Ice

**Icebergs.**

- They have keels below the water as well as the visible ice above.
- The navigator estimates the clearance needed to pass under one, from:
  - the keel;
  - the boat's own height;
  - the bottom below;
  - a safety margin.
- She advises going round when that is too tight or too deep.
- Ice from a report is less certain than ice held on sonar.
- The advice is advice. Hitting ice damages the boat.

**Close pack ice.**

- North of the charted limit the pack is a lid: the boat cannot surface through it.
- The crew warn you before you try.

## Depth and the hull

- **Safe depth:** about 200 m. Going deeper is possible; nothing stops you except the hull.
- **Below safe depth:**
  - The hull works harder and fatigue builds.
  - The engineer and the alarms tell you about it.
  - Failures become possible: leaks, damaged equipment, groaning frames.
- **The deeper you go:**
  - The more often failures happen.
  - A damaged or tired hull fails sooner.
  - Far beyond its limit, the hull fails completely.
- **Time compression** is limited while you are deep.

## The living world

**Traffic.** Ships go about their business across the region:

- merchant ships on the shipping lanes;
- trawlers working the banks;
- the coast guard on fishery patrol;
- a research ship surveying the ridge;
- foreign warships on deployment.

Each is always somewhere real. They come into your sensors when you are within reach and leave the picture when you are far away. Foreign units come and go: a deployment ends, and days later a ship returns, perhaps under a different commander.

**Aircraft.**

| What | How you meet it |
|---|---|
| Maritime patrol aircraft, ours and foreign | On patrols |
| Airliners | On polar routes |

You know them only through your own senses:

- **ESM, with a mast up:** a bearing on their radar, drawn as a line on the chart (the range is a guess).
- **A sighting, at the periscope or on the bridge:** a position.
- **Afterwards:** a last known position that fades.

A foreign patrol aircraft can find a mast or a surfaced boat. Keep the masts down when its radar is near.

**Reports arrive late.**

- Intelligence reports come with Northern Command's six-hourly broadcasts, and only with a mast up.
- Sources: patrol aircraft sightings, analysts, signals intercepts, rescue coordination and the media.
- Each one states:
  - its source grade and confidence;
  - when the event happened, when it was observed, when it was sent and when you received it.
- Reports can be wrong. When two disagree, both are kept and flagged; neither is assumed right.
- They go into the Captain's Log under intelligence and into the dossiers. Units known only from reports appear on the chart with their age and a circle of doubt.

**Naval intelligence (I).**

- **Units** you have met or been told about, with:
  - class and navy;
  - status and commander;
  - last position and history.
  - Each detail carries its own confidence.
- **Two separate measures:**
  - the class's *intrinsic capability* against a submarine;
  - the *tactical threat* a contact poses now.
- **The class library.**

**Commanders** are persistent people with their own character.

- They remember meeting your boat: a search that came to nothing, a near thing, an attack.
- What they remember changes how they hunt: how long they keep at it, how readily they ping, how sharp their lookouts are.
- Nothing more than that, and nothing at all if they have never met you.
- A commander who survives the loss of a ship may come back on another. The dead do not.
- Northern Command also keeps a reading of your own conduct: how stealthy, how quick to use weapons, how much the other side knows of you.

**Damage.**

- Where a torpedo hits matters. A hit under the keel amidships can break a small ship's back. A bow hit may leave a large ship afloat and listing. A stern hit may take her steering and power.
- Your damage assessment is built only from evidence:
  - detonations and secondary explosions heard;
  - fire, list and settling seen through the periscope;
  - screws stopped, breaking-up noises;
  - later, rescue reports.
- It always says how confident it is, and changes as evidence arrives.

**Consequences.** An attack, a loss or a confirmed detection stirs up the foreign forces: more patrols, and aircraft sent to look where it happened.

## Your crew, your orders

**The crew judge what you do.** Each person weighs your orders against what matters to them:

- their country and their trust in government, command and you;
- their shipmates and their tolerance for risk;
- their own convictions.

On their own initiative, and within what is realistic aboard a warship, they may:

- challenge an order (the XO's objection depends on what is in your sights);
- ask for a word in private when it is quiet;
- refuse to take part in a specific act. Someone else stands their watch, usually less skilfully, and they come back after a while.
- ask, formally, to be reassigned.

There is no score for any of this. You see it in what people do, in the log, and on the desk in your cabin.

**You are free to command as you see fit.** Follow your orders, bend them, ignore a recall, fire without authority, or take the boat where she should not go. Nothing ends the game. The world answers:

- **Northern Command's signals:** they ask for your position, recall you, can relieve you of command, and warn other units. You copy them only with a mast up.
- **Your crew's judgement.**
- **The other side's interest.**

Opportunities you miss stay missed. Your standing with Northern Command is shown in your cabin and in the debrief.

## Aboard

- **The engine room, the mess and your cabin** are working interfaces rather than walk-around rooms:
  - **Engine room:** a live plant mimic (diesels, battery, AIP, motor, shaft), equipment condition and the hull, as the watch keeper sees them.
  - **Mess:** who is there and what they are doing, meals, and the sweets tally.
  - **Cabin:** your desk:
    - the log and intelligence;
    - rest;
    - the watch bill and your orders;
    - what the crew have brought you.
- **The Mess Cup.** Play for it at the mess table:
  - up to four players, each staking a few sweets;
  - equal chips, last one standing;
  - the winner takes the stakes and the cup, and the record is kept.
- **The exterior camera** keeps to its side of the sea surface. It starts on the boat's side; press **V**, or orbit clearly through the surface, to cross.

## Ships and ice

- **Distinct ship classes:**
  - foreign frigates with a hangar and flight deck;
  - corvettes with ASW launchers and a lattice mast;
  - a coast guard cutter with a high-visibility stripe, a working deck and a crane;
  - container ships and bulk carriers;
  - trawlers and research ships.
- **Damage is visible:** fire, smoke, a list, scorched hull plating where the hit was.
- **Detail fades with distance.**
- **Icebergs:** weathered pinnacles or tabular cliffs, a wave-cut notch at the waterline and a keel below. Their shape follows the same profile that collisions and the navigator's clearance advice use.

## Time compression

- **Levels:** ×1 to ×250, from the keys or the command bar.
- **Situation limits:**
  - ×25 when the boat is alert or below safe depth.
  - ×2 at action stations.
- **Dropping back:** it drops to ×1 by itself for contacts, warnings, ice, shoaling water and signals.
- **No skipped collisions:** the simulation keeps its small steps at every level, so nothing is passed through at speed.

## Things worth knowing

**Information is imperfect.**

- Sonar gives a bearing long before it gives a range. Manoeuvring helps the crew work out a contact's course and speed.
- The contact list and the chart show only what the crew know, with their confidence.
- Your own position drifts while submerged until you take a fix with a mast up.

**Being heard is the risk.** Speed, cavitation, the diesels and transmissions make you louder.

**The crew live their own day.**

- Watches, meals, sleep and off-duty time.
- Who answers depends on who is on duty.
- They talk rarely; silence is normal.

**Rest.** Miller takes the watch with your standing orders. In the patrol sector he keeps to it; on a route you laid he follows it. You are woken for anything important.

**Weapons are real, and so are the consequences.**

## Known limitations (playtest)

- **The wider region is thinly populated.** It has about ten ships on voyages and a few aircraft at a time; the original patrol area keeps its own story traffic.
- **Distant ships are simple.** Ships beyond the horizon are drawn only as contacts. Regional ships use the existing ship models.
- **No helicopters.** Foreign warships do not yet launch them.
- **The interiors are interfaces.** The engine room, mess and cabin are 2D working interfaces. Only the control room has the path-traced, walk-to-station treatment.
- **The underwater view.** Looking up at a shallow angle from just below the surface can show a crisp band where the distant surface is.
- **Limits of freedom of command:**
  - The crew refuse, object and ask to leave, but never take the boat from you.
  - A boat believed to be defecting is hunted and disowned, but the other side does not yet receive her.
- **The 3D world is streamed around you.**
  - Near the boat: detailed seabed and land.
  - Further away: coarse land.
  - Distant terrain can appear a moment after a long jump with the developer tools.
- **Geography is generated, but fixed.** It is the same in every campaign. Fjords are simplified channels.
- **Simplified simulation.**
  - Sonar is a simplified sonar equation.
  - Fire control is the simple solution from earlier builds.
  - Other ships have simple behaviours.
- **Placeholder presentation.**
  - The crew are figures that stand or sit at their stations.
  - Only some lines are voiced; the rest are subtitled.

## Deferred

These are deferred:

- path-traced interiors for the engine room, mess and cabin;
- helicopters;
- branching fjords;
- the XO relieving a captain;
- the other side receiving a defector;
- verification on Windows hardware.

## Testing

Windows gameplay and audio have **not** been played on Windows by the developer.

- The Windows build is produced by GitHub Actions.
- Testing was done on Linux:
  - headless checks: saves, interface, chart against seabed, collisions, time compression, the hull, traffic, aircraft, reports, intelligence, damage, crew judgement, command standing, rooms, the Mess Cup, ship classes, iceberg shape, cards, sound resolution, pause and control room;
  - a 62-hour simulated patrol;
  - software-rendered screenshots.
