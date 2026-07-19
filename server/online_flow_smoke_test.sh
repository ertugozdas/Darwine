#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-$((40200 + RANDOM % 1000))}"
SECRET="${SECRET:-24681357}"
RULESET="${RULESET:-siege}"
MATCH_NAME="${MATCH_NAME:-Smoke Online Match}"
CARD_POOL="${CARD_POOL:-all_cards}"
TURN_DURATION="${TURN_DURATION:-60}"
AUTO_ATTACK="${AUTO_ATTACK:-false}"
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
	printf 'ONLINE_FLOW_SMOKE_FAILED: %s\n' "$1" >&2
	for log in "$HOST_LOG" "$CLIENT_LOG"; do
		if [[ -s "$log" ]]; then
			printf '\n[%s]\n' "$(basename "$log")" >&2
			sed -n '1,320p' "$log" >&2
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
	--smoke-host --smoke-online-flow --public-ip 127.0.0.1 --port "$PORT" \
	--secret "$SECRET" --ruleset "$RULESET" --match-name "$MATCH_NAME" \
	--card-pool "$CARD_POOL" --turn-duration "$TURN_DURATION" --auto-attack "$AUTO_ATTACK" \
	--name "Host Commander" >"$HOST_LOG" 2>&1 &
HOST_PID=$!
PIDS+=("$HOST_PID")
wait_for_marker "$HOST_PID" "$HOST_LOG" "DARWINE_HOST_INVITE_CODE=" 20 || fail_with_logs "Oda hazır olmadı."

INVITE_CODE="$(awk -F= '/^DARWINE_HOST_INVITE_CODE=/{code=$2} END{print code}' "$HOST_LOG")"
[[ -n "$INVITE_CODE" ]] || fail_with_logs "Davet kodu okunamadı."

"$GODOT_BIN_RESOLVED" --headless --path "$ROOT_DIR" -- \
	--smoke-client --smoke-online-flow --invite "$INVITE_CODE" --name "Remote Commander" \
	>"$CLIENT_LOG" 2>&1 &
CLIENT_PID=$!
PIDS+=("$CLIENT_PID")

wait_for_marker "$CLIENT_PID" "$CLIENT_LOG" "NETWORK_RECONNECT_CLIENT_DROPPED" 45 || fail_with_logs "İstemci bağlantı kesme adımına ulaşamadı."
wait_for_marker "$HOST_PID" "$HOST_LOG" "NETWORK_RECONNECT_WINDOW_OPEN player=2" 10 || fail_with_logs "Sunucu yeniden bağlanma penceresini açmadı."
wait_for_marker "$HOST_PID" "$HOST_LOG" "NETWORK_RECONNECT_SERVER_ACCEPTED player=2" 15 || fail_with_logs "Sunucu oyuncuyu eski yuvasına kabul etmedi."
wait_for_marker "$CLIENT_PID" "$CLIENT_LOG" "NETWORK_RECONNECT_CLIENT_READY player=2" 15 || fail_with_logs "İstemci geri yüklenen maça dönemedi."
wait_for_marker "$HOST_PID" "$HOST_LOG" "ONLINE_FLOW_REMATCH_SERVER_START generation=2" 15 || fail_with_logs "İki rövanş oyu yeni maçı başlatmadı."
wait_for_marker "$CLIENT_PID" "$CLIENT_LOG" "ONLINE_FLOW_REMATCH_CLIENT_READY generation=2" 20 || fail_with_logs "İstemci rövanş maçına giremedi."
wait_for_marker "$HOST_PID" "$HOST_LOG" "ONLINE_FLOW_REMATCH_HOST_READY generation=2" 10 || fail_with_logs "Oda sahibi rövanş maçına giremedi."

EXPECTED_SETTINGS="match_name=$MATCH_NAME card_pool=$CARD_POOL turn_duration=$TURN_DURATION auto_attack=$AUTO_ATTACK"
grep -q "$EXPECTED_SETTINGS" "$CLIENT_LOG" || fail_with_logs "İstemci hostun tam oda ayarlarını almadı."
grep -q "ONLINE_FLOW_REMATCH_CLIENT_READY generation=2.*$EXPECTED_SETTINGS" "$CLIENT_LOG" || fail_with_logs "İstemci rövanşta oda ayarlarını korumadı."
grep -q "ONLINE_FLOW_REMATCH_HOST_READY generation=2.*$EXPECTED_SETTINGS" "$HOST_LOG" || fail_with_logs "Oda sahibi rövanşta oda ayarlarını korumadı."

if [[ "$RULESET" == "dominion" || "$RULESET" == "hakimiyet" || "$RULESET" == "1" ]]; then
	grep -q "ONLINE_FLOW_REMATCH_CLIENT_READY generation=2 ruleset=Hakimiyet" "$CLIENT_LOG" || fail_with_logs "İstemci rövanşta Hakimiyet kuralını korumadı."
	grep -q "ONLINE_FLOW_REMATCH_HOST_READY generation=2 ruleset=Hakimiyet" "$HOST_LOG" || fail_with_logs "Sunucu rövanşta Hakimiyet kuralını korumadı."
fi

for log in "$HOST_LOG" "$CLIENT_LOG"; do
	if grep -E "SCRIPT ERROR|Parse Error|ERROR:" "$log" >/dev/null 2>&1; then
		fail_with_logs "Godot günlüğünde hata bulundu."
	fi
done

printf 'ONLINE_FLOW_SMOKE_OK reconnect=restored rematch=started ruleset=%s settings=%s/%s/%s invite=%s port=%s\n' "$RULESET" "$CARD_POOL" "$TURN_DURATION" "$AUTO_ATTACK" "$INVITE_CODE" "$PORT"
