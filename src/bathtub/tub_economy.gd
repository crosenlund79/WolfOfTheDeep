class_name TubEconomy
extends RefCounted
## The shared rules of the candy economy. The same prices, repairs, rewards
## and harbour patch apply to the player and to every rival: nobody gets free
## candy, and nobody is ever left without a boat that floats.


static func hull_cost(ship: Dictionary) -> int:
	return ceili(maxf(float(ship["max_hull"]) - float(ship["hull"]), 0.0) / TubData.HULL_PER_CANDY)


static func comp_cost(ship: Dictionary, c: String) -> int:
	return ceili((1.0 - float((ship["comp"] as Dictionary)[c])) * float(TubData.COMPONENT_FULL_COST))


static func full_repair_cost(ship: Dictionary) -> int:
	var t := hull_cost(ship)
	for c in TubData.COMPONENTS:
		t += comp_cost(ship, c)
	return t


## Repair hull with what can be afforded (up to `budget` if given). Returns candy spent.
static func repair_hull(ship: Dictionary, candy: int, budget: int = -1) -> int:
	var cost := hull_cost(ship)
	var spend := mini(candy, cost if budget < 0 else mini(budget, cost))
	if spend <= 0:
		return 0
	ship["hull"] = minf(float(ship["hull"]) + float(spend) * TubData.HULL_PER_CANDY, float(ship["max_hull"]))
	return spend


## Repair one component, fully if affordable, otherwise as far as the candy goes.
static func repair_comp(ship: Dictionary, c: String, candy: int) -> int:
	var cost := comp_cost(ship, c)
	var spend := mini(candy, cost)
	if spend <= 0:
		return 0
	var comp: Dictionary = ship["comp"]
	comp[c] = 1.0 if spend >= cost else minf(float(comp[c]) + float(spend) / float(TubData.COMPONENT_FULL_COST), 1.0)
	return spend


## Why it cannot be bought ("" if it can).
static func buy_blocker(ship: Dictionary, item: String, candy: int) -> String:
	var it: Dictionary = TubData.SHOP[item]
	if (ship["upgrades"] as Array).has(item):
		return "already fitted"
	if not (it["for"] as Array).has(String(ship["kind"])):
		return "does not fit this vessel"
	if candy < int(it["price"]):
		return "needs %d candy" % int(it["price"])
	return ""


## Fit an upgrade (the caller pays). Returns the price.
static func buy(ship: Dictionary, item: String) -> int:
	(ship["upgrades"] as Array).append(item)
	if item == "armour":
		ship["max_hull"] = int(ship["max_hull"]) + 30
		ship["hull"] = float(ship["hull"]) + 30.0
	return int(TubData.SHOP[item]["price"])


## No permanent bankruptcy: the harbour patches anyone up to a floating
## minimum, free. Returns true if it had to.
static func harbour_patch(ship: Dictionary) -> bool:
	var did := false
	var floor_h := float(ship["max_hull"]) * TubData.PATCH_HULL
	if float(ship["hull"]) < floor_h:
		ship["hull"] = floor_h
		did = true
	var comp: Dictionary = ship["comp"]
	for c in TubData.COMPONENTS:
		if float(comp[c]) < TubData.PATCH_COMPONENT:
			comp[c] = TubData.PATCH_COMPONENT
			did = true
	return did


## A rival's refit between battles, from a few plain rules and their purse:
## mend the hull as far as their caution wants, fix what is badly broken,
## then buy what they long for if they can keep their reserve. Returns what
## they did, in words; the captain's candy and ship are changed.
static func plan_rival(c: TubCaptain) -> Array[String]:
	var out: Array[String] = []
	var ship := c.ship
	var caution := clampf(c.trait_v("caution") + (0.15 if c.tilt < 0.0 else 0.0), 0.0, 1.0)
	var target := 1.0 if caution >= 0.6 else (0.5 if caution < 0.2 else 0.75)
	var want_h := float(ship["max_hull"]) * target
	if float(ship["hull"]) < want_h:
		var need := ceili((want_h - float(ship["hull"])) / TubData.HULL_PER_CANDY)
		var spent := repair_hull(ship, c.candy, need)
		c.candy -= spent
		if spent > 0:
			out.append("%s mended the hull (%d candy)." % [c.short.capitalize(), spent])
		if float(ship["hull"]) < want_h - 0.5:
			out.append("%s could not afford a full repair and sails with %d%% hull." % [c.short.capitalize(), int(100.0 * float(ship["hull"]) / float(ship["max_hull"]))])
	var fix_below := 0.8 if caution >= 0.6 else (0.3 if caution < 0.2 else 0.5)
	for k in TubData.COMPONENTS:
		if float((ship["comp"] as Dictionary)[k]) < fix_below and c.candy > 0:
			var spent2 := repair_comp(ship, k, c.candy)
			c.candy -= spent2
			if spent2 > 0:
				out.append("%s fixed the %s (%d candy)." % [c.short.capitalize(), String(TubData.COMPONENT_NAMES[k]).to_lower(), spent2])
	var bought := 0
	for item in c.prefs:
		if bought >= (2 if caution < 0.2 else 1):
			break
		if buy_blocker(ship, String(item), c.candy - c.reserve) == "":
			c.candy -= buy(ship, String(item))
			bought += 1
			out.append("%s bought a %s." % [c.short.capitalize(), String(TubData.SHOP[item]["name"])])
	if harbour_patch(ship):
		out.append("%s was patched up for free at the harbour, just enough to float." % c.short.capitalize())
	return out
