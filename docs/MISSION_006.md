# Wolf of the Deep: Command & Combat Refinement

*Development Mission 006: corrections from the Mission 005 playtest. A playtest build, not a finished game.*

This build fixes what the Mission 005 playtest turned up:

- the boat turned too slowly;
- torpedoes missed with a "100 %" solution, and the game could not say why;
- there was no sense of being hunted;
- the chart could not be searched, and had no legend;
- time was held too low in action;
- there was no briefing;
- the watchbill left out the cook;
- there was no quick way to try things out.

The world, the patrol and the crew are as before. `README_MISSION_005.md` (next to this file) still describes them.

## Launching (Windows)

1. Unzip the folder anywhere.
2. Run **`WolfOfTheDeep.exe`**. No installer is needed and nothing has to be compiled.
3. The main menu appears over the live sea.
   - **F11** toggles windowed mode.
   - **F9** switches to performance mode if it runs slowly.

**Your files** are under `%APPDATA%\Godot\app_userdata\Wolf of the Deep\`:
- campaigns in `saves\`;
- settings in `settings.cfg`.

Test scenarios write nothing there.

Sounds can be replaced through the `custom/audio/` folder next to the `.exe` (see `AUDIO_LIBRARY.md`).

## What changed

### The helm

**The boat answers the helm sooner and turns faster, but stays heavy.** The rudder now moves at a realistic rate, the helmsman steadies her on the new course with little overshoot, and the rate of turn depends on speed.

| At 9 kt | Mission 005 | Now |
|---|---|---|
| A 10° course change settles in | about 45 s | about 22 s |
| A 90° turn takes | about 127 s | about 78 s |

| Speed | Highest rate of turn |
|---|---|
| 3 kt | about 0.5°/s |
| 9 kt | about 1.4°/s |
| 18 kt | about 2.8°/s |

- Stopped in the water, she hardly answers the rudder at all.
- She turns the same at every time compression.

**Where to see it:**
- the **HELM** line on the conn panel: ordered and actual heading, the rudder angle, and whether she is swinging;
- the command bar: `HDG 025›040 RUD 15R ↻`.

### Torpedoes: why they missed, and what changed

**The three causes of the misses:**
1. The aim did not allow for the torpedo's own turn after launch, so shots at large angles went behind the target.
2. The weapon's reach (4 km) was shorter than many of the shots.
3. The "100 %" was a timer, not a measure of how well the target was known.

**How fire control works now:**
- **Estimates, not the truth.** Fire control works only from what the attack party can estimate:
  - range by stadimeter;
  - course and speed from watching her, tightened by the sonar's motion analysis.
- **The estimates have errors.** They shrink the longer you watch, and grow with distance, darkness, poor visibility and a heavy sea.
- **A turn takes time to show.** If the target turns, the crew notice only after a while.
- **The aim allows for the run.** The gyro course comes from a model of the torpedo's own run, its turn after launch included.
- **Lock needs sight.** You can only lock what you can see; fog limits it.

**The weapon:**
- runs about 12 km at about 50 kt;
- switches its seeker on after a safe run of 400 m;
- looks ahead about ±20° out to about 900 m (less in a heavy sea);
- may or may not pick the target up, may home on her, and may lose her again.

**The guidance wire** brings telemetry back. It parts if the boat manoeuvres hard or goes deep.

**Controlled engagements** (in the automated checks, through the game's own fire-control chain):
- **Steady targets** watched before firing: 14 hits in 16 shots, across geometries from close aboard to 6 km and from ahead to far abaft the beam.
- **A hurried four-second look in snow:** 4 hits in 8.

### Following a shot

**After launch, reports follow the run stage by stage:**
1. launch confirmed, with the gyro angle and the expected time to intercept;
2. running;
3. seeker enabled;
4. target acquired, or lost;
5. the expected intercept;
6. then one outcome:
   - **impact detected**;
   - **suspected miss** (no detonation by the expected time);
   - **confirmed miss** (only when the run is seen to end, for example the telemetry reports run complete);
   - **result unknown** (the wire has parted and nothing is heard).

**The post-attack assessment:**
- It names a cause only when there is evidence:
  - the target was seen to alter course;
  - the seeker never acquired;
  - the target was beyond the weapon's reach.
- Otherwise it lists *possible* causes and says no cause was established.
- It never uses information the crew could not have.

**With the developer tools on** (and in test scenarios), a `[DEV]` line adds the exact technical outcome: the closest approach and why it missed.

### Solution quality

The periscope shows **SOLUTION QUALITY: NONE, POOR, FAIR, GOOD or FIRM**, with the error bars behind it: `RNG 3.1 KM ±4% · CRS 270 ±6° · SPD 12 KT ±1`.

**It is not a chance of a hit**, and the display says so. It measures how well her motion is known: the expected spread of the aim point at the intercept.

**A FIRM solution can still miss:**
- she turns or changes speed after you fire;
- the seeker fails to acquire, or loses her;
- she is beyond the weapon's reach;
- the wire parts.

### Being hunted

**The pursuit status is the crew's assessment, from evidence only:**
- active sonar heard, and how close it sounded;
- a warship held on sonar or in sight that keeps closing;
- a foreign patrol aircraft about;
- intelligence of a search;
- whether we have given ourselves away (for example by firing).

**Levels:**
1. no pursuit indication;
2. possible search;
3. probable pursuit;
4. confirmed pursuit.

**Where to see it:**
- the **HUNTED** line on the conn panel, with the reasons;
- the status flags on the command bar;
- the Captain's Log, which records each change.

**When it gets worse than you were last told:**
- Miller tells you;
- time drops to ×1;
- at probable pursuit or worse, the boat goes to battle stations.

**The crew can be wrong in both directions:**
- a ship that has not yet heard or seen anything can be searching without anyone aboard knowing;
- a warship that merely passes close can look like a hunter.

### The chart

**Find (F).** Type part of a name to search:

| Searches | Examples |
|---|---|
| Charted names | islands, banks, troughs, straits |
| Harbours, stations and anchorages | new in this build |
| Rocks, wrecks, shoals and obstructions | |
| Navigation areas | the patrol sector, the rendezvous, the pack-ice limit |
| Your route | waypoints |
| What the boat already holds | contacts, reported units, aircraft, reported icebergs |

- Typing "storoya" finds STORØYA.
- Click a result, or press Enter for the first one. The chart centres on it and marks it.
- Nothing the boat does not know is ever listed.

**Legend (G).**
- It opens and closes with **G**, or with the button at the top left.
- Every symbol is drawn by the chart's own code, so the legend always matches the chart, in the day colours and the low-light scheme.
- Every entry has words; nothing relies on colour alone.

### Time compression

**Levels:** ×1, ×2, ×4, ×10, ×25, ×50, ×100, ×250.

**Limits:**

| Situation | Highest |
|---|---|
| Battle stations, a weapon running, flooding | ×4 (was ×2) |
| Alert (a contact within about 4 km, silent running) or below safe depth | ×25 |
| Otherwise | ×250 |

The simulation steps are the same small steps at ×4 as at ×1.

**What drops time to ×1:**
- emergencies, damage, ice, shoaling water and signals, as before;
- intelligence of a search, or of a foreign unit within about 60 km;
- a new contact heard or seen, or within about 15 km. A distant AIS report no longer stops you.

**Advance until event (J, or ▸▸ on the command bar).**
- The world runs at the highest rate the situation allows. Nothing is skipped: the boat sails every metre and every ship, sensor and crew member keeps going.
- While it runs, the flags read **ADVANCING UNTIL EVENT**.
- **It stops for:**
  - new contacts;
  - threats and pursuit;
  - significant intelligence;
  - urgent crew and engineering reports;
  - ice and shoaling water;
  - waypoints;
  - signals.
- **It also stops when:**
  - the situation becomes tactical;
  - the boat goes below safe depth;
  - the battery runs low;
  - water under the keel gets short;
  - twelve hours pass without incident.
- **When it stops,** the reason is shown and logged.
- **J or Esc** stops it at once.
- **It refuses to start** in a tactical situation.

### Mission briefing

**When it appears:** when a campaign begins or is loaded. Reopen it with **F1**, or **Mission briefing** in the orders (**Tab**).

**What it covers:**
- orders;
- objectives, as given;
- position, sector and rendezvous;
- known threats;
- recent developments (from the log);
- what is outstanding;
- the boat's condition.

It is built only from what the captain already knows: older saves get one too, and nothing pending or hidden is shown.

**While it is open,** the world waits. **Esc** or **Enter** closes it.

### Watchbill

The cabin's watchbill lists everyone aboard, in three groups:
- the control-room (bridge) watch;
- the machinery watch;
- the galley.

**Each person's state:** ON WATCH, ON DUTY, OFF DUTY, RESTING or UNAVAILABLE.

Basse is listed under the galley. His work there is duty, not a bridge watch. Below the list, the stations show who is standing each one now.

### Test scenarios

**From the main menu: Test Scenarios.**

**Presets:**

| Preset | What it sets up |
|---|---|
| **Torpedo Range** | Targets stopped, steaming steadily or zig-zagging |
| **Submarine Pursuit** | Anti-submarine ships with a rough position on you come looking |
| **Arctic Navigation** | North through drifting icebergs to a waypoint at the pack edge |
| **Naval Encounter** | Foreign warships on patrol across your track |
| **Mixed Traffic** | Cargo ships, trawlers, a research ship and a warship or two |

**Parameters:**
- opposing and allied units;
- difficulty;
- start distance;
- weather and light;
- start depth and speed;
- target behaviour (Torpedo Range only).

**How a scenario runs:**
- in open water far from the patrol area;
- with the story switched off;
- with its own objective and briefing;
- with the developer diagnostics on: exact torpedo outcomes, and a panel with the truth about the scenario's units (**F7** hides it).

**Restart and leave:**
- **F8**, or **Restart Scenario** in the menu, starts it again with the same set-up.
- **Esc** opens the menu; **Main Menu** leaves.

**Nothing is saved.** Saving and autosave are refused, and campaign saves, progress and settings are untouched.

## Playtest corrections: weapons, damage confirmation, poker, drone

A second round of corrections from hands-on play.

### Poker after an engagement

**What was wrong.** After sinking two ships, cards stayed refused:
- The boat was still at **battle stations** and rigged for **silent running**. Both are orders the captain gives, and both stay in force until the captain lifts them.
- Nothing said so. Basse only said *"When nobody is chasing us"*, even when nobody was, and the orders menu greyed the card game out without a reason.
- Finishing an engagement never disabled cards permanently. Once the boat stood down, cards came back.

**What changed:**
- **A reason every time.** When cards are not possible, the reason is given in Basse's answer, on screen, in the orders menu and on the mess panel:
  - an emergency;
  - a weapon running;
  - a pursuit;
  - battle stations or silent running, saying where to lift them;
  - a warship close aboard.
- **The XO recommends standing down** when the plot has been quiet for ten minutes. With the conn (you resting), he stands the boat down himself, and logs it.
- **A harmless ship nearby no longer stops a game.** A neutral merchant passing within 4 km keeps the watch alert but does not cancel cards.
- **If nobody is free,** you are told who is where. The off-watch crew play in the day and evening. In the evening the four-player table, and the Mess Cup, fill.
- **A genuine emergency still rules cards out,** and breaks up a game already running.

### Weapons on the chart

**Your own torpedoes** are drawn after launch:
- **Live by wire.** While the guidance wire holds, telemetry gives the torpedo's real position: a filled dart with a short track, labelled *WIRE*.
- **Estimated.** Once the wire parts, the position is dead-reckoned from the last report: an open dart, a dashed track, a growing circle of doubt, labelled *EST.* It may have turned to home, so the true position can be anywhere in the circle.
- **Ended.** When the run ends it is marked with the time and how it ended (*detonation heard*, *run complete*, *estimated end of run*), greyed and crossed out, and dropped after ten minutes.

**Detonations heard** (your hits, secondary explosions) are marked where the plot places them.

**Enemy torpedoes and charges** (depth charges, ASW weapons) appear **only once detected**, never because they exist. A detected weapon that is no longer heard is dead-reckoned and then marked no longer tracked.

> **Note:** in this build, opposing ships and aircraft do not yet attack the boat with torpedoes, ASW rockets or depth charges, and the boat carries no countermeasures. These symbols are ready for when they do, and are in the legend.

**Under time compression,** positions are worked out from time, not frame by frame, so they are right at any speed.

**The legend (G)** lists every weapon symbol.

### Damage assessment on request

**How to ask:**
- **Tab → Fire control: damage assessment of S…** for the ships you have engaged (most recent first);
- the **Damage assessment** button in the contact list (**K**).

**The answer is one of:**
- **CONFIRMED SUNK**: seen to go under, or breaking-up noises *and* a report of her loss;
- **PROBABLE SINKING**: breaking-up noises, settling or a heavy list, or a report of her loss alone;
- **CONFIRMED DAMAGED**: fire, a list or trim seen, or secondary explosions heard;
- **PROBABLE DAMAGE**: a detonation at the expected time, but no effect seen or heard;
- **NO DAMAGE CONFIRMED**: no detonation, and she has been seen or heard since, apparently unharmed;
- **STATUS UNKNOWN**: no detonation, and nothing seen or heard of her since.

**It is built only from what the crew have:**
- detonations heard;
- what was seen through the periscope and heard on sonar since;
- whether contact was lost;
- reports received later.

**It says what is still uncertain,** for example:
- nobody has seen her go under;
- no report of her loss has come in;
- the contact is not held now.

**Asking again** without new evidence gives the same answer.

**Later evidence:** once you have asked, a report or an observation that changes the answer is logged as an **update**. The earlier answer stays in the Captain's Log.

### Reconnaissance drone (limited)

**Is it plausible?** For a small conventional submarine in a near-future setting, a small battery quadcopter carried as **trial equipment** is plausible. It is launched and recovered by hand from the bridge. This is not standard fit on most submarines, and the game treats it as an experiment with real limits. **Two are aboard.**

**Launch:** Tab → *Launch the reconnaissance drone*.
- Only with the boat **surfaced**, at **6 kt or less**, and in a moderate sea.
- Not in a gale.
- The menu says why when it cannot go up.

**Fly:** select a point on the chart, then Tab → *Drone: fly to the chart selection*.
- Its radio link reaches about **6 km**; it will not go further.
- It flies about **22 minutes**, less in cold, snow, fog or wind.
- It turns for home on its battery by itself.

**Recover:** Tab → *Drone: return and recover*. Recovery also needs the boat surfaced, slow and in a moderate sea.

**What it sees:**
- ships on the surface and ice, within what its camera can make out in the light and weather (up to about 6 km);
- it classifies ships within about 3 km;
- it can read a ship's name only very close, about 600 m.

**What it cannot do:** it never detects anything submerged.

**Risks:**
- foreign warships nearby may notice it (radar, lookouts, its radio link), and a drone over the sea means a launcher not far off;
- it can be lost to wind, icing or a flat battery;
- **diving with it up abandons it.**

**Saving** is not possible while it is in the air.

**On the chart:** a small quad cross, its leg to where it is going, and the radio-reach ring.

**Deferred:** a live camera view from the drone. Its observations reach the boat as contacts, classifications, names and ice, through the chart, the contact list and the log. A video view would be a separate piece of work.

## Controls

| Keys | Action |
|---|---|
| **1 – 0** | Views: 1 control room · 2 periscope · 3 exterior · 4 sonar · 5 chart · 6 mess · 7 cabin · 8 engine room · 9 torpedo cam · 0 cinematic |
| **A / D** | Ordered course −10° / +10° (hold Shift for 1°) |
| **W / S** | Telegraph up / down (all stop to flank) |
| **O / P / Z / X** | Surface / periscope depth / deeper / shallower |
| **M** | Raise or lower the masts |
| **B** | Emergency blow (from 40 m or deeper) |
| **Tab** | Orders to the crew: also the mission briefing, damage assessments of ships engaged, and the drone |
| **F1** | Mission briefing |
| **K** | Contact list |
| **I** | Naval intelligence |
| **L** | Captain's Log |
| **N** | Fast to the next waypoint |
| **J** | Advance until event (J or Esc stops it) |
| **+ / −** | Time compression (×1 ×2 ×4 ×10 ×25 ×50 ×100 ×250) |
| **V** | Exterior view: above or below the surface |
| **F5** | Quick save (not in test scenarios) |
| **F7 / F8** | Test scenarios only: diagnostics panel / restart |
| **F10** | Developer panel (when enabled in Settings) |
| **Space** | Fire, from the periscope view (press again to confirm) |
| **H** | Help |
| **U** | Hide the interface |
| **Esc** | Close the open panel or briefing, stop an advance, or open the game menu |

**Chart:**

| Action | How |
|---|---|
| Find | **F** |
| Legend | **G** |
| Select | Click |
| Steer for the selection | Double-click or **Enter** |
| Add a waypoint | **Shift+click** |
| Remove the last waypoint | **Backspace** |
| Zoom | Wheel or **PgUp / PgDn** |
| Pan | Right-drag |
| Centre on the boat | **C** |
| Fast to the next waypoint | **N** |

**Periscope:**
- **Train:** drag or **Q / E**.
- **Zoom:** wheel.
- **Change sensor:** **T**.
- **Mark a bearing:** **Enter**.
- **Fire:** **Space**.
- **Fire control:** keep the crosshair on her to build a solution. The longer you watch, the better it gets.

**Control room:** **Q / E** change viewpoint, click a station to use it, **R** toggles red lighting.

## Playtest notes: worth trying

1. **Turning.** Order a 90° turn at 3, 9 and 18 kt and watch the HELM line and the chart.
2. **Torpedo Range, stopped targets.** Watch a target for a minute, then fire. Fire again after a two-second glance and compare.
3. **Torpedo Range, zig-zagging targets, Hard.** Fire and read the post-attack assessment, which shows the `[DEV]` line here. Then compare what the crew could say with what really happened.
4. **Submarine Pursuit.** Go deep, slow down, open the range. Watch the HUNTED line and the log. Try it in fog and darkness.
5. **The campaign.** Press **J** on a quiet transit and see what stops it. Try **F** on the chart ("long", "wreck", "kestrel", a contact number) and open the legend with **G** in both colour schemes.
6. **Load an older Mission 005 save.** The briefing should appear and make sense.
7. **After an attack,** try to call cards. Read why not, stand down when the XO recommends it, and deal.
8. **Ask for a damage assessment** (Tab or K) right after a hit, again after a periscope look, and again after the next broadcast.
9. **Surface in calm weather and launch the drone** towards a contact at the edge of sight. Then dive with it still up to see what happens.

## Known limitations

**Fire control:**
- It is a model. Range, course and speed are estimated for you; you cannot plot by hand or enter your own estimates.
- Seeker mode, run depth and wire commands are not under your control.
- One tube fires at a time.

**Torpedoes:**
- Targets do not hear the torpedo or try to evade it.
- A miss caused only by the target's speed, or by the seeker, can stay "unknown" in normal play. That is deliberate.

**Pursuit:** the assessment is a simple weighing of evidence. It does not know about sonobuoys or helicopters, which the world does not have yet.

**Time:**
- Advance until event stops after twelve quiet hours.
- A contact within about 4 km still limits time to ×25, even a harmless one.

**Test scenarios:**
- Five fixed presets at fixed sites.
- Allied units are coast-guard cutters.
- There are no opposing submarines.
- Difficulty changes target speed and zig-zags, and how alert and persistent the hunters are.
- The region's own traffic and aircraft may wander through.

**The chart:**
- Search finds the charted names plus five harbours, stations and anchorages. The region has no larger ports.
- At small window widths or a large interface scale, the command bar's figures can be cut short.

**Opposing weapons:** opposing ships and aircraft do not yet attack the boat (no torpedoes, ASW rockets or depth charges), and the boat has no countermeasures. The chart is ready for them, but they do not occur in play.

**The drone** has no camera view of its own. Its observations reach you through the chart, the contact list and the log.

**The patrol objective "Remain undetected"** can be marked failed on the other side's judgement, before the crew have evidence of it. This is older behaviour, noted for a later fix.

**Everything listed in `README_MISSION_005.md`** still applies:
- a thinly populated region;
- no helicopters;
- the interiors are interfaces;
- simplified sonar and ship behaviour;
- placeholder crew figures and partial voicing.

## Testing

**Windows:** gameplay and audio have **not** been played on Windows by the developer. The Windows build is produced by GitHub Actions.

**Testing was done on Linux.**

**Headless checks:**

| Area | Checks |
|---|---|
| Cards and sound | cards, sound resolution |
| Interface | pause, control room, saves, UI |
| World and command | world, intelligence, conduct |
| Torpedo | trajectories and collision, interception, miss diagnosis and what normal play may know |
| Helm | turning |
| Command | pursuit, ×4 with a weapon running, advance-until-event stops, chart search, briefing on loaded and older saves, watchbill |
| Scenarios | every preset, and that nothing reaches the saves or settings |
| Combat operations | the reported poker case (two warships sunk, then ordinary operations), the XO standing down, weapon tracks (live, estimated, ended, expired, never undetected, time-step independent), damage assessment requests and their update from a later report, and the drone (launch limits, observation, recovery, loss) |

**Also:**
- a 62-hour simulated patrol: same story course and objectives as before these changes;
- software-rendered screenshots.
