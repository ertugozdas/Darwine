extends Node


func _ready() -> void:
	# Networking lives in the NetworkManager autoload. This deliberately empty
	# scene keeps a dedicated process away from splash/menu rendering.
	process_mode = Node.PROCESS_MODE_ALWAYS
