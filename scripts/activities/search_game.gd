class_name SearchGame
extends Activity
## Jeu de recherche : des objets sont cachés ; le joueur désigne une cachette,
## l'animal la renifle et indique « chaud / froid » selon son flair.

var comp := false
var lvl_idx := 0
var lvl: Dictionary
var spots: Array[Dictionary] = []
var nodes: Array[Node3D] = []
var tries := 0
var found := 0
var busy_sniff := false

func _init(params: Dictionary = {}) -> void:
	comp = bool(params.get("comp", false))
	lvl_idx = int(params.get("level", -1))

func _start() -> void:
	if lvl_idx < 0:
		lvl_idx = int(GameState.data["search_level"])
	lvl_idx = clampi(lvl_idx, 0, GameData.SEARCH_LEVELS.size() - 1)
	lvl = GameData.SEARCH_LEVELS[lvl_idx]
	tries = int(lvl["tries"]) + int(lvl["objects"]) - 1
	make_top("👃 " + tr("Jeu de recherche · niveau %d") % (lvl_idx + 1), not comp)
	_update_info()
	var area: Rect2 = main.env_root.get_meta("spots_area", Rect2(-2.2, -1.9, 4.4, 3.0))
	var n := int(lvl["spots"])
	var cols := 4 if n <= 8 else 4
	var rows := int(ceil(float(n) / cols))
	var idxs: Array = range(n)
	idxs.shuffle()
	var hidden: Array = idxs.slice(0, int(lvl["objects"]))
	for i in n:
		var cx := i % cols
		var cy := i / cols
		var x := lerpf(area.position.x + 0.4, area.end.x - 0.4, (cx + 0.5) / cols) + randf_range(-0.25, 0.25)
		var z := lerpf(area.position.y + 0.3, area.end.y - 0.6, (cy + 0.5) / maxf(1.0, rows)) + randf_range(-0.2, 0.2)
		var pos := Vector3(x, 0, z)
		var node := _make_spot(pos, i)
		spots.append({"pos": pos, "has": hidden.has(i), "checked": false})
		nodes.append(node)
	pet.position = Vector3(0, 0, area.end.y + 0.5)
	pet.bounds = area.grow(1.5)
	pet.state = "action"
	pet.model.set_posture("sit")
	main.cam_rig.target = null
	main.cam_rig.follow = false
	main.cam_rig.focus = Vector3(area.get_center().x, 0.2, area.get_center().y)
	main.cam_rig.reset_view(maxf(area.size.x, area.size.y) * 0.9 + 2.0, -0.75, 0.0)
	big_hint(tr("Touchez une cachette !"), 1.4)

func _make_spot(pos: Vector3, i: int) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	main.world.add_child(n)
	match main.env_id:
		"house":
			var c := Color.from_hsv(fmod(i * 0.17, 1.0), 0.45, 0.95)
			WorldBuilder.box(n, Vector3(0.45, 0.16, 0.45), Vector3(0, 0.08, 0), c)
			WorldBuilder.ball(n, 0.05, Vector3(0, 0.17, 0), c.darkened(0.2))
		"beach":
			WorldBuilder.ball(n, 0.3, Vector3(0, 0.0, 0), Color(0.92, 0.82, 0.6), Vector3(1, 0.45, 1))
		_:
			WorldBuilder.ball(n, 0.28, Vector3(0, 0.18, 0), Color(0.35, 0.62, 0.3).lightened(randf() * 0.15), Vector3(1, 0.8, 1), 10)
			WorldBuilder.ball(n, 0.2, Vector3(0.18, 0.12, 0.05), Color(0.38, 0.66, 0.32), Vector3(1, 0.8, 1), 10)
	WorldBuilder.interactive(n, "spot_%d" % i, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.2, 0))
	return n

func _update_info() -> void:
	info_label.text = tr("Trouvés : %d/%d · Essais restants : %d") % [found, int(lvl["objects"]), tries]

func handle_input(event: InputEvent) -> bool:
	if finished:
		return false
	if event is InputEventScreenTouch and event.index == 0 and not event.pressed:
		if busy_sniff:
			return true
		var hit := main.raycast(event.position, 4)
		var part := main.hit_part(hit)
		if part.begins_with("spot_"):
			_check(int(part.substr(5)))
		return true
	return event is InputEventScreenTouch or event is InputEventScreenDrag

func _check(i: int) -> void:
	if i < 0 or i >= spots.size():
		return
	var sp := spots[i]
	if sp["checked"]:
		big_hint(tr("Déjà fouillé"), 0.6)
		return
	busy_sniff = true
	pet.walk_to(sp["pos"] + Vector3(0, 0, 0.35), 1.4, func(): _sniff(i))

func _sniff(i: int) -> void:
	var sp := spots[i]
	pet.face(sp["pos"])
	pet.model.set_posture("sniff")
	pet.model.sniff = 1.0
	Audio.play("sniff")
	await get_tree().create_timer(1.3, false).timeout
	if finished:
		return
	pet.model.sniff = 0.0
	sp["checked"] = true
	if sp["has"]:
		found += 1
		GameState.inc_stat("found", 1)
		pet.model.set_posture("bow", 6.0)
		pet.model.expression = "happy"
		pet.model.emote("❗")
		pet.voice()
		Audio.play("success", 0.0, -4.0)
		var bone := WorldBuilder.cyl(nodes[i], 0.03, 0.03, 0.26, Vector3(0, 0.3, 0), Color(0.98, 0.95, 0.88), 8, Vector3(0, 0, PI / 2))
		for sx in [-0.13, 0.13]:
			WorldBuilder.ball(bone, 0.045, Vector3(0, sx, 0), Color(0.98, 0.95, 0.88))
		bone.create_tween().tween_property(bone, "position:y", 0.6, 0.6).set_trans(Tween.TRANS_BACK)
		big_hint(tr("Trouvé !"), 0.8, UiKit.C_ACCENT2)
	else:
		tries -= 1
		var d := _nearest_hidden(sp["pos"])
		var nose := float(GameData.breed(GameState.active_pet()["breed"])["stats"]["nose"]) / 100.0
		if randf() < (1.0 - nose) * 0.35:
			d = randf_range(0.5, 4.0)   # flair trompé
		var hint := "❄️"
		var txt := tr("Froid…")
		if d < 1.2:
			hint = "🔥"
			txt = tr("Brûlant !")
			pet.model.wag_amp = 1.0
		elif d < 2.3:
			hint = "♨️"
			txt = tr("Tiède")
			pet.model.wag_amp = 0.5
		else:
			pet.model.wag_amp = 0.1
		pet.model.emote(hint)
		big_hint(hint + " " + txt, 0.8)
		Audio.play("pop", 0.1, -4.0)
		nodes[i].scale = Vector3(1, 0.6, 1)
	_update_info()
	await get_tree().create_timer(0.9, false).timeout
	busy_sniff = false
	pet.model.set_posture("stand")
	if found >= int(lvl["objects"]):
		_finish(true)
	elif tries <= 0:
		_finish(false)

func _nearest_hidden(p: Vector3) -> float:
	var best := INF
	for sp in spots:
		if sp["has"] and not sp["checked"]:
			best = minf(best, p.distance_to(sp["pos"]))
	return best

func _finish(win: bool) -> void:
	finished = true
	var score := float(found) / float(lvl["objects"]) * 70.0 + (float(tries) / float(lvl["tries"])) * 30.0 * (1.0 if win else 0.0)
	GameState.change_need("energy", -6.0)
	GameState.change_need("mood", 6.0 if win else 0.0)
	GameState.add_relation(5)
	if on_done.is_valid():
		on_done.call(clampf(score, 0.0, 100.0))
		return
	var lines: Array = []
	var coins := 0
	if win:
		coins = int(lvl["reward"]) + tries * 5
		lines.append(tr("Bravo ! %s a tout trouvé.") % pet_name())
		if lvl_idx == int(GameState.data["search_level"]) and lvl_idx < GameData.SEARCH_LEVELS.size() - 1:
			GameState.data["search_level"] = lvl_idx + 1
			lines.append(tr("Niveau %d débloqué !") % (lvl_idx + 2))
		Audio.play("success")
	else:
		coins = found * 8
		lines.append(tr("Plus d'essais… %d objet(s) trouvé(s).") % found)
	show_results("👃 " + tr("Recherche"), lines, coins, 15 + found * 5)

func _exit_tree() -> void:
	super._exit_tree()
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
