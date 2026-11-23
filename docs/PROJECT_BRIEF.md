# Project Brief — Single design and task handoff record

This brief now records the active game, Wolf of the Deep. This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** Wolf of the Deep: The Battle for the Arctic (user, Mission 003 brief)
- **Godot version (pin minor, e.g. 4.x):** 4.7.x (user instruction for Visual Prototype 001, Prototype 002 and Mission 003)
- **Premise / core player loop:** Grounded contemporary / near-future submarine command in the Arctic (no sci-fi, paranormal or impossible technology; not an arcade shooter). Captain-first command: navigate, investigate contacts, delegate, rest; a living crew; a world that does not revolve around the captain (user, Mission 003)
- **Perspective / art direction:** Realistic 3D exterior and periscope views with clear 2D displays; interior compartments (user, Mission 003)
- **Confirmed mechanics and constraints:** Crew functions bound to replaceable roles, not people; imperfect sensor information; rest and delegation with standing orders; optional, interruptible Texas Hold'em for persistent candy; Basse's singing only in short muffled fragments; inbox recordings are an immutable archive; story spoilers kept in clearly marked internal files only (user, Mission 003)
- **Explicitly out of scope:** Installer; crew injury or loss implementation (architecture only) (user, Mission 003)
- **Existing modules / boundaries:** `src/` modules: core (settings, campaign saves), log (Captain's Log), nav (chart data), intel (intelligence database, delayed reports, damage assessment), traffic (regional ships and aircraft), ocean, sky, environment (weather), world (clock, regional geography, terrain streaming, Arctic area and ice), submarine, ships, weapons, encounter, sensors, crew (crew, dialogue, watch officer, figures, conscience), interior, command_room, control_room_pilot, patrol (patrol, command standing, spoiler-marked story), poker, audio, ui, cameras, fx, main (composition and controls)
- **Testing framework (GUT or GdUnit4) and commands:** Approved exception: practical checks only, no test framework (user, Mission 003). Commands: `godot --headless --path . -s tests/check_poker.gd`, `godot --headless --path . -s tests/check_audio.gd`, and with `--fixed-fps 30`: `tests/check_pause.gd`, `tests/check_control_room.gd`, `tests/check_save.gd`, `tests/check_ui.gd`, `tests/check_world.gd`, `tests/check_intel.gd`, `tests/check_conduct.gd`; `godot --headless --path . -- --sim-hours=62`
- **Target platforms:** Windows x64 playtest builds via GitHub Actions (runtime asset overrides cover Windows/Linux; other platforms need an explicit decision)
- **Asset override notes:** Runtime `custom/` folder overrides required; see `assets/README.md` and `docs/AUDIO_LIBRARY.md`

## Current approved development objective

**Status: Approved in conversation, 2026-11-22 — Development Mission 003 "A Living Submarine"** (builds on Prototype 002). This heading records an objective *after* the user approves it in conversation; it is not an instruction to implement, and a later task needs fresh approval.

- **User approval (reference / summary):** User asked for a playable, atmospheric open-patrol vertical slice and explicitly asked Claude to make grounded creative and practical design decisions independently, without routine approvals.
- **Objective:** A small open Arctic area (navigation, ice hazards, independent vessels, emerging situations); a living crew with routines, relationships and sparse talk; delegation and rest with standing orders; the creator's recordings integrated through a registry with overrides; optional mess-table poker; torpedo functionality preserved.
- **Priorities (user):** 1 stable navigable submarine, 2 open Arctic patrol, 3 living crew, 4 delegation and rest, 5 existing audio, 6 polish, 7 poker.
- **In scope:** The above; `AUDIO_LIBRARY.md`; controls/README; known limitations; portable Windows x64 artifact via GitHub Actions.
- **Out of scope:** Installer; crew injury/loss beyond architecture; claiming Windows gameplay or audio verification that did not happen.
- **Acceptance criteria / done when:** A playable patrol with an achievable resolution; spoiler-free delivery notes; Windows artifact link, launch instructions, controls and limitations provided.
- **Relevant checks:** Headless launch; simulated patrol; card-engine and sound-resolution checks; software-rendered screenshots of the main views.

## Current mission (branch `claude/mission-005-living-arctic`)

**Status: Approved in conversation, 2026-11-23 — Development Mission 005 "The Living Arctic"** (builds on the control room pilot with its visual polish, commit `e78a4cb`; not to be merged automatically).

- **Objective (summary):** main menu, persistent saves, settings and developer tools; persistent command bar; periscope and exterior camera fixes; a coherent ~600 × 600 km charted region with a seabed that agrees with the chart, soundings, ice and restricted navigation, dangerous depth, route planning and time compression; contact list, Captain's Log, intelligence, reputations, battle damage assessment, delayed reports, aircraft; freedom of command and crew loyalty foundations; interiors, vessels and icebergs; audio and poker preserved.
- **Priorities (user):** A playability > B navigation > C world / intelligence > D visuals > E emergent systems. No spoilers in delivery notes.
- **Recovery checkpoints:** R0 baseline, R1 command interface, R2 Arctic navigation, R3 living world, R4 final integration. Each is a separate remote backup branch (`backup/mission-005-r*`); Windows builds at R0, R2 and R4.
- **Delivery notes:** `docs/MISSION_005.md`.

## Earlier experiment (branch `claude/control-room-pilot`)

**Status: Approved in conversation, 2026-11-22 — Mission 004C "The Control Room — Visual Quality Pilot"** (experiment; not to be merged automatically). The earlier 2D cutaway experiment (`claude/interior-rework-experiment`) was rejected by the user and is not built upon.

- **Baseline:** commit `cc666aa` (Mission 003 + Esc fix); remote backup branch `backup/pre-interior-rework-004`.
- **Objective:** one convincing, realistic control room that belongs with the exterior; fixed viewpoints with transitions; restrained crew presence; existing gameplay, audio, dialogue and exterior preserved.
- **Chosen technique (Claude's proposal for the user to judge):** hybrid — the room modelled and path-traced offline (Blender/Cycles via `tools/interior/`), composited in Godot with live displays, lamps, red lighting and subtle motion.
- **Checks:** `tests/check_control_room.gd` (run with `--fixed-fps 30`), plus the existing checks.

## Proposals awaiting user approval

None. Keep proposals clearly separate from confirmed decisions and active work. Do not promote them to tasks automatically.
