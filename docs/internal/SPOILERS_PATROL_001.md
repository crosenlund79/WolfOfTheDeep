# ⚠ SPOILERS: Patrol One story notes (internal)

> **Do not read this if you want to play Patrol One unspoiled.**
> These are internal design notes for the authored situations.
>
> Player-facing documents, summaries, commit messages and build notes must not repeat anything here.
>
> The code lives in `src/patrol/story_patrol_001.gd`, which carries the same warning.

## Principles

**The world runs on its own clock.** Situations unfold whether or not the captain watches. Everything the captain learns comes through sensors, signals and the crew, so it can be partial, late or missed.

**Choices are ordinary command actions.** Where the boat goes, whether it comes to periscope depth, what is transmitted, whether to surface. There is no dialogue tree.

**No moralising.** The debrief states consequences plainly.

## Vessels

| Vessel | Behaviour |
|---|---|
| **ARKTIS BRIDGE** | A merchant on passage, with AIS on. Crosses the southern half of the area westbound and leaves. |
| **HAVTIND** | A trawler with nine crew, working Kestrel Bank (west of Ravnøya). |
| **POLAR MERIDIAN** | A research vessel. Loops along the ice edge in the sector at 6 kn, with stops. |
| Foreign patrol vessel | No name and AIS off. Patrols a loop through the eastern sector. Pings occasionally, and investigates when its suspicion builds from radar, lookouts or our noise. |
| Unidentified submarine | Quiet, single shaft. Hidden until Day 1, 21:00. It then shadows POLAR MERIDIAN at about 1 km until about Day 2, 04:30, and leaves north under the ice. If we come within 1.5 km, or within 4 km while noisy, for about 2 minutes, it notices us, leaves early and counts as counter-detection. |

## Timeline

**Weather:**

| Time | Condition |
|---|---|
| Day 1, 14:00 | Overcast |
| Day 1, 20:30 | Clear night (aurora likely) |
| Day 2, 05:00 | Fog |
| Day 2, 10:00 | Overcast |
| Day 2, 15:30 | Snow |
| Day 2, 18:30 | Gale |
| Day 3, 06:00 | Overcast |
| Day 3, 13:00 | Clear |

**Events:**

| Time | Event |
|---|---|
| Day 1, 18:00 | PRIORITY signal: POLAR MERIDIAN reports unexplained hydrophone noise. Optional objective: classify without interfering or being detected. Requires about 15 minutes of classified tracking. |
| Day 2, 12:05 | Basse's 58th birthday at lunch. A small, ordinary moment, recorded in crew history. |
| Day 2, 18:45 | HAVTIND finally leaves the bank and runs east for home at 5 kn, in the gale. |
| Day 2, 19:15 | Engine failure. HAVTIND drifts toward the rock off Ravnøya's southwest shore and reaches it after about 7.5 hours. Sonar (if tracking) reports the shaft noise stopping, and Miller suggests a mast to listen on channel 16. A MAYDAY is queued on VHF; it is heard only with a mast up (or surfaced). |

## The HAVTIND choices

1. **Ignore it.** She goes aground. The coast guard recovers three survivors next morning, and fuel oil reaches the bird cliffs.
2. **Relay through Northern Command.** At periscope depth with masts up, use Orders → *Radio: relay the distress call*. The transmission slightly raises the patrol vessel's suspicion. The patrol vessel (acting as coast guard) steams to HAVTIND at 17 kn and takes her in tow if it arrives before she grounds. HQ acknowledges and withholds the source.
3. **Go ourselves.** Surface and stay within 600 m of her at 5 kn or less for about 25 minutes. All nine are taken aboard. The patrol is compromised (counter-detection), and the debrief says so plainly.

Whatever happens to the people, if she reaches the rock, the oil-sheen consequence applies.

## Firing

Firing at any ship is possible. The XO challenges once (we are not at war), and a second press fires. It is logged and counts as counter-detection. Crew history records it, and the debrief leads with it.

## Debrief lines

`StoryPatrol001.debrief_notes()` picks lines from these flags:

- `visitor_tracked` / `visitor_alerted`
- `we_rescued` / `crew_saved_by_coastguard` / `trawler_lost` / `trawler_failed`
- `oil`
- `fired`

## Ideas for later patrols (not implemented)

- The submarine's signature could reappear.
- HAVTIND's survivors (or their families) could be met in port.
- Crew history and relationships already persist in `user://wolf_crew.json`.
