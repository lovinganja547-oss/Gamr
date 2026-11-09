class_name SearchGame
extends Activity
## Cache-cache / recherche : des objets sont cachés dans des cachettes cohérentes avec le lieu.
## Le joueur désigne une cachette, l'animal la renifle ; son flair (bouton « Flair », limité)
## et son comportement (queue qui s'agite près d'un objet) guident le joueur.

var comp := false
var daily := false
var lvl_idx := -1
var lvl: Dictionary
var spots: Array[Dictionary] = []
var nodes: Array[Node3D] = []
var errors_left := 0
var clues_left := 0
var found_items: Array[String] = []
var busy_sniff := false
var clue_busy := false
var started := false
var rng := RandomNumberGenerator.new()
var clue_btn: Button
var glows: Array[Node3D] = []

const PROPS := {
	"house": ["cushion", "box", "basket", "under"],
	"garden": ["bush", "flowerbed", "leaves", "box"],
	"park": ["bush", "leaves", "log", "rock"],
	"forest": ["leaves", "log", "rock", "bush"],
	"beach": ["sand", "rock", "crate"],
	"center": ["tire", "crate", "box"],
}

func _init(params: Dictionary = {}) -> void:
	comp = bool(params.get("comp", false))
	lvl_idx = int(params.get("level", -1))
	daily = bool(params.get("daily", false))

func _start() -> void:
	make_top("[i:search] " + tr("Cache-cache"), not comp)
	pet.state = "action"
	if comp or lvl_idx >= 0:
		_setup()
	else:
		_level_picker()

# ------------------------------------------------------------------ choix du niveau
func _level_picker() -> void:
	info_label.text = tr("Choisissez un niveau de difficulté.")
	var v := UiKit.vbox(10)
	var unlocked := int(GameState.data["search_level"])
	var sd: Dictionary = GameState.data.get("search_daily", {})
	var daily_done: bool = sd.get("day", "") == GameState.today() and sd.get("done", false)
	var dc := UiKit.panel(14, Color(1, 0.95, 0.8))
	var dv := UiKit.vbox(4)
	dv.add_child(UiKit.label("[i:daily_star] " + tr("Défi du jour"), 28))
	dv.add_child(UiKit.label(tr("Cachettes identiques pour tous aujourd'hui, récompense doublée.") if not daily_done else tr("Défi réussi aujourd'hui, revenez demain !"), 21, UiKit.C_SUB))
	var db := UiKit.button(tr("Relever le défi"), func():
		started = true
		main.close_panel()
		daily = true
		lvl_idx = mini(unlocked, 2)
		_setup(), UiKit.C_GOLD, 24, 72)
	db.disabled = daily_done
	dv.add_child(db)
	dc.add_child(dv)
	v.add_child(dc)
	for i in GameData.SEARCH_LEVELS.size():
		var L: Dictionary = GameData.SEARCH_LEVELS[i]
		var ii := i
		var c := UiKit.panel(14, Color(1, 0.97, 0.9))
		var h := UiKit.hbox(8)
		var info := UiKit.vbox(2)
		info.add_child(UiKit.label("%s · %d %s" % [tr(L["name"]), int(L["spots"]), tr("cachettes")], 26))
		info.add_child(UiKit.label(tr("%d objet(s) · %d erreurs permises · flair ×%d") % [int(L["objects"]), int(L["tries"]), int(L["clues"])], 20, UiKit.C_SUB))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var b := UiKit.button(tr("Jouer") if i <= unlocked else tr("Verrouillé"), func():
			started = true
			main.close_panel()
			lvl_idx = ii
			_setup(), UiKit.C_ACCENT2 if i <= unlocked else UiKit.C_DISABLED, 24, 72)
		b.disabled = i > unlocked
		b.custom_minimum_size = Vector2(150, 72)
		h.add_child(b)
		c.add_child(h)
		v.add_child(c)
	main.open_panel("[i:search] " + tr("Cache-cache"), UiKit.scroll(v), func():
		if not started:
			quit())

# ------------------------------------------------------------------ mise en place
func _setup() -> void:
	started = true
	lvl_idx = clampi(lvl_idx, 0, GameData.SEARCH_LEVELS.size() - 1)
	lvl = GameData.SEARCH_LEVELS[lvl_idx]
	errors_left = int(lvl["tries"])
	clues_left = int(lvl["clues"]) + (1 if pet.pet.get("temperament", "") == "curieux" else 0)
	if daily:
		rng.seed = hash(GameState.today() + main.env_id)
	else:
		rng.randomize()
	top_label.text = tr("Cache-cache · %s") % tr(lvl["name"]) + (" · " + tr("Défi du jour") if daily else "")
	var bb := bottom_bar()
	clue_btn = UiKit.button("[i:clue] " + tr("Flair (%d)") % clues_left, _use_clue, UiKit.C_BLUE, 26, 84)
	clue_btn.disabled = clues_left <= 0
	bb.add_child(UiKit.expand(clue_btn))
	var area: Rect2 = main.env_root.get_meta("spots_area", Rect2(-2.2, -1.9, 4.4, 3.0))
	var n := int(lvl["spots"])
	var cols := 2 if n <= 4 else 3
	var rows := int(ceil(float(n) / cols))
	var c0 := area.get_center()
	area = Rect2(c0.x - 1.9, area.position.y, 3.8, minf(area.size.y, 0.9 + rows * 0.9))
	var order: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = order[i]; order[i] = order[j]; order[j] = t
	var hidden: Array = order.slice(0, int(lvl["objects"]))
	var kinds: Array = PROPS.get(main.env_id, PROPS["garden"])
	for i in n:
		var cx := i % cols
		var cy := i / cols
		var x := lerpf(area.position.x + 0.4, area.end.x - 0.4, (cx + 0.5) / cols) + rng.randf_range(-0.25, 0.25)
		var z := lerpf(area.position.y + 0.3, area.end.y - 0.6, (cy + 0.5) / maxf(1.0, rows)) + rng.randf_range(-0.2, 0.2)
		var pos := Vector3(x, 0, z)
		if main.nav:
			var f := main.nav.nearest_free(Vector2(x, z))
			pos = Vector3(f.x, 0, f.y)
		var kind: String = kinds[rng.randi() % kinds.size()]
		var has: bool = hidden.has(i)
		spots.append({"pos": pos, "has": has, "checked": false, "kind": kind, "item": _pick_item() if has else ""})
		nodes.append(_make_spot(pos, i, kind))
	pet.position = Vector3(c0.x, 0, area.end.y + 0.5)
	if main.nav:
		var fp := main.nav.nearest_free(Vector2(pet.position.x, pet.position.z))
		pet.position = Vector3(fp.x, 0, fp.y)
	pet.bounds = area.grow(1.5)
	pet.model.set_posture("sit")
	main.cam_rig.target = null
	main.cam_rig.follow = false
	main.cam_rig.focus = Vector3(area.get_center().x, 0.2, area.get_center().y)
	main.cam_rig.reset_view(6.5 + area.size.y * 0.4, -0.95, 0.0)
	main.cam_rig.screen_shift = 0.1
	_update_info()
	big_hint(tr("Touchez une cachette !"), 1.4)

## Objet caché : objet de collection du lieu (rare possible), jouet ou accessoire.
func _pick_item() -> String:
	var env := main.env_id
	if rng.randf() < float(lvl["rare"]):
		var rares := GameData.collectibles(env, 3)
		if not rares.is_empty():
			return rares[rng.randi() % rares.size()]
	var r := rng.randf()
	if r < 0.08:
		return GameData.SEARCH_ACCESSORIES[rng.randi() % GameData.SEARCH_ACCESSORIES.size()]
	if r < 0.3:
		return GameData.SEARCH_TOYS[rng.randi() % GameData.SEARCH_TOYS.size()]
	var pool: Array = GameData.collectibles(env, 0)
	pool = pool.filter(func(id): return int(GameData.item(id).get("rarity", 1)) < 3)
	if pool.is_empty():
		return "stick"
	return pool[rng.randi() % pool.size()]

func _make_spot(pos: Vector3, i: int, kind: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	main.world.add_child(n)
	match kind:
		"cushion":
			var c := Color.from_hsv(rng.randf(), 0.45, 0.95)
			WorldBuilder.ball(n, 0.26, Vector3(0, 0.08, 0), c, Vector3(1.2, 0.4, 1.2), 12)
			WorldBuilder.ball(n, 0.05, Vector3(0, 0.19, 0), c.darkened(0.2))
		"box":
			WorldBuilder.box(n, Vector3(0.42, 0.3, 0.36), Vector3(0, 0.15, 0), Color(0.78, 0.6, 0.4))
			WorldBuilder.box(n, Vector3(0.44, 0.02, 0.06), Vector3(0, 0.31, 0), Color(0.9, 0.85, 0.7))
		"basket":
			WorldBuilder.torus(n, 0.15, 0.24, Vector3(0, 0.1, 0), Color(0.75, 0.55, 0.32))
			WorldBuilder.cyl(n, 0.2, 0.16, 0.16, Vector3(0, 0.08, 0), Color(0.7, 0.5, 0.3), 14)
		"under":
			WorldBuilder.box(n, Vector3(0.55, 0.04, 0.45), Vector3(0, 0.32, 0), Color(0.62, 0.42, 0.28))
			for sx in [-0.23, 0.23]:
				for sz in [-0.18, 0.18]:
					WorldBuilder.box(n, Vector3(0.04, 0.32, 0.04), Vector3(sx, 0.16, sz), Color(0.55, 0.38, 0.25))
		"bush":
			WorldBuilder.ball(n, 0.28, Vector3(0, 0.18, 0), Color(0.35, 0.62, 0.3).lightened(rng.randf() * 0.15), Vector3(1, 0.8, 1), 10)
			WorldBuilder.ball(n, 0.2, Vector3(0.18, 0.12, 0.05), Color(0.38, 0.66, 0.32), Vector3(1, 0.8, 1), 10)
		"flowerbed":
			WorldBuilder.ball(n, 0.3, Vector3(0, 0.02, 0), Color(0.45, 0.32, 0.22), Vector3(1.2, 0.3, 1.0), 10)
			for k in 5:
				WorldBuilder.ball(n, 0.05, Vector3(cos(k * 1.26) * 0.18, 0.12, sin(k * 1.26) * 0.14), [Color(1, 0.5, 0.6), Color(1, 0.85, 0.3), Color(0.75, 0.55, 1)][k % 3])
		"leaves":
			for k in 7:
				WorldBuilder.ball(n, 0.1, Vector3(rng.randf_range(-0.18, 0.18), 0.05 + k * 0.012, rng.randf_range(-0.15, 0.15)), [Color(0.82, 0.48, 0.2), Color(0.9, 0.68, 0.25), Color(0.65, 0.35, 0.18)][k % 3], Vector3(1.4, 0.35, 1.0), 6)
		"log":
			WorldBuilder.cyl(n, 0.13, 0.13, 0.7, Vector3(0, 0.13, 0), Color(0.5, 0.34, 0.22), 10, Vector3(0, rng.randf() * PI, PI / 2))
		"rock":
			WorldBuilder.ball(n, 0.25, Vector3(0, 0.12, 0), Color(0.6, 0.6, 0.58), Vector3(1.2, 0.75, 1.0), 9)
		"sand":
			WorldBuilder.ball(n, 0.3, Vector3(0, 0.0, 0), Color(0.92, 0.82, 0.6), Vector3(1, 0.45, 1), 10)
		"crate":
			WorldBuilder.box(n, Vector3(0.4, 0.34, 0.4), Vector3(0, 0.17, 0), Color(0.72, 0.55, 0.35))
			for k in 3:
				WorldBuilder.box(n, Vector3(0.42, 0.03, 0.03), Vector3(0, 0.06 + k * 0.12, 0.2), Color(0.55, 0.4, 0.25))
		"tire":
			WorldBuilder.torus(n, 0.12, 0.26, Vector3(0, 0.08, 0), Color(0.22, 0.22, 0.25))
	WorldBuilder.interactive(n, "spot_%d" % i, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.2, 0))
	return n

func _update_info() -> void:
	info_label.text = tr("Trouvés : %d/%d · Erreurs permises : %d") % [found_items.size(), int(lvl["objects"]), errors_left]
	if clue_btn:
		clue_btn.text = tr("Flair (%d)") % clues_left
		clue_btn.disabled = clues_left <= 0 or finished

# ------------------------------------------------------------------ jeu
func handle_input(event: InputEvent) -> bool:
	if finished or not started:
		return false
	if event is InputEventScreenTouch and event.index == 0 and not event.pressed:
		if busy_sniff or clue_busy:
			return true
		var part := main.hit_part(main.raycast(event.position, 4))
		if part.begins_with("spot_"):
			_check(int(part.substr(5)))
		return true
	return event is InputEventScreenTouch or event is InputEventScreenDrag

func _process(_delta: float) -> void:
	if finished or not started or pet == null:
		return
	# Indice de comportement : la queue s'agite près d'un objet caché
	var d := _nearest_hidden(pet.position)
	if not busy_sniff:
		pet.model.wag_amp = lerpf(pet.model.wag_amp, 0.9 if d < 1.0 else (0.45 if d < 1.8 else 0.15), 0.05)

func _check(i: int) -> void:
	if i < 0 or i >= spots.size():
		return
	var sp := spots[i]
	if busy_sniff or clue_busy:
		return
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
	await get_tree().create_timer(1.2, false).timeout
	if finished:
		return
	pet.model.sniff = 0.0
	sp["checked"] = true
	if sp["has"]:
		var id: String = sp["item"]
		found_items.append(id)
		GameState.inc_stat("found", 1)
		pet.model.set_posture("bow", 6.0)
		pet.model.shake = 0.5
		pet.model.expression = "happy"
		pet.model.emote("emo_exclaim")
		pet.voice()
		Audio.play("success", 0.0, -4.0)
		var it := GameData.item(id)
		var spr := Sprite3D.new()
		spr.texture = UiKit.icon(str(it.get("icon", id)))
		spr.pixel_size = 0.0028
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.no_depth_test = true
		spr.position = Vector3(0, 0.3, 0)
		nodes[i].add_child(spr)
		spr.create_tween().tween_property(spr, "position:y", 0.75, 0.6).set_trans(Tween.TRANS_BACK)
		var rare := int(it.get("rarity", 1)) >= 3
		big_hint((tr("Objet rare : %s !") if rare else tr("Trouvé : %s !")) % tr(it.get("name", id)), 1.0, UiKit.C_GOLD if rare else UiKit.C_ACCENT2)
		await get_tree().create_timer(0.5, false).timeout
		pet.model.shake = 0.0
	else:
		errors_left -= 1
		var d := _nearest_hidden(sp["pos"])
		var nose := float(GameData.breed(GameState.active_pet()["breed"])["stats"]["nose"]) / 100.0
		if pet.pet.get("temperament", "") == "curieux":
			nose = minf(1.0, nose + 0.15)
		if rng.randf() < (1.0 - nose) * 0.3:
			d = rng.randf_range(0.5, 4.0)   # flair trompé
		var hint := "emo_cold"
		var txt := tr("Froid…")
		if d < 1.2:
			hint = "emo_hot"
			txt = tr("Brûlant !")
		elif d < 2.3:
			hint = "emo_warm"
			txt = tr("Tiède")
		pet.model.emote(hint)
		big_hint(txt, 0.8)
		Audio.play("pop", 0.1, -4.0)
		nodes[i].scale = Vector3(1, 0.7, 1)
	_update_info()
	await get_tree().create_timer(0.8, false).timeout
	busy_sniff = false
	pet.model.set_posture("stand")
	if found_items.size() >= int(lvl["objects"]):
		_finish(true)
	elif errors_left < 0:
		_finish(false)

## Flair : l'animal renifle l'air, fait quelques pas vers l'objet le plus proche
## et les cachettes voisines brillent quelques secondes.
func _use_clue() -> void:
	if clues_left <= 0 or busy_sniff or clue_busy or finished:
		return
	clues_left -= 1
	_update_info()
	var target := -1
	var best := INF
	for i in spots.size():
		if spots[i]["has"] and not spots[i]["checked"]:
			var dd := pet.position.distance_to(spots[i]["pos"])
			if dd < best:
				best = dd
				target = i
	if target < 0:
		return
	clue_busy = true
	pet.model.set_posture("alert")
	pet.model.sniff = 1.0
	pet.model.emote("emo_paw")
	Audio.play("sniff")
	await get_tree().create_timer(0.9, false).timeout
	pet.model.sniff = 0.0
	var tp: Vector3 = spots[target]["pos"]
	pet.walk_to(pet.position.lerp(tp, 0.5), 1.0)
	# deux cachettes en surbrillance : la bonne et une voisine (selon le flair)
	var cand: Array = [target]
	var others: Array = range(spots.size()).filter(func(k): return k != target and not spots[k]["checked"])
	others.sort_custom(func(a, b): return (spots[a]["pos"] as Vector3).distance_to(tp) < (spots[b]["pos"] as Vector3).distance_to(tp))
	if not others.is_empty():
		cand.append(others[0])
	for k in cand:
		var ring := WorldBuilder.torus(nodes[k], 0.32, 0.4, Vector3(0, 0.03, 0), Color(1, 0.9, 0.4))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glows.append(ring)
		var tw := ring.create_tween().set_loops(4)
		tw.tween_property(ring, "scale", Vector3(1.2, 1, 1.2), 0.35)
		tw.tween_property(ring, "scale", Vector3.ONE, 0.35)
		get_tree().create_timer(3.0, false).timeout.connect(func():
			if is_instance_valid(ring):
				ring.queue_free())
	await get_tree().create_timer(1.2, false).timeout
	clue_busy = false

func _nearest_hidden(p: Vector3) -> float:
	var best := INF
	for sp in spots:
		if sp["has"] and not sp["checked"]:
			best = minf(best, p.distance_to(sp["pos"]))
	return best

# ------------------------------------------------------------------ fin
func _finish(win: bool) -> void:
	finished = true
	if clue_btn:
		clue_btn.disabled = true
	var objects := int(lvl["objects"])
	var ratio := float(found_items.size()) / float(objects)
	var score := ratio * 70.0 + (float(maxi(errors_left, 0)) / maxf(1.0, float(lvl["tries"]))) * 30.0 * (1.0 if win else 0.0)
	GameState.spend_energy("search")
	GameState.change_need("mood", 6.0 if win else 1.0)
	GameState.add_relation(5)
	# objets trouvés : au sac (collection) ou possédés (jouets, accessoires)
	var lines: Array = []
	var extra := 0
	for id in found_items:
		var it := GameData.item(id)
		if GameState.CONSUMABLE_CAT(it):
			GameState.add_item(id)
		else:
			extra += GameState.grant_owned(id)
		lines.append("[i:%s] %s" % [it.get("icon", id), tr(it.get("name", id))])
	if on_done.is_valid():
		on_done.call(clampf(score, 0.0, 100.0))
		return
	var coins := 0
	var xp := 0
	if win:
		coins = int(lvl["reward"]) + maxi(errors_left, 0) * 5
		xp = int(lvl["xp"])
		lines.push_front(tr("Bravo ! %s a tout trouvé.") % pet_name())
		if lvl_idx == int(GameState.data["search_level"]) and lvl_idx < GameData.SEARCH_LEVELS.size() - 1:
			GameState.data["search_level"] = lvl_idx + 1
			lines.append(tr("Niveau « %s » débloqué !") % tr(GameData.SEARCH_LEVELS[lvl_idx + 1]["name"]))
		if daily:
			coins *= 2
			GameState.data["search_daily"] = {"day": GameState.today(), "done": true, "seed": 0}
			lines.append(tr("Défi du jour réussi : récompense doublée !"))
		Audio.play("success")
	else:
		coins = found_items.size() * 8
		xp = int(int(lvl["xp"]) * ratio * 0.5)
		lines.push_front(tr("Plus d'essais… %d objet(s) trouvé(s).") % found_items.size())
	if extra > 0:
		lines.append(tr("Objets déjà possédés revendus : +%d pièces") % extra)
	show_results("[i:search] " + tr("Cache-cache"), lines, coins, xp)

func _exit_tree() -> void:
	super._exit_tree()
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
