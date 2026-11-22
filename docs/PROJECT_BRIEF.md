# Project Brief — Single design and task handoff record

This is the **master template**, not an active game. Complete it collaboratively when creating a game. This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** Undecided
- **Godot version (pin minor, e.g. 4.x):** 4.7.x for Visual Prototype 001 (user instruction, 2026-11-22); the long-term pin remains part of the unapproved design decisions
- **Premise / core player loop:** Undecided
- **Perspective / art direction:** Undecided
- **Confirmed mechanics and constraints:** None
- **Explicitly out of scope:** Undecided
- **Existing modules / boundaries:** None; no game code in starter pack
- **Testing framework (GUT or GdUnit4) and commands:** Undecided until first implemented module
- **Target platforms:** Undecided (runtime asset overrides currently cover Windows/Linux only; other platforms need an explicit decision)
- **Asset override notes:** Runtime `custom/` folder overrides required; see `assets/README.md`

## Current approved development objective

**Status: Approved in conversation, 2026-11-22 — Prototype 002 "First Contact"** (extends Visual Prototype 001, which the user reviewed). This heading records an objective *after* the user approves it in conversation; it is not an instruction to implement, and a later task needs fresh approval.

- **User approval (reference / summary):** User asked for Prototype 002: a small, enjoyable first engagement (dive, raise periscope, find a ship, fire a torpedo, watch it sink) plus a reusable replaceable-sound system. The 17 design decisions in the feasibility report remain unapproved.
- **Objective (one by default):** Simple depth and periscope controls; one surface ship on a predetermined route; periscope train/zoom/fire; one simplified torpedo that can miss; explosion and a several-second sinking; centralized audio manager with custom > template > silence playback and an external `custom/audio/` folder.
- **In scope:** The above, keyboard plus on-screen controls, a replay control, template sounds, sound and controls READMEs, portable Windows x64 build via GitHub Actions; Godot 4.7.x; MP3 overrides (user request).
- **Out of scope:** Full submarine simulation, realistic fire control or manual targeting, sonar system, dynamic campaign, crew management, advanced enemy AI or counterattack, installer.
- **Acceptance criteria / done when:** The game launches; the submarine dives and surfaces; the periscope works; a torpedo can be launched; the ship can be hit and sunk; sounds play and an external custom sound overrides a template.
- **Relevant module tests:** Approved exception: no module test suite ("no deep testing"); headless launch check plus a scripted check of override precedence and fallback.
- **Relevant integration/manual checks:** Scripted render of the dive, periscope and fire-hit-sink sequence; exported build loading an override from `custom/audio/` next to the executable; the user's review of the Windows build.

## Proposals awaiting user approval

None. Keep proposals clearly separate from confirmed decisions and active work. Do not promote them to tasks automatically.
