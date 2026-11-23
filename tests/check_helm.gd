extends SceneTree
## Practical check of the helm (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_helm.gd
## How quickly the boat answers a course order, how she settles on the new
## heading, how fast she can turn at different speeds (heavy, not arcade),
## and that time compression does not change any of it.

var main: Node
var frame := 0
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		main.call("_begin_patrol")
	if frame < 6:
		return false
	_run()
	print("HELM CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	return true


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _reset(kts: float) -> Submarine:
	var sub: Submarine = main.sub
	sub.position = Vector3(60000.0, -60.0, 150000.0)
	sub.depth = 60.0
	sub.set_target_depth(60.0)
	sub.heading = 0.0
	sub.ordered_heading = 0.0
	sub.helm_auto = true
	sub.rudder_angle = 0.0
	sub.rudder_order = 0.0
	sub.yaw_rate = 0.0
	var step: int = Submarine.SPEED_STEPS.find(kts)
	sub.set_speed_step(maxi(step, 0))
	sub.speed = kts * Submarine.KNOT
	return sub


## Order a course change and watch: response time, settle time, overshoot.
func _turn(kts: float, change: float, dt: float) -> Dictionary:
	var sub := _reset(kts)
	sub.ordered_heading = deg_to_rad(change)
	var t := 0.0
	var first := -1.0
	var settled := -1.0
	var peak := 0.0
	var max_rate := 0.0
	while t < 300.0:
		sub.advance(dt)
		t += dt
		var hd := rad_to_deg(wrapf(sub.heading, -PI, PI))
		var rate := absf(rad_to_deg(sub.yaw_rate))
		max_rate = maxf(max_rate, rate)
		if first < 0.0 and rate >= 0.3:
			first = t
		peak = maxf(peak, hd * signf(change))
		if settled < 0.0 and absf(hd - change) < 1.0 and rate < 0.1:
			settled = t
		if settled > 0.0 and t > settled + 30.0:
			break
	return {"first": first, "settled": settled, "overshoot": maxf(peak - absf(change), 0.0), "max_rate": max_rate}


func _run() -> void:
	print("answering the helm")
	var a := _turn(9.0, 10.0, 0.1)
	_ok(a["first"] > 0.0 and float(a["first"]) < 4.5, "a 10° order at 9 kt: the swing is clear within %.1f s" % float(a["first"]))
	_ok(a["settled"] > 0.0 and float(a["settled"]) < 30.0, "and she is steady on the new course in %.0f s" % float(a["settled"]))
	_ok(float(a["overshoot"]) < 2.0, "overshoot %.1f°" % float(a["overshoot"]))
	var b := _turn(9.0, 90.0, 0.1)
	_ok(b["settled"] > 0.0 and float(b["settled"]) < 100.0, "a 90° turn at 9 kt takes %.0f s" % float(b["settled"]))
	_ok(float(b["overshoot"]) < 3.0, "overshoot %.1f°" % float(b["overshoot"]))
	var c := _turn(9.0, -45.0, 0.1)
	_ok(c["settled"] > 0.0 and float(c["overshoot"]) < 3.0, "turns to port the same way (%.0f s)" % float(c["settled"]))

	print("a heavy boat, not an arcade one")
	var slow := _turn(3.0, 180.0, 0.1)
	var mid := _turn(9.0, 180.0, 0.1)
	var fast := _turn(18.0, 180.0, 0.1)
	_ok(float(slow["max_rate"]) < 0.8, "at 3 kt at most %.2f°/s" % float(slow["max_rate"]))
	_ok(float(mid["max_rate"]) > 1.0 and float(mid["max_rate"]) < 1.8, "at 9 kt about %.2f°/s" % float(mid["max_rate"]))
	_ok(float(fast["max_rate"]) > float(mid["max_rate"]) and float(fast["max_rate"]) < 3.5, "at 18 kt about %.2f°/s" % float(fast["max_rate"]))
	var sub := _reset(0.0)
	sub.ordered_heading = deg_to_rad(90.0)
	for _i in 300:
		sub.advance(0.1)
	_ok(absf(rad_to_deg(sub.heading)) < 1.0, "stopped in the water she hardly answers the rudder")

	print("time compression changes nothing")
	var d1 := _turn(9.0, 60.0, 0.1)
	var d2 := _turn(9.0, 60.0, 1.0)
	_ok(absf(float(d1["settled"]) - float(d2["settled"])) < 3.0 and absf(float(d1["overshoot"]) - float(d2["overshoot"])) < 0.5,
		"a 60° turn: %.0f s at fine steps, %.0f s at one-second steps" % [float(d1["settled"]), float(d2["settled"])])

	print("the helm is visible")
	sub = _reset(9.0)
	sub.ordered_heading = deg_to_rad(40.0)
	for _i in 60:
		sub.advance(0.1)
	var txt := sub.helm_text()
	_ok(txt.contains("RIGHT") and txt.contains("TURNING"), "conn shows the rudder and the swing: " + txt)

	_reset(9.0)
