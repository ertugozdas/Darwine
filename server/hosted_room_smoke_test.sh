#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-$((39000 + RANDOM % 1200))}"
SECRET="${SECRET:-987654}"
RULESET="${RULESET:-siege}"
TEMP_DIR="$(mktemp -d)"
HOST_LOG="$TEMP_DIR/host.log"
CLIENT_LOG="$TEMP_DIR/client.log"
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
	printf 'HOSTED_ROOM_SMOKE_FAILED: %s\n' "$1" >&2
	for log in "$HOST_LOG" "$CLIENT_LOG"; do
		if [[ -s "$log" ]]; then
			printf '\n[%s]\n' "$(basename "$log")" >&2
			sed -n '1,260p' "$log" >&2
		fi
	done
	exit 1
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

GODOT_BIN_RESOLVED="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
[[ -x "$GODOT_BIN_RESOLVED" ]] || fail_with_logs "Godot bulunamadı."

"$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--smoke-host --public-ip 127.0.0.1 --port "$PORT" --secret "$SECRET" --ruleset "$RULESET" --name "Host Commander" \
	>"$HOST_LOG" 2>&1 &
HOST_PID=$!
PIDS+=("$HOST_PID")
wait_for_marker "$HOST_PID" "$HOST_LOG" "DARWINE_HOST_INVITE_CODE=" 20 || fail_with_logs "Oyun içi oda hazır olmadı."

INVITE_CODE="$(awk -F= '/^DARWINE_HOST_INVITE_CODE=/{code=$2} END{print code}' "$HOST_LOG")"
[[ -n "$INVITE_CODE" ]] || fail_with_logs "Oda davet kodu okunamadı."

"$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--smoke-client --invite "$INVITE_CODE" --name "Remote Commander" \
	>"$CLIENT_LOG" 2>&1 &
CLIENT_PID=$!
PIDS+=("$CLIENT_PID")

wait_for_marker "$CLIENT_PID" "$CLIENT_LOG" "NETWORK_SMOKE_CLIENT_READY player=2" 45 || fail_with_logs "Uzak oyuncu oyun içi odaya giremedi."
wait_for_marker "$HOST_PID" "$HOST_LOG" "NETWORK_SMOKE_SERVER_OK players=1" 10 || fail_with_logs "Oda sahibi uzak oyuncuyu doğrulamadı."
wait_for_marker "$HOST_PID" "$HOST_LOG" "HOSTED_ROOM_MATCH_READY" 10 || fail_with_logs "Oda sahibi yerel oyuncu olarak maçı başlatamadı."

if [[ "$RULESET" == "dominion" || "$RULESET" == "hakimiyet" || "$RULESET" == "1" ]]; then
	grep -q "NETWORK_SMOKE_CLIENT_READY player=2.*ruleset=Hakimiyet" "$CLIENT_LOG" || fail_with_logs "İstemci Hakimiyet oda kuralını almadı."
	grep -q "HOSTED_ROOM_MATCH_READY ruleset=Hakimiyet" "$HOST_LOG" || fail_with_logs "Oda sahibi Hakimiyet kuralını kurmadı."
fi

for log in "$HOST_LOG" "$CLIENT_LOG"; do
	if grep -E "SCRIPT ERROR|Parse Error" "$log" >/dev/null 2>&1; then
		fail_with_logs "Godot çalışma günlüğünde betik hatası bulundu."
	fi
done

printf 'HOSTED_ROOM_SMOKE_OK ruleset=%s invite=%s port=%s\n' "$RULESET" "$INVITE_CODE" "$PORT"
