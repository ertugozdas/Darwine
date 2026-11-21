class_name ProfileRepository extends Node

signal profile_changed
signal match_recorded(result: Dictionary)
signal profile_recovered(message: String)
signal sync_state_changed(state: String, message: String)

const DEFAULT_SAVE_PATH := "user://darwine_profile.json"
const SCENARIO_CATALOG := preload("res://scripts/scenario_catalog.gd")
const SAVE_VERSION := 5
const BACKUP_COUNT := 3
const MAX_HISTORY := 30
const MAX_PENDING_OPERATIONS := 256
const SERVER_AUTHORITATIVE_PROFILE_KEYS := [
	"level", "xp", "total_xp", "seals", "stats", "achievements", "missions", "campaigns", "competitive",
]

const TITLE_COSMETICS := {
	"sancak_tasiyicisi": "Sancak Taşıyıcısı",
	"koridor_nobetcisi": "Koridor Nöbetçisi",
	"zafer_nobetcisi": "Zafer Nöbetçisi",
	"kusatma_ustasi": "Kuşatma Ustası",
	"demir_irade": "Demir İrade",
}
const BANNER_COSMETICS := {
	"kul_ve_pirinc": "Kül ve Pirinç",
	"ayaz_muhru": "Ayaz Mührü",
	"kizil_safak": "Kızıl Şafak",
	"uc_koridor": "Üç Koridor Sancağı",
	"gece_muhafizi": "Gece Muhafızı",
}
const LEVEL_REWARDS := {
	2: {"kind": "title", "id": "koridor_nobetcisi"},
	3: {"kind": "banner", "id": "ayaz_muhru"},
	5: {"kind": "title", "id": "kusatma_ustasi"},
	7: {"kind": "banner", "id": "kizil_safak"},
}
const ACHIEVEMENT_DEFINITIONS := [
	{
		"id": "ilk_zafer",
		"title": "İlk Sancak",
		"description": "İlk zaferini kazan.",
		"metric": "wins",
		"target": 1,
		"reward_kind": "title",
		"reward_id": "zafer_nobetcisi",
	},
	{
		"id": "tecrubeli_komutan",
		"title": "Tecrübeli Komutan",
		"description": "10 maç tamamla.",
		"metric": "matches",
		"target": 10,
		"reward_kind": "banner",
		"reward_id": "gece_muhafizi",
	},
	{
		"id": "kusatma_izi",
		"title": "Kuşatma İzi",
		"description": "Rakip merkezlere toplam 100 hasar ver.",
		"metric": "hq_damage",
		"target": 100,
		"reward_kind": "banner",
		"reward_id": "uc_koridor",
	},
	{
		"id": "demir_seri",
		"title": "Demir Seri",
		"description": "Üst üste 3 maç kazan.",
		"metric": "best_streak",
		"target": 3,
		"reward_kind": "title",
		"reward_id": "demir_irade",
	},
]
const DAILY_MISSIONS := [
	{"id": "gunluk_meydan", "title": "Meydana Çık", "description": "2 maç tamamla.", "metric": "matches", "target": 2, "reward": 20},
	{"id": "gunluk_arsenal", "title": "Arsenali Aç", "description": "15 kart oyna.", "metric": "cards_played", "target": 15, "reward": 18},
	{"id": "gunluk_gedik", "title": "Gedik Aç", "description": "Merkez binalarına 20 hasar ver.", "metric": "hq_damage", "target": 20, "reward": 22},
]
const WEEKLY_MISSIONS := [
	{"id": "haftalik_zafer", "title": "Zafer Haftası", "description": "3 maç kazan.", "metric": "wins", "target": 3, "reward": 70},
	{"id": "haftalik_sefer", "title": "Uzun Sefer", "description": "Toplam 30 raund oyna.", "metric": "rounds", "target": 30, "reward": 55},
	{"id": "haftalik_rakip", "title": "Canlı Rakip", "description": "3 çevrimiçi maç tamamla.", "metric": "online_matches", "target": 3, "reward": 55},
]

var save_path := DEFAULT_SAVE_PATH
var _profile: Dictionary = {}
var _sync_provider: ProfileSyncProvider = null
var _active_sync_request_id := ""
var _last_load_status := ""
var _applying_cached_sections := false


func _ready() -> void:
	_load_profile()
	call_deferred("_bind_local_repositories")


func configure_storage_path(path: String, reset: bool = false) -> void:
	save_path = path if not path.strip_edges().is_empty() else DEFAULT_SAVE_PATH
	if reset:
		SafeJsonStore.remove_family(save_path, BACKUP_COUNT)
	_load_profile()


func get_last_load_status() -> String:
	return _last_load_status


func set_sync_provider(provider: ProfileSyncProvider) -> void:
	if _sync_provider != provider and not _active_sync_request_id.is_empty():
		if _sync_provider:
			_sync_provider.cancel_sync(_active_sync_request_id)
		_active_sync_request_id = ""
	if _sync_provider and _sync_provider.sync_completed.is_connected(_on_provider_sync_completed):
		_sync_provider.sync_completed.disconnect(_on_provider_sync_completed)
	_sync_provider = provider
	if _sync_provider and not _sync_provider.sync_completed.is_connected(_on_provider_sync_completed):
		_sync_provider.sync_completed.connect(_on_provider_sync_completed)
	sync_state_changed.emit(
		"hazır" if _sync_provider and _sync_provider.is_available() else "çevrimdışı",
		"Çevrimiçi profil sağlayıcısı hazır." if _sync_provider and _sync_provider.is_available() else "Çevrimiçi hesap sağlayıcısı bağlı değil. Yerel profil önbelleği kullanılıyor."
	)


func begin_online_sync() -> Dictionary:
	if not _active_sync_request_id.is_empty():
		return {"success": false, "error": "Profil eşitlemesi zaten sürüyor."}
	if not _sync_provider or not _sync_provider.is_available():
		return {
			"success": false,
			"unavailable": true,
			"error": "Gerçek bir hesap veya çevrimiçi profil sağlayıcısı bağlı değil.",
		}
	var account_id := _sync_provider.get_account_id().strip_edges()
	if account_id.is_empty():
		return {"success": false, "unavailable": true, "error": "Çevrimiçi hesap kimliği bulunamadı."}
	var sync_data := _profile.get("sync", {}) as Dictionary
	_active_sync_request_id = "%s-%d" % [str(_profile.get("profile_id", "profile")), Time.get_ticks_usec()]
	var request := {
		"account_id": account_id,
		"profile_id": str(_profile.get("profile_id", "")),
		"client_profile": _build_sync_profile_payload(),
		"pending_operations": (sync_data.get("pending_operations", []) as Array).duplicate(true),
		"last_server_revision": int(sync_data.get("last_server_revision", 0)),
	}
	if not _sync_provider.begin_sync(_active_sync_request_id, request):
		_active_sync_request_id = ""
		return {"success": false, "error": "Çevrimiçi sağlayıcı eşitlemeyi başlatamadı."}
	sync_state_changed.emit("eşitleniyor", "Profil değişiklikleri güvenli kuyruktan gönderiliyor.")
	return {"success": true, "request_id": _active_sync_request_id}


func get_profile() -> Dictionary:
	_ensure_mission_periods()
	return _profile.duplicate(true)


func get_stats() -> Dictionary:
	return (_profile.get("stats", {}) as Dictionary).duplicate(true)


func get_history() -> Array:
	return (_profile.get("history", []) as Array).duplicate(true)


func get_scenario_state(campaign_id: String, scenario_id: String) -> Dictionary:
	var campaigns := _profile.get("campaigns", {}) as Dictionary
	var campaign_variant: Variant = campaigns.get(campaign_id, {})
	if not campaign_variant is Dictionary:
		return {}
	var states_variant: Variant = (campaign_variant as Dictionary).get("scenario_states", {})
	if not states_variant is Dictionary:
		return {}
	var state_variant: Variant = (states_variant as Dictionary).get(scenario_id, {})
	return (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}


func is_scenario_unlocked(campaign_id: String, scenario: Dictionary) -> bool:
	var unlock_variant: Variant = scenario.get("unlock", {})
	var requirements_variant: Variant = (
		(unlock_variant as Dictionary).get("requires", [])
		if unlock_variant is Dictionary
		else []
	)
	if not requirements_variant is Array:
		return false
	for requirement_variant in requirements_variant as Array:
		if not bool(get_scenario_state(campaign_id, str(requirement_variant)).get("completed", false)):
			return false
	return true


func record_scenario_result(
	campaign_id: String,
	scenario: Dictionary,
	evaluation: Dictionary,
	match_id: String
) -> Dictionary:
	var scenario_id := str(scenario.get("id", "")).strip_edges()
	var normalized_campaign_id := campaign_id.strip_edges()
	var normalized_match_id := match_id.strip_edges()
	if scenario_id.is_empty() or normalized_campaign_id.is_empty() or normalized_match_id.is_empty():
		return {"recorded": false, "error": "Senaryo sonucu için kimlik bilgileri eksik."}
	var catalog_result := SCENARIO_CATALOG.load_catalog()
	if not bool(catalog_result.get("success", false)):
		return {"recorded": false, "error": str(catalog_result.get("error", "Senaryo kataloğu yüklenemedi."))}
	var canonical_campaign := SCENARIO_CATALOG.get_campaign()
	if normalized_campaign_id != str(canonical_campaign.get("campaign_id", "")):
		return {"recorded": false, "error": "Bilinmeyen kampanya kimliği: %s" % normalized_campaign_id}
	var canonical_scenario := SCENARIO_CATALOG.get_scenario(scenario_id)
	if canonical_scenario.is_empty():
		return {"recorded": false, "error": "Bilinmeyen senaryo kimliği: %s" % scenario_id}
	scenario = canonical_scenario
	var campaigns := (_profile.get("campaigns", {}) as Dictionary).duplicate(true)
	var campaign_variant: Variant = campaigns.get(normalized_campaign_id, {})
	var campaign: Dictionary = (campaign_variant as Dictionary).duplicate(true) if campaign_variant is Dictionary else {}
	var states_variant: Variant = campaign.get("scenario_states", {})
	var states: Dictionary = (states_variant as Dictionary).duplicate(true) if states_variant is Dictionary else {}
	var state_variant: Variant = states.get(scenario_id, {})
	var state: Dictionary = (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}
	if str(state.get("last_match_id", "")) == normalized_match_id:
		return {"recorded": false, "duplicate": true, "state": state.duplicate(true)}

	var was_completed := bool(state.get("completed", false))
	var completed := bool(evaluation.get("completed", false))
	var completed_now := completed and not was_completed
	state["attempts"] = int(state.get("attempts", 0)) + 1
	state["completed"] = was_completed or completed
	state["last_match_id"] = normalized_match_id
	state["last_played_at_utc"] = Time.get_datetime_string_from_system(true, true)
	state["last_evaluation"] = evaluation.duplicate(true)
	state["best_objectives_completed"] = maxi(
		int(state.get("best_objectives_completed", 0)),
		int(evaluation.get("completed_required_count", 0))
	)
	if completed_now:
		state["completed_at_utc"] = Time.get_datetime_string_from_system(true, true)

	var seals_before := int(_profile.get("seals", 0))
	var new_cosmetics: Array[String] = []
	var reward_variant: Variant = scenario.get("reward", {})
	var reward: Dictionary = reward_variant as Dictionary if reward_variant is Dictionary else {}
	if completed_now:
		var reward_kind := str(reward.get("kind", ""))
		if reward_kind == "seals":
			_profile["seals"] = seals_before + maxi(0, int(reward.get("amount", 0)))
		elif reward_kind in ["title", "banner"]:
			_unlock_cosmetic(reward_kind, str(reward.get("id", "")), new_cosmetics)

	states[scenario_id] = state
	campaign["scenario_states"] = states
	campaign["last_played_scenario_id"] = scenario_id
	campaign["updated_at_unix"] = int(Time.get_unix_time_from_system())
	campaigns[normalized_campaign_id] = campaign
	_profile["campaigns"] = campaigns
	_enqueue_operation("campaign_progress", {
		"campaign_id": normalized_campaign_id,
		"scenario_id": scenario_id,
		"state": state.duplicate(true),
	})
	_save_profile()
	var result := {
		"recorded": true,
		"completed": bool(state.get("completed", false)),
		"completed_now": completed_now,
		"seals_gained": int(_profile.get("seals", 0)) - seals_before,
		"new_cosmetics": new_cosmetics,
		"state": state.duplicate(true),
	}
	profile_changed.emit()
	return result


func get_level_progress() -> Dictionary:
	var level := int(_profile.get("level", 1))
	var current_xp := int(_profile.get("xp", 0))
	var required := xp_required_for_level(level)
	return {
		"level": level,
		"current_xp": current_xp,
		"required_xp": required,
		"ratio": clampf(float(current_xp) / float(maxi(1, required)), 0.0, 1.0),
	}


func get_achievement_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var states := _profile.get("achievements", {}) as Dictionary
	for definition_variant in ACHIEVEMENT_DEFINITIONS:
		var definition := (definition_variant as Dictionary).duplicate(true)
		var state := states.get(str(definition.get("id", "")), {}) as Dictionary
		definition["progress"] = int(state.get("progress", 0))
		definition["completed"] = bool(state.get("completed", false))
		definition["reward_name"] = get_cosmetic_name(
			str(definition.get("reward_kind", "")),
			str(definition.get("reward_id", ""))
		)
		entries.append(definition)
	return entries


func get_mission_entries(period: String) -> Array[Dictionary]:
	_ensure_mission_periods()
	var normalized := "weekly" if period == "weekly" else "daily"
	var definitions: Array = WEEKLY_MISSIONS if normalized == "weekly" else DAILY_MISSIONS
	var missions := _profile.get("missions", {}) as Dictionary
	var states := missions.get(normalized, {}) as Dictionary
	var entries: Array[Dictionary] = []
	for definition_variant in definitions:
		var definition := (definition_variant as Dictionary).duplicate(true)
		var state := states.get(str(definition.get("id", "")), {}) as Dictionary
		definition["period"] = normalized
		definition["progress"] = int(state.get("progress", 0))
		definition["completed"] = bool(state.get("completed", false))
		definition["rewarded"] = bool(state.get("rewarded", false))
		entries.append(definition)
	return entries


func get_unlocked_titles() -> Array[Dictionary]:
	return _cosmetic_entries("title", _profile.get("unlocked_titles", []) as Array)


func get_unlocked_banners() -> Array[Dictionary]:
	return _cosmetic_entries("banner", _profile.get("unlocked_banners", []) as Array)


func get_cosmetic_name(kind: String, cosmetic_id: String) -> String:
	if kind == "title":
		return str(TITLE_COSMETICS.get(cosmetic_id, cosmetic_id.capitalize()))
	return str(BANNER_COSMETICS.get(cosmetic_id, cosmetic_id.capitalize()))


func set_commander_name(value: String) -> bool:
	var normalized := value.strip_edges().left(24)
	if normalized.is_empty():
		return false
	_profile["commander_name"] = normalized
	_profile["commander_updated_at_unix"] = int(Time.get_unix_time_from_system())
	_enqueue_operation("commander", {"commander_name": normalized})
	_save_profile()
	profile_changed.emit()
	return true


func select_title(cosmetic_id: String) -> bool:
	if cosmetic_id not in (_profile.get("unlocked_titles", []) as Array):
		return false
	_profile["selected_title"] = cosmetic_id
	_enqueue_operation("cosmetic_selection", {"kind": "title", "id": cosmetic_id})
	_save_profile()
	profile_changed.emit()
	return true


func select_banner(cosmetic_id: String) -> bool:
	if cosmetic_id not in (_profile.get("unlocked_banners", []) as Array):
		return false
	_profile["selected_banner"] = cosmetic_id
	_enqueue_operation("cosmetic_selection", {"kind": "banner", "id": cosmetic_id})
	_save_profile()
	profile_changed.emit()
	return true


func record_match(
	summary: Dictionary,
	perspective_player_id: int,
	mode: String,
	deck_name: String = ""
) -> Dictionary:
	if perspective_player_id not in GameRules.PLAYER_IDS:
		return {"recorded": false, "error": "Geçersiz oyuncu bakış açısı."}
	_ensure_mission_periods()
	var match_id := str(summary.get("match_id", "")).strip_edges()
	if match_id.is_empty():
		match_id = "%s-%d" % [str(summary.get("seed", 0)), Time.get_ticks_usec()]
	for entry_variant in _profile.get("history", []) as Array:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("match_id", "")) == match_id:
			return {"recorded": false, "duplicate": true}

	var winner_id := int(summary.get("winner_id", 0))
	var won := winner_id == perspective_player_id
	var draw := winner_id not in GameRules.PLAYER_IDS
	var player_metrics := _player_metrics(summary, perspective_player_id)
	var rounds := maxi(1, int(summary.get("round_count", 1)))
	var cards_played := maxi(0, int(player_metrics.get("cards_played", 0)))
	var hq_damage := maxi(0, int(player_metrics.get("hq_damage", 0)))
	var destroyed := maxi(0, int(player_metrics.get("cards_destroyed", 0)))
	var ruleset := int(summary.get("ruleset", MatchSetup.Ruleset.SIEGE))
	var is_dominion := ruleset == MatchSetup.Ruleset.DOMINION
	var ruleset_name := str(summary.get("ruleset_name", "Hakimiyet" if is_dominion else "Kuşatma"))
	var win_reason := str(summary.get("win_reason", ""))
	var dominion_score := maxi(0, int(player_metrics.get("dominion_score", 0)))
	var dominion_points := maxi(0, int(player_metrics.get("dominion_points", player_metrics.get("dominion_lane_wins", 0))))
	var opponent_metrics := _player_metrics(summary, 2 if perspective_player_id == 1 else 1)
	var opponent_dominion_score := maxi(0, int(opponent_metrics.get("dominion_score", 0)))
	var duration_seconds := maxf(0.0, float(summary.get("duration_seconds", 0.0)))
	var normalized_mode := mode if not mode.strip_edges().is_empty() else "Yerel"

	var stats := _profile.get("stats", {}) as Dictionary
	stats["matches"] = int(stats.get("matches", 0)) + 1
	stats["wins"] = int(stats.get("wins", 0)) + (1 if won else 0)
	stats["draws"] = int(stats.get("draws", 0)) + (1 if draw else 0)
	stats["losses"] = int(stats.get("losses", 0)) + (1 if not won and not draw else 0)
	stats["cards_played"] = int(stats.get("cards_played", 0)) + cards_played
	stats["hq_damage"] = int(stats.get("hq_damage", 0)) + hq_damage
	stats["cards_destroyed"] = int(stats.get("cards_destroyed", 0)) + destroyed
	stats["total_rounds"] = int(stats.get("total_rounds", 0)) + rounds
	if is_dominion:
		stats["dominion_matches"] = int(stats.get("dominion_matches", 0)) + 1
		stats["dominion_wins"] = int(stats.get("dominion_wins", 0)) + (1 if won else 0)
		stats["dominion_points"] = int(stats.get("dominion_points", 0)) + dominion_points
	if normalized_mode == "Çevrimiçi":
		stats["online_matches"] = int(stats.get("online_matches", 0)) + 1
	elif normalized_mode == "Yapay Zekâ":
		stats["ai_matches"] = int(stats.get("ai_matches", 0)) + 1
	if won:
		stats["current_streak"] = int(stats.get("current_streak", 0)) + 1
	else:
		stats["current_streak"] = 0
	stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), int(stats.get("current_streak", 0)))
	_profile["stats"] = stats

	var level_before := int(_profile.get("level", 1))
	var seals_before := int(_profile.get("seals", 0))
	var xp_gained := 55 + mini(35, rounds * 2) + (40 if won else 0) + (15 if normalized_mode == "Çevrimiçi" else 0)
	_profile["total_xp"] = int(_profile.get("total_xp", 0)) + xp_gained
	_profile["xp"] = int(_profile.get("xp", 0)) + xp_gained
	_profile["seals"] = int(_profile.get("seals", 0)) + 6 + (4 if won else 0)
	var new_cosmetics: Array[String] = []
	while int(_profile.get("xp", 0)) >= xp_required_for_level(int(_profile.get("level", 1))):
		var required := xp_required_for_level(int(_profile.get("level", 1)))
		_profile["xp"] = int(_profile.get("xp", 0)) - required
		_profile["level"] = int(_profile.get("level", 1)) + 1
		_unlock_level_reward(int(_profile.get("level", 1)), new_cosmetics)

	var new_achievements: Array[String] = []
	_evaluate_achievements(new_achievements, new_cosmetics)
	var mission_delta := {
		"matches": 1,
		"wins": 1 if won else 0,
		"cards_played": cards_played,
		"hq_damage": hq_damage,
		"rounds": rounds,
		"online_matches": 1 if normalized_mode == "Çevrimiçi" else 0,
	}
	var completed_missions: Array[String] = []
	_advance_missions(mission_delta, completed_missions)

	var history_entry := {
		"match_id": match_id,
		"timestamp_utc": Time.get_datetime_string_from_system(true, true),
		"result": "Zafer" if won else ("Beraberlik" if draw else "Mağlubiyet"),
		"won": won,
		"draw": draw,
		"mode": normalized_mode,
		"ruleset": ruleset,
		"ruleset_name": ruleset_name,
		"win_reason": win_reason,
		"deck_name": deck_name if not deck_name.strip_edges().is_empty() else "İsimsiz Deste",
		"rounds": rounds,
		"duration_seconds": duration_seconds,
		"cards_played": cards_played,
		"hq_damage": hq_damage,
		"cards_destroyed": destroyed,
		"dominion_score": dominion_score,
		"opponent_dominion_score": opponent_dominion_score,
		"dominion_points": dominion_points,
		"dominion_lane_wins": maxi(0, int(player_metrics.get("dominion_lane_wins", dominion_points))),
		"mvp_card_name": str(player_metrics.get("mvp_card_name", "—")),
		"match_analysis": (summary.get("match_analysis", {}) as Dictionary).duplicate(true) if summary.get("match_analysis", {}) is Dictionary else {},
		"campaign_id": str(summary.get("scenario_context", {}).get("campaign_id", "")) if summary.get("scenario_context", {}) is Dictionary else "",
		"scenario_id": str(summary.get("scenario_id", "")),
		"xp_gained": xp_gained,
	}
	var history := _profile.get("history", []) as Array
	history.push_front(history_entry)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	_profile["history"] = history
	_enqueue_operation("match_result", {
		"match_id": match_id,
		"summary": summary.duplicate(true),
		"perspective_player_id": perspective_player_id,
		"mode": normalized_mode,
		"deck_name": deck_name,
	})
	_save_profile()

	var result := {
		"recorded": true,
		"xp_gained": xp_gained,
		"seals_gained": int(_profile.get("seals", 0)) - seals_before,
		"level_before": level_before,
		"level_after": int(_profile.get("level", 1)),
		"new_achievements": new_achievements,
		"completed_missions": completed_missions,
		"new_cosmetics": new_cosmetics,
		"history_entry": history_entry.duplicate(true),
	}
	profile_changed.emit()
	match_recorded.emit(result.duplicate(true))
	return result


func xp_required_for_level(level: int) -> int:
	return 100 + maxi(0, level - 1) * 45


func _default_profile() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"profile_id": "",
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"last_modified_unix": int(Time.get_unix_time_from_system()),
		"commander_name": "Komutan",
		"commander_updated_at_unix": 0,
		"level": 1,
		"xp": 0,
		"total_xp": 0,
		"seals": 0,
		"selected_title": "sancak_tasiyicisi",
		"selected_banner": "kul_ve_pirinc",
		"unlocked_titles": ["sancak_tasiyicisi"],
		"unlocked_banners": ["kul_ve_pirinc"],
		"stats": {
			"matches": 0,
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"online_matches": 0,
			"ai_matches": 0,
			"cards_played": 0,
			"hq_damage": 0,
			"cards_destroyed": 0,
			"dominion_matches": 0,
			"dominion_wins": 0,
			"dominion_points": 0,
			"total_rounds": 0,
			"current_streak": 0,
			"best_streak": 0,
		},
		"achievements": {},
		"missions": {},
		"campaigns": {},
		"history": [],
		"decks": {"updated_at_unix": 0, "active_deck_id": "", "decks": []},
		"settings": {"updated_at_unix": 0, "values": {}},
		"competitive": {},
		"sync": {
			"pending_operations": [],
			"last_server_revision": 0,
			"last_synced_at_utc": "",
		},
		"migration_history": [],
	}


func _load_profile() -> void:
	_profile = _default_profile()
	_last_load_status = "yeni"
	var loaded := SafeJsonStore.read_dictionary(save_path)
	var recovered_from := 0
	if bool(loaded.get("success", false)):
		_profile = _merge_profile(_migrate_profile(loaded.get("data", {}) as Dictionary))
		_last_load_status = "yüklendi"
	else:
		for backup_index in range(1, BACKUP_COUNT + 1):
			var backup := SafeJsonStore.read_dictionary(SafeJsonStore.backup_path(save_path, backup_index))
			if not bool(backup.get("success", false)):
				continue
			_profile = _merge_profile(_migrate_profile(backup.get("data", {}) as Dictionary))
			recovered_from = backup_index
			_last_load_status = "yedekten_kurtarıldı"
			break
		if recovered_from == 0 and not bool(loaded.get("missing", false)):
			_last_load_status = "bozuk_kayıt_yenilendi"
	if str(_profile.get("profile_id", "")).is_empty():
		_profile["profile_id"] = _new_profile_id()
	_ensure_mission_periods()
	_save_profile()
	if recovered_from > 0:
		profile_recovered.emit("Profil %d numaralı yedekten kurtarıldı." % recovered_from)
	elif _last_load_status == "bozuk_kayıt_yenilendi":
		profile_recovered.emit("Profil kaydı bozuktu; güvenli yeni profil açıldı ve bozuk dosya yedekte tutuldu.")
	profile_changed.emit()


func _merge_profile(saved: Dictionary) -> Dictionary:
	var merged := _default_profile()
	for key_variant in saved.keys():
		var key := str(key_variant)
		if merged.has(key):
			merged[key] = saved[key_variant]
	var default_stats := (_default_profile().get("stats", {}) as Dictionary)
	var saved_stats := merged.get("stats", {}) as Dictionary
	for key_variant in default_stats.keys():
		var key := str(key_variant)
		if not saved_stats.has(key):
			saved_stats[key] = default_stats[key]
	merged["stats"] = saved_stats
	merged["level"] = maxi(1, int(merged.get("level", 1)))
	merged["xp"] = maxi(0, int(merged.get("xp", 0)))
	merged["seals"] = maxi(0, int(merged.get("seals", 0)))
	if not merged.get("history", []) is Array:
		merged["history"] = []
	if not merged.get("unlocked_titles", []) is Array:
		merged["unlocked_titles"] = ["sancak_tasiyicisi"]
	if not merged.get("unlocked_banners", []) is Array:
		merged["unlocked_banners"] = ["kul_ve_pirinc"]
	if not merged.get("decks", {}) is Dictionary:
		merged["decks"] = _default_profile()["decks"]
	if not merged.get("settings", {}) is Dictionary:
		merged["settings"] = _default_profile()["settings"]
	if not merged.get("competitive", {}) is Dictionary:
		merged["competitive"] = {}
	if not merged.get("campaigns", {}) is Dictionary:
		merged["campaigns"] = {}
	if not merged.get("sync", {}) is Dictionary:
		merged["sync"] = _default_profile()["sync"]
	var sync_data := merged.get("sync", {}) as Dictionary
	if not sync_data.get("pending_operations", []) is Array:
		sync_data["pending_operations"] = []
	merged["sync"] = sync_data
	if not merged.get("migration_history", []) is Array:
		merged["migration_history"] = []
	merged["save_version"] = SAVE_VERSION
	return merged


func _save_profile() -> void:
	_profile["save_version"] = SAVE_VERSION
	_profile["last_modified_unix"] = int(Time.get_unix_time_from_system())
	var result := SafeJsonStore.write_dictionary_atomic(save_path, _profile, BACKUP_COUNT)
	if not bool(result.get("success", false)):
		push_warning("Profil kaydedilemedi: %s" % str(result.get("error", "bilinmeyen hata")))


func _migrate_profile(saved: Dictionary) -> Dictionary:
	var migrated := saved.duplicate(true)
	var source_version := int(migrated.get("save_version", 1))
	var history_variant: Variant = migrated.get("migration_history", [])
	var migration_history: Array = (history_variant as Array).duplicate(true) if history_variant is Array else []
	if source_version < 2:
		migrated["decks"] = {"updated_at_unix": 0, "active_deck_id": "", "decks": []}
		migrated["settings"] = {"updated_at_unix": 0, "values": {}}
		migrated["sync"] = {
			"pending_operations": [],
			"last_server_revision": 0,
			"last_synced_at_utc": "",
		}
		migration_history.append({"from": source_version, "to": 2, "at_utc": Time.get_datetime_string_from_system(true, true)})
		source_version = 2
	if source_version < 3:
		migrated["competitive"] = migrated.get("competitive", {}) if migrated.get("competitive", {}) is Dictionary else {}
		migrated["commander_updated_at_unix"] = int(migrated.get("last_modified_unix", 0))
		migration_history.append({"from": source_version, "to": 3, "at_utc": Time.get_datetime_string_from_system(true, true)})
		source_version = 3
	if source_version < 4:
		var stats_variant: Variant = migrated.get("stats", {})
		var stats: Dictionary = stats_variant as Dictionary if stats_variant is Dictionary else {}
		for key in ["dominion_matches", "dominion_wins", "dominion_points"]:
			if not stats.has(key):
				stats[key] = 0
		migrated["stats"] = stats
		var migrated_history: Array = []
		var saved_history_variant: Variant = migrated.get("history", [])
		if saved_history_variant is Array:
			for entry_variant in saved_history_variant as Array:
				if not entry_variant is Dictionary:
					continue
				var entry := (entry_variant as Dictionary).duplicate(true)
				entry["ruleset"] = int(entry.get("ruleset", MatchSetup.Ruleset.SIEGE))
				entry["ruleset_name"] = str(entry.get("ruleset_name", "Kuşatma"))
				entry["win_reason"] = str(entry.get("win_reason", "headquarters"))
				entry["dominion_score"] = maxi(0, int(entry.get("dominion_score", 0)))
				entry["opponent_dominion_score"] = maxi(0, int(entry.get("opponent_dominion_score", 0)))
				entry["dominion_points"] = maxi(0, int(entry.get("dominion_points", 0)))
				entry["dominion_lane_wins"] = maxi(0, int(entry.get("dominion_lane_wins", 0)))
				migrated_history.append(entry)
		migrated["history"] = migrated_history
		migration_history.append({"from": source_version, "to": 4, "at_utc": Time.get_datetime_string_from_system(true, true)})
		source_version = 4
	if source_version < 5:
		migrated["campaigns"] = migrated.get("campaigns", {}) if migrated.get("campaigns", {}) is Dictionary else {}
		migration_history.append({"from": source_version, "to": 5, "at_utc": Time.get_datetime_string_from_system(true, true)})
	migrated["migration_history"] = migration_history
	migrated["save_version"] = SAVE_VERSION
	return migrated


func _enqueue_operation(kind: String, payload: Dictionary) -> void:
	var sync_data := (_profile.get("sync", {}) as Dictionary).duplicate(true)
	var pending_variant: Variant = sync_data.get("pending_operations", [])
	var pending: Array = (pending_variant as Array).duplicate(true) if pending_variant is Array else []
	var operation_id := "%s:%s:%d" % [
		str(_profile.get("profile_id", "local")),
		kind,
		Time.get_ticks_usec(),
	]
	pending.append({
		"operation_id": operation_id,
		"idempotency_key": operation_id,
		"kind": kind,
		"created_at_utc": Time.get_datetime_string_from_system(true, true),
		"payload": payload.duplicate(true),
	})
	if pending.size() > MAX_PENDING_OPERATIONS:
		pending = pending.slice(pending.size() - MAX_PENDING_OPERATIONS)
	sync_data["pending_operations"] = pending
	_profile["sync"] = sync_data


func get_pending_sync_operations() -> Array:
	var sync_data := _profile.get("sync", {}) as Dictionary
	return (sync_data.get("pending_operations", []) as Array).duplicate(true)


func update_decks_cache(payload: Dictionary, queue_change: bool = true) -> void:
	var normalized := payload.duplicate(true)
	normalized["updated_at_unix"] = int(payload.get("updated_at_unix", Time.get_unix_time_from_system()))
	_profile["decks"] = normalized
	if queue_change:
		_enqueue_operation("decks", normalized)
	_save_profile()
	profile_changed.emit()


func update_settings_cache(values: Dictionary, queue_change: bool = true) -> void:
	var normalized := {
		"updated_at_unix": int(values.get("updated_at_unix", Time.get_unix_time_from_system())),
		"values": (values.get("values", values) as Dictionary).duplicate(true),
	}
	_profile["settings"] = normalized
	if queue_change:
		_enqueue_operation("settings", normalized)
	_save_profile()
	profile_changed.emit()


func get_cached_decks() -> Dictionary:
	return (_profile.get("decks", {}) as Dictionary).duplicate(true)


func get_cached_settings() -> Dictionary:
	return (_profile.get("settings", {}) as Dictionary).duplicate(true)


func _build_sync_profile_payload() -> Dictionary:
	var payload := _profile.duplicate(true)
	# Queue transport metadata is sent separately and never merged as profile data.
	payload.erase("sync")
	return payload


func _on_provider_sync_completed(request_id: String, result: Dictionary) -> void:
	if request_id != _active_sync_request_id:
		return
	_active_sync_request_id = ""
	if not bool(result.get("success", false)):
		sync_state_changed.emit("hata", str(result.get("error", "Profil eşitlemesi başarısız.")))
		return
	if not bool(result.get("server_authoritative", false)):
		sync_state_changed.emit("hata", "Sağlayıcı sunucu otoritesini doğrulamadı; profil uygulanmadı.")
		return
	var remote_variant: Variant = result.get("profile", {})
	if not remote_variant is Dictionary:
		sync_state_changed.emit("hata", "Sunucu profil yanıtı geçersiz.")
		return
	_merge_online_profile(remote_variant as Dictionary)
	var acknowledged := {}
	var acknowledged_variant: Variant = result.get("acknowledged_operation_ids", [])
	if acknowledged_variant is Array:
		for operation_id_variant in acknowledged_variant as Array:
			acknowledged[str(operation_id_variant)] = true
	var sync_data := (_profile.get("sync", {}) as Dictionary).duplicate(true)
	var remaining: Array = []
	for operation_variant in sync_data.get("pending_operations", []) as Array:
		if not operation_variant is Dictionary:
			continue
		var operation := operation_variant as Dictionary
		if not acknowledged.has(str(operation.get("operation_id", ""))):
			remaining.append(operation.duplicate(true))
	sync_data["pending_operations"] = remaining
	sync_data["last_server_revision"] = int(result.get("revision", sync_data.get("last_server_revision", 0)))
	sync_data["last_synced_at_utc"] = Time.get_datetime_string_from_system(true, true)
	_profile["sync"] = sync_data
	_save_profile()
	_apply_cached_sections_to_local_repositories()
	profile_changed.emit()
	sync_state_changed.emit("eşitlendi", "Profil sunucu otoritesiyle eşitlendi.")


func _merge_online_profile(remote: Dictionary) -> void:
	for key in SERVER_AUTHORITATIVE_PROFILE_KEYS:
		if remote.has(key):
			_profile[key] = remote[key].duplicate(true) if remote[key] is Dictionary or remote[key] is Array else remote[key]

	_profile["unlocked_titles"] = _union_strings(
		_profile.get("unlocked_titles", []) as Array,
		remote.get("unlocked_titles", []) as Array
	)
	_profile["unlocked_banners"] = _union_strings(
		_profile.get("unlocked_banners", []) as Array,
		remote.get("unlocked_banners", []) as Array
	)
	for selected_key in ["selected_title", "selected_banner"]:
		if remote.has(selected_key):
			_profile[selected_key] = str(remote[selected_key])

	_profile["history"] = _merge_history_by_match_id(
		remote.get("history", []) as Array,
		_profile.get("history", []) as Array
	)
	_profile["settings"] = _latest_section(
		_profile.get("settings", {}) as Dictionary,
		remote.get("settings", {}) as Dictionary
	)
	_profile["decks"] = _latest_section(
		_profile.get("decks", {}) as Dictionary,
		remote.get("decks", {}) as Dictionary
	)
	if int(remote.get("commander_updated_at_unix", 0)) > int(_profile.get("commander_updated_at_unix", 0)):
		_profile["commander_name"] = str(remote.get("commander_name", _profile.get("commander_name", "Komutan")))
		_profile["commander_updated_at_unix"] = int(remote.get("commander_updated_at_unix", 0))


func _union_strings(left: Array, right: Array) -> Array[String]:
	var seen := {}
	var merged: Array[String] = []
	for value_variant in left + right:
		var value := str(value_variant)
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		merged.append(value)
	return merged


func _merge_history_by_match_id(primary: Array, secondary: Array) -> Array:
	var seen := {}
	var merged: Array = []
	for entry_variant in primary + secondary:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var match_id := str(entry.get("match_id", ""))
		if match_id.is_empty() or seen.has(match_id):
			continue
		seen[match_id] = true
		merged.append(entry.duplicate(true))
		if merged.size() >= MAX_HISTORY:
			break
	return merged


func _latest_section(local: Dictionary, remote: Dictionary) -> Dictionary:
	return (
		remote.duplicate(true)
		if int(remote.get("updated_at_unix", 0)) > int(local.get("updated_at_unix", 0))
		else local.duplicate(true)
	)


func _bind_local_repositories() -> void:
	var deck_repository := get_node_or_null("/root/DeckManager")
	if deck_repository:
		if deck_repository.has_method("export_profile_payload"):
			update_decks_cache(deck_repository.export_profile_payload(), false)
		var deck_callback := Callable(self, "_capture_local_decks")
		if deck_repository.has_signal("decks_changed") and not deck_repository.is_connected("decks_changed", deck_callback):
			deck_repository.connect("decks_changed", deck_callback)
	var settings_repository := get_node_or_null("/root/SettingsManager")
	if settings_repository:
		if settings_repository.has_method("export_profile_payload"):
			update_settings_cache(settings_repository.export_profile_payload(), false)
		var settings_callback := Callable(self, "_capture_local_settings")
		if settings_repository.has_signal("settings_changed") and not settings_repository.is_connected("settings_changed", settings_callback):
			settings_repository.connect("settings_changed", settings_callback)


func _capture_local_decks() -> void:
	if _applying_cached_sections:
		return
	var deck_repository := get_node_or_null("/root/DeckManager")
	if deck_repository and deck_repository.has_method("export_profile_payload"):
		update_decks_cache(deck_repository.export_profile_payload(), true)


func _capture_local_settings(_section: String = "all") -> void:
	if _applying_cached_sections:
		return
	var settings_repository := get_node_or_null("/root/SettingsManager")
	if settings_repository and settings_repository.has_method("export_profile_payload"):
		update_settings_cache(settings_repository.export_profile_payload(), true)


func _apply_cached_sections_to_local_repositories() -> void:
	_applying_cached_sections = true
	var deck_repository := get_node_or_null("/root/DeckManager")
	if deck_repository and deck_repository.has_method("import_profile_payload"):
		deck_repository.import_profile_payload(get_cached_decks())
	var settings_repository := get_node_or_null("/root/SettingsManager")
	if settings_repository and settings_repository.has_method("import_profile_payload"):
		settings_repository.import_profile_payload(get_cached_settings())
	_applying_cached_sections = false


func _new_profile_id() -> String:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(12)
	if not random_bytes.is_empty():
		return "profile-%s" % random_bytes.hex_encode()
	return "profile-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]


func _ensure_mission_periods() -> void:
	var missions_variant: Variant = _profile.get("missions", {})
	var missions := missions_variant as Dictionary if missions_variant is Dictionary else {}
	var daily_key := Time.get_date_string_from_system(true)
	var weekly_key := str(int(floor(Time.get_unix_time_from_system() / 604800.0)))
	var changed := false
	if str(missions.get("daily_key", "")) != daily_key:
		missions["daily_key"] = daily_key
		missions["daily"] = _new_mission_states(DAILY_MISSIONS)
		changed = true
	if str(missions.get("weekly_key", "")) != weekly_key:
		missions["weekly_key"] = weekly_key
		missions["weekly"] = _new_mission_states(WEEKLY_MISSIONS)
		changed = true
	_profile["missions"] = missions
	if changed and not _profile.is_empty():
		_save_profile()


func _new_mission_states(definitions: Array) -> Dictionary:
	var states := {}
	for definition_variant in definitions:
		var definition := definition_variant as Dictionary
		states[str(definition.get("id", ""))] = {"progress": 0, "completed": false, "rewarded": false}
	return states


func _advance_missions(delta: Dictionary, completed: Array[String]) -> void:
	var missions := _profile.get("missions", {}) as Dictionary
	for period in ["daily", "weekly"]:
		var definitions: Array = WEEKLY_MISSIONS if period == "weekly" else DAILY_MISSIONS
		var states := missions.get(period, {}) as Dictionary
		for definition_variant in definitions:
			var definition := definition_variant as Dictionary
			var mission_id := str(definition.get("id", ""))
			var state := states.get(mission_id, {}) as Dictionary
			var target := int(definition.get("target", 1))
			var metric := str(definition.get("metric", ""))
			state["progress"] = mini(target, int(state.get("progress", 0)) + int(delta.get(metric, 0)))
			if int(state["progress"]) >= target and not bool(state.get("completed", false)):
				state["completed"] = true
				state["rewarded"] = true
				_profile["seals"] = int(_profile.get("seals", 0)) + int(definition.get("reward", 0))
				completed.append(str(definition.get("title", mission_id)))
			states[mission_id] = state
		missions[period] = states
	_profile["missions"] = missions


func _evaluate_achievements(completed: Array[String], new_cosmetics: Array[String]) -> void:
	var stats := _profile.get("stats", {}) as Dictionary
	var states_variant: Variant = _profile.get("achievements", {})
	var states := states_variant as Dictionary if states_variant is Dictionary else {}
	for definition_variant in ACHIEVEMENT_DEFINITIONS:
		var definition := definition_variant as Dictionary
		var achievement_id := str(definition.get("id", ""))
		var metric := str(definition.get("metric", ""))
		var target := int(definition.get("target", 1))
		var state := states.get(achievement_id, {}) as Dictionary
		state["progress"] = mini(target, int(stats.get(metric, 0)))
		if int(state["progress"]) >= target and not bool(state.get("completed", false)):
			state["completed"] = true
			state["completed_at"] = Time.get_datetime_string_from_system(true, true)
			completed.append(str(definition.get("title", achievement_id)))
			_unlock_cosmetic(
				str(definition.get("reward_kind", "")),
				str(definition.get("reward_id", "")),
				new_cosmetics
			)
		states[achievement_id] = state
	_profile["achievements"] = states


func _unlock_level_reward(level: int, new_cosmetics: Array[String]) -> void:
	if not LEVEL_REWARDS.has(level):
		return
	var reward := LEVEL_REWARDS[level] as Dictionary
	_unlock_cosmetic(str(reward.get("kind", "")), str(reward.get("id", "")), new_cosmetics)


func _unlock_cosmetic(kind: String, cosmetic_id: String, new_cosmetics: Array[String]) -> void:
	if cosmetic_id.is_empty():
		return
	var key := "unlocked_titles" if kind == "title" else "unlocked_banners"
	var unlocked := _profile.get(key, []) as Array
	if cosmetic_id in unlocked:
		return
	unlocked.append(cosmetic_id)
	_profile[key] = unlocked
	new_cosmetics.append(get_cosmetic_name(kind, cosmetic_id))


func _cosmetic_entries(kind: String, ids: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id_variant in ids:
		var cosmetic_id := str(id_variant)
		entries.append({"id": cosmetic_id, "name": get_cosmetic_name(kind, cosmetic_id)})
	return entries


func _player_metrics(summary: Dictionary, player_id: int) -> Dictionary:
	var players_variant: Variant = summary.get("players", {})
	if not players_variant is Dictionary:
		return {}
	var players := players_variant as Dictionary
	if players.has(player_id):
		return (players[player_id] as Dictionary).duplicate(true)
	if players.has(str(player_id)):
		return (players[str(player_id)] as Dictionary).duplicate(true)
	return {}
