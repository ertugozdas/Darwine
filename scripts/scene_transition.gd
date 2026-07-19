extends Node

signal transition_started(target_scene_path: String)

const LOADING_SCREEN_PATH := "res://loading_screen.tscn"
const DEFAULT_TARGET_PATH := "res://main_menu.tscn"
const DEFAULT_MINIMUM_SCREEN_TIME := 1.35

var target_scene_path := DEFAULT_TARGET_PATH
var minimum_screen_time := DEFAULT_MINIMUM_SCREEN_TIME
var transition_active := false


func transition_to(
	target_path: String,
	minimum_duration: float = DEFAULT_MINIMUM_SCREEN_TIME
) -> Error:
	if transition_active:
		return ERR_BUSY
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		push_error("Yüklenecek sahne bulunamadı: %s" % target_path)
		return ERR_FILE_NOT_FOUND

	target_scene_path = target_path
	minimum_screen_time = maxf(minimum_duration, 0.0)
	transition_active = true
	transition_started.emit(target_scene_path)

	var change_error := get_tree().change_scene_to_file(LOADING_SCREEN_PATH)
	if change_error != OK:
		transition_active = false
		push_error("Yükleme ekranı açılamadı: %s" % error_string(change_error))
	return change_error


func mark_completed() -> void:
	transition_active = false

