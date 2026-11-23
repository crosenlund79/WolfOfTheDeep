class_name TubData
extends RefCounted
## Fixed data for the Bathtub Edition: vessel types, components, the shop,
## prices and rewards, and the recurring cast of rival captains. Plain data
## only; the rules that use it live in TubEconomy, TubBattle and TubCareer.

## Vessel types. speed in px/s, turn in rad/s, radius in px.
const KINDS := {
	"sub": {"name": "Toy Submarine", "hull": 100, "speed": 250.0, "turn": 2.5, "radius": 24.0, "art": "sub", "scale": 0.62},
	"patrol": {"name": "Toy Patrol Boat", "hull": 70, "speed": 215.0, "turn": 2.0, "radius": 26.0, "art": "patrol", "scale": 0.62},
	"destroyer": {"name": "Toy Destroyer", "hull": 150, "speed": 115.0, "turn": 0.95, "radius": 40.0, "art": "destroyer", "scale": 0.7},
	"duck": {"name": "Rubber Duck", "hull": 120, "speed": 160.0, "turn": 1.7, "radius": 34.0, "art": "duck", "scale": 0.62},
}

const COMPONENTS := ["propulsion", "steering", "weapons", "sensors"]
const COMPONENT_NAMES := {"propulsion": "Propeller", "steering": "Rudder", "weapons": "Weapons", "sensors": "Periscope & lookouts"}
const COMPONENT_EFFECT := {
	"propulsion": "slower top speed",
	"steering": "slower turns",
	"weapons": "slower reloads",
	"sensors": "spots enemies later",
}

const DEPTHS := ["SURFACE", "PERISCOPE", "DEEP"]

## The shop. "for": which vessel types can fit it.
const SHOP := {
	"propeller": {"name": "Faster Propeller", "price": 40, "desc": "+15% top speed", "for": ["sub", "patrol", "destroyer", "duck"]},
	"rudder": {"name": "Better Rudder", "price": 35, "desc": "+25% turning", "for": ["sub", "patrol", "destroyer", "duck"]},
	"launcher": {"name": "Rapid Launcher", "price": 50, "desc": "weapons reload 40% faster", "for": ["sub", "patrol", "destroyer", "duck"]},
	"racks": {"name": "Extra Torpedo Racks", "price": 30, "desc": "+4 torpedoes each battle", "for": ["sub"]},
	"shield": {"name": "Bubble Shield", "price": 70, "desc": "absorbs one hit; refills in 20 s", "for": ["sub", "patrol", "destroyer", "duck"]},
	"periscope": {"name": "Sharp Periscope", "price": 35, "desc": "+40% spotting range; sees into foam", "for": ["sub", "patrol", "destroyer", "duck"]},
	"armour": {"name": "Reinforced Hull", "price": 60, "desc": "+30 maximum hull", "for": ["sub", "patrol", "destroyer", "duck"]},
	"decoy": {"name": "Decoy Duckling", "price": 45, "desc": "2 decoys each battle (G)", "for": ["sub"]},
}
const SHOP_ORDER := ["propeller", "rudder", "launcher", "racks", "shield", "periscope", "armour", "decoy"]

## Repairs: hull points per candy; a component from wrecked to perfect.
const HULL_PER_CANDY := 2.0
const COMPONENT_FULL_COST := 30
## No permanent bankruptcy: the harbour patches anyone, free, up to here.
const PATCH_HULL := 0.4
const PATCH_COMPONENT := 0.3

## Battle prize money and salvage (the same for everyone).
const REWARD := {"hit": 3, "sink": 30, "victory": 25, "survive": 10, "salvage": 10}
## A sunk toy spills some of its captain's candy into the water.
const SPILL_BASE := 6
const SPILL_SHARE := 0.08

const START_CANDY := 100
const BATTLE_TIME := 360.0

## The recurring cast. traits: aggression, caution (retreats sooner, keeps
## range, repairs first), temper (how much grudges bite), greed (chases
## spilled candy). poker: tight, aggro, bluff.
const ROSTER := {
	"plunge": {"name": "Commodore Percival Plunge", "short": "PLUNGE", "kind": "destroyer", "vessel": "HMS Indomitable Splash",
		"livery": Color(0.17, 0.3, 0.62), "candy": 160, "reserve": 30,
		"traits": {"aggression": 0.7, "caution": 0.3, "temper": 0.6, "greed": 0.4},
		"poker": {"tight": 0.45, "aggro": 0.7, "bluff": 0.35}, "prefs": ["armour", "launcher", "shield"],
		"style": "Arrogant, loud, sure of his own brilliance. Likes big guns and big bets."},
	"quackworth": {"name": "Admiral Quackworth", "short": "QUACKWORTH", "kind": "duck", "vessel": "The Old Squeaker",
		"livery": Color(1.0, 0.83, 0.2), "candy": 140, "reserve": 25,
		"traits": {"aggression": 0.65, "caution": 0.45, "temper": 0.9, "greed": 0.3},
		"poker": {"tight": 0.65, "aggro": 0.4, "bluff": 0.15}, "prefs": ["armour", "propeller", "shield"],
		"style": "Grumpy and stubborn. Never forgets a slight. Rams first, asks questions never."},
	"moss": {"name": "Lieutenant Mossy Toadstool", "short": "MOSSY", "kind": "patrol", "vessel": "Lily Pad",
		"livery": Color(0.3, 0.62, 0.28), "candy": 120, "reserve": 50,
		"traits": {"aggression": 0.3, "caution": 0.9, "temper": 0.3, "greed": 0.5},
		"poker": {"tight": 0.8, "aggro": 0.25, "bluff": 0.08}, "prefs": ["shield", "periscope", "rudder"],
		"style": "Careful to a fault. Keeps the range open, repairs everything, folds a lot."},
	"soapbeard": {"name": "Captain Soapbeard", "short": "SOAPBEARD", "kind": "patrol", "vessel": "The Lather Lass",
		"livery": Color(0.72, 0.2, 0.17), "candy": 70, "reserve": 0,
		"traits": {"aggression": 0.95, "caution": 0.05, "temper": 0.8, "greed": 0.9},
		"poker": {"tight": 0.2, "aggro": 0.85, "bluff": 0.6}, "prefs": ["launcher", "propeller", "rudder"],
		"style": "A reckless wind-up pirate. Spends every sweet, bluffs every hand, never retreats."},
	"inkwell": {"name": "Professor Inkwell", "short": "INKWELL", "kind": "destroyer", "vessel": "The Eight-Armed Argument",
		"livery": Color(0.48, 0.31, 0.66), "candy": 150, "reserve": 40,
		"traits": {"aggression": 0.5, "caution": 0.6, "temper": 0.35, "greed": 0.35},
		"poker": {"tight": 0.6, "aggro": 0.55, "bluff": 0.25}, "prefs": ["periscope", "launcher", "armour"],
		"style": "A calculating octopus. Patient, precise, and keeps careful notes on everyone."},
}
const ROSTER_ORDER := ["plunge", "quackworth", "moss", "soapbeard", "inkwell"]

## What they say. Keys are events; picked at random, never twice running.
const LINES := {
	"plunge": {
		"intro": ["Stand aside, minnow. The Commodore is here.", "Splendid! Another tadpole to sink."],
		"grudge": ["You! I have NOT forgotten our last meeting.", "Today I take my candy back, with interest."],
		"respect": ["Ah. You again. Let us make this a proper duel.", "A worthy opponent. How tiresome."],
		"hit_player": ["Ha! Direct hit!", "Feel the Commodore's broadside!"],
		"hurt": ["My paintwork!", "Impossible! A lucky shot!"],
		"sunk": ["This is NOT how it was supposed to go!", "Glub. Most undignified."],
		"retreat": ["A tactical withdrawal. Entirely planned."],
		"win_battle": ["As expected. Bow before the Commodore."],
		"poker_raise": ["I raise. Obviously.", "Let us make this interesting."],
		"poker_fold": ["Pfah. Beneath me."], "poker_win": ["The table recognises its superior."],
		"poker_lose": ["The deck is clearly rigged."], "broke": ["I shall... sit this one out. Temporarily."],
	},
	"quackworth": {
		"intro": ["QUACK. Get out of my bath.", "Hmph. Youngsters."],
		"grudge": ["I remember you. I remember EVERYTHING.", "Revenge is a dish best served squeaky."],
		"respect": ["Hmph. You fight well. For a tin can."],
		"hit_player": ["SQUEAK!", "That'll teach you!"],
		"hurt": ["My beautiful rubber!", "Grr. Quack."],
		"sunk": ["I'll be back. Ducks always float back."],
		"retreat": ["I'm not running, I'm waddling. Strategically."],
		"win_battle": ["Kids these days."],
		"poker_raise": ["Raise. Don't argue.", "Quack. Raise."],
		"poker_fold": ["Fold. Hmph."], "poker_win": ["Mine. All mine."],
		"poker_lose": ["Rigged. Every one of you."], "broke": ["Not today. My purse is empty and so is my patience."],
	},
	"moss": {
		"intro": ["Oh dear. Oh dear oh dear.", "Let's all keep a sensible distance, shall we?"],
		"grudge": ["You sank me last time. I've taken... notes."],
		"respect": ["Ah, it's you. Please go easy on me."],
		"hit_player": ["Sorry! Sorry! It's my job!", "Oh! I hit something!"],
		"hurt": ["Eek! Taking damage!", "Not the hull, not the hull!"],
		"sunk": ["Ribbit... glub."],
		"retreat": ["I'm heading home! Nothing to see here!"],
		"win_battle": ["Oh! We won? How lovely."],
		"poker_raise": ["I... raise? Yes. I raise."],
		"poker_fold": ["Too rich for me.", "I'll fold, thank you."], "poker_win": ["Oh my! For me?"],
		"poker_lose": ["That was most of my repair money..."], "broke": ["I need every sweet for repairs, I'm afraid."],
	},
	"soapbeard": {
		"intro": ["Arr! Hand over yer sweeties!", "Yo ho, a bubble bath for me!"],
		"grudge": ["Ye scuttled me, ye scallywag! Now ye pay!"],
		"respect": ["Ahoy, old foe! May the best pirate win!"],
		"hit_player": ["Arr! Take that!", "Har har! Soaked ye!"],
		"hurt": ["Blast yer barnacles!", "Me lather! Me lovely lather!"],
		"sunk": ["Abandon... bubble..."],
		"retreat": ["Soapbeard never retre... oh, fine."],
		"win_battle": ["The bath be MINE!"],
		"poker_raise": ["All the sweets! Well, more of 'em!", "Raise, ye landlubbers!"],
		"poker_fold": ["Arr. Fold."], "poker_win": ["Treasure! Glorious treasure!"],
		"poker_lose": ["Me sweeties! Me beautiful sweeties!"], "broke": ["Me purse be empty. Lend us a sweet? No?"],
	},
	"inkwell": {
		"intro": ["Fascinating. Let us test a hypothesis.", "I have calculated eight ways this ends. All bad for you."],
		"grudge": ["Last time you embarrassed me. I have revised my methods."],
		"respect": ["A pleasure to observe you again, Captain."],
		"hit_player": ["As predicted.", "Precisely."],
		"hurt": ["Unexpected. Noted.", "An error in my figures."],
		"sunk": ["A flaw in the model. Glub."],
		"retreat": ["Withdrawing to recalculate."],
		"win_battle": ["Q.E.D."],
		"poker_raise": ["The odds favour a raise.", "Raise. Statistically sound."],
		"poker_fold": ["Negative expectation. Fold."], "poker_win": ["The numbers never lie."],
		"poker_lose": ["Variance. Merely variance."], "broke": ["My budget does not allow it this week."],
	},
}
