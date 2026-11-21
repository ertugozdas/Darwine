extends SceneTree

const TIMEOUT_SECONDS := 5.0

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := get_root().get_node_or_null("SteamManager")
	_expect(manager != null, "SteamManager autoload bulunamadı")
	if not manager:
		_finish()
		return
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SECONDS * 1000.0)
	while not bool(manager.get("is_available")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not bool(manager.get("is_available")):
		print("STEAM_RUNTIME_CALLBACK_SMOKE_SKIPPED: Steam istemcisi bağlı değil")
		quit(0)
		return
	while not bool(manager.get("are_stats_ready")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_expect(bool(manager.get("are_stats_ready")), "user_stats_received callback'i çalışma döngüsüne ulaşmadı")
	_expect(int(manager.get("steam_id")) > 0, "Steam kullanıcı kimliği alınamadı")
	_expect(not str(manager.call("get_persona_name")).is_empty(), "Steam görünen adı alınamadı")
	_expect(not str(manager.call("get_overlay_status_text")).is_empty(), "Steam overlay durumu üretilemedi")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STEAM_RUNTIME_CALLBACK_SMOKE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("STEAM_RUNTIME_CALLBACK_SMOKE_FAILED: %d" % _failures.size())
	quit(1)
