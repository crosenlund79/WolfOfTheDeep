class_name TubShip
extends RefCounted
## One toy in the bath during a battle: the player's submarine or a rival's
## vessel. Plain state plus the numbers derived from equipment and damage;
## TubBattle moves it and decides what happens to it.

const DEPTH_SPEED := [1.0, 0.8, 0.6]      # surface, periscope, deep
const DEPTH_CHANGE := 0.7                 # seconds to change depth
const AIR_TIME := 25.0                    # seconds of air when deep
const AIR_REFILL := 8.0

var id := ""
var name := ""
var kind := "sub"
var is_player := false
var livery := Color.WHITE
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0                    # px/s along the heading (negative astern)
var push := Vector2.ZERO            # currents and knocks, decaying
var throttle := 0.0                 # -0.5 .. 1
var rudder := 0.0                   # -1 .. 1
var hull := 100.0
var max_hull := 100
var comp := {}
var upgrades: Array = []
var depth := 0                      # 0 surface, 1 periscope, 2 deep
var depth_to := 0
var depth_t := 0.0                  # > 0 while changing depth
var air := 1.0
var ammo := 0
var reload := 0.0
var shield := false
var shield_t := 0.0
var decoys := 0
var state := "active"               # active, sunk, retreated
var style := {}                     # rivals: aggression, caution, retreat_at
var ai := {}
var revealed_t := 0.0               # pinged by a destroyer: seen for a while
var lifting := 0.0                  # being lifted out of the bath (retreat)
var hit_flash := 0.0
var last_attacker := ""
var last_attacker_t := -99.0
var hits := 0
var sinks := 0
var dmg_dealt := 0.0
var candy_got := 0
var sink_t := 0.0                   # time since it went down (for the view)


func setup(state_d: Dictionary, id_v: String, name_v: String, player: bool) -> void:
	id = id_v
	name = name_v
	is_player = player
	kind = String(state_d["kind"])
	max_hull = int(state_d["max_hull"])
	hull = float(state_d["hull"])
	comp = (state_d["comp"] as Dictionary).duplicate()
	upgrades = (state_d["upgrades"] as Array).duplicate()
	shield = has("shield")
	if is_player:
		ammo = 8 + (4 if has("racks") else 0)
		decoys = 2 if has("decoy") else 0


func has(up: String) -> bool:
	return upgrades.has(up)


func radius() -> float:
	return float(TubData.KINDS[kind]["radius"])


func forward() -> Vector2:
	return Vector2.RIGHT.rotated(heading)


func velocity() -> Vector2:
	return forward() * speed + push


func active() -> bool:
	return state == "active"


func c(k: String) -> float:
	return float(comp.get(k, 1.0))


func top_speed() -> float:
	var v := float(TubData.KINDS[kind]["speed"]) * (1.15 if has("propeller") else 1.0)
	v *= 0.45 + 0.55 * c("propulsion")
	return v * (DEPTH_SPEED[depth] if kind == "sub" else 1.0)


func turn_rate() -> float:
	return float(TubData.KINDS[kind]["turn"]) * (1.25 if has("rudder") else 1.0) * (0.4 + 0.6 * c("steering"))


## Seconds between shots of the main weapon.
func reload_time() -> float:
	var base: float = {"sub": 1.6, "patrol": 0.9, "destroyer": 7.5, "duck": 6.5}[kind]
	if has("launcher"):
		base *= 0.6
	return base / (0.35 + 0.65 * c("weapons"))


## How far they spot a toy on the surface in clear water.
func sight() -> float:
	return 950.0 * (1.4 if has("periscope") else 1.0) * (0.5 + 0.5 * c("sensors"))


func can_fire() -> bool:
	return active() and depth < 2 and depth_t <= 0.0 and reload <= 0.0 and (ammo > 0 or not is_player)


func hull_frac() -> float:
	return hull / maxf(float(max_hull), 1.0)


## The ship's state to carry back into the career after the battle.
func state_dict() -> Dictionary:
	return {"kind": kind, "hull": maxf(hull, 0.0), "max_hull": max_hull, "comp": comp.duplicate(), "upgrades": upgrades.duplicate()}
