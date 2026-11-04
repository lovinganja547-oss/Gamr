class_name VoicePanel
extends VBoxContainer
## Apprentissage d'un mot vocal pour un ordre : instructions, enregistrement, contrôle qualité,
## réécoute, recommencer, validation. Les modèles sont stockés dans pet["voice"][cmd].

var cmd := "sit"
var on_change: Callable = Callable()
var state := "idle"      # idle | recording | review | testing
var result := {}
var status_l: Label
var tip_l: Label
var info_l: Label
var level_bar: ProgressBar
var word_edit: LineEdit
var btn_record: Button
var btn_play: Button
var btn_retry: Button
var btn_ok: Button
var btn_test: Button
var btn_clear: Button
var btn_cancel: Button
var _countdown := 0.0
var _result_pending := false

func _init(c: String, cb: Callable = Callable()) -> void:
	cmd = c
	on_change = cb

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var p := GameState.active_pet()
	var d: Dictionary = GameData.COMMANDS[cmd]
	add_child(UiKit.label(tr("Choisissez un mot court (par exemple « %s ») et prononcez-le toujours de la même façon, dans un endroit calme. Le jeu apprend votre voix : rien n'est envoyé sur Internet.") % tr(d["name"]), 22, UiKit.C_SUB))
	status_l = UiKit.label(tr("Prêt à enregistrer."), 30, UiKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	status_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_l)
	tip_l = UiKit.label("", 22, UiKit.C_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	tip_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip_l)
	level_bar = UiKit.bar(0, UiKit.C_ACCENT2, 18)
	add_child(level_bar)
	info_l = UiKit.label("[i:mic] ", 24, UiKit.C_SUB)
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info_l)
	var wh := UiKit.hbox(10)
	var wl := UiKit.label(tr("Mot affiché :"), 24, UiKit.C_SUB)
	wh.add_child(wl)
	word_edit = LineEdit.new()
	word_edit.max_length = 20
	word_edit.placeholder_text = tr(d["name"])
	word_edit.text = str(p.get("voice", {}).get(cmd, {}).get("word", ""))
	word_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_edit.custom_minimum_size = Vector2(0, 70)
	wh.add_child(word_edit)
	add_child(wh)
	var row := UiKit.hbox(10)
	btn_record = UiKit.button("[i:record] " + tr("Enregistrer"), _record, UiKit.C_DANGER, 26, 84)
	row.add_child(UiKit.expand(btn_record))
	btn_cancel = UiKit.button(tr("Annuler"), _cancel, UiKit.C_DISABLED, 24, 84)
	row.add_child(UiKit.expand(btn_cancel))
	add_child(row)
	var row2 := UiKit.hbox(10)
	btn_play = UiKit.button("[i:listen] " + tr("Écouter"), _play, UiKit.C_BLUE, 24, 84)
	row2.add_child(UiKit.expand(btn_play))
	btn_retry = UiKit.button("[i:reload] " + tr("Recommencer"), _record, UiKit.C_ACCENT, 24, 84)
	row2.add_child(UiKit.expand(btn_retry))
	btn_ok = UiKit.button("[i:check] " + tr("Valider"), _validate, UiKit.C_ACCENT2, 24, 84)
	row2.add_child(UiKit.expand(btn_ok))
	add_child(row2)
	var row3 := UiKit.hbox(10)
	btn_test = UiKit.button("[i:mic] " + tr("Tester la reconnaissance"), _test, UiKit.C_BLUE, 22, 76)
	row3.add_child(UiKit.expand(btn_test))
	btn_clear = UiKit.button("[i:trash] " + tr("Effacer"), _clear, UiKit.C_DANGER, 22, 76)
	btn_clear.custom_minimum_size = Vector2(190, 76)
	row3.add_child(btn_clear)
	add_child(row3)
	add_child(UiKit.label(tr("Conseils : 2 ou 3 enregistrements du même mot rendent la reconnaissance plus fiable. Chaque compagnon a ses propres mots."), 20, UiKit.C_SUB))
	Voice.level.connect(_on_level)
	Voice.utterance_ready.connect(_on_utterance)
	Voice.permission_result.connect(_on_permission)
	_update_info()
	_set_state("idle")

func _exit_tree() -> void:
	if Voice.level.is_connected(_on_level):
		Voice.level.disconnect(_on_level)
	if Voice.utterance_ready.is_connected(_on_utterance):
		Voice.utterance_ready.disconnect(_on_utterance)
	if Voice.permission_result.is_connected(_on_permission):
		Voice.permission_result.disconnect(_on_permission)
	if Voice.is_recording():
		Voice.cancel_record()

func _update_info() -> void:
	var p := GameState.active_pet()
	var n := Voice.template_count(p, cmd)
	var r := Voice.reliability(p, cmd)
	var txt := tr("Enregistrements : %d/%d · Fiabilité : %s") % [n, Voice.MAX_TEMPLATES, Voice.reliability_label(r)]
	if n > 0:
		var e: Dictionary = p.get("voice", {}).get(cmd, {})
		var uses := int(e.get("uses", 0))
		if uses > 0:
			txt += "  ·  " + tr("reconnu %d fois sur %d") % [int(e.get("hits", 0)), uses]
	UiKit.set_label(info_l, "[i:mic] " + txt)
	btn_clear.visible = n > 0
	btn_test.visible = n > 0

func _set_state(s: String) -> void:
	state = s
	btn_record.visible = s == "idle"
	btn_cancel.visible = s == "recording" or s == "testing"
	btn_play.visible = s == "review"
	btn_retry.visible = s == "review"
	btn_ok.visible = s == "review"
	btn_test.disabled = s != "idle" and s != "review"
	btn_clear.disabled = s == "recording" or s == "testing"
	word_edit.editable = s != "recording"
	if s == "idle":
		level_bar.value = 0.0

func _on_level(v: float) -> void:
	if state == "recording" or state == "testing":
		level_bar.value = v * 100.0

func _on_permission(granted: bool) -> void:
	if granted and state == "idle":
		status_l.text = tr("Micro autorisé. Touchez « Enregistrer ».")
	elif not granted:
		status_l.text = tr(Voice.QUALITY_TEXT["permission"])

func _begin_capture(test: bool) -> bool:
	if not Voice.ensure_permission():
		status_l.text = tr(Voice.QUALITY_TEXT["permission"])
		tip_l.text = ""
		return false
	if not Voice.available():
		status_l.text = tr(Voice.QUALITY_TEXT["no_mic"])
		tip_l.text = tr("Les ordres restent disponibles par geste ou bouton.")
		return false
	if not Voice.record_utterance(5.0):
		status_l.text = tr("Micro indisponible pour le moment.")
		return false
	_set_state("testing" if test else "recording")
	_countdown = 5.0
	status_l.text = tr("Parlez maintenant…")
	tip_l.text = tr("Dites le mot une seule fois, puis attendez.")
	return true

func _record() -> void:
	if state == "recording" or state == "testing":
		return
	result = {}
	_begin_capture(false)

func _test() -> void:
	if state == "recording" or state == "testing":
		return
	_begin_capture(true)

func _cancel() -> void:
	Voice.cancel_record()
	status_l.text = tr("Annulé.")
	tip_l.text = ""
	_set_state("review" if not result.is_empty() and bool(result.get("ok", false)) else "idle")

func _process(delta: float) -> void:
	if state == "recording" or state == "testing":
		_countdown = maxf(0.0, _countdown - delta)
		tip_l.text = tr("Dites le mot une seule fois, puis attendez. (%d s)") % int(ceil(_countdown))

func _on_utterance(res: Dictionary) -> void:
	if state != "recording" and state != "testing":
		return
	var testing := state == "testing"
	if not bool(res.get("ok", false)):
		var reason := str(res.get("reason", ""))
		status_l.text = tr(Voice.QUALITY_TEXT.get(reason, "Enregistrement inutilisable."))
		tip_l.text = tr("Touchez « Recommencer » pour réessayer.") if not result.is_empty() else tr("Touchez « Enregistrer » pour réessayer.")
		Audio.play("buzz", 0.0, -8.0)
		_set_state("review" if not result.is_empty() and bool(result.get("ok", false)) else "idle")
		return
	if testing:
		var r := Voice.recognize(res["feats"])
		if r["cmd"] == cmd:
			status_l.text = tr("Reconnu : « %s » (%d %%)") % [Voice.word(GameState.active_pet(), cmd), int(float(r["conf"]) * 100.0)]
			Audio.play("chime")
		elif r["cmd"] != "":
			status_l.text = tr("Confondu avec « %s » : ajoutez un enregistrement plus net.") % Voice.word(GameState.active_pet(), str(r["cmd"]))
			Audio.play("buzz", 0.0, -8.0)
		else:
			status_l.text = tr("Non reconnu : réenregistrez le mot plus distinctement.")
			Audio.play("buzz", 0.0, -8.0)
		tip_l.text = tr("Durée : %.1f s · rapport signal/bruit : %d dB") % [float(res.get("duration", 0.0)), int(float(res.get("snr", 0.0)))]
		_set_state("review" if not result.is_empty() and bool(result.get("ok", false)) else "idle")
		return
	result = res
	status_l.text = tr("Enregistrement net. Écoutez, puis validez.")
	tip_l.text = tr("Durée : %.1f s · rapport signal/bruit : %d dB") % [float(res.get("duration", 0.0)), int(float(res.get("snr", 0.0)))]
	Audio.play("pop")
	_set_state("review")

func _play() -> void:
	if result.has("samples"):
		Voice.play_samples(result["samples"])

func _validate() -> void:
	if state != "review" or not bool(result.get("ok", false)):
		return
	var p := GameState.active_pet()
	var n := Voice.add_template(p, cmd, result["feats"], word_edit.text)
	GameState.set_setting("voice", true)
	Audio.play("success", 0.0, -4.0)
	status_l.text = tr("Mot enregistré (%d/%d).") % [n, Voice.MAX_TEMPLATES]
	tip_l.text = tr("Répétez l'opération une ou deux fois pour renforcer la reconnaissance.") if n < Voice.MAX_TEMPLATES else tr("Un nouvel enregistrement remplacera le plus ancien.")
	result = {}
	_update_info()
	_set_state("idle")
	if on_change.is_valid():
		on_change.call()

func _clear() -> void:
	Voice.clear_cmd(GameState.active_pet(), cmd)
	status_l.text = tr("Enregistrements effacés pour cet ordre.")
	tip_l.text = ""
	result = {}
	_update_info()
	_set_state("idle")
	if on_change.is_valid():
		on_change.call()
