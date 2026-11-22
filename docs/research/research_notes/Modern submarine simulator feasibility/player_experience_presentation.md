# Player Experience and Presentation: Captain-Level Command vs Hands-On Station Operation in Submarine and Crew-Command Simulators

Research date: November 2026. Scope: player-experience design and presentation options for a planned modern-era submarine command and career simulator (Godot 4, small team). Research notes only; no presentation approach is chosen here.

**Claim labels used throughout:**
- **[F]** confirmed fact: documented feature or statement from a primary or official source that I fetched.
- **[C]** critic or reviewer opinion, attributed.
- **[P]** player or community opinion. This is anecdotal and not representative.
- **[U]** unverified. It came from a search-result summary or an informal source, and I could not open or confirm the page itself.
- **[E]** estimate.
- **[I] / [R]** inference or recommendation by the researcher. These appear only in the Inferences sections.

Silent Hunter III–V, UBOAT and Wolfpack are WWII games. Dangerous Waters, Cold Waters and Sea Power are the closest in era to a modern-era design.

---

## 1. How existing games let the player act as commander and/or station operator, and what players liked or disliked

### Takeaway
Successful titles either (a) keep the player at captain level and let an AI crew do the technical work, as Cold Waters does, or (b) let the player jump to any station instantly with automation behind every station they skip, as Dangerous Waters and the Silent Hunter realism toggles do. The most consistent complaints are about **friction in moving between roles**: SH5's walk-to-station interior, Dangerous Waters' click-heavy station UIs, and poor crew feedback in Cold Waters (text only, no history) and UBOAT (opaque crew state). Crew/bridge games outside the naval genre show that "captain gives orders, others operate" works best with human crews. Single-player AI crews get criticized when they are unreliable under pressure.

### Cited Findings

**Silent Hunter III (2005, WWII U-boat)**
- [F] SH3's realism menu adds a "manual targeting system" (TDC) and "no map contact updates" to the standard realism toggles. When manual TDC is on, the player must first identify the target in the ship recognition manual and send that match to the TDC. — [SUBSIM SH3 review](https://www.subsim.com/ssr/sh3_rc1/sh3_review1.htm) [U: quoted in a search summary, page not opened]; [SUBSIM SH3 tips](https://www.subsim.com/tips/tip_sh3.php)
- [P] The community tips page says play at 100% realism is far harder than at casual settings because sub and crew sensors are "reduced dramatically" and depend on weather. It also says the player must "deal with the crew, rest them, assign the best guys where they are needed." — [SUBSIM SH3 tips](https://www.subsim.com/tips/tip_sh3.php)
- [C] An SH4 review notes that SH4's crew stays mostly quiet apart from status messages, "unlike the tips the officers gave in SH3." This implies SH3's officer advice was valued. — [Outnow.ch SH4 review](https://outnow.ch/en/Games/2007/SilentHunter4-WolvesOfThePacific/Review/)

**Silent Hunter 4 (2007, WWII Pacific)**
- [F] Time compression goes up to 8000x. It drops to 1x on contact with enemy ships or planes. — [SUBSIM SH4 page](https://www.subsim.com/sh4/silent_hunter4.php)
- [P] On long transits, contacts keep interrupting time compression. — [SUBSIM forum](https://www.subsim.com/radioroom/showthread.php?p=885708)
- [P] At very high compression (above about 128x), players report that they are less likely to see targets. — [SUBSIM forum archive](https://www.subsim.com/radioroom/archive/index.php/t-140764.html)
- [P] A "No Weapon Officer Assistance" realism toggle moves the player from officer-assisted aiming to manual targeting. — [SUBSIM forum](https://www.subsim.com/radioroom/showthread.php?p=2087603) [U: exact in-game wording not verified]

**Silent Hunter 5 (2010, WWII Atlantic): the walkable-interior experiment**
- [F/C] SH5 moved to a fully 3D submarine interior with a first-person point of view. GameSpot (Brett Todd, 5/10) says key functions were removed from the interface "in favor of clumsy commands and giving orders to the crew in person." He calls this a poor fit for the setting, since U-boats had voice tubes for giving orders at a distance. He also calls the new crew morale system broken. — [GameSpot SH5 review](https://www.gamespot.com/reviews/silent-hunter-5-battle-of-the-atlantic-review/1900-6254133/) [U: only fragments retrieved]
- [C] Bit-tech's review includes these lines: "requiring you to physically walk through the various compartments of the submarine to get to the station you want"; "Actually having to move between stations was never going to be fun"; "it slows down the gameplay far too much"; "Nothing is more infuriating than being stuck in the conning tower." It contrasts this with the earlier games' "keyboard shortcuts that made sure you always had a chance to be where the excitement was." It also criticizes that controls cannot be remapped, says crew dialogue is so sparse "it quickly becomes repetitive and boring," and reports that first-person mode "crawls along at an appallingly slow frame rate." — [Bit-tech SH5 review p.1](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/1/)
- [C] Bit-tech page 2 argues that the work on the Type VII interior left no time for other submarine classes. — [Bit-tech SH5 review p.2](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/2/) [U: search summary]
- [C] The positive view: The Courier found the interior "as cramped and gloomy as a HD remake of Das Boot" and said the sim's immersion is hard to beat. — [The Courier](https://www.thecourier.co.uk/entertainment/142932/review-silent-hunter-5-pc)
- [C] HistoryNet notes that chatting with the crew raises morale and earns promotion points. — [HistoryNet](https://www.historynet.com/?p=13682315) [U]
- [F] Metascore is 62 from 26 critic reviews ("mixed or average"). — [Metacritic](https://www.metacritic.com/game/1300054115/) [U: search summary]

**Dangerous Waters (2005, modern era, multi-platform station sim)**
- [F] Players can man stations such as sonar and radar themselves, or let AI "simulated crew members" man non-command functions. Multiplayer "allows multiple players to occupy individual crew stations on the same vessel." Metacritic score is 82. — [Wikipedia](https://en.wikipedia.org/wiki/Dangerous_Waters_(video_game))
- [C] GameZone says the F-keys "allow players to jump from one station to another easily." It calls the learning curve steep but rewarding. — [GameZone](https://gamezone.com/?p=99597) [U: search summary]
- [C] GameSpot says each station mirrors its real-world counterpart and that sonar layouts differ between classes. It warns that newcomers may feel lost right away. — [GameSpot](https://www.gamespot.com/pc/sim/dangerouswaters/review.html) [U: search summary]
- [C] Armchair General writes: "The AI [Autocrew] is available to help, but control falls squarely on the shoulders of the player." TMA "is a fundamental requirement, but can still be assigned to the AI." On hotkeys, "it is impractical to remember them all" and "There is no way to easily see what commands are available for the current window." The reviewer liked the remappable hotkeys. On one basic process, pausing the game "does not mitigate the fact that this basic process is very awkward to conduct," because it takes "extensive numbers of mouse clicks." — [Armchair General](https://armchairgeneral.com/review-dangerous-waters.htm)
- [C] SUBSIM writes: "The TMA station simulates a good old paper plot using virtual rulers and tools"; frigate TMA "can become a nightmare"; "the auto-TMA does a competent job." The auto-TMA sometimes leaves "three separate solutions for every nearby surface contact." Bearing lines pile up until "the NavMap looks like a game of Chinese Pick-up Sticks." — [SUBSIM DW review p.2](https://www.subsim.com/ssr/dangerous_waters/dangwater_review_page2.htm)

**Cold Waters (2017, Killerfish Games, Cold War / 1968–1984 era): captain with an abstracted crew**
- [F] Giant Bomb describes it as a spiritual successor to MicroProse's *Red Storm Rising*. — [Giant Bomb](https://giantbomb.com/wiki/Companies/Killerfish_Games) [U]
- [C] The SUBSIM review is the key evidence for the captain-level model. Quotes: "You are the captain and your AI crew will do most of the pencil-whipping for you." "Unlike Sub Command or Dangerous Waters, in this game there are no dedicated TMA or fire control stations." "If you want to get involved, you can help speed up a good solution by using the signature classification tools." "You still have plenty of gameplay to manage by determining your course, depth, and speed." The reviewer's verdict: "a truly great game." — [SUBSIM Cold Waters review](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)
- [C] Frustrations from the same review: "There are no crew voices to inform you about changes in depth, course, passing layers, contact updates"; "There is no way to pull up history in the message bar." The reviewer also says many players wanted a helm station. — [SUBSIM Cold Waters review](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)
- [C] PC Gamer's headline calls it "a tense, focused take on submarine combat" and "an excellent stealth game." Only the headline and subhead were retrieved. — [PC Gamer](https://www.pcgamer.com/cold-waters-is-a-tense-focused-take-on-submarine-combat/)
- [P] GOG players say it does "a great job of taking the key aspects of submarine warfare and making them easier to grasp" and that it "kills you dead at the first mistake." — [GOG](https://www.gog.com/en/game/cold_waters)
- [F] Steam shows 3,523 English user reviews at 87% positive ("Very Positive"). — [Steam](https://store.steampowered.com/app/541210/Cold_Waters/)
- [P] A community guide on damage control says you assign repair teams to compartments, and that you cannot stay silent "with damage control teams banging away with their tools." This shows delegated crew actions creating tactical trade-offs. — [PMC Tactical guide](https://cold-waters.pmctactical.org/damage-control.php)

**Sea Power (2024 Early Access, Triassic Games / MicroProse, Cold War era, multi-unit)**
- [F] Store features include "Pausable real-time controls with time compression options," "Advanced sensor modeling for radar, sonar, electronic countermeasures, and visual identification," and carrier flight ops "with configurable simulation level." Steam shows 4,292 English reviews at 91% positive. — [Steam](https://store.steampowered.com/app/1286220/Sea_Power/)
- [F] Triassic Games' founder Nils Dücker previously co-designed Cold Waters at Killerfish. — [Triassic Games](https://www.triassicgames.com/about/)
- [C] Fan-site review: players "can operate from a 3D perspective to appreciate stunning visuals or they can switch to a tactical 2D map for command decisions." The review calls the tactical displays "much more accessible than other games in the genre." — [PMC Tactical Sea Power review](https://sea-power.pmctactical.org/review.php)
- [C] Reviews say players can take personal control of individual units at any time. — [Gamepressure](https://gamepressure.com/games/sea-power-naval-combat-in-the-missile-age/zc5a60) [U]
- [C] An Early Access review says the game "lacks in-game guidance." — [Game8](https://game8.co/articles/reviews/sea-power-naval-combat-in-the-missile-age-game-review-early-access). Another reviewer says the lack of onboarding "hurts its first impression." — [Chalgyr](https://www.chalgyr.com/search/label/Naval%20Combat) [U]
- [P] An aggregated Steam-review summary reports that players call the order-giving UI "inconvenient, poorly designed, and non-intuitive." — [Vaporlens aggregator](https://vaporlens.app/app/1286220/sea_power_naval_combat_in_the_missile_age) [U: AI aggregator]

**UBOAT (Deep Water Studio, WWII): commander as crew manager**
- [C] Vice: crew "divid[ed] into officers, who have specific abilities, and sailors, who are generalists." "Sailors can be assigned to different rotating shifts, which then run mostly automatically." Officers "can be sent around the boat to take stations such as the hydrophone." Crew "keep themselves busy with default tasks if they aren't micromanaged" but "can be idle and inefficient when officers aren't around." Crew "can panic or make too much noise, endangering the whole vessel." Torpedo solutions "become ever more certain the longer you assign officers to the task." The captain can walk the interior in first person. Dislikes: bugs, thin campaigns, and morale that did not respond to the war's context. — [Vice](https://www.vice.com/en/article/uboat-recasts-the-sub-sim-as-a-roguelike-management-game)
- [P] GOG players praise the choice of manual or automatic targeting ("enter the recorded data in the TDC yourself… or you can let your crew do the difficult stuff"). They complain that "the game doesnt tell you how to (or even that you can) check the progress of the crew" and that the controls are "a REAL mess." — [GOG UBOAT reviews](https://www.gog.com/en/game/uboat)

**Wolfpack (co-op WWII U-boat)**
- [C/F] Up to five players crew one boat, each working a station by hand ("turning valves, pulling levers"). Bots can fill unmanned stations ("two guys can manage one boat and employ the bots for one, two, or three of the stations"). The bridge has a voice tube to the control room. Reviewers warn it is "not a submarine simulator where many of the complex calculations and controls are streamlined for you." — [SUBSIM Wolfpack review](https://www.subsim.com/ssr/wolfpack/review_wolfpack.php); [Steam](https://store.steampowered.com/app/490920/Wolfpack/) [U: quotes came from a search summary that drew on both pages]

**FTL: Faster Than Light (Subset Games)**
- [F] The developers "opted to streamline the gameplay and focus on crew movement and power management." Earlier plans to manage food and morale were cut. They saw earlier space games as ones where "the player was never truly the commander of a starship, they were usually just glorified foot soldiers"; "placing yourself into the shoes of Captain Picard seems to be a common fantasy." — [PocketGamer.biz](https://www.pocketgamer.biz/ftw-the-making-of-faster-than-light/)
- [F] GDC postmortem: "By having one singular focus we were able to abandon everything else that didn't fit in line with that vision"; "We kept ditching things to keep moving towards the goal." — [Game Developer](https://www.gamedeveloper.com/design/designing-without-a-pitch---an-em-ftl-em-postmortem)

**Barotrauma (co-op 2D side-view submarine)**
- [C] Players take roles such as captain, engineer, medic and security. Communication "break[s] down," which reviewers frame as part of the fun. — [Common Sense Media](https://www.commonsensemedia.org/game-reviews/barotrauma)
- [C] Reviewers say the division of labour is "compromised in single-player" and that "a crew is not something the game can supply for you." — [HighGround Gaming](https://www.highgroundgaming.com/barotrauma-review/); [Gamegeeker](https://gamegeeker.com/games/barotrauma/review?market=US)
- [P] Bot crew are criticized for acting badly under threat. One example is a GitHub discussion titled "When a tiger attack occurs, the bots act like complete idiots." — [GitHub discussion](https://www.github.com/FakeFishGames/Barotrauma/discussions/13903)

**Artemis Spaceship Bridge Simulator (networked co-op bridge)**
- [F] The captain "sets policy and strategy" and relays commands, but "does not have a dedicated screen and does not have any controls." One station is configured as a shared "main screen" visible to all players. Star Trek was the main inspiration. — [Wikipedia](https://en.wikipedia.org/wiki/Artemis:_Spaceship_Bridge_Simulator)
- [C] Tom's Guide lists five operator stations (Helm, Engineering, Weapons, Science, Communications) and says the captain has no direct control over gameplay. — [Tom's Guide](https://www.tomsguide.com/us/review-artemis-bridge-simulator,review-1928.html)

**Carrier Command 2 (Geometa, co-op carrier command)**
- [C] Reviews say the "grueling pace and lack of automation almost completely disappears" with several players, and that about four crew members are needed to keep the workload manageable. Single-player "lacks any automated systems that can make ship command more efficient." Reviewers also note a steep learning curve, poor tutorials, and no matchmaking. — [Cultured Vultures](https://culturedvultures.com/?p=161988); [Roundtable Co-op](https://roundtablecoop.com/?p=8317) [U: the search summary blended these two sources, so exact attribution between them is unverified]

**Duskers, Iron Lung, Highfleet (console- and instrument-mediated command)**
- [C] Duskers is played almost entirely by typed commands (e.g., "navigate 1 r3") to drones. Reviewers praise its tension and audio; some find the repetitive typing a drawback. — [GameSpot](https://gamespot.com/reviews/duskers-review/1900-6416465/); [Bit-tech](https://www.bit-tech.net/reviews/gaming/duskers-review/2/)
- [C] In Iron Lung, the sub's only window is barricaded, so the player navigates "by sensors alone" and a single exterior camera. Dread Central calls this "a sense of terrible claustrophobia and helplessness." — [Dread Central](https://www.dreadcentral.com/reviews/486480/ultra-indie-spotlight-sunday-iron-lung/)
- [C] Highfleet uses "a diegetic interface that has you accessing the different parts of the game experience through the window of your flagship." — [PC Gamer](https://www.pcgamer.com/highfleet-review/). Its radio-intercept minigame is criticized as the weakest system because the player must set every signal parameter by "incredibly slow mouse wheel scroll." — [Cultured Vultures](https://culturedvultures.com/?p=161058) [U]. An analysis notes the intercept system can be skipped entirely. — [Ashlander Analysis](https://ashlanderanalysis.substack.com/p/highfleet-the-false-prophet-simulator) [U]

### Inferences
- [I] **Captain-level abstraction is commercially proven for modern-era subs.** Cold Waters and Sea Power both earned "Very Positive" Steam ratings with no mandatory station operation. Dangerous Waters' station depth earned critical respect (Metacritic 82), but reviewers stress its steep learning curve, click-heavy UI and hotkey overload.
- [I] **The strongest repeated complaint is the cost of switching roles,** not the existence of roles. SH5's walk-to-station interior was criticized and Dangerous Waters' F-key jumping was praised. A dual-mode design should make "take the station" a one-input action.
- [I] **Crew feedback quality is a recurring weak point.** Examples: Cold Waters' text-only messages with no history, SH4's quiet crew compared with SH3's advising officers, SH5's repetitive dialogue, and UBOAT's opaque crew progress. In a captain-level game the crew's reports are the main interface, so they need investment.
- [I] **Delegated AI must be trustworthy under pressure.** Barotrauma bots and Cold Waters' missed warnings (per players) show that an unreliable crew forces the "captain" to micromanage, which defeats the command fantasy. Dangerous Waters' auto-TMA was called "competent" but created duplicate tracks, which is a readability failure rather than a competence failure.
- [I] **Human co-op crews (Artemis, Wolfpack, Barotrauma, Carrier Command 2) make the captain role socially rich,** but single-player versions suffer without strong automation. Multiplayer station play would be a large added scope for a small team. That is a scope decision, not a recommendation.
- [I] FTL shows that a "captain" fantasy can be delivered by cutting crew micro-systems (food, morale) and keeping a few high-leverage decisions. This is a useful counterweight to UBOAT-style crew simulation.

### Gaps
- No developer postmortem found for Cold Waters, Dangerous Waters or SH5 that explains why the designers chose their command model. The evidence is from reviews only.
- The PC Gamer Cold Waters review body could not be retrieved (truncated). The GameSpot SH5 review text was only partly retrieved.
- No reliable data was found on what share of players use manual vs automatic settings in SH3/SH4/UBOAT. No telemetry is public.
- The Carrier Command 2 developer article on its command interface (speedrun.com) returned HTTP 403.
- I found no source confirming the design reason for FTL's pause mechanic.

---

## 2. Publicly documented real-world submarine control-room roles and procedures usable for authenticity

### Takeaway
Unclassified public sources confirm a clear chain that maps well onto a dual-mode game. The **Commanding Officer** delegates the ship to an **Officer of the Deck** (OOD). The OOD or a **conning officer** holds "the conn" (control of ship movement), and the CO can take it at any time. Under them are ship-control watchstanders (helmsman, planesman, Diving Officer, Chief of the Watch at ballast control), a **sonar supervisor** who receives reports from sonar operators, and a fire control technician who develops contact solutions. Modern US boats (Virginia class) replace optical periscopes with photonics masts feeding control-room displays, which is directly relevant to presentation. I did not find authoritative public sources on exact report phrasing.

### Cited Findings
- [F] "The conn" is control of a ship's movements. The captain typically assigns an officer of the deck or conning officer and "can take the conn at any time by giving an order to the helm." The OOD may hand the conn to a junior officer for training while keeping responsibility for safe passage. "Deck" and "conn" are distinct and can be held by different officers. — [Wikipedia: Conn (nautical)](https://en.wikipedia.org/wiki/Conn_(nautical)), citing Barber, *The Naval Shiphandler's Guide* (2005); [Wikipedia: Officer of the deck](https://en.wikipedia.org/wiki/Officer_of_the_deck)
- [F] A US Navy news article names submarine watchstations including engineering officer of the watch (EOOW), junior officer of the deck (JOOD), conning officer (CONN) and combat systems officer of the watch (CSOOW). — [Navy.mil](https://www.navy.mil/Press-Office/News-Stories/Article/2248971) [U: search snippet; page returned 403]
- [F] Boston University NROTC: new submarine officers stand junior watches and eventually qualify as Officer of the Deck, "responsible for the entire submarine." This progression could map to a career structure. — [BU NROTC](https://www.bu.edu/rotc/navy/careers/submarine-officer) [U: search snippet]
- [F] PBS NOVA's control room description (a US attack submarine): helmsman and planesman in the front seats with aircraft-style controls; the diving officer sits behind them and "oversees their every action"; the Chief of the Watch sits outboard at the Ballast Control Panel, which "submerges and surfaces the boat" and manages trim; two periscopes stand in the centre; plotting tables are used for navigation; weapons consoles line the starboard side; the aftmost Weapons Control Panel holds the "fire" button, used "once the prerequisites for firing have been met." — [PBS NOVA control room](https://www.pbs.org/wgbh/nova/subsecrets/spriconhiright.html); [PBS NOVA ship control station](https://www.pbs.org/wgbh/nova/subsecrets/spriconlortscc.html)
- [F] The Navy's sonar technician occupational standard lists a "Sonar Supervisor" job and requires operators to "Report sonar data to sonar supervisor." — [MyNavyHR STS occupational standard](https://www.mynavyhr.navy.mil/Portals/55/Reference/NEOCS/Vol1/STS_occs_CH_103_Jul25.pdf) [U: search snippet]
- [F] A US Navy submarine captain (Capt. Jeffrey Currer) says: "Sonar is our only window to the world." Training a sonar operator takes about a year, proficiency another year, and master level "another four years." Passive sonar is preferred because active pings reveal position. Contact classifications "are a lot like fingerprints." — [DVIDS](https://www.dvidshub.net/news/printable/519180)
- [F] Virginia-class boats use two photonics masts with visible and infrared cameras on telescoping arms. Imagery goes to displays inside the boat, so the control room no longer has to sit directly under the sail. — [Wikipedia: Photonics mast](https://en.wikipedia.org/wiki/Photonics_mast); [SPIE](https://spie.org/news/the-eyes-of-a-submarine_photonics-masts)
- [F] DVIDS captions (USS Delaware, Virginia class, 2026) show sonar technicians standing "a control watch," consistent with sonar being worked from the control area. Navy photos (USS Ohio) show a fire control technician searching for contacts "through the scope while standing watch in control." — [DVIDS image](https://www.dvidshub.net/image/9555644/sonar-watch-delaware); [Navy.mil photo gallery](https://www.navy.mil/Resources/Photo-Gallery/igcategory/Submarines/igpage/73/isListView/True/) [U: captions via search]
- [U] The NTSB report on the USS Greeneville collision (2001) reportedly names the conning officer or OOD, the fire control technician of the watch (who "determines 'solutions' for the range, course, and speed of contacts") and the sonar supervisor as the core contact-management team. — [NTSB MAB-05/01 (archived)](https://webarchive.library.unt.edu/web/20080916094556/http://www.ntsb.gov/publictn/2005/MAB0501.pdf). The fetch returned empty; the content came from a search summary.
- [U] The USS Connecticut grounding investigation (2021) reports that the sonar supervisor flagged a trace near the bow and judged it likely biological. Press coverage says the OOD did not report the hazard to the CO, who was not on watch. These are real-world examples of report-chain failures. — [Stars and Stripes](https://stripes.com/branches/navy/2022-05-23/connecticut-submarine-undersea-mountain-crash-6104783.html); [US Pacific Fleet command investigation (FOIA)](https://www.cpf.navy.mil/Portals/52/Downloads/FOIA-Reading-Room/2022/uss-connecticut-01-command-investigation.pdf)
- [U] WWII US submarine doctrine separates the *approach* (manoeuvring to a favourable attack position) from the *attack* (manoeuvring to a firing position). A Naval Submarine League piece describes the captain and fire control party visualizing the attack together, and a zig-zagging target forcing the tracking party to restart its solution. — [Current Doctrine Submarines, Ch. IV (HyperWar)](https://ibiblio.org/hyperwar/USN/ref/SS-Doct/SS-Doct-4.html); [Naval Submarine League archive](https://archive.navalsubleague.org/?p=4769). These are historical, not modern procedure.
- [U] Informal sources suggest internal calls name the station addressed first, then the caller (e.g., "Sonar, Conn…" answered with "Conn, Sonar, aye"). — [Reddit r/submarines via mirror](https://redlib.ssps.io/r/submarines/comments/1hry2c5/help_voice_commands_used_in_modern_us_submarines). Not authoritative.

### Inferences
- [I] The **conn handoff** offers a ready-made, authentic metaphor for switching between captain and operator modes. "The captain can take the conn at any time" corresponds to the player taking direct helm control, and handing it back corresponds to delegating to the AI OOD.
- [I] The documented **report chain** (operator → sonar supervisor → OOD → CO) supports a layered report stream in which the CO-level player receives filtered, summarized reports, and taking a station exposes the raw data.
- [I] Real incident reports (Greeneville, Connecticut) show that tension in real control rooms comes from **incomplete information and report-chain judgment calls**, not from operating machinery. This favours designs in which crew reports and their reliability are part of the gameplay.
- [I] **Modern-era authenticity argument:** on Virginia-class boats the "periscope" view is a camera feed on a display. A screen-based (console-focused or hybrid) periscope view is therefore authentic for a modern setting, unlike a WWII optical eyepiece. This only applies if the player's boat or nation uses photonics masts; many modern boats still have optical periscopes.
- [R] Use only generic, publicly documented role names and phrasing patterns. Do not imply operational accuracy for current classified procedures.

### Gaps
- I found no official, unclassified US Navy or Royal Navy publication on exact standard report and order phraseology for submarines (for example, contact report format or "man battle stations" sequence). Navy pages (navy.mil, netc.navy.mil JQR PDF) returned 403. Next step: the Naval Submarine League *Submarine Review* archive, or published memoirs such as *Blind Man's Bluff* (Sontag & Drew), which I did not access in this pass.
- The NTSB Greeneville report and the Connecticut investigation PDFs could not be opened directly. Claims from them are marked [U].
- I found no public source describing modern fire-control tracking party composition at battle stations.

---

## 3. Design patterns that support both commander and station-operator modes

### Takeaway
Existing games already show the building blocks: per-station automation toggles (SH3/SH4 realism, UBOAT targeting, DW Autocrew), instant station switching (DW F-keys, SH3/SH4 shortcuts), crew competence that grows with assignment (UBOAT), time compression that drops on contact (SH4), pause (DW, Sea Power) and bot-filled stations (Wolfpack). The documented failure modes are slow role switching (SH5), opaque or low-quality crew reporting (Cold Waters, UBOAT, SH5), unreliable AI under stress (Barotrauma), compression interrupts that fire too often (SH4), and weak onboarding (Sea Power, Highfleet, DW, Carrier Command 2).

### Cited Findings
- [F] **Per-station automation exists in several forms.** In DW, the AI crew can man non-command stations and TMA "can still be assigned to the AI." — [Wikipedia DW](https://en.wikipedia.org/wiki/Dangerous_Waters_(video_game)); [Armchair General](https://armchairgeneral.com/review-dangerous-waters.htm). In SH3/SH4, manual TDC and weapon-officer assistance are realism toggles. — [SUBSIM SH3 tips](https://www.subsim.com/tips/tip_sh3.php); [SUBSIM forum](https://www.subsim.com/radioroom/showthread.php?p=2087603). UBOAT offers manual or automatic targeting. — [GOG UBOAT](https://www.gog.com/en/game/uboat). Sea Power has a "configurable simulation level" for carrier ops. — [Steam](https://store.steampowered.com/app/1286220/Sea_Power/)
- [F] **Crew competence and assignment as a mechanic.** In UBOAT, firing solutions improve the longer officers are assigned, and crews go idle without officers present. — [Vice](https://www.vice.com/en/article/uboat-recasts-the-sub-sim-as-a-roguelike-management-game)
- [F/C] **Instant station switching is praised; physical travel is criticized.** — [GameZone DW](https://gamezone.com/?p=99597) [U]; [Bit-tech SH5](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/1/)
- [F/P] **Interrupts during time compression.** SH4 drops to 1x on enemy contact. — [SUBSIM SH4](https://www.subsim.com/sh4/silent_hunter4.php). Players complain about frequent interruptions on transits — [SUBSIM forum](https://www.subsim.com/radioroom/showthread.php?p=885708) — and about reduced detection at high compression. — [SUBSIM forum archive](https://www.subsim.com/radioroom/archive/index.php/t-140764.html)
- [C] **Pause alone does not fix a bad station UI.** Armchair General says DW's ability to pause "does not mitigate the fact that this basic process is very awkward to conduct." — [Armchair General](https://armchairgeneral.com/review-dangerous-waters.htm)
- [C] **The report stream needs voice and history.** In Cold Waters, "There are no crew voices to inform you about changes in depth, course, passing layers, contact updates" and "There is no way to pull up history in the message bar." — [SUBSIM Cold Waters](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)
- [C] **Optional deeper involvement on top of automation.** In Cold Waters the player "can help speed up a good solution by using the signature classification tools" without being required to. — [SUBSIM Cold Waters](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)
- [C/F] **Bots fill unmanned stations in co-op.** — [SUBSIM Wolfpack](https://www.subsim.com/ssr/wolfpack/review_wolfpack.php) [U]. Single-player without automation is criticized. — [Cultured Vultures CC2](https://culturedvultures.com/?p=161988) [U]
- [F] **Onboarding difficulties for complex sims.** The Highfleet developer: "We immediately realized that we would have problems explaining the rules of the game to the players"; "Our tutorial turned out to be too short." — [Game Developer](https://www.gamedeveloper.com/design/designing-i-highfleet-i-a-strategy-game-with-heavy-machinery-and-twirling-knobs). Sea Power lacks in-game guidance. — [Game8](https://game8.co/articles/reviews/sea-power-naval-combat-in-the-missile-age-game-review-early-access). Players report UBOAT doesn't explain crew progress. — [GOG UBOAT](https://www.gog.com/en/game/uboat)
- [C] Game Maker's Toolkit argues that front-loaded tutorials fit genres with many connected systems poorly. — [GMTK talk notes](https://notes.hamatti.org/Gaming/VIdeo-games/Can-we-Improve-Tutorials-for-Complex-Games) [U: secondary notes]. The GDC session "Prime, Teach, Observe" covers priming players and iterating on tutorial design. — [GDC Vault](https://gdcvault.com/play/1020131/Prime-Teach-Observe-Tutorializing-Innovative). Its content was not accessed.
- [F] **Delegated actions with tactical side effects.** Cold Waters damage-control teams make noise, so repairs conflict with silent running. — [PMC Tactical](https://cold-waters.pmctactical.org/damage-control.php)

### Inferences
- [R] **Per-station "who's on it" control with three states:** *Crew (auto)*, *Crew (assisted: crew proposes, player confirms)* and *Player (manual)*. Generalizes the DW Autocrew, SH4 weapon-officer and UBOAT targeting toggles. Store the state per station and expose it on the station itself and in a settings preset.
- [R] **"Take the station / hand it back" as a one-input action** modelled on the conn handoff, with an explicit, short crew acknowledgement ("Conn, aye"-style flavour) so the player always knows who has control. This avoids SH5's walk-to-station cost. Any walkable or visual travel should be optional cosmetics, not a required path.
- [R] **Crew competence affects the quality of delegated work** (solution accuracy, classification time, report latency and false-report rate), not just speed. Ties delegation to the career/crew progression layer (UBOAT precedent) and gives the player a reason to step in.
- [R] **A layered report stream:** (1) priority-tagged spoken or text callouts; (2) a scrollable, filterable log with timestamps (answering the Cold Waters complaint); (3) "drill-down" from a report straight into the relevant station. Reports should reflect the real chain (operator → supervisor → OOD → CO) so they arrive summarized at captain level.
- [R] **Rule-based compression interrupts** with player-tunable thresholds (e.g., new contact, contact classification change, torpedo in water, depth/hazard alarms), plus an "interrupt summary" on drop. This responds to SH4 complaints about too-frequent interrupts and avoids silently degrading detection at high compression.
- [R] **Realism presets plus per-item overrides,** with explicit effects on career scoring if any. This follows the SH3/SH4 precedent. Exactly how scoring should apply is an open design question.
- [R] **Onboarding:** teach captain-mode first (everything automated). Then introduce each station as an optional "qualification" mission, which mirrors the real junior-watch → OOD progression documented by BU NROTC. Provide a sandbox or practice range per station. Avoid one front-loaded tutorial.
- [I] Multiplayer station crews (Artemis, Wolfpack, DW) are a well-loved pattern. Supporting them needs networked station state and bot fill-ins, a material scope increase, so it should be an explicit user decision rather than a default.

### Gaps
- No quantitative usability study of station-switching or automation toggles in naval sims was found.
- No public design document from UBOAT or Cold Waters on crew-AI architecture or competence modelling.
- GDC onboarding talks (Rainbow Six Siege onboarding redesign; Prime, Teach, Observe) were only identified by title. Their recommendations were not retrieved.

---

## 4. Presentation approaches: full 3D vs hybrid 3D/2D vs command-console-focused

### Takeaway
All three approaches have shipped and been well received in some form. Full 3D walkable interiors deliver strong atmosphere but carry the largest documented cost, performance and usability risk (SH5, UBOAT bugs). Hybrid 3D-exterior/periscope views plus 2D tactical maps (Cold Waters, Sea Power, Dangerous Waters) are the modern-era genre norm and are praised for readability. Console- or instrument-focused presentation (Iron Lung, Duskers, Highfleet, Artemis) has delivered high tension on very small teams, but risks opacity and onboarding problems. For a modern sub, screen-based control rooms (photonics-mast feeds) also make the console approach authentic. The deciding factors are scope, target audience and how much the design relies on limited information.

### Cited Findings

**(1) Full 3D exterior + walkable/3D interior**
- [C] SH5's walkable interior was praised for atmosphere — [The Courier](https://www.thecourier.co.uk/entertainment/142932/review-silent-hunter-5-pc) — and criticized for slow movement, being stuck at ladders, sparse crew dialogue and poor frame rate. — [Bit-tech p.1](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/1/). The reviewer says the effort was limited to a single sub class (Type VII). — [Bit-tech p.2](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/2/) [U]
- [C] UBOAT combines a first-person walkable interior with crew management. It was praised for depth and criticized for bugs, crashes and messy controls. — [Vice](https://www.vice.com/en/article/uboat-recasts-the-sub-sim-as-a-roguelike-management-game); [GOG UBOAT](https://www.gog.com/en/game/uboat)
- [C/F] Wolfpack uses a 3D interior with manually operated stations (valves, levers) for co-op crews. — [SUBSIM Wolfpack](https://www.subsim.com/ssr/wolfpack/review_wolfpack.php) [U]

**(2) Hybrid: 3D exterior/periscope + 2D consoles/tactical maps**
- [C] Cold Waters: "The player navigates his sub through a 2D tactical map with the familiar naval icons and the 3D viewer." "Contacts on the 2D tactical map are only as reliable as the sonar and visual detection can make them." "You may not see an enemy in the 3D view if he has not been detected." — [SUBSIM Cold Waters](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)
- [C] Sea Power: players switch between a 3D view and a "tactical 2D map for command decisions," and the tactical displays are called more accessible than others in the genre. — [PMC Tactical](https://sea-power.pmctactical.org/review.php). Some players criticize the order UI. — [Vaporlens](https://vaporlens.app/app/1286220/sea_power_naval_combat_in_the_missile_age) [U]
- [C] Dangerous Waters pairs 3D views with detailed 2D station screens that mirror real consoles. It is praised for detail and criticized for clutter and learning curve. — [GameSpot](https://www.gamespot.com/pc/sim/dangerouswaters/review.html) [U]; [SUBSIM DW](https://www.subsim.com/ssr/dangerous_waters/dangwater_review_page2.htm)
- [F] Engine feasibility: Godot's SubViewport can render a 3D scene to a texture shown in 2D UI ("SubViewports are used for rendering 3D objects within a 2D game"). The docs also note that by default the viewport updates its render target only when visible. This supports a 3D periscope or exterior view embedded inside a 2D console. — [Godot docs: Using Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)

**(3) Command-console-focused (mostly 2D/diegetic instruments + audio)**
- [C] Iron Lung: barricaded window, sensors and one exterior camera. Praised as "a masterclass" in building tension — [GG Recon](https://www.ggrecon.com/reviews/iron-lung-review/) — with "exceptional sound design" — [Bloody Disgusting](https://bloody-disgusting.com/video-games/3707036/iron-lung-review/). It runs about one hour.
- [F] Iron Lung was made by a single developer (David Szymanski: developer, publisher and composer) in Unity. — [Wikipedia](https://en.wikipedia.org/wiki/Iron_Lung_(video_game))
- [C] Duskers: command-line drone control and audio-led tension. Reviewers cite "a huge amount of tension" and "raw, pulsing tension," while one calls the interface "not that pretty." — [GameSpot](https://gamespot.com/reviews/duskers-review/1900-6416465/); [Bit-tech](https://www.bit-tech.net/reviews/gaming/duskers-review/2/)
- [F/C] Highfleet: the developer says "The digital interface is certainly more convenient, but it is the analogue interface that gives this feeling of immersiveness." He also admits onboarding problems ("Our tutorial turned out to be too short"). He describes himself as an indie working "together with my friend." — [Game Developer](https://www.gamedeveloper.com/design/designing-i-highfleet-i-a-strategy-game-with-heavy-machinery-and-twirling-knobs). The slow dial-based radio interaction is criticized. — [Cultured Vultures](https://culturedvultures.com/?p=161058) [U]
- [F] Artemis gives each operator a dedicated 2D station screen plus a shared main screen, while the captain has none. — [Wikipedia](https://en.wikipedia.org/wiki/Artemis:_Spaceship_Bridge_Simulator)
- [F] Modern photonics masts feed camera imagery to control-room displays, so a screen-based "periscope" is authentic for such boats. — [Wikipedia: Photonics mast](https://en.wikipedia.org/wiki/Photonics_mast)
- [F] Deep Sea (an experimental audio game) blinds the player and relies on sound. Players reported "shaking hands, sweating, and a stumbling voice." The designer says "It's never the game itself. It's always imagination," but "It doesn't have a 100% success rate." — [Game Developer](https://www.gamedeveloper.com/audio/experimental-i-deep-sea-i-terrifies-players-with-sound-blindness)

**Production scale reference points**
- [U] Killerfish Games (Cold Waters) has been described by a forum user as "3 guys." This is an unverified user comment. — [Steam discussion](https://steamcommunity.com/app/541210/discussions/0/2666627464751130577)
- [F] Highfleet: indie developer plus a friend (no headcount given). — [Game Developer](https://www.gamedeveloper.com/design/designing-i-highfleet-i-a-strategy-game-with-heavy-machinery-and-twirling-knobs). Iron Lung: solo developer. — [Wikipedia](https://en.wikipedia.org/wiki/Iron_Lung_(video_game))

### Inferences

**Comparison matrix ([I]/[E]; relative ratings are researcher estimates, not measured data)**

| Criterion | (1) Full 3D + walkable interior | (2) Hybrid 3D views + 2D consoles/maps | (3) Console-focused (2D/diegetic + audio) |
|---|---|---|---|
| Immersion | Highest "being there" (SH5/UBOAT praised atmosphere). The risk is that it becomes tedium when travel is mandatory | High: periscope and exterior "money shots" plus readable command layer | High *tension* via restricted information (Iron Lung, Duskers). Lower spectacle |
| Readability | Lowest by default. Information sits in 3D space and on small in-world screens | High: 2D map and consoles are the genre's readable core (Sea Power, Cold Waters) | Variable. Can be very clear (dedicated screens) or opaque (Highfleet dials) |
| Dual-mode support | Natural "walk to station" metaphor, but slow (SH5) | Easy: station = screen and hotkey (DW). Captain = map + reports (Cold Waters) | Easy: each station is a screen. Captain view = summary screen + report stream (Artemis model) |
| Production cost [E] | Highest: interior art per sub class, character animation, first-person navigation, performance | Medium: exterior 3D (water, ships, weapons) + UI work. Interior optional | Lowest art cost. UI/UX, audio and information-design cost are high |
| Technical/feasibility risk (small Godot team) [E] | High: SH5 shipped one interior class and had performance issues | Medium: Godot SubViewport supports 3D views embedded in 2D UI | Low–medium: mostly Control-node UI + audio. The risk lies in design clarity |
| Scaling to multiple sub classes/nations [E] | Poor: each interior is a large asset | Good: consoles can be data-driven; exteriors are a single model each | Best: console layouts can be data-driven variants |
| Marketing/visual appeal [I] | Strongest screenshots/trailers | Strong (exterior shots) | Weakest for trailers. Relies on mood and word of mouth |
| Tension tools | Spatial claustrophobia, crew presence | Fog-of-war map (Cold Waters hides undetected units in 3D) | Sensory restriction, audio-first play (Iron Lung, Deep Sea) |

**Questions that would decide the approach (for the user, not answered here):**
1. Is the core fantasy **"being the captain in the room"** (favours 3D presence) or **"commanding through information"** (favours hybrid or console)?
2. How many playable sub classes and nations are planned? Each walkable interior multiplies art cost.
3. Must a 3D exterior or periscope view exist for marketing or for gameplay (visual ID, surface attacks)? If yes, approach 3 becomes approach 2.
4. Will the game rely on **limited information** (sonar-only awareness) as a core tension mechanic? If so, how much world view should the player get at all?
5. Is co-op station play in scope? Separate per-player station screens favour 2/3.
6. What is the team's art vs UI/audio skill balance and the target hardware?
7. Is the setting tied to photonics-mast boats (screen periscope = authentic) or optical-periscope boats?

- [I] Approaches can be staged. For example, a console/hybrid core first, with optional 3D views or interior cosmetics added later. This only holds if the module boundaries keep presentation separate from simulation, which applies to all three options.

### Gaps
- No public budget, headcount or schedule data for SH5's interior, UBOAT or Cold Waters. Cost ratings above are estimates.
- No direct player-preference survey comparing presentation styles in naval sims was found.
- No Godot-specific case study of a shipped naval sim was found. The engine claim is limited to documented SubViewport capability.

---

## 5. Role of audio in submarine-game immersion

### Takeaway
Audio is repeatedly cited as a primary tension source in sensor-limited games (Iron Lung, Duskers, Deep Sea) and as the realism anchor in subs ("Sonar is our only window to the world"). In naval sims, players notice when crew voice callouts are missing (Cold Waters) or sparse (SH4, SH5). I found no dedicated postmortem on submarine-sim audio.

### Cited Findings
- [F] Real-world framing: "Sonar is our only window to the world." Passive listening is primary; active pings are used sparingly because they reveal position. Contact signatures are "like fingerprints." — [DVIDS](https://www.dvidshub.net/news/printable/519180)
- [C] Cold Waters: the SUBSIM reviewer praises "a score that blends with underwater sounds, sonar pings, and sinking ship rumbles," "tense and subtle without being intrusive." The same reviewer criticizes that "There are no crew voices to inform you about changes in depth, course, passing layers, contact updates." — [SUBSIM Cold Waters](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)
- [C] SH4's crew stays mostly quiet apart from status messages, unlike SH3's officer tips. — [Outnow.ch](https://outnow.ch/en/Games/2007/SilentHunter4-WolvesOfThePacific/Review/). SH5 crew dialogue "quickly becomes repetitive and boring." — [Bit-tech](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/1/)
- [C] Iron Lung: tension is built through "exceptional sound design." — [Bloody Disgusting](https://bloody-disgusting.com/video-games/3707036/iron-lung-review/)
- [C] Duskers: reviewers describe "ominous sounds… bulkheads creaking, computers chattering." Audio cues are often the only warning of threats. — [GamingOnLinux](https://gamingonlinux.com/2016/05/duskers-leaves-early-access-heres-a-review)
- [F] Deep Sea: a sight-deprived, audio-only design produced strong fear responses, which came mainly from players' imagination. — [Game Developer](https://www.gamedeveloper.com/audio/experimental-i-deep-sea-i-terrifies-players-with-sound-blindness)
- [P] Cold Waters community guidance: damage-control work is noisy and conflicts with silent running. This is an example of own-ship noise as a mechanic. — [PMC Tactical](https://cold-waters.pmctactical.org/damage-control.php)
- [C] UBOAT crew "can panic or make too much noise, endangering the whole vessel." — [Vice](https://www.vice.com/en/article/uboat-recasts-the-sub-sim-as-a-roguelike-management-game)
- [F] Real sonar skill takes years: about one year of training to operate and about four more to reach master level. — [DVIDS](https://www.dvidshub.net/news/printable/519180)

### Inferences
- [I] Crew voice callouts appear to be an expected feature. Their absence is noted even in highly rated games. For a small team, a modular callout system (station + event + value, e.g., "Conn, Sonar: new contact, bearing…") could cover many events with limited recorded lines. That is an inference; I found no source on recording cost.
- [R] Treat audio as three channels with separate volume controls: (1) **diegetic environment** (hull creaks, machinery, flow noise, transients); (2) **sonar listening** (hydrophone or broadband as an optional manual station); (3) **crew callouts** (the report stream from Q3). Pair every important callout with a text log entry for accessibility and history.
- [I] Because real sonar classification takes years to master (DVIDS), manual listening should be assisted by visual aids or crew classification at lower realism levels. Pure ear-only identification would gate most players.
- [I] Own-ship noise as a player-visible resource (UBOAT, Cold Waters precedents) links audio, crew actions and stealth into one readable system.

### Gaps
- No developer postmortem or GDC audio talk specific to a submarine sim (SH series, Cold Waters, UBOAT, DW) was found.
- No source was found on the recording or localisation cost of crew voice systems in naval sims.
- Hydrophone-recording articles found were for non-submarine games (subROV, film work) and were not used.

---

## 6. UI readability and accessibility for dense sim interfaces; diegetic vs non-diegetic UI research

### Takeaway
Research does not support "diegetic is always better." Performance depends on the information type (Peacocke et al. 2018). Coherence between UI theme and game fiction predicts immersion more than display type (Fagerholt & Lorentzon 2009). Removing non-diegetic HUD elements raised immersion mainly for expert players (Iacovides et al. 2015). Sim-specific complaints centre on hotkey discoverability, clutter (DW), slow analogue-style controls (Highfleet radio), lack of remapping (SH5) and missing message history (Cold Waters). Xbox Accessibility Guidelines give concrete minimum contrast ratios and recommend player-configurable text.

### Cited Findings
- [F] Fagerholt & Lorentzon (Chalmers/EA DICE, 2009) classify UI elements by diegesis and spatiality. They found "game coherence," where the HUD theme matches the game theme, is a stronger determinant of immersion than display type. — [Chalmers thesis record](https://odr.chalmers.se/items/d5fe6889-4cc6-49c2-ba56-0d759e2f37eb/full); [PDF](https://publications.lib.chalmers.se/records/fulltext/111921.pdf) [U: findings from search summary]
- [F] Peacocke et al. (2018) ran four within-subjects FPS experiments. For ammo, the diegetic number was best (about 35% fewer shots before reload than icons on the HUD). For health, HUD displays performed best, and participants preferred a bar on the HUD even though it performed worse. For navigation, a guide line far outperformed a compass (21.6 s vs 56.4 s per waypoint). The authors' conclusions: "no one display type – HUDs or alternatives – are universally best" and "Our results do not support existing recommendations to use alternative displays whenever possible." Only performance and preference were measured, not immersion. — [Peacocke et al., York University](https://www.yorku.ca/mack/ec2018.html)
- [F] Iacovides et al. (CHI PLAY 2015), "Removing the HUD": removing non-diegetic elements increased immersion in **expert** players, mainly through cognitive involvement and sense of control. The authors argue that designers must consider player expertise. — [Open University repository](https://oro.open.ac.uk/46759)
- [F] Xbox Accessibility Guideline 102 sets a minimum contrast of 4.5:1 for standard text and visual elements and 3:1 for large-scale text. It suggests a high-contrast mode and solid backgrounds behind on-screen text. — [Microsoft XAG 102](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102)
- [F] Xbox text guidance says platform screen magnifiers are not a substitute for minimum text size. It says the best approach is "providing players with choices to configure the UI." — [Microsoft XAG 101 deep dive](https://devdocs.xbox.com/build/game-principles/accessibility/xag-deep-dives/xag-101-text-display.md) [U: search summary]
- [F] Game Accessibility Guidelines note that after text size, contrast is one of the most common UI complaints. — [gameaccessibilityguidelines.com](https://gameaccessibilityguidelines.com/?p=21) [U: specific page not confirmed]
- [C] Dangerous Waters: hotkeys are "impractical to remember"; "There is no way to easily see what commands are available for the current window." Remappable hotkeys were praised. — [Armchair General](https://armchairgeneral.com/review-dangerous-waters.htm). Map clutter: "Chinese Pick-up Sticks." — [SUBSIM DW](https://www.subsim.com/ssr/dangerous_waters/dangwater_review_page2.htm)
- [C] SH5: "the cardinal sin of not allowing you to remap any of the keyboard or mouse controls." — [Bit-tech](https://bit-tech.net/reviews/gaming/pc/silent-hunter-5-review/1/)
- [C] Highfleet: radio interception via "incredibly slow mouse wheel scroll." Players accidentally zoom the map while turning a dial. — [Cultured Vultures](https://culturedvultures.com/?p=161058) [U]
- [C] Cold Waters: no message history, and players asked for NATO designations on contact labels. The latter was later patched. — [SUBSIM Cold Waters](https://www.subsim.com/ssr/cold_waters/review_cold_waters.php)

### Inferences
- [R] **Use a hybrid UI policy:** keep diegetic consoles for atmosphere and coherence, but make time-critical, safety-critical information (torpedo warnings, depth/hazard alarms, own-ship noise) available in a consistent non-diegetic layer as well. The Peacocke health/ammo split and Iacovides' expertise effect support offering a "minimal HUD" option for expert players instead of forcing either.
- [R] **Discoverability:** each station screen should show its available actions and bindings on screen, as an answer to the DW complaint. All inputs should be remappable (SH5 complaint).
- [R] **Clutter control:** filtering, aging and merging of contact tracks and bearing lines, with a player-clearable history. This responds to the DW auto-TMA duplication and pick-up-sticks problems.
- [R] **Avoid "analogue for analogue's sake"** for frequent actions (the Highfleet dial complaint). Reserve skeuomorphic controls for infrequent or flavour actions, or give them keyboard or direct-entry alternatives.
- [R] Plan accessibility from the start of UI work: scalable text, a contrast target of at least 4.5:1, colour-independent contact symbology (shape plus colour), subtitles and a log for all voice callouts, and separate audio buses. These are inferences from the XAG and GAG guidance.

### Gaps
- No accessibility study specific to naval or flight sims was found.
- The research on diegetic UI is FPS-based. Whether it transfers to slow-paced command sims is an open question.
- The exact Game Accessibility Guidelines wording on text size and contrast was not retrieved directly.
