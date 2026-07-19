extends SceneTree

const INVITE_CODE := preload("res://scripts/invite_code.gd")


func _init() -> void:
	var code: String = INVITE_CODE.encode_ipv4("203.0.113.42", 7777, 0x12345678)
	_assert(not code.is_empty(), "Kod üretilemedi")
	_assert(code.replace("-", "").length() == 20, "Kod 20 karakter değil")

	var decoded: Dictionary = INVITE_CODE.decode(code.to_lower())
	_assert(bool(decoded.get("success", false)), "Kod çözülemedi: %s" % decoded.get("error", ""))
	_assert(decoded.get("address") == "203.0.113.42", "IPv4 round-trip bozuk")
	_assert(int(decoded.get("port", 0)) == 7777, "Port round-trip bozuk")
	_assert(int(decoded.get("secret", 0)) == 0x12345678, "Oturum anahtarı round-trip bozuk")

	var broken := code.substr(0, code.length() - 1) + ("0" if not code.ends_with("0") else "1")
	_assert(not bool(INVITE_CODE.decode(broken).get("success", false)), "Checksum bozuk kodu kabul etti")
	_assert(not bool(INVITE_CODE.decode("KISA-KOD").get("success", false)), "Kısa kod kabul edildi")

	print("INVITE_CODE_SMOKE_OK code=%s" % code)
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
