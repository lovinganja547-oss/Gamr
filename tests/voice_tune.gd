extends Node
## Calibrage des seuils de reconnaissance à partir de distances mesurées.
## Entrée : le fichier produit par le banc (BENCH_DUMP=chemin tests/run_voice_bench.sh).
## Usage : TUNE_DUMP=chemin [TUNE_SET="delta_w=0.8,mask_rel=0.01"] godot --headless
##         --path . res://tests/voice_tune.tscn
## Options : TUNE_VERBOSE=1 (cas limites), TUNE_CSV=chemin (une ligne par essai).
## Affiche la répartition des distances (même mot, autre mot enregistré, mot inconnu, bruit)
## puis le taux de reconnaissance et de fausses acceptations pour une grille de seuils.

func _q(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return NAN
	return a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)]

func _dist(name: String, a: PackedFloat32Array) -> void:
	a.sort()
	print("TUNE   %-34s n=%4d  min %.2f  5%% %.2f  25%% %.2f  médiane %.2f  75%% %.2f  95%% %.2f  max %.2f" % [name, a.size(), _q(a, 0.0), _q(a, 0.05), _q(a, 0.25), _q(a, 0.5), _q(a, 0.75), _q(a, 0.95), _q(a, 1.0)])

func _ready() -> void:
	var path := OS.get_environment("TUNE_DUMP")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("TUNE fichier introuvable : ", path)
		get_tree().quit(1)
		return
	var items: Array = f.get_var()
	f.close()
	var sets := OS.get_environment("TUNE_SET")
	var use_mean := true
	for kv in sets.split(",", false):
		var parts := kv.split("=")
		if parts[0] == "mean":
			use_mean = parts[1] == "1"
		else:
			Voice.set(parts[0], float(parts[1]) if parts[0] != "dtw_open" else int(parts[1]))
	print("TUNE réglages : ", sets, " · énoncés : ", items.size())
	# modèles par locuteur et par ordre
	var tpl := {}
	for it in items:
		it["feats"] = Voice.make_feats(it["mel"], it["noise_mel"])
		it["flat"] = Voice.prep(it["feats"])
		if it["kind"] == "enr":
			var key := str(it["sp"]) + "/" + str(it["label"])
			if not tpl.has(key):
				tpl[key] = []
			tpl[key].append(it)
	var refs := {}     # sp -> {cmd: [flat]}
	var intra := PackedFloat32Array()
	for key in tpl.keys():
		var sp := int(str(key).split("/")[0])
		var cmd := str(key).split("/")[1]
		if not refs.has(sp):
			refs[sp] = {}
		var flats: Array = []
		var raws: Array = []
		for it in tpl[key]:
			flats.append(it["flat"])
			raws.append(it["feats"])
		for i in flats.size():
			for j in range(i + 1, flats.size()):
				intra.append(Voice.dtw_flat(flats[i], flats[j]))
		if use_mean:
			var mt := Voice.mean_template(raws)
			if not mt.is_empty():
				flats.append(Voice.prep(mt))
		refs[sp][cmd] = flats
	var same := PackedFloat32Array()
	var other := PackedFloat32Array()
	var ratio := PackedFloat32Array()
	var unk := PackedFloat32Array()
	var noi := PackedFloat32Array()
	var trials: Array = []    # [kind, d_best, d_second, correct?]
	for it in items:
		if it["kind"] == "enr" or it["kind"] == "cap":
			continue
		var r: Dictionary = refs.get(int(it["sp"]), {})
		var best := ""
		var bd := INF
		var sd := INF
		var own := INF
		var oth := INF
		for cmd in r.keys():
			var d := INF
			for t in r[cmd]:
				d = minf(d, Voice.dtw_flat(it["flat"], t))
			if d < bd:
				sd = bd
				bd = d
				best = cmd
			elif d < sd:
				sd = d
			if cmd == it["label"]:
				own = d
			else:
				oth = minf(oth, d)
		if it["kind"] == "rec":
			same.append(own)
			other.append(oth)
			ratio.append(own / oth)
		elif it["kind"] == "unk":
			unk.append(bd)
		else:
			noi.append(bd)
		trials.append([it["kind"], bd, sd, best == it["label"], float(it.get("snr", 0.0)), it["label"], it["sp"]])
		if OS.get_environment("TUNE_VERBOSE") == "1" and ((it["kind"] == "rec" and own > 0.95) or (it["kind"] != "rec" and bd < 1.15)):
			var lens: Array = []
			for t in r.get(it["label"], []):
				lens.append(t.size() / Voice.FDIMS)
			print("TUNE   cas ", it["kind"], " loc ", it["sp"], " « ", it["label"], " » d=%.2f autre=%.2f meilleur=%s" % [own if it["kind"] == "rec" else bd, oth, best], " cadres=", it["feats"].size(), " modèles=", lens, " rsb=%.0f" % float(it.get("snr", 0.0)))
	_dist("entre modèles du même mot", intra)
	_dist("même mot (test -> son ordre)", same)
	_dist("autre mot enregistré (le plus proche)", other)
	_dist("rapport même / autre", ratio)
	_dist("mot inconnu (ordre le plus proche)", unk)
	_dist("bruit (ordre le plus proche)", noi)
	var nrec := same.size()
	var csv_path := OS.get_environment("TUNE_CSV")
	if csv_path != "":
		var cf := FileAccess.open(csv_path, FileAccess.WRITE)
		cf.store_line("genre,meilleur,second,correct,rsb,mot,locuteur")
		for t in trials:
			cf.store_line("%s,%.4f,%.4f,%d,%.1f,%s,%d" % [t[0], t[1], minf(t[2], 99.0), 1 if t[3] else 0, t[4], t[5], t[6]])
		cf.close()
	# point de fonctionnement sans réglage manuel : seuil juste sous la plus petite distance
	# d'un mot inconnu ou d'un bruit (0 fausse acceptation), puis à 2 % de fausses acceptations
	var neg := PackedFloat32Array()
	for t in trials:
		if t[0] != "rec" and t[1] <= t[2] * 0.9:
			neg.append(t[1])
	neg.sort()
	for fa in [0.0, 0.02, 0.05]:
		var thr := _q(neg, fa) - 0.001
		var okc0 := 0
		for t in trials:
			if t[0] == "rec" and t[3] and t[1] <= thr and t[1] <= t[2] * 0.9:
				okc0 += 1
		print("TUNE   RESUME à %.0f %% de fausses acceptations : seuil %.2f, reconnus %.1f %% (seuil / médiane même mot = %.2f)" % [fa * 100.0, thr, 100.0 * okc0 / maxf(1.0, nrec), thr / _q(same, 0.5)])
	for mm in [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8]:
		for mg in [0.8, 0.85, 0.9, 0.95]:
			var okc := 0
			var wrong := 0
			var fpu := 0
			var fpn := 0
			for t in trials:
				var acc: bool = t[1] <= mm and t[1] <= t[2] * mg
				if t[0] == "rec":
					if acc and t[3]:
						okc += 1
					elif acc:
						wrong += 1
				elif acc:
					if t[0] == "unk":
						fpu += 1
					else:
						fpn += 1
			print("TUNE   seuil %.2f marge %.2f : reconnus %5.1f %%  confondus %d  inconnus acceptés %d/%d  bruits acceptés %d/%d" % [mm, mg, 100.0 * okc / maxf(1.0, nrec), wrong, fpu, unk.size(), fpn, noi.size()])
	get_tree().quit(0)
