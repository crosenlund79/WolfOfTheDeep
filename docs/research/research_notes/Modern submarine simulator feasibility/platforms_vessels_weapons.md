# Modern Submarine Platforms, Vessel Behaviour, Navigation, Weapons and Damage Models for a Godot 4 Command Simulator

Research notes, November 2026. Research only: no implementation code, no proposal here is an approved objective.

**Label key used throughout**
- **[Official]**: stated by a navy, government body or manufacturer.
- **[Reported/approx]**: publicly reported or approximate figure from defence press, reference sites or secondary summaries. Not authoritative; real values may be classified.
- **[Community]**: fan guides, forum posts, reviews or patch notes about a game. Used for design patterns only.
- **[Academic/technical]**: course notes, papers or technical reports.
- **Inferences**: researcher recommendation or inference, not sourced fact.

**Method caveat (applies to all sections):** Direct page fetches failed for several primary sources: navy.mil fact files (HTTP 403), royalnavy.mod.uk (403), aph.gov.au (403), seaforces.org (503), moddb.com (403), and m.usni.org (blocked by this session's network allowlist). Findings citing those URLs come from search-engine extracts of the page, not a full read. Re-verify them before quoting verbatim in a final report. Official navies typically publish floor figures (for example "25+ knots"). These notes never treat such figures as true maximums. No classified characteristics (true depth, acoustic signature, exact top speed) are presented as known.

## Q1. SSN vs SSK/AIP: publicly reported characteristics (endurance, speed, batteries, snorkelling, AIP types, Li-ion, missions, weapons, crew)

### Takeaway
Nuclear attack submarines (SSNs) such as Virginia and Astute buy air-independent endurance limited mainly by food, high sustained submerged speed (officially only "25+ knots") and large weapon loads (about 38 to 50 weapons, up to 40 Tomahawks on VPM-equipped Virginias). The price is very high cost, size and crew (about 100 to 145). Conventional diesel-electric boats (SSKs) and their air-independent propulsion (AIP) variants are small and littoral-oriented. The AIP types are fuel cell (Type 212A), Stirling (Gotland, early Sōryū), MESMA (Agosta 90B/Scorpène offer) and Li-ion without AIP (late Sōryū, Taigei). AIP stretches submerged endurance from days to roughly 2 to 3 weeks (reported), but only at low AIP speeds of about 5 to 10 kt (reported, conflicting). Snorkelling is reduced, not eliminated, so "indiscretion" remains the defining SSK constraint.

### Cited Findings

**SSN: US Virginia class (and US predecessors for context)**
- [Official] The US Navy fact file lists Virginia-class speed as "25+ knots (28+ miles per hour, 46.3+ kph)". The Submarine Industrial Base Council gives the same floor figure. — [US Navy fact file](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2169558/attack-submarines-ssn/); [Submarine Industrial Base Council](https://submarinesuppliers.org/programs/ssn-ssgn/virginia-class/)
- [Official vs Reported] Virginia crew figures conflict. The US Navy fact file gives 145 (17 officers, 128 enlisted). SIBC gives 132 (15 officers, 117 enlisted). Army Recognition says the layout accommodates about 135. — [US Navy fact file](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2169558/attack-submarines-ssn/); [SIBC](https://submarinesuppliers.org/programs/ssn-ssgn/virginia-class/); [Army Recognition](https://armyrecognition.com/military-products/navy/submarines/attack-submarines/virginia-class-ssn-774)
- [Reported/approx] Block V Virginias add the Virginia Payload Module (four additional payload tubes), raising missile capacity to as many as 40 Tomahawks. Earlier blocks use two large bow Virginia Payload Tubes of six Tomahawks each. — [Army Recognition](https://armyrecognition.com/military-products/navy/submarines/attack-submarines/virginia-class-ssn-774); [SIBC](https://submarinesuppliers.org/programs/ssn-ssgn/virginia-class/)
- [Reported/approx, weak] Virginia has four torpedo tubes. This comes only from a Wikipedia snippet about a 2004 test firing and needs verification. — [Wikipedia: USS Virginia (SSN-774)](https://wikipedia.com/wiki/USS_Virginia_(SSN-774))
- [Official] Seawolf has no VLS but eight torpedo tubes and can hold up to 50 weapons in its torpedo room. Los Angeles-class boats (later units) have 12 VLS tubes for Tomahawk. — [US Navy fact file](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2169558/attack-submarines-ssn/)
- [Official] CRS (2021 vintage) reported 34 Virginias procured through FY2021 and an estimated procurement cost of about $3.45 billion per boat. This shows why SSNs are rare national assets. — [CRS RL32418 (2021) via EveryCRSReport](https://www.everycrsreport.com/files/2021-07-29_RL32418_6ef6f5932d3fbad147f7b2462d158a22df207505.html)
- [Technical/Official-adjacent] FAS defines "tactical speed" as the speed at which a submarine is quiet enough to track enemy submarines effectively. "Maximum burst speed" is the propulsion maximum regardless of self-noise. It cites Seawolf's tactical speed of 25 kt as a significant fraction of its burst speed. — [FAS DOD-101: Submarines](https://man.fas.org/dod-101/sys/ship/deep.htm)

**SSN: UK Astute class**
- [Official] HMS Audacious has "provision for up to 38 weapons in six 21-inch torpedo tubes". — [Royal Navy: HMS Audacious](https://www.royalnavy.mod.uk/organisation/units-and-squadrons/astute-class/hms-audacious)
- [Official] The weapon load is a mixture of Spearfish heavyweight torpedoes and Tomahawk Block IV/V cruise missiles. The class can strike ground targets "hundreds of miles inland". — [BAE Systems: Astute class](https://www.baesystems.com/en/product/astute-class-submarines); [Royal Navy: Astute class](https://www.royalnavy.mod.uk/equipment/submarine/astute-class)
- [Conflict] Astute crew: BAE Systems and Wikipedia cite 98. The Royal Navy's HMS Audacious page lists 21 officers, 39 senior rates and 69 junior rates, about 129 in total. The gap is unexplained (possibly patrol crew vs total complement). — [BAE Systems](https://www.baesystems.com/en/product/astute-class-submarines); [Royal Navy: HMS Audacious](https://www.royalnavy.mod.uk/organisation/units-and-squadrons/astute-class/hms-audacious); [Wikiwand: HMS Astute](https://www.wikiwand.com/en/articles/HMS_Astute_(S119))
- [Reported/approx] Astute can carry only about three months of food for its crew. This is the practical SSN endurance limit, not fuel. — [Wikiwand: HMS Astute](https://www.wikiwand.com/en/articles/HMS_Astute_(S119))
- [Reported/approx] Tomahawk range is reported as more than 1,000 miles (1,600 km). This came from a search extract, and attribution to the UK government news item is unverified. — [GOV.UK: Navy sub fires first Tomahawk missile](https://gov.uk/government/news/navy-sub-fires-first-tomahawk-missile)

**SSN general**
- [Reference/secondary] Nuclear propulsion is completely independent of air, so the boat need not surface frequently. Conventional boats' batteries limit them to a few days submerged at slow speed. Nuclear boats can be noisier than battery-electric boats because of reactor coolant pumps and steam machinery. — [Wikipedia: Nuclear submarine](https://EN.wikipedia.com/wiki/Nuclear_submarine)

**SSK/AIP: fuel cell (German Type 212A / 212CD; Type 214 not covered)**
- [Reported/approx] Type 212A endurance is about three weeks submerged without snorkelling and about 12 weeks overall. — [Seaforces Online: Type 212A](https://seaforces.org/marint/German-Navy/Submarine/Type-212A-class.htm)
- [Reported] A Type 212A made an 18-day submerged transit without snorkelling in 2013. — [National Interest](https://nationalinterest.org/node/208476)
- [Reported] Conventional boats must snorkel to recharge batteries. The Type 212CD's AIP lets it stay down for weeks. — [The Defense Post: Type 212CD guide (Aug 2026)](https://thedefensepost.com/2026/08/09/type-212cd-submarine-guide/)

**SSK/AIP: Stirling (Swedish Gotland; first ten Japanese Sōryū)**
- [Official, manufacturer] Saab says the Stirling system means the submarine does not have to surface to charge batteries, which increases submerged endurance "from days to weeks". — [Saab: The secret to the world's most silent submarine](https://saab.com/newsroom/stories/2015/march/the-secret-to-the-worlds-most-silent-submarine)
- [Reported/approx] Gotland endurance is more than 14 days submerged without snorkelling, limited mainly by the liquid oxygen (LOX) carried. — [Wikipedia: Gotland-class submarine](https://en.wikipedia.com/wiki/Gotland_class_submarine)
- [Reported/approx; conflicting] One reference listing gives about 5 kt on AIP vs about 20 kt submerged on battery. An RSIS analysis puts Stirling boats at around 10 kt cruising, "half that of a sub running on batteries". — [Seaforces: Gotland A19](https://seaforces.org/marint/Swedish-Navy/Submarine/Gotland-A19-class.htm); [RSIS (2009): AIP submarines](https://rsis.edu.sg/rsis-publication/rsis/1220-air-independent-powered-submar/)
- [Reported] Forces News headlines the Gotland class as "tailor-made" for protecting the Baltic, a littoral mission profile. — [Forces News](https://www.forcesnews.com/technology/weapons-and-kit/swedens-silent-gotland-class-submarines-tailor-made-protecting-baltic)
- [Reported, title-level only] National Interest recounts a wargame in which a US Navy aircraft carrier was "sunk". It surfaced in Gotland-related searches, but the details were not read. — [National Interest](https://nationalinterest.org/blog/reboot/forgotten-story-how-navy-aircraft-carrier-was-sunk-wargame-179584)

**SSK/AIP: MESMA (French closed-cycle steam turbine)**
- [Reference/secondary] MESMA (Module d'Energie Sous-Marin Autonome) is a closed-cycle steam turbine AIP offered for the Agosta 90B and Scorpène classes. The Agosta 90B figure is about 16 days submerged and 1,400 nmi on AIP. That is not a Scorpène specification, and no Scorpène-MESMA endurance figure was found. Reported cost is about $50 to 60 million per system, retrofittable as a plug-in hull section at major overhaul. — [Wikipedia: Air-independent propulsion](https://Www.Wikipedia.org/wiki/Air-independent_power); [RSIS](https://rsis.edu.sg/rsis-publication/rsis/1220-air-independent-powered-submar/)

**Lithium-ion without AIP (Japan: late Sōryū, Taigei)**
- [Reported] Oryu, the 11th Sōryū, was the first submarine with GS Yuasa lithium nickel cobalt aluminium oxide batteries. They replaced the Kockums Stirling AIP fitted to the previous ten boats, and the final two Sōryū (Oryu, Toryu) both moved to Li-ion. — [Shephard Media](https://www.shephardmedia.com/news/naval-warfare/li-ion-answer-japanese-submarines/)
- [Reported] Taigei has no AIP. It relies on stored battery energy submerged and diesel generators when snorkelling. — [19FortyFive (Jun 2026)](https://www.19fortyfive.com/2026/06/japans-soryu-submarines-started-as-aip-hunters-and-ended-as-battery-pioneers-the-quiet-boats-guarding-the-first-island-chain/)
- [Reported] Li-ion's stated advantages are higher discharge rates, faster recharge and higher energy density. It saves weight and complexity by making AIP unnecessary for endurance. — [US INDOPACOM (repost of press report)](https://www.pacom.mil/Media/News/News-Articles/Article/564673/japan-to-make-major-switch-on-sub-propulsion/); [Shephard Media](https://www.shephardmedia.com/news/naval-warfare/li-ion-answer-japanese-submarines/)
- [Reported] The seventh Taigei-class boat, JS Shogei, was launched in Kobe in October 2026. Actual battery capacity (MWh), charge duration and endurance at given speeds remain undisclosed. — [Army Recognition (2026)](https://www.armyrecognition.com/news/navy-news/2026/japan-launches-7th-taigei-class-submarine-js-shogei-with-lithium-ion-batteries-for-longer-underwater-operations); [Interesting Engineering](https://interestingengineering.com/military/japan-launches-3300-ton-submarine)

**Snorkelling and indiscretion**
- [Reported, lower-tier source] Indiscretion rate is the share of a patrol spent with a mast up (snorkelling). A snorkelling boat is noisy, leaves a wake and gives a radar return. Designers of conventional boats work hardest to push this number down. — [GlobalMilitary.net explainer](https://www.globalmilitary.net/news/nuclear-vs-aip-how-submarines-run-without-air-japan-explainer/)
- [Official/parliamentary] An Australian Parliamentary Library paper concludes that AIP can improve an SSK's indiscretion rate but does not overcome the "snorting" disadvantage relative to SSNs. — [APH Research Paper 2024-25](https://www.aph.gov.au/About_Parliament/Parliamentary_departments/Parliamentary_Library/Research/Research_Papers/2024-25/The_deterrence_advantage_of_nuclear_powered_submarines)
- [Think tank] An ORF brief links falling indiscretion rates in conventional boats to better propulsion efficiency and AIP. — [ORF (2023)](https://www.orfonline.org/public/uploads/posts/pdf/20230914113030.pdf)
- [Technical] A DTIC comparative design study of ten conventional and nuclear fast-attack submarine designs tabulates indiscretion rates and intervals at 80% battery depth of discharge and at 6 and 10 kt. Only the table of contents was retrieved, so no numbers are available. — [DTIC ADA202251](https://apps.dtic.mil/sti/pdfs/ADA202251.pdf)
- [Opinion] USNI Proceedings (2018) argues there is still a case for diesel submarines, largely on cost. — [USNI Proceedings: There's a case for diesels](https://www.usni.org/magazines/proceedings/2018/june/theres-case-diesels)

### Inferences
- The three-tier energy picture is design-useful (inference from the cited sources).
  - **Diesel/snorkel:** recharges, but is highly indiscreet.
  - **Battery:** fast (reportedly about 20 kt burst) but finite, from hours at high speed to days at low speed.
  - **AIP:** slow (reportedly about 5 to 10 kt), consumable (LOX or hydrogen), weeks long.
  - **Li-ion boats** collapse AIP into a larger, faster-charging battery, which shortens snorkel windows rather than removing them.
- SSN endurance is effectively limited by provisions and mission length (about three months of food reported for Astute), not fuel. Its constraint set is acoustic: tactical (quiet) speed vs burst speed.
- Weapon load is roughly 38 to 50 weapons on SSNs plus VLS/VPM land-attack capacity. AIP boats carry far fewer, but no SSK weapon-load figure was verified here. That makes weapon scarcity a natural SSK tension lever.
- Treat all speeds and depths as game-tunable fictional parameters bounded by the public floor figures above. The public figures are intentionally imprecise.

### Gaps
- SSK crew sizes and weapon fits (tube count, reload count, mines) for Type 212A/214, Gotland, Scorpène and Sōryū/Taigei were not verified, because the primary seaforces/navy pages failed to load. From unverified recollection only: crews are commonly cited at roughly 25 to 35 for Type 212A/Gotland and about 65 for Sōryū/Taigei. Verify before use.
- Type 214 (fuel cell, export) was not researched. Fuel-cell output (kW), maximum speed on fuel cells, and hydrogen storage limits were not reliably sourced.
- No quantified indiscretion ratios were found (the DTIC report's tables were not retrieved).
- No Scorpène-specific MESMA endurance figure was found. Agosta 90B is only a proxy.
- Diving depth figures were deliberately not collected (classified; public figures are floors only).

## Q2. Player-experience implications: which platform makes a better first playable, and are fictional/composite classes preferable?

### Takeaway
An SSK/AIP boat reproduces the scarcity loop that made WWII sims tense: battery as a clock, snorkel exposure, few weapons. It also suits small littoral maps and short missions, so it is the stronger first playable (recommendation). An SSN suits a later, broader blue-water mode where tension comes from acoustics, speed-vs-noise choices and a richer threat environment. A fictional composite class is preferable: real performance data are classified or only "+"-floor public figures, and real names carry trademark/licensing considerations (see Q7).

### Cited Findings
- [Community/review] Cold Waters is described as a "tense, focused take on submarine combat". It is a modern-era (SSN-centric) sub sim built around combat engagements. — [PC Gamer](https://pcgamer.com/cold-waters-is-a-tense-focused-take-on-submarine-combat)
- [Community/review] UBOAT "recasts the sub sim as a roguelike management game". It shows that crew and resource management can carry a sub game. — [Vice](https://www.vice.com/en/article/uboat-recasts-the-sub-sim-as-a-roguelike-management-game)
- [Community/review] SUBSIM's UBOAT review highlights real-time repair progress and having to prioritise repairs to get the boat home. Survival logistics are a core tension source. — [SUBSIM review: UBOAT](https://www.subsim.com/subsim-game-review-uboat)
- [Community] In Cold Waters, damage-control work is noisy, so the boat cannot remain in silent running while repairing. Survival and stealth are traded off directly. — [PMC Tactical: Cold Waters damage control](https://cold-waters.pmctactical.org/damage-control.php)
- [Reported] Snorkelling is the conventional boat's most vulnerable state: noise, wake, radar return. — [GlobalMilitary.net](https://www.globalmilitary.net/news/nuclear-vs-aip-how-submarines-run-without-air-japan-explainer/)
- [Reported] AIP improves but does not eliminate the snorting disadvantage. — [APH Research Paper 2024-25](https://www.aph.gov.au/About_Parliament/Parliamentary_departments/Parliamentary_Library/Research/Research_Papers/2024-25/The_deterrence_advantage_of_nuclear_powered_submarines)
- [Reported] Modern Li-ion boats' battery capacity and endurance are undisclosed. Even "realistic" modern SSK data would have to be invented. — [Army Recognition](https://www.armyrecognition.com/news/navy-news/2026/japan-launches-7th-taigei-class-submarine-js-shogei-with-lithium-ion-batteries-for-longer-underwater-operations)
- [Official] US Navy SSN speed is published only as "25+ knots", a floor. Exact values are not public. — [US Navy fact file](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2169558/attack-submarines-ssn/)

### Inferences
- **Recommendation: first playable = fictional composite SSK/AIP ("modern littoral hunter").** Reasons:
  - **Readable resource loop:** battery state of charge, AIP oxidiser/fuel percentage, diesel fuel, and a visible "exposure" meter while snorkelling.
  - **Natural mission clock:** the boat must snorkel or return.
  - **Small, dense littoral maps:** shallow water, bathymetry, shipping noise. These are cheaper to build in Godot than open-ocean campaigns.
  - **Few weapons and few systems:** fewer UI panels and a smaller test surface, consistent with the project's smallest-justified-change rule.
  - **Easier design target:** the WWII "Silent Hunter" tension maps directly onto it.
- **SSN as a later mode.** Tension sources:
  - Speed-vs-noise (tactical vs burst speed).
  - Being counter-detected while launching land-attack/anti-ship missiles.
  - Under-ice or deep-water duels with other SSNs.
  - Long-range transit decisions.
  - Larger threat sets (MPA plus helicopters plus escorts).

  The SSN removes the energy clock, so it needs other pressure (time-on-station objectives, rules of engagement (ROE), datum-avoidance after attacks).
- **Composite classes:** define two or three fictional hulls with stats expressed as bands derived from public "+"-figures. For example, a "battery burst ~20 kt, AIP ~5 to 10 kt" style envelope, not copied specifications. Use fictional names and generic navies or factions. This sidesteps classified-data pretence, naming/trademark risk and politically sensitive country framing.
- Li-ion vs AIP could be a player-facing loadout choice on the fictional SSK: AIP for long slow endurance, Li-ion for faster burst and quicker recharge. This is a rich, cheap design lever.

### Gaps
- No player-research or sales data was found comparing SSK-centric vs SSN-centric games' reception.
- Cold Waters' and Silent Hunter's design-intent documentation (official manuals or developer post-mortems) was not retrieved. Reception claims rest on reviews and community sources.

## Q3. Vessel behaviour: degrees of freedom, speed/acceleration/turn, depth via planes/ballast, cavitation, test/crush depth, surface and air units

### Takeaway
Full 6-DOF hydrodynamics is unnecessary (recommendation). Commercial sims expose behaviour as discrete degradations: half turn rate, half depth rate, speed caps. Physics sources only support simple monotonic relationships, such as a cavitation-onset speed that rises with depth, and speed bands (ultra-quiet, patrol, high speed, snorkel). A 3-DOF horizontal model (x, y, heading) with first-order speed lag, plus a separate 1-D depth state driven by planes (speed-dependent) and ballast/trim (speed-independent), captures all player-relevant behaviour.

### Cited Findings
- [Community] Cold Waters subsystem damage effects:
  - Rudder damage halves turn rate.
  - Dive-plane damage halves depth change rate.
  - Ballast damage halves depth change rate and disables emergency blow.
  - Propulsion damage caps the telegraph at Two-Thirds Ahead.
  - Reactor loss caps it at All Stop (dead in the water).

  Effects are discrete multipliers, not simulated hydrodynamics. — [Magic Game World: Cold Waters non-operational subsystems](https://magicgameworld.com/?p=6151)
- [Community] Cold Waters flooding recovery:
  - A flooding boat sinks even while repairs proceed. The fix is to increase speed and use planes plus ballast to rise.
  - High speed near the surface risks cavitation and broaching.
  - Holding a shallow depth needs continuous plane control, because reaching an ordered depth does not stop negative buoyancy.

  This implies a buoyancy term (flooding mass) plus a speed-dependent plane lift term in the depth model. — [PMC Tactical](https://cold-waters.pmctactical.org/damage-control.php)
- [Technical] Tactical (quiet) speed vs maximum burst speed are distinct operational concepts. — [FAS DOD-101](https://man.fas.org/dod-101/sys/ship/deep.htm)
- [Academic] Submarine propeller noise falls into four operating regimes: ultra-quiet low speed, normal patrol speed, high speed, and near-surface operation when snorkelling. Cavitation inception speed is the lowest speed at which cavitation occurs. — [Springer chapter](https://link.springer.com/chapter/10.1007/978-3-319-16184-6_7)
- [Academic] The cavitation number includes the hydrostatic head (ρgh). Deeper immersion raises ambient pressure, so higher speed is needed before cavitation starts. — [MIT OCW 2.611: Cavitation notes](https://ocw.mit.edu/courses/2-611-marine-power-and-propulsion-fall-2006/b5483b7eff2776524737db0929227a26_04cavitation.pdf)
- [Academic] Cavitation is difficult to initiate when a submarine is deep because of high pressure. The same paper has an internally inconsistent line about testing at ≤10 m, so use with caution. — [Undip journal paper](https://ejournal.undip.ac.id/index.php/kapal/article/download/52960/25114)
- [Academic] Near the surface, pressure may fall below vapour pressure and cavitation noise can dominate. Beyond a certain speed the propeller is the main noise source for underwater vehicles. — [TU Hamburg paper](https://tore.tuhh.de/bitstreams/f697e795-0cca-4d6b-90bb-3f405ac36252/download)
- [Reported/approx] Stirling AIP speed is reported at about 5 kt vs about 20 kt on battery (listing). RSIS says about 10 kt. Either way, AIP is a low-speed mode. — [Seaforces: Gotland](https://seaforces.org/marint/Swedish-Navy/Submarine/Gotland-A19-class.htm); [RSIS](https://rsis.edu.sg/rsis-publication/rsis/1220-air-independent-powered-submar/)
- [Community] UBOAT (post-2.0 patch notes) gives enemy ships active damage control. They can patch small shell breaches and run pumps but cannot repair torpedo damage. AI surface units get a simplified survival model. — [SteamDB patch notes: UBOAT](https://steamdb.info/patchnotes/17066668)
- [Community] War on the Sea (the Cold Waters developer's later game) models counterflooding to correct list. Counterflooding too many compartments scuttles the ship, an abstracted surface-ship stability model. — [Magic Game World: War on the Sea damage control](https://www.magicgameworld.com/?p=125637)

### Inferences
- **Recommended minimum vessel model (inference, not sourced physics):**
  - **Horizontal (3-DOF):**
    - Position x/y and heading.
    - Speed follows ordered telegraph speed with a first-order lag. Separate acceleration and deceleration constants; deceleration is coast-down plus a reverse-power option.
    - Turn rate scales with rudder angle and speed, with a minimum steerage speed, and is capped. Optional speed bleed in hard turns.
    - No sway or roll simulation. Show advance/transfer only through the turn-rate cap.
  - **Vertical (1-D):** depth rate = plane term (proportional to plane angle times speed, so ineffective at low speed) + buoyancy term (ballast/trim state minus flooding mass) + emergency-blow impulse. Pitch angle can be cosmetic, derived from the depth rate. This reproduces the Cold Waters lesson that at zero speed only ballast changes depth, and that a flooded boat needs speed plus planes to climb.
  - **Damage hooks:** expose turn-rate, depth-rate and max-speed multipliers that the damage model sets (Cold Waters-style halving/caps). This keeps the damage and vessel modules decoupled through a small interface, which suits the project's modularity rule.
- **Acoustic speed bands:** implement self-noise as a function of speed band, with extra noise when snorkelling, transients and damage-control work. Use a cavitation-onset threshold speed that increases monotonically with depth (for example linear or step-wise in depth bands). Only the monotonic direction is sourced; constants are game-tuned.
- **Test/crush depth as abstract thresholds:**
  - Above "test depth": normal.
  - Between test and "design/collapse" depth: hull-stress accumulates over time, with creaks as audio warnings, increasing leak/flood probability and compounding existing damage.
  - Beyond collapse depth: loss.

  Use fictional numbers and never publish them as real-boat values.
- **SSK energy model:** use battery state of charge as a resource. Power draw rises steeply with speed; a cubic speed–power relationship is the standard naval-architecture approximation, but it is not sourced in these notes, so verify. Add AIP as a second slow-rate source with a consumable, and snorkel recharge at shallow depth with an exposure meter. Li-ion could be modelled as a larger battery plus a higher charge rate.
- **Surface ships:** state machines (transit → search → prosecute → attack → re-search) following waypoints, with simple speed/turn caps (same 3-DOF model, no depth). Abstracted damage: hit points per compartment, or flooding fraction plus a counterflood option à la War on the Sea, with simplified DC (UBOAT-style "can patch small breaches, not torpedo holes").
- **Aircraft (MPA/helicopter):** no flight physics needed. Model them as sensor/weapon carriers with on-station time, transit speed, a sonobuoy/dip inventory and simple search patterns. See Q5.

### Gaps
- No public, quantified cavitation-onset-vs-depth curve for any submarine was found. Only the direction of the effect is sourced.
- No authoritative source was found on submarine acceleration, turning circles or plane effectiveness (likely sensitive). These must be invented.
- Official Cold Waters/Silent Hunter manuals describing their vessel physics were not retrieved. Patterns come from community guides.

## Q4. Navigation: dead reckoning, inertial drift, position fixes, bathymetry/grounding, currents

### Takeaway
Real submarines navigate submerged by inertial dead reckoning that drifts. They correct it with GPS fixes (at periscope depth, an exposure risk), bathymetric fixes or navigation sonar. The gameplay-relevant core is a position-uncertainty value that grows with time since the last fix, a fix action that costs exposure, and bathymetry with grounding risk in the littorals (recommendation). Currents and detailed INS error physics are optional.

### Cited Findings
- [Reference/secondary] Submarines navigate submerged mainly by inertial navigation, which measures the boat's motion and continually updates position. They periodically come to periscope depth to raise a GPS antenna, though surfacing or exposing masts is risky given radar and satellite surveillance. — [Wikipedia: Submarine navigation](https://Www.Wikipedia.org/wiki/Submarine_navigation)
- [Trade press] Gyros drift over time and lose reliability without periodic GPS updates. The older WSN-7 reportedly required a GPS fix about every eight hours; the fibre-optic WSN-12 allows longer submerged periods without updates. Attribution comes from a search extract. — [Military & Aerospace Electronics](https://www.militaryaerospace.com/sensors/article/14295433/inertial-navigation-fiberoptic-gyro-fog-surface-ships-and-submarines)
- [Technical] The Electrostatically Supported Gyroscope Navigator (ESGN) is described as the heart of the Ohio-class navigation subsystem. Its fix inputs include GPS or bathymetry, plus a navigation sonar giving bathymetric fixes and velocity measurements. This was attributed via search extract to DTIC documents, and the exact document is unverified. — [DTIC ADA386504](https://apps.dtic.mil/sti/tr/pdf/ADA386504.pdf); [DTIC ADA257329](https://apps.dtic.mil/sti/pdfs/ADA257329.pdf)
- [Academic, Norwegian Defence University College] A thesis studies "challenges and consequences of a poor position update of a submarine INS in the littorals". It notes the submarine may be forced deep before a proper GNSS fix is obtained, so tactical pressure degrades navigation quality. — [FHS Brage](https://fhs.brage.unit.no/fhs-xmlui/handle/11250/2389390)
- [Community] Moving to periscope depth slows flooding in Cold Waters. Periscope depth is a recurring "safe but exposed" layer in game design. — [PMC Tactical](https://cold-waters.pmctactical.org/damage-control.php)

### Inferences
- **Minimum navigation model (recommendation):**
  - **True vs believed position:** keep both. Believed position = dead reckoning from ordered course and speed plus an INS error that grows with time since the last fix.
  - **Uncertainty display:** an ellipse or circle on the chart.
  - **Fix actions:**
    - GPS/periscope fix: requires periscope depth and mast up, adds an exposure/indiscretion cost, and is interruptible if forced deep, mirroring the FHS finding.
    - Bathymetric fix: requires a nav sonar and a distinctive seabed, and has a small acoustic cost.
    - Visual fix: landmarks via periscope in the littoral.
- **Bathymetry** is gameplay-relevant for the SSK littoral mode. Use a heightmap or grid of seabed depth, a keel-clearance warning, and grounding damage. Pair this with position uncertainty so that bad navigation in shallow water is a real risk.
- **Currents** are optional: a single regional set/drift vector, unknown until a fix reveals the offset. This is cheap and adds DR texture. A full ocean model is unnecessary.
- INS drift should be tuned to the mission timescale (hours of game time), not to real drift specifications, which are not public in detail.

### Gaps
- No public, quantified drift rates (nmi/hour) for current submarine INS were found. Treat drift as a game tuning parameter.
- Doctrinal frequency of navigation fixes on modern boats was not found.

## Q5. Weapons and ASW threats: heavyweight torpedoes, countermeasures, missiles, mines, aircraft and escorts (generic, unclassified)

### Takeaway
Public sources support a generic heavyweight-torpedo model: wire guidance from the launching boat, which can be dropped; onboard active or passive homing; and a pre-programmed search/acquire/attack logic. Modern-era threats are layered. Maritime patrol aircraft lay sonobuoy fields. Ship-based helicopters use dipping sonar plus sonobuoys. Escorts carry their own sonar. All of these can be abstracted into sensor-and-weapon carriers with simple behaviour states (recommendation).

### Cited Findings
- [Technical/Official-adjacent] Mk 48 and Mk 48 ADCAP torpedoes can be guided by wires from the submarine, or use their own active or passive sensors to run programmed target search, acquisition and attack. — [FAS: Mk 48](https://man.fas.org/dod-101/sys/ship/weaps/mk-48.htm)
- [Official] The Royal Australian Navy states the Mk 48/ADCAP can operate with or without wire guidance and with active or passive homing. It publicly lists a length of 5.79 m and a range of 8 km. Treat the range as a notional public figure only. — [Royal Australian Navy: Mark 48](https://www.navy.gov.au/capabilities/weapons/mark-48)
- [Official] The US Navy describes the Mk 48 as a heavyweight acoustic-homing torpedo with sophisticated sonar, all-digital guidance and control, digital fusing and propulsion improvements. — [US Navy fact file: Mk 48](https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2167907/mk-48-heavyweight-torpedo/)
- [Official] DOT&E calls the Mk 48 ADCAP the primary anti-submarine and anti-surface weapon used by US submarines. Later variants, such as Mod 7 CBASS, add a new sonar with software-upgradable effectiveness. — [DOT&E FY2012 Mk 48 ADCAP report](https://www.dote.osd.mil/Portals/97/pub/reports/FY2012/navy/2012mk48adcap.pdf)
- [Reported] Spearfish (UK) is wire-guided with an active/passive homing head. Attribution comes from a search extract. — [UK Defence Journal](https://ukdefencejournal.org.uk/britains-stealthy-hunter-killer-submarine-the-astute-class/)
- [Community] Cold Waters tube mechanics:
  - A damaged tube is unusable for the rest of the patrol, and its wire or loaded weapon is lost.
  - Firing from angled tubes above about 20 kt can jam the torpedo and disable the tube.
  - Fire-control damage stops target motion analysis and clears tracked contacts.

  These are gameplay constraints tying own-ship speed to weapon employment. — [Magic Game World: Cold Waters subsystems](https://magicgameworld.com/?p=6151)
- [Official, manufacturer] P-8A performs ASW "through an integrated sensor suite to conduct search, detection, classification, localization, tracking and attack of submarines". — [Boeing: P-8 Poseidon](https://www.boeing.com/defense/maritime-surveillance/p-8-poseidon/)
- [Trade press] P-8A has storage for 129 sonobuoys, about 50% more than the P-3. — [AIN Online (2017)](https://ainonline.com/aviation-news/defense/2017-06-18/p-8a-roll-out-us-navy-accelerates-asw-mission)
- [Official, NAVAIR] Sonobuoys are air-launched, expendable electro-mechanical acoustic sensors that relay underwater sounds of ships and submarines to processors on P-3C, P-8A and MH-60R. — [NAVAIR: Air ASW Systems](https://www.navair.navy.mil/product/Air-ASW-Systems)
- [Official, manufacturer] The MH-60R sensor fit includes dipping sonar and sonobuoys. — [Lockheed Martin: MH-60R](https://www.lockheedmartin.com/en-us/products/sikorsky-mh-60r-cg-helicopter.html)
- [Defence press] Airborne ASW combines maritime patrol aircraft laying sonobuoy fields with shipborne helicopters using dipping sonar. — [European Security & Defence: Airborne ASW](https://euro-sd.com/?p=29975)
- [Defence press] Uncrewed helicopters (MQ-8C Fire Scout) were being fitted to launch sonobuoys, an emerging drone ASW layer. — [The War Zone](https://www.twz.com/38691/submarine-hunting-kit-will-let-mq-8c-fire-scout-drone-helicopters-launch-sonobuoys)
- [Official] Astute-class Tomahawk land-attack capability strikes "hundreds of miles inland". Virginia Block V carries up to 40 Tomahawks. — [Royal Navy](https://www.royalnavy.mod.uk/equipment/submarine/astute-class); [SIBC](https://submarinesuppliers.org/programs/ssn-ssgn/virginia-class/)

### Inferences
- **Generic heavyweight torpedo model (recommendation).** States:
  1. Launch (tube-ready check; own-speed limit per the Cold Waters pattern).
  2. Wire-guided run: player steers, sets run-to-enable distance, search depth/ceiling/floor, and active vs passive seeker.
  3. Enable.
  4. Search pattern (snake/circle).
  5. Acquire.
  6. Home.
  7. Detonate or miss.
  8. Re-attack: re-search if target lost and fuel remains.

  Wire-cut triggers: player command, own-ship exceeding a speed/turn threshold, tube damage, a wire-length/time limit, or the torpedo passing an arbitrary geometry limit. While wired, the boat is tethered and constrained, which creates tension. Fuel/run time is the hard limit. All numbers are fictional.
- **Countermeasures/decoys:** model as transient noise sources. Each enemy and own-ship seeker has a probability of seduction by a decoy, based on decoy type, seeker mode and geometry. Add simple evasive manoeuvre bonuses (knuckle, depth change, crossing thermal layer if a layer model exists). No real seeker logic is required or appropriate.
- **Anti-ship/land-attack missiles:** model the launch as a high-exposure event. Launch depth/speed limits apply, and a broach or visible launch creates a datum that alerts ASW assets. The missile flight itself can be abstracted (time-to-target plus hit probability vs defences). This is the main SSN-specific tension source.
- **Mines:** tube-laid; occupy tube/reload slots; a placement-accuracy minigame tied to navigation uncertainty (Q4). Optional for the first playable.
- **ASW threat layers (abstracted):**
  - **MPA:** arrives after cues such as a snorkel/ESM detection or a missile launch. Lays a sonobuoy line or field (inventory-limited, consistent with the ~129-buoy figure as an upper scale), then prosecutes and drops lightweight torpedoes.
  - **Helicopter:** shorter range, ship-launched. Dipping-sonar "jump" pattern (hover, dip, listen/ping, move) plus a few buoys and torpedoes.
  - **Escorts:** hull and towed sonar, speed-noise trade-offs mirroring the player's, and ASW weapons.
  - **Drones:** optional later layer.

  Each layer is a state machine with sensor range bands, not a physics model.

### Gaps
- No public, verifiable seeker/acquisition ranges, wire lengths or speed figures were collected. These are sensitive, and the RAN 8 km public range is not a performance claim.
- Modern decoy and countermeasure types (expendable vs mobile) were not researched in public sources.
- Missile launch depth/speed envelopes are not public. Treat them as invented.
- Submarine-laid mine types and modern tube-launched mine inventories were not researched.
- Lightweight torpedoes (Mk 54, Sting Ray, MU90) used by aircraft and escorts were not covered.

## Q6. Damage: compartment flooding, fire, system degradation, depth stress, crew damage control (patterns from Silent Hunter III/V, Cold Waters, UBOAT)

### Takeaway
All three reference games converge on compartment-level flooding plus discrete subsystem degradations plus a damage-control (DC) allocation decision. Cold Waters adds a "pumps first", noise-cost-of-DC and "go shallow to slow flooding" loop. UBOAT adds crew-labour repair prioritisation and leak plugging. Silent Hunter III adds sink conditions: flooding threshold, critical compartment loss, or structural integrity. A compartment-plus-subsystem model with a small DC-team allocation decision is sufficient. Fluid dynamics, stress fields and fire spread simulation are not needed (recommendation).

### Cited Findings
- [Community] Cold Waters flooding and damage control:
  - Pumps should be repaired before flooded compartments, because with pumps out, DC teams in a flooded compartment remove no water.
  - Surfacing drains flooding, but usually not under attack.
  - Going shallower, ideally to periscope depth, slows flooding.
  - DC is noisy, so silent running is impossible during repairs.

  — [PMC Tactical: Cold Waters damage control](https://cold-waters.pmctactical.org/damage-control.php)
- [Community] In Cold Waters, pumps reduce flooding across all compartments, and a damaged pump removes that offset and the DC party's pumping bonus. Subsystem losses (sonar, towed array, periscope, ESM, radar, tubes, fire control, rudder, planes, ballast, propulsion, reactor) each map to a specific capability penalty: halving, cap or full loss. — [Magic Game World: Cold Waters subsystems](https://magicgameworld.com/?p=6151)
- [Community] War on the Sea models counterflooding to correct list, with a scuttling risk if overused. — [Magic Game World: War on the Sea DC](https://www.magicgameworld.com/?p=125637)
- [Community/review] UBOAT shows repair progress in real time as crew work. The reviewer had to prioritise repairs to get home. — [SUBSIM review: UBOAT](https://www.subsim.com/subsim-game-review-uboat)
- [Community] UBOAT players report:
  - Evacuating leaking compartments and setting repairs manually.
  - Idle non-engineer officers plugging leaks while mechanics repair.
  - More crew plugging more leaks reduces inflow.

  A developer reply says sailors seal leaks automatically. — [Steam community: UBOAT](https://steamcommunity.com/app/494840/discussions/0/1742262144178458124)
- [Community] UBOAT AI surface ships got active damage control (patch small shell breaches, run pumps, but not torpedo damage). — [SteamDB: UBOAT patch notes](https://steamdb.info/patchnotes/17066668)
- [Community] Silent Hunter III ships sink from flooding above a critical level, a critical hit destroying compartments, or loss of too much structural integrity. Major mods (NYGM, GWX) re-tuned the damage model, for example by reducing critical-hit odds and raising hit points. — [SUBSIM forum: Ship sinking in SH3](https://www.subsim.com/radioroom/archive/index.php/t-157483.html)
- [Community] Silent Hunter III tracks hull integrity as a percentage (the meter can be hidden). Players report that at-sea repairs do not restore full integrity, which needs a return to base. Forum reports conflict on whether hatches affect flood spread. — [SUBSIM forum](https://www.subsim.com/radioroom/archive/index.php/t-157483.html); [SUBSIM Radio Room](https://www.subsim.com/radioroom/showthread.php?p=1192805)
- [Official training doc] US Navy surface-warfare damage-control training material on principles of controlling flooding exists as a real-world reference for DC concepts (boundaries, dewatering). — [FAS: SWOS DC lesson 4.7](https://man.fas.org/dod-101/navy/docs/swos/dca/stg4-07.html)

### Inferences
- **Sufficient damage model (recommendation):**
  - **Compartments:** about 4 to 7 per fictional hull. Each has:
    - Flood level (0–1) and inflow rate from breaches.
    - Breach count/severity.
    - Fire on/off with an intensity value.
    - Hosted subsystems.
    - Crew stations.
  - **Inflow rate:** scales with breach severity × a depth factor. This captures "go shallow to slow flooding" with one multiplier.
  - **Outflow:** pumps (global; a subsystem that can fail) plus DC team effort.
  - **Total flooded mass:** feeds the vessel model's buoyancy term (Q3), producing the "sinking unless you use speed + planes + ballast" behaviour.
  - **Subsystems:** each has a health state (OK, degraded, failed, destroyed) that maps to a capability multiplier or cap, consumed by other modules (sensors, weapons, vessel) through a narrow interface. Cold Waters' table is a good template for which effects matter.
  - **Damage control:** a small number of DC teams (or crew-hours) assigned to compartments or subsystems. Repair produces noise (stealth trade-off). Some damage is unrepairable at sea, such as destroyed tubes or structural integrity, preserving consequences.
  - **Hull stress:** one structural-integrity scalar. It is reduced by weapon hits and by time spent below test depth. A lower scalar lowers the effective collapse threshold.
  - **Fire:** optional for the first playable. Simplest form: a fire in a compartment degrades its subsystems over time until extinguished by DC, with a crew-casualty chance. No spread simulation, or spread only to adjacent compartments on a timer.
  - **Loss conditions** (the SH3 triad): total flooding over a buoyancy threshold that cannot be recovered, a critical compartment destroyed (reactor/engine room, magazine), or structural integrity at zero / collapse depth exceeded.
- **Avoid:** fluid simulation, per-frame hull stress fields, detailed crew pathfinding (UBOAT-style crew walking is heavy for a first playable), and hatch/pressure-equalisation physics (even SH3 players dispute whether hatches matter).

### Gaps
- Official design documentation for Silent Hunter V's or Cold Waters' damage systems was not retrieved. Patterns rest on fan guides, forums and reviews, which may reflect outdated versions or mods.
- No source was found on how fire specifically is modelled in Cold Waters or Silent Hunter V.
- No data was found on players' perceived complexity or fun for DC systems.

## Q7. Legal/ethical: real class names, real-world data and trademarks; norms in commercial naval games

### Takeaway
US case law (AM General v. Activision, 2020) shows realistic depiction of real military hardware in games can be protected expression under the Rogers test. However, Jack Daniel's v. VIP (US Supreme Court, 2023) removed Rogers protection where a mark is used as the user's own source identifier, such as a title, logo or branding. The safest course for a small project is fictional or composite classes and names, with real-world inspiration acknowledged generically (recommendation). This also avoids presenting guessed "real" performance data as fact. This is not legal advice, and jurisdictions outside the US were not researched.

### Cited Findings
- [Legal reporting] In AM General LLC v. Activision Blizzard (S.D.N.Y., No. 17-cv-8644, 31 March 2020), Judge George B. Daniels applied the Rogers test and found that Humvees in Call of Duty had artistic relevance (realism) and did not explicitly mislead as to source. Confusion that does exist is outweighed by First Amendment interests. Claims included trademark and trade dress infringement, unfair competition, false designation, false advertising and dilution. — [Finnegan: Incontestable blog](https://www.finnegan.com/en/insights/blogs/incontestable/in-legal-warfare-over-humvee-trademarks-the-first-amendment-goes-beyond-the-call-of-duty-in-dismissing-am-generals-claims.html); [Hollywood Reporter](https://www.hollywoodreporter.com/thr-esq/call-duty-wins-first-amendment-victory-use-humvees-1287882); [AIPLA](https://www.aipla.org/detail/news/2020/04/08/activision-beats-humvee-trademark-claims-over-call-of-duty)
- [Legal reporting] Activision did not dispute the strength of AM General's HUMVEE mark, and evidence of actual confusion weighed only "slightly" for AM General. The win rested on expressive-use protection, not on the mark being weak. — [AIPLA](https://www.aipla.org/detail/news/2020/04/08/activision-beats-humvee-trademark-claims-over-call-of-duty); [Court opinion (DocumentCloud)](https://s3.documentcloud.org/documents/6116331/Activision-Humvee.pdf)
- [Legal commentary; attribution needs verification] Rogers was later applied to a tractor in Saber Interactive v. Oovee (2022, the Spintires game). — [Osgoode IP blog: "When the game gets too real"](https://www.yorku.ca/osgoode/iposgoode/?p=40269)
- [Legal reporting] Jack Daniel's Properties v. VIP Products (US Supreme Court, 8 June 2023, unanimous, No. 22-148) held Rogers does not apply when the alleged infringer uses a mark as a designation of source for its own goods. The Court declined to opine on Rogers generally, and commentators called the decision narrow, with uncertain wider effect. — [Bloomberg Law](https://news.bloomberglaw.com/ip-law/jack-daniels-high-court-win-leaves-trademark-rogers-test-hazy); [Jenner & Block analysis](https://www.jenner.com/print/v2/content/54077/unpacking-the-supreme-courts-decision-in-jack-daniels-properties-inc-v-vip-products-llc.pdf)
- [Legal commentary] After Jack Daniel's, defendants using marks as source identifiers face the traditional likelihood-of-confusion analysis. Commentators flagged trade dress as a likely next battleground. — [Bloomberg Law](https://news.bloomberglaw.com/ip-law/jack-daniels-high-court-win-leaves-trademark-rogers-test-hazy)
- [Legal commentary] Video games depicting real vehicles have been subject to multiple trademark suits, which shows this is a recurring litigation risk area. — [Osgoode IP blog](https://www.yorku.ca/osgoode/iposgoode/?p=40269); [NYU JIPEL](https://jipel.law.nyu.edu/activision-humvee-trademark-suit/)

### Inferences
- **Risk tiers (recommendation; not legal advice):**
  - **Lowest:** fictional class names, fictional or generic navies, original silhouettes "inspired by" categories (SSK, AIP, SSN), and stats expressed as fictional values.
  - **Moderate:** generic type designations that are not brands (for example "heavyweight torpedo", "maritime patrol aircraft") or real class names used descriptively in non-marketing content.
  - **Higher:**
    - Real manufacturer names, logos or product brand names (e.g., company-branded weapons) in the game title, store page, key art or UI branding. Jack Daniel's narrows protection exactly where a mark acts as branding.
    - Close replicas of distinctive product trade dress.
    - Implying endorsement by a navy or manufacturer.
- **Data and ethics:**
  - Present performance values as fictional. Do not claim they reflect real systems, especially classified ones.
  - Avoid reproducing export-controlled or leaked material. Some game communities have seen leaks of restricted military documents, but this was not researched here and is noted only as a general risk to set a policy for in community channels.
- **Norm observation:** many commercial naval games depict real classes. Cold Waters' and Silent Hunter's naming practices were not documented in sources retrieved here, so whether they licensed names is unknown. A fictional-composite approach costs little and matches the project's need to avoid classified data claims.
- Country/faction framing: fictional navies avoid presenting real nations' forces in specific conflict scenarios. This is a reputational and ethical consideration and was not legally researched.

### Gaps
- Non-US law (EU/UK trademark, German law given German-built references, Japanese law) was not researched.
- No source was retrieved on whether Cold Waters, Dangerous Waters or Silent Hunter licensed real class/manufacturer names, or on the Bell Helicopter v. EA (Battlefield 3) dispute. These are commonly cited industry examples but are unverified here.
- No source was found on export-control (ITAR/EAR) implications of publishing simulation data. It is likely irrelevant if all data are fictional or public, but this was not verified.
- Insignia, ensigns and national symbols usage rules were not researched.
