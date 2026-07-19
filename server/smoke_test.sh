#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-$((37000 + RANDOM % 2000))}"
SECRET="${SECRET:-123456}"
RULESET="${RULESET:-siege}"
TEMP_DIR="$(mktemp -d)"
SERVER_LOG="$TEMP_DIR/server.log"
CLIENT_ONE_LOG="$TEMP_DIR/client-one.log"
CLIENT_TWO_LOG="$TEMP_DIR/client-two.log"
PIDS=()

cleanup() {
	for pid in "${PIDS[@]:-}"; do
		if kill -0 "$pid" >/dev/null 2>&1; then
			kill "$pid" >/dev/null 2>&1 || true
		fi
	done
	rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

fail_with_logs() {
	printf 'NETWORK_SMOKE_FAILED: %s\n' "$1" >&2
	for log in "$SERVER_LOG" "$CLIENT_ONE_LOG" "$CLIENT_TWO_LOG"; do
		if [[ -s "$log" ]]; then
			printf '\n[%s]\n' "$(basename "$log")" >&2
			sed -n '1,240p' "$log" >&2
		fi
	done
	exit 1
}

find_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf '%s' "$GODOT_BIN"
	elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
		printf '%s' "/Applications/Godot.app/Contents/MacOS/Godot"
	elif command -v godot4 >/dev/null 2>&1; then
		command -v godot4
	elif command -v godot >/dev/null 2>&1; then
		command -v godot
	else
		return 1
	fi
}

wait_for_marker() {
	local pid="$1"
	local log="$2"
	local marker="$3"
	local timeout_seconds="$4"
	local deadline=$((SECONDS + timeout_seconds))
	while (( SECONDS < deadline )); do
		if grep -q "$marker" "$log" 2>/dev/null; then
			return 0
		fi
		if ! kill -0 "$pid" >/dev/null 2>&1; then
			return 1
		fi
		sleep 0.1
	done
	return 1
}

GODOT_BIN_RESOLVED="$(find_godot)" || fail_with_logs "Godot bulunamadı. GODOT_BIN=/tam/yol ile belirtin."

if [[ -n "${SERVER_PACK:-}" ]]; then
	[[ -f "$SERVER_PACK" ]] || fail_with_logs "SERVER_PACK bulunamadı: $SERVER_PACK"
	"$GODOT_BIN_RESOLVED" --headless --main-pack "$SERVER_PACK" -- --server --smoke-server --public-ip 127.0.0.1 --port "$PORT" --secret "$SECRET" --ruleset "$RULESET" >"$SERVER_LOG" 2>&1 &
else
	"$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- --server --smoke-server --public-ip 127.0.0.1 --port "$PORT" --secret "$SECRET" --ruleset "$RULESET" >"$SERVER_LOG" 2>&1 &
fi
SERVER_PID=$!
PIDS+=("$SERVER_PID")
wait_for_marker "$SERVER_PID" "$SERVER_LOG" "DARWINE_INVITE_CODE=" 20 || fail_with_logs "Sunucu hazır olmadı."

INVITE_CODE="$(awk -F= '/^DARWINE_INVITE_CODE=/{code=$2} END{print code}' "$SERVER_LOG")"
[[ -n "$INVITE_CODE" ]] || fail_with_logs "Davet kodu okunamadı."

"$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- --smoke-client --invite "$INVITE_CODE" --name "Smoke One" >"$CLIENT_ONE_LOG" 2>&1 &
CLIENT_ONE_PID=$!
PIDS+=("$CLIENT_ONE_PID")
"$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- --smoke-client --invite "$INVITE_CODE" --name "Smoke Two" >"$CLIENT_TWO_LOG" 2>&1 &
CLIENT_TWO_PID=$!
PIDS+=("$CLIENT_TWO_PID")

wait_for_marker "$CLIENT_ONE_PID" "$CLIENT_ONE_LOG" "NETWORK_SMOKE_CLIENT_READY" 45 || fail_with_logs "Birinci istemci maça giremedi."
wait_for_marker "$CLIENT_TWO_PID" "$CLIENT_TWO_LOG" "NETWORK_SMOKE_CLIENT_READY" 45 || fail_with_logs "İkinci istemci maça giremedi."
wait_for_marker "$SERVER_PID" "$SERVER_LOG" "NETWORK_SMOKE_SERVER_OK players=2" 10 || fail_with_logs "Sunucu iki hazır istemciyi doğrulamadı."

if [[ "$RULESET" == "dominion" || "$RULESET" == "hakimiyet" || "$RULESET" == "1" ]]; then
	grep -q "NETWORK_SMOKE_CLIENT_READY.*ruleset=Hakimiyet" "$CLIENT_ONE_LOG" || fail_with_logs "Birinci istemci Hakimiyet kuralını almadı."
	grep -q "NETWORK_SMOKE_CLIENT_READY.*ruleset=Hakimiyet" "$CLIENT_TWO_LOG" || fail_with_logs "İkinci istemci Hakimiyet kuralını almadı."
fi

for log in "$SERVER_LOG" "$CLIENT_ONE_LOG" "$CLIENT_TWO_LOG"; do
	if grep -E "SCRIPT ERROR|Parse Error" "$log" >/dev/null 2>&1; then
		fail_with_logs "Godot çalışma günlüğünde betik hatası bulundu."
	fi
done

printf 'NETWORK_SMOKE_OK ruleset=%s invite=%s port=%s\n' "$RULESET" "$INVITE_CODE" "$PORT"
