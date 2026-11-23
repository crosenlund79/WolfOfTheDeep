extends SceneTree
## Practical check of freedom of command and the crew's conscience (no framework):
##   godot --headless --path . --fixed-fps 30 -s tests/check_conduct.gd
## The XO's objection depends on the target; firing on a civilian ship costs
## trust and some refuse to take part (others cover their stations); refusals
## end; worn-out trust becomes a reassignment request. Northern Command
## answers an overdue boat, an ignored recall and a run into foreign waters,
## and turning back is noted. Nothing ends the game. All of it is saved.

var main: Node
var frame := 0
var steps: Array[Callable] = []
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		func() -> void: main.call("_begin_patrol"),
		_check_objection,
		_check_refusal,
		_check_reassignment,
		_check_overdue,
		_check_foreign,
		_check_rooms,
		_check_cup,
		_check_save,
	]


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if steps.is_empty():
		print("CONDUCT CHECK: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		return true
	var s: Callable = steps.pop_front()
	s.call()
	return false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _check_objection() -> void:
	print("the XO's objection")
	var cs: Conscience = main.conscience
	var civ := cs.objection({"civil": true})
	var war := cs.objection({"warship": true})
	_ok(civ.contains("civilian") and civ.contains("object"), "against a civilian ship: a formal objection")
	_ok(war.contains("not at war"), "against a warship in peacetime: a warning")
	_ok(cs.objection({"authorised": true}).contains("released"), "with weapons released: procedure, not protest")


func _check_refusal() -> void:
	print("refusing to take part")
	var cs: Conscience = main.conscience
	var crew: Crew = main.crew
	var t0 := cs.trust("freja")
	var refused := cs.judge("fire", {"civil": true})
	_ok(cs.trust("freja") < t0, "trust in the captain falls (%.2f → %.2f)" % [t0, cs.trust("freja")])
	_ok(refused.has("freja") or refused.has("maya"), "someone with convictions refuses (%s)" % str(refused))
	_ok(not refused.has("miller"), "the XO objects but does not walk off")
	if refused.has("freja"):
		var holder: CrewMember = crew.role_holder("SONAR")
		_ok(holder != null and holder.id != "freja", "her station is covered by %s" % (holder.name if holder else "nobody"))
	var found := false
	for e in main.captain_log.entries:
		if String(e["cat"]) == "CREW" and String(e["text"]).contains("relieved of"):
			found = true
	_ok(found, "the refusal is in the Captain's Log")
	main.clock.seconds += (Conscience.REFUSAL_HOURS + 0.5) * 3600.0
	cs.advance(2.0)
	_ok(crew.members["freja"].available and crew.members["maya"].available, "after a few hours they are back on duty")


func _check_reassignment() -> void:
	print("asking to be reassigned")
	var cs: Conscience = main.conscience
	var crew: Crew = main.crew
	for other in crew.members.values():
		(other as CrewMember).conscience["captain"] = 0.6
	cs.set("_reassign", {})
	var m: CrewMember = crew.members["maya"]
	m.conscience["captain"] = 0.2
	m.awake = true
	crew.alert = 0
	crew.captain_asleep = false
	cs.set("_raise_t", 0.0)
	cs.advance(2.0)
	_ok(cs.reassignment_requests().has("maya"), "worn-out trust becomes a formal request")
	m.conscience["captain"] = 0.6


func _check_overdue() -> void:
	print("overdue, recalled, relieved")
	var st: CommandStanding = main.standing
	var patrol: Patrol = main.patrol
	var sub: Submarine = main.sub
	sub.position = Vector3(5000.0, -60.0, -5000.0)
	main.clock.seconds = patrol.deadline + 2.0 * 3600.0
	st.advance(61.0)
	_ok(st.state == "OVERDUE", "missed rendezvous: overdue")
	var asked := patrol.pending.filter(func(m: Dictionary) -> bool: return String(m["text"]).contains("OVERDUE"))
	_ok(not asked.is_empty(), "Northern Command asks for position and intentions (copied with a mast up)")
	main.clock.seconds += 13.0 * 3600.0
	st.advance(61.0)
	_ok(st.state == "RECALLED", "then recalls the boat")
	main.clock.seconds += 25.0 * 3600.0
	st.advance(61.0)
	_ok(st.state == "RELIEVED", "an ignored recall: the captain is relieved of command")
	_ok(main.started and not main.in_main_menu, "and the game goes on")
	sub.position = Vector3(patrol.rv.x, -60.0, patrol.rv.z)
	st.advance(61.0)
	_ok(st.state == "UNDER QUESTION", "bringing her home is noted (%s)" % st.state.to_lower())


func _check_foreign() -> void:
	print("foreign waters")
	var st: CommandStanding = main.standing
	var patrol: Patrol = main.patrol
	var sub: Submarine = main.sub
	var tr: WorldTraffic = main.traffic
	var alert0 := tr.foreign_alert
	sub.position = Vector3(CommandStanding.FOREIGN_X + 5000.0, -60.0, -20000.0)
	st.advance(61.0)
	main.clock.seconds += 1.5 * 3600.0
	st.advance(61.0)
	var warn := patrol.pending.filter(func(m: Dictionary) -> bool: return String(m["text"]).contains("FOREIGN HOME WATERS"))
	_ok(not warn.is_empty(), "Northern Command orders the boat out")
	main.clock.seconds += 6.0 * 3600.0
	st.advance(61.0)
	_ok(st.state == "BELIEVED DEFECTING", "staying there: believed to be defecting")
	_ok(tr.foreign_alert > alert0, "and the other side takes an interest")
	sub.position = Vector3(100000.0, -60.0, 100000.0)
	st.advance(61.0)
	_ok(st.state == "UNDER QUESTION", "turning back is noted")


func _check_rooms() -> void:
	print("engine room, mess and cabin")
	for pair in [[main.View.ENGINE, "engine"], [main.View.MESS, "mess"], [main.View.CABIN, "cabin"]]:
		main.set_view(pair[0])
		_ok(main.room_panel.visible and main.room_panel.room == String(pair[1]), "%s: its own interface" % String(pair[1]))
	main.set_view(main.View.CONTROL)
	_ok(not main.room_panel.visible, "back in the control room it is gone")


func _check_cup() -> void:
	print("the Mess Cup")
	var crew: Crew = main.crew
	main.crew.alert = 0
	main.clock.seconds = float(int(main.clock.seconds / 86400.0)) * 86400.0 + 20.0 * 3600.0
	crew.advance(0.0)
	main.call("_open_cards", true)
	var table: Node = main.poker
	_ok(table.visible and bool(table.get("tournament")), "the cup table opens")
	var g: PokerGame = table.get("game")
	_ok(g != null and g.players.size() <= 4, "four players at most (%d)" % (g.players.size() if g else 0))
	if g == null or g.players.size() < 2:
		return
	var members: Dictionary = table.get("_members")
	var w: CrewMember = members[1]
	var before_w := w.candy_count()
	var before_c: int = int(crew.captain_candy.get("toffee", 0)) + int(crew.captain_candy.get("chocolate", 0)) + int(crew.captain_candy.get("liquorice", 0))
	for i in g.players.size():
		g.players[i]["stack"] = 0
	g.players[1]["stack"] = PokerTable.CUP_CHIPS * g.players.size()
	table.call("_end", "")
	var after_c: int = int(crew.captain_candy.get("toffee", 0)) + int(crew.captain_candy.get("chocolate", 0)) + int(crew.captain_candy.get("liquorice", 0))
	_ok(w.candy_count() == before_w + PokerTable.CUP_ENTRY * (g.players.size() - 1), "the winner takes the stakes (%d → %d)" % [before_w, w.candy_count()])
	_ok(after_c == before_c - PokerTable.CUP_ENTRY, "the captain paid the entry")
	_ok(not crew.mess_cup.is_empty() and String(crew.mess_cup[-1]["winner"]) == w.short, "the cup is on record: %s" % w.short)


func _check_save() -> void:
	print("saving")
	var st: CommandStanding = main.standing
	var d: Dictionary = main.gather_state("check")
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var hist := st.history.size()
	st.state = "UNDER ORDERS"
	st.history.clear()
	main.apply_state(parsed)
	_ok(st.state == "UNDER QUESTION" and st.history.size() == hist, "standing and its history restored")
	_ok(main.conscience.reassignment_requests().has("maya"), "reassignment requests restored")
	_ok(not main.crew.mess_cup.is_empty(), "the Mess Cup record restored")
