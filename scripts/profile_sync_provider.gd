class_name ProfileSyncProvider extends Node

## Contract for a real account/backend adapter. The base implementation is
## deliberately unavailable; local JSON is never presented as an online save.

signal sync_completed(request_id: String, result: Dictionary)
signal availability_changed(is_available: bool)


func is_available() -> bool:
	return false


func get_account_id() -> String:
	return ""


func begin_sync(_request_id: String, _request: Dictionary) -> bool:
	return false


func cancel_sync(_request_id: String) -> void:
	pass
