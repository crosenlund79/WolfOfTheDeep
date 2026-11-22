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

**Status: Approved in conversation, 2026-11-22 — Visual Prototype 001 "Silent Sea".** This heading records an objective *after* the user approves it in conversation; it is not an instruction to implement, and a later task needs fresh approval.

- **User approval (reference / summary):** User asked to "create Visual Prototype 001" to judge the look and feel of a modern submarine simulator before investing in mechanics; research report kept as reference; the 17 design decisions in the feasibility report are explicitly **not** approved.
- **Objective (one by default):** A visual prototype: convincing modern submarine, atmospheric 3D ocean, lighting and weather, immersive presentation (exterior camera, periscope view, sonar/tactical displays, small command room). Cosmetic or staged behaviour.
- **In scope:** Visuals and presentation; Godot 4.7.x; separate working branch; source plus a portable Windows x64 build produced by GitHub Actions (export preset and workflow approved for this objective).
- **Out of scope:** Acoustic duel, sonar physics, weapons simulation, enemy AI, campaign systems, complex architecture.
- **Acceptance criteria / done when:** The prototype launches and can be explored; the user judges it visually.
- **Relevant module tests:** Approved exception: no module test suite for this prototype ("no deep testing"); a headless launch smoke check only.
- **Relevant integration/manual checks:** User's visual review of the Windows build.

## Proposals awaiting user approval

None. Keep proposals clearly separate from confirmed decisions and active work. Do not promote them to tasks automatically.
