class_name TubBattle
extends RefCounted
## One battle in the bath, as pure simulation (no drawing): the player's
## submarine against rival captains' toys among soap, sponges and foam.
## step(dt) advances everything; the view reads the state and drains
## `events` for effects, sounds and speech bubbles. Deterministic for a seed.
##
## Depth: SURFACE fastest, sees and is seen furthest, shot at by deck guns;
## PERISCOPE slower, harder to spot, can still fire torpedoes; DEEP slow,
## nearly invisible, passes under floating things and torpedoes, cannot fire,
## limited air - but depth charges reach it.

const HALF := Vector2(860.0, 400.0)       # the water inside the tub
const CORNER := 150.0
const DRAIN := Vector2(770.0, 0.0)
const DRAIN_R := 300.0
const FAUCET_X := -860.0
const FAUCET_EVERY := 24.0
const FAUCET_RUN := 6.0

const SUB_TORP := {"speed": 560.0, "life": 2.4, "dmg": 24.0}
const SHIP_TORP := {"speed": 360.0, "life": 3.2, "dmg": 18.0}
const PELLET := {"speed": 620.0, "life": 0.9, "dmg": 4.0}
const CHARGE := {"fuse": 1.1, "r": 95.0, "deep": 20.0, "scope": 13.0}
const SQUEAK := {"r": 260.0, "grow": 520.0, "dmg": 10.0}
const RAM_DMG := 22.0

var rng := RandomNumberGenerator.new()
var ships: Array[TubShip] = []
var player: TubShip
var obstacles: Array[Dictionary] = []     # soap, bottle, sponge, cloth
var foam: Array[Dictionary] = []          # {pos, r, vel, phase}
var torps: Array[Dictionary] = []         # {pos, vel, owner, life, dmg, sub}
var pellets: Array[Dictionary] = []
var charges: Array[Dictionary] = []       # {pos, fuse, owner}
var waves: Array[Dictionary] = []         # {pos, r, owner, done}
var pickups: Array[Dictionary] = []       # {pos, amount, t}
var decoys: Array[Dictionary] = []        # {pos, life}
var events: Array[Dictionary] = []
var purses := {}                          # id -> candy at the start (spills come from here)
var ledger := {}                          # id -> candy won or lost in the water
var relations := {}                       # rival id -> {player: grudge, other id: grudge}
var helped: Array[String] = []            # rivals the player saved from an attacker
var dmg_by := {}                          # "attacker>victim" -> damage done
var sunk_by := {}                         # victim id -> who sank them
var time := 0.0
var limit := TubData.BATTLE_TIME
var faucet_on := false
var over := false
var result := ""                          # victory, defeat, withdrew, draw
var retreat_hold := 0.0
var sandbox := false                      # a peaceful bath behind the menus: never ends
var cleared_t := -1.0                     # when the last rival went: a moment to grab the candy
const GRAB_TIME := 8.0
var _say_t := {}


## player_state: the player's ship dictionary; rivals: [{captain: TubCaptain}]
func setup(player_state: Dictionary, player_candy: int, rivals: Array, seed_v: int) -> void:
	rng.seed = seed_v
	_layout()
	player = TubShip.new()
	player.setup(player_state, "player", "Little Wolf", true)
	player.pos = Vector2(-640.0, 0.0)
	player.heading = 0.0
	player.livery = Color(0.15, 0.65, 0.6)
	ships.append(player)
	purses["player"] = player_candy
	ledger["player"] = 0
	var spots := [Vector2(560.0, -230.0), Vector2(560.0, 230.0), Vector2(380.0, 0.0), Vector2(250.0, -300.0)]
	for i in rivals.size():
		var cap: TubCaptain = rivals[i]
		var s := TubShip.new()
		s.setup(cap.ship, cap.id, cap.short, false)
		s.livery = cap.livery
		s.style = cap.battle_style()
		s.pos = spots[i % spots.size()]
		s.heading = PI
		s.ai = {"target": "", "think": rng.randf() * 0.5, "cool": 1.5 + rng.randf(), "dc": 0.0, "ping": 3.0, "squeak": 2.0,
			"charge": 0.0, "charge_cool": 2.0, "orbit": 1.0 if rng.randf() < 0.5 else -1.0, "wander": Vector2.ZERO, "wander_t": 0.0,
			"seen": {}, "greed": cap.trait_v("greed")}
		ships.append(s)
		purses[cap.id] = cap.candy
		ledger[cap.id] = 0
		var rel := {"player": cap.grudge}
		for k in cap.relations.keys():
			rel[k] = float(cap.relations[k])
		relations[cap.id] = rel
		_say(s, "grudge" if cap.grudge >= 25.0 else ("respect" if cap.respect >= 40.0 else "intro"), 1.0)


## Soap, a bottle, a sponge, a washcloth and foam, placed clear of the start.
func _layout() -> void:
	var kinds := [["soap", Vector2(75, 45), 30.0], ["soap", Vector2(75, 45), 30.0], ["bottle", Vector2(110, 40), 38.0],
		["sponge", Vector2(95, 60), 20.0], ["cloth", Vector2(115, 90), 40.0]]
	for k in kinds:
		for _try in 60:
			var p := Vector2(rng.randf_range(-480.0, 480.0), rng.randf_range(-290.0, 290.0))
			var o := {"kind": k[0], "pos": p, "half": k[1], "corner": float(k[2]), "rot": rng.randf_range(-0.6, 0.6)}
			var ok := true
			for q in obstacles:
				if p.distance_to(q["pos"]) < 230.0:
					ok = false
			if p.distance_to(Vector2(-640, 0)) < 260.0 or p.distance_to(DRAIN) < 260.0:
				ok = false
			if ok:
				obstacles.append(o)
				break
	for i in 4:
		foam.append({"pos": Vector2(rng.randf_range(-600.0, 600.0), rng.randf_range(-300.0, 300.0)), "r": rng.randf_range(85.0, 135.0),
			"vel": Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 8.0)), "phase": rng.randf() * TAU})


# --- geometry ---------------------------------------------------------------------

static func tub_sdf(p: Vector2) -> float:
	var q := p.abs() - (HALF - Vector2(CORNER, CORNER))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - CORNER


static func box_sdf(o: Dictionary, p: Vector2) -> float:
	var local := (p - (o["pos"] as Vector2)).rotated(-float(o["rot"]))
	var rc := float(o["corner"])
	var q := local.abs() - ((o["half"] as Vector2) - Vector2(rc, rc))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rc


static func _grad(f: Callable, p: Vector2) -> Vector2:
	var e := 1.0
	return Vector2(float(f.call(p + Vector2(e, 0))) - float(f.call(p - Vector2(e, 0))), float(f.call(p + Vector2(0, e))) - float(f.call(p - Vector2(0, e)))).normalized()


## Does this obstacle stop something at this depth? Soap and bottles sit on
## the bottom and stop everything; a sponge floats (the deep pass under);
## a washcloth only slows.
static func blocks(o: Dictionary, depth: int) -> bool:
	match String(o["kind"]):
		"soap", "bottle":
			return true
		"sponge":
			return depth < 2
	return false


func in_foam(p: Vector2) -> bool:
	for f in foam:
		if p.distance_to(f["pos"]) < float(f["r"]) * 0.85:
			return true
	return false


func under_cloth(p: Vector2) -> bool:
	for o in obstacles:
		if String(o["kind"]) == "cloth" and box_sdf(o, p) < 0.0:
			return true
	return false


## Can `a` see `b`? Depth, foam, the washcloth, a ping, damage to lookouts.
func can_see(a: TubShip, b: TubShip) -> bool:
	if not b.active():
		return false
	var d := a.pos.distance_to(b.pos)
	if b.revealed_t > 0.0 and d < 480.0:
		return true
	var f: float = [1.0, 0.5, 0.22][b.depth]
	if b.depth == 1 and absf(b.speed) > 0.7 * b.top_speed():
		f = 0.75          # a periscope wake at speed
	if not a.has("periscope") and (in_foam(b.pos) or (b.depth >= 1 and under_cloth(b.pos))):
		f *= 0.35
	return d < a.sight() * f


# --- the step ---------------------------------------------------------------------

func step(dt: float) -> void:
	if over:
		return
	time += dt
	var phase := fmod(time, FAUCET_EVERY)
	var was_on := faucet_on
	faucet_on = phase > FAUCET_EVERY - FAUCET_RUN
	if faucet_on and not was_on:
		_event({"type": "faucet"})
	for f in foam:
		f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * dt
		var fp: Vector2 = f["pos"]
		if absf(fp.x) > HALF.x - 120.0:
			f["vel"] = Vector2(-(f["vel"] as Vector2).x, (f["vel"] as Vector2).y)
		if absf(fp.y) > HALF.y - 100.0:
			f["vel"] = Vector2((f["vel"] as Vector2).x, -(f["vel"] as Vector2).y)
	for s in ships:
		if s.state == "sunk":
			s.sink_t += dt
		if not s.active():
			continue
		if not s.is_player:
			_ai(s, dt)
		_move(s, dt)
		_tick(s, dt)
	_collide_ships()
	_step_torps(dt)
	_step_pellets(dt)
	_step_charges(dt)
	_step_waves(dt)
	_step_pickups(dt)
	for d in decoys:
		d["life"] = float(d["life"]) - dt
	decoys = decoys.filter(func(d: Dictionary) -> bool: return float(d["life"]) > 0.0)
	_check_end()


func _tick(s: TubShip, dt: float) -> void:
	s.reload = maxf(s.reload - dt, 0.0)
	s.revealed_t = maxf(s.revealed_t - dt, 0.0)
	s.hit_flash = maxf(s.hit_flash - dt, 0.0)
	if s.has("shield") and not s.shield:
		s.shield_t -= dt
		if s.shield_t <= 0.0:
			s.shield = true
			_event({"type": "shield_up", "id": s.id, "pos": s.pos})
	if s.depth_t > 0.0:
		s.depth_t -= dt
		if s.depth_t <= 0.0:
			s.depth = s.depth_to
			_event({"type": "depth", "id": s.id, "depth": s.depth, "pos": s.pos})
	if s.kind == "sub":
		if s.depth == 2:
			s.air -= dt / TubShip.AIR_TIME
			if s.air <= 0.0:
				s.air = 0.0
				set_depth(s, 1)
				_event({"type": "air", "id": s.id, "pos": s.pos})
		else:
			s.air = minf(s.air + dt / TubShip.AIR_REFILL, 1.0)


func _move(s: TubShip, dt: float) -> void:
	var top := s.top_speed()
	var charging := float(s.ai.get("charge", 0.0)) > 0.0
	if charging:
		top *= 2.2
	var want := clampf(s.throttle, -0.5, 1.0) * top
	if not s.is_player and charging:
		want = top
	# Soft cloth slows anything that is not deep under it.
	if s.depth < 2 and under_cloth(s.pos):
		want *= 0.5
	var accel := 260.0 if want > s.speed else 340.0
	s.speed = move_toward(s.speed, want, accel * dt)
	var grip := 0.35 + 0.65 * minf(absf(s.speed) / maxf(top * 0.6, 1.0), 1.0)
	s.heading = wrapf(s.heading + s.rudder * s.turn_rate() * grip * dt * signf(s.speed if absf(s.speed) > 5.0 else 1.0), -PI, PI)
	# Currents: the drain pulls, the faucet pushes.
	var to_drain := DRAIN - s.pos
	var dd := to_drain.length()
	if dd < DRAIN_R:
		s.push += to_drain.normalized() * (1.0 - dd / DRAIN_R) * 90.0 * dt
	if faucet_on and s.pos.x < FAUCET_X + 420.0 and absf(s.pos.y) < 110.0:
		s.push += Vector2(160.0, 0.0) * dt
	s.push = s.push.move_toward(Vector2.ZERO, 60.0 * dt)
	s.pos += (s.forward() * s.speed + s.push) * dt
	_resolve_static(s)
	if s.lifting > 0.0 or (s.is_player and retreat_hold > 0.0):
		s.speed = move_toward(s.speed, 0.0, 300.0 * dt)


## Keep a toy inside the tub and out of the soap.
func _resolve_static(s: TubShip) -> void:
	var r := s.radius()
	var d := tub_sdf(s.pos) + r
	if d > 0.0:
		var n := _grad(tub_sdf, s.pos)
		s.pos -= n * d
		var hit := s.speed
		s.speed *= 0.4
		if absf(hit) > 140.0:
			_bump(s, absf(hit))
	for o in obstacles:
		if not blocks(o, s.depth):
			continue
		var od := box_sdf(o, s.pos) - r
		if od < 0.0:
			var n2 := _grad(func(p: Vector2) -> float: return box_sdf(o, p), s.pos)
			s.pos -= n2 * od
			var hit2 := s.speed
			s.speed *= 0.4
			if absf(hit2) > 140.0:
				_bump(s, absf(hit2))


func _bump(s: TubShip, v: float) -> void:
	_damage(s, v / 40.0, "", "bump")
	_event({"type": "thud", "pos": s.pos})


func _collide_ships() -> void:
	for i in ships.size():
		var a := ships[i]
		if not a.active() or a.depth >= 2:
			continue
		for j in range(i + 1, ships.size()):
			var b := ships[j]
			if not b.active() or b.depth >= 2:
				continue
			var gap := a.pos.distance_to(b.pos) - a.radius() - b.radius()
			if gap >= 0.0:
				continue
			var n := (b.pos - a.pos).normalized() if a.pos != b.pos else Vector2.RIGHT
			a.pos += n * gap * 0.5
			b.pos -= n * gap * 0.5
			var rel := (a.velocity() - b.velocity()).dot(n)
			if rel > 100.0:
				var ram_a := float(a.ai.get("charge", 0.0)) > 0.0
				var ram_b := float(b.ai.get("charge", 0.0)) > 0.0
				_damage(b, rel / 16.0 + (RAM_DMG if ram_a else 0.0), a.id, "ram")
				_damage(a, rel / 16.0 + (RAM_DMG if ram_b else 0.0), b.id, "ram")
				b.push += n * 160.0
				a.push -= n * 160.0
				_event({"type": "ram", "pos": (a.pos + b.pos) * 0.5})
				a.ai["charge"] = 0.0
				b.ai["charge"] = 0.0
			a.speed *= 0.6
			b.speed *= 0.6


# --- the player -----------------------------------------------------------------

func player_fire() -> bool:
	var s := player
	if not s.can_fire():
		if s.active() and s.depth == 2:
			_event({"type": "cant_fire", "why": "too deep"})
		elif s.active() and s.ammo <= 0:
			_event({"type": "cant_fire", "why": "no torpedoes"})
		return false
	s.ammo -= 1
	s.reload = s.reload_time()
	var side := s.forward().orthogonal() * (6.0 if s.ammo % 2 == 0 else -6.0)
	var p := s.pos + s.forward() * (s.radius() + 10.0) + side
	torps.append({"pos": p, "vel": s.forward() * (SUB_TORP["speed"] + maxf(s.speed, 0.0) * 0.5), "owner": s.id,
		"life": SUB_TORP["life"], "dmg": SUB_TORP["dmg"], "trail": 0.0})
	_event({"type": "launch", "pos": p, "id": s.id})
	return true


func set_depth(s: TubShip, to: int) -> void:
	to = clampi(to, 0, 2) if s.kind == "sub" else 0
	if to == s.depth or s.depth_t > 0.0:
		return
	if to == 2 and s.air < 0.2:
		_event({"type": "cant_dive", "id": s.id})
		return
	s.depth_to = to
	s.depth_t = TubShip.DEPTH_CHANGE
	_event({"type": "diving" if to > s.depth else "rising", "id": s.id, "pos": s.pos})


func player_decoy() -> bool:
	if player.decoys <= 0 or not player.active():
		return false
	player.decoys -= 1
	decoys.append({"pos": player.pos - player.forward() * 30.0, "life": 7.0})
	_event({"type": "decoy", "pos": player.pos})
	return true


## Holding X against the rim: the hand lifts the sub out (a withdrawal).
func player_retreat(dt: float, holding: bool) -> void:
	if holding and tub_sdf(player.pos) > -(player.radius() + 30.0) and player.depth == 0:
		retreat_hold += dt
		if retreat_hold >= 2.0:
			player.state = "retreated"
			_event({"type": "lifted", "id": "player", "pos": player.pos})
	else:
		retreat_hold = 0.0


# --- weapons ---------------------------------------------------------------------

func _step_torps(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for t in torps:
		t["life"] = float(t["life"]) - dt
		var p: Vector2 = (t["pos"] as Vector2) + (t["vel"] as Vector2) * dt
		t["pos"] = p
		var gone := float(t["life"]) <= 0.0
		if tub_sdf(p) > -4.0:
			gone = true
			_event({"type": "splash", "pos": p})
		for o in obstacles:
			if not gone and blocks(o, 0) and box_sdf(o, p) < 0.0:
				gone = true
				_event({"type": "splash", "pos": p, "on": String(o["kind"])})
		for d in decoys:
			if not gone and p.distance_to(d["pos"]) < 18.0 and String(t["owner"]) != "player":
				gone = true
				d["life"] = 0.0
				_event({"type": "pop", "pos": p})
		for s in ships:
			if gone or not s.active() or s.id == String(t["owner"]) or s.depth >= 2:
				continue
			if p.distance_to(s.pos) < s.radius() + 4.0:
				gone = true
				_damage(s, float(t["dmg"]), String(t["owner"]), "torpedo")
				_event({"type": "boom", "pos": p, "big": true})
		if not gone:
			keep.append(t)
	torps = keep


func _step_pellets(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for b in pellets:
		b["life"] = float(b["life"]) - dt
		var p: Vector2 = (b["pos"] as Vector2) + (b["vel"] as Vector2) * dt
		b["pos"] = p
		var gone := float(b["life"]) <= 0.0 or tub_sdf(p) > 0.0
		for o in obstacles:
			if not gone and blocks(o, 0) and box_sdf(o, p) < 0.0:
				gone = true
		for s in ships:
			if gone or not s.active() or s.id == String(b["owner"]) or s.depth != 0:
				continue
			if p.distance_to(s.pos) < s.radius():
				gone = true
				_damage(s, float(b["dmg"]), String(b["owner"]), "pellet")
				_event({"type": "plink", "pos": p})
		if not gone:
			keep.append(b)
		elif float(b["life"]) <= 0.0:
			_event({"type": "plop", "pos": p})
	pellets = keep


func _step_charges(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for ch in charges:
		ch["fuse"] = float(ch["fuse"]) - dt
		if float(ch["fuse"]) > 0.0:
			keep.append(ch)
			continue
		var p: Vector2 = ch["pos"]
		_event({"type": "depth_boom", "pos": p})
		for s in ships:
			if not s.active() or s.depth == 0 or s.id == String(ch["owner"]):
				continue
			var d := p.distance_to(s.pos)
			if d < CHARGE["r"] + s.radius() * 0.5:
				var full: float = CHARGE["deep"] if s.depth == 2 else CHARGE["scope"]
				_damage(s, full * (1.0 - 0.5 * d / CHARGE["r"]), String(ch["owner"]), "charge")
				s.push += (s.pos - p).normalized() * 140.0
		for d2 in decoys:
			if p.distance_to(d2["pos"]) < CHARGE["r"]:
				d2["life"] = 0.0
	charges = keep


func _step_waves(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for w in waves:
		w["r"] = float(w["r"]) + SQUEAK["grow"] * dt
		var done: Dictionary = w["done"]
		for s in ships:
			if not s.active() or s.depth >= 2 or s.id == String(w["owner"]) or done.has(s.id):
				continue
			var d := s.pos.distance_to(w["pos"])
			if absf(d - float(w["r"])) < 30.0 + s.radius() * 0.5:
				done[s.id] = true
				_damage(s, SQUEAK["dmg"], String(w["owner"]), "squeak")
				s.push += (s.pos - (w["pos"] as Vector2)).normalized() * 220.0
		if float(w["r"]) < SQUEAK["r"]:
			keep.append(w)
	waves = keep


func _step_pickups(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for pk in pickups:
		pk["t"] = float(pk["t"]) + dt
		var p: Vector2 = pk["pos"]
		var to := DRAIN - p
		if to.length() < DRAIN_R:
			p += to.normalized() * (1.0 - to.length() / DRAIN_R) * 45.0 * dt
			pk["pos"] = p
		if p.distance_to(DRAIN) < 28.0:
			_event({"type": "drain", "pos": p, "amount": int(pk["amount"])})
			continue
		var taken := false
		for s in ships:
			if s.active() and s.depth < 2 and p.distance_to(s.pos) < s.radius() + 18.0:
				taken = true
				var a := int(pk["amount"])
				s.candy_got += a
				ledger[s.id] = int(ledger.get(s.id, 0)) + a
				_event({"type": "candy", "pos": p, "id": s.id, "amount": a})
				break
		if not taken:
			keep.append(pk)
	pickups = keep


# --- damage ----------------------------------------------------------------------

func _damage(s: TubShip, amount: float, by: String, how: String) -> void:
	if not s.active() or amount <= 0.0:
		return
	if s.shield and how != "bump":
		s.shield = false
		s.shield_t = 20.0
		_event({"type": "shield_pop", "id": s.id, "pos": s.pos})
		return
	s.hull -= amount
	s.hit_flash = 0.25
	if how != "bump":
		var k: String = TubData.COMPONENTS[rng.randi() % TubData.COMPONENTS.size()]
		s.comp[k] = maxf(float(s.comp[k]) - amount / 80.0, 0.0)
	var a := _ship(by)
	if a and a != s:
		var key := by + ">" + s.id
		dmg_by[key] = float(dmg_by.get(key, 0.0)) + amount
		a.hits += 1
		a.dmg_dealt += amount
		s.last_attacker = by
		s.last_attacker_t = time
		if s.is_player and not a.is_player:
			_say(a, "hit_player", 0.35)
		elif a.is_player and not s.is_player:
			_say(s, "hurt", 0.3)
	_event({"type": "hit", "id": s.id, "by": by, "how": how, "pos": s.pos, "amount": amount})
	if s.hull <= 0.0:
		_sink(s, a)


func _sink(s: TubShip, by: TubShip) -> void:
	s.hull = 0.0
	s.state = "sunk"
	s.speed = 0.0
	if by and by != s:
		by.sinks += 1
		sunk_by[s.id] = by.id
	# Did the player just save someone from this ship?
	if by and by.is_player:
		for o in ships:
			if o != s and not o.is_player and o.last_attacker == s.id and time - o.last_attacker_t < 12.0 and not helped.has(o.id):
				helped.append(o.id)
	if not s.is_player:
		_say(s, "sunk", 1.0)
	# Some of the captain's own candy spills into the water.
	var purse := int(purses.get(s.id, 0)) + int(ledger.get(s.id, 0))
	var spill := mini(maxi(purse, 0), TubData.SPILL_BASE + int(round(float(maxi(purse, 0)) * TubData.SPILL_SHARE)))
	if spill > 0:
		ledger[s.id] = int(ledger.get(s.id, 0)) - spill
		var parts := 3
		for i in parts:
			var amt := spill / parts + (spill % parts if i == 0 else 0)
			if amt <= 0:
				continue
			var off := Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-50.0, 50.0))
			var pp := s.pos + off
			if tub_sdf(pp) > -30.0:
				pp = s.pos
			pickups.append({"pos": pp, "amount": amt, "t": 0.0})
	_event({"type": "sunk", "id": s.id, "by": by.id if by else "", "pos": s.pos, "spill": spill})


func _ship(id_v: String) -> TubShip:
	for s in ships:
		if s.id == id_v:
			return s
	return null


func _check_end() -> void:
	if sandbox:
		return
	if not player.active():
		over = true
		result = "defeat" if player.state == "sunk" else "withdrew"
	elif ships.filter(func(s: TubShip) -> bool: return not s.is_player and s.active()).is_empty():
		if cleared_t < 0.0:
			cleared_t = time
			_event({"type": "cleared", "candy": not pickups.is_empty()})
		if pickups.is_empty() or time - cleared_t > GRAB_TIME:
			over = true
			result = "victory"
	elif time >= limit:
		over = true
		result = "draw"
	if over:
		_event({"type": "over", "result": result})
		for s in ships:
			if s.active() and not s.is_player and result != "victory":
				_say(s, "win_battle", 0.6 if result == "defeat" else 0.0)


func _event(e: Dictionary) -> void:
	events.append(e)


func take_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


## A captain says something (not too often).
func _say(s: TubShip, key: String, chance: float) -> void:
	if rng.randf() > chance:
		return
	if time - float(_say_t.get(s.id, -99.0)) < 5.0 and key not in ["sunk", "retreat"]:
		return
	_say_t[s.id] = time
	_event({"type": "say", "id": s.id, "key": key})


# --- the rivals' minds -----------------------------------------------------------

func _ai(s: TubShip, dt: float) -> void:
	var ai := s.ai
	for k in ["think", "cool", "dc", "ping", "squeak", "charge", "charge_cool", "wander_t"]:
		ai[k] = float(ai[k]) - dt
	if s.lifting > 0.0 or s.hull_frac() < float(s.style.get("retreat_at", 0.2)) and String(ai.get("mode", "")) != "retreat":
		if String(ai.get("mode", "")) != "retreat":
			ai["mode"] = "retreat"
			_say(s, "retreat", 1.0)
	var seen: Dictionary = ai["seen"]
	for o in ships:
		if o != s and can_see(s, o):
			seen[o.id] = {"pos": o.pos, "t": time, "depth": o.depth}
	if float(ai["think"]) <= 0.0:
		ai["think"] = 0.5
		ai["target"] = _choose_target(s)
	var goal := s.pos
	var throttle := 1.0
	var tgt: TubShip = _ship(String(ai["target"]))
	var decoy_t := String(ai["target"]) == "decoy"
	var t_pos := Vector2.ZERO
	var know := false
	if decoy_t and not decoys.is_empty():
		t_pos = decoys[0]["pos"]
		know = true
	elif tgt and seen.has(tgt.id) and time - float((seen[tgt.id] as Dictionary)["t"]) < 6.0:
		t_pos = (seen[tgt.id] as Dictionary)["pos"]
		know = true
	if String(ai.get("mode", "")) == "retreat":
		# Head for the nearest rim and wait for the hand.
		var out := s.pos.normalized() if s.pos.length() > 1.0 else Vector2.RIGHT
		if absf(s.pos.x) / HALF.x > absf(s.pos.y) / HALF.y:
			out = Vector2(signf(s.pos.x), 0.0)
		else:
			out = Vector2(0.0, signf(s.pos.y) if s.pos.y != 0.0 else 1.0)
		goal = s.pos + out * 200.0
		if tub_sdf(s.pos) > -(s.radius() + 25.0):
			s.lifting += dt
			throttle = 0.0
			if s.lifting > 1.5:
				s.state = "retreated"
				_event({"type": "lifted", "id": s.id, "pos": s.pos})
				return
	elif know:
		var d := s.pos.distance_to(t_pos)
		var caution := float(s.style.get("caution", 0.5))
		var want: float = {"patrol": 260.0 + 140.0 * caution, "destroyer": 500.0 + 120.0 * caution, "duck": 200.0}[s.kind]
		if d > want + 70.0:
			goal = t_pos
		elif d < want - 70.0:
			goal = s.pos + (s.pos - t_pos).normalized() * 200.0
		else:
			var tan := (t_pos - s.pos).normalized().orthogonal() * float(ai["orbit"])
			goal = s.pos + tan * 200.0
			throttle = 0.75
		_weapons(s, tgt, t_pos, d, decoy_t)
	else:
		# Candy in the water? The greedy go for it.
		var best := {}
		for pk in pickups:
			if s.pos.distance_to(pk["pos"]) < 420.0 * (0.5 + float(ai["greed"])):
				best = pk
		if not best.is_empty() and float(ai["greed"]) > 0.3:
			goal = best["pos"]
		else:
			if float(ai["wander_t"]) <= 0.0 or s.pos.distance_to(ai["wander"]) < 80.0:
				ai["wander"] = Vector2(rng.randf_range(-600.0, 600.0), rng.randf_range(-280.0, 280.0))
				ai["wander_t"] = 6.0
			goal = ai["wander"]
			throttle = 0.6
	if float(ai["charge"]) > 0.0 and know:
		goal = t_pos
	_steer(s, goal, throttle)


func _choose_target(s: TubShip) -> String:
	var seen: Dictionary = s.ai["seen"]
	var rel: Dictionary = relations.get(s.id, {})
	var best := ""
	var best_w := 0.0
	for o in ships:
		if o == s or not o.active() or not seen.has(o.id) or time - float((seen[o.id] as Dictionary)["t"]) > 6.0:
			continue
		var w := 0.0
		if o.is_player:
			w = 1.5 + float(rel.get("player", 0.0)) / 50.0
		else:
			w = 0.25 + maxf(float(rel.get(o.id, 0.0)), 0.0) / 50.0
		# Whoever just hit me becomes interesting.
		if s.last_attacker == o.id and time - s.last_attacker_t < 10.0:
			w += 1.0
		w /= 1.0 + s.pos.distance_to(o.pos) / 700.0
		if w > best_w:
			best_w = w
			best = o.id
	for d in decoys:
		if s.pos.distance_to(d["pos"]) < 650.0 and 3.0 > best_w:
			best = "decoy"
			best_w = 3.0
	return best


## Steer toward a point, nudged away from soap, sponges and the rim.
func _steer(s: TubShip, goal: Vector2, throttle: float) -> void:
	var want := (goal - s.pos)
	want = want.normalized() if want.length() > 1.0 else s.forward()
	var avoid := Vector2.ZERO
	var look := s.pos + s.forward() * 60.0
	for o in obstacles:
		if not blocks(o, s.depth):
			continue
		var d := box_sdf(o, look) - s.radius()
		if d < 110.0:
			avoid -= _grad(func(p: Vector2) -> float: return box_sdf(o, p), look) * (110.0 - d) / 110.0 * 1.6
	var wd := -(tub_sdf(look) + s.radius())
	if wd < 120.0:
		avoid -= _grad(tub_sdf, look) * (120.0 - wd) / 120.0 * 1.6
	var dir := (want + avoid).normalized()
	var err := wrapf(dir.angle() - s.heading, -PI, PI)
	s.rudder = clampf(err * 2.2, -1.0, 1.0)
	s.throttle = throttle * (0.55 if absf(err) > 1.6 else 1.0)
	if s.kind == "duck" and float(s.ai["charge"]) <= 0.0:
		# A duck waddles.
		s.rudder = clampf(s.rudder + sin(time * 3.2 + s.pos.x * 0.01) * 0.35, -1.0, 1.0)


func _lead(from: Vector2, t_pos: Vector2, tgt: TubShip, speed: float) -> Vector2:
	if tgt == null:
		return t_pos
	var v := tgt.velocity()
	var t := from.distance_to(t_pos) / speed
	return t_pos + v * t


func _weapons(s: TubShip, tgt: TubShip, t_pos: Vector2, d: float, decoy_t: bool) -> void:
	var ai := s.ai
	var t_depth := 0 if decoy_t else (tgt.depth if tgt else 0)
	var aggression := float(s.style.get("aggression", 0.5))
	var wfac := 1.0 / (0.35 + 0.65 * s.c("weapons")) * (0.6 if s.has("launcher") else 1.0)
	match s.kind:
		"patrol":
			if t_depth == 0 and d < 480.0 and float(ai["cool"]) <= 0.0:
				ai["cool"] = 0.9 * wfac / (0.7 + aggression * 0.6)
				var aim := _lead(s.pos, t_pos, tgt, PELLET["speed"])
				var dir := (aim - s.pos).normalized().rotated(rng.randf_range(-0.06, 0.06))
				pellets.append({"pos": s.pos + dir * (s.radius() + 4.0), "vel": dir * PELLET["speed"], "owner": s.id, "life": PELLET["life"], "dmg": PELLET["dmg"]})
				_event({"type": "pew", "pos": s.pos, "id": s.id})
			if t_depth >= 1 and d < 85.0 and float(ai["dc"]) <= 0.0:
				ai["dc"] = 3.5 * wfac
				charges.append({"pos": s.pos - s.forward() * 20.0, "fuse": CHARGE["fuse"], "owner": s.id})
				_event({"type": "charge", "pos": s.pos})
		"destroyer":
			if float(ai["ping"]) <= 0.0:
				ai["ping"] = 9.0
				_event({"type": "ping", "pos": s.pos, "id": s.id})
				for o in ships:
					if o != s and o.active() and o.depth >= 1 and o.pos.distance_to(s.pos) < 480.0:
						o.revealed_t = 4.0
			if t_depth < 2 and d < 950.0 and float(ai["cool"]) <= 0.0:
				ai["cool"] = 7.5 * wfac / (0.75 + aggression * 0.5)
				var aim2 := _lead(s.pos, t_pos, tgt, SHIP_TORP["speed"])
				var base := (aim2 - s.pos).normalized()
				for k in [-1, 0, 1]:
					var dir2 := base.rotated(deg_to_rad(10.0) * k)
					torps.append({"pos": s.pos + dir2 * (s.radius() + 8.0), "vel": dir2 * SHIP_TORP["speed"], "owner": s.id,
						"life": SHIP_TORP["life"], "dmg": SHIP_TORP["dmg"], "trail": 0.0})
				_event({"type": "launch", "pos": s.pos, "id": s.id})
			if t_depth >= 1 and d < 110.0 and float(ai["dc"]) <= 0.0:
				ai["dc"] = 5.0 * wfac
				for side in [-1.0, 1.0]:
					charges.append({"pos": s.pos - s.forward() * 24.0 + s.forward().orthogonal() * 30.0 * side, "fuse": CHARGE["fuse"], "owner": s.id})
				_event({"type": "charge", "pos": s.pos})
		"duck":
			if t_depth < 2 and d < 380.0 and float(ai["charge_cool"]) <= 0.0:
				ai["charge"] = 1.4
				ai["charge_cool"] = 5.0 / (0.7 + aggression * 0.6)
				_event({"type": "quack", "pos": s.pos, "id": s.id})
			if d < 260.0 and float(ai["squeak"]) <= 0.0:
				ai["squeak"] = 6.5 * wfac
				waves.append({"pos": s.pos, "r": s.radius(), "owner": s.id, "done": {}})
				_event({"type": "squeak", "pos": s.pos, "id": s.id})


# --- results ---------------------------------------------------------------------

## What everyone earned, by the rules in TubData.REWARD.
func earnings() -> Dictionary:
	var out := {}
	for s in ships:
		var e := {"hits": s.hits * int(TubData.REWARD["hit"]), "sinks": s.sinks * int(TubData.REWARD["sink"]), "candy_water": int(ledger.get(s.id, 0)),
			"survive": int(TubData.REWARD["survive"]) if s.state != "sunk" else 0, "salvage": int(TubData.REWARD["salvage"]) if s.state == "sunk" else 0,
			"victory": 0}
		if s.is_player and result == "victory":
			e["victory"] = int(TubData.REWARD["victory"])
		if not s.is_player and result == "defeat" and s.active():
			e["victory"] = int(TubData.REWARD["victory"]) / 2
		var total := 0
		for k in e.keys():
			total += int(e[k])
		e["total"] = total
		out[s.id] = e
	return out
