# Deferred observations — not approved tasks

Record only observations found during approved work. An item here is **not** permission to implement or add to the current objective.

| Date | Observation | Context |
| --- | --- | --- |
| 2026-11-22 | Asset resolver (guideline 3) not yet implemented: Visual Prototype 001 generates all graphics and audio procedurally and ships no image/audio files. | Implement and test the `custom/` resolver when the first real asset files are introduced. |
| 2026-11-22 | Frame rate on real GPUs is unmeasured; development renders used a software Vulkan driver. An F9 performance mode exists. | Visual Prototype 001 review on the user's Windows PC. |
| 2026-11-22 | The Windows executable was not launched on Windows by Claude; its packed data was verified by loading it with the Linux engine (headless and rendered). | Visual Prototype 001 GitHub Actions build. |
| 2026-11-23 | Headless runs report audio stream playbacks as "leaked / still in use" at exit (engine warning when quitting with sounds playing). Present before Mission 005; harmless. | Mission 005 R2 checks. |
| 2026-11-23 | Regional fjords are single winding channels; branching fjords, sills and glacier fronts would read more naturally on the chart. | Mission 005 R2 chart review. |
| 2026-11-23 | Seen from just below the surface at a grazing angle, the distant underside of the sea surface shows as a crisp band that does not blend with the underwater fog. | Mission 005 R4 exterior camera work. |
| 2026-11-23 | The engine room, mess and cabin 3D rooms still exist behind the new 2D interfaces and keep rendering while hidden. | Mission 005 R4 interiors. |
| 2026-11-23 | The "Remain undetected" objective is marked failed the moment a warship's hidden assessment crosses its threshold, so the objective list (and the briefing that repeats it) can tell the player something the crew could not know. Pre-existing behaviour. | Mission 006 R2, briefing and pursuit work. |
| 2026-11-23 | At 1920 px wide the command bar's live values (heading, rudder, depth, keel, battery, hull) only just fit; at smaller widths or larger UI scale they clip. | Mission 006 R2 command bar. |
| 2026-11-23 | The headless patrol simulation (`--sim-hours`) autosaves into the normal save folder like a real campaign; a check that snapshots the save folder must not run alongside it. | Mission 006 R3 scenario isolation check. |
| 2026-11-23 | Opposing ships and aircraft never attack the boat: no torpedoes, ASW rockets, depth charges or sonobuoys are simulated, and the boat carries no countermeasures. The chart's weapon layer has a detection hook and legend entries ready for them. | Mission 006 playtest corrections, weapons on the chart. |
| 2026-11-23 | The reconnaissance drone reports through contacts, the chart and the log; a live camera view from it is not implemented. | Mission 006 playtest corrections, drone. |
| 2026-11-23 | Run-to-run variation in the 62 h simulation is large (14 to 21 wakes across runs with the same code), mostly from the story warship's movements; comparisons should use stages and objectives, not wake counts. | Mission 006 playtest corrections, simulation. |
