class_name InviteCode extends RefCounted

## Human-friendly, central-service-free invite codes.
##
## The 20 Crockford Base32 characters contain:
## - protocol version (1 byte)
## - public IPv4 address (4 bytes)
## - UDP port (2 bytes)
## - per-server invite secret (4 bytes)
## - CRC-8 typo checksum (1 byte)

const PROTOCOL_VERSION := 1
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const ENCODED_CHARACTER_COUNT := 20
const PAYLOAD_SIZE := 12


static func encode_ipv4(address: String, port: int, secret: int) -> String:
	var octets := _parse_ipv4(address)
	if octets.is_empty() or port < 1 or port > 65535 or secret < 1:
		return ""

	var bytes := PackedByteArray()
	bytes.append(PROTOCOL_VERSION)
	for octet in octets:
		bytes.append(int(octet))
	bytes.append((port >> 8) & 0xFF)
	bytes.append(port & 0xFF)
	for shift in [24, 16, 8, 0]:
		bytes.append((secret >> shift) & 0xFF)
	bytes.append(_crc8(bytes))

	var compact := _base32_encode(bytes)
	var groups: Array[String] = []
	for offset in range(0, compact.length(), 5):
		groups.append(compact.substr(offset, mini(5, compact.length() - offset)))
	return "-".join(groups)


static func decode(raw_code: String) -> Dictionary:
	var compact := normalize(raw_code).replace("-", "")
	if compact.length() != ENCODED_CHARACTER_COUNT:
		return _failure("Davet kodu 20 karakter olmalı.")

	var bytes := _base32_decode(compact)
	if bytes.size() != PAYLOAD_SIZE:
		return _failure("Davet kodu çözülemedi.")
	if int(bytes[0]) != PROTOCOL_VERSION:
		return _failure("Davet kodunun sürümü bu oyunla uyumlu değil.")

	var expected_checksum := _crc8(bytes.slice(0, PAYLOAD_SIZE - 1))
	if int(bytes[PAYLOAD_SIZE - 1]) != expected_checksum:
		return _failure("Davet kodu hatalı veya eksik yazılmış.")

	var address := "%d.%d.%d.%d" % [bytes[1], bytes[2], bytes[3], bytes[4]]
	var port := (int(bytes[5]) << 8) | int(bytes[6])
	var secret := (
		(int(bytes[7]) << 24)
		| (int(bytes[8]) << 16)
		| (int(bytes[9]) << 8)
		| int(bytes[10])
	)
	if _parse_ipv4(address).is_empty() or port < 1 or secret < 1:
		return _failure("Davet kodundaki sunucu bilgisi geçersiz.")

	return {
		"success": true,
		"address": address,
		"port": port,
		"secret": secret,
		"protocol": int(bytes[0]),
		"code": _format_compact(compact),
	}


static func normalize(raw_code: String) -> String:
	var normalized := raw_code.strip_edges().to_upper()
	normalized = normalized.replace(" ", "").replace("_", "-")
	# Crockford aliases make codes forgiving when typed from a screenshot.
	normalized = normalized.replace("O", "0").replace("I", "1").replace("L", "1")
	return normalized


static func _parse_ipv4(address: String) -> Array[int]:
	var parts := address.strip_edges().split(".")
	if parts.size() != 4:
		return []
	var octets: Array[int] = []
	for part in parts:
		if not part.is_valid_int():
			return []
		var octet := part.to_int()
		if octet < 0 or octet > 255:
			return []
		octets.append(octet)
	return octets


static func _base32_encode(bytes: PackedByteArray) -> String:
	var output := ""
	var buffer := 0
	var bit_count := 0
	for byte in bytes:
		buffer = (buffer << 8) | int(byte)
		bit_count += 8
		while bit_count >= 5:
			bit_count -= 5
			output += ALPHABET[(buffer >> bit_count) & 0x1F]
		buffer &= (1 << bit_count) - 1 if bit_count > 0 else 0
	if bit_count > 0:
		output += ALPHABET[(buffer << (5 - bit_count)) & 0x1F]
	return output


static func _base32_decode(compact: String) -> PackedByteArray:
	var output := PackedByteArray()
	var buffer := 0
	var bit_count := 0
	for character in compact:
		var value := ALPHABET.find(character)
		if value < 0:
			return PackedByteArray()
		buffer = (buffer << 5) | value
		bit_count += 5
		while bit_count >= 8:
			bit_count -= 8
			output.append((buffer >> bit_count) & 0xFF)
		buffer &= (1 << bit_count) - 1 if bit_count > 0 else 0
	return output


static func _crc8(bytes: PackedByteArray) -> int:
	var crc := 0
	for byte in bytes:
		crc ^= int(byte)
		for _bit in range(8):
			crc = ((crc << 1) ^ 0x07) & 0xFF if (crc & 0x80) != 0 else (crc << 1) & 0xFF
	return crc


static func _format_compact(compact: String) -> String:
	var groups: Array[String] = []
	for offset in range(0, compact.length(), 5):
		groups.append(compact.substr(offset, mini(5, compact.length() - offset)))
	return "-".join(groups)


static func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message}
