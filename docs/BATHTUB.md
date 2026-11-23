# Wolf of the Deep — Bathtub Edition (experiment)

A fast, top-down 2D toy-submarine game in a bathtub: torpedoes and bubble
trails, soap and sponges, rival captains with long memories, and a poker club
where everyone gambles with the same candy they need for repairs.

This is an **experiment** on branch `claude/bathtub-edition`. It is not merged
anywhere. The serious submarine simulator is untouched on its own branch and in
the recovery branch `backup/pre-bathtub-experiment`; its saves live in a
different folder and are never read or written by this edition.

## Start

1. Download the build ZIP from the GitHub Actions run and extract it anywhere.
2. Run `WolfOfTheDeepBathtub.exe`. No installer and no compiling. Windows may
   warn about an unsigned program: *More info → Run anyway*.
3. Choose **New Game** (or **Continue**). Read **How to play** once if you like.

The game opens full screen at 1920 × 1080 and scales to other sizes. Alt+Enter
is not bound; quit from the menu.

## Controls

| Key | Action |
| --- | --- |
| W / S (or ↑ / ↓) | Ahead / astern. Hold Shift for half speed |
| A / D (or ← / →) | Steer |
| Space | Fire a torpedo straight ahead (aim with the whole boat) |
| Q / E | Rise / dive: Surface ↔ Periscope ↔ Deep |
| G | Drop a decoy duckling (if you bought some) |
| X (hold, at the rim, surfaced) | The hand lifts you out: withdraw from the battle |
| Tab | **Tactical pause**: your submarine, repairs, upgrades, the captains |
| Esc | Pause menu (resume, restart this battle, give up, music); also *back* in menus |
| M | Music on / off |
| At the poker table | C check/call · R raise · P bet the pot · A all in · F fold · **Space: next captain / next hand** · Esc leave |

Menus also work with the mouse.

## The loop

**Harbour → Battle → Results → Harbour** (poker, repairs, upgrades) → next battle.

- **Battles** last at most six minutes of bath time. Sink every rival (then grab
  the spilled candy before it drains), outlast them, or slip out at the rim.
  The first battle has two rivals, later ones three.
- **Depth** is the main tactical choice:
  - *Surface* — fastest and you see furthest, but everyone sees you and the
    patrol boats' deck guns can hit you.
  - *Periscope* — a little slower and harder to spot; you can still fire.
    Deck guns cannot reach you; torpedoes, the duck's squeak and (lightly)
    depth charges can.
  - *Deep* — nearly invisible, passes under sponges, washcloths and
    torpedoes, but cannot fire or pick up candy, uses air (rise before it runs
    out) and depth charges hit hardest.
- **The bath**: soap and the shampoo bottle block everything; the sponge floats
  (dive under it); the washcloth slows you; foam hides you; the drain pulls;
  the tap pushes while it runs. Ramming the rim or the soap at speed dents
  the hull a little.
- **Component damage**: hits wear the propeller (speed), rudder (turning),
  launcher (reload) and periscope (spotting) as well as the hull.

## Candy

Candy is the one currency, for you and for every rival alike.

- **Earned** in battle at the same posted rates for everyone: 3 per hit, 30 per
  sinking, 25 for a victory, 10 for surviving, 10 salvage if sunk. A sunk
  toy also spills part of its captain's candy into the water for anyone to grab.
- **Spent** on repairs (2 hull per candy; a wrecked part costs 30 to make
  perfect), upgrades, and poker stakes.
- **No permanent bankruptcy**: anyone (you or a rival) with nothing left gets a
  free harbour patch to a floating minimum: 40 % hull, 30 % parts. Nobody gets
  free repairs beyond that, and nobody has hidden candy.
- In battle, Tab offers one **emergency patch** (+20 hull for 15 candy).
  Full repairs and upgrades are bought at the harbour.

| Upgrade | Price | Effect |
| --- | --- | --- |
| Faster Propeller | 40 | +15 % top speed |
| Better Rudder | 35 | +25 % turning |
| Rapid Launcher | 50 | reload 40 % faster |
| Extra Torpedo Racks | 30 | +4 torpedoes each battle (submarine only) |
| Bubble Shield | 70 | absorbs one hit; refills in 20 s |
| Sharp Periscope | 35 | +40 % spotting; sees into foam |
| Reinforced Hull | 60 | +30 maximum hull |
| Decoy Duckling | 45 | 2 decoys each battle (submarine only) |

## The rival captains

| Captain | Vessel | Temperament |
| --- | --- | --- |
| Commodore Percival Plunge | HMS Indomitable Splash (destroyer) | Arrogant, loud; big guns and big bets |
| Admiral Quackworth | The Old Squeaker (rubber duck) | Grumpy, stubborn, rams first |
| Lieutenant Mossy Toadstool | Lily Pad (patrol boat) | Careful; keeps the range open, folds a lot |
| Captain Soapbeard | The Lather Lass (patrol boat) | Reckless; spends every sweet, bluffs every hand |
| Professor Inkwell | The Eight-Armed Argument (destroyer) | Calculating and patient; keeps notes on everyone |

Each captain keeps a persistent purse, ship condition, upgrades, a record and
**memories**. Between battles they repair and buy upgrades from their own
purse according to temperament; if they lost their candy (in battle or at your
poker table) they fight the next battle damaged or unimproved, and the harbour
gossip says so.

**GRUDGE** grows only from things that happened: sinking a captain, damaging
them, beating them at cards. A grudge makes a captain more aggressive towards
you, more likely to turn up in your battles, and greet you accordingly. Being
saved by you from another attacker softens them; being sunk repeatedly makes a
captain warier; a heavy loss at cards puts a hot-tempered captain on tilt and
shakes a careful one. The **Captains** panel (Tab, or at the harbour) shows each
captain's mood, purse, ship and what they remember.

## The Captains' Poker Club

Optional four-player Texas Hold'em at the harbour, played for real candy.

- Three tables: Penny (blinds 1/2), Bubble (2/4) and High Tide (5/10), each
  with a buy-in range. You take at most the table maximum to the table; the
  rest stays in your purse.
- Captains sit only if they can afford the buy-in; careful captains keep their
  repair money and decline. The stakes screen says who sits and why others do not.
- Correct all-ins and side pots; nobody can bet more than they have.
- After each captain acts the game **waits for Space**, so you can follow
  every action. Everything won or lost changes the real purses at once.

## Saves

Saved automatically at the harbour and after every battle, plus a pre-battle
snapshot for *Restart this battle*.

- Windows: `%APPDATA%\Godot\app_userdata\Wolf of the Deep Bathtub Edition\bathtub\`
  (`career.json`, `prebattle.json`). Delete the folder to start over.
- The serious simulator uses `...\app_userdata\Wolf of the Deep\saves\`; the
  Bathtub Edition never touches it.

## Replacing art and sounds

Put files in a `custom` folder next to the executable (the ZIP contains it) and
restart the game. A missing or unreadable file falls back to the built-in one.

- Pictures: `custom/graphics/bathtub/<name>.png` — `sub`, `patrol`,
  `patrol_livery`, `destroyer`, `destroyer_livery`, `duck`, `duck_livery`,
  `torpedo`, `soap`, `sponge`, `washcloth`, `bottle`, `faucet`, `candy`,
  `decoy`, `charge`, `portrait_player`, `portrait_plunge`, `portrait_quackworth`,
  `portrait_moss`, `portrait_soapbeard`, `portrait_inkwell`. Ship pictures face
  right (east); livery layers are white shapes tinted with the captain's colour.
- Sounds: `custom/audio/bathtub/<name>.ogg`, `.wav` or `.mp3` — `bubble_launch`,
  `toy_hit`, `splash_small`, `plink`, `pew`, `depth_boom`, `plop`, `ping`,
  `squeak`, `squeak_small`, `quack`, `thud`, `sink`, `candy`, `gurgle`, `pop`,
  `bubble`, `dive`, `surface`, `lift`, `faucet`, `whistle`, `ui_click`,
  `music` (looped).

All built-in pictures and sounds were made for this edition. The font is
Fredoka (SIL Open Font License, included).

## A short playtest (15–20 minutes)

1. **New Game.** Read the harbour gossip, open **The Captains** and pick one to watch.
2. **Battle 1** on the surface: feel the speed and turning, fire a few
   torpedoes, notice who shoots at you. Then try periscope and deep — does each
   depth feel useful? Dive under the sponge; hide in foam.
3. Press **Tab** mid-fight: the bath freezes. Check your parts. Use the
   emergency patch if hurt.
4. Sink a toy and **grab its spilled candy**; or hold **X** at the rim to slip out.
5. At the harbour: **repair**, maybe buy one upgrade. Read the gossip — who
   could not afford repairs?
6. **Poker**: sit at the Penny Table, play a few hands (Space after each
   captain). Try to take a captain's candy, then check the Captains panel.
7. **Battle 2/3**: is the captain you sank angrier? Is the one you fleeced
   still damaged? Use *Esc → Restart this battle* once.
8. Quit, start again, **Continue**: everything should be as you left it.

Questions worth answering: Are battles too short or too long? Is the surface
too dangerous? Are torpedoes satisfying to land? Does any captain feel unfair?
Is poker worth the detour? Do grudges show up in a way you notice?

## Known limitations

- Claude did not run the Windows build. The game was verified on Linux:
  headless checks, a ten-battle soak and software-rendered screenshots. Frame
  rate on a real graphics card is unmeasured.
- The sounds and music were synthesised for this edition and checked to load
  and play; nobody has listened to the mix yet.
- Balance is first-pass. In automated soaks, a careless player who stays on the
  surface against three rivals sank within roughly half a minute to two and a
  half minutes; one who stayed at periscope depth often lasted three to six.
  A real player should do better. Needs a human playtest.
- A player who keeps losing with no candy fights at the free 40 % patch and can
  slide into a losing streak; the free patch, survival pay and salvage are the
  only way back.
- One bath, five captains, three toy types. Keyboard only in battle (no
  gamepad, no rebinding). Rival lines repeat over many battles.
- Poker captains play by hand strength and temperament; they do not read you.
- The serious simulator's files are still packed into the executable (unused),
  so it is larger than it needs to be, and the Windows file properties still
  name the serious game.

## Future suggestions (not planned)

- More baths: kitchen sink, paddling pool, a garden pond with a heron.
- Gamepad support and key rebinding; an easy/normal setting.
- A season table and a *Bath Cup* final; rivals' own poker nights, loans and
  alliances between captains.
- Visible damage on the toys; portraits that change with mood.
- A smaller build that leaves out the serious simulator.

## Developer checks

```
godot --headless --path . --fixed-fps 30 -s tests/check_tub_battle.gd
godot --headless --path . -s tests/check_tub_economy.gd
godot --headless --path . --fixed-fps 30 -s tests/check_tub_rivals.gd
godot --headless --path . --fixed-fps 30 -s tests/check_tub_flow.gd
godot --headless --path . -s tests/check_poker.gd
```

Movement, collisions, depth, torpedoes and weapons by depth, the tactical
pause, damage and repair costs, candy rewards, upgrades, refits, poker rules,
all-ins and side pots, persistent rival finances (including the six-step
"lose at poker → cannot afford → fights damaged → survives save/load" test),
GRUDGE, save/load, battle progression, menus and keys, and the art/sound
overrides (using a temporary folder, never `custom/`).
